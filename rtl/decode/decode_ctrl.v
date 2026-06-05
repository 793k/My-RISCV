// 控制译码子模块
// 输入 opcode/funct3/funct7，输出 instr_sel 和 op 选择信号

module decode_ctrl (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg  [5:0] instr_sel,
    output reg  [4:0] op_sel
);

    `include "decode_params.vh"

    always @(*) begin

        // instr_sel = 6'd0;
        op_sel = `op_sel_defaut;

        case (opcode)
            `opcode_I          : begin
                op_sel = `op_sel_I;
                case (funct3)
                    `funct3_I_addi     : instr_sel = `instr_sel_addi;
                    `funct3_I_slit     : instr_sel = `instr_sel_slit;
                    `funct3_I_slitu    : instr_sel = `instr_sel_slitu;
                    `funct3_I_xori     : instr_sel = `instr_sel_xori;
                    `funct3_I_ori      : instr_sel = `instr_sel_ori;
                    `funct3_I_andi     : instr_sel = `instr_sel_andi;
                    `funct3_I_slli     :
                        begin
                            instr_sel = `instr_sel_slli;
                            op_sel = `op_sel_I_shamt;
                        end
                    `funct3_I_srli_srai: begin
                        if (funct7 == 7'b0000000) begin
                            instr_sel = `instr_sel_srli;
                        end else begin
                            instr_sel = `instr_sel_srai;
                        end
                        op_sel = `op_sel_I_shamt;
                    end
                    default            : ;
                endcase
            end

            `opcode_R: begin
                op_sel = `op_sel_R;
                case (funct3)
                    `funct3_R_add_sub: begin
                        if (funct7 == 7'b0000000) begin
                            instr_sel = `instr_sel_add;
                        end else begin
                            instr_sel = `instr_sel_sub;
                        end
                    end
                    `funct3_R_sll    : instr_sel = `instr_sel_sll;
                    `funct3_R_slt    : instr_sel = `instr_sel_slt;
                    `funct3_R_sltu   : instr_sel = `instr_sel_sltu;
                    `funct3_R_xor    : instr_sel = `instr_sel_xor;
                    `funct3_R_or     : instr_sel = `instr_sel_or;
                    `funct3_R_and    : instr_sel = `instr_sel_and;
                    `funct3_R_srl_sra: begin
                        if (funct7 == 7'b0000000) begin
                            instr_sel = `instr_sel_srl;
                        end else begin
                            instr_sel = `instr_sel_sra;
                        end
                    end
                    default          : ;
                endcase
            end

            `opcode_BRANCH: begin
                op_sel = `op_sel_branch;
                case (funct3)
                    `funct3_BCH_beq : instr_sel = `instr_sel_beq;
                    `funct3_BCH_bne : instr_sel = `instr_sel_bne;
                    `funct3_BCH_blt : instr_sel = `instr_sel_blt;
                    `funct3_BCH_bge : instr_sel = `instr_sel_bge;
                    `funct3_BCH_bltu: instr_sel = `instr_sel_bltu;
                    `funct3_BCH_bgeu: instr_sel = `instr_sel_bgeu;
                    default         : ;
                endcase
            end

            `opcode_U_lui: begin
                op_sel = `op_sel_U;
                instr_sel = `instr_sel_lui;
            end

            `opcode_U_auipc: begin
                op_sel = `op_sel_U;
                instr_sel = `instr_sel_auipc;
            end

            `opcode_J_jal: begin
                op_sel = `op_sel_J_jal;
                instr_sel = `instr_sel_jal;
            end

            `opcode_J_jalr: begin
                op_sel = `op_sel_J_jalr;
                instr_sel = `instr_sel_jalr;
            end
            default: ;
        endcase
    end

endmodule

