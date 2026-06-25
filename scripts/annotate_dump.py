#!/usr/bin/env python3
"""为 objdump 反汇编输出添加中文注释，输出到 program_annotated.dump"""
import re, sys

def annotate(lines):
    out = []
    for line in lines:
        s = line.rstrip()
        # 函数入口
        if re.match(r'^[0-9a-f]+ <(\w+)>:', s):
            name = re.match(r'^[0-9a-f]+ <(\w+)>:', s).group(1)
            out.append(s)
            comments = {
                '_start':  '; ---------- 硬件复位入口：设置 sp/gp，复制 .rodata/.data 到 RAM，清零 .bss，调用 main ----------',
                '_putchar':'; ---------- 发送一个字符到 UART：轮询 STATUS 直到 TX FIFO 有空位，写 DATA ----------',
                '_write':  '; ---------- 向 fd 写 len 字节：逐字节调用 _putchar ----------',
                '_exit':   '; ---------- 死循环（后续替换为 ECALL 关机）----------',
                'main':    '; ---------- 主函数：_write(1, msg, 19) → 返回 0 ----------',
            }
            if name in comments:
                out.append('    ' + comments[name])
            continue
        # 指令行
        m = re.match(r'^\s*([0-9a-f]+):\s+([0-9a-f]+)\s+(.+)$', s, re.IGNORECASE)
        if m:
            addr, enc, instr = m.group(1), m.group(2), m.group(3)
            comment = ''
            # 关键指令注释
            if 'lui\ta4,0x80000' in instr:
                comment = '; a4 = UART 基址 0x80000000'
            elif 'lw\ta5,4(a4)' in instr and '80000004' in instr:
                comment = '; a5 = UART_STATUS（读状态寄存器）'
            elif 'andi\ta5,a5,1' in instr:
                comment = '; 检查 tx_full 位（bit0）'
            elif 'bnez\ta5,' in instr and '98' in instr:
                comment = '; 如果 FIFO 满则循环等待'
            elif 'sw\ta0,0(a4)' in instr and '80000000' in s:
                comment = '; UART_DATA = 字符 c'
            elif 'ret' in instr:
                comment = '; 返回调用者'
            elif 'lbu\ta0,0(a5)' in instr:
                comment = '; a0 = buf[i]（从 RAM 读一个字节）'
            elif 'jal\tra,94' in instr or 'jal\tra,ac' in instr:
                comment = '; 调用子函数'
            elif 'addi\tsp,sp,-' in instr:
                comment = '; 分配栈帧'
            elif 'li\ta0,1' in instr and '00100513' in s:
                comment = '; fd = 1'
            elif 'li\ta2,19' in instr:
                comment = '; len = 19（字符串长度）'
            elif 'lui\ta1,0x1' in instr:
                comment = '; a1 = 0x1000（字符串 "Hello from RISC-V!\\n" 的 RAM VMA）'
            elif 'jal\tra,f8' in instr or 'jal\tra,ec' in instr:
                comment = '; call main()'
            elif 'li\ta0,0' in instr and '00000513' in s:
                comment = '; return 0'
            out.append(f'    {addr}:  {enc}  {instr}{" "*(40-len(instr))}{comment}')
            continue
        out.append(s)
    return out

if __name__ == '__main__':
    if len(sys.argv) < 2:
        lines = sys.stdin.buffer.read().decode('utf-8', errors='replace').splitlines(True)
    else:
        with open(sys.argv[1], 'r', encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
    result = '\n'.join(annotate(lines))
    if len(sys.argv) >= 3:
        with open(sys.argv[2], 'w', encoding='utf-8') as f:
            f.write(result)
        print(f'Annotated: {sys.argv[2]}')
    else:
        sys.stdout.buffer.write(result.encode('utf-8'))
