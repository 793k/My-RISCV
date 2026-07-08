module rom_dp (
    input  wire [10:0] if_addr,    // 取指端口地址
    input  wire        if_clk,     // 取指端口时钟
    output wire [31:0] if_q,       // 取指端口数据

    input  wire [10:0] dbus_addr,  // 数据读端口地址
    input  wire        dbus_clk,   // 数据读端口时钟
    output wire [31:0] dbus_q      // 数据读端口数据
);

    wire [31:0] q_a_wire;
    wire [31:0] q_b_wire;

    assign if_q   = q_a_wire;
    assign dbus_q = q_b_wire;

    altsyncram altsyncram_component (
        .address_a (if_addr),
        .clock0    (if_clk),
        .q_a       (q_a_wire),
        .address_b (dbus_addr),
        .clock1    (dbus_clk),
        .q_b       (q_b_wire),

        .aclr0          (1'b0),
        .aclr1          (1'b0),
        .addressstall_a (1'b0),
        .addressstall_b (1'b0),
        .byteena_a      (1'b1),
        .byteena_b      (1'b1),
        .clocken0       (1'b1),
        .clocken1       (1'b1),
        .clocken2       (1'b1),
        .clocken3       (1'b1),
        .data_a         ({32{1'b1}}),
        .data_b         ({32{1'b1}}),
        .rden_a         (1'b1),
        .rden_b         (1'b1),
        .wren_a         (1'b0),
        .wren_b         (1'b0)
    );

    defparam
        altsyncram_component.address_aclr_a = "NONE",
        altsyncram_component.address_aclr_b = "NONE",
        altsyncram_component.clock_enable_input_a = "BYPASS",
        altsyncram_component.clock_enable_input_b = "BYPASS",
        altsyncram_component.clock_enable_output_a = "BYPASS",
        altsyncram_component.clock_enable_output_b = "BYPASS",
        altsyncram_component.init_file = "test.mif",
        altsyncram_component.intended_device_family = "Cyclone IV GX",
        altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
        altsyncram_component.lpm_type = "altsyncram",
        altsyncram_component.numwords_a = 2048,
        altsyncram_component.numwords_b = 2048,
        altsyncram_component.operation_mode = "DUAL_PORT",
        altsyncram_component.outdata_aclr_a = "NONE",
        altsyncram_component.outdata_aclr_b = "NONE",
        altsyncram_component.outdata_reg_a = "UNREGISTERED",
        altsyncram_component.outdata_reg_b = "UNREGISTERED",
        altsyncram_component.ram_block_type = "M9K",
        altsyncram_component.widthad_a = 11,
        altsyncram_component.widthad_b = 11,
        altsyncram_component.width_a = 32,
        altsyncram_component.width_b = 32,
        altsyncram_component.width_byteena_a = 1,
        altsyncram_component.width_byteena_b = 1;

endmodule
