// 32bit架构，写法非标，学习为主

module decode (
    input  wire [31:0] instr,
    input  wire [31:0] pc_count,
    output wire [ 4:0] rd_addr,
    output wire [ 5:0] instr_sel, // 指令选项

    output wire [ 4:0] rs1_addr,
    input  wire [31:0] rs1_data,

    output wire [ 4:0] rs2_addr,
    input  wire [31:0] rs2_data,

    output reg  [31:0] op1,
    output reg  [31:0] op2,

    output reg  [31:0] jump_op1,
    output reg  [31:0] jump_op2
);

    `include "decode_params.vh"

    // 内部信号
    wire [ 6:0] opcode;
    wire [ 2:0] funct3;
    wire [ 6:0] funct7;
    wire [31:0] imm_I;
    wire [ 4:0] shamt;
    wire [ 4:0] op2_sel;

    // --------------------------------------------------
    // 字段提取（纯组合逻辑）
    // --------------------------------------------------

    assign rd_addr = instr[11:7];

    assign rs1_addr = instr[19:15];

    assign rs2_addr = instr[24:20];

    assign funct3 = instr[14:12];

    assign funct7 = instr[31:25];

    assign opcode = instr[6:0];

    // --------------------------------------------------
    // 立即数拆解
    // --------------------------------------------------

    assign imm_I = {{20{instr[31]}}, instr[31:20]};

    assign shamt = instr[24:20];

    assign imm_branch = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'd0};

    // --------------------------------------------------
    // 控制译码实例化
    // --------------------------------------------------

    decode_ctrl u_decode_ctrl (
        .opcode   (opcode),
        .funct3   (funct3),
        .funct7   (funct7),
        .instr_sel(instr_sel),
        .op2_sel  (op2_sel)
    );

    // --------------------------------------------------
    // 操作数赋值
    // --------------------------------------------------

    always @(*) begin
        op1 = rs1_data;
        case (op2_sel)
            `op2_sel_defaut : op2 = rs2_data;
            `op2_sel_I      : op2 = imm_I;
            `op2_sel_I_shamt: op2 = {27'b0, shamt};
            `op2_sel_R      : op2 = rs2_data;
            `op2_sel_branch : op2 = rs2_data;
            default         : op2 = imm_I;
        endcase

        jump_op1 = pc_count;
        jump_op2 = imm_branch;
    end

endmodule

