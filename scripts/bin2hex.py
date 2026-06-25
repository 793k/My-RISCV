#!/usr/bin/env python3
"""Convert binary file to hex text (one 32-bit word per line)."""
import sys


def bin_to_hex(bin_path, hex_path):
    with open(bin_path, "rb") as f:
        data = f.read()

    words = []
    for i in range(0, len(data), 4):
        chunk = data[i:i + 4]
        if len(chunk) < 4:
            chunk = chunk + b'\x00' * (4 - len(chunk))
        val = int.from_bytes(chunk, byteorder='little')
        words.append(val)

    with open(hex_path, "w") as f:
        for w in words:
            f.write(f"{w:08X}\n")

    print(f"bin2hex: {len(words)} words → {hex_path}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python bin2hex.py <input.bin> <output.hex>")
        sys.exit(1)
    bin_to_hex(sys.argv[1], sys.argv[2])
