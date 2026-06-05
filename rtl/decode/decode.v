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
    wire [ 4:0] op_sel;
    wire [31:0] imm_branch;
    wire [31:0] imm_U;
    wire [31:0] imm_jal;
    wire [31:0] imm_jalr;

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

    assign imm_I = {{20{instr[31]}}, instr[31:20]};  //I类

    assign shamt = instr[24:20];  //I类

    assign imm_branch = {
        {19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'd0
    };  //branch类立即数

    assign imm_U = {instr[31:12], 12'd0};  //U类立即数

    assign imm_jal = {{12{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    assign imm_jalr = {{20{instr[31]}}, instr[31:20]};  //jalr立即数

    // --------------------------------------------------
    // 控制译码实例化
    // --------------------------------------------------

    decode_ctrl u_decode_ctrl (
        .opcode   (opcode),
        .funct3   (funct3),
        .funct7   (funct7),
        .instr_sel(instr_sel),
        .op_sel  (op_sel)
    );

    // --------------------------------------------------
    // 操作数赋值
    // --------------------------------------------------

    always @(*) begin
        op1 = rs1_data;
        case (op_sel)
            `op_sel_defaut : op2 = rs2_data;
            `op_sel_I      : op2 = imm_I;
            `op_sel_I_shamt: op2 = {27'b0, shamt};
            `op_sel_R      : op2 = rs2_data;
            `op_sel_branch : op2 = rs2_data;
            `op_sel_U      : op2 = imm_U; //lui,auipc
            default        : op2 = 32'd0;
        endcase

        jump_op1 = pc_count;
        case (op_sel)  //跳转指令
            `op_sel_J_jal : jump_op2 = imm_jal;
            `op_sel_J_jalr: jump_op2 = imm_jalr;
            default       : jump_op2 = imm_branch;
        endcase

    end

endmodule

