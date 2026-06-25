module rom_bus (
    input  wire [10:0] addr_i,
    output wire [31:0] data_o
);
    reg [31:0] mem [0:2047];

    // ../../ 从 simulation/modelsim/ 回到 quartus_project/
    initial $readmemh("../../ip_core/rom_32x256/program_text.hex", mem);

    assign data_o = mem[addr_i];

endmodule
