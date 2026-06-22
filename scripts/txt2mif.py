#!/usr/bin/env python3
"""
Convert hex text file (one 32-bit instruction per line) to Quartus MIF format.
Usage:
    python txt2mif.py <input.txt> [output.mif]
    python txt2mif.py test_data/test.txt
"""

import sys
import os


def txt_to_mif(txt_path, mif_path=None, depth=2048, width=32):
    if mif_path is None:
        base, _ = os.path.splitext(txt_path)
        mif_path = base + ".mif"

    with open(txt_path, "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f if line.strip()]

    instructions = []
    for line in lines:
        # Remove comments if any
        line = line.split("//")[0].split("#")[0].strip()
        if not line:
            continue
        # Validate hex width
        val = int(line, 16)
        if val >= (1 << width):
            raise ValueError(f"Value {line} exceeds {width} bits")
        instructions.append(line.zfill(width // 4))

    if len(instructions) > depth:
        raise ValueError(
            f"Too many instructions ({len(instructions)}), max depth is {depth}"
        )

    with open(mif_path, "w", encoding="utf-8") as f:
        f.write(f"DEPTH = {depth};\n")
        f.write(f"WIDTH = {width};\n")
        f.write("ADDRESS_RADIX = HEX;\n")
        f.write("DATA_RADIX = HEX;\n")
        f.write("CONTENT\n")
        f.write("BEGIN\n")

        for i, instr in enumerate(instructions):
            f.write(f"\t{i:04X} : {instr};\n")

        if len(instructions) < depth:
            f.write(
                f"\t[{len(instructions):04X}..{depth - 1:04X}] : 00000000;\n"
            )

        f.write("END;\n")

    print(f"Generated: {mif_path}")
    print(f"  Instructions: {len(instructions)} / {depth}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python txt2mif.py <input.txt> [output.mif]")
        sys.exit(1)

    txt_file = sys.argv[1]
    mif_file = sys.argv[2] if len(sys.argv) > 2 else None
    txt_to_mif(txt_file, mif_file)
