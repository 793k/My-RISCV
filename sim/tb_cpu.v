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
    // PC 子模块
    // wire [31:0] sim_pc_out;       assign sim_pc_out = u_cpu.u_pc_count.out_addr;
    // ROM 子模块
    // wire [31:0] sim_rom_out;      assign sim_rom_out = u_cpu.u_rom.instr_out;
    // 寄存器堆内部 32 个寄存器（假设 regfile 内部数组名叫 regs）
    // 如果你的 regfile 里寄存器数组不叫 regs，请改成实际名字
    wire [31:0] sim_regs[0:31];
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gen_reg_probe

            assign sim_regs[gi] = u_cpu.u_regfile.regs[gi];
        end
    endgenerate

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

