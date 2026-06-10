module CPU (
    input wire clk,     // 系统时钟
    input wire rst_n    // 低电平复位信号
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

    wire        stall;                // 流水线暂停
    wire        flush;                // 清空 ID/EX 流水线寄存器

    wire        pc_jump_en;           // PC 跳转使能
    wire [31:0] pc_jump_addr;         // PC 跳转目标地址

    // ============================================================
    // IF Stage 信号
    // ============================================================

    wire [31:0] pc_addr;              // 当前 PC 地址
    wire [31:0] instr;                // 从 ROM 读出的指令

    // ============================================================
    // IF/ID 流水线寄存器
    // ============================================================

    reg  [31:0] if_id_pc;             // ID 阶段可见的 PC
    reg  [31:0] if_id_instr;          // ID 阶段可见的指令

    // ============================================================
    // ID Stage 信号
    // ============================================================

    wire [ 4:0] id_rd_addr;           // 目标寄存器地址
    wire [ 5:0] id_instr_sel;         // ALU 指令选择
    wire [ 4:0] id_rs1_addr;          // 源寄存器 1 地址
    wire [ 4:0] id_rs2_addr;          // 源寄存器 2 地址
    wire [31:0] id_rs1_data;          // 源寄存器 1 数据
    wire [31:0] id_rs2_data;          // 源寄存器 2 数据
    wire [31:0] id_op1;               // ALU 操作数 1
    wire [31:0] id_op2;               // ALU 操作数 2
    wire [31:0] id_jump_op1;          // 跳转操作数 1（PC）
    wire [31:0] id_jump_op2;          // 跳转操作数 2（立即数）
    wire [ 4:0] id_op_sel;            // 操作类型选择

    // ============================================================
    // ID/EX 流水线寄存器
    // ============================================================

    reg  [31:0] id_ex_op1;            // EX 阶段 ALU 操作数 1
    reg  [31:0] id_ex_op2;            // EX 阶段 ALU 操作数 2
    reg  [31:0] id_ex_jump_op1;       // EX 阶段跳转操作数 1
    reg  [31:0] id_ex_jump_op2;       // EX 阶段跳转操作数 2
    reg  [ 4:0] id_ex_rd_addr;        // EX 阶段目标寄存器地址
    reg  [ 4:0] id_ex_rs1_addr;       // EX 阶段源寄存器 1 地址（前递用）
    reg  [ 4:0] id_ex_rs2_addr;       // EX 阶段源寄存器 2 地址（前递用）
    reg  [ 5:0] id_ex_instr_sel;      // EX 阶段 ALU 指令选择
    reg  [ 4:0] id_ex_op_sel;         // EX 阶段操作类型选择

    // ============================================================
    // EX Stage 信号
    // ============================================================

    reg  [31:0] alu_op1;              // 数据前递后的 ALU 操作数 1
    reg  [31:0] alu_op2;              // 数据前递后的 ALU 操作数 2

    wire [ 5:0] alu_instr_sel;        // bubble 处理后的 ALU 指令选择

    wire [31:0] ex_rd_data;           // ALU 运算结果
    wire [31:0] ex_jump_addr;         // 跳转目标地址
    wire        ex_jump_en;           // 跳转使能
    wire        ex_wr_en;             // 寄存器写使能

    // ============================================================
    // EX/MEM 流水线寄存器
    // ============================================================

    reg  [31:0] ex_mem_rd_data;       // MEM 阶段可见的 ALU 结果
    reg         ex_mem_wr_en;         // MEM 阶段可见的写使能
    reg  [ 4:0] ex_mem_rd_addr;       // MEM 阶段可见的目标寄存器地址

    // ============================================================
    // MEM/WB 流水线寄存器
    // ============================================================

    reg  [31:0] mem_wb_rd_data;       // WB 阶段写入寄存器的数据
    reg         mem_wb_wr_en;         // WB 阶段寄存器写使能
    reg  [ 4:0] mem_wb_rd_addr;       // WB 阶段目标寄存器地址

    // ============================================================
    // 测试接口信号
    // ============================================================

    wire [31:0] jump_addr;
    wire        jump_en;
    wire [ 4:0] rd_addr;
    wire [ 5:0] instr_sel;
    wire [ 4:0] rs1_addr;
    wire [ 4:0] rs2_addr;
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] op1;
    wire [31:0] op2;
    wire [31:0] jump_op1;
    wire [31:0] jump_op2;
    wire        wr_en;
    wire [31:0] rd_data;

    // ============================================================
    // 0. 全局控制信号赋值
    // ============================================================

    assign stall       = 1'b0;
    assign flush       = ex_jump_en;

    assign pc_jump_en   = ex_jump_en | stall;
    assign pc_jump_addr = ex_jump_en ? ex_jump_addr : pc_addr;

    // ============================================================
    // 1. IF Stage（取指令阶段）
    // ============================================================

    pc_count #(
        .AW(32)
    ) u_pc_count (
        .clk      (clk),
        .rst_n    (rst_n),
        .jump_en  (pc_jump_en),
        .jump_addr(pc_jump_addr),
        .out_addr (pc_addr)
    );

    rom #(
        .AW(32)
    ) u_rom (
        .instr_addr(pc_addr),
        .instr_out (instr)
    );

    // ============================================================
    // 2. IF/ID 流水线寄存器（取指 -> 译码）
    // ============================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc    <= 32'd0;
            if_id_instr <= 32'h00000013;       // 默认填充 NOP
        end else if (stall) begin

        end else if (flush) begin
            if_id_pc    <= if_id_pc;
            if_id_instr <= 32'h00000013;
        end else begin
            if_id_pc    <= pc_addr;
            if_id_instr <= instr;
        end
    end

    // ============================================================
    // 3. ID Stage（译码 + 寄存器堆读数）
    // ============================================================

    decode u_decode (
        .instr    (if_id_instr),
        .pc_count (if_id_pc),
        .rd_addr  (id_rd_addr),
        .instr_sel(id_instr_sel),
        .rs1_addr (id_rs1_addr),
        .rs1_data (id_rs1_data),
        .rs2_addr (id_rs2_addr),
        .rs2_data (id_rs2_data),
        .op1      (id_op1),
        .op2      (id_op2),
        .jump_op1 (id_jump_op1),
        .jump_op2 (id_jump_op2),
        .op_sel   (id_op_sel)
    );

    regfile u_regfile (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (mem_wb_wr_en),
        .wr_addr (mem_wb_rd_addr),
        .wr_data (mem_wb_rd_data),
        .rs1_addr(id_rs1_addr),
        .rs2_addr(id_rs2_addr),
        .rs1_data(id_rs1_data),
        .rs2_data(id_rs2_data)
    );

    // ============================================================
    // 4. ID/EX 流水线寄存器（译码 -> 执行）
    // ============================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_op1       <= 32'd0;
            id_ex_op2       <= 32'd0;
            id_ex_jump_op1  <= 32'd0;
            id_ex_jump_op2  <= 32'd0;
            id_ex_rd_addr   <= 5'd0;
            id_ex_rs1_addr  <= 5'd0;
            id_ex_rs2_addr  <= 5'd0;
            id_ex_instr_sel <= `instr_sel_addi;  // NOP
            id_ex_op_sel    <= `op_sel_I;
        end else if (flush) begin
            id_ex_op1       <= 32'd0;
            id_ex_op2       <= 32'd0;
            id_ex_jump_op1  <= 32'd0;
            id_ex_jump_op2  <= 32'd0;
            id_ex_rd_addr   <= 5'd0;
            id_ex_rs1_addr  <= 5'd0;
            id_ex_rs2_addr  <= 5'd0;
            id_ex_instr_sel <= `instr_sel_addi;  // NOP
            id_ex_op_sel    <= `op_sel_I;
        end else begin
            id_ex_op1       <= id_op1;
            id_ex_op2       <= id_op2;
            id_ex_jump_op1  <= id_jump_op1;
            id_ex_jump_op2  <= id_jump_op2;
            id_ex_rd_addr   <= id_rd_addr;
            id_ex_rs1_addr  <= id_rs1_addr;
            id_ex_rs2_addr  <= id_rs2_addr;
            id_ex_instr_sel <= id_instr_sel;
            id_ex_op_sel    <= id_op_sel;
        end
    end

    // ============================================================
    // 5. EX Stage（执行阶段：数据前递 + ALU 运算）
    // ============================================================

    // op1（rs1）前递逻辑
    always @(*) begin
        if (ex_mem_wr_en && (ex_mem_rd_addr != 5'd0)
            && (ex_mem_rd_addr == id_ex_rs1_addr)) begin
            alu_op1 = ex_mem_rd_data;
        end else if (mem_wb_wr_en && (mem_wb_rd_addr != 5'd0)
            && (mem_wb_rd_addr == id_ex_rs1_addr)) begin
            alu_op1 = mem_wb_rd_data;
        end else begin
            alu_op1 = id_ex_op1;
        end
    end

    // op2（rs2）前递逻辑
    always @(*) begin
        if ((id_ex_op_sel == `op_sel_R || id_ex_op_sel == `op_sel_branch)
            && ex_mem_wr_en && (ex_mem_rd_addr != 5'd0)
            && (ex_mem_rd_addr == id_ex_rs2_addr)) begin
            alu_op2 = ex_mem_rd_data;
        end else if ((id_ex_op_sel == `op_sel_R || id_ex_op_sel == `op_sel_branch)
            && mem_wb_wr_en && (mem_wb_rd_addr != 5'd0)
            && (mem_wb_rd_addr == id_ex_rs2_addr)) begin
            alu_op2 = mem_wb_rd_data;
        end else begin
            alu_op2 = id_ex_op2;
        end
    end

    // bubble 处理
    assign alu_instr_sel = id_ex_instr_sel;

    // ALU 实例化
    alu u_alu (
        .op1      (alu_op1),
        .op2      (alu_op2),
        .jump_op1 (id_ex_jump_op1),
        .jump_op2 (id_ex_jump_op2),
        .instr_sel(alu_instr_sel),
        .rd_data  (ex_rd_data),
        .jump_addr(ex_jump_addr),
        .jump_en  (ex_jump_en),
        .wr_en    (ex_wr_en)
    );

    // ============================================================
    // 6. EX/MEM 流水线寄存器（执行 -> 访存）
    // ============================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_rd_data   <= 32'd0;
            ex_mem_wr_en     <= 1'd0;
            ex_mem_rd_addr   <= 5'd0;
        end else begin
            ex_mem_rd_data   <= ex_rd_data;
            ex_mem_wr_en     <= ex_wr_en;
            ex_mem_rd_addr   <= id_ex_rd_addr;
        end
    end

    // ============================================================
    // 7. MEM Stage（访存阶段）
    // ============================================================
    // 当前无数据存储器（DM），本阶段为直传
    // 后续添加 LSU 时可在此接入数据 SRAM 读写
    // ============================================================

    // ============================================================
    // 8. MEM/WB 流水线寄存器（访存 -> 写回）
    // ============================================================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_rd_data <= 32'd0;
            mem_wb_wr_en   <= 1'd0;
            mem_wb_rd_addr <= 5'd0;
        end else begin
            mem_wb_rd_data <= ex_mem_rd_data;
            mem_wb_wr_en   <= ex_mem_wr_en;
            mem_wb_rd_addr <= ex_mem_rd_addr;
        end
    end

    // ============================================================
    // 9. WB Stage（写回阶段）
    // ============================================================
    // 寄存器写回由 regfile 的 wr_en/wr_addr/wr_data 端口完成
    // 连接见上方 regfile 实例化（接 mem_wb_* 信号）
    // ============================================================

    // ============================================================
    // 10. 测试接口赋值
    // ============================================================

    assign jump_addr  = ex_jump_addr;
    assign jump_en    = ex_jump_en;
    assign rd_addr    = id_rd_addr;
    assign instr_sel  = id_instr_sel;
    assign rs1_addr   = id_rs1_addr;
    assign rs2_addr   = id_rs2_addr;
    assign rs1_data   = id_rs1_data;
    assign rs2_data   = id_rs2_data;
    assign op1        = id_op1;
    assign op2        = id_op2;
    assign jump_op1   = id_jump_op1;
    assign jump_op2   = id_jump_op2;
    assign wr_en      = mem_wb_wr_en;
    assign rd_data    = mem_wb_rd_data;

endmodule
