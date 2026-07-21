// ============================================================
// ALU 模块
// ============================================================
// 功能：根据 instr_sel_i 执行算术逻辑运算或分支跳转判断
//       输出运算结果、跳转地址、跳转使能及写回使能
//
// 注意: trap 决策已移至 trap_ctrl 模块, ALU 不再判断 ecall/ebreak
//       MRET、CSR 读写仍在 ALU 中处理
// ============================================================

module alu (
    input  wire [31:0] alu_a_i,
    input  wire [31:0] alu_b_i,
    input  wire [31:0] jump_base_i,
    input  wire [31:0] jump_offs_i,
    input  wire [ 5:0] instr_sel_i,
    input  wire [11:0] csr_addr_i,
    input  wire [31:0] csr_rdata_i,
    input  wire [31:0] mepc_i,

    output reg  [31:0] result_o,
    output reg  [31:0] jump_target_o,
    output reg         jump_en_o,
    output reg         reg_wr_en_o,
    output reg         mem_wr_en_o,
    output reg  [31:0] mem_rd_idx_o,
    output reg  [31:0] mem_rd_val_o,

    output reg         mret_o,

    output reg         csr_we_o,
    output reg  [11:0] csr_waddr_o,
    output reg  [31:0] csr_wdata_o
);

    `include "../decode/decode_params.vh"


    always @(*) begin
        result_o      = 32'd0;
        jump_target_o = 32'd0;
        jump_en_o     = 1'd0;
        reg_wr_en_o   = 1'd0;
        mem_wr_en_o   = 1'd0;
        mem_rd_val_o  = 32'd0;
        mem_rd_idx_o  = 32'd0;
        mret_o        = 1'd0;
        csr_we_o      = 1'd0;
        csr_waddr_o   = 12'd0;
        csr_wdata_o   = 32'd0;
        case (instr_sel_i)

            // --------------------------------------------------
            // R-type / I-type ALU
            // --------------------------------------------------
            `instr_sel_addi, `instr_sel_add: begin
                result_o = alu_a_i + alu_b_i;
                reg_wr_en_o   = 1'd1;
            end

            `instr_sel_slit, `instr_sel_slt: begin
                result_o = ($signed(alu_a_i) < $signed(alu_b_i)) ? 32'd1 : 32'd0;
                reg_wr_en_o   = 1'd1;
            end

            `instr_sel_slitu, `instr_sel_sltu: begin
                result_o = (alu_a_i < alu_b_i) ? 32'd1 : 32'd0;
                reg_wr_en_o   = 1'd1;
            end

            `instr_sel_xori, `instr_sel_xor: begin
                result_o = alu_a_i ^ alu_b_i;
                reg_wr_en_o   = 1'd1;
            end

            `instr_sel_ori, `instr_sel_or: begin
                result_o = alu_a_i | alu_b_i;
                reg_wr_en_o   = 1'd1;
            end

            `instr_sel_andi, `instr_sel_and: begin
                result_o = alu_a_i & alu_b_i;
                reg_wr_en_o   = 1'd1;
            end

            `instr_sel_slli, `instr_sel_sll: begin
                result_o = alu_a_i << alu_b_i[4:0];
                reg_wr_en_o   = 1'd1;
            end

            `instr_sel_srli, `instr_sel_srl: begin
                result_o = alu_a_i >> alu_b_i[4:0];
                reg_wr_en_o   = 1'd1;
            end

            `instr_sel_srai, `instr_sel_sra: begin
                result_o = $signed(alu_a_i) >>> alu_b_i[4:0];
                reg_wr_en_o   = 1'd1;
            end

            `instr_sel_sub: begin
                result_o = alu_a_i - alu_b_i;
                reg_wr_en_o   = 1'd1;
            end

            // --------------------------------------------------
            // B-type Branch
            // --------------------------------------------------
            `instr_sel_beq: begin
                if (alu_a_i == alu_b_i) begin
                    jump_target_o = jump_base_i + jump_offs_i;
                    jump_en_o   = 1'd1;
                end
            end

            `instr_sel_bne: begin
                if (alu_a_i != alu_b_i) begin
                    jump_target_o = jump_base_i + jump_offs_i;
                    jump_en_o   = 1'd1;
                end
            end

            `instr_sel_blt: begin
                if ($signed(alu_a_i) < $signed(alu_b_i)) begin
                    jump_target_o = jump_base_i + jump_offs_i;
                    jump_en_o   = 1'd1;
                end
            end

            `instr_sel_bge: begin
                if ($signed(alu_a_i) >= $signed(alu_b_i)) begin
                    jump_target_o = jump_base_i + jump_offs_i;
                    jump_en_o   = 1'd1;
                end
            end

            `instr_sel_bltu: begin
                if (alu_a_i < alu_b_i) begin
                    jump_target_o = jump_base_i + jump_offs_i;
                    jump_en_o   = 1'd1;
                end
            end

            `instr_sel_bgeu: begin
                if (alu_a_i >= alu_b_i) begin
                    jump_target_o = jump_base_i + jump_offs_i;
                    jump_en_o   = 1'd1;
                end
            end

            // --------------------------------------------------
            // U-type
            // --------------------------------------------------
            `instr_sel_lui: begin
                result_o = alu_b_i;
                reg_wr_en_o   = 1'd1;
            end

            `instr_sel_auipc: begin
                result_o = alu_b_i + jump_base_i;
                reg_wr_en_o   = 1'd1;
            end

            // --------------------------------------------------
            // J-type
            // --------------------------------------------------
            `instr_sel_jal: begin
                result_o   = jump_base_i + 4;
                reg_wr_en_o     = 1'd1;
                jump_en_o   = 1'd1;
                jump_target_o = jump_base_i + jump_offs_i;
            end

            `instr_sel_jalr: begin
                result_o   = jump_base_i + 4;
                reg_wr_en_o     = 1'd1;
                jump_en_o   = 1'd1;
                jump_target_o = (alu_a_i + jump_offs_i) & ~32'd3;
            end

            `instr_sel_sb,`instr_sel_sh,`instr_sel_sw: begin
                mem_wr_en_o  = 1'd1;
                mem_rd_val_o = alu_b_i;
                mem_rd_idx_o = alu_a_i+jump_offs_i;
            end
            `instr_sel_lb,`instr_sel_lbu,`instr_sel_lh,`instr_sel_lhu,`instr_sel_lw: begin
                mem_wr_en_o  = 1'd0;
                reg_wr_en_o = 1'd1;
                mem_rd_val_o = alu_b_i;
                mem_rd_idx_o = alu_a_i+jump_offs_i;
            end

            // --------------------------------------------------
            // SYSTEM: ecall / ebreak / fence (NOP, trap 由 trap_ctrl 管)
            // --------------------------------------------------
            `instr_sel_ecall, `instr_sel_ebreak, `instr_sel_fence: begin
            end

            // --------------------------------------------------
            // SYSTEM: MRET
            // --------------------------------------------------
            `instr_sel_mret: begin
                mret_o = 1'd1;
                jump_target_o = mepc_i;
                jump_en_o     = 1'd1;
            end

            // --------------------------------------------------
            // SYSTEM: CSR 读写
            // --------------------------------------------------
            `instr_sel_csrrw, `instr_sel_csrrwi: begin
                result_o      = csr_rdata_i;
                reg_wr_en_o   = 1'd1;
                csr_we_o      = 1'd1;
                csr_waddr_o   = csr_addr_i;
                csr_wdata_o   = alu_a_i;
            end

            `instr_sel_csrrs, `instr_sel_csrrsi: begin
                result_o      = csr_rdata_i;
                reg_wr_en_o   = 1'd1;
                csr_we_o      = 1'd1;
                csr_waddr_o   = csr_addr_i;
                csr_wdata_o   = csr_rdata_i | alu_a_i;
            end

            `instr_sel_csrrc, `instr_sel_csrrci: begin
                result_o      = csr_rdata_i;
                reg_wr_en_o   = 1'd1;
                csr_we_o      = 1'd1;
                csr_waddr_o   = csr_addr_i;
                csr_wdata_o   = csr_rdata_i & ~alu_a_i;
            end

            default: ;
        endcase
    end

endmodule
