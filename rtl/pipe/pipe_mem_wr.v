module pipe_mem_wr (
    input  wire clk,
    input  wire rst_n,
    input  wire reg_wr_en_i,
    input  wire [ 4:0] reg_rd_idx_i,
    input  wire [31:0] reg_rd_val_i,

    output reg  reg_wr_en_o,
    output reg  [ 4:0] reg_rd_idx_o,
    output reg  [31:0] reg_rd_val_o
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_wr_en_o  <= 1'd0;
            reg_rd_idx_o <= 5'd0;
            reg_rd_val_o <= 32'd0;
        end else begin
            reg_wr_en_o  <= reg_wr_en_i;
            reg_rd_idx_o <= reg_rd_idx_i;
            reg_rd_val_o <= reg_rd_val_i;
        end
    end

endmodule

