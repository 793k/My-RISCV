module CPU (
    input  wire clk, // 系统时钟
    input  wire rst_n, // 低电平复位信号
    output wire [31:0] o_pc, // 当前 PC
    output wire [5:0] o_instr, // 当前指令
    output wire [31:0] o_reg_rd_val // ALU 结果
);

    // ============================================================
    // 架构说明：五级流水线 CPU（IF -> ID -> EX -> MEM -> WB）
    // ============================================================
    // 1. IF  (Instruction Fetch)    : 取指令，从 ROM 中读取指令
    // 2. ID  (Instruction Decode)   : 译码 + 寄存器堆读数
    // 3. EX  (Execute)              : 执行运算 / 分支跳转判断
    // 4. MEM (Memory Access)        : 访存（当前无数据存储器，直传）
    // 5. WB  (Write Back)           : 写回寄存器堆
    //
    // jal/jalr 指令在 EX 阶段产生跳转，惩罚 2 个周期
    // ============================================================

    `include "decode/decode_params.vh"

    // ============================================================
    // 全局控制信号
    // ============================================================

    wire        stall;  // 流水线暂停
    wire        flush;  // 清空 ID/EX 流水线寄存器

    wire        pc_jump_en;  // PC 跳转使能
    wire [31:0] pc_jump_addr;  // PC 跳转目标地址

    // ============================================================
    // IF Stage 信号
    // ============================================================

    wire [31:0] if_pc;  // 当前 PC 地址
    wire [31:0] if_instr;  // 从 ROM 读出的指令

    // ============================================================
    // IF/ID 流水线寄存器输出（ID 阶段输入）
    // ============================================================

    wire [31:0] id_pc;  // ID 阶段可见的 PC
    wire [31:0] id_instr;  // ID 阶段可见的指令

    // ============================================================
    // ID Stage 信号（decode 输出）
    // ============================================================

    wire [ 4:0] id_rd_idx;  // 目标寄存器索引
    wire [ 5:0] id_instr_sel;  // ALU 指令选择
    wire [ 4:0] id_rs1_idx;  // 源寄存器 1 索引
    wire [ 4:0] id_rs2_idx;  // 源寄存器 2 索引
    wire [31:0] id_rs1_val;  // 源寄存器 1 值
    wire [31:0] id_rs2_val;  // 源寄存器 2 值
    wire [31:0] id_alu_a;  // ID 阶段 ALU 操作数 A
    wire [31:0] id_alu_b;  // ID 阶段 ALU 操作数 B
    wire [31:0] id_jump_base;  // 跳转基址（PC）
    wire [31:0] id_jump_offs;  // 跳转偏移量
    wire [ 4:0] id_op_type;  // 操作类型选择

    // ============================================================
    // ID/EX 流水线寄存器输出（EX 阶段输入）
    // ============================================================

    wire [31:0] ex_jump_base;  // EX 阶段跳转基址
    wire [31:0] ex_jump_offs;  // EX 阶段跳转偏移
    wire [ 4:0] ex_rd_idx;  // EX 阶段目标寄存器索引
    wire [ 4:0] ex_rs1_idx;  // EX 阶段源寄存器 1 索引（前递用）
    wire [ 4:0] ex_rs2_idx;  // EX 阶段源寄存器 2 索引（前递用）
    wire [ 4:0] ex_op_type;  // EX 阶段操作类型选择

    // ============================================================
    // EX Stage 信号
    // ============================================================

    wire [31:0] ex_alu_a_fwd;  // 数据前递后的 ALU 操作数 A
    wire [31:0] ex_alu_b_fwd;  // 数据前递后的 ALU 操作数 B
    wire [ 5:0] ex_instr_sel;  // EX 阶段 ALU 指令选择

    wire [31:0] ex_reg_rd_val;  // ALU 运算结果
    wire [31:0] ex_jump_target;  // 跳转目标地址
    wire        ex_jump_en;  // 跳转使能
    wire        ex_reg_wr_en;  // 寄存器写使能

    wire        ex_mem_wr_en;
    wire [31:0] ex_mem_rd_idx;
    wire [31:0] ex_mem_rd_val;
    // ============================================================
    // EX/MEM 流水线寄存器输出（MEM 阶段输入）
    // ============================================================
    wire [5:0]  mem_instr_sel;
    wire [31:0] mem_reg_rd_val;  // MEM 阶段可见的 ALU 结果
    wire [31:0] mem_mem_rd_val;  // MEM 阶段可见的 ALU 结果
    wire [31:0] mem_mem_read_rd_val;  // MEM 阶段可见的 ALU 结果
    wire        mem_reg_wr_en;  // MEM 阶段可见的写使能
    wire        mem_mem_wr_en;  // MEM 阶段可见的写使能
    wire [ 4:0] mem_reg_rd_idx;  // MEM 阶段可见的目标寄存器索引
    wire [ 31:0]mem_mem_rd_idx;  // MEM 阶段可见的目标寄存器索引

    // ============================================================
    // MEM/WB 流水线寄存器输出（WB 阶段输入）
    // ============================================================

    wire        wb_reg_wr_en;  // WB 阶段寄存器写使能
    wire [ 4:0] wb_reg_rd_idx;  // WB 阶段目标寄存器索引
    wire [31:0] wb_reg_rd_val;  // WB 阶段写入寄存器的值

    // ============================================================
    // 测试接口信号（仅用于仿真调试）
    // ============================================================

    wire [31:0] dbg_jump_target;
    wire        dbg_jump_en;
    wire [ 4:0] dbg_rd_idx;
    wire [ 5:0] dbg_instr_sel;
    wire [ 4:0] dbg_rs1_idx;
    wire [ 4:0] dbg_rs2_idx;
    wire [31:0] dbg_rs1_val;
    wire [31:0] dbg_rs2_val;
    wire [31:0] dbg_alu_a;
    wire [31:0] dbg_alu_b;
    wire [31:0] dbg_jump_base;
    wire [31:0] dbg_jump_offs;
    wire        dbg_reg_wr_en;
    wire [31:0] dbg_write_val;

    // ============================================================
    // 0. 全局控制信号赋值
    // ============================================================

    assign stall = 1'b0;

    assign flush = ex_jump_en;

    assign pc_jump_en = ex_jump_en | stall;

    assign pc_jump_addr = ex_jump_en ? ex_jump_target : if_pc;

    // ============================================================
    // 1. IF Stage（取指令阶段）
    // ============================================================

    pc_count #(
        .AW(32)
    ) u_pc_count (
        .clk    (clk),
        .rst_n  (rst_n),
        .jump_en(pc_jump_en),
        .target (pc_jump_addr),
        .pc     (if_pc)
    );

    rom_32x256 u_rom (
        .address(if_pc[12:2]),
        .clock  (~clk),
        .q      (if_instr)
    );

    // rom #(
    //     .AW(32)
    // ) u_rom (
    //     .addr (if_pc),
    //     .instr(if_instr)
    // );
    // ============================================================
    // 2. IF/ID 流水线寄存器（取指 -> 译码）
    // ============================================================

    pipe_if_id u_pipe_if_id (
        .clk    (clk),
        .rst_n  (rst_n),
        .stall  (stall),
        .flush  (flush),
        .pc_i   (if_pc),
        .instr_i(if_instr),
        .pc_o   (id_pc),
        .instr_o(id_instr)
    );

    // ============================================================
    // 3. ID Stage（译码 + 寄存器堆读数）
    // ============================================================

    decode u_decode (
        .instr    (id_instr),
        .pc       (id_pc),
        .rd_idx   (id_rd_idx),
        .instr_sel(id_instr_sel),
        .rs1_idx  (id_rs1_idx),
        .rs1_val  (id_rs1_val),
        .rs2_idx  (id_rs2_idx),
        .rs2_val  (id_rs2_val),
        .alu_a    (id_alu_a),
        .alu_b    (id_alu_b),
        .jump_base(id_jump_base),
        .jump_offs(id_jump_offs),
        .op_type  (id_op_type)
    );

    regfile u_regfile (
        .clk    (clk),
        .rst_n  (rst_n),
        .wr_en  (wb_reg_wr_en),
        .wr_idx (wb_reg_rd_idx),
        .wr_data(wb_reg_rd_val),
        .rs1_idx(id_rs1_idx),
        .rs2_idx(id_rs2_idx),
        .rs1_val(id_rs1_val),
        .rs2_val(id_rs2_val)
    );

    // ============================================================
    // 4. ID/EX 流水线寄存器（译码 -> 执行）
    // ============================================================

    pipe_id_ex u_pipe_id_ex (
        .clk  (clk),
        .rst_n(rst_n),
        .flush(flush),

        .mem_reg_wr_en_i (mem_reg_wr_en),
        .mem_reg_rd_idx_i(mem_reg_rd_idx),
        .mem_reg_rd_val_i(mem_reg_rd_val),
        .wb_reg_wr_en_i  (wb_reg_wr_en),
        .wb_rd_idx_i     (wb_reg_rd_idx),
        .wb_write_val_i  (wb_reg_rd_val),

        .alu_a_i    (id_alu_a),
        .alu_b_i    (id_alu_b),
        .jump_base_i(id_jump_base),
        .jump_offs_i(id_jump_offs),
        .rd_idx_i   (id_rd_idx),
        .rs1_idx_i  (id_rs1_idx),
        .rs2_idx_i  (id_rs2_idx),
        .instr_sel_i(id_instr_sel),
        .op_type_i  (id_op_type),

        .alu_a_fwd_o(ex_alu_a_fwd),
        .alu_b_fwd_o(ex_alu_b_fwd),
        .jump_base_o(ex_jump_base),
        .jump_offs_o(ex_jump_offs),
        .alu_sel_o  (ex_instr_sel),
        .rd_idx_o   (ex_rd_idx),
        .rs1_idx_o  (ex_rs1_idx),
        .rs2_idx_o  (ex_rs2_idx),
        .op_type_o  (ex_op_type)
    );

    // ============================================================
    // 5. EX Stage（执行阶段：数据前递 + ALU 运算）
    // ============================================================

    alu u_alu (
        .alu_a_i      (ex_alu_a_fwd),
        .alu_b_i     (ex_alu_b_fwd),
        .jump_base_i  (ex_jump_base),
        .jump_offs_i  (ex_jump_offs),
        .instr_sel_i  (ex_instr_sel),

        .jump_en_o    (ex_jump_en),
        .jump_target_o(ex_jump_target),//跳转指令不经过mem和wr阶段

        .reg_wr_en_o  (ex_reg_wr_en),
        .result_o     (ex_reg_rd_val),//用于写入reg寄存器的值
    
        .mem_wr_en_o  (ex_mem_wr_en),
        .mem_rd_idx_o (ex_mem_rd_idx),
        .mem_rd_val_o (ex_mem_rd_val)//用于mem阶段的值
    );

    // ============================================================
    // 6. EX/MEM 流水线寄存器（执行 -> 访存）
    // ============================================================

    pipe_ex_mem u_pipe_ex_mem (
        .clk(clk),
        .rst_n(rst_n),

        .reg_rd_idx_i(ex_rd_idx),//不过alu直传
        .instr_sel_i(ex_instr_sel),//不过alu直传

        .reg_wr_en_i(ex_reg_wr_en),
        .reg_rd_val_i(ex_reg_rd_val),

        .mem_wr_en_i(ex_mem_wr_en),
        .mem_wr_idx_i(ex_mem_rd_idx),
        .mem_wr_val_i(ex_mem_rd_val),
        
        .reg_wr_en_o(mem_reg_wr_en),
        .reg_rd_idx_o(mem_reg_rd_idx),
        .reg_rd_val_o(mem_reg_rd_val),
        .mem_wr_en_o(mem_mem_wr_en),
        .mem_wr_idx_o(mem_mem_rd_idx),
        .mem_wr_val_o(mem_mem_rd_val),
        .instr_sel_o(mem_instr_sel)
    );

    // ============================================================
    // 7. MEM Stage（访存阶段）
    // ============================================================
    // 当前无数据存储器（DM），本阶段为直传
    // 后续添加 LSU 时可在此接入数据 SRAM 读写
    // ============================================================
    mem_ctrl u_mem_ctrl(
        .clk(clk),
        .reg_rd_val_i(mem_reg_rd_val),
        .mem_wr_en_i(mem_mem_wr_en),
        .mem_rd_idx_i(mem_mem_rd_idx),
        .mem_rd_val_i(mem_mem_rd_val),
        .mem_instr_sel_i(mem_instr_sel),
        .q_val_o(mem_mem_read_rd_val)
    );
    // ============================================================
    // 8. MEM/WB 流水线寄存器（访存 -> 写回）
    // ============================================================
    pipe_mem_wr u_pipe_mem_wr (
        .clk(clk),
        .rst_n(rst_n),

        .reg_wr_en_i(mem_reg_wr_en),
        .reg_rd_idx_i(mem_reg_rd_idx),
        .reg_rd_val_i(mem_mem_read_rd_val),

        .reg_wr_en_o(wb_reg_wr_en),
        .reg_rd_idx_o(wb_reg_rd_idx),
        .reg_rd_val_o(wb_reg_rd_val)
    );

    // ============================================================
    // 9. WB Stage（写回阶段）
    // ============================================================
    // 寄存器写回由 regfile 的 wr_en/wr_idx/wr_data 端口完成
    // 连接见上方 regfile 实例化（接 wb_* 信号）
    // ============================================================
    // ============================================================
    // 10. 测试接口赋值
    // ============================================================

    assign dbg_jump_target = ex_jump_target;

    assign dbg_jump_en = ex_jump_en;

    assign dbg_rd_idx = id_rd_idx;

    assign dbg_instr_sel = id_instr_sel;

    assign dbg_rs1_idx = id_rs1_idx;

    assign dbg_rs2_idx = id_rs2_idx;

    assign dbg_rs1_val = id_rs1_val;

    assign dbg_rs2_val = id_rs2_val;

    assign dbg_alu_a = id_alu_a;

    assign dbg_alu_b = id_alu_b;

    assign dbg_jump_base = id_jump_base;

    assign dbg_jump_offs = id_jump_offs;

    assign dbg_reg_wr_en = wb_reg_wr_en;

    assign dbg_write_val = wb_reg_rd_val;

    // 顶层输出信号

    assign o_pc = if_pc;

    assign o_instr = id_instr_sel;

    assign o_reg_rd_val = ex_reg_rd_val;

endmodule

