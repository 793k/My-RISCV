`timescale 1ns / 1ps

module tb_rom;

    parameter AW = 32;

    // wire             clk;
    // wire             rst_n;
    // wire             jump_en;
    reg  [AW-1:0] instr_addr;
    wire [AW-1:0] instr_out;

    rom #(
        .AW(AW)
    ) u_rom (
        .instr_addr(instr_addr),
        .instr_out (instr_out)
    );

    initial begin

        // clk = 1'b0;
        // rst_n = 1'b0;
        // jump_en = 1'b0;
        instr_addr = 32'd0;
        #100;
        instr_addr = 32'd4;
        #100;
        instr_addr = 32'd9;
        #100;

        // jump_en = 0;
        $finish;
    end

endmodule

