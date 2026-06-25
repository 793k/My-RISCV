`timescale 1ns / 1ps

module tb_cpu;

    reg clk;
    reg rst_n;

    // ── DUT ──
    wire uart_txd;
    CPU u_cpu (
        .clk        (clk),
        .rst_n      (rst_n),
        .o_uart_txd (uart_txd)
    );

    // ================================================================
    // IF 阶段
    // ================================================================
    wire [31:0] if_pc     = u_cpu.if_pc;
    wire [31:0] if_instr  = u_cpu.if_instr;

    // ================================================================
    // ID 阶段
    // ================================================================
    wire [31:0] id_pc       = u_cpu.id_pc;
    wire [31:0] id_instr    = u_cpu.id_instr;
    wire [4:0]  id_rd       = u_cpu.dbg_rd_idx;
    wire [5:0]  id_sel      = u_cpu.dbg_instr_sel;
    wire [4:0]  id_rs1_idx  = u_cpu.dbg_rs1_idx;
    wire [4:0]  id_rs2_idx  = u_cpu.dbg_rs2_idx;
    wire [31:0] id_rs1_val  = u_cpu.dbg_rs1_val;
    wire [31:0] id_rs2_val  = u_cpu.dbg_rs2_val;
    wire [31:0] id_alu_a    = u_cpu.dbg_alu_a;
    wire [31:0] id_alu_b    = u_cpu.dbg_alu_b;
    wire [31:0] id_jmp_base = u_cpu.dbg_jump_base;
    wire [31:0] id_jmp_offs = u_cpu.dbg_jump_offs;

    // ================================================================
    // EX 阶段
    // ================================================================
    wire [31:0] ex_result   = u_cpu.ex_reg_rd_val;
    wire        ex_wr_en    = u_cpu.ex_reg_wr_en;
    wire [31:0] ex_jmp_tgt  = u_cpu.dbg_jump_target;
    wire        ex_jmp_en   = u_cpu.dbg_jump_en;

    // ================================================================
    // MEM / 总线阶段
    // ================================================================
    wire [31:0] bus_addr        = u_cpu.bus_addr;
    wire [31:0] bus_wdata       = u_cpu.bus_wdata;
    wire        bus_wen         = u_cpu.bus_wen;
    wire [31:0] bus_rdata_mux   = u_cpu.bus_rdata;
    wire [31:0] bus_alu         = u_cpu.bus_alu_rdata;
    wire [5:0]  bus_instr       = u_cpu.bus_instr_sel;

    // 片选
    wire        cs_ram          = u_cpu.cs_ram_we;
    wire        cs_uart_we      = u_cpu.cs_uart_we;
    wire        cs_uart_re      = u_cpu.cs_uart_re;

    // 外设响应
    wire [31:0] rsp_ram         = u_cpu.rsp_ram;
    wire [31:0] rsp_rom         = u_cpu.rsp_rom;
    wire [31:0] rsp_uart        = u_cpu.rsp_uart;

    // ================================================================
    // WB 阶段
    // ================================================================
    wire        wb_wr_en  = u_cpu.wb_reg_wr_en;
    wire [4:0]  wb_rd     = u_cpu.wb_reg_rd_idx;
    wire [31:0] wb_wdata  = u_cpu.wb_reg_rd_val;

    // ================================================================
    // ALU 内部
    // ================================================================
    wire [31:0] alu_result     = u_cpu.u_alu.result_o;
    wire [31:0] alu_jmp_tgt    = u_cpu.u_alu.jump_target_o;
    wire        alu_jmp_en     = u_cpu.u_alu.jump_en_o;
    wire        alu_wr_en      = u_cpu.u_alu.reg_wr_en_o;
    wire [31:0] alu_mem_addr   = u_cpu.u_alu.mem_rd_idx_o;
    wire [31:0] alu_mem_wdata  = u_cpu.u_alu.mem_rd_val_o;
    wire        alu_mem_wen    = u_cpu.u_alu.mem_wr_en_o;

    // ================================================================
    // UART
    // ================================================================
    wire uart_txd_loop = uart_txd;
    wire [1:0]  uart_tx_state = u_cpu.u_uart.tx_state;
    wire [1:0]  uart_rx_state = u_cpu.u_uart.rx_state;
    wire        uart_tx_busy  = u_cpu.u_uart.tx_busy;
    wire [15:0] uart_baud     = u_cpu.u_uart.baud_div;
    wire [2:0]  uart_ctrl     = u_cpu.u_uart.ctrl;

    // ================================================================
    // 寄存器组
    // ================================================================
    wire [31:0] regs [0:31];
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gen_reg_probe
            assign regs[gi] = u_cpu.u_regfile.regs[gi];
        end
    endgenerate

    wire [31:0] reg_x0  = regs[0];
    wire [31:0] reg_ra  = regs[1];
    wire [31:0] reg_sp  = regs[2];
    wire [31:0] reg_gp  = regs[3];
    wire [31:0] reg_t0  = regs[5];
    wire [31:0] reg_t1  = regs[6];
    wire [31:0] reg_t2  = regs[7];
    wire [31:0] reg_s0  = regs[8];
    wire [31:0] reg_s1  = regs[9];
    wire [31:0] reg_a0  = regs[10];
    wire [31:0] reg_a1  = regs[11];
    wire [31:0] reg_a2  = regs[12];
    wire [31:0] reg_s10 = regs[26];
    wire [31:0] reg_s11 = regs[27];

    // ================================================================
    // 时钟 & 复位
    // ================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
        #5000;
        $display(">>> Simulation finished at %0t ns", $time);
        $finish;
    end

    // ================================================================
    // 波形 Dump
    // ================================================================
    initial begin
        $dumpfile("cpu_wave.vcd");
        $dumpvars(0, tb_cpu);
    end

    // ================================================================
    // 终端打印
    // ================================================================
    always @(posedge clk) begin
        if (rst_n) begin
            $display(
                "T=%0t | PC=%08X Instr=%08X | rs1=%02d(%08X) rs2=%02d(%08X) | rd=%02d WE=%b WD=%08X | bus WE=%b ADDR=%08X RD=%08X | JMP=%b -> %08X",
                $time,
                if_pc, if_instr,
                id_rs1_idx, id_rs1_val,
                id_rs2_idx, id_rs2_val,
                id_rd, wb_wr_en, wb_wdata,
                bus_wen, bus_addr, bus_rdata_mux,
                ex_jmp_en, ex_jmp_tgt
            );
        end
    end

endmodule
