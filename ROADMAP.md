# CPU 终极目标路线图

## 目标

能够运行 GCC (riscv32-unknown-elf-gcc) 编译的 C 程序，输出结果可通过 UART 观察。

## 当前状态总览

| 模块 | 状态 |
|---|---|
| RV32I 基础整数指令 (37/40) | ✅ 已实现 |
| 五级流水线 (IF→ID→EX→MEM→WB) | ✅ 已实现 |
| 数据前递 (MEM→EX, WB→EX) | ✅ 已实现 |
| 跳转/分支冲刷 | ✅ 已实现 |
| 指令 ROM (Altera M9K IP) | ✅ 已实现 |
| 数据 RAM (Altera M9K IP, 带字节使能) | ✅ 已实现 |
| Load/Store 指令 (lb/lbu/lh/lhu/lw/sb/sh/sw) | ✅ 已实现 |
| Data RAM MIF 初始化 | ✅ 已实现 |
| 异常/中断处理 | ❌ 未实现 |
| CSR 寄存器 | ❌ 未实现 |
| ECALL/EBREAK | ❌ 未实现 |
| FENCE/FENCE.I | ❌ 未实现 |
| 特权架构 (Machine Mode) | ❌ 未实现 |
| UART 外设 | 🔶 代码已写，未集成 |
| Timer 外设 | ❌ 未实现 |
| Load-use 冒险修复 | ✅ 已修复 (MEM load 直达转发) |
| 全量 rv32ui 测试 | ❌ 未验证 |
| GCC 编译程序运行 | ❌ 目标状态 |

---

## 一、指令集完整性

### 1.1 RV32I 基础整数指令集（共 40 条）

#### R-type (10)
| 指令 | 编码 | 状态 |
|---|---|---|
| ADD | funct7=0x00, funct3=0x0 | ✅ |
| SUB | funct7=0x20, funct3=0x0 | ✅ |
| SLL | funct7=0x00, funct3=0x1 | ✅ |
| SLT | funct7=0x00, funct3=0x2 | ✅ |
| SLTU | funct7=0x00, funct3=0x3 | ✅ |
| XOR | funct7=0x00, funct3=0x4 | ✅ |
| SRL | funct7=0x00, funct3=0x5 | ✅ |
| SRA | funct7=0x20, funct3=0x5 | ✅ |
| OR | funct7=0x00, funct3=0x6 | ✅ |
| AND | funct7=0x00, funct3=0x7 | ✅ |

#### I-type ALU (10)
| 指令 | 编码 | 状态 |
|---|---|---|
| ADDI | opcode=0x13, funct3=0x0 | ✅ |
| SLTI | opcode=0x13, funct3=0x2 | ✅ |
| SLTIU | opcode=0x13, funct3=0x3 | ✅ |
| XORI | opcode=0x13, funct3=0x4 | ✅ |
| ORI | opcode=0x13, funct3=0x6 | ✅ |
| ANDI | opcode=0x13, funct3=0x7 | ✅ |
| SLLI | opcode=0x13, funct3=0x1 | ✅ |
| SRLI | opcode=0x13, funct3=0x5, funct7=0x00 | ✅ |
| SRAI | opcode=0x13, funct3=0x5, funct7=0x20 | ✅ |
| JALR | opcode=0x67, funct3=0x0 | ✅ |

#### B-type Branch (6)
| 指令 | 编码 | 状态 |
|---|---|---|
| BEQ | opcode=0x63, funct3=0x0 | ✅ |
| BNE | opcode=0x63, funct3=0x1 | ✅ |
| BLT | opcode=0x63, funct3=0x4 | ✅ |
| BGE | opcode=0x63, funct3=0x5 | ✅ |
| BLTU | opcode=0x63, funct3=0x6 | ✅ |
| BGEU | opcode=0x63, funct3=0x7 | ✅ |

#### U-type (2)
| 指令 | 编码 | 状态 |
|---|---|---|
| LUI | opcode=0x37 | ✅ |
| AUIPC | opcode=0x17 | ✅ |

#### J-type (1)
| 指令 | 编码 | 状态 |
|---|---|---|
| JAL | opcode=0x6F | ✅ |

#### Load (5)
| 指令 | 编码 | 状态 |
|---|---|---|
| LB | opcode=0x03, funct3=0x0 | ✅ |
| LH | opcode=0x03, funct3=0x1 | ✅ |
| LW | opcode=0x03, funct3=0x2 | ✅ |
| LBU | opcode=0x03, funct3=0x4 | ✅ |
| LHU | opcode=0x03, funct3=0x5 | ✅ |

#### Store (3)
| 指令 | 编码 | 状态 |
|---|---|---|
| SB | opcode=0x23, funct3=0x0 | ✅ |
| SH | opcode=0x23, funct3=0x1 | ✅ |
| SW | opcode=0x23, funct3=0x2 | ✅ |

#### 特权/同步 (3)
| 指令 | 编码 | 状态 |
|---|---|---|
| FENCE | opcode=0x0F | ❌ 可作为 NOP 实现 |
| FENCE.I | opcode=0x0F, funct3=0x1 | ❌ 可作为 NOP 实现 |
| ECALL | opcode=0x73, funct3=0x0 | ❌ 触发环境调用异常 |
| EBREAK | opcode=0x73, funct3=0x0 | ❌ 触发断点异常 |
| CSRRW | opcode=0x73, funct3=0x1 | ❌ 读写 CSR |
| CSRRS | opcode=0x73, funct3=0x2 | ❌ 读置位 CSR |
| CSRRC | opcode=0x73, funct3=0x3 | ❌ 读清除 CSR |
| CSRRWI | opcode=0x73, funct3=0x5 | ❌ 立即数读写 CSR |
| CSRRSI | opcode=0x73, funct3=0x6 | ❌ 立即数读置位 CSR |
| CSRRCI | opcode=0x73, funct3=0x7 | ❌ 立即数读清除 CSR |
| MRET | opcode=0x73 | ❌ 机器模式异常返回 |
| WFI | opcode=0x73 | ❌ 等待中断（可作 NOP） |

> **注意**：ECALL/EBREAK 和所有 CSR 指令共享 opcode=0x73，通过 funct3 和 rd/rs1 字段区分。
> 要运行 GCC 编译的程序，至少需要实现 ECALL、MRET、部分 CSR（mstatus/mepc/mcause/mtvec/mie/mip）。

### 1.2 RV32M 乘除法扩展（可选，GCC 默认不使用）

| 指令 | 编码 | 优先级 |
|---|---|---|
| MUL/MULH/MULHSU/MULHU | opcode=0x33, funct7=0x01 | 低 |
| DIV/DIVU/REM/REMU | opcode=0x33, funct7=0x01 | 低 |

> GCC 编译时加 `-march=rv32i` 即可避免生成乘除法指令。如果确实需要，可软件模拟（trap 到 M-mode 处理 "Illegal Instruction" 异常）。

---

## 二、特权架构 (RISC-V Privileged Spec 1.10+)

### 2.1 Machine Mode (M-mode) — 必须实现

运行 GCC 程序需要至少实现 Machine Mode：

#### CSR 寄存器

| CSR | 地址 | 说明 | 优先级 |
|---|---|---|---|
| `mvendorid` | 0xF11 | 厂商 ID (硬连线 0) | 🔶 中 |
| `marchid` | 0xF12 | 架构 ID (硬连线 1) | 🔶 中 |
| `mimpid` | 0xF13 | 实现 ID (硬连线 0) | 🔶 中 |
| `mhartid` | 0xF14 | 硬件线程 ID (硬连线 0) | 🔶 中 |
| `mstatus` | 0x300 | 机器状态 (至少需要 MIE/MPIE/MPP) | 🔴 高 |
| `misa` | 0x301 | ISA 和扩展 (硬连线 RV32I) | 🔶 中 |
| `mie` | 0x304 | 机器中断使能 | 🔴 高 |
| `mtvec` | 0x305 | 机器 trap 向量基址 | 🔴 高 |
| `mstatush` | 0x310 | mstatus 高 32 位 (RV32 可选) | 🟢 低 |
| `mscratch` | 0x340 | 机器模式暂存寄存器 | 🔴 高 |
| `mepc` | 0x341 | 机器异常 PC | 🔴 高 |
| `mcause` | 0x342 | 机器 trap 原因 | 🔴 高 |
| `mtval` | 0x343 | 机器 trap 值 | 🔴 高 |
| `mip` | 0x344 | 机器中断挂起 | 🔴 高 |

#### Trap 处理流程

```
1. 异常/中断发生
2. mcause ← 异常原因码
3. mtval ← 异常相关信息
4. mepc ← 当前 PC (或 PC+4，取决于异常类型)
5. mstatus.MPIE ← mstatus.MIE
6. mstatus.MIE ← 0
7. mstatus.MPP ← 当前特权模式
8. PC ← mtvec (BASE 模式: 直接跳转; VECTORED 模式: BASE + 4×cause)
```

#### Trap 返回 (MRET)

```
1. mstatus.MIE ← mstatus.MPIE
2. mstatus.MPIE ← 1
3. 特权模式 ← mstatus.MPP
4. mstatus.MPP ← U-mode
5. PC ← mepc
```

#### 异常原因码 (mcause)

| 类型 | 码 | 说明 | 优先级 |
|---|---|---|---|
| 中断 | 3 | 机器软件中断 (MSIP) | 🟢 低 |
| 中断 | 7 | 机器定时器中断 (MTIP) | 🔴 高 |
| 中断 | 11 | 机器外部中断 (MEIP) | 🔴 高 |
| 异常 | 0 | 指令地址未对齐 | 🔶 中 |
| 异常 | 2 | 非法指令 | 🔴 高 |
| 异常 | 3 | 断点 (EBREAK) | 🔶 中 |
| 异常 | 4 | Load 地址未对齐 | 🔶 中 |
| 异常 | 5 | Load 访问错误 | 🔶 中 |
| 异常 | 6 | Store 地址未对齐 | 🔶 中 |
| 异常 | 7 | Store 访问错误 | 🔶 中 |
| 异常 | 8 | 用户态 ECALL | 🔴 高 |
| 异常 | 11 | 机器态 ECALL | 🔴 高 |

---

## 三、流水线架构完善

### 3.1 Load-Use 冒险修复 ✅

**问题**：MEM 转发信号 `mem_reg_rd_val` 来自 `pipe_ex_mem.reg_rd_val_o` = ALU `result_o`。对于 load 指令，`result_o = 0`（默认值），真实数据在 `mem_ctrl.q_val_o`（RAM 输出）。

**修复**（1 行改动，`CPU.v:225`）：
```
- .mem_reg_rd_val_i(mem_reg_rd_val),       // ALU result → load 时为 0
+ .mem_reg_rd_val_i(mem_mem_read_rd_val),  // mem_ctrl.q_val_o → 自动区分
```

`mem_ctrl.q_val_o` 在 ALU/store/jump 时透传 `reg_rd_val_i`（= ALU 结果），在 load 时覆盖为 RAM 数据，无需额外端口或检测逻辑。

**时序说明（FPGA vs ASIC）**：此方案在 ASIC 上足以满足 192MHz（关键路径 ~2.3ns < 半周期 2.6ns），但在 Cyclone IV E FPGA 上受限于 M9K RAM tCO(~2.5ns) + ALU(~4ns) ≈ 7.8ns，实际 FPGA 频率约 60-80MHz。若需 FPGA 高频验证，可改为插 stall 走 WB 转发。

### 3.2 转发路径

| 转发路径 | 状态 | 数据来源 |
|---|---|---|
| ALU result (MEM→EX) | ✅ | `mem_mem_read_rd_val` (q_val_o 透传) |
| Load result (MEM→EX) | ✅ | `mem_mem_read_rd_val` (q_val_o = RAM 输出) |
| WB result (WB→EX) | ✅ | `wb_reg_rd_val` |
| Store data (rs2) 转发 | ✅ | `mem_mem_read_rd_val` / `wb_write_val` |

### 3.3 分支预测

| 当前 | 建议 |
|---|---|
| 静态不跳转（每次分支冲刷 2 周期） | 添加 BTB 或简单静态预测（向后跳转预测 taken） |

### 3.4 控制信号完整性

| 信号 | 当前 | 状态 |
|---|---|---|
| `stall` | `1'b0` 硬连线 | 🔶 当前无 hazard 场景需要 stall |
| `flush` | `ex_jump_en` | ✅ 正确 |
| `o_instr` | `[5:0]` | ✅ 已修复 |

---

## 四、内存映射 (Memory Map)

### 4.1 目标内存布局

```
地址空间 (32-bit, 4GB)
│
├─ 0x00000000 ───────────── 0x00001FFF  (8KB)
│  指令 ROM (2K x 32)
│
├─ 0x00010000 ───────────── 0x00011FFF  (8KB)
│  数据 RAM (2K x 32, 当前已占用低 128B @0x1000)
│
├─ 0x02000000 ───────────── 0x020000FF  (256B)
│  系统控制 / GPIO / LED
│
├─ 0x80000000 ───────────── 0x800000FF  (256B)
│  UART 控制器 (当前已有实现)
│
├─ 0x80000100 ───────────── 0x800001FF  (256B)
│  Timer (mtime/mtimecmp)
│
└─ 0xFFFFFFFF ─────────────
```

### 4.2 当前实现与目标差距

| 当前 | 目标 |
|---|---|
| ROM 0x00000000 | ROM 0x00000000 (保持) |
| RAM 0x00000000 (重叠覆盖!) | RAM 0x00010000 (需分离地址空间) |
| 无外设总线 | UART + Timer 映射到 0x8xxxxxxx |

### 4.3 地址空间分离 🔴

**当前问题**：ROM 和 RAM 都是从地址 0 开始，靠不同的物理 IP 区分。但软件视角下访问地址 0 应该只走 ROM（取指），RAM 应该用独立地址段。

**方案**：在 `mem_ctrl` 上层加地址译码器 (Address Decoder)：

```verilog
// 统一总线访问
case (addr[31:24])
    8'h00:  // ROM 地址空间（只读）
        instr_data = rom_q;
    8'h01:  // RAM 地址空间 (0x0001xxxx)
        ram_address = addr[12:2];
        // ...
    8'h80:  // 外设地址空间
        case (addr[23:16])
            8'h00: // UART @0x8000xxxx
            8'h01: // Timer @0x8001xxxx
        endcase
endcase
```

---

## 五、启动流程 (Boot Sequence)

### 5.1 当前

```
复位 → PC=0 → 从 ROM 取指执行
```

### 5.2 目标（GCC 程序运行流程）

```
1. 硬件复位
2. PC ← 0x00000000 (ROM 起始)
3. 执行 _start（汇编启动代码 crt0.S）:
   a. 初始化全局指针 gp (指向 .data 段起始)
   b. 初始化堆栈指针 sp (指向栈顶，通常 RAM 末尾)
   c. 清零 .bss 段
   d. 从 ROM 复制 .data 段到 RAM
   e. 调用 main()
4. main() 执行 C 代码
5. main() 返回后调用 exit() → 死循环或关机
```

### 5.3 需要的软件支持

| 文件 | 说明 |
|---|---|
| `crt0.S` | 启动代码：设置 sp/gp，清零 bss，复制 data 段 |
| `link.ld` | 链接脚本：定义 ROM/RAM 地址布局 |
| `syscalls.c` | 系统调用桩：write/read/exit 等通过 ECALL 实现 |
| `Makefile` | 编译脚本：`riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32` |

### 5.4 链接脚本示例

```ld
MEMORY {
    ROM  (rx) : ORIGIN = 0x00000000, LENGTH = 8K
    RAM  (rw) : ORIGIN = 0x00010000, LENGTH = 8K
}

SECTIONS {
    .text : { *(.text*) } > ROM
    .rodata : { *(.rodata*) } > ROM
    .data : {
        __data_start = .;
        *(.data*)
        __data_end = .;
    } > RAM AT > ROM
    .bss : {
        __bss_start = .;
        *(.bss*)
        __bss_end = .;
    } > RAM
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
```

---

## 六、编译工具链设置

### 6.1 安装 RISC-V GCC

```bash
# Windows (MSYS2)
pacman -S mingw-w64-x86_64-riscv32-unknown-elf-gcc

# 或者从官网下载预编译包
# https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases
```

### 6.2 编译命令

```bash
# 编译 C 程序
riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
    -T link.ld crt0.S main.c -o program.elf

# 提取 text 段
riscv32-unknown-elf-objcopy -O verilog program.elf program.verilog

# 生成 ROM MIF（当前流程）
python scripts/txt2mif.py program_hex.txt rom_test.mif

# 生成 RAM MIF (data 段初始化)
python scripts/gen_data_mif.py -i program.verilog -o ram_init.mif --base 0x10000
```

---

## 七、分阶段实现计划

### Phase 1: 流水线完善

- [x] **1.1** 修复 Load-Use 冒险（`mem_reg_rd_val` → `mem_mem_read_rd_val`，1 行改动）
- [x] **1.2** 修复 `o_instr` 位宽不匹配（已是 `[5:0]`）
- [ ] **1.3** 地址空间分离（ROM=0x00_0000, RAM=0x00_10000）
- [x] **1.4** 工程目录清理（ALU→alu, MEM→mem, 移除 .bak/空文件/废弃 rom.v）
- [x] **1.5** Data RAM MIF 初始化流程（gen_data_mif.py + ram_init.mif）
- [x] **1.6** rv32ui-p-sb 测试通过

### Phase 2: 基础特权架构和异常

- [ ] **2.1** 实现 CSR 寄存器模块 (`rtl/csr/csr.v`)
- [ ] **2.2** 实现 Trap 控制逻辑（mepc/mcause/mtval/mstatus）
- [ ] **2.3** 实现 ECALL/EBREAK 异常
- [ ] **2.4** 实现 MRET 指令
- [ ] **2.5** 实现非法指令异常
- [ ] **2.6** 实现 FENCE/FENCE.I（作为 NOP）

### Phase 3: 外设集成

- [ ] **3.1** 实现地址译码器 (Address Decoder)
- [ ] **3.2** 集成 UART 控制器
- [ ] **3.3** 实现 Timer (mtime/mtimecmp)
- [ ] **3.4** 连接中断信号到 CPU（MTIP/MEIP）

### Phase 4: 软件生态

- [ ] **4.1** 编写 crt0.S 启动代码
- [ ] **4.2** 编写 link.ld 链接脚本
- [ ] **4.3** 实现 syscalls (write 通过 UART 输出)
- [ ] **4.4** 编写 Makefile 自动化编译
- [ ] **4.5** 编写示例 C 程序（hello world / 冒泡排序）

### Phase 5: 完整测试与优化

- [ ] **5.1** 跑通全部 rv32ui 单指令测试
- [ ] **5.2** 跑通 rv32um 乘除法测试（可选）
- [ ] **5.3** ACS 合规测试
- [ ] **5.4** 性能优化（分支预测、深流水线）
- [ ] **5.5** FPGA 时序收敛：SDC 约束，目标 80MHz (Cyclone IV E)
- [ ] **5.6** ASIC 目标：192MHz@TSMC 28nm，需评估 MEM load 转发关键路径

---

## 八、文件结构目标

```
cpu/
├── rtl/
│   ├── CPU.v                        # 顶层
│   ├── alu/alu.v                    # ALU
│   ├── decode/
│   │   ├── decode.v                 # 译码
│   │   ├── decode_ctrl.v            # 控制译码
│   │   └── decode_params.vh         # 参数定义
│   ├── pipe/
│   │   ├── pipe_if_id.v
│   │   ├── pipe_id_ex.v             # ID/EX + 转发
│   │   ├── pipe_ex_mem.v
│   │   └── pipe_mem_wr.v
│   ├── hazard/
│   │   └── hazard.v                 # 🆕 冒险检测 (stall/flush)
│   ├── mem/
│   │   ├── mem_ctrl.v               # 数据 RAM 控制器
│   │   └── addr_decoder.v           # 🆕 地址译码/总线
│   ├── csr/
│   │   └── csr.v                    # 🆕 CSR 寄存器 + 异常控制
│   ├── pc/pc_count.v
│   ├── regfile/regfile.v
│   └── uart/                        # 保留，待集成
│       ├── uart.v
│       ├── uart_rx.v
│       └── uart_tx.v
├── quartus_project/
│   └── ip_core/
│       ├── rom_32x256/
│       └── ram_32_1024/
├── sim/
│   └── tb_cpu.v
├── sw/                              # 🆕 软件目录
│   ├── crt0.S                       # 启动代码
│   ├── link.ld                      # 链接脚本
│   ├── syscalls.c                   # 系统调用
│   ├── main.c                       # 示例 C 程序
│   └── Makefile                     # 编译脚本
├── scripts/
│   ├── txt2mif.py
│   └── gen_data_mif.py
└── test_data/
    └── ...
```

---

## 九、关键设计决策待定

| 决策 | 选项 A | 选项 B | 建议 |
|---|---|---|---|
| 总线架构 | 哈佛结构 (当前，独立 I/D 总线) | 统一总线 + 仲裁 | 保持哈佛（简单、高性能） |
| 中断优先级 | 固定优先级 | 可编程优先级 | 固定（先简化） |
| CSR 实现方式 | 寄存器堆 + 硬连线 | 可扩展框架 | 寄存器堆（简单） |
| GCC 库 | -nostdlib (无标准库) | newlib (有 malloc/printf) | 先用 -nostdlib，后续升级 |
| FPU | 无 | 可选扩展 | 不考虑 |
| Cache | 无 | I-Cache + D-Cache | 当前不需要 |

---

## 十、最小可运行 GCC 程序清单

要运行最简单的 `main() { return 0; }` 需要：

1. ✅ 全部 RV32I 指令（已实现 37+8/40+8）
2. ❌ ECALL + MRET（用于 exit 系统调用）
3. ❌ CSR: mstatus/mepc/mcause/mtvec/mscratch
4. ❌ 启动代码 (crt0.S)：设置 sp、gp
5. ❌ 链接脚本 (link.ld)：定义 ROM/RAM 布局
6. ❌ 地址空间分离
7. ✅ Load-use 冒险修复（MEM load 直达转发）

**最小可运行 "Hello World"** 额外需要：
8. ❌ UART 集成 + 地址映射
9. ❌ syscalls.c (write 系统调用通过 ECALL → UART 输出)
10. ❌ Timer 中断（用于时钟/超时，可选）

---

*文档版本: 1.1 | 日期: 2026-06-23 | 更新: Load-use 修复 (1行改动), 工程目录清理, FPGA/ASIC 时序分析*
