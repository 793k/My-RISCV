// =============================================================================
// CSR 寄存器堆 — 管家账本 + 出事自动记账 + MRET 自动恢复
// =============================================================================

module csr_regfile (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        csr_we_i,
    input  wire [11:0] csr_addr_i,
    input  wire [31:0] csr_wdata_i,
    output wire [31:0] csr_rdata_o,

    input  wire        trap_taken_i,
    input  wire [31:0] trap_pc_i,
    input  wire [31:0] trap_cause_i,
    input  wire [31:0] trap_tval_i,

    input  wire        mret_i,

    input  wire        ext_irq_i,        // 外部中断线 (UART)

    output wire [31:0] mtvec_o,
    output wire [31:0] mepc_o,
    output wire        mstatus_mie_o,    // 中断总开关, 给 trap_ctrl
    output wire [31:0] mie_o,            // 中断分开关, 给 trap_ctrl
    output wire [31:0] mip_o             // 中断挂起, 给 trap_ctrl
);

    reg [31:0] mstatus;
    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mtval;
    reg [31:0] mtvec;
    reg [31:0] mscratch;
    reg [31:0] mie;
    reg [31:0] mip_sw;      // 软件可写的 mip 位 (bit3=MSIP)

    localparam CSR_MSTATUS   = 12'h300;
    localparam CSR_MISA      = 12'h301;
    localparam CSR_MIE       = 12'h304;
    localparam CSR_MTVEC     = 12'h305;
    localparam CSR_MSCRATCH  = 12'h340;
    localparam CSR_MEPC      = 12'h341;
    localparam CSR_MCAUSE    = 12'h342;
    localparam CSR_MTVAL     = 12'h343;
    localparam CSR_MIP       = 12'h344;
    localparam CSR_MVENDORID = 12'hF11;
    localparam CSR_MARCHID   = 12'hF12;
    localparam CSR_MIMPID    = 12'hF13;
    localparam CSR_MHARTID   = 12'hF14;

    // === mip 硬件直读: 中断挂起 = 硬件信号 | 软件写 ===
    wire [31:0] mip_hw;
    assign mip_hw = {19'd0, ext_irq_i, 7'd0, mip_sw[3], 3'd0};

    assign csr_rdata_o = csr_rdata_comb(csr_addr_i);

    function [31:0] csr_rdata_comb(input [11:0] addr);
        case (addr)
            CSR_MSTATUS:   csr_rdata_comb = mstatus;
            CSR_MISA:      csr_rdata_comb = 32'h40000100;
            CSR_MIE:       csr_rdata_comb = mie;
            CSR_MTVEC:     csr_rdata_comb = mtvec;
            CSR_MSCRATCH:  csr_rdata_comb = mscratch;
            CSR_MEPC:      csr_rdata_comb = mepc;
            CSR_MCAUSE:    csr_rdata_comb = mcause;
            CSR_MTVAL:     csr_rdata_comb = mtval;
            CSR_MIP:       csr_rdata_comb = mip_hw;
            CSR_MVENDORID: csr_rdata_comb = 32'h00000000;
            CSR_MARCHID:   csr_rdata_comb = 32'h00000001;
            CSR_MIMPID:    csr_rdata_comb = 32'h00000001;
            CSR_MHARTID:   csr_rdata_comb = 32'h00000000;
            default:       csr_rdata_comb = 32'h00000000;
        endcase
    endfunction

    assign mtvec_o       = mtvec;
    assign mepc_o        = mepc;
    assign mstatus_mie_o = mstatus[3];
    assign mie_o         = mie;
    assign mip_o         = mip_hw;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus  <= 32'h00001800;
            mepc     <= 32'h00000000;
            mcause   <= 32'h00000000;
            mtval    <= 32'h00000000;
            mtvec    <= 32'h00000000;
            mscratch <= 32'h00000000;
            mie      <= 32'h00000000;
            mip_sw   <= 32'h00000000;

        end else if (trap_taken_i) begin
            mstatus[12:11] <= 2'b11;
            mstatus[7]     <= mstatus[3];
            mstatus[3]     <= 1'b0;
            mepc           <= trap_pc_i;
            mcause         <= trap_cause_i;
            mtval          <= trap_tval_i;

        end else if (mret_i) begin
            mstatus[3]     <= mstatus[7];
            mstatus[7]     <= 1'b1;
            mstatus[12:11] <= 2'b00;

        end else if (csr_we_i) begin
            case (csr_addr_i)
                CSR_MSTATUS:  mstatus  <= csr_wdata_i;
                CSR_MEPC:     mepc     <= csr_wdata_i;
                CSR_MCAUSE:   mcause   <= csr_wdata_i;
                CSR_MTVAL:    mtval    <= csr_wdata_i;
                CSR_MTVEC:    mtvec    <= csr_wdata_i;
                CSR_MSCRATCH: mscratch <= csr_wdata_i;
                CSR_MIE:      mie      <= csr_wdata_i;
                CSR_MIP:      mip_sw   <= csr_wdata_i;  // 只软件可写位生效
                default: ;
            endcase
        end
    end

endmodule
