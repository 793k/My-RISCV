module addr_decoder (
    input  wire [31:0] bus_addr_i,
    input  wire        bus_wen_i,
    input  wire [5:0]  bus_instr_sel_i,

    input  wire [31:0] rsp_ram_i,
    input  wire [31:0] rsp_rom_i,
    input  wire [31:0] rsp_uart_i,
    input  wire [31:0] rsp_spi_i,
    input  wire [31:0] rsp_i2c_i,

    output reg         cs_ram_we_o,
    output reg         cs_uart_we_o,
    output reg         cs_uart_re_o,
    output reg         cs_spi_we_o,
    output reg         cs_spi_re_o,
    output reg         cs_i2c_we_o,
    output reg         cs_i2c_re_o,

    output reg  [31:0] bus_rdata_o
);

    `include "../decode/decode_params.vh"

    wire [7:0] addr_hi    = bus_addr_i[31:24];
    wire [7:0] addr_midhi = bus_addr_i[23:16];

    wire bus_access = (bus_instr_sel_i >= `instr_sel_lb && bus_instr_sel_i <= `instr_sel_sw);

    // ── 片选 ──
    always @(*) begin
        {cs_ram_we_o, cs_uart_we_o, 
         cs_uart_re_o,
         cs_spi_we_o,  cs_spi_re_o,
         cs_i2c_we_o,  cs_i2c_re_o} = 7'b0;

        case ({addr_hi, addr_midhi})
            // UART
            {8'h80, 8'h00}: begin
                cs_uart_we_o = bus_wen_i;
                cs_uart_re_o = !bus_wen_i;
            end
            // SPI 预留
            {8'h80, 8'h01}: begin
                cs_spi_we_o = bus_wen_i;
                cs_spi_re_o = !bus_wen_i;
            end
            // I2C 预留
            {8'h80, 8'h02}: begin
                cs_i2c_we_o = bus_wen_i;
                cs_i2c_re_o = !bus_wen_i;
            end
            // 其他地址默认写 RAM
            default: cs_ram_we_o = bus_wen_i;
        endcase
    end

    // ── 响应 mux ──
    always @(*) begin
        bus_rdata_o = rsp_ram_i;
        if (bus_access) begin
            case ({addr_hi, addr_midhi})
                {8'h80, 8'h00}: bus_rdata_o = rsp_uart_i;
                {8'h80, 8'h01}: bus_rdata_o = rsp_spi_i;
                {8'h80, 8'h02}: bus_rdata_o = rsp_i2c_i;
                {8'h00, 8'h00}: bus_rdata_o = rsp_rom_i;
            endcase
        end
    end

endmodule
