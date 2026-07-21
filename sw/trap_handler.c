/*
 * trap_handler.c — M-mode Trap Handler (编译器自动保存/恢复寄存器)
 *
 * ECALL (code=11)  → 仅处理 _exit (sysnum=93)
 * UART TX 中断      → 空返回 (只验证中断线能拉起来)
 */

#include <stdint.h>

#define UART_BASE   ((volatile uint32_t *)0x80000000)

__attribute__((interrupt("machine")))
void trap_entry(void) {
    uint32_t mcause, mepc, code, sysnum;

    asm volatile ("csrr %0, 0x342" : "=r"(mcause));
    code = mcause & 0x7FFFFFFF;

    if ((mcause >> 31) == 0) {
        // === 异常 ===
        if (code == 11) {   // ECALL
            asm volatile ("mv %0, a0" : "=r"(sysnum));

            if (sysnum == 93) {     // _exit
                asm volatile ("wfi");
                while (1);
            }

            asm volatile ("csrr %0, 0x341" : "=r"(mepc));
            mepc += 4;
            asm volatile ("csrw 0x341, %0" :: "r"(mepc));
        }
        return;
    }

    // === UART TX 中断 ===
    // 写 1 到 STATUS[4] 清 tx_done 锁存位, tx_ie 保持使能, 下次发完再触发
    *(UART_BASE + 1) = 0x10;   // STATUS bit4=1, 其余=0
}
