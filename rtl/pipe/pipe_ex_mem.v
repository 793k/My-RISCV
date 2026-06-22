module pipe_ex_mem (
    input  wire clk,
    input  wire rst_n,

    input  wire [5:0] instr_sel_i,

    input  wire reg_wr_en_i,
    input  wire [ 4:0] reg_rd_idx_i,
    input  wire [31:0] reg_rd_val_i,

    input  wire mem_wr_en_i,
    input  wire [31:0] mem_wr_idx_i,
    input  wire [31:0] mem_wr_val_i,

    output reg  reg_wr_en_o,
    output reg  [ 4:0] reg_rd_idx_o,
    output reg  [31:0] reg_rd_val_o,

    output reg  mem_wr_en_o,
    output reg  [31:0] mem_wr_idx_o,
    output reg  [31:0] mem_wr_val_o,

    output reg  [5:0] instr_sel_o
);

    //流水线寄存器

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_wr_en_o  <= 1'd0;
            reg_rd_idx_o <= 5'd0;
            reg_rd_val_o <= 32'd0;

            mem_wr_en_o  <= 1'd0;
            mem_wr_idx_o <= 32'd0;
            mem_wr_val_o <= 32'd0;
            instr_sel_o  <= 6'd0;
        end else begin
            reg_wr_en_o  <= reg_wr_en_i;
            reg_rd_idx_o <= reg_rd_idx_i;
            reg_rd_val_o <= reg_rd_val_i;

            mem_wr_en_o  <= mem_wr_en_i;
            mem_wr_idx_o <= mem_wr_idx_i;
            mem_wr_val_o <= mem_wr_val_i;
            instr_sel_o  <= instr_sel_i;
        end
    end

endmodule

