module pipe_id_ex (
    input  wire clk,
    input  wire rst_n,
    input  wire flush,

    // 前递输入（来自 MEM / WB 阶段）
    input  wire        mem_reg_wr_en_i,
    input  wire [ 4:0] mem_rd_idx_i,
    input  wire [31:0] mem_alu_result_i,
    input  wire        wb_reg_wr_en_i,
    input  wire [ 4:0] wb_rd_idx_i,
    input  wire [31:0] wb_write_val_i,

    // ID 阶段输入
    input  wire [31:0] alu_a_i,
    input  wire [31:0] alu_b_i,
    input  wire [31:0] jump_base_i,
    input  wire [31:0] jump_offs_i,
    input  wire [ 4:0] rd_idx_i,
    input  wire [ 4:0] rs1_idx_i,
    input  wire [ 4:0] rs2_idx_i,
    input  wire [ 5:0] instr_sel_i,
    input  wire [ 4:0] op_type_i,

    // EX 阶段输出（前递后）
    output reg  [31:0] alu_a_fwd_o,
    output reg  [31:0] alu_b_fwd_o,
    output reg  [31:0] jump_base_o,
    output reg  [31:0] jump_offs_o,
    output wire [ 5:0] alu_sel_o,

    // EX 阶段输出（流水线寄存器直传）
    output reg  [ 4:0] rd_idx_o,
    output reg  [ 4:0] rs1_idx_o,
    output reg  [ 4:0] rs2_idx_o,
    output reg  [ 4:0] op_type_o
);

    `include "../decode/decode_params.vh"

    // 内部流水线寄存器
    reg [31:0] reg_alu_a;
    reg [31:0] reg_alu_b;
    reg [ 5:0] reg_instr_sel;

    // --------------------------------------------------
    // 流水线寄存器（时序逻辑）
    // --------------------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_alu_a     <= 32'd0;
            reg_alu_b     <= 32'd0;
            jump_base_o   <= 32'd0;
            jump_offs_o   <= 32'd0;
            rd_idx_o      <= 5'd0;
            rs1_idx_o     <= 5'd0;
            rs2_idx_o     <= 5'd0;
            reg_instr_sel <= `instr_sel_addi;  // NOP
            op_type_o     <= `op_sel_I;
        end else if (flush) begin
            reg_alu_a     <= 32'd0;
            reg_alu_b     <= 32'd0;
            jump_base_o   <= 32'd0;
            jump_offs_o   <= 32'd0;
            rd_idx_o      <= 5'd0;
            rs1_idx_o     <= 5'd0;
            rs2_idx_o     <= 5'd0;
            reg_instr_sel <= `instr_sel_addi;  // NOP
            op_type_o     <= `op_sel_I;
        end else begin
            reg_alu_a     <= alu_a_i;
            reg_alu_b     <= alu_b_i;
            jump_base_o   <= jump_base_i;
            jump_offs_o   <= jump_offs_i;
            rd_idx_o      <= rd_idx_i;
            rs1_idx_o     <= rs1_idx_i;
            rs2_idx_o     <= rs2_idx_i;
            reg_instr_sel <= instr_sel_i;
            op_type_o     <= op_type_i;
        end
    end

    // --------------------------------------------------
    // op1（rs1）前递逻辑（组合逻辑）
    // --------------------------------------------------

    always @(*) begin
        if (mem_reg_wr_en_i && (mem_rd_idx_i != 5'd0)
            && (mem_rd_idx_i == rs1_idx_o)) begin
            alu_a_fwd_o = mem_alu_result_i;
        end else if (wb_reg_wr_en_i && (wb_rd_idx_i != 5'd0)
            && (wb_rd_idx_i == rs1_idx_o)) begin
            alu_a_fwd_o = wb_write_val_i;
        end else begin
            alu_a_fwd_o = reg_alu_a;
        end
    end

    // --------------------------------------------------
    // op2（rs2）前递逻辑（组合逻辑）
    // --------------------------------------------------

    always @(*) begin
        if ((op_type_o == `op_sel_R || op_type_o == `op_sel_branch)
            && mem_reg_wr_en_i && (mem_rd_idx_i != 5'd0)
            && (mem_rd_idx_i == rs2_idx_o)) begin
            alu_b_fwd_o = mem_alu_result_i;
        end else if ((op_type_o == `op_sel_R || op_type_o == `op_sel_branch)
            && wb_reg_wr_en_i && (wb_rd_idx_i != 5'd0)
            && (wb_rd_idx_i == rs2_idx_o)) begin
            alu_b_fwd_o = wb_write_val_i;
        end else begin
            alu_b_fwd_o = reg_alu_b;
        end
    end

    assign alu_sel_o = reg_instr_sel;

endmodule
