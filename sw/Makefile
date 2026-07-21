# ================================================================
# RISC-V GCC 编译 Makefile — My-RISCV CPU
# ================================================================
# 功能：将 C/汇编源码编译为 RV32I ELF，提取 text/rodata 段，
#       生成 Quartus ROM/RAM MIF 文件，供 ModelSim 仿真或 FPGA 烧录。
#
# 用法：cd sw && make        # 编译 + MIF 全流程
#       cd sw && make clean  # 删除所有中间文件
# ================================================================

SHELL = cmd

# ================================================================
# 一、RISC-V 工具链路径
# ================================================================
# GCC_ROOT：你的工具链根目录（预编译包，rv32imafc 多架构版本）
# CROSS   ：交叉编译前缀，后续自动拼接 gcc/objcopy/objdump/size

GCC_ROOT  := ../environment/riscv32-unknown-elf-gcc-8.3.0_rv32imafc_ilp32f_newlib
CROSS     := $(GCC_ROOT)/bin/riscv32-unknown-elf

CC        = $(CROSS)-gcc       # C/汇编编译器
OBJCOPY   = $(CROSS)-objcopy   # 段提取、格式转换
OBJDUMP   = $(CROSS)-objdump   # 反汇编（反斜杠版用于 cmd /c 的 > 重定向）
OD_WIN    = $(subst /,\,$(OBJDUMP))
SIZE      = $(CROSS)-size      # 段大小统计
PYTHON    = python

# ================================================================
# 二、编译参数
# ================================================================
ARCH      = rv32i               # 目标指令集：仅 RV32I 基础整数
                                 #   不生成 M(乘除)/A(原子)/F(单精度浮点)
                                 #   /C(压缩指令)/D(双精度浮点) 扩展
ABI       = ilp32               # 数据模型：int=32, long=32, pointer=32
                                 #   （你的 CPU 是 32 位，所有类型 4 字节）

CFLAGS   := -march=$(ARCH) -mabi=$(ABI)
CFLAGS   += -nostdlib           # 不链接标准 C 库（libc）
                                 #   因为没有 OS，malloc/printf 等无法工作
CFLAGS   += -nostartfiles       # 不链接默认启动文件（crt0.o）
                                 #   我们用自己的 crt0.S 控制 sp/gp/bss
CFLAGS   += -ffreestanding      # 独立环境：告知编译器不依赖任何宿主 OS
CFLAGS   += -Os                 # 优化体积（ROM 只有 8KB，越小越好）
CFLAGS   += -fno-builtin        # 禁用编译器内建函数
                                 #   避免 GCC 把 _write 自动替换成 puts 等
CFLAGS   += -Wall -Wextra       # 开启所有警告（裸机程序易出 bug）

# 链接参数
LDFLAGS  := -T link.ld          # 使用自定义链接脚本（定义 ROM/RAM 布局）
LDFLAGS  += -nostdlib -nostartfiles

# ================================================================
# 三、输出目录和文件路径
# ================================================================
OUT = output

OBJS      = $(OUT)/crt0.o $(OUT)/trap_handler.o $(OUT)/syscalls.o $(OUT)/main.o
ELF       = $(OUT)/program.elf
DUMP      = $(OUT)/program.dump
VERILOG   = $(OUT)/program.verilog
BIN_HEX   = $(OUT)/program_text.hex   # hex 文本（bin2hex 输出）
TEXT_BIN  = $(OUT)/program_text.bin   # 纯二进制（.text + .rodata）

# MIF 输出路径（直接覆盖 Quartus IP 目录中的文件）
ROM_MIF   = ../quartus_project/ip_core/rom_32x256/test.mif
ROM_HEX   = ../quartus_project/ip_core/rom_32x256/program_text.hex
RAM_MIF   = ../quartus_project/ip_core/ram_32_1024/ram_init.mif

# 辅助 Python 脚本路径
TXT2MIF   = ../scripts/txt2mif.py      # hex 文本 → MIF（ROM 用）
GEN_MIF   = ../scripts/gen_data_mif.py  # verilog/objdump → MIF（RAM 用）
BIN2HEX   = ../scripts/bin2hex.py      # 二进制 → hex 文本
ANNOTATE  = ../scripts/annotate_dump.py # 反汇编 → 带中文注释的 dump

# ================================================================
# 四、默认构建目标
# ================================================================
.PHONY: all clean mif

all: $(OUT) $(ELF) $(DUMP) $(VERILOG) mif        # make = 编译 + 生成 MIF

# ----------------------------------------------------------------
# 4.1 创建 output 目录
# ----------------------------------------------------------------
$(OUT):
	if not exist $(OUT) mkdir $(OUT)

# ----------------------------------------------------------------
# 4.2 链接：.o → ELF
# ----------------------------------------------------------------
$(ELF): $(OBJS) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS)
	$(SIZE) $@

# ----------------------------------------------------------------
# 4.3 编译 C 文件：.c → output/.o
# ----------------------------------------------------------------
# $< = 第一个依赖（.c 文件），$@ = 目标（.o 文件）
$(OUT)/crt0.o: crt0.S
	$(CC) $(CFLAGS) -c -o $@ $<

$(OUT)/syscalls.o: syscalls.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(OUT)/main.o: main.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(OUT)/trap_handler.o: trap_handler.c
	$(CC) $(CFLAGS) -c -o $@ $<

# ----------------------------------------------------------------
# 4.4 反汇编：ELF → .dump
# ----------------------------------------------------------------
# -d: 反汇编所有代码段   -S: 穿插 C 源码
# 用于验证编译器实际生成的每条指令是否正确
$(DUMP): $(ELF)
	$(OD_WIN) -d -S $< > $@
	$(PYTHON) $(ANNOTATE) $@ $(OUT)/program_annotated.dump

# ----------------------------------------------------------------
# 4.5 Verilog hex 导出：ELF → .verilog
# ----------------------------------------------------------------
# objcopy -O verilog：输出 @地址 + 字节 格式
# 包含全部 loadable 段（.text + .rodata 等），供 gen_data_mif.py 解析
$(VERILOG): $(ELF)
	$(OBJCOPY) -O verilog $< $@

# ----------------------------------------------------------------
# 4.6 MIF 文件生成（ROM + RAM）
# ----------------------------------------------------------------
# 步骤：
#   ① objcopy -O binary -j .text -j .rodata → 提取纯二进制（仅 text+rodata）
#   ② bin2hex → 每行一个 32-bit hex 值
#   ③ txt2mif → Quartus MIF 格式 ROM 初始化文件
#   ④ gen_data_mif --base 0 → Data RAM MIF（完整 ROM 镜像）
#
# 为什么 --base 0x1000？
#   addr_decoder 已经将 ROM 地址范围(0x0000xxxx)的 load 路由到 rom_bus，
#   RAM 不再需要镜像 ROM 数据。RAM MIF 仅在 0x1000 处留一个零字即可。
#   运行时 data/bss 全部由 crt0.S 初始化，不需要预加载。
mif: $(ELF) $(VERILOG)
	$(OBJCOPY) -O binary -j .text -j .rodata $(ELF) $(TEXT_BIN)
	$(PYTHON) $(BIN2HEX) $(TEXT_BIN) $(BIN_HEX)
	$(PYTHON) $(TXT2MIF) $(BIN_HEX) $(ROM_MIF)
	$(PYTHON) $(GEN_MIF) -i $(VERILOG) -o $(RAM_MIF) --base 0x1000
	$(PYTHON) -c "import shutil; shutil.copy('$(BIN_HEX)', '$(ROM_HEX)')"

# ----------------------------------------------------------------
# 4.7 清理
# ----------------------------------------------------------------
clean:
	-rmdir /s /q $(OUT) 2>nul
