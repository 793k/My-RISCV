#!/usr/bin/env python3
"""
格式化项目内所有 Verilog 文件
步骤：1) Verible 对齐  2) 后处理插入空行和段落注释
"""

import re
import subprocess
import sys
from pathlib import Path

# 配置
RTL_DIR = Path("rtl")
SIM_DIR = Path("sim")

EMBEDDED_FORMATTER = Path(__file__).parent / "tools" / "verible-verilog-format.exe"
FORMATTER = str(EMBEDDED_FORMATTER) if EMBEDDED_FORMATTER.exists() else "verible-verilog-format"

VERIBLE_FLAGS = [
    "--assignment_statement_alignment=align",
    "--case_items_alignment=align",
    "--port_declarations_alignment=align",
    "--module_net_variable_alignment=align",
    "--formal_parameters_alignment=align",
    "--indentation_spaces=4",
    "--inplace",
]


def find_files():
    files = []
    for directory in [RTL_DIR, SIM_DIR]:
        if directory.exists():
            files.extend(directory.rglob("*.v"))
            files.extend(directory.rglob("*.sv"))
    return sorted(files)


def run_verible(filepath):
    cmd = [FORMATTER] + VERIBLE_FLAGS + [str(filepath)]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.returncode == 0
    except FileNotFoundError:
        print(f"[FAIL] 找不到 '{FORMATTER}'")
        sys.exit(1)


def align_port_declarations(lines):
    """对齐模块内的端口声明"""
    port_re = re.compile(r"^(\s*)(input|output|inout)\b\s*(.*)$")

    ports = []
    for i, line in enumerate(lines):
        m = port_re.match(line)
        if not m:
            continue
        # 跳过非端口声明（如 input 在模块内部作为 wire 声明）
        if len(m.group(1)) > 4:
            continue

        indent = m.group(1)
        direction = m.group(2)
        rest = m.group(3).strip()

        # 分离尾部注释
        comment = ""
        comment_pos = rest.find("//")
        if comment_pos != -1:
            comment = rest[comment_pos:]
            rest = rest[:comment_pos].strip()

        # 分离结尾符号 , 或 ;
        ending = ""
        if rest.endswith(",") or rest.endswith(";"):
            ending = rest[-1]
            rest = rest[:-1].strip()

        # 从 rest 中提取 width [x:y]
        wm = re.match(r"^(\[.*?\])\s*(.*)$", rest)
        if wm:
            width = wm.group(1)
            rest2 = wm.group(2).strip()
        else:
            width = ""
            rest2 = rest

        # 从 rest2 中提取 type (wire/reg/logic) 和 name
        tm = re.match(r"^(wire|reg|logic)\s+(.*)$", rest2)
        if tm:
            var_type = tm.group(1)
            name = tm.group(2)
        else:
            var_type = ""
            name = rest2

        ports.append(
            {
                "idx": i,
                "indent": indent,
                "direction": direction,
                "var_type": var_type,
                "width": width,
                "name": name,
                "ending": ending,
                "comment": comment,
            }
        )

    if len(ports) < 2:
        return lines

    max_dir = max(len(p["direction"]) for p in ports)
    max_type = max(len(p["var_type"]) for p in ports)
    max_width = max(len(p["width"]) for p in ports)

    result = list(lines)
    for p in ports:
        parts = [p["indent"], p["direction"].ljust(max_dir)]

        # type 列
        if max_type > 0:
            if p["var_type"]:
                parts.append(" " + p["var_type"].ljust(max_type))
            else:
                parts.append(" " + " " * max_type)

        # width 列
        if max_width > 0:
            if p["width"]:
                parts.append(" " + p["width"].ljust(max_width))
            else:
                parts.append(" " + " " * max_width)

        # name + 结尾
        parts.append(" " + p["name"] + p["ending"])

        # 注释
        if p["comment"]:
            parts.append(" " + p["comment"])

        parts.append("\n")
        result[p["idx"]] = "".join(parts)

    return result


def expand_case_begin_blocks(lines):
    """处理 case 标签后的 begin/end 块：
    - 纯语句块（无嵌套控制结构）：begin 移到下一行，提升可读性
    - 含控制结构的块：begin 保持在标签行，避免过深缩进
    - 标签后裸 if/else：加 begin/end 包裹
    - 标准化已有展开块的缩进
    """
    result = list(lines)

    # 定位 case...endcase 块
    case_blocks = []
    in_case = False
    case_start = None
    for idx, line in enumerate(result):
        s = line.strip()
        if re.match(r"^\s*case\b", s) and not in_case:
            in_case = True
            case_start = idx
        elif s == "endcase" and in_case:
            case_blocks.append((case_start, idx))
            in_case = False

    def is_control_keyword(stripped):
        if not stripped:
            return False
        return any(
            stripped.startswith(kw)
            for kw in ("if ", "else", "case", "always", "assign", "initial", "for ", "while ", "forever ")
        ) or stripped in ("if", "else", "case", "always", "assign", "initial")

    for start, end in case_blocks:
        i = start + 1
        while i < end:
            line = result[i]
            stripped = line.strip()

            if not stripped or stripped.startswith("//"):
                i += 1
                continue

            if stripped.startswith("case") or stripped == "endcase":
                i += 1
                continue

            # 找标签行的冒号（跳过位宽 [x:y] 中的冒号）
            colon_pos = -1
            bracket_depth = 0
            for cp, ch in enumerate(stripped):
                if ch == "[":
                    bracket_depth += 1
                elif ch == "]":
                    bracket_depth -= 1
                elif ch == ":" and bracket_depth <= 0:
                    colon_pos = cp
                    break

            if colon_pos == -1:
                i += 1
                continue

            prefix = stripped[:colon_pos]
            if "?" in prefix:
                i += 1
                continue

            tag_prefix = stripped[:colon_pos + 1]
            suffix = stripped[colon_pos + 1:].strip()
            indent = line[: len(line) - len(line.lstrip())]

            # --- 情况 A: 标签行同一行有 begin（verible 标准输出）---
            if suffix.startswith("begin"):
                # 找与标签行 begin 匹配的 end
                j = i + 1
                nested_depth = 0
                block_end = -1
                while j < len(result):
                    js = result[j].strip()
                    if js.startswith("begin"):
                        nested_depth += 1
                    elif js == "end" or js.startswith("end "):
                        if nested_depth == 0:
                            block_end = j
                            break
                        nested_depth -= 1
                    j += 1

                if block_end == -1:
                    i += 1
                    continue

                # 检查块内是否有控制结构（if/case/always 等）
                has_control = False
                for k in range(i + 1, block_end):
                    ks = result[k].strip()
                    if ks and not ks.startswith("//") and is_control_keyword(ks):
                        has_control = True
                        break

                # 收集有效语句行
                stmt_indices = [
                    k for k in range(i + 1, block_end)
                    if result[k].strip() and not result[k].strip().startswith("//")
                ]

                # 纯语句块且有多条语句 → 展开为 begin 在下一行
                if len(stmt_indices) > 1 and not has_control:
                    result[i] = indent + tag_prefix + "\n"
                    begin_indent = indent + "    "
                    stmt_indent = begin_indent + "    "
                    for k in stmt_indices:
                        result[k] = stmt_indent + result[k].strip() + "\n"
                    result.insert(i + 1, begin_indent + "begin\n")
                    block_end += 1
                    result[block_end] = begin_indent + "end\n"
                    end += 1
                    i = block_end + 1
                    continue

            # --- 情况 B: 标签行以 : 结尾（或 :+空格），下一行是 begin（用户手动改的格式）---
            elif not suffix or suffix.isspace():
                if i + 1 < end:
                    next_stripped = result[i + 1].strip()
                    if next_stripped == "begin" or next_stripped.startswith("begin "):
                        # 找匹配的 end
                        j = i + 2
                        nested_depth = 0
                        block_end = -1
                        while j < len(result):
                            js = result[j].strip()
                            if js == "begin" or js.startswith("begin "):
                                nested_depth += 1
                            elif js == "end" or js.startswith("end "):
                                if nested_depth == 0:
                                    block_end = j
                                    break
                                nested_depth -= 1
                            j += 1

                        if block_end != -1:
                            has_control = False
                            for k in range(i + 2, block_end):
                                ks = result[k].strip()
                                if ks and not ks.startswith("//") and is_control_keyword(ks):
                                    has_control = True
                                    break

                            stmt_indices = [
                                k for k in range(i + 2, block_end)
                                if result[k].strip() and not result[k].strip().startswith("//")
                            ]

                            if len(stmt_indices) > 1 and not has_control:
                                begin_indent = indent + "    "
                                stmt_indent = begin_indent + "    "
                                result[i + 1] = begin_indent + "begin\n"
                                for k in stmt_indices:
                                    result[k] = stmt_indent + result[k].strip() + "\n"
                                result[block_end] = begin_indent + "end\n"
                                i = block_end + 1
                                continue

            # --- 情况 C: 标签在同一行结束，下一行是 if/else 块（裸 if，需加 begin/end）---
            elif not suffix and i + 1 < end:
                next_stripped = result[i + 1].strip()
                if next_stripped.startswith("if ") or next_stripped.startswith("else"):
                    j = i + 1
                    depth = 0
                    block_end = -1
                    while j < len(result):
                        js = result[j].strip()
                        if js.startswith("begin"):
                            depth += 1
                        elif js == "end" or js.startswith("end "):
                            depth -= 1
                            if depth == 0:
                                block_end = j
                                if (
                                    j + 1 < len(result)
                                    and result[j + 1].strip().startswith("else")
                                ):
                                    j += 1
                                    continue
                                break
                        j += 1

                    if block_end > i:
                        result[i] = indent + tag_prefix + " begin\n"
                        for k in range(i + 1, block_end + 1):
                            old = result[k]
                            if old.strip():
                                result[k] = "    " + old
                        result.insert(block_end + 1, indent + "end\n")
                        end += 1
                        i = block_end + 2
                        continue

            i += 1

    return result


def fix_case_lines(lines):
    """把 case/default 标签后的单条短语句合并到同一行；if 块保持展开"""
    result = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        is_case_label = (
            stripped.endswith(":")
            and not stripped.startswith("//")
            and (
                stripped.startswith("case")
                or stripped.startswith("default")
                or "`instr_sel" in stripped
                or re.search(r"\b[\w`]+\s*:\s*$", stripped)
            )
        )

        merged = False

        if is_case_label and i + 1 < len(lines):
            next_line = lines[i + 1]
            next_stripped = next_line.strip()

            # 只合并非 if/case/default/begin/end/空/注释/另一个标签的单条语句
            if (
                next_stripped
                and not next_stripped.startswith("//")
                and not next_stripped.startswith("begin")
                and not next_stripped.startswith("end")
                and not next_stripped.startswith("if")
                and not next_stripped.startswith("case")
                and not next_stripped.startswith("default")
                and not next_stripped.endswith(":")
            ):
                indent = line[: len(line) - len(line.lstrip())]
                result.append(indent + stripped + " " + next_stripped + "\n")
                i += 2
                merged = True

        if not merged:
            result.append(line)
            i += 1

    return result


def align_case_colons(lines):
    """按段落（空行分隔）对齐 case 块内标签的冒号"""
    result = list(lines)

    # 找到所有 case...endcase 块的范围
    case_blocks = []
    in_case = False
    case_start = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if re.match(r"^\s*case\b", stripped) and not in_case:
            in_case = True
            case_start = i
        elif stripped == "endcase" and in_case:
            case_blocks.append((case_start, i))
            in_case = False

    for start, end in case_blocks:
        # 收集块内所有 case 标签信息
        tag_info = {}
        for i in range(start + 1, end):
            line = lines[i]
            stripped = line.strip()
            if not stripped or stripped.startswith("//"):
                continue
            if stripped.startswith("begin") or stripped.startswith("end"):
                continue
            if stripped == "endcase":
                break

            code_part = stripped
            comment = ""
            comment_pos = code_part.find("//")
            if comment_pos != -1:
                comment = code_part[comment_pos:]
                code_part = code_part[:comment_pos].rstrip()

            if ":" not in code_part:
                continue

            # 找到第一个不在方括号 [...] 内的冒号（避免位宽表达式）
            def _is_in_brackets(s, pos):
                depth = 0
                for i, c in enumerate(s):
                    if i >= pos:
                        break
                    if c == "[":
                        depth += 1
                    elif c == "]":
                        depth -= 1
                return depth > 0

            colon_pos = -1
            for cp in range(len(code_part)):
                if code_part[cp] == ":" and not _is_in_brackets(code_part, cp):
                    colon_pos = cp
                    break

            if colon_pos == -1:
                continue

            prefix = code_part[:colon_pos].rstrip()
            suffix = code_part[colon_pos + 1:].strip()

            # 排除 ?: 三元运算符
            if "?" in prefix:
                continue

            indent = line[: len(line) - len(line.lstrip())]
            parts = [p.strip() for p in prefix.split(",")]
            tag_info[i] = {
                "idx": i,
                "indent": indent,
                "parts": parts,
                "suffix": suffix,
                "comment": comment,
            }

        if len(tag_info) < 2:
            continue

        # 按空行和标签 part 数分段落
        paragraphs = []
        current_para = []
        current_parts_count = None
        sorted_indices = sorted(tag_info.keys())

        for idx in sorted_indices:
            parts_count = len(tag_info[idx]["parts"])
            if current_para:
                prev_idx = current_para[-1]
                has_blank = False
                for j in range(prev_idx + 1, idx):
                    if lines[j].strip() == "":
                        has_blank = True
                        break
                if has_blank or parts_count != current_parts_count:
                    paragraphs.append(current_para)
                    current_para = []
            current_para.append(idx)
            current_parts_count = parts_count

        if current_para:
            paragraphs.append(current_para)

        # 每个段落独立对齐冒号
        for para in paragraphs:
            if len(para) < 2:
                continue

            para_labels = [tag_info[idx] for idx in para]

            # 计算每列最大宽度
            max_cols = max(len(cl["parts"]) for cl in para_labels)
            max_widths = [0] * max_cols
            for cl in para_labels:
                for j, part in enumerate(cl["parts"]):
                    max_widths[j] = max(max_widths[j], len(part))

            # 计算该段落最大总前缀宽度
            all_prefixes = []
            for cl in para_labels:
                padded = [p.ljust(max_widths[k]) for k, p in enumerate(cl["parts"])]
                all_prefixes.append(", ".join(padded) + ":")
            max_total = max(len(p) for p in all_prefixes)

            for cl in para_labels:
                idx = cl["idx"]
                indent = cl["indent"]
                parts = cl["parts"]
                suffix = cl["suffix"]
                comment = cl["comment"]

                padded_parts = [p.ljust(max_widths[k]) for k, p in enumerate(parts)]
                prefix = ", ".join(padded_parts) + ":"
                prefix_padded = prefix.ljust(max_total)

                new_line = indent + prefix_padded
                if suffix:
                    new_line += " " + suffix
                if comment:
                    new_line += " " + comment
                new_line += "\n"
                result[idx] = new_line

    return result


def format_if_statements(lines):
    """规范化 if/else 语句中的空格，不增删代码只调整空格/空行"""
    result = []
    for line in lines:
        new_line = line

        # if( / else( → if ( / else (
        new_line = re.sub(r'\b(if|else)\s*\(', r'\1 (', new_line)

        # )begin → ) begin
        new_line = re.sub(r'\)\s*begin\b', ') begin', new_line)

        # elsebegin → else begin
        new_line = re.sub(r'\belse\s*begin\b', 'else begin', new_line)

        # endelse → end else
        new_line = re.sub(r'\bend\s*else\b', 'end else', new_line)

        # elseif → else if
        new_line = re.sub(r'\belse\s*if\b', 'else if', new_line)

        # 赋值号 = 周围加空格（排除 ==、!=、<=、>=、=> 等复合运算符）
        new_line = re.sub(r'(?<![=<>!])\s*=\s*(?![=<>])', ' = ', new_line)

        result.append(new_line)
    return result


def indent_case_if_blocks(lines):
    """调整 case 标签后 if/else 块的缩进，使 if 行对齐到标签冒号之后"""
    result = list(lines)
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # 检测 case 标签行（以冒号结尾，排除 case/endcase 关键字本身）
        if not stripped.endswith(":"):
            i += 1
            continue
        if stripped.startswith("//") or stripped.startswith("case"):
            i += 1
            continue

        is_case_label = (
            stripped.startswith("default")
            or "`instr_sel" in stripped
            or re.search(r"\b[\w`]+\s*:\s*$", stripped)
        )

        if not is_case_label or i + 1 >= len(lines):
            i += 1
            continue

        next_line = lines[i + 1]
        next_stripped = next_line.strip()
        if not (next_stripped.startswith("if ") or next_stripped.startswith("else")):
            i += 1
            continue

        # 计算目标缩进：标签行缩进 + 标签前缀（到冒号为止）长度
        label_indent = len(line) - len(line.lstrip())
        prefix_len = len(stripped.rstrip())
        target_indent = label_indent + prefix_len

        # 收集整个 if/else 链（含嵌套 begin...end）
        j = i + 1
        block_indices = []
        begin_depth = 0

        while j < len(lines):
            curr_line = lines[j]
            curr_stripped = curr_line.strip()

            block_indices.append(j)

            if curr_stripped.startswith("begin"):
                begin_depth += 1
            elif curr_stripped == "end" or curr_stripped.startswith("end "):
                begin_depth -= 1
                if begin_depth <= 0:
                    # 检查 end 后面是否有 else/else if
                    if j + 1 < len(lines):
                        next_next_stripped = lines[j + 1].strip()
                        if next_next_stripped.startswith("else"):
                            j += 1
                            continue
                    break

            j += 1

        if not block_indices:
            i += 1
            continue

        # 调整整个块的缩进
        current_if_indent = len(lines[block_indices[0]]) - len(lines[block_indices[0]].lstrip())
        delta = target_indent - current_if_indent

        for idx in block_indices:
            old_line = result[idx]
            old_indent = len(old_line) - len(old_line.lstrip())
            new_indent = max(0, old_indent + delta)
            result[idx] = " " * new_indent + old_line.lstrip()

        i = j + 1

    return result


def post_process(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # 先对齐端口声明
    lines = align_port_declarations(lines)

    # 展开 case 标签后紧凑的多语句 begin/end 块，给 if/else 块加 begin/end 包裹
    lines = expand_case_begin_blocks(lines)

    # 修复 case 标签换行（单条语句合并到标签行）
    lines = fix_case_lines(lines)

    # 对齐 case 块内标签的冒号
    lines = align_case_colons(lines)

    # 规范化 if/else 语句空格
    lines = format_if_statements(lines)

    # 调整 case 标签后 if/else 块的缩进
    lines = indent_case_if_blocks(lines)

    # 第一步：合并连续的单行注释（去掉中间的空白行）
    merged = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if stripped.startswith("//"):
            # 收集整个注释块
            block = [line]
            j = i + 1
            while j < len(lines):
                s = lines[j].strip()
                if s == "":
                    # 看看空行后面是否还是注释
                    k = j + 1
                    while k < len(lines) and lines[k].strip() == "":
                        k += 1
                    if k < len(lines) and lines[k].strip().startswith("//"):
                        j = k  # 跳过空行，继续收集注释
                    else:
                        break
                elif s.startswith("//"):
                    block.append(lines[j])
                    j += 1
                else:
                    break
            merged.extend(block)
            i = j
        elif stripped == "":
            # 只保留一个空行
            merged.append(line)
            while i + 1 < len(lines) and lines[i + 1].strip() == "":
                i += 1
            i += 1
        else:
            merged.append(line)
            i += 1

    # 清理 wire/reg/logic 和紧跟的 assign 之间的空行
    cleaned = []
    i = 0
    while i < len(merged):
        line = merged[i]
        stripped = line.strip()
        if re.match(r"^\s*(reg|wire|logic)\b", stripped):
            cleaned.append(line)
            j = i + 1
            blanks = []
            while j < len(merged) and merged[j].strip() == "":
                blanks.append(merged[j])
                j += 1
            if j < len(merged) and re.match(r"^\s*assign\b", merged[j].strip()):
                i = j
                continue
            else:
                cleaned.extend(blanks)
                i = j
                continue
        cleaned.append(line)
        i += 1
    merged = cleaned

    # 第二步：按规则插入空行
    result = []
    prev_stripped = ""

    for i, line in enumerate(merged):
        stripped = line.strip()

        # 跳过重复空行（保险）
        if stripped == "":
            if result and result[-1].strip() == "":
                continue
            result.append(line)
            continue

        # 规则1: module 声明前加空行（如果前面有注释）
        if stripped.startswith("module ") and prev_stripped.startswith("//"):
            if result and result[-1].strip() != "":
                result.append("\n")

        # 规则2: `include 前后加空行
        if "`include" in stripped:
            if result and result[-1].strip() != "":
                result.append("\n")
            result.append(line)
            result.append("\n")
            prev_stripped = stripped
            continue

        # 规则3: 注释块前加空行（注释块开头，且前面不是注释）
        if stripped.startswith("//"):
            if prev_stripped != "" and not prev_stripped.startswith("//"):
                if result and result[-1].strip() != "":
                    result.append("\n")
            result.append(line)
            prev_stripped = stripped
            continue

        # 规则4: always / assign / initial 前加空行
        if re.match(r"^\s*(always|assign|initial)\b", stripped):
            # wire/reg/logic 与紧跟的 assign 配对时，不插入空行
            if not re.match(r"^\s*(reg|wire|logic)\b", prev_stripped):
                if result and result[-1].strip() != "":
                    result.append("\n")

        # 规则5: endmodule 前加空行
        if stripped == "endmodule":
            if result and result[-1].strip() != "":
                result.append("\n")

        # 规则6: 端口声明和内部信号之间加空行
        if re.match(r"^\s*(reg|wire|logic)\s", stripped):
            if re.match(r"^\s*(input|output|inout)\b", prev_stripped):
                if result and result[-1].strip() != "":
                    result.append("\n")

        result.append(line)
        prev_stripped = stripped

    # 文件末尾只留一个换行
    while result and result[-1].strip() == "":
        result.pop()
    result.append("\n")

    with open(filepath, "w", encoding="utf-8", newline="") as f:
        f.writelines(result)


def format_file(filepath):
    ok = run_verible(filepath)
    if not ok:
        print(f"[ERROR] {filepath}")
        return False

    post_process(filepath)
    print(f"[OK]    {filepath}")
    return True


def main():
    import sys

    if len(sys.argv) > 1:
        # 格式化指定文件
        filepath = Path(sys.argv[1])
        if not filepath.exists():
            print(f"文件不存在: {filepath}")
            return
        print(f"格式化: {filepath}\n")
        if format_file(filepath):
            print("\n完成")
        else:
            print("\n失败")
        return

    # 格式化全部
    files = find_files()
    if not files:
        print("没有找到 .v 或 .sv 文件")
        return

    print(f"找到 {len(files)} 个文件，开始格式化...\n")
    ok = fail = 0

    for f in files:
        if format_file(f):
            ok += 1
        else:
            fail += 1

    print(f"\n完成: {ok} 成功, {fail} 失败")


if __name__ == "__main__":
    main()
