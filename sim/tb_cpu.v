`timescale 1ns / 1ps

module tb_cpu;

    // ==================================================
    // 1. 激励信号
    // ==================================================
    reg clk;
    reg rst_n;

    // ==================================================
    // 2. DUT 实例化
    // ==================================================
    CPU u_cpu (
        .clk  (clk),
        .rst_n(rst_n)
    );

    // ==================================================
    // 3. 引出 CPU 内部全部线网（一级层次）
    // ==================================================
    wire [31:0] sim_if_pc;
    assign sim_if_pc = u_cpu.if_pc;
    wire [31:0] sim_if_instr;
    assign sim_if_instr = u_cpu.if_instr;
    wire [31:0] sim_id_pc;
    assign sim_id_pc = u_cpu.id_pc;
    wire [31:0] sim_id_instr;
    assign sim_id_instr = u_cpu.id_instr;

    wire [31:0] sim_dbg_jump_target;
    assign sim_dbg_jump_target = u_cpu.dbg_jump_target;
    wire sim_dbg_jump_en;
    assign sim_dbg_jump_en = u_cpu.dbg_jump_en;
    wire [4:0] sim_dbg_rd_idx;
    assign sim_dbg_rd_idx = u_cpu.dbg_rd_idx;
    wire [5:0] sim_dbg_instr_sel;
    assign sim_dbg_instr_sel = u_cpu.dbg_instr_sel;
    wire [4:0] sim_dbg_rs1_idx;
    assign sim_dbg_rs1_idx = u_cpu.dbg_rs1_idx;
    wire [4:0] sim_dbg_rs2_idx;
    assign sim_dbg_rs2_idx = u_cpu.dbg_rs2_idx;
    wire [31:0] sim_dbg_rs1_val;
    assign sim_dbg_rs1_val = u_cpu.dbg_rs1_val;
    wire [31:0] sim_dbg_rs2_val;
    assign sim_dbg_rs2_val = u_cpu.dbg_rs2_val;
    wire [31:0] sim_dbg_alu_a;
    assign sim_dbg_alu_a = u_cpu.dbg_alu_a;
    wire [31:0] sim_dbg_alu_b;
    assign sim_dbg_alu_b = u_cpu.dbg_alu_b;
    wire [31:0] sim_dbg_jump_base;
    assign sim_dbg_jump_base = u_cpu.dbg_jump_base;
    wire [31:0] sim_dbg_jump_offs;
    assign sim_dbg_jump_offs = u_cpu.dbg_jump_offs;
    wire sim_dbg_reg_wr_en;
    assign sim_dbg_reg_wr_en = u_cpu.dbg_reg_wr_en;
    wire [31:0] sim_dbg_write_val;
    assign sim_dbg_write_val = u_cpu.dbg_write_val;

    // EX/MEM 阶段信号
    wire [31:0] sim_ex_reg_rd_val;
    assign sim_ex_reg_rd_val = u_cpu.ex_reg_rd_val;
    wire sim_ex_reg_wr_en;
    assign sim_ex_reg_wr_en = u_cpu.ex_reg_wr_en;
    wire [31:0] sim_ex_mem_rd_idx;
    assign sim_ex_mem_rd_idx = u_cpu.ex_mem_rd_idx;
    wire [31:0] sim_ex_mem_rd_val;
    assign sim_ex_mem_rd_val = u_cpu.ex_mem_rd_val;
    wire sim_ex_mem_wr_en;
    assign sim_ex_mem_wr_en = u_cpu.ex_mem_wr_en;

    // MEM 阶段信号
    wire [5:0] sim_mem_instr_sel;
    assign sim_mem_instr_sel = u_cpu.mem_instr_sel;
    wire [31:0] sim_mem_reg_rd_val;
    assign sim_mem_reg_rd_val = u_cpu.mem_reg_rd_val;
    wire [31:0] sim_mem_mem_read_rd_val;
    assign sim_mem_mem_read_rd_val = u_cpu.mem_mem_read_rd_val;
    wire sim_mem_reg_wr_en;
    assign sim_mem_reg_wr_en = u_cpu.mem_reg_wr_en;
    wire sim_mem_mem_wr_en;
    assign sim_mem_mem_wr_en = u_cpu.mem_mem_wr_en;
    wire [31:0] sim_mem_mem_rd_idx;
    assign sim_mem_mem_rd_idx = u_cpu.mem_mem_rd_idx;

    // WB 阶段信号
    wire [31:0] sim_wb_reg_rd_val;
    assign sim_wb_reg_rd_val = u_cpu.wb_reg_rd_val;
    wire sim_wb_reg_wr_en;
    assign sim_wb_reg_wr_en = u_cpu.wb_reg_wr_en;
    wire [4:0] sim_wb_reg_rd_idx;
    assign sim_wb_reg_rd_idx = u_cpu.wb_reg_rd_idx;

    // ==================================================
    // 4. ALU 子模块内部信号
    // ==================================================
    wire [31:0] sim_alu_result;
    assign sim_alu_result = u_cpu.u_alu.result_o;
    wire [31:0] sim_alu_jump_target;
    assign sim_alu_jump_target = u_cpu.u_alu.jump_target_o;
    wire sim_alu_jump_en;
    assign sim_alu_jump_en = u_cpu.u_alu.jump_en_o;
    wire sim_alu_reg_wr_en;
    assign sim_alu_reg_wr_en = u_cpu.u_alu.reg_wr_en_o;
    wire [31:0] sim_alu_mem_rd_idx;
    assign sim_alu_mem_rd_idx = u_cpu.u_alu.mem_rd_idx_o;
    wire [31:0] sim_alu_mem_rd_val;
    assign sim_alu_mem_rd_val = u_cpu.u_alu.mem_rd_val_o;
    wire sim_alu_mem_wr_en;
    assign sim_alu_mem_wr_en = u_cpu.u_alu.mem_wr_en_o;

    // ==================================================
    // 5. 寄存器组（数组 + RISC-V ABI 别名）
    // ==================================================
    wire [31:0] sim_regs[0:31];
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gen_reg_probe
            assign sim_regs[gi] = u_cpu.u_regfile.regs[gi];
        end
    endgenerate

    wire [31:0] sim_zero = sim_regs[0];
    wire [31:0] sim_ra   = sim_regs[1];
    wire [31:0] sim_sp   = sim_regs[2];
    wire [31:0] sim_gp   = sim_regs[3];
    wire [31:0] sim_tp   = sim_regs[4];
    wire [31:0] sim_t0   = sim_regs[5];
    wire [31:0] sim_t1   = sim_regs[6];
    wire [31:0] sim_t2   = sim_regs[7];
    wire [31:0] sim_s0   = sim_regs[8];
    wire [31:0] sim_s1   = sim_regs[9];
    wire [31:0] sim_a0   = sim_regs[10];
    wire [31:0] sim_a1   = sim_regs[11];
    wire [31:0] sim_a2   = sim_regs[12];
    wire [31:0] sim_a3   = sim_regs[13];
    wire [31:0] sim_a4   = sim_regs[14];
    wire [31:0] sim_a5   = sim_regs[15];
    wire [31:0] sim_a6   = sim_regs[16];
    wire [31:0] sim_a7   = sim_regs[17];
    wire [31:0] sim_s2   = sim_regs[18];
    wire [31:0] sim_s3   = sim_regs[19];
    wire [31:0] sim_s4   = sim_regs[20];
    wire [31:0] sim_s5   = sim_regs[21];
    wire [31:0] sim_s6   = sim_regs[22];
    wire [31:0] sim_s7   = sim_regs[23];
    wire [31:0] sim_s8   = sim_regs[24];
    wire [31:0] sim_s9   = sim_regs[25];
    wire [31:0] sim_s10  = sim_regs[26];
    wire [31:0] sim_s11  = sim_regs[27];
    wire [31:0] sim_t3   = sim_regs[28];
    wire [31:0] sim_t4   = sim_regs[29];
    wire [31:0] sim_t5   = sim_regs[30];
    wire [31:0] sim_t6   = sim_regs[31];

    // ==================================================
    // 6. 时钟生成（100MHz，10ns 周期）
    // ==================================================

    initial begin
        clk = 0;
        forever #(5) clk = ~clk;
    end

    // ==================================================
    // 7. 复位 & 仿真控制
    // ==================================================

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;

        #5000;
        $display(">>> Simulation finished at %0t ns", $time);
        $finish;
    end

    // ==================================================
    // 8. 波形 Dump（VCD）
    // ==================================================

    initial begin
        $dumpfile("cpu_wave.vcd");
        $dumpvars(0, tb_cpu);
    end

    // ==================================================
    // 9. 终端打印
    // ==================================================

    always @(posedge clk) begin
        if (rst_n) begin
            $display(
                "T=%0t | PC=%08X Instr=%08X | rs1=%02d(%08X) rs2=%02d(%08X) | rd=%02d WE=%b WD=%08X | MEM WE=%b ADDR=%08X DATA=%08X | JUMP=%b -> %08X",
                $time,
                sim_if_pc,
                sim_if_instr,
                sim_dbg_rs1_idx,
                sim_dbg_rs1_val,
                sim_dbg_rs2_idx,
                sim_dbg_rs2_val,
                sim_dbg_rd_idx,
                sim_dbg_reg_wr_en,
                sim_dbg_write_val,
                sim_mem_mem_wr_en,
                sim_mem_mem_rd_idx,
                sim_mem_mem_read_rd_val,
                sim_dbg_jump_en,
                sim_dbg_jump_target
            );
        end
    end

endmodule
