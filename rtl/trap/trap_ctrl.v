// =============================================================================
// Trap 统一决策模块
// =============================================================================
// 组合逻辑判断本周期要不要 trap, 异常优先级 > 中断。
// 同时处理异常 (同步于指令) 和中断 (异步, 在指令边界检查)。
// =============================================================================

module trap_ctrl (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [ 5:0] instr_sel_i,
    input  wire [31:0] ex_pc_i,

    input  wire        mstatus_mie_i,  // mstatus[3]: 中断总开关
    input  wire [31:0] mie_i,
    input  wire [31:0] mip_i,

    output wire        trap_taken_o,
    output wire [31:0] trap_pc_o,
    output wire [31:0] trap_cause_o,
    output wire [31:0] trap_tval_o
);

    `include "../decode/decode_params.vh"

    // === 异常条件 ===
    wire exception_ecall   = (instr_sel_i == `instr_sel_ecall);
    wire exception_ebreak  = (instr_sel_i == `instr_sel_ebreak);
    wire exception_illegal = 1'b0;

    wire any_exception = exception_ecall | exception_ebreak | exception_illegal;

    // === 中断条件 ===
    wire interrupt_meip  = (mip_i[11] & mie_i[11]);  // 外部中断 (UART)
    wire interrupt_mtip  = (mip_i[7]  & mie_i[7]);   // Timer 中断 (预留)
    wire interrupt_msip  = (mip_i[3]  & mie_i[3]);   // 软件中断 (预留)

    wire any_interrupt = mstatus_mie_i & (interrupt_meip | interrupt_mtip | interrupt_msip);

    // === 组合逻辑输出 ===
    assign trap_taken_o = any_exception | any_interrupt;

    // trap_pc: 异常记当前指令, 中断记下一条
    assign trap_pc_o = any_exception ? ex_pc_i :
                       any_interrupt ? (ex_pc_i + 32'd4) :
                       32'd0;

    // trap_cause: 异常 bit31=0, 中断 bit31=1
    wire [31:0] exception_cause = exception_ecall  ? 32'd11 :
                                  exception_ebreak ? 32'd3  :
                                                     32'd2;  // illegal

    wire [31:0] interrupt_cause = interrupt_meip ? {1'b1, 27'd0, 4'd11} :  // MEIP: bit31=1, cause=11
                                  interrupt_mtip ? {1'b1, 27'd0, 4'd7}  :  // MTIP: bit31=1, cause=7
                                  interrupt_msip ? {1'b1, 27'd0, 4'd3}  :  // MSIP: bit31=1, cause=3
                                                   32'd0;

    assign trap_cause_o = any_exception ? exception_cause :
                          any_interrupt ? interrupt_cause :
                          32'd0;

    // trap_tval: 异常存指令编码, 中断无附加信息
    wire [31:0] exception_tval = exception_ecall  ? 32'h00000073 :
                                 exception_ebreak ? 32'h00100073 :
                                                    32'd0;

    assign trap_tval_o = any_exception ? exception_tval : 32'd0;

endmodule
