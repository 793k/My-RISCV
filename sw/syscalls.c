/*
 * 系统调用桩（syscalls）—— 当前阶段绕过 ECALL/MRET，直接操作 UART 硬件寄存器
 *
 * 硬件映射（由 rtl/mem/addr_decoder.v 完成地址译码）：
 *   0x80000000 → UART_DATA   （写 = 发送 FIFO，读 = 接收 FIFO）
 *   0x80000004 → UART_STATUS （bit0=tx_full, bit1=rx_empty, bit2=tx_busy）
 *   0x80000008 → UART_CTRL   （bit0=使能, bit1=tx中断, bit2=rx中断）
 *   0x8000000C → UART_BAUD   （分频值 = 时钟频率 / 目标波特率）
 *
 * 编译为 RV32I 后，这里的每次读写会变成 lw/sw 指令，
 * CPU MEM 阶段 → addr_decoder 识别 0x80xxxxxx → 路由到 UART 控制器。
 */

#define UART_BASE   ((volatile unsigned int *)0x80000000)
#define UART_DATA   (*(UART_BASE + 0))
#define UART_STATUS (*(UART_BASE + 1))
#define UART_CTRL   (*(UART_BASE + 2))
#define UART_BAUD   (*(UART_BASE + 3))

/*
 * UART 初始化（PLL 模式：CLK=48 MHz）
 * baud_div 使用硬件默认值，由 uart.v 的 localparam BAUD_DIV_DEFAULT 决定
 */
void uart_init(void) {
    UART_CTRL = 1;                  // bit0=使能 TX
}

/*
 * 发送一个字符到 UART TX
 * 流程：轮询 STATUS 直到 TX FIFO 不满（tx_full=0），然后写入 DATA 寄存器
 */
void _putchar(char c) {
    while (UART_STATUS & 1);  /* 等待 UART TX FIFO 有空位 */
    UART_DATA = (unsigned int)(unsigned char)c;
    /* 等待当前字符传输完成，避免背靠背写入导致帧错位 */
    while (UART_STATUS & 4);  /* 等待 tx_busy 清除 */
}

static void delay_ms(int ms) {
    for (volatile int i = 0; i < ms * 500; i++);
}

/*
 * 向 fd 写入 len 个字节
 */
void _write(int fd, const char *buf, int len) {
    (void)fd;
    for (int i = 0; i < len; i++) {
        _putchar(buf[i]);
        delay_ms(1);
    }
}

/*
 * 程序退出（当前死循环，后续实现 ECALL → machine mode → 关机）
 */
void _exit(int code) {
    (void)code;
    while (1);
}
