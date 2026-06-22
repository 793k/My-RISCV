module uart_rx #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD_RATE = 115_200
) (
    input  wire clk,
    input  wire rst_n,

    input  wire rxd, // UART 输入
    output reg  [7:0] rx_data, // 接收到的数据
    output reg  rx_valid // 高电平一个周期，表示 rx_data 有效
);

    localparam BIT_PERIOD = CLK_HZ / BAUD_RATE;
    localparam CNT_W = $clog2(BIT_PERIOD);
    localparam HALF_BIT = BIT_PERIOD / 2;

    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [      1:0] state;
    reg [CNT_W-1:0] clk_cnt;
    reg [      2:0] bit_cnt;
    reg [      7:0] shift_reg;
    reg rxd_sync, rxd_dly;  // 两级同步 + 边沿检测
    wire start_detect;

    // 输入同步 + 下降沿检测（检测起始位）

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rxd_sync <= 1'b1;
            rxd_dly  <= 1'b1;
        end else begin
            rxd_sync <= rxd;
            rxd_dly  <= rxd_sync;
        end
    end

    assign start_detect = rxd_dly && !rxd_sync;  // 下降沿

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            clk_cnt   <= {CNT_W{1'b0}};
            bit_cnt   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0;  // 默认拉低，只脉冲一个周期

            case (state)
                IDLE: begin
                    clk_cnt <= {CNT_W{1'b0}};
                    bit_cnt <= 3'd0;
                    if (start_detect) begin
                        state <= START;
                    end
                end

                START: begin

                    // 等待到起始位中心（半个 bit 周期）采样，确认不是毛刺
                    if (clk_cnt == HALF_BIT - 1) begin
                        clk_cnt <= {CNT_W{1'b0}};
                        if (!rxd_sync) begin  // 确认仍为低
                            state <= DATA;
                        end else begin
                            state <= IDLE;  // 毛刺，放弃
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DATA: begin

                    // 每个 bit 中心采样
                    if (clk_cnt == BIT_PERIOD - 1) begin
                        clk_cnt   <= {CNT_W{1'b0}};
                        shift_reg <= {rxd_sync, shift_reg[7:1]};  // LSB first
                        if (bit_cnt == 3'd7) begin
                            bit_cnt <= 3'd0;
                            state   <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                STOP: begin
                    if (clk_cnt == BIT_PERIOD - 1) begin
                        clk_cnt  <= {CNT_W{1'b0}};
                        rx_data  <= shift_reg;
                        rx_valid <= 1'b1;  // 脉冲一个周期
                        state    <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

