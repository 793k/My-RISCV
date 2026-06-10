// ============================================================
// 寄存器堆模块
// ============================================================
// 功能：32 个 32 位通用寄存器，支持异步读、同步写
//       x0 恒为 0，支持同周期读写旁路（write-after-read bypass）
// ============================================================

module regfile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire [ 4:0] wr_addr,
    input  wire [31:0] wr_data,
    input  wire [ 4:0] rs1_addr,
    input  wire [ 4:0] rs2_addr,
    output reg  [31:0] rs1_data,
    output reg  [31:0] rs2_data
);

    reg [31:0] regs [0:31];
    integer    i;

    // --------------------------------------------------
    // 异步读端口（组合逻辑）
    // --------------------------------------------------

    always @(*) begin
        // rs1 读端口
        if (rs1_addr == 5'd0)
            rs1_data = 32'd0;
        else if (wr_en && rs1_addr == wr_addr)
            rs1_data = wr_data;              // 同周期写回旁路
        else
            rs1_data = regs[rs1_addr];

        // rs2 读端口
        if (rs2_addr == 5'd0)
            rs2_data = 32'd0;
        else if (wr_en && rs2_addr == wr_addr)
            rs2_data = wr_data;              // 同周期写回旁路
        else
            rs2_data = regs[rs2_addr];
    end

    // --------------------------------------------------
    // 同步写端口（时序逻辑）
    // --------------------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;            // 复位清零
        end else if (wr_en && wr_addr != 5'd0) begin
            regs[wr_addr] <= wr_data;        // x0 不可写
        end
    end

endmodule
