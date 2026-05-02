#!/usr/bin/env python3
"""
Simple assembler for the custom GPU ISA.
Outputs program.hex for use with $readmemh.

Instruction formats:
  R-TYPE: [opcode(5)][rd(5)][ra(5)][rb(5)][rc(5)][func(4)][mode(3)]
  I-TYPE: [opcode(5)][rd(5)][ra(5)][imm17(17)]

Usage:
  python3 assembler.py input.asm              # prints hex to stdout
  python3 assembler.py input.asm -o prog.hex  # writes to file
"""

import sys
import re

# Opcodes
OPCODES = {
    'ALU':      0x00,
    'TENSOR':   0x01,
    'LD':       0x02,
    'ST':       0x03,
    'BEQ':      0x04,
    'BNE':      0x05,
    'BLT':      0x06,
    'BGE':      0x07,
    'LUI':      0x08,
    'ADDI':     0x09,
    'HALT':     0x0A,
    'NOP':      0x0B,
    'MOVI':     0x0C,
    'RELU_INT': 0x0D,
    'VBCAST':   0x0E,
}

# ALU func codes
ALU_FUNCS = {
    'VADD': 0, 'VSUB': 1, 'VAND': 2, 'VOR': 3, 'VXOR': 4, 'VSLT': 5,
}

# Tensor modes
TENSOR_MODES = {
    'ADD': 0, 'MUL': 1, 'FMA': 2,
}


def parse_reg(s):
    """Parse register name like R0..R31, return int."""
    s = s.strip().rstrip(',').upper()
    if s.startswith('R'):
        n = int(s[1:])
        if 0 <= n <= 31:
            return n
    raise ValueError(f"Invalid register: {s}")


def parse_imm(s, bits=17):
    """Parse immediate value (decimal or hex), return unsigned value fitting in `bits`."""
    s = s.strip().rstrip(',')
    val = int(s, 0)  # auto-detect base (0x for hex, plain for decimal)
    mask = (1 << bits) - 1
    return val & mask


def encode_r_type(opcode, rd, ra, rb, rc=0, func=0, mode=0):
    word = (opcode << 27) | (rd << 22) | (ra << 17) | (rb << 12) | (rc << 7) | (func << 3) | mode
    return word & 0xFFFFFFFF


def encode_i_type(opcode, rd, ra, imm17):
    word = (opcode << 27) | (rd << 22) | (ra << 17) | (imm17 & 0x1FFFF)
    return word & 0xFFFFFFFF


def assemble_line(line, labels, pc):
    """Assemble a single instruction line, return 32-bit word."""
    # Remove comments
    line = re.sub(r'[#;].*', '', line).strip()
    if not line:
        return None

    # Check for label
    if ':' in line:
        label_part, _, line = line.partition(':')
        line = line.strip()
        if not line:
            return None

    parts = line.replace(',', ' ').split()
    mnemonic = parts[0].upper()

    # --- HALT ---
    if mnemonic == 'HALT':
        return encode_i_type(OPCODES['HALT'], 0, 0, 0)

    # --- NOP ---
    if mnemonic == 'NOP':
        return encode_i_type(OPCODES['NOP'], 0, 0, 0)

    # --- MOVI Rd, imm ---
    if mnemonic == 'MOVI':
        rd = parse_reg(parts[1])
        imm = parse_imm(parts[2])
        return encode_i_type(OPCODES['MOVI'], rd, 0, imm)

    # --- ADDI Rd, Ra, imm ---
    if mnemonic == 'ADDI':
        rd = parse_reg(parts[1])
        ra = parse_reg(parts[2])
        imm = parse_imm(parts[3])
        return encode_i_type(OPCODES['ADDI'], rd, ra, imm)

    # --- LUI Rd, imm ---
    if mnemonic == 'LUI':
        rd = parse_reg(parts[1])
        imm = parse_imm(parts[2])
        return encode_i_type(OPCODES['LUI'], rd, 0, imm)

    # --- LD Rd, Ra, offset ---
    if mnemonic == 'LD':
        rd = parse_reg(parts[1])
        ra = parse_reg(parts[2])
        imm = parse_imm(parts[3])
        return encode_i_type(OPCODES['LD'], rd, ra, imm)

    # --- ST Rd, Ra, offset ---
    if mnemonic == 'ST':
        rd = parse_reg(parts[1])
        ra = parse_reg(parts[2])
        imm = parse_imm(parts[3])
        return encode_i_type(OPCODES['ST'], rd, ra, imm)

    # --- Branch: BEQ/BNE/BLT/BGE Rd, Ra, offset_or_label ---
    if mnemonic in ('BEQ', 'BNE', 'BLT', 'BGE'):
        rd = parse_reg(parts[1])
        ra = parse_reg(parts[2])
        target = parts[3].strip()
        if target in labels:
            offset = labels[target] - pc
            imm = offset & 0x1FFFF
        else:
            imm = parse_imm(target)
        return encode_i_type(OPCODES[mnemonic], rd, ra, imm)

    # --- ALU: VADD/VSUB/VAND/VOR/VXOR/VSLT Rd, Ra, Rb ---
    if mnemonic in ALU_FUNCS:
        rd = parse_reg(parts[1])
        ra = parse_reg(parts[2])
        rb = parse_reg(parts[3])
        func = ALU_FUNCS[mnemonic]
        return encode_r_type(OPCODES['ALU'], rd, ra, rb, rc=0, func=func, mode=0)

    # --- RELU_INT Rd, Ra ---
    if mnemonic == 'RELU_INT':
        rd = parse_reg(parts[1])
        ra = parse_reg(parts[2])
        return encode_r_type(OPCODES['RELU_INT'], rd, ra, 0, rc=0, func=0, mode=0)

    # --- VBCAST Rd, Ra, lane ---
    if mnemonic == 'VBCAST':
        rd = parse_reg(parts[1])
        ra = parse_reg(parts[2])
        lane = int(parts[3].strip(), 0)
        if lane < 0 or lane > 3:
            raise ValueError(f"VBCAST lane must be 0..3, got {lane}")
        return encode_r_type(OPCODES['VBCAST'], rd, ra, 0, rc=0, func=0, mode=lane)

    # --- Tensor: TENSOR_ADD/TENSOR_MUL/TENSOR_FMA [_RELU] Rd, Ra, Rb [, Rc] ---
    if mnemonic.startswith('TENSOR_'):
        rest = mnemonic[7:]  # remove "TENSOR_"
        relu = 0
        if rest.endswith('_RELU'):
            relu = 1
            rest = rest[:-5]
        if rest not in TENSOR_MODES:
            raise ValueError(f"Unknown tensor op: {mnemonic}")
        mode = TENSOR_MODES[rest]
        rd = parse_reg(parts[1])
        ra = parse_reg(parts[2])
        rb = parse_reg(parts[3])
        rc = 0
        if len(parts) > 4:
            rc = parse_reg(parts[4])
        func = relu  # func[0] = relu_en
        return encode_r_type(OPCODES['TENSOR'], rd, ra, rb, rc=rc, func=func, mode=mode)

    raise ValueError(f"Unknown mnemonic: {mnemonic}")


def assemble(source):
    """Two-pass assembler. Returns list of 32-bit words."""
    lines = source.strip().split('\n')

    # Pass 1: collect labels
    labels = {}
    pc = 0
    for line in lines:
        clean = re.sub(r'[#;].*', '', line).strip()
        if not clean:
            continue
        if ':' in clean:
            label = clean.split(':')[0].strip()
            labels[label] = pc
            rest = clean.split(':', 1)[1].strip()
            if rest:
                pc += 1
        else:
            pc += 1

    # Pass 2: assemble
    words = []
    pc = 0
    for line in lines:
        word = assemble_line(line, labels, pc)
        if word is not None:
            words.append(word)
            pc += 1

    return words


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} input.asm [-o output.hex]")
        sys.exit(1)

    with open(sys.argv[1], 'r') as f:
        source = f.read()

    words = assemble(source)

    output_lines = [f"{w:08X}" for w in words]
    output = '\n'.join(output_lines) + '\n'

    if '-o' in sys.argv:
        idx = sys.argv.index('-o')
        outfile = sys.argv[idx + 1]
        with open(outfile, 'w') as f:
            f.write(output)
        print(f"Assembled {len(words)} instructions -> {outfile}")
    else:
        print(output, end='')


if __name__ == '__main__':
    main()
