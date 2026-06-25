/*
 * 通用 CPU UART 控制器（带寄存器接口 + FIFO + 中断）
 *
 * 设计目标：
 *   1. 通过标准寄存器接口与 CPU 通信（类似 APB-lite，但更简单）
 *   2. 内置 TX/RX FIFO 解耦 CPU 总线时序和串口时序
 *   3. 波特率可运行时配置
 *   4. 支持中断通知 CPU
 *
 * 典型应用场景：
 *   - 挂载到 CPU 的内存映射总线上作为外设
 *   - 通过 0x00 写数据发送，读数据接收
 *   - 通过中断或轮询 STATUS 寄存器判断收发状态
 */
module uart #(
    // 系统时钟频率，默认 50MHz
    parameter CLK_HZ       = 50_000_000,
    // 默认波特率，仅决定复位后初始值，实际可通过寄存器修改
    parameter DEFAULT_BAUD = 115_200,
    // TX/RX FIFO 深度，默认 8，必须是 2 的幂次方便指针处理
    parameter FIFO_DEPTH   = 8
)(
    input  wire        clk,      // 系统时钟
    input  wire        rst_n,    // 低电平异步复位

    // =====================================================================
    // 寄存器总线接口（单周期读写，ready 恒为 1）
    // =====================================================================
    input  wire [31:0] addr,     // 寄存器地址（32bit 字节对齐，方便对接 AHB/APB 总线）
    input  wire        wen,      // 写使能（高有效）
    input  wire        ren,      // 读使能（高有效）
    input  wire [31:0] wdata,    // CPU 写入数据
    output reg  [31:0] rdata,    // 返回给 CPU 的数据
    output wire        ready,    // 从机 ready，本模块恒为 1，单周期完成

    // =====================================================================
    // UART 物理信号线
    // =====================================================================
    output reg         txd,      // UART 发送输出（连接到外部 TXD 引脚）
    input  wire        rxd,      // UART 接收输入（连接到外部 RXD 引脚）

    // =====================================================================
    // 中断信号
    // =====================================================================
    output wire        irq       // 高电平有效，通知 CPU 有事件需要处理
);

    // =====================================================================
    // 一、寄存器地址定义
    // =====================================================================
    // 将连续地址映射到不同功能寄存器，CPU 通过 addr 选择访问目标
    //
    // 地址    寄存器    类型    说明
    // 0x00    DATA      RW      写=把数据推入 TX FIFO；读=从 RX FIFO 取出数据
    // 0x04    STATUS    RO      当前状态：满、空、忙、溢出
    // 0x08    CTRL      RW      控制：使能、TX 中断使能、RX 中断使能
    // 0x0C    BAUD      RW      波特率分频值 = CLK_HZ / 目标波特率
    //
    // 地址使用 32bit，直接对接总线地址；低位译码选择寄存器
    localparam ADDR_DATA = 32'h0000_0000;
    localparam ADDR_STAT = 32'h0000_0004;
    localparam ADDR_CTRL = 32'h0000_0008;
    localparam ADDR_BAUD = 32'h0000_000C;

    // =====================================================================
    // 二、内部寄存器声明
    // =====================================================================
    // baud_div：波特率分频计数器阈值
    //   - 每 bit 的时钟周期数 = baud_div
    //   - 例如 50MHz / 115200 ≈ 434，写 434 即可得到 115200 波特率
    //   - 16bit 宽，支持波特率从 CLK_HZ/1 到 CLK_HZ/65535 的范围
    reg [15:0] baud_div;

    // ctrl：控制寄存器，3bit
    //   bit[0] = uart_en   ：模块总使能，为 0 时收发均停止
    //   bit[1] = tx_ie     ：TX 中断使能
    //   bit[2] = rx_ie     ：RX 中断使能
    reg [2:0] ctrl;

    // rx_overrun：RX 溢出标志
    //   当 RX FIFO 满时又有新数据到达，置 1，需软件写 1 清零（W1C）
    reg rx_overrun;

    // 提取控制位信号，增强可读性
    wire uart_en = ctrl[0];
    wire tx_ie   = ctrl[1];
    wire rx_ie   = ctrl[2];

    // =====================================================================
    // 三、TX FIFO（发送缓冲队列）
    // =====================================================================
    // 为什么需要 FIFO？
    //   CPU 总线速度很快（50MHz），而 UART 波特率很慢（115200bps）。
    //   没有 FIFO 的话，CPU 每发一个字节必须等待约 87us（10bit/115200），
    //   效率极低。FIFO 让 CPU 一次性写入多个字节后立刻返回。
    //
    // 为什么 FIFO 深度用 2 的幂次？
    //   指针用二进制计数，自然回绕，不需要额外做取模运算。
    //   例如深度 8，指针 3bit，从 7 到 0 自然回绕。

    reg [7:0] tx_fifo [0:FIFO_DEPTH-1]; // 数据存储数组

    // 读写指针：比实际索引多 1bit（最高位作为回绕标记）
    //   - 低 $clog2(FIFO_DEPTH) bit 用于索引数组
    //   - 最高位用来区分 "空" 和 "满"
    //   例如深度 8，指针为 4bit（3bit 索引 + 1bit 回绕标记）
    reg [$clog2(FIFO_DEPTH):0] tx_wr_ptr, tx_rd_ptr;

    // tx_full 判断逻辑：
    //   当回绕位不同、但索引位相同时，表示写指针追上读指针一圈，FIFO 满
    wire tx_full  = (tx_wr_ptr[$clog2(FIFO_DEPTH)] != tx_rd_ptr[$clog2(FIFO_DEPTH)]) &&
                    (tx_wr_ptr[$clog2(FIFO_DEPTH)-1:0] == tx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]);

    // tx_empty 判断逻辑：
    //   当读写指针完全相等时，表示所有数据都已读出，FIFO 空
    wire tx_empty = (tx_wr_ptr == tx_rd_ptr);

    // =====================================================================
    // 四、RX FIFO（接收缓冲队列）
    // =====================================================================
    // 同理，RX FIFO 缓存接收到的数据，CPU 可以批量读取
    reg [7:0] rx_fifo [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH):0] rx_wr_ptr, rx_rd_ptr;

    wire rx_full  = (rx_wr_ptr[$clog2(FIFO_DEPTH)] != rx_rd_ptr[$clog2(FIFO_DEPTH)]) &&
                    (rx_wr_ptr[$clog2(FIFO_DEPTH)-1:0] == rx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]);
    wire rx_empty = (rx_wr_ptr == rx_rd_ptr);

    // =====================================================================
    // 五、TX 引擎（串行发送状态机）
    // =====================================================================
    // UART 帧格式（8N1）：
    //   [ 起始位(0) | D0 | D1 | ... | D7 | 停止位(1) ]
    //   每 bit 持续时间 = baud_div 个系统时钟周期

    localparam TX_IDLE  = 2'd0,  // 空闲：等待 FIFO 非空
               TX_START = 2'd1,  // 发送起始位（拉低）
               TX_DATA  = 2'd2,  // 发送 8 位数据（LSB first）
               TX_STOP  = 2'd3;  // 发送停止位（拉高）

    reg [1:0]  tx_state;     // 当前状态
    reg [15:0] tx_clk_cnt;   // 波特率分频计数器
    reg [2:0]  tx_bit_cnt;   // 已发送的数据位计数（0~7）
    reg [7:0]  tx_shift;     // 移位寄存器，当前正在发送的字节
    reg        tx_busy;      // 发送忙标志，供 STATUS 寄存器查询
    reg        rx_overrun_set; // RX overflow 脉冲（RX 状态机 → 寄存器块）

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state   <= TX_IDLE;
            tx_clk_cnt <= 16'd0;
            tx_bit_cnt <= 3'd0;
            tx_shift   <= 8'd0;
            tx_busy    <= 1'b0;
            txd        <= 1'b1;
            tx_rd_ptr  <= 0;  // UART 空闲时保持高电平
        end else begin
            case (tx_state)

                // ---------------------------------------------------------
                // TX_IDLE：空闲态
                // ---------------------------------------------------------
                // 保持 txd 为高（空闲电平）。
                // 如果模块使能且 TX FIFO 非空，从 FIFO 取出一个字节开始发送。
                TX_IDLE: begin
                    txd <= 1'b1;
                    if (uart_en && !tx_empty) begin
                        // 从 FIFO 读取数据到移位寄存器
                        tx_shift <= tx_fifo[tx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]];
                        // 读指针推进，表示该数据已取出
                        tx_rd_ptr <= tx_rd_ptr + 1'b1;
                        tx_state   <= TX_START;
                        tx_busy    <= 1'b1;
                        tx_clk_cnt <= 16'd0;
                    end else begin
                        tx_busy <= 1'b0;
                    end
                end

                // ---------------------------------------------------------
                // TX_START：发送起始位
                // ---------------------------------------------------------
                // UART 起始位 = 低电平，持续 1 个 bit 时间
                TX_START: begin
                    txd <= 1'b0;  // 拉低
                    if (tx_clk_cnt == baud_div - 1) begin
                        tx_clk_cnt <= 16'd0;
                        tx_state   <= TX_DATA;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1'b1;
                    end
                end

                // ---------------------------------------------------------
                // TX_DATA：发送 8 位数据
                // ---------------------------------------------------------
                // LSB first：先发最低位 tx_shift[0]
                // 每发送 1 位后右移，8 位发完进入停止位
                TX_DATA: begin
                    txd <= tx_shift[0];
                    if (tx_clk_cnt == baud_div - 1) begin
                        tx_clk_cnt <= 16'd0;
                        tx_shift   <= {1'b0, tx_shift[7:1]};  // 右移，移入 0
                        if (tx_bit_cnt == 3'd7) begin
                            tx_bit_cnt <= 3'd0;
                            tx_state   <= TX_STOP;
                        end else begin
                            tx_bit_cnt <= tx_bit_cnt + 1'b1;
                        end
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1'b1;
                    end
                end

                // ---------------------------------------------------------
                // TX_STOP：发送停止位
                // ---------------------------------------------------------
                // 停止位 = 高电平，持续 1 个 bit 时间（可扩展为多 stop bit）
                // 完成后回到 IDLE，准备发送下一个字节
                TX_STOP: begin
                    txd <= 1'b1;
                    if (tx_clk_cnt == baud_div - 1) begin
                        tx_clk_cnt <= 16'd0;
                        tx_state   <= TX_IDLE;
                        tx_busy    <= 1'b0;
                    end else begin
                        tx_clk_cnt <= tx_clk_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

    // =====================================================================
    // 六、RX 引擎（串行接收状态机）
    // =====================================================================
    // 接收比发送更复杂，因为输入信号是异步的（来自外部设备）。
    // 需要做两件事：
    //   1. 同步：用两级触发器消除亚稳态
    //   2. 采样：在 bit 中心采样，避开边沿变化

    // ---------------------------------------------------------------
    // 6.1 输入同步（消除亚稳态）
    // ---------------------------------------------------------------
    // rxd 是外部异步信号，直接用于时序逻辑可能产生亚稳态。
    // 用两级 D 触发器同步到 clk 域：
    //   rxd -> rxd_sync -> rxd_dly
    // 这是标准的跨时钟域同步方案。
    reg rxd_sync, rxd_dly;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rxd_sync <= 1'b1;
            rxd_dly  <= 1'b1;
        end else begin
            rxd_sync <= rxd;      // 第一级同步
            rxd_dly  <= rxd_sync; // 第二级同步（同时用于边沿检测）
        end
    end

    // 下降沿检测：前一拍高、当前拍低 = 起始位到来
    // 注意：UART 空闲为高，起始位为低
    wire rx_start_det = rxd_dly && !rxd_sync;

    // ---------------------------------------------------------------
    // 6.2 RX 状态机
    // ---------------------------------------------------------------
    // 状态转移：IDLE -> START -> DATA -> STOP -> IDLE
    // 采样策略：每个 bit 的中心点采样（bit 开始 + baud_div/2）
    // 这样可以避开信号边沿，提高抗干扰能力

    localparam RX_IDLE  = 2'd0,
               RX_START = 2'd1,
               RX_DATA  = 2'd2,
               RX_STOP  = 2'd3;

    reg [1:0]  rx_state;
    reg [15:0] rx_clk_cnt;
    reg [2:0]  rx_bit_cnt;
    reg [7:0]  rx_shift;  // 接收移位寄存器（LSB first 移入）

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state   <= RX_IDLE;
            rx_clk_cnt <= 16'd0;
            rx_bit_cnt <= 3'd0;
            rx_shift   <= 8'd0;
            rx_wr_ptr  <= 0;
            rx_shift   <= 8'd0;
        end else begin
            rx_overrun_set <= 1'b0;
            case (rx_state)

                // ---------------------------------------------------------
                // RX_IDLE：等待起始位
                // ---------------------------------------------------------
                RX_IDLE: begin
                    rx_clk_cnt <= 16'd0;
                    // 只有模块使能时才响应外部信号
                    if (uart_en && rx_start_det)
                        rx_state <= RX_START;
                end

                // ---------------------------------------------------------
                // RX_START：验证起始位
                // ---------------------------------------------------------
                // 起始位检测可能是毛刺（噪声），不立即信任。
                // 等待半个 bit 周期（baud_div/2）后采样：
                //   - 如果仍为低电平，确认是真实起始位，进入 DATA
                //   - 如果变高了，认为是毛刺，返回 IDLE
                RX_START: begin
                    if (rx_clk_cnt == (baud_div >> 1) - 1) begin
                        rx_clk_cnt <= 16'd0;
                        if (!rxd_sync)
                            rx_state <= RX_DATA;
                        else
                            rx_state <= RX_IDLE;
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1'b1;
                    end
                end

                // ---------------------------------------------------------
                // RX_DATA：接收 8 位数据
                // ---------------------------------------------------------
                // 每个 bit 的中心采样（计数到 baud_div-1 时采样）
                // 采样值从 LSB 移入 rx_shift
                // 8 位收完后进入 STOP
                RX_DATA: begin
                    if (rx_clk_cnt == baud_div - 1) begin
                        rx_clk_cnt <= 16'd0;
                        // LSB first：新采样值放到最高位，整体右移
                        rx_shift   <= {rxd_sync, rx_shift[7:1]};
                        if (rx_bit_cnt == 3'd7) begin
                            rx_bit_cnt <= 3'd0;
                            rx_state   <= RX_STOP;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt + 1'b1;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1'b1;
                    end
                end

                // ---------------------------------------------------------
                // RX_STOP：停止位 + 数据入 FIFO
                // ---------------------------------------------------------
                // 停止位期间不需要采样，只需要等 1 个 bit 时间。
                // 停止位结束后：
                //   - 如果 RX FIFO 未满，把 rx_shift 写入 FIFO
                //   - 如果 RX FIFO 满了，置 rx_overrun 标志
                RX_STOP: begin
                    if (rx_clk_cnt == baud_div - 1) begin
                        rx_clk_cnt <= 16'd0;
                        rx_state   <= RX_IDLE;
                        if (!rx_full) begin
                            rx_fifo[rx_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= rx_shift;
                            rx_wr_ptr <= rx_wr_ptr + 1'b1;
                        end else begin
                            rx_overrun_set <= 1'b1;
                        end
                    end else begin
                        rx_clk_cnt <= rx_clk_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

    // =====================================================================
    // 七、寄存器接口逻辑（CPU 读写控制）
    // =====================================================================
    // 这是 CPU 侧与 UART 控制器交互的核心。
    // wen=1 时根据 addr 写相应寄存器；ren=1 时根据 addr 返回 rdata。
    // 本模块为单周期响应（ready=1），无等待周期。

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位初始化
            baud_div   <= CLK_HZ / DEFAULT_BAUD;  // 计算默认波特率分频值
            ctrl       <= 3'b001;                   // 默认使能 UART
            rx_overrun <= 1'b0;
            tx_wr_ptr  <= 0;
            rx_rd_ptr  <= 0;
            rdata      <= 32'd0;
        end else begin
            // ---------------------------------------------------------
            // 7.1 STATUS 寄存器写操作（W1C：写 1 清零）
            // ---------------------------------------------------------
            // rx_overrun：由 RX 状态机置脉冲 rx_overrun_set，本块锁存；
            // 软件向 STATUS 的 bit[3] 写 1 清零。
            if (rx_overrun_set)
                rx_overrun <= 1'b1;
            else if (wen && addr[3:0] == 4'h4)
                rx_overrun <= rx_overrun & ~wdata[3];

            // ---------------------------------------------------------
            // 7.2 写寄存器
            // ---------------------------------------------------------
            if (wen) begin
                case (addr[3:0])
                    4'h0: begin
                        if (!tx_full) begin
                            tx_fifo[tx_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= wdata[7:0];
                            tx_wr_ptr <= tx_wr_ptr + 1'b1;
                        end
                    end

                    4'h8: ctrl <= wdata[2:0];

                    4'hC: baud_div <= wdata[15:0];
                endcase
            end

            if (ren) begin
                case (addr[3:0])
                    4'h0: begin
                        rdata <= {24'd0, rx_fifo[rx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]]};
                        if (!rx_empty)
                            rx_rd_ptr <= rx_rd_ptr + 1'b1;
                    end

                    4'h4: rdata <= {28'd0, rx_overrun, tx_busy, rx_empty, tx_full};

                    4'h8: rdata <= {29'd0, ctrl};

                    4'hC: rdata <= {16'd0, baud_div};

                    default: rdata <= 32'd0;
                endcase
            end else begin
                // 不读时 rdata 保持 0（避免总线冲突，实际看总线协议要求）
                rdata <= 32'd0;
            end
        end
    end

    // 恒为 1，表示本从机永远单周期响应
    assign ready = 1'b1;

    // =====================================================================
    // 八、中断逻辑
    // =====================================================================
    // 中断触发条件：
    //   1. TX 完成中断：TX FIFO 空 且 TX 引擎空闲 且 tx_ie 使能
    //      表示所有数据已发送完毕，CPU 可以准备下一批数据
    //   2. RX 接收中断：RX FIFO 非空 且 rx_ie 使能
    //      表示有新数据到达，CPU 应该来读取
    //
    // 典型中断服务流程：
    //   1. CPU 收到 irq，读 STATUS 判断是 TX 还是 RX 中断
    //   2. 如果是 RX 中断，循环读 DATA 直到 rx_empty=1
    //   3. 如果是 TX 中断，继续写入数据到 DATA，或关闭 tx_ie

    assign irq = (tx_empty && !tx_busy && tx_ie) || (!rx_empty && rx_ie);

endmodule
