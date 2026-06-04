module rom #(
    parameter AW = 32
) (
    input  wire [31:0] instr_addr,
    output reg  [31:0] instr_out
);

    reg [31:0] rom_mem[0:4095];

    initial begin
        $readmemh("D:/BaiduSyncdisk/cpu/test_data/test.txt", rom_mem);
    end

    always @(*) begin
        instr_out = rom_mem[instr_addr[31:2]];
    end

endmodule

