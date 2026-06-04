`timescale 1ns / 1ps

module tb_pc_count;

    parameter AW = 32;

    logic          clk;
    logic          rst_n;
    logic          jump_en;
    logic [AW-1:0] jump_addr;
    logic [AW-1:0] out_addr;

    pc_count #(
        .AW(AW)
    ) u_pc_count (
        .clk      (clk),
        .rst_n    (rst_n),
        .jump_en  (jump_en),
        .jump_addr(jump_addr),
        .out_addr (out_addr)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        jump_en = 1'b0;
        jump_addr = {AW{1'b0}};
        #100;
        rst_n = 1'b1;
        #500;
        jump_addr = 200;
        jump_en = 1'b1;
        #100

        // jump_en = 0;
        $finish;
    end

endmodule

