module decode (
    input  wire [31:0] instr_i,
    input  wire [31:0] pc_i,
    output wire [ 4:0] rd_idx_o,
    output wire [ 5:0] instr_sel_o,

    output wire [ 4:0] rs1_idx_o,
    input  wire [31:0] rs1_val_i,

    output wire [ 4:0] rs2_idx_o,
    input  wire [31:0] rs2_val_i,

    output reg  [31:0] alu_a_o,
    output reg  [31:0] alu_b_o,

    output reg  [31:0] jump_base_o,
    output reg  [31:0] jump_offs_o,

    output wire [4:0] op_type_o
);

    `include "decode_params.vh"

    wire [ 6:0] opcode  = instr_i[ 6: 0];
    wire [ 2:0] funct3  = instr_i[14:12];
    wire [ 6:0] funct7  = instr_i[31:25];
    wire [ 4:0] shamt   = instr_i[24:20];
    wire [31:0] imm_I   = {{20{instr_i[31]}}, instr_i[31:20]};
    wire [31:0] imm_L   = {{20{instr_i[31]}}, instr_i[31:20]};
    wire [31:0] imm_jalr= {{20{instr_i[31]}}, instr_i[31:20]};
    wire [31:0] imm_U   = {instr_i[31:12], 12'd0};
    wire [31:0] imm_S   = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
    wire [31:0] imm_branch = {
        {19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'd0
    };
    wire [31:0] imm_jal = {
        {11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0
    };

    assign rd_idx_o  = instr_i[11:7];
    assign rs1_idx_o = instr_i[19:15];
    assign rs2_idx_o = instr_i[24:20];

    decode_ctrl u_decode_ctrl (
        .opcode   (opcode),
        .funct3   (funct3),
        .funct7   (funct7),
        .instr_sel(instr_sel_o),
        .op_type  (op_type_o)
    );

    always @(*) begin
        alu_a_o = rs1_val_i;

        case (op_type_o)
            `op_sel_I      : alu_b_o = imm_I;
            `op_sel_I_shamt: alu_b_o = {27'b0, shamt};
            `op_sel_R      : alu_b_o = rs2_val_i;
            `op_sel_branch : alu_b_o = rs2_val_i;
            `op_sel_U      : alu_b_o = imm_U;
            default        : alu_b_o = rs2_val_i;
        endcase

        jump_base_o = pc_i;

        case (op_type_o)
            `op_sel_J_jal : jump_offs_o = imm_jal;
            `op_sel_J_jalr: jump_offs_o = imm_jalr;
            `op_sel_S     : jump_offs_o = imm_S;
            `op_sel_L     : jump_offs_o = imm_L;
            default       : jump_offs_o = imm_branch;
        endcase
    end

endmodule
