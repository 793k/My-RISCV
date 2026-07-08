// UART 控制器：寄存器接口 + TX/RX FIFO + 中断
// 寄存器：0x0=DATA  0x4=STATUS  0x8=CTRL  0xC=BAUD
// STATUS: bit[0]=tx_full [1]=rx_empty [2]=tx_busy [3]=rx_overrun
// CTRL:   bit[0]=en [1]=tx_ie [2]=rx_ie
module uart #(
    parameter CLK_HZ       = 50000000,
    parameter DEFAULT_BAUD = 115200,
    parameter FIFO_DEPTH   = 8
)(
    input  wire        clk_i,
    input  wire        rst_n_i,
    input  wire [31:0] addr_i,
    input  wire        wen_i,
    input  wire        ren_i,
    input  wire [31:0] wdata_i,
    output reg  [31:0] rdata_o,
    output wire        ready_o,
    output reg         txd_o,
    input  wire        rxd_i,
    output wire        irq_o,
    output wire [15:0] dbg_baud_div
);

    localparam DATA = 4'h0, STAT = 4'h4, CTRL = 4'h8, BAUD = 4'hC;

    localparam BAUD_DIV_DEFAULT = CLK_HZ / DEFAULT_BAUD;

    reg [15:0] baud_div;
    reg [2:0]  ctrl;
    reg        rx_overrun;
    wire       uart_en  = ctrl[0];
    wire       tx_ie    = ctrl[1];
    wire       rx_ie    = ctrl[2];

    // ── TX FIFO ──
    reg [7:0] tx_fifo [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH):0] tx_wr_ptr, tx_rd_ptr;
    wire tx_full  = (tx_wr_ptr[$clog2(FIFO_DEPTH)] != tx_rd_ptr[$clog2(FIFO_DEPTH)])
                 && (tx_wr_ptr[$clog2(FIFO_DEPTH)-1:0] == tx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]);
    wire tx_empty = (tx_wr_ptr == tx_rd_ptr);

    // ── RX FIFO ──
    reg [7:0] rx_fifo [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH):0] rx_wr_ptr, rx_rd_ptr;
    wire rx_full  = (rx_wr_ptr[$clog2(FIFO_DEPTH)] != rx_rd_ptr[$clog2(FIFO_DEPTH)])
                 && (rx_wr_ptr[$clog2(FIFO_DEPTH)-1:0] == rx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]);
    wire rx_empty = (rx_wr_ptr == rx_rd_ptr);

    // ── TX 引擎（8N1 帧，baud_div clocks/bit）──
    localparam TX_IDLE = 0, TX_START = 1, TX_DATA = 2, TX_STOP = 3;

    reg [1:0]  tx_state;
    reg [15:0] tx_clk_cnt;
    reg [2:0]  tx_bit_cnt;
    reg [7:0]  tx_shift;
    reg        tx_busy;
    reg        rx_overrun_set;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            tx_state   <= TX_IDLE;
            tx_clk_cnt <= 0;
            tx_bit_cnt <= 0;
            tx_shift   <= 0;
            tx_busy    <= 0;
            txd_o      <= 1'b1;
            tx_rd_ptr  <= 0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    txd_o <= 1'b1;
                    if (uart_en && !tx_empty) begin
                        tx_shift   <= tx_fifo[tx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]];
                        tx_rd_ptr  <= tx_rd_ptr + 1'b1;
                        tx_state   <= TX_START;
                        tx_busy    <= 1'b1;
                        tx_clk_cnt <= 0;
                    end else tx_busy <= 1'b0;
                end
                TX_START: begin
                    txd_o <= 1'b0;
                    if (tx_clk_cnt == baud_div - 1) begin
                        tx_clk_cnt <= 0;
                        tx_state   <= TX_DATA;
                    end else tx_clk_cnt <= tx_clk_cnt + 1'b1;
                end
                TX_DATA: begin
                    txd_o <= tx_shift[0];
                    if (tx_clk_cnt == baud_div - 1) begin
                        tx_clk_cnt <= 0;
                        tx_shift   <= {1'b0, tx_shift[7:1]};
                        if (tx_bit_cnt == 7) begin
                            tx_bit_cnt <= 0;
                            tx_state   <= TX_STOP;
                        end else tx_bit_cnt <= tx_bit_cnt + 1'b1;
                    end else tx_clk_cnt <= tx_clk_cnt + 1'b1;
                end
                TX_STOP: begin
                    txd_o <= 1'b1;
                    if (tx_clk_cnt == baud_div - 1) begin
                        tx_clk_cnt <= 0;
                        tx_state   <= TX_IDLE;
                        tx_busy    <= 1'b0;
                    end else tx_clk_cnt <= tx_clk_cnt + 1'b1;
                end
            endcase
        end
    end

    // ── RX 同步（两级触发器消亚稳态）──
    reg rxd_sync, rxd_dly;
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin rxd_sync <= 1'b1; rxd_dly <= 1'b1; end
        else         begin rxd_sync <= rxd_i;  rxd_dly <= rxd_sync; end
    end
    wire rx_start_det = rxd_dly && !rxd_sync;

    // ── RX 引擎（bit 中心采样）──
    localparam RX_IDLE = 0, RX_START = 1, RX_DATA = 2, RX_STOP = 3;

    reg [1:0]  rx_state;
    reg [15:0] rx_clk_cnt;
    reg [2:0]  rx_bit_cnt;
    reg [7:0]  rx_shift;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            rx_state   <= RX_IDLE;
            rx_clk_cnt <= 0;
            rx_bit_cnt <= 0;
            rx_shift   <= 0;
            rx_wr_ptr  <= 0;
        end else begin
            rx_overrun_set <= 1'b0;
            case (rx_state)
                RX_IDLE: begin
                    rx_clk_cnt <= 0;
                    if (uart_en && rx_start_det) rx_state <= RX_START;
                end
                RX_START: begin
                    if (rx_clk_cnt == (baud_div >> 1) - 1) begin
                        rx_clk_cnt <= 0;
                        rx_state <= !rxd_sync ? RX_DATA : RX_IDLE;
                    end else rx_clk_cnt <= rx_clk_cnt + 1'b1;
                end
                RX_DATA: begin
                    if (rx_clk_cnt == baud_div - 1) begin
                        rx_clk_cnt <= 0;
                        rx_shift   <= {rxd_sync, rx_shift[7:1]};
                        if (rx_bit_cnt == 7) begin
                            rx_bit_cnt <= 0;
                            rx_state   <= RX_STOP;
                        end else rx_bit_cnt <= rx_bit_cnt + 1'b1;
                    end else rx_clk_cnt <= rx_clk_cnt + 1'b1;
                end
                RX_STOP: begin
                    if (rx_clk_cnt == baud_div - 1) begin
                        rx_clk_cnt <= 0;
                        rx_state   <= RX_IDLE;
                        if (!rx_full) begin
                            rx_fifo[rx_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= rx_shift;
                            rx_wr_ptr <= rx_wr_ptr + 1'b1;
                        end else rx_overrun_set <= 1'b1;
                    end else rx_clk_cnt <= rx_clk_cnt + 1'b1;
                end
            endcase
        end
    end

    // ── 寄存器接口 ──
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            baud_div   <= BAUD_DIV_DEFAULT;
            ctrl       <= 3'b001;
            rx_overrun <= 1'b0;
            tx_wr_ptr  <= 0;
            rx_rd_ptr  <= 0;
            rdata_o    <= 0;
        end else begin
            if (rx_overrun_set)
                rx_overrun <= 1'b1;
            else if (wen_i && addr_i[3:0] == STAT)
                rx_overrun <= rx_overrun & ~wdata_i[3];

            if (wen_i) begin
                case (addr_i[3:0])
                    DATA: if (!tx_full) begin
                        tx_fifo[tx_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= wdata_i[7:0];
                        tx_wr_ptr <= tx_wr_ptr + 1'b1;
                    end
                    CTRL: ctrl     <= wdata_i[2:0];
                    BAUD: baud_div <= wdata_i[15:0];
                endcase
            end

            if (ren_i) begin
                case (addr_i[3:0])
                    DATA: begin
                        rdata_o <= {24'd0, rx_fifo[rx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]]};
                        if (!rx_empty) rx_rd_ptr <= rx_rd_ptr + 1'b1;
                    end
                    STAT: rdata_o <= {28'd0, rx_overrun, tx_busy, rx_empty, tx_full};
                    CTRL: rdata_o <= {29'd0, ctrl};
                    BAUD: rdata_o <= {16'd0, baud_div};
                    default: rdata_o <= 0;
                endcase
            end else rdata_o <= 0;
        end
    end

    assign ready_o = 1'b1;
    assign irq_o   = (tx_empty && !tx_busy && tx_ie) || (!rx_empty && rx_ie);
    assign dbg_baud_div = baud_div;

endmodule
