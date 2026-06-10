// ============================================================
// ALU 模块
// ============================================================
// 功能：根据 instr_sel 执行算术逻辑运算或分支跳转判断
//       输出运算结果、跳转地址、跳转使能及写回使能
// ============================================================

module alu (
    input  wire [31:0] alu_a,
    input  wire [31:0] alu_b,
    input  wire [31:0] jump_base,
    input  wire [31:0] jump_offs,
    input  wire [ 5:0] instr_sel,
    output reg  [31:0] result,
    output reg  [31:0] jump_target,
    output reg         jump_en,
    output reg         reg_wr_en
);

    `include "../decode/decode_params.vh"

    always @(*) begin
        result   = 32'd0;
        jump_target = 32'd0;
        jump_en   = 1'd0;
        reg_wr_en     = 1'd0;

        case (instr_sel)

            // --------------------------------------------------
            // R-type / I-type ALU
            // --------------------------------------------------
            `instr_sel_addi, `instr_sel_add: begin
                result = alu_a + alu_b;
                reg_wr_en   = 1'd1;
            end

            `instr_sel_slit, `instr_sel_slt: begin
                result = ($signed(alu_a) < $signed(alu_b)) ? 32'd1 : 32'd0;
                reg_wr_en   = 1'd1;
            end

            `instr_sel_slitu, `instr_sel_sltu: begin
                result = (alu_a < alu_b) ? 32'd1 : 32'd0;
                reg_wr_en   = 1'd1;
            end

            `instr_sel_xori, `instr_sel_xor: begin
                result = alu_a ^ alu_b;
                reg_wr_en   = 1'd1;
            end

            `instr_sel_ori, `instr_sel_or: begin
                result = alu_a | alu_b;
                reg_wr_en   = 1'd1;
            end

            `instr_sel_andi, `instr_sel_and: begin
                result = alu_a & alu_b;
                reg_wr_en   = 1'd1;
            end

            `instr_sel_slli, `instr_sel_sll: begin
                result = alu_a << alu_b[4:0];
                reg_wr_en   = 1'd1;
            end

            `instr_sel_srli, `instr_sel_srl: begin
                result = alu_a >> alu_b[4:0];
                reg_wr_en   = 1'd1;
            end

            `instr_sel_srai, `instr_sel_sra: begin
                result = $signed(alu_a) >>> alu_b[4:0];
                reg_wr_en   = 1'd1;
            end

            `instr_sel_sub: begin
                result = alu_a - alu_b;
                reg_wr_en   = 1'd1;
            end

            // --------------------------------------------------
            // B-type Branch
            // --------------------------------------------------
            `instr_sel_beq: begin
                if (alu_a == alu_b) begin
                    jump_target = jump_base + jump_offs;
                    jump_en   = 1'd1;
                end
            end

            `instr_sel_bne: begin
                if (alu_a != alu_b) begin
                    jump_target = jump_base + jump_offs;
                    jump_en   = 1'd1;
                end
            end

            `instr_sel_blt: begin
                if ($signed(alu_a) < $signed(alu_b)) begin
                    jump_target = jump_base + jump_offs;
                    jump_en   = 1'd1;
                end
            end

            `instr_sel_bge: begin
                if ($signed(alu_a) >= $signed(alu_b)) begin
                    jump_target = jump_base + jump_offs;
                    jump_en   = 1'd1;
                end
            end

            `instr_sel_bltu: begin
                if (alu_a < alu_b) begin
                    jump_target = jump_base + jump_offs;
                    jump_en   = 1'd1;
                end
            end

            `instr_sel_bgeu: begin
                if (alu_a >= alu_b) begin
                    jump_target = jump_base + jump_offs;
                    jump_en   = 1'd1;
                end
            end

            // --------------------------------------------------
            // U-type
            // --------------------------------------------------
            `instr_sel_lui: begin
                result = alu_b;
                reg_wr_en   = 1'd1;
            end

            `instr_sel_auipc: begin
                result = alu_b + jump_base;
                reg_wr_en   = 1'd1;
            end

            // --------------------------------------------------
            // J-type
            // --------------------------------------------------
            `instr_sel_jal: begin
                result   = jump_base + 4;
                reg_wr_en     = 1'd1;
                jump_en   = 1'd1;
                jump_target = jump_base + jump_offs;
            end

            `instr_sel_jalr: begin
                result   = jump_base + 4;
                reg_wr_en     = 1'd1;
                jump_en   = 1'd1;
                jump_target = (alu_a + jump_offs) & ~32'd3;  // rs1 + imm，四字节对齐
            end

            default: ;
        endcase
    end

endmodule
