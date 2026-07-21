/*
 * 系统调用 — 仅 _exit 走 ECALL, 发送在 main.c 里裸机操作
 */

#define UART_BASE   ((volatile unsigned int *)0x80000000)
#define UART_CTRL   (*(UART_BASE + 2))

void uart_init(void) {
    UART_CTRL = 3;  // en(1) | tx_ie(2)
}

void _exit(int code) {
    register int num asm("a0") = 93;
    register int arg1 asm("a1") = code;
    asm volatile ("ecall" : : "r"(num), "r"(arg1) : "memory");
    while (1);
}
