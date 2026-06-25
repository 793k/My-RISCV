module regfile (
    input  wire        clk_i,
    input  wire        rst_n_i,
    input  wire        wr_en_i,
    input  wire [ 4:0] wr_idx_i,
    input  wire [31:0] wr_data_i,
    input  wire [ 4:0] rs1_idx_i,
    input  wire [ 4:0] rs2_idx_i,
    output reg  [31:0] rs1_val_o,
    output reg  [31:0] rs2_val_o
);

    reg [31:0] regs [0:31];
    integer    i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'd0;
    end

    always @(*) begin
        if (rs1_idx_i == 5'd0)
            rs1_val_o = 32'd0;
        else if (wr_en_i && rs1_idx_i == wr_idx_i)
            rs1_val_o = wr_data_i;
        else
            rs1_val_o = regs[rs1_idx_i];

        if (rs2_idx_i == 5'd0)
            rs2_val_o = 32'd0;
        else if (wr_en_i && rs2_idx_i == wr_idx_i)
            rs2_val_o = wr_data_i;
        else
            rs2_val_o = regs[rs2_idx_i];
    end

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (wr_en_i && wr_idx_i != 5'd0) begin
            regs[wr_idx_i] <= wr_data_i;
        end
    end

endmodule
