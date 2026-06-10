// ============================================================
// ALU 模块
// ============================================================
// 功能：根据 instr_sel 执行算术逻辑运算或分支跳转判断
//       输出运算结果、跳转地址、跳转使能及写回使能
// ============================================================

module alu (
    input  wire [31:0] op1,
    input  wire [31:0] op2,
    input  wire [31:0] jump_op1,
    input  wire [31:0] jump_op2,
    input  wire [ 5:0] instr_sel,
    output reg  [31:0] rd_data,
    output reg  [31:0] jump_addr,
    output reg         jump_en,
    output reg         wr_en
);

    `include "../decode/decode_params.vh"

    always @(*) begin
        rd_data   = 32'd0;
        jump_addr = 32'd0;
        jump_en   = 1'd0;
        wr_en     = 1'd0;

        case (instr_sel)

            // --------------------------------------------------
            // R-type / I-type ALU
            // --------------------------------------------------
            `instr_sel_addi, `instr_sel_add: begin
                rd_data = op1 + op2;
                wr_en   = 1'd1;
            end

            `instr_sel_slit, `instr_sel_slt: begin
                rd_data = ($signed(op1) < $signed(op2)) ? 32'd1 : 32'd0;
                wr_en   = 1'd1;
            end

            `instr_sel_slitu, `instr_sel_sltu: begin
                rd_data = (op1 < op2) ? 32'd1 : 32'd0;
                wr_en   = 1'd1;
            end

            `instr_sel_xori, `instr_sel_xor: begin
                rd_data = op1 ^ op2;
                wr_en   = 1'd1;
            end

            `instr_sel_ori, `instr_sel_or: begin
                rd_data = op1 | op2;
                wr_en   = 1'd1;
            end

            `instr_sel_andi, `instr_sel_and: begin
                rd_data = op1 & op2;
                wr_en   = 1'd1;
            end

            `instr_sel_slli, `instr_sel_sll: begin
                rd_data = op1 << op2[4:0];
                wr_en   = 1'd1;
            end

            `instr_sel_srli, `instr_sel_srl: begin
                rd_data = op1 >> op2[4:0];
                wr_en   = 1'd1;
            end

            `instr_sel_srai, `instr_sel_sra: begin
                rd_data = $signed(op1) >>> op2[4:0];
                wr_en   = 1'd1;
            end

            `instr_sel_sub: begin
                rd_data = op1 - op2;
                wr_en   = 1'd1;
            end

            // --------------------------------------------------
            // B-type Branch
            // --------------------------------------------------
            `instr_sel_beq: begin
                if (op1 == op2) begin
                    jump_addr = jump_op1 + jump_op2;
                    jump_en   = 1'd1;
                end
            end

            `instr_sel_bne: begin
                if (op1 != op2) begin
                    jump_addr = jump_op1 + jump_op2;
                    jump_en   = 1'd1;
                end
            end

            `instr_sel_blt: begin
                if ($signed(op1) < $signed(op2)) begin
                    jump_addr = jump_op1 + jump_op2;
                    jump_en   = 1'd1;
                end
            end

            `instr_sel_bge: begin
                if ($signed(op1) >= $signed(op2)) begin
                    jump_addr = jump_op1 + jump_op2;
                    jump_en   = 1'd1;
                end
            end

            `instr_sel_bltu: begin
                if (op1 < op2) begin
                    jump_addr = jump_op1 + jump_op2;
                    jump_en   = 1'd1;
                end
            end

            `instr_sel_bgeu: begin
                if (op1 >= op2) begin
                    jump_addr = jump_op1 + jump_op2;
                    jump_en   = 1'd1;
                end
            end

            // --------------------------------------------------
            // U-type
            // --------------------------------------------------
            `instr_sel_lui: begin
                rd_data = op2;
                wr_en   = 1'd1;
            end

            `instr_sel_auipc: begin
                rd_data = op2 + jump_op1;
                wr_en   = 1'd1;
            end

            // --------------------------------------------------
            // J-type
            // --------------------------------------------------
            `instr_sel_jal: begin
                rd_data   = jump_op1 + 4;
                wr_en     = 1'd1;
                jump_en   = 1'd1;
                jump_addr = jump_op1 + jump_op2;
            end

            `instr_sel_jalr: begin
                rd_data   = jump_op1 + 4;
                wr_en     = 1'd1;
                jump_en   = 1'd1;
                jump_addr = (op1 + jump_op2) & ~32'd3;  // rs1 + imm，四字节对齐
            end

            default: ;
        endcase
    end

endmodule
