module regfile (
    input  wire clk,
    input  wire rst_n,
    input  wire wr_en,
    input  wire [ 4:0] wr_addr,
    input  wire [31:0] wr_data,
    input  wire [ 4:0] rs1_addr,
    input  wire [ 4:0] rs2_addr,
    output reg  [31:0] rs1_data,
    output reg  [31:0] rs2_data
);
    reg     [31:0] regs[0:31];
    integer        i;

    always @(*) begin
        if (rs1_addr == 5'd0) rs1_data = 32'd0;
        else rs1_data = regs[rs1_addr];

        if (rs2_addr == 5'd0) rs2_data = 32'd0;
        else rs2_data = regs[rs2_addr];
    end

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) regs[i] <= 32'd0;  //清空寄存器
        end else if (wr_en && wr_addr != 5'd0) begin
            regs[wr_addr] <= wr_data;  //非x0写入
        end
    end

endmodule

