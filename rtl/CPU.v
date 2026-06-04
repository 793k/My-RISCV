module CPU (
    input wire clk,
    input wire rst_n
);

    wire [31:0] pc_addr;
    wire [31:0] jump_addr;
    wire [31:0] instr;
    wire [ 4:0] rd_addr;
    wire [31:0] rd_data;
    wire [ 5:0] instr_sel;
    wire [ 4:0] rs1_addr;
    wire [ 4:0] rs2_addr;
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] op1;
    wire [31:0] op2;
    wire [31:0] jump_op1;
    wire [31:0] jump_op2;
    wire        wr_en;
    wire        jump_en;

    pc_count #(
        .AW(32)
    ) u_pc_count (
        .clk      (clk),
        .rst_n    (rst_n),
        .jump_en  (jump_en),
        .jump_addr(jump_addr),
        .out_addr (pc_addr)
    );

    rom #(
        .AW(32)
    ) u_rom (
        .instr_addr(pc_addr),
        .instr_out (instr)
    );

    decode u_decode (
        .instr    (instr),
        .rd_addr  (rd_addr),
        .instr_sel(instr_sel),
        .rs1_addr (rs1_addr),
        .rs1_data (rs1_data),
        .rs2_addr (rs2_addr),
        .rs2_data (rs2_data),
        .op1      (op1),
        .op2      (op2),
        .jump_op1 (jump_op1),
        .jump_op2 (jump_op2)
    );

    regfile u_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_addr(rd_addr),
        .wr_data(rd_data),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    alu u_alu (
        .op1(op1),
        .op2(op2),
        .jump_op1(jump_op1),
        .jump_op2(jump_op2),
        .instr_sel(instr_sel),
        .rd_data(rd_data),
        .jump_addr(jump_addr),
        .jump_en(jump_en),
        .wr_en(wr_en)
    );

endmodule

