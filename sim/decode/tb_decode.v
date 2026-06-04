`timescale 1ns / 1ps

module tb_decode;

    reg  [31:0] instr;
    reg  [31:0] rs1_data;
    reg  [31:0] rs2_data;

    wire [ 4:0] rd_addr;
    wire [ 5:0] instr_sel;
    wire [ 4:0] rs1_addr;
    wire [ 4:0] rs2_addr;
    wire [31:0] op1;
    wire [31:0] op2;
    wire [31:0] jump_op1;
    wire [31:0] jump_op2;

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

    // 辅助任务：打印结果
    task automatic check;
        input [255:0] name;
        input [5:0] exp_sel;
        input [31:0] exp_op1;
        input [31:0] exp_op2;
        begin
            #1;
            $display(
                "%-12s | instr_sel = %2d | op1 = %h | op2 = %h | rd = %d | rs1 = %d | rs2 = %d",
                name, instr_sel, op1, op2, rd_addr, rs1_addr, rs2_addr);
            if (instr_sel !== exp_sel)
                $display("  ERROR: instr_sel expect %d, got %d", exp_sel, instr_sel);
            if (op1 !== exp_op1) $display("  ERROR: op1 expect %h, got %h", exp_op1, op1);
            if (op2 !== exp_op2) $display("  ERROR: op2 expect %h, got %h", exp_op2, op2);
        end
    endtask

    initial begin
        $display("========================================");
        $display("Testbench for decode module");
        $display("========================================");

        rs1_data = 32'hAAAA_AAAA;
        rs2_data = 32'h5555_5555;

        // ---------- I-type ----------
        // addi x3, x1, 10
        // imm = 10, rs1 = 1, funct3 = 000, rd = 3, opcode = 0010011
        instr = {20'd10, 5'd1, 3'b000, 5'd3, 7'b0010011};
        check("addi", 6'd0, rs1_data, 32'd10);

        // slit x4, x2, -5 (imm = -5 符号扩展)
        instr = {12'hFFB, 5'd2, 3'b010, 5'd4, 7'b0010011};
        check("slit", 6'd1, rs1_data, 32'hFFFF_FFFB);

        // xori x5, x3, 0x7FF
        instr = {12'h7FF, 5'd3, 3'b100, 5'd5, 7'b0010011};
        check("xori", 6'd3, rs1_data, 32'h0000_07FF);

        // slli x6, x4, 5  (shamt = 5)
        // funct7 = 0000000, shamt = 5, rs1 = 4, funct3 = 001, rd = 6
        instr = {7'b0000000, 5'd5, 5'd4, 3'b001, 5'd6, 7'b0010011};
        check("slli", 6'd6, rs1_data, 32'd5);

        // srli x7, x5, 10
        instr = {7'b0000000, 5'd10, 5'd5, 3'b101, 5'd7, 7'b0010011};
        check("srli", 6'd7, rs1_data, 32'd10);

        // srai x8, x6, 15
        instr = {7'b0100000, 5'd15, 5'd6, 3'b101, 5'd8, 7'b0010011};
        check("srai", 6'd8, rs1_data, 32'd15);

        // ---------- R-type ----------
        // add x9, x1, x2
        // funct7 = 0000000, rs2 = 2, rs1 = 1, funct3 = 000, rd = 9, opcode = 0110011
        instr = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'd9, 7'b0110011};
        check("add", 6'd9, rs1_data, rs2_data);

        // sub x10, x3, x4
        instr = {7'b0100000, 5'd4, 5'd3, 3'b000, 5'd10, 7'b0110011};
        check("sub", 6'd10, rs1_data, rs2_data);

        // xor x11, x5, x6
        instr = {7'b0000000, 5'd6, 5'd5, 3'b100, 5'd11, 7'b0110011};
        check("xor", 6'd14, rs1_data, rs2_data);

        // srl x12, x7, x8
        instr = {7'b0000000, 5'd8, 5'd7, 3'b101, 5'd12, 7'b0110011};
        check("srl", 6'd17, rs1_data, rs2_data);

        // sra x13, x9, x10
        instr = {7'b0100000, 5'd10, 5'd9, 3'b101, 5'd13, 7'b0110011};
        check("sra", 6'd18, rs1_data, rs2_data);

        // ---------- B-type ----------
        // beq x1, x2, offset = 8
        // imm[12|10:5] = 0000000, rs2 = 2, rs1 = 1, funct3 = 000, imm[4:1|11] = 0000_0
        instr = {7'b0000000, 5'd2, 5'd1, 3'b000, 4'b0000, 1'b0, 7'b1100011};
        check("beq", 6'd19, rs1_data, 32'h0000_0008);

        // bne x3, x4, offset = -16
        // imm = -16 = 12'hFF0, B-type 编码
        instr = {1'b1, 6'b111111, 5'd4, 5'd3, 3'b001, 4'b1111, 1'b1, 7'b1100011};
        check("bne", 6'd20, rs1_data, 32'hFFFF_FFF0);

        // ---------- 非法指令 ----------

        instr = 32'h0000_0000;
        check("nop/illegal", 6'd0, rs1_data, 32'h0000_0000);

        $display("========================================");
        $display("Test finished");
        $display("========================================");
        $finish;
    end

endmodule

