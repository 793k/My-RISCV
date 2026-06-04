// 解码模块参数定义
// 32bit架构，写法非标，学习为主

// --------------------------------------------------
// 操作码常量
// --------------------------------------------------
`define opcode_I      7'b0010011
`define opcode_R      7'b0110011
`define opcode_BRANCH 7'b1100011


`define op2_sel_defaut  5'd0
`define op2_sel_I       5'd1
`define op2_sel_I_shamt 5'd2
`define op2_sel_R       5'd3
`define op2_sel_branch  5'd4
// --------------------------------------------------
// funct3 常量 - I-type
// --------------------------------------------------
`define funct3_I_addi      3'b000
`define funct3_I_slit      3'b010
`define funct3_I_slitu     3'b011
`define funct3_I_xori      3'b100
`define funct3_I_ori       3'b110
`define funct3_I_andi      3'b111
`define funct3_I_slli      3'b001
`define funct3_I_srli_srai 3'b101

// --------------------------------------------------
// instr_sel 常量 - I-type
// --------------------------------------------------
`define instr_sel_addi  6'd0
`define instr_sel_slit  6'd1
`define instr_sel_slitu 6'd2
`define instr_sel_xori  6'd3
`define instr_sel_ori   6'd4
`define instr_sel_andi  6'd5
`define instr_sel_slli  6'd6
`define instr_sel_srli  6'd7
`define instr_sel_srai  6'd8

// --------------------------------------------------
// funct3 常量 - R-type
// --------------------------------------------------
`define funct3_R_add_sub 3'b000
`define funct3_R_sll     3'b001
`define funct3_R_slt     3'b010
`define funct3_R_sltu    3'b011
`define funct3_R_xor     3'b100
`define funct3_R_or      3'b110
`define funct3_R_and     3'b111
`define funct3_R_srl_sra 3'b101

// --------------------------------------------------
// instr_sel 常量 - R-type
// --------------------------------------------------
`define instr_sel_add  6'd9
`define instr_sel_sub  6'd10
`define instr_sel_sll  6'd11
`define instr_sel_slt  6'd12
`define instr_sel_sltu 6'd13
`define instr_sel_xor  6'd14
`define instr_sel_or   6'd15
`define instr_sel_and  6'd16
`define instr_sel_srl  6'd17
`define instr_sel_sra  6'd18

// --------------------------------------------------
// funct3 常量 - Bch-type
// --------------------------------------------------
`define funct3_BCH_beq  3'b000
`define funct3_BCH_bne  3'b001
`define funct3_BCH_blt  3'b100
`define funct3_BCH_bge  3'b101
`define funct3_BCH_bltu 3'b110
`define funct3_BCH_bgeu 3'b111

// --------------------------------------------------
// instr_sel 常量 - Bch-type
// --------------------------------------------------
`define instr_sel_beq  6'd19
`define instr_sel_bne  6'd20
`define instr_sel_blt  6'd21
`define instr_sel_bge  6'd22
`define instr_sel_bltu 6'd23
`define instr_sel_bgeu 6'd24
