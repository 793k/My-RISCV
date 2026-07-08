/*
 * 用户 C 程序入口
 *
 * 执行流程：
 *   _start(crt0.S) → 初始化 sp/gp → 复制 .rodata 到 RAM → 清零 .bss → call main
 *   main → _write("Hello from RISC-V!\n") → _putchar 逐字节写 UART
 */
extern void _write(int fd, const char *buf, int len);
extern void uart_init(void);

static const char msg[] = "Hello from RISC-V!\n";

int main(void) {
    uart_init();
    _write(1, msg, sizeof(msg) - 1);
    // for(int i = 0; i < 10; i++)
    //     _write(1, msg, sizeof(msg) - 1);
    return 0;
}
