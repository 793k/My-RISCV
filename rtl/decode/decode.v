// ============================================================
// 指令译码模块
// ============================================================
// 功能：从指令中提取各字段，生成操作数与控制信号
//       支持 R/I/S/B/U/J 型指令的立即数扩展
// ============================================================

module decode (
    input  wire [31:0] instr,
    input  wire [31:0] pc,
    output wire [ 4:0] rd_idx,
    output wire [ 5:0] instr_sel,     // ALU 指令选择

    output wire [ 4:0] rs1_idx,
    input  wire [31:0] rs1_val,

    output wire [ 4:0] rs2_idx,
    input  wire [31:0] rs2_val,

    output reg  [31:0] alu_a,
    output reg  [31:0] alu_b,

    output reg  [31:0] jump_base,
    output reg  [31:0] jump_offs,

    output wire [ 4:0] op_type        // 操作类型选择（用于流水线前递判断）
);

    `include "decode_params.vh"

    // ============================================================
    // 内部信号
    // ============================================================

    wire [ 6:0] opcode;
    wire [ 2:0] funct3;
    wire [ 6:0] funct7;
    wire [31:0] imm_I;
    wire [ 4:0] shamt;
    wire [31:0] imm_branch;
    wire [31:0] imm_U;
    wire [31:0] imm_jal;
    wire [31:0] imm_jalr;

    // ============================================================
    // 指令字段提取（纯组合逻辑）
    // ============================================================

    assign rd_idx  = instr[11:7];
    assign rs1_idx = instr[19:15];
    assign rs2_idx = instr[24:20];
    assign funct3   = instr[14:12];
    assign funct7   = instr[31:25];
    assign opcode   = instr[6:0];

    // ============================================================
    // 立即数扩展
    // ============================================================

    assign imm_I = {{20{instr[31]}}, instr[31:20]};  // I-type

    assign shamt = instr[24:20];  // I-type shift amount

    assign imm_branch = {
        {19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'd0
    };  // B-type

    assign imm_U = {instr[31:12], 12'd0};  // U-type (lui / auipc)

    assign imm_jal = {
        {11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0
    };  // J-type (jal)

    assign imm_jalr = {{20{instr[31]}}, instr[31:20]};  // I-type (jalr)

    // ============================================================
    // 控制译码子模块实例化
    // ============================================================

    decode_ctrl u_decode_ctrl (
        .opcode   (opcode),
        .funct3   (funct3),
        .funct7   (funct7),
        .instr_sel(instr_sel),
        .op_type  (op_type)
    );

    // ============================================================
    // 操作数生成（组合逻辑）
    // ============================================================

    always @(*) begin
        // ALU 操作数 1：固定为 rs1 数据
        alu_a = rs1_val;

        // ALU 操作数 2：根据指令类型选择
        case (op_type)
            `op_sel_defaut : alu_b = rs2_val;
            `op_sel_I      : alu_b = imm_I;
            `op_sel_I_shamt: alu_b = {27'b0, shamt};
            `op_sel_R      : alu_b = rs2_val;
            `op_sel_branch : alu_b = rs2_val;
            `op_sel_U      : alu_b = imm_U;        // lui, auipc
            default        : alu_b = 32'd0;
        endcase

        // 跳转操作数 1：固定为当前 PC
        jump_base = pc;

        // 跳转操作数 2：根据跳转类型选择
        case (op_type)
            `op_sel_J_jal : jump_offs = imm_jal;
            `op_sel_J_jalr: jump_offs = imm_jalr;
            default       : jump_offs = imm_branch;
        endcase
    end

endmodule
