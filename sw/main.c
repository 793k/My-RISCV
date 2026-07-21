/*
 * 用户 C 程序入口 — 裸机直接写 UART
 *
 * 发送: main.c 里轮询 UART_STATUS, 逐字节写 UART_DATA (不走 ECALL/trap)
 * 中断: 每发完一个字节, UART 硬件 irq → trap → handler 空返回
 *
 * UART 寄存器:
 *   0x80000000 = DATA      0x80000004 = STATUS (bit0=tx_full)
 *   0x80000008 = CTRL         bit0=使能, bit1=TX中断
 */

#define UART_BASE   ((volatile unsigned int *)0x80000000)
#define UART_DATA   (*(UART_BASE + 0))
#define UART_STATUS (*(UART_BASE + 1))
#define UART_CTRL   (*(UART_BASE + 2))

extern void _exit(int code);

void uart_init(void) {
    UART_CTRL = 3;  // en(1) | tx_ie(2) → TX 中断使能
}

static const char msg[] = "RISC-V bare-metal + UART TX IRQ\n";

int main(void) {
    uart_init();

    // 裸机发送: 逐字节轮询, 每塞一个字节到 FIFO 就等它发完
    for (int i = 0; msg[i]; i++) {
        while (UART_STATUS & 1);    // bit0=tx_full, 满了就等
        UART_DATA = (unsigned int)(unsigned char)msg[i];
    }

    // 死循环 — UART 每发完一个字节就触发中断, handler 里是空的
    volatile int x = 0;
    while (1) {
        x++;
    }

    _exit(0);
    return 0;
}
