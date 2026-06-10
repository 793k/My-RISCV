module pipe_if_id (
    input  wire clk,
    input  wire rst_n,
    input  wire stall,
    input  wire flush,
    input  wire [31:0] pc_i,
    input  wire [31:0] instr_i,
    output reg  [31:0] pc_o,
    output reg  [31:0] instr_o
);
//流水线寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_o    <= 32'd0;
            instr_o <= 32'h00000013;
        end else if (stall) begin

            // 保持
        end else if (flush) begin
            instr_o <= 32'h00000013;
        end else begin
            pc_o    <= pc_i;
            instr_o <= instr_i;
        end
    end

endmodule

