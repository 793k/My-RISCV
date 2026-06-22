module uart_tx #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD_RATE = 115_200
) (
    input  wire clk,
    input  wire rst_n,

    input  wire [7:0] tx_data,
    input  wire tx_valid, // 高电平启动发送
    output reg  tx_ready, // 空闲时为 1，可接收新数据
    output reg  txd // UART 输出
);

    // 波特率分频计数：每 bit 采样周期 = CLK_HZ / BAUD_RATE
    localparam BIT_PERIOD = CLK_HZ / BAUD_RATE;
    localparam CNT_W = $clog2(BIT_PERIOD);

    // 状态机
    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [      1:0] state;
    reg [CNT_W-1:0] clk_cnt;
    reg [      2:0] bit_cnt;
    reg [      7:0] shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            clk_cnt   <= {CNT_W{1'b0}};
            bit_cnt   <= 3'd0;
            shift_reg <= 8'd0;
            txd       <= 1'b1;  // UART 空闲为高
            tx_ready  <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    txd      <= 1'b1;
                    tx_ready <= 1'b1;
                    if (tx_valid) begin
                        shift_reg <= tx_data;
                        state     <= START;
                        tx_ready  <= 1'b0;
                    end
                end

                START: begin
                    txd <= 1'b0;  // 起始位
                    if (clk_cnt == BIT_PERIOD - 1) begin
                        clk_cnt <= {CNT_W{1'b0}};
                        state   <= DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DATA: begin
                    txd <= shift_reg[0];  // LSB first
                    if (clk_cnt == BIT_PERIOD - 1) begin
                        clk_cnt <= {CNT_W{1'b0}};
                        if (bit_cnt == 3'd7) begin
                            bit_cnt <= 3'd0;
                            state   <= STOP;
                        end else begin
                            bit_cnt   <= bit_cnt + 1'b1;
                            shift_reg <= {1'b0, shift_reg[7:1]};
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                STOP: begin
                    txd <= 1'b1;  // 停止位
                    if (clk_cnt == BIT_PERIOD - 1) begin
                        clk_cnt  <= {CNT_W{1'b0}};
                        state    <= IDLE;
                        tx_ready <= 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

