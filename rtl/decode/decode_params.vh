// ============================================================
// 解码模块参数定义
// ============================================================
// 说明：32bit 架构，RISC-V RV32I 指令集相关常量定义
// ============================================================
// ============================================================
// 操作码 (opcode)
// ============================================================

`define opcode_I        7'b0010011   // I-type ALU
`define opcode_R        7'b0110011   // R-type ALU
`define opcode_BRANCH   7'b1100011   // B-type Branch
`define opcode_U_lui    7'b0110111   // U-type LUI
`define opcode_U_auipc  7'b0010111   // U-type AUIPC
`define opcode_J_jal    7'b1101111   // J-type JAL
`define opcode_J_jalr   7'b1100111   // I-type JALR
`define opcode_L        7'b0000011   // J-type Store
`define opcode_S        7'b0100011   // I-type Load
`define opcode_SYSTEM   7'b1110011   // SYSTEM (CSR / trap / MRET)
`define opcode_FENCE    7'b0001111   // FENCE / FENCE.I
// ============================================================
// 操作类型选择 (op_sel)
// ============================================================

`define op_sel_defaut    5'd0        // 默认值
`define op_sel_I         5'd1        // I-type (imm_I)
`define op_sel_I_shamt   5'd2        // I-type shift (imm_shamt)
`define op_sel_R         5'd3        // R-type (rs2)
`define op_sel_branch    5'd4        // B-type (rs2)
`define op_sel_U         5'd5        // U-type (imm_U)
`define op_sel_J_jal     5'd6        // J-type JAL (imm_jal)
`define op_sel_J_jalr    5'd7        // I-type JALR (imm_jalr)
`define op_sel_S         5'd8        // S-type Store
`define op_sel_L         5'd9        // I-type Load
`define op_sel_SYSTEM    5'd10       // SYSTEM (CSR/ECALL/EBREAK/MRET)
`define op_sel_SYSTEM_i  5'd11       // SYSTEM CSR 立即数版 (rs1 = uimm)
// ============================================================
// funct3 常量 - I-type
// ============================================================

`define funct3_I_addi      3'b000
`define funct3_I_slit      3'b010
`define funct3_I_slitu     3'b011
`define funct3_I_xori      3'b100
`define funct3_I_ori       3'b110
`define funct3_I_andi      3'b111
`define funct3_I_slli      3'b001
`define funct3_I_srli_srai 3'b101

// ============================================================
// funct3 常量 - R-type
// ============================================================

`define funct3_R_add_sub 3'b000
`define funct3_R_sll     3'b001
`define funct3_R_slt     3'b010
`define funct3_R_sltu    3'b011
`define funct3_R_xor     3'b100
`define funct3_R_or      3'b110
`define funct3_R_and     3'b111
`define funct3_R_srl_sra 3'b101

// ============================================================
// funct3 常量 - B-type
// ============================================================

`define funct3_BCH_beq  3'b000
`define funct3_BCH_bne  3'b001
`define funct3_BCH_blt  3'b100
`define funct3_BCH_bge  3'b101
`define funct3_BCH_bltu 3'b110
`define funct3_BCH_bgeu 3'b111

`define funct3_Store_sb  3'b000
`define funct3_Store_sh  3'b001
`define funct3_Store_sw  3'b010

`define funct3_Load_lb  3'b000
`define funct3_Load_lh  3'b001
`define funct3_Load_lw  3'b010
`define funct3_Load_lbu 3'b100
`define funct3_Load_lhu 3'b101

// ============================================================
// instr_sel 常量 - I-type ALU
// ============================================================

`define instr_sel_addi  6'd0
`define instr_sel_slit  6'd1
`define instr_sel_slitu 6'd2
`define instr_sel_xori  6'd3
`define instr_sel_ori   6'd4
`define instr_sel_andi  6'd5
`define instr_sel_slli  6'd6
`define instr_sel_srli  6'd7
`define instr_sel_srai  6'd8

// ============================================================
// instr_sel 常量 - R-type ALU
// ============================================================

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

// ============================================================
// instr_sel 常量 - B-type Branch
// ============================================================

`define instr_sel_beq  6'd19
`define instr_sel_bne  6'd20
`define instr_sel_blt  6'd21
`define instr_sel_bge  6'd22
`define instr_sel_bltu 6'd23
`define instr_sel_bgeu 6'd24

// ============================================================
// instr_sel 常量 - U-type / J-type
// ============================================================

`define instr_sel_lui   6'd25
`define instr_sel_auipc 6'd26
`define instr_sel_jal   6'd27
`define instr_sel_jalr  6'd28

`define instr_sel_lb   6'd29
`define instr_sel_lh   6'd30
`define instr_sel_lw   6'd31
`define instr_sel_lbu  6'd32
`define instr_sel_lhu  6'd33

`define instr_sel_sb   6'd34
`define instr_sel_sh   6'd35
`define instr_sel_sw   6'd36

`define instr_sel_ecall   6'd37
`define instr_sel_ebreak  6'd38
`define instr_sel_csrrw   6'd39
`define instr_sel_csrrs   6'd40
`define instr_sel_csrrc   6'd41
`define instr_sel_csrrwi  6'd42
`define instr_sel_csrrsi  6'd43
`define instr_sel_csrrci  6'd44
`define instr_sel_mret    6'd45
`define instr_sel_fence   6'd46

// ============================================================
// funct3 常量 - SYSTEM (CSR / trap)
// ============================================================

`define funct3_SYS_ecall_ebreak_mret 3'b000
`define funct3_SYS_csrrw             3'b001
`define funct3_SYS_csrrs             3'b010
`define funct3_SYS_csrrc             3'b011
`define funct3_SYS_csrrwi            3'b101
`define funct3_SYS_csrrsi            3'b110
`define funct3_SYS_csrrci            3'b111