#!/usr/bin/env python3
"""
fc_host.py — Host-side tool for FC layer inference on NetFPGA SoC.

Builds command packets for y = ReLU(W * X + B) where W, X, B are 4x4 BF16 matrices.
Can generate testbench hex, send/receive via raw Ethernet, and verify results.

Usage:
  python3 fc_host.py --test              # Run golden model test
  python3 fc_host.py --hex               # Print packet as hex for testbench
  python3 fc_host.py --send -i eth1      # Send packet and receive result
"""

import struct
import argparse
import numpy as np

# ═══════════════════════════════════════════════════════════════
#  BF16 Utilities
# ═══════════════════════════════════════════════════════════════

def float_to_bf16(f):
    """Convert float to BF16 (upper 16 bits of float32)."""
    b = struct.pack('>f', f)
    return struct.unpack('>H', b[:2])[0]

def bf16_to_float(h):
    """Convert BF16 to float."""
    b = struct.pack('>H', h) + b'\x00\x00'
    return struct.unpack('>f', b)[0]

def bf16_hex(f):
    """Float to BF16 hex string."""
    return f"0x{float_to_bf16(f):04X}"

# ═══════════════════════════════════════════════════════════════
#  GPU Kernel (13 instructions)
# ═══════════════════════════════════════════════════════════════

GPU_KERNEL = [
    0x20000000,  # [0]  MOVI R0, 0
    0xF0400004,  # [1]  WMMA.LOAD R4, [R0+4]
    0xF0800008,  # [2]  WMMA.LOAD R8, [R0+8]
    0xF0000000,  # [3]  WMMA.LOAD R0, [R0+0]
    0xECC04800,  # [4]  WMMA.MMA R12, R0, R4, R8
    0x20000000,  # [5]  MOVI R0, 0
    0x54CC0000,  # [6]  MAX.f R12, R12, R0
    0x54DD0000,  # [7]  MAX.f R13, R13, R0
    0x54EE0000,  # [8]  MAX.f R14, R14, R0
    0x54FF0000,  # [9]  MAX.f R15, R15, R0
    0x20000000,  # [10] MOVI R0, 0
    0xF8C00000,  # [11] WMMA.STORE R12, [R0+0]
    0xC8000000,  # [12] RET
    0x00000000,  # [13] NOP (pad)
    0x00000000,  # [14] NOP (pad)
    0x00000000,  # [15] NOP (pad)
]

# ═══════════════════════════════════════════════════════════════
#  ARM Firmware (80 instructions = 40 DWs)
# ═══════════════════════════════════════════════════════════════

ARM_NOP  = 0xE1A00000
ARM_HALT = 0xEAFFFFFE

def arm_mov(rd, imm8):
    """MOV Rd, #imm8"""
    return 0xE3A00000 | (rd << 12) | (imm8 & 0xFF)

def arm_mcr(crn, rd):
    """MCR p10, 0, Rd, CRn"""
    return 0xEE000A10 | (crn << 16) | (rd << 12)

def build_arm_firmware(dunpack_len=6, dpack_dst=48):
    """Build ARM firmware for GPU FC inference.

    Returns list of 80 instruction words (32-bit each).
    """
    prog = []

    # Phase 1: D_IMEM (CPU DMEM[0..15] → GPU IMEM)
    prog += [arm_mov(0, 0),   arm_mcr(0, 0)]     # CR0=0 (src)
    prog += [arm_mcr(1, 0),   arm_mov(1, 16)]     # CR1=0 (dst), R1=16
    prog += [arm_mcr(2, 1),   arm_mov(2, 5)]      # CR2=16 (len), R2=5
    prog += [arm_mcr(3, 2),   ARM_NOP]             # CR3=5 (D_IMEM)
    prog += [ARM_NOP] * 8                           # wait

    # Phase 2: D_UNPACK (CPU DMEM[16..] → GPU DMEM, burst_all)
    prog += [arm_mov(0, 16),  arm_mcr(0, 0)]      # CR0=16 (src)
    prog += [arm_mov(1, 0),   arm_mcr(1, 1)]      # CR1=0 (dst)
    prog += [arm_mov(2, dunpack_len), arm_mcr(2, 2)]  # CR2=len
    prog += [arm_mov(3, 0x41), arm_mcr(3, 3)]     # CR3=0x41 (burst_all|start)
    prog += [ARM_NOP] * 10                          # wait

    # Phase 3: GPU launch
    prog += [arm_mov(0, 0),   arm_mcr(4, 0)]      # CR4=0 (entry_pc)
    prog += [arm_mov(1, 0x0F), arm_mcr(7, 1)]     # CR7=0xF (thread_mask)
    prog += [arm_mov(2, 1),   arm_mcr(5, 2)]      # CR5=1 (start)
    prog += [ARM_NOP] * 20                          # wait for GPU

    # Phase 4: D_PACK (GPU DMEM → CPU DMEM, burst_all)
    prog += [arm_mov(0, 0),   arm_mcr(0, 0)]      # CR0=0 (gpu src)
    prog += [arm_mov(1, dpack_dst), arm_mcr(1, 1)] # CR1=dst (cpu)
    prog += [arm_mov(2, 2),   arm_mcr(2, 2)]      # CR2=2 (xfer)
    prog += [arm_mov(3, 0x43), arm_mcr(3, 3)]     # CR3=0x43 (burst_all|dir|start)
    prog += [ARM_NOP] * 10                          # wait for D_PACK

    # Phase 5: Halt
    prog += [ARM_HALT, ARM_NOP]

    assert len(prog) == 80, f"ARM firmware must be 80 instrs, got {len(prog)}"
    return prog

# ═══════════════════════════════════════════════════════════════
#  Matrix Data Packing
# ═══════════════════════════════════════════════════════════════

def pack_row_to_cpu_words(row_bf16):
    """Pack 4 BF16 values into 2 CPU words.
    CPU word = {DMEM[odd], DMEM[even]} = {hi16, lo16}
    """
    assert len(row_bf16) == 4
    w0 = (row_bf16[1] << 16) | row_bf16[0]
    w1 = (row_bf16[3] << 16) | row_bf16[2]
    return [w0, w1]

def pack_matrices(W, X, B):
    """Pack W, X, B (4x4 float) into CPU DMEM words for D_UNPACK burst_all.

    Returns 24 CPU words: 6 per bank (W_row + X_row + B_row).
    Banks are sequential (bank0 first, then bank1, etc.) matching
    D_UNPACK burst_all behavior.
    """
    words = []
    for bank in range(4):
        w_bf16 = [float_to_bf16(W[bank][j]) for j in range(4)]
        x_bf16 = [float_to_bf16(X[bank][j]) for j in range(4)]
        b_bf16 = [float_to_bf16(B[bank][j]) for j in range(4)]
        words += pack_row_to_cpu_words(w_bf16)
        words += pack_row_to_cpu_words(x_bf16)
        words += pack_row_to_cpu_words(b_bf16)
    assert len(words) == 24
    return words

# ═══════════════════════════════════════════════════════════════
#  Command Packet Builder
# ═══════════════════════════════════════════════════════════════

def cmd_word(opcode, addr, count, param=0):
    """Build 64-bit command word."""
    return ((opcode & 0xF) << 60) | ((addr & 0xFFF) << 48) | \
           ((count & 0xFFFF) << 32) | (param & 0xFFFFFFFF)

def pack_dw(hi32, lo32):
    """Pack two 32-bit words into one 64-bit DW (hi=bits[63:32], lo=bits[31:0])."""
    return ((hi32 & 0xFFFFFFFF) << 32) | (lo32 & 0xFFFFFFFF)

def build_packet(W, X, B, dpack_dst=48):
    """Build complete command packet for FC inference.

    Returns list of 64-bit words (no Ethernet header — added by send layer).
    """
    arm_prog = build_arm_firmware(dunpack_len=6, dpack_dst=dpack_dst)
    matrix_words = pack_matrices(W, X, B)

    packet = []

    # LOAD_IMEM: ARM firmware (40 DWs)
    packet.append(cmd_word(0x1, 0x000, 40))
    for i in range(0, 80, 2):
        packet.append(pack_dw(arm_prog[i+1], arm_prog[i]))

    # LOAD_DMEM addr=0: GPU kernel (8 DWs)
    packet.append(cmd_word(0x2, 0x000, 8))
    for i in range(0, 16, 2):
        packet.append(pack_dw(GPU_KERNEL[i+1], GPU_KERNEL[i]))

    # LOAD_DMEM addr=16: matrix data (12 DWs)
    packet.append(cmd_word(0x2, 0x010, 12))
    for i in range(0, 24, 2):
        packet.append(pack_dw(matrix_words[i+1], matrix_words[i]))

    # LOAD_DMEM addr=dpack_dst: zero readback area (4 DWs)
    packet.append(cmd_word(0x2, dpack_dst, 4))
    for _ in range(4):
        packet.append(0)

    # CPU_START
    packet.append(cmd_word(0x3, 0x000, 0, 0))

    # READBACK
    packet.append(cmd_word(0x4, dpack_dst, 4))

    # SEND_PKT
    packet.append(cmd_word(0x5, 0x000, 0))

    return packet

# ═══════════════════════════════════════════════════════════════
#  Result Parser
# ═══════════════════════════════════════════════════════════════

def parse_tx_output(tx_dws):
    """Parse TX DWs into 4x4 float result matrix.

    TX layout (4 DWs from READBACK of 4 banks × 2 packed words):
      TX[i] = {CPU[dst+2i+1], CPU[dst+2i]}
    Each CPU word = {bf16_hi, bf16_lo}
    """
    result = np.zeros((4, 4), dtype=np.float32)
    for bank in range(4):
        dw = tx_dws[bank]
        cpu_lo = dw & 0xFFFFFFFF
        cpu_hi = (dw >> 32) & 0xFFFFFFFF
        result[bank][0] = bf16_to_float(cpu_lo & 0xFFFF)
        result[bank][1] = bf16_to_float((cpu_lo >> 16) & 0xFFFF)
        result[bank][2] = bf16_to_float(cpu_hi & 0xFFFF)
        result[bank][3] = bf16_to_float((cpu_hi >> 16) & 0xFFFF)
    return result

# ═══════════════════════════════════════════════════════════════
#  Golden Model
# ═══════════════════════════════════════════════════════════════

def golden_fc(W, X, B):
    """Compute y = ReLU(W @ X + B) in float (golden reference)."""
    D = W @ X + B
    return np.maximum(D, 0)

# ═══════════════════════════════════════════════════════════════
#  Ethernet Send/Receive (for hardware testing)
# ═══════════════════════════════════════════════════════════════

ETHERTYPE_SOC = 0x88B5

def packet_to_bytes(packet_dws, dst_mac=b'\xff\xff\xff\xff\xff\xff',
                    src_mac=b'\x00\x00\x00\x00\x00\x01'):
    """Convert list of 64-bit DWs to Ethernet frame bytes."""
    frame = dst_mac + src_mac + struct.pack('>H', ETHERTYPE_SOC)
    for dw in packet_dws:
        frame += struct.pack('>Q', dw)
    # Pad to minimum Ethernet frame size (64 bytes)
    if len(frame) < 64:
        frame += b'\x00' * (64 - len(frame))
    return frame

def send_and_receive(packet_dws, iface='eth1', timeout_sec=5):
    """Send packet via raw socket and wait for response."""
    try:
        import socket
        sock = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(ETHERTYPE_SOC))
        sock.bind((iface, 0))
        sock.settimeout(timeout_sec)

        frame = packet_to_bytes(packet_dws)
        sock.send(frame)
        print(f"Sent {len(frame)} bytes on {iface}")

        resp = sock.recv(2048)
        print(f"Received {len(resp)} bytes")
        sock.close()

        # Parse response: skip 14-byte Ethernet header
        payload = resp[14:]
        tx_dws = []
        for i in range(0, len(payload), 8):
            if i + 8 <= len(payload):
                tx_dws.append(struct.unpack('>Q', payload[i:i+8])[0])
        return tx_dws

    except ImportError:
        print("Error: raw sockets require root and Linux")
        return None
    except socket.timeout:
        print("Error: no response received (timeout)")
        return None

# ═══════════════════════════════════════════════════════════════
#  CLI
# ═══════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(description='FC layer inference on NetFPGA SoC')
    parser.add_argument('--test', action='store_true', help='Run golden model test')
    parser.add_argument('--hex', action='store_true', help='Print packet as hex')
    parser.add_argument('--send', action='store_true', help='Send packet via Ethernet')
    parser.add_argument('-i', '--iface', default='eth1', help='Network interface')
    args = parser.parse_args()

    # Test matrices
    W = np.eye(4, dtype=np.float32)  # Identity
    X = np.array([[2, 3, 0, -1]] * 4, dtype=np.float32)
    B = np.zeros((4, 4), dtype=np.float32)

    if args.test or (not args.hex and not args.send):
        print("=== Golden Model Test ===")
        print(f"W =\n{W}")
        print(f"X =\n{X}")
        print(f"B =\n{B}")

        expected = golden_fc(W, X, B)
        print(f"\ny = ReLU(W @ X + B) =\n{expected}")

        # Verify BF16 round-trip
        print("\nBF16 encoding:")
        for name, val in [("2.0", 2.0), ("3.0", 3.0), ("0.0", 0.0), ("-1.0", -1.0), ("1.0", 1.0)]:
            h = float_to_bf16(val)
            back = bf16_to_float(h)
            print(f"  {name}: {bf16_hex(val)} -> {back}")

        # Build and verify packet
        packet = build_packet(W, X, B)
        print(f"\nPacket: {len(packet)} DWs ({len(packet)*8} bytes payload)")

        # Simulate expected TX output
        expected_tx = []
        for bank in range(4):
            row = expected[bank]
            bf = [float_to_bf16(row[j]) for j in range(4)]
            cpu_lo = (bf[1] << 16) | bf[0]
            cpu_hi = (bf[3] << 16) | bf[2]
            expected_tx.append(pack_dw(cpu_hi, cpu_lo))

        print("\nExpected TX DWs:")
        for i, dw in enumerate(expected_tx):
            print(f"  TX[{i}]: 0x{dw:016X}")

        # Parse back to verify round-trip
        parsed = parse_tx_output(expected_tx)
        print(f"\nParsed result:\n{parsed}")
        match = np.allclose(expected, parsed, atol=1e-2)
        print(f"Golden match: {'PASS' if match else 'FAIL'}")

    if args.hex:
        print("\n=== Packet Hex Dump ===")
        packet = build_packet(W, X, B)
        for i, dw in enumerate(packet):
            print(f"  [{i:3d}] 0x{dw:016X}")

    if args.send:
        print(f"\n=== Sending on {args.iface} ===")
        packet = build_packet(W, X, B)
        tx_dws = send_and_receive(packet, iface=args.iface)
        if tx_dws:
            print("\nTX Response:")
            for i, dw in enumerate(tx_dws):
                print(f"  TX[{i}]: 0x{dw:016X}")
            result = parse_tx_output(tx_dws)
            print(f"\nResult:\n{result}")
            expected = golden_fc(W, X, B)
            match = np.allclose(expected, result, atol=1e-2)
            print(f"Match: {'PASS' if match else 'FAIL'}")

if __name__ == '__main__':
    main()
