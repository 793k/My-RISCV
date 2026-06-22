module mem_ctrl (
    input  wire clk,
    input  wire [31:0] reg_rd_val_i,
    input  wire mem_wr_en_i,
    input  wire [31:0] mem_rd_idx_i,
    input  wire [31:0] mem_rd_val_i,
    input  wire [ 5:0] mem_instr_sel_i,

    output reg  [31:0] q_val_o
);

    `include "../decode/decode_params.vh"

    wire [10:0] word_addr = mem_rd_idx_i[12:2];
    wire [ 1:0] offset    = mem_rd_idx_i[1:0];

    reg  [ 3:0] byteena;
    reg  [31:0] store_data;

    wire [31:0] raw;

    ram_32_1024 ram_32_1024_inst (
        .address(word_addr),
        .clock  (~clk),
        .byteena(byteena),
        .data   (store_data),
        .wren   (mem_wr_en_i),
        .q      (raw)
    );

    wire [ 7:0] sel_byte = (offset == 2'd3) ? raw[31:24] :
                           (offset == 2'd2) ? raw[23:16] :
                           (offset == 2'd1) ? raw[15: 8] :
                                              raw[ 7: 0];

    wire [15:0] sel_half = offset[1] ? raw[31:16] : raw[15:0];

    always @(*) begin
        byteena    = 4'b0000;
        store_data = mem_rd_val_i;
        q_val_o    = reg_rd_val_i;
        case (mem_instr_sel_i)
            `instr_sel_sb :
                begin
                    byteena = 4'b0001 << offset;
                    store_data = mem_rd_val_i << (offset * 8);
                end
            `instr_sel_sh :
                begin
                    byteena = 4'b0011<< offset;
                    store_data = mem_rd_val_i << (offset * 8);
                end
            `instr_sel_sw :
                begin
                    byteena    = 4'b1111;
                    store_data = mem_rd_val_i;
                end
            `instr_sel_lb : q_val_o = {{24{sel_byte[7]}}, sel_byte};
            `instr_sel_lbu: q_val_o = {24'd0, sel_byte};
            `instr_sel_lh : q_val_o = {{16{sel_half[15]}}, sel_half};
            `instr_sel_lhu: q_val_o = {16'd0, sel_half};
            `instr_sel_lw : q_val_o = raw;

            default: ;
        endcase
    end

endmodule

