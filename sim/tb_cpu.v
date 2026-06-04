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
    wire [31:0] sim_pc_addr;
    assign sim_pc_addr = u_cpu.pc_addr;
    wire [31:0] sim_jump_addr;
    assign sim_jump_addr = u_cpu.jump_addr;
    wire [31:0] sim_instr;
    assign sim_instr = u_cpu.instr;
    wire [4:0] sim_rd_addr;
    assign sim_rd_addr = u_cpu.rd_addr;
    wire [5:0] sim_instr_sel;
    assign sim_instr_sel = u_cpu.instr_sel;
    wire [4:0] sim_rs1_addr;
    assign sim_rs1_addr = u_cpu.rs1_addr;
    wire [4:0] sim_rs2_addr;
    assign sim_rs2_addr = u_cpu.rs2_addr;
    wire [31:0] sim_rs1_data;
    assign sim_rs1_data = u_cpu.rs1_data;
    wire [31:0] sim_rs2_data;
    assign sim_rs2_data = u_cpu.rs2_data;
    wire [31:0] sim_op1;
    assign sim_op1 = u_cpu.op1;
    wire [31:0] sim_op2;
    assign sim_op2 = u_cpu.op2;
    wire [31:0] sim_jump_op1;
    assign sim_jump_op1 = u_cpu.jump_op1;
    wire [31:0] sim_jump_op2;
    assign sim_jump_op2 = u_cpu.jump_op2;
    wire sim_wr_en;
    assign sim_wr_en = u_cpu.wr_en;
    wire sim_jump_en;
    assign sim_jump_en = u_cpu.jump_en;
    wire [31:0] sim_rd_data;
    assign sim_rd_data = u_cpu.rd_data;

    // ==================================================
    // 4. 引出子模块内部关键信号（二级层次）
    // ==================================================

    // --------------------------------------------------
    // 寄存器组（数组形式 + RISC-V ABI 别名，方便波形查看器分组）
    // --------------------------------------------------
    wire [31:0] sim_regs[0:31];
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gen_reg_probe
            assign sim_regs[gi] = u_cpu.u_regfile.regs[gi];
        end
    endgenerate

    // 寄存器别名组（按 RISC-V 调用约定命名）
    wire [31:0] sim_zero, sim_ra, sim_sp, sim_gp, sim_tp;
    wire [31:0] sim_t0, sim_t1, sim_t2;
    wire [31:0] sim_s0, sim_s1;
    wire [31:0] sim_a0, sim_a1, sim_a2, sim_a3, sim_a4, sim_a5, sim_a6, sim_a7;
    wire [31:0] sim_s2, sim_s3, sim_s4, sim_s5, sim_s6, sim_s7, sim_s8, sim_s9, sim_s10, sim_s11;
    wire [31:0] sim_t3, sim_t4, sim_t5, sim_t6;

    assign sim_zero = sim_regs[0];   // x0
    assign sim_ra   = sim_regs[1];   // x1
    assign sim_sp   = sim_regs[2];   // x2
    assign sim_gp   = sim_regs[3];   // x3
    assign sim_tp   = sim_regs[4];   // x4
    assign sim_t0   = sim_regs[5];   // x5
    assign sim_t1   = sim_regs[6];   // x6
    assign sim_t2   = sim_regs[7];   // x7
    assign sim_s0   = sim_regs[8];   // x8  (fp)
    assign sim_s1   = sim_regs[9];   // x9
    assign sim_a0   = sim_regs[10];  // x10
    assign sim_a1   = sim_regs[11];  // x11
    assign sim_a2   = sim_regs[12];  // x12
    assign sim_a3   = sim_regs[13];  // x13
    assign sim_a4   = sim_regs[14];  // x14
    assign sim_a5   = sim_regs[15];  // x15
    assign sim_a6   = sim_regs[16];  // x16
    assign sim_a7   = sim_regs[17];  // x17
    assign sim_s2   = sim_regs[18];  // x18
    assign sim_s3   = sim_regs[19];  // x19
    assign sim_s4   = sim_regs[20];  // x20
    assign sim_s5   = sim_regs[21];  // x21
    assign sim_s6   = sim_regs[22];  // x22
    assign sim_s7   = sim_regs[23];  // x23
    assign sim_s8   = sim_regs[24];  // x24
    assign sim_s9   = sim_regs[25];  // x25
    assign sim_s10  = sim_regs[26];  // x26
    assign sim_s11  = sim_regs[27];  // x27
    assign sim_t3   = sim_regs[28];  // x28
    assign sim_t4   = sim_regs[29];  // x29
    assign sim_t5   = sim_regs[30];  // x30
    assign sim_t6   = sim_regs[31];  // x31

    // ALU 子模块输出（假设 alu 内部有这些信号名，按实际修改）
    wire [31:0] sim_alu_rd_data;
    assign sim_alu_rd_data = u_cpu.u_alu.rd_data;
    wire [31:0] sim_alu_jump_addr;
    assign sim_alu_jump_addr = u_cpu.u_alu.jump_addr;
    wire sim_alu_jump_en;
    assign sim_alu_jump_en = u_cpu.u_alu.jump_en;
    wire sim_alu_wr_en;
    assign sim_alu_wr_en = u_cpu.u_alu.wr_en;

    // ==================================================
    // 5. 时钟生成（100MHz，10ns 周期）
    // ==================================================

    initial begin
        clk = 0;
        forever #(5) clk = ~clk;
    end

    // ==================================================
    // 6. 复位 & 仿真控制
    // ==================================================

    initial begin
        rst_n = 0;
        #100;  // 复位 100ns
        rst_n = 1;  // 释放复位

        #5000;  // 跑 5us
        $display(">>> Simulation finished at %0t ns", $time);
        $finish;
    end

    // ==================================================
    // 7. 波形 Dump（VCD，通用格式）
    // ==================================================

    initial begin
        $dumpfile("cpu_wave.vcd");
        $dumpvars(0, tb_cpu);  // dump 整个 tb_cpu 层次，包含所有内部信号
    end

    // ==================================================
    // 8. 终端打印（方便快速查错）
    // ==================================================

    always @(posedge clk) begin
        if (rst_n) begin
            $display(
                "T = %0t | PC = %08X | Instr = %08X | rs1 = %02d(%08X) rs2 = %02d(%08X) | rd = %02d WE = %b WD = %08X | JUMP = %b -> %08X",
                $time, sim_pc_addr, sim_instr, sim_rs1_addr, sim_rs1_data, sim_rs2_addr,
                sim_rs2_data, sim_rd_addr, sim_wr_en, sim_rd_data, sim_jump_en, sim_jump_addr);
        end
    end

endmodule

