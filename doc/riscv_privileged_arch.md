# RISC-V 特权架构 (Privileged Architecture) 学习笔记

> 本文档基于 RISC-V Privileged Specification v1.12，聚焦 Machine Mode (M-mode)，
> 面向 RV32I CPU 核心的实现者。结合 `D:\MY\cpu` 工程的实际架构编写。

---

## 目录

1. [什么是特权架构](#1-什么是特权架构)
2. [特权等级体系](#2-特权等级体系)
3. [Machine Mode (M-mode) 简介](#3-machine-mode-m-mode-简介)
4. [CSR 寄存器详解](#4-csr-寄存器详解)
5. [Trap（异常/中断）机制](#5-trap异常中断机制)
6. [CSR 指令集](#6-csr-指令集)
7. [软件上下文与 ABI](#7-软件上下文与-abi)
8. [本 CPU 的实现建议](#8-本-cpu-的实现建议)

---

## 1. 什么是特权架构

### 1.1 直观类比

| 概念 | 类比（x86/ARM） | RISC-V |
|------|------------------|--------|
| 用户态 | Ring 3 / EL0 | **U-mode** (User) |
| 内核态 | Ring 0 / EL1 | **S-mode** (Supervisor) |
| 虚拟化 | Ring -1 / EL2 | **HS-mode** (Hypervisor) |
| 固件/Boot | — / EL3 | **M-mode** (Machine) |

特权架构定义了：
- **谁可以访问什么资源**（CSR 寄存器、物理内存、特殊指令）
- **发生意外时怎么办**（异常和中断怎样处理）
- **CPU 复位后从哪里开始跑**

### 1.2 为什么 CPU 需要特权模式

一个没有特权模式的 CPU 意味着：
- 任何程序都可以关闭中断、修改时钟、直接写 UART 寄存器
- 程序崩溃（数组越界、除零）无法被捕获，CPU 直接跑飞
- 操作系统无法隔离进程

有了 M-mode 之后，所有"危险操作"必须经过 trap → 由 M-mode 软件统一处理 → 返回，CPU 就不会跑飞。

### 1.3 最小需求

RISC-V 规范要求：**所有 CPU 必须实现 M-mode**（即使没有 U-mode/S-mode）。M-mode 是你的 CPU 能运行 GCC 编译程序的最低门槛。

---

## 2. 特权等级体系

```
                    ┌─────────────┐
                    │  U-mode     │  ← 普通应用程序（printf, 计算）
                    │  (User)     │
                    ├──────┼──────┤
                    │  S-mode     │  ← 操作系统内核（Linux）
                    │  (Supervisor)│
                    ├──────┼──────┤
                    │  M-mode     │  ← 固件/硬件管理（必须实现）
                    │  (Machine)  │
                    └─────────────┘
```

### 2.1 每个模式的编号

| 值 | 模式 | 用于 |
|----|------|------|
| `2'b00` | User (U) | 应用程序 |
| `2'b01` | Supervisor (S) | 操作系统 |
| `2'b11` | Machine (M) | 最高权限 |

> **注意**：`2'b10` 保留给 Hypervisor (HS-mode)。RV32 的 MPP 字段只有 2bit，所以只能表示 U/S/M 三级。

### 2.2 特权级切换规则

```
┌──────────────────────────────────────────────────┐
│                                                   │
│  切换方向          触发方式                       │
│                                                   │
│  U/S/M → M      Trap 进入（异常/中断）             │
│  M → U/S         MRET 指令                       │
│  M → M           MRET 时若 MPP=M                 │
│  U → S ↛        ❌ 不能直接切换，必须经 M-mode    │
│                                                   │
└──────────────────────────────────────────────────┘
```

**关键规则**：特权级只能通过 trap 上升，只能通过 `MRET` 下降。没有"降级指令"——一旦进入 M-mode，只有 `MRET` 可以离开。

### 2.3 本工程的选择

本工程只需实现 **M-mode**（不需要 U-mode/S-mode），所有代码跑在 M-mode 下。这是绝大多数 MCU 级 RISC-V 核（如 GD32VF103）的做法。

---

## 3. Machine Mode (M-mode) 简介

### 3.1 什么是 M-mode

M-mode 是 RISC-V CPU 的"管家模式"——它拥有：
- 访问 **所有 CSR 寄存器**（包括控制中断/内存保护的寄存器）
- 执行 **所有指令**（包括 `MRET`、`WFI`）
- 访问 **所有物理内存**
- 处理 **所有异常和中断**

### 3.2 复位状态

CPU 上电/复位后：

| 寄存器 | 复位值 | 含义 |
|--------|--------|------|
| PC | `0x00000000` | 从 ROM 第一个指令开始 |
| `mstatus.MIE` | `0` | 全局中断关闭 |
| `mstatus.MPP` | `2'b11` | 复位后处于 M-mode |
| `mtvec` | 未定义 | 需软件初始化 |
| `mepc`、`mcause`、`mtval` | 未定义 | 需硬件在 trap 时写入 |
| 通用寄存器 (x0-x31) | 未定义 | 需软件初始化（x0 硬连线为 0） |

### 3.3 M-mode 下的资源

| 资源 | M-mode | U-mode |
|------|--------|--------|
| 通用寄存器 x0-x31 | ✅ | ✅ |
| PC | ✅ | ✅ |
| `ECALL` 指令 | ✅ | ✅ |
| `MRET` 指令 | ✅ | ❌ (触发非法指令异常) |
| 所有 CSR 读/写 | ✅ | ❌ (触发非法指令异常) |
| `WFI` 指令 | ✅ | ❌ (可能触发非法指令异常) |

---

## 4. CSR 寄存器详解

CSR (Control and Status Register) 是独立于 x0-x31 通用寄存器的 **控制/状态寄存器**。地址空间 12-bit (0x000-0xFFF)，只读/只写/读写由高 2bit 决定：

| CSR 地址 [11:10] | 访问类型 |
|-------------------|----------|
| `00` | 用户自定义（未定义） |
| `01` | 用户自定义（未定义） |
| `10` | 非标准只读（未定义） |
| `11` | 标准 CSR（读/写由具体寄存器决定） |

**标准 CSR 都在 `0x300-0xFFF` 范围内。**

### 4.1 mstatus (0x300) — Machine Status

**这是最重要的 CSR。** 它控制了全局中断开关、当前特权级、以及字节序/数据宽度等信息。

#### 位布局 (RV32)

```
  31                22  21  17  16  15  14  13  12  11  10  9   8   7   6   5   4   3   2   1   0
┌────────────────────┬─────┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐
│       SD           │ WPRI│TSR│TW│TVM│MXR│SUM│MPRV│XS[1:0]│FS[1:0]│MPP[1:0]│WPRI│SPP│MPIE│WPRI│SPIE│UPIE│MIE│WPRI│SIE│UIE│
└────────────────────┴─────┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
```

#### 本工程需要的位（最小集）

| 位 | 名称 | 宽度 | 描述 |
|----|------|------|------|
| [3] | **MIE** | 1 | Machine Interrupt Enable — 全局中断使能。`0`=关中断，`1`=开中断。`CSRRS x0, mstatus, (1<<3)` 开中断 |
| [7] | **MPIE** | 1 | Machine Previous Interrupt Enable — 进入 trap 之前 MIE 的值。陷阱发生时硬件自动 `MPIE ← MIE`，然后 `MIE ← 0` |
| [12:11] | **MPP** | 2 | Machine Previous Privilege — 进入 trap 之前的特权模式。`2'b11`=M, `2'b01`=S, `2'b00`=U |

**MPP 的值**：
| MPP | 含义 |
|-----|------|
| `2'b00` | User |
| `2'b01` | Supervisor |
| `2'b11` | Machine |

> 其他位在本工程中可以为 `0`（不需要浮点、不需要 S-mode、不需要虚拟内存保护、不需要字节序切换）。

#### 为什么需要 MPIE + MPP

```
举个例子：

程序在 M-mode 运行，MIE=1（开中断）
    ↓ 发生 timer 中断
    ↓ 硬件自动：
    ↓   MPIE ← 1     (记住之前 MIE=1)
    ↓   MIE  ← 0     (进入 M-mode 后关中断)
    ↓   MPP  ← 2'b11 (记住之前在 M-mode)
    ↓   PC   ← mtvec (跳转到 trap handler)
    ↓
trap handler 处理完...
    ↓ 执行 MRET
    ↓ 硬件自动：
    ↓   MIE  ← MPIE   (=1, 恢复开中断)
    ↓   MPIE ← 1
    ↓   模式 ← MPP    (=M-mode)
    ↓   PC   ← mepc   (回到被打断的指令)
```

如果没有 MPIE，trap 返回后就不知道之前中断是开还是关。

---

### 4.2 mtvec (0x305) — Machine Trap Vector

**陷阱入口地址。** 软件初始化时必须设置这个寄存器，告诉 CPU 发生 trap 时跳转到哪里。

#### 位布局

```
  31                           2   1   0
┌──────────────────────────────┬───────┐
│          BASE[31:2]          │ MODE  │
└──────────────────────────────┴───────┘
```

| 字段 | 位 | 描述 |
|------|-----|------|
| BASE | [31:2] | Trap handler 入口地址的基址（4 字节对齐，所以低 2bit 恒为 0） |
| MODE | [1:0] | Trap 地址模式 |

**MODE 取值**：

| MODE | 名称 | 行为 |
|------|------|------|
| `2'b00` | **Direct** | 所有 trap 都跳转到 `BASE`（推荐先实现这个） |
| `2'b01` | **Vectored** | 中断时跳转到 `BASE + 4 × cause`，异常时仍然是 `BASE` |

> **建议**：先实现 Direct 模式，Vectored 模式更高效但硬件更复杂。Direct 模式下 handler 自己读 `mcause` 来分支处理。

#### 示例：软件设置 mtvec

```asm
la    t0, trap_handler
csrrw x0, mtvec, t0        # mtvec = &trap_handler
```

---

### 4.3 mepc (0x341) — Machine Exception Program Counter

**陷阱返回地址。** Trap 发生时硬件自动写入。

| 寄存器 | 位宽 | trap 时写入 | MRET 时读取 |
|--------|------|-------------|-------------|
| mepc | 32 | 故障指令的 PC（异常）或下一条指令的 PC（中断） | PC ← mepc |

**异常 vs 中断的 mepc 区别**：

| 类型 | mepc 指向 | 原因 |
|------|-----------|------|
| 异常（ECALL/非法指令） | **出错的指令** | MRET 后需要重新执行该指令，所以 handler 要自己 `mepc += 4` 跳到下一条 |
| 中断（timer/UART） | **下一条没执行的指令** | 中断是异步的，被中断的指令还没执行完，返回后应该执行它 |

#### 软件侧处理

```asm
# ECALL handler 中必须加4，否则 MRET 回来又会触发同样的 ECALL
csrr  t0, mepc
addi  t0, t0, 4
csrrw x0, mepc, t0
mret
```

---

### 4.4 mcause (0x342) — Machine Cause

**陷阱原因码。** Trap 发生时硬件自动写入。

#### 位布局

```
  31  30   29                                    0
┌──┬──────────────────────────────────────────────┐
│I │              Exception Code                  │
│R │                                              │
└──┴──────────────────────────────────────────────┘
```

| 位 | 名称 | 描述 |
|----|------|------|
| [31] | **Interrupt** | `1` = 中断, `0` = 异常 |
| [30:0] | Exception Code | 原因码 |

#### 完整原因码表

| 类型 | 码 | 助记符 | 描述 | 优先级 |
|------|-----|--------|------|--------|
| **中断** | 0 | — | (保留，不用) | — |
| | 1 | — | Supervisor software interrupt | 🟢低 |
| | 2 | — | (保留) | — |
| | 3 | MSIP | **Machine software interrupt** | 🟢低 |
| | 4 | — | (保留) | — |
| | 5 | STIP | Supervisor timer interrupt | 🟢低 |
| | 6 | — | (保留) | — |
| | 7 | **MTIP** | **Machine timer interrupt** | 🔴高 |
| | 8 | — | (保留) | — |
| | 9 | SEIP | Supervisor external interrupt | 🟢低 |
| | 10 | — | (保留) | — |
| | 11 | **MEIP** | **Machine external interrupt** | 🔴高 |
| | 12-15 | — | (保留) | — |
| | ≥16 | — | 平台自定义 | 🟢低 |
| **异常** | 0 | — | Instruction address misaligned | 🔶中 |
| | 1 | — | Instruction access fault | 🔶中 |
| | 2 | **ILLEGAL** | **Illegal instruction** | 🔴高 |
| | 3 | **BREAK** | **Breakpoint (EBREAK)** | 🔴高 |
| | 4 | — | Load address misaligned | 🔶中 |
| | 5 | — | Load access fault | 🔶中 |
| | 6 | — | Store address misaligned | 🔶中 |
| | 7 | — | Store access fault | 🔶中 |
| | 8 | **U_ECALL** | **Environment call from U-mode** | 🔴高 |
| | 9 | **S_ECALL** | Environment call from S-mode | 🔴高 |
| | 10 | — | (保留) | — |
| | 11 | **M_ECALL** | **Environment call from M-mode** | 🔴高 |
| | 12 | — | Instruction page fault | 🔶中 |
| | 13 | — | Load page fault | 🔶中 |
| | 14 | — | (保留) | — |
| | 15 | — | Store page fault | 🔶中 |

**本工程最少需要实现（优先级高）**：

| 码 | 场景 | 何时触发 |
|----|------|----------|
| 2 | 非法指令 | 执行未定义的 opcode/funct3/funct7 |
| 3 | EBREAK | 调试断点 |
| 11 | M-mode ECALL | C 程序调用 `_exit()` 等系统调用 |

#### 软件读取 mcause 示例

```asm
csrr  t0, mcause
srli  t1, t0, 31           # t1 = IR (1=中断, 0=异常)
andi  t0, t0, 0x7FFFFFFF   # t0 = cause code

beqz  t1, is_exception      # 分支到异常处理
# 否则是中断处理...
```

---

### 4.5 mtval (0x343) — Machine Trap Value

**【不是寄存器的"值"，而是异常的"附加信息"】。**

| 异常类型 | mtval 的值 |
|----------|-----------|
| 非法指令 | **出错的指令编码** (32-bit) |
| EBREAK | 出错的指令 |
| ECALL | ECALL 指令本身 |
| 地址未对齐 | **错误的地址** |
| 页错误 | 访问的虚拟地址 |
| 中断 | **0** (没有附加信息) |

**用途**：trap handler 可以通过读 mtval 知道具体哪条指令触发了异常，从而实现**软件模拟指令**（如用 trap 模拟不存在的 MUL/DIV 指令）。

---

### 4.6 mie (0x304) — Machine Interrupt Enable

**每个中断源的独立开关。** `mstatus.MIE` 是总开关，`mie` 是分开关。两者 `&` 运算后决定中断是否真的触发。

#### 位布局

```
  31           11  10  9   8   7   6   5   4   3   2   1   0
┌──────────────┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐
│    WPRI      │ME│(R)│SE│(R)│MT│(R)│ST│(R)│MS│(R)│(R)│(R)│
│              │IE│   │IE│   │IE│   │IE│   │IE│   │   │   │
└──────────────┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
```

| 位 | 名称 | 描述 | 本工程需要？ |
|----|------|------|-------------|
| 3 | **MSIE** | Machine Software Interrupt Enable | 🔶 可选 |
| 7 | **MTIE** | **Machine Timer Interrupt Enable** | 🔴 需要（Timer 中断） |
| 11 | **MEIE** | **Machine External Interrupt Enable** | 🔴 需要（UART 中断） |

> 注意：`mie` 和 `mip` 的 bit 位置是对称的——同一个中断源在 mie 中对应同一个 bit。

#### 中断触发条件

```
中断触发 = mstatus.MIE  &&  mie[CAUSE]  &&  mip[CAUSE]
             总开关            分开关          挂起位
```

---

### 4.7 mip (0x344) — Machine Interrupt Pending

**正在等待处理的中断。** 这是一个"状态"寄存器，硬件设置它的位，软件读取和清除。

#### 位布局

| 位 | 名称 | 描述 | 硬件驱动 |
|----|------|------|----------|
| 3 | MSIP | Machine Software Interrupt Pending | 软件写触发 |
| 7 | **MTIP** | **Machine Timer Interrupt Pending** | 硬件：mtime ≥ mtimecmp 时置1 |
| 11 | **MEIP** | **Machine External Interrupt Pending** | 硬件：UART RX/TX 中断线 |

---

### 4.8 信息类 CSR（只读，硬连线）

这些寄存器用于软件识别 CPU，可以硬连线到固定值：

| CSR | 地址 | 描述 | 建议值 |
|-----|------|------|--------|
| `misa` | 0x301 | Machine ISA Register | `0x40000100` = RV32 (MXL=1, 表示 RV32) |
| `mvendorid` | 0xF11 | 厂商 ID | `0x00000000` |
| `marchid` | 0xF12 | 架构 ID | `0x00000001` |
| `mimpid` | 0xF13 | 实现版本 ID | `0x00000001` |
| `mhartid` | 0xF14 | 硬件线程 ID | `0x00000000` (单核) |

`misa` 的位布局：

```
  31 30  29 28                                     2   1   0
┌──────┬──────────────────────────────────────────────┬──┐
│ MXL  │                Extensions[25:0]              │0 │
│[1:0] │                                              │  │
└──────┴──────────────────────────────────────────────┴──┘
```

- MXL = 1 → RV32
- Extensions 每一位代表一个扩展：bit 0=RV32I, bit 8=RV32I base (=I)
- RV32I 的 `misa` = `0x40000100`

---

### 4.9 mscratch (0x340) — Machine Scratch

**给 trap handler 用的临时寄存器。** 硬件不自动操作它，完全由软件使用。

**为什么需要**：trap handler 第一件事要保存寄存器，但通用寄存器都"脏"的——不能直接 `sw t0, xxx(t1)` 因为 t0/t1 还是被打断程序的。这时候用 `CSRRW t0, mscratch, t0` 把 t0 和 mscratch 交换，就可以安全使用 t0 了。

---

## 5. Trap（异常/中断）机制

### 5.1 什么是 Trap

**Trap = 异常 (Exception) + 中断 (Interrupt)**

| | 异常 | 中断 |
|---|------|------|
| 来源 | 程序自身 (同步) | 外部事件 (异步) |
| 发生时机 | 某条指令执行时 | 任意时刻 |
| mepc 指向 | 出错的指令 | 下一条未执行的指令 |
| mcause[31] | 0 | 1 |
| 可恢复性 | 通常可恢复（函数调用） | 总是可以恢复 |

### 5.2 Trap 的完整硬件流程

当异常/中断发生时，硬件在 **一个周期内原子完成** 以下操作：

```
┌─── 硬件 Trap 入口 ──────────────────────────────────────────────┐
│                                                                   │
│  1. 获取当前 PC：                                                 │
│     如果是异常：trap_pc = 触发异常的指令的 PC                      │
│     如果是中断：trap_pc = 下一条即将执行的指令的 PC                 │
│                                                                   │
│  2. mcause ← cause_code                                          │
│     - 异常 2: 非法指令                                            │
│     - 异常 11: M-mode ECALL                                      │
│     - 中断 7: Timer 中断                                          │
│     - 中断 11: 外部中断                                           │
│                                                                   │
│  3. mtval ← 附加信息                                              │
│     - 非法指令: 指令编码本身                                       │
│     - ECALL: 指令编码                                             │
│     - 中断: 0                                                     │
│                                                                   │
│  4. mepc ← trap_pc                                               │
│                                                                   │
│  5. mstatus.MPIE ← mstatus.MIE                                   │
│     mstatus.MIE  ← 0           // 进入 trap 后关全局中断           │
│                                                                   │
│  6. mstatus.MPP  ← 当前特权级   // 本工程始终是 2'b11 (M-mode)     │
│                                                                   │
│  7. PC ← mtvec                   // 跳转到 trap handler            │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

**关键特性**：以上 7 步是原子的——中间不能被打断（即 trap 期间不能再 trap）。

### 5.3 MRET 的完整硬件流程

```
┌─── MRET 指令硬件操作 ──────────────────────────────────────────────┐
│                                                                     │
│  1. 特权模式 ← mstatus.MPP     // 进入 trap 之前的模式              │
│                                                                     │
│  2. mstatus.MIE  ← mstatus.MPIE    // 恢复旧的中断使能               │
│     mstatus.MPIE ← 1               // 为下次 trap 准备好            │
│                                                                     │
│  3. mstatus.MPP  ← U-mode (2'b00)  // 最低特权级为默认               │
│     （如果没有 U-mode，规范允许写得任意，可以是 M-mode）              │
│                                                                     │
│  4. PC ← mepc                                                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.4 中断触发时序

```
时钟周期    IF        ID        EX        MEM       WB
─────────────────────────────────────────────────────────
  N       inst_a
  N+1     inst_b    inst_a
  N+2     inst_c    inst_b    inst_a
  N+3     ──── 中断信号到达 ────→  inst_b 被标记为 "最后一个完成"
  N+4     trap      inst_c    inst_b    inst_b 完成，mepc←N+4, flush IF/ID
  N+5     handler   trap       NOP      NOP
  N+6     handler   handler    trap      NOP
```

中断在 EX/MEM 阶段被识别。需要 **冲刷** 流水线中比 trap_pc 更新的指令（类似你现有的 branch flush 机制）。

### 5.5 指令在流水线中的 Trap 检查点

| 异常类型 | 检查阶段 | 说明 |
|----------|----------|------|
| 非法指令 | **ID** (译码阶段) | 译码器输出 `illegal_instr = 1` |
| ECALL | **ID** | 译码器识别 opcode=0x73 + funct3=0x0 + 无 rs1/rd |
| EBREAK | **ID** | 译码器识别 EBREAK 编码 |
| 访存未对齐 | **EX/MEM** | 地址译码器检测 |
| 外部中断 | **MEM** | 在 MEM 阶段统一检查 `mie & mip & mstatus.MIE` |

> **你的工程中**：非法指令检测当前在 `decode.v` 内，只需要把 `illegal_instr` 信号透传到 EX 阶段，在 EX 阶段触发 trap。

---

## 6. CSR 指令集

所有 CSR 指令共享 **opcode = 0x73 (SYSTEM)**。

### 6.1 指令编码

```
  31          20 19    15 14   12 11     7 6        0
┌──────────────┬─────────┬───────┬─────────┬─────────┐
│   CSR[11:0]  │  rs1    │funct3 │   rd    │ opcode  │
│              │  / uimm │       │         │ 1110011 │
└──────────────┴─────────┴───────┴─────────┴─────────┘
```

### 6.2 六条 CSR 指令

| 指令 | funct3 | 操作 |
|------|--------|------|
| **CSRRW** | `0x1` | `rd = CSR; CSR = rs1` (原子读后写) |
| **CSRRS** | `0x2` | `rd = CSR; CSR = CSR \| rs1` (读后置位) |
| **CSRRC** | `0x3` | `rd = CSR; CSR = CSR & ~rs1` (读后清除) |
| **CSRRWI** | `0x5` | `rd = CSR; CSR = zext(rs1_field)` (立即数版 CSRRW，rs1 字段变成 5bit uimm) |
| **CSRRSI** | `0x6` | `rd = CSR; CSR = CSR \| zext(rs1_field)` (立即数版 CSRRS) |
| **CSRRCI** | `0x7` | `rd = CSR; CSR = CSR & ~zext(rs1_field)` (立即数版 CSRRCI) |

**立即数版本的特别说明**：
- `funct3` = `5/6/7` 时，指令的 `rs1[19:15]` 字段不再是寄存器号，而是一个 **5-bit 无符号立即数**（`uimm[4:0]`）
- 如果 `uimm == 0`，立即数 CSRRSI/CSRRCI 的效果就是"只读不写"（常用于 `csrr rd, csr` 伪指令）

### 6.3 常用伪指令

RISC-V 汇编器支持以下伪指令，编译器会自动展开：

| 伪指令 | 展开为 | 效果 |
|--------|--------|------|
| `csrr rd, csr` | `csrrs rd, csr, x0` | 读 CSR 到 rd |
| `csrw csr, rs1` | `csrrw x0, csr, rs1` | 写 rs1 到 CSR（旧值丢弃） |
| `csrs csr, rs1` | `csrrs x0, csr, rs1` | 置位 CSR（旧值丢弃） |
| `csrc csr, rs1` | `csrrc x0, csr, rs1` | 清除 CSR 位（旧值丢弃） |
| `csrwi csr, imm` | `csrrwi x0, csr, imm` | 立即数写 CSR |
| `csrsi csr, imm` | `csrrsi x0, csr, imm` | 立即数置位 CSR |
| `csrci csr, imm` | `csrrci x0, csr, imm` | 立即数清除 CSR |

### 6.4 CSR 指令的硬件实现要点

```verilog
// CSR 读：从 CSR 寄存器堆读出旧值，写到 rd
csr_read_data = csr_regfile[csr_addr];

// CSR 写：根据 funct3 计算新值
case (funct3)
    3'b001: csr_write_data = rs1_val;              // CSRRW
    3'b010: csr_write_data = csr_read_data | rs1_val;   // CSRRS
    3'b011: csr_write_data = csr_read_data & ~rs1_val;  // CSRRC
    3'b101: csr_write_data = {27'd0, rs1_val[4:0]};     // CSRRWI
    3'b110: csr_write_data = csr_read_data | {27'd0, rs1_val[4:0]};  // CSRRSI
    3'b111: csr_write_data = csr_read_data & ~{27'd0, rs1_val[4:0]}; // CSRRCI
endcase

// 写回：如果 rd != x0，rd ← csr_read_data（通用寄存器写回）
//       同时更新 CSR（如果是写操作）
```

### 6.5 CSR 指令在流水线中的位置

CSR 指令需要在 **EX 阶段**有专用的 CSR 读口（读 CSR 寄存器堆），在 **WB 阶段**写回 rd。建议把它放到 ALU 旁边：

```
ID stage  →  识别 CSR 指令, 译出 csr_addr[11:0] + funct3
EX stage  →  csr_read = csr_regfile[csr_addr];        // 读出旧值
             csr_write = 根据 funct3/rs1 计算           // 计算新值
             rd_val_o  = csr_read                      // 输出到 rd（给 MEM pipe）
MEM stage →  csr_regfile[csr_addr] <= csr_write;      // 写入 CSR（本周期生效？）
```

**时序陷阱**：如果 EX 阶段读 CSR、MEM 阶段写 CSR，而下一个周期的 EX 阶段又要读同个 CSR，就会出现 RAW 冒险——需要转发。

**简化方案**：所有 CSR 操作在 **EX 阶段完整完成**（读写都在同一拍），避免冒险。

```verilog
// EX stage 完成 CSR 读写
csr_read_data = csr_regfile[csr_addr];
if (csr_we) csr_regfile[csr_addr] <= csr_write_data;
```

---

## 7. 软件上下文与 ABI

### 7.1 调用约定

RISC-V 标准调用约定定义了哪些寄存器需要调用者/被调用者保存：

| 寄存器 | ABI 名称 | 保存者 | 用途 |
|--------|----------|--------|------|
| x0 | zero | — | 硬连线 0 |
| x1 | ra | Caller | 返回地址 |
| x2 | sp | Callee | 栈指针 |
| x3 | gp | — | 全局指针 |
| x4 | tp | — | 线程指针 |
| x5-x7 | t0-t2 | Caller | 临时寄存器 |
| x8 | s0/fp | Callee | 帧指针 |
| x9 | s1 | Callee | 保存寄存器 |
| x10-x11 | a0-a1 | Caller | 函数参数/返回值 |
| x12-x17 | a2-a7 | Caller | 函数参数 |
| x18-x27 | s2-s11 | Callee | 保存寄存器 |
| x28-x31 | t3-t6 | Caller | 临时寄存器 |

**Trap handler 中的寄存器保存**：

进入 trap handler 后，handler 需要保存 **所有可能被它使用的寄存器**。对于本工程（只有 M-mode），最小保存方案：

```asm
trap_entry:
    # 交换 mscratch 和 t0（这样 t0 可以用 mscratch 保存）
    csrrw   t0, mscratch, t0

    # 保存 caller-saved 寄存器（至少 a0-a7, ra, t0-t6）
    sw      ra,  0*4(sp)
    sw      a0,  1*4(sp)
    # ... 更多寄存器 ...
```

### 7.2 ECALL 作为系统调用

GCC 编译的程序没有操作系统，一切 I/O 通过 ECALL 实现。本工程的 syscall ABI 举例：

```c
// 软件侧（C 代码）
void _write(int fd, const char* buf, int len) {
    register int a0 asm("a0") = 1;        // syscall number: write = 1
    register int a1 asm("a1") = fd;       // fd
    register int a2 asm("a2") = (int)buf; // buffer
    register int a3 asm("a3") = len;      // length
    asm volatile ("ecall");
}
```

对应的 trap handler：

```asm
# 读 syscall 编号
csrr    t0, mcause
li      t1, 11            # ECALL from M-mode?
bne     t0, t1, other_trap

# 读 a0 = syscall number
# a0 是 x10，需要从被打断程序的上下文中取出
# （如果 handler 保存了所有寄存器，从栈上读）

# 处理 write syscall：
#   逐个字符输出到 UART
#   写回返回值到 a0 (x10)
```

### 7.3 一个完整的最小 Trap Handler

```asm
.section .text.trap, "ax"
.align 2

.globl trap_entry
trap_entry:
    # 1. 保存被中断的上下文
    addi    sp, sp, -16*4
    sw      ra,  0*4(sp)
    sw      t0,  1*4(sp)
    sw      t1,  2*4(sp)
    sw      t2,  3*4(sp)
    sw      a0,  4*4(sp)
    sw      a1,  5*4(sp)
    sw      a2,  6*4(sp)
    sw      a3,  7*4(sp)
    sw      a4,  8*4(sp)
    sw      a5,  9*4(sp)
    sw      a6, 10*4(sp)
    sw      a7, 11*4(sp)
    sw      t3, 12*4(sp)
    sw      t4, 13*4(sp)
    sw      t5, 14*4(sp)
    sw      t6, 15*4(sp)

    # 2. 读 mcause
    csrr    t0, mcause
    srli    t1, t0, 31
    bnez    t1, trap_interrupt    # bit31=1 → 中断

    # 3. 异常处理
    andi    t0, t0, 0x7FFFFFFF
    li      t1, 11               # ECALL from M-mode
    beq     t0, t1, handle_ecall
    li      t1, 2                # Illegal instruction
    beq     t0, t1, handle_illegal
    j       trap_return

handle_ecall:
    # a0 = syscall number (寄存器 a0 尚未破坏)
    li      t0, 1                # write syscall?
    bne     a0, t0, handle_exit
    # write(fd=a1, buf=a2, len=a3):
    #   ... UART 输出 ...
    j       trap_return

handle_exit:
    # 死循环或关机
    wfi
    j       handle_exit

handle_illegal:
    # 可以在这里软件模拟 MUL/DIV 等不支持指令
    csrr    t0, mtval            # 读出错的指令编码
    # ... 模拟 ...
    j       trap_return

trap_interrupt:
    andi    t0, t0, 0x7FFFFFFF
    li      t1, 7                # Timer interrupt?
    beq     t0, t1, handle_timer
    li      t1, 11               # External interrupt?
    beq     t0, t1, handle_uart
    j       trap_return

handle_timer:
    # 写 mtimecmp 或清除计时器
    j       trap_return

handle_uart:
    # 处理 UART RX/TX 中断
    j       trap_return

trap_return:
    # ECALL 后要 mepc += 4（否则 MRET 又触发 ECALL）
    csrr    t0, mcause
    srli    t0, t0, 31
    bnez    t0, 1f               # 中断不跳过
    csrr    t0, mepc
    addi    t0, t0, 4            # 跳过 ECALL 指令
    csrw    mepc, t0
1:
    # 恢复寄存器
    lw      ra,  0*4(sp)
    lw      t0,  1*4(sp)
    lw      t1,  2*4(sp)
    lw      t2,  3*4(sp)
    lw      a0,  4*4(sp)
    lw      a1,  5*4(sp)
    lw      a2,  6*4(sp)
    lw      a3,  7*4(sp)
    lw      a4,  8*4(sp)
    lw      a5,  9*4(sp)
    lw      a6, 10*4(sp)
    lw      a7, 11*4(sp)
    lw      t3, 12*4(sp)
    lw      t4, 13*4(sp)
    lw      t5, 14*4(sp)
    lw      t6, 15*4(sp)
    addi    sp, sp, 16*4
    mret
```

---

## 8. 本 CPU 的实现建议

### 8.1 新增文件

```
rtl/
├── csr/
│   └── csr_regfile.v        # CSR 寄存器堆（含 trap 入口状态机）
└── CPU.v                    # 修改：接入 csr/trap 信号
```

### 8.2 第一阶段：最小闭环（ECALL → MRET round-trip）

**目标**：写一个程序 `ecall; mret`，能来回跑不跑飞。

**需要实现的**：

| 序号 | 任务 | 工作量 |
|------|------|--------|
| 1 | CSR 寄存器堆（至少实现 `mstatus`、`mepc`、`mcause`、`mtvec`，每个 32-bit） | 小 |
| 2 | 非法指令检测（译码器输出 `illegal_instr`） | 小（`decode.v` 已有返回默认值的 fallback） |
| 3 | Trap 入口逻辑（EX 阶段检测异常/中断，冲刷流水线，写 CSR） | 中 |
| 4 | CSRRW 指令（只做最基础的 CSR 读写，funct3=0x1） | 小 |
| 5 | MRET 指令（funct3=0x0，rs1=x0，rd=x0，从 mepc 跳回） | 小 |

### 8.3 第二阶段：中断

**目标**：Timer 中断能触发，UART 中断能处理。

**需要新增**：

| 任务 | 说明 |
|------|------|
| `mie` / `mip` 寄存器 | 中断分开关 + 挂起状态 |
| 中断仲裁 | 多个中断同时发生时，按优先级选择最高优先级 |
| Timer 外设 (`mtime`/`mtimecmp`) | 两个 64-bit 寄存器，`mtimecmp` 可写，`mtime` 自增 |
| 连接到 `mip.MTIP` | Timer 中断线 |

### 8.4 流水线集成要点

Trap 本质上是一种特殊的"分支"——需要冲刷流水线。你已有的 `flush` 机制可以直接复用：

```verilog
// 在 EX 阶段检查 trap 条件
assign trap_taken = illegal_instr_o | ecall_o | ebreak_o | interrupt_pending;

// 搬运到你已有的 flush 逻辑中
wire flush = ex_jump_en | trap_taken;    // 原先是 ex_jump_en
```

**Trap 的流水线冲刷与 branch 完全一样**：
- IF/ID 和 ID/EX pipe 清空（注入 NOP）
- 唯一区别是 trap 需要额外写 CSR（mstatus/mepc/mcause/mtval）

### 8.5 寄存器堆的写口

CSR 指令需要写回 rd（通用寄存器），这个走你已有的 WB 写口就行。CSR 本身的写需要独立的一对寄存器堆读写口（CSR 寄存器堆 ≠ x0-x31 寄存器堆）：

```
    ┌───────────┐         ┌───────────┐
    │  x0-x31   │         │ CSR 0-4095│
    │ regfile.v │         │ csr_reg.v │
    └─────┬─────┘         └─────┬─────┘
          │                     │
    EX: 2R/1W               EX: 1R/1W
    WB: 1W  (rd write)      MEM: (csr write, 或都在 EX)
```

### 8.6 验证方案

**单元级**：
- CSR 读/写测试：写 `csrrw` 验证写入读取
- MRET 测试：进入 trap → MRET 返回，验证 PC 恢复

**集成级**：
- ECALL 测试：`ecall` + handler 计数，每次 `ecall` handler 中 `t0 += 1`，跑 100 次验证
- 中断测试：Timer 中断周期触发，handler 计数

**软件级**：
- 写一个 C 程序 `printf("hello\n")`，经 `_write()` → ECALL → handler 输出到 UART

---

## 附录 A：所有 CSR 地址快速索引

| 地址 | 名称 | 描述 | 本工程 |
|------|------|------|--------|
| 0x300 | `mstatus` | 全局状态 | 🔴必须 |
| 0x301 | `misa` | ISA 信息 | 🔶建议 |
| 0x304 | `mie` | 中断使能 | 🔴必须 |
| 0x305 | `mtvec` | Trap 入口地址 | 🔴必须 |
| 0x340 | `mscratch` | 暂存寄存器 | 🔶建议 |
| 0x341 | `mepc` | Trap 返回地址 | 🔴必须 |
| 0x342 | `mcause` | Trap 原因 | 🔴必须 |
| 0x343 | `mtval` | Trap 附加信息 | 🔴必须 |
| 0x344 | `mip` | 中断挂起 | 🔴必须 |
| 0xF11 | `mvendorid` | 厂商 ID | 🟢可选 |
| 0xF12 | `marchid` | 架构 ID | 🟢可选 |
| 0xF13 | `mimpid` | 实现 ID | 🟢可选 |
| 0xF14 | `mhartid` | 线程 ID | 🟢可选 |

## 附录 B：最小 CSR 寄存器堆 Verilog 伪代码

```verilog
module csr_regfile (
    input  wire        clk,
    input  wire        rst_n,

    // CSR read port
    input  wire [11:0] csr_addr_i,
    output wire [31:0] csr_rdata_o,

    // CSR write port
    input  wire        csr_we_i,
    input  wire [11:0] csr_waddr_i,
    input  wire [31:0] csr_wdata_i,

    // Trap entry (from EX stage)
    input  wire        trap_taken_i,
    input  wire [31:0] trap_pc_i,
    input  wire [31:0] trap_cause_i,
    input  wire [31:0] trap_tval_i,

    // MRET (from EX stage)
    input  wire        mret_i,

    // Outputs
    output wire [31:0] mtvec_o,
    output wire [31:0] mepc_o
);

    reg [31:0] mstatus, mie, mtvec, mscratch, mepc, mcause, mtval, mip;

    // 读取
    always_comb begin
        case (csr_addr_i)
            12'h300: csr_rdata_o = mstatus;
            12'h301: csr_rdata_o = 32'h40000100;  // misa hardwired
            12'h304: csr_rdata_o = mie;
            12'h305: csr_rdata_o = mtvec;
            12'h340: csr_rdata_o = mscratch;
            12'h341: csr_rdata_o = mepc;
            12'h342: csr_rdata_o = mcause;
            12'h343: csr_rdata_o = mtval;
            12'h344: csr_rdata_o = mip;
            default: csr_rdata_o = 32'h0;
        endcase
    end

    // 写入（MRET、Trap、CSR 写指令三者的优先级需要处理）
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus <= 32'h00001800;  // MPP=M-mode
            mie    <= 32'h0;
            mtvec  <= 32'h0;
            mepc   <= 32'h0;
            mcause <= 32'h0;
            mtval  <= 32'h0;
            mip    <= 32'h0;
        end else begin
            // MRET 优先级最高
            if (mret_i) begin
                mstatus[7]  <= mstatus[7];  // MIE ← MPIE (实现: mstatus[7]=MPIE)
                mstatus[7]  <= 1'b1;         // MPIE ← 1, 这里需要重新设计
                // 简化为：MIE <= MPIE; MPIE <= 1
            end
            // Trap entry
            else if (trap_taken_i) begin
                mstatus[7]  <= mstatus[3];   // MPIE ← MIE
                mstatus[3]  <= 1'b0;         // MIE ← 0
                mstatus[12:11] <= 2'b11;     // MPP ← M-mode
                mepc   <= trap_pc_i;
                mcause <= trap_cause_i;
                mtval  <= trap_tval_i;
            end
            // CSR 写指令
            else if (csr_we_i) begin
                case (csr_waddr_i)
                    12'h300: mstatus <= csr_wdata_i;
                    12'h304: mie     <= csr_wdata_i;
                    12'h305: mtvec   <= csr_wdata_i;
                    12'h340: mscratch <= csr_wdata_i;
                    12'h341: mepc    <= csr_wdata_i;
                    12'h342: mcause  <= csr_wdata_i;
                    12'h343: mtval   <= csr_wdata_i;
                endcase
            end
        end
    end

    assign mtvec_o = mtvec;
    assign mepc_o  = mepc;

endmodule
```

---

*文档版本: 1.0 | 日期: 2026-07-20 | 面向 D:\MY\cpu 工程*
