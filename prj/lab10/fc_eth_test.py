#!/usr/bin/env python
"""
FC layer inference via Ethernet path on NetFPGA.
Compatible with Python 2.4+.

Usage: sudo python fc_eth_test.py [interface] [fc44|fc81]
"""

import struct
import sys
import os
import time

# ===============================================================
#  Register I/O
# ===============================================================
BASE = 0x2000200
SW_CMD = BASE + 0x0C
HW_ST  = BASE + 0x10
HW_W0H = BASE + 0x14
HW_W0L = BASE + 0x18
HW_W1H = BASE + 0x1C
HW_W1L = BASE + 0x20

def regwrite(addr, val):
    os.system("regwrite 0x%08x 0x%08x > /dev/null 2>&1" % (addr, val & 0xFFFFFFFF))

def regread(addr):
    import re
    f = os.popen("regread 0x%08x 2>/dev/null" % addr)
    output = f.read()
    f.close()
    # Match ":<space>0x<hex>" pattern (value comes after colon)
    m = re.search(r':\s+(0x[0-9a-fA-F]+)', output)
    if m:
        return int(m.group(1), 16)
    return 0

# ===============================================================
#  BF16
# ===============================================================
def bf16(f):
    b = struct.pack('>f', f)
    return struct.unpack('>H', b[:2])[0]

def bf16f(h):
    b = struct.pack('>H', h) + '\x00\x00'
    return struct.unpack('>f', b)[0]

# ===============================================================
#  ARM helpers
# ===============================================================
NOP  = 0xE1A00000
HALT = 0xEAFFFFFE

def arm_mov(rd, imm8):
    return 0xE3A00000 | (rd << 12) | (imm8 & 0xFF)

def arm_mcr(crn, rd):
    return 0xEE000A10 | (crn << 16) | (rd << 12)

def cmd_word(opcode, addr, count, param=0):
    return ((opcode & 0xF) << 60) | ((addr & 0xFFF) << 48) | \
           ((count & 0xFFFF) << 32) | (param & 0xFFFFFFFF)

def pack_dw(hi32, lo32):
    return ((hi32 & 0xFFFFFFFF) << 32) | (lo32 & 0xFFFFFFFF)

def pack_row(vals):
    b = [bf16(v) for v in vals]
    return [(b[1] << 16) | b[0], (b[3] << 16) | b[2]]

# ===============================================================
#  ARM firmware with proper DMA waits
# ===============================================================
def build_arm(dunpack, dpack_dst, gnop, du_wait):
    prog = []
    # D_IMEM (src=0, dst=0, len=16)
    prog += [arm_mov(0,0), arm_mcr(0,0)]
    prog += [arm_mcr(1,0), arm_mov(1,16)]
    prog += [arm_mcr(2,1), arm_mov(2,5)]
    prog += [arm_mcr(3,2), NOP]
    # D_UNPACK (src=16, dst=0, burst_all)
    prog += [arm_mov(0,16), arm_mcr(0,0)]
    prog += [arm_mov(1,0), arm_mcr(1,1)]
    prog += [arm_mov(2,dunpack), arm_mcr(2,2)]
    prog += [arm_mov(3,0x41), arm_mcr(3,3)]
    # Wait for D_UNPACK
    prog += [NOP] * (du_wait * 2)
    # GPU launch
    prog += [arm_mov(0,0), arm_mcr(4,0)]
    prog += [arm_mov(1,0x0F), arm_mcr(7,1)]
    prog += [arm_mov(2,1), arm_mcr(5,2)]
    # Wait for GPU
    prog += [NOP] * (gnop * 2)
    # D_PACK (src=0, dst=dpack_dst, xfer=2, burst_all)
    prog += [arm_mov(0,0), arm_mcr(0,0)]
    prog += [arm_mov(1,dpack_dst), arm_mcr(1,1)]
    prog += [arm_mov(2,2), arm_mcr(2,2)]
    prog += [arm_mov(3,0x43), arm_mcr(3,3)]
    # D_PACK wait + halt
    prog += [NOP] * 10
    prog += [HALT, NOP]
    if len(prog) % 2 != 0:
        prog.append(NOP)
    return prog

# ===============================================================
#  GPU kernels
# ===============================================================
GPU_FC44 = [
    0x20000000, 0xF0400004, 0xF0800008, 0xF0000000,
    0xECC04800, 0x20000000, 0x54CC0000, 0x54DD0000,
    0x54EE0000, 0x54FF0000, 0x20000000, 0xF8C00000,
    0xC8000000, 0, 0, 0,
]

GPU_FC81 = [
    0x20F00000, 0xF00F0000, 0xF04F0004, 0xF08F0010,
    0xECC04800, 0xF00F0008, 0xF04F000C, 0xECC04C00,
    0x20000000, 0x54CC0000, 0xF8C00000, 0xC8000000,
    0, 0, 0, 0,
]

# ===============================================================
#  Test data
# ===============================================================
def fc44_data():
    W = [[2,1,0,0],[0,2,1,0],[0,0,2,1],[1,0,0,2]]
    X = [[1,1,1,1]]*4
    B = [[-3,-3,-3,-3],[0.5,0.5,0.5,0.5],[-5,-5,-5,-5],[1,1,1,1]]
    words = []
    for bank in range(4):
        words += pack_row(W[bank])
        words += pack_row(X[bank])
        words += pack_row(B[bank])
    return words

def fc81_data():
    w = [2,3,-1,0.5, 1,-2,0.5,3]
    x = [1,2,3,4, 1,2,3,4]
    bias = -8.0
    words = []
    for bank in range(4):
        for tile in range(2):
            if bank == 0:
                wr = [bf16(w[tile*4+k]) for k in range(4)]
            else:
                wr = [0,0,0,0]
            words.append((wr[1] << 16) | wr[0])
            words.append((wr[3] << 16) | wr[2])
            xv = bf16(x[tile*4+bank])
            words.append((xv << 16) | xv)
            words.append((xv << 16) | xv)
        if bank == 0:
            bv = bf16(bias)
            words.append((bv << 16) | bv)
            words.append((bv << 16) | bv)
        else:
            words.append(0)
            words.append(0)
    return words

# ===============================================================
#  Build Ethernet frame
# ===============================================================
def build_frame(arm_prog, gpu_kernel, data_words, rb_addr):
    payload = []

    # LOAD_IMEM: ARM firmware
    ndw = len(arm_prog) // 2
    payload.append(cmd_word(0x1, 0, ndw))
    for i in range(0, len(arm_prog), 2):
        payload.append(pack_dw(arm_prog[i+1], arm_prog[i]))

    # LOAD_DMEM addr=0: GPU kernel
    ndw = len(gpu_kernel) // 2
    payload.append(cmd_word(0x2, 0, ndw))
    for i in range(0, len(gpu_kernel), 2):
        payload.append(pack_dw(gpu_kernel[i+1], gpu_kernel[i]))

    # LOAD_DMEM addr=16: data
    ndw = len(data_words) // 2
    payload.append(cmd_word(0x2, 16, ndw))
    for i in range(0, len(data_words), 2):
        payload.append(pack_dw(data_words[i+1], data_words[i]))

    # Zero readback area
    payload.append(cmd_word(0x2, rb_addr, 4))
    for _ in range(4):
        payload.append(0)

    # Commands
    payload.append(cmd_word(0x3, 0, 0))
    payload.append(cmd_word(0x4, rb_addr, 4))
    payload.append(cmd_word(0x5, 0, 0))

    # Ethernet frame
    dst_mac = '\xff\xff\xff\xff\xff\xff'
    src_mac = '\x00\x00\x00\x00\x00\x01'
    frame = dst_mac + src_mac + struct.pack('>H', 0x88B5)
    for dw in payload:
        frame += struct.pack('>Q', dw)
    if len(frame) < 64:
        frame += '\x00' * (64 - len(frame))

    return frame, len(payload)

# ===============================================================
#  Write pcap file (for tcpreplay)
# ===============================================================
def write_pcap(filename, frame):
    """Write a single-packet pcap file."""
    f = open(filename, 'wb')
    # pcap global header
    f.write(struct.pack('<IHHiIII',
        0xa1b2c3d4,  # magic
        2, 4,         # version
        0,            # timezone
        0,            # sigfigs
        65535,        # snaplen
        1))           # linktype (Ethernet)
    # packet header
    ts = int(time.time())
    f.write(struct.pack('<IIII', ts, 0, len(frame), len(frame)))
    # packet data
    f.write(frame)
    f.close()

# ===============================================================
#  Main
# ===============================================================
if __name__ == '__main__':
    iface = 'nf2c0'
    test = 'fc44'
    if len(sys.argv) > 1:
        iface = sys.argv[1]
    if len(sys.argv) > 2:
        test = sys.argv[2]

    print "=== FC Ethernet Test (%s) on %s ===" % (test, iface)
    print ""

    # Network mode
    regwrite(SW_CMD, 0x04)
    time.sleep(0.01)
    regwrite(SW_CMD, 0x00)
    time.sleep(0.01)

    if test == 'fc44':
        arm = build_arm(dunpack=6, dpack_dst=48, gnop=15, du_wait=15)
        gpu = GPU_FC44
        data = fc44_data()
        rb_addr = 48
        print "FC(4x4): W*X+B, Y=[0, 3.5, 0, 4.0]"
    elif test == 'fc81':
        arm = build_arm(dunpack=10, dpack_dst=100, gnop=20, du_wait=20)
        gpu = GPU_FC81
        data = fc81_data()
        rb_addr = 100
        print "FC(8->1): 2 WMMA tiles, dot=17.5, b=-8, y=9.5"
    else:
        print "Unknown test: %s" % test
        sys.exit(1)

    frame, ndws = build_frame(arm, gpu, data, rb_addr)

    print "ARM: %d instructions" % len(arm)
    print "Payload: %d DWs (%d bytes)" % (ndws, ndws * 8)
    print "Frame: %d bytes" % len(frame)
    print ""

    # Write pcap file
    pcap_file = '/tmp/fc_test.pcap'
    write_pcap(pcap_file, frame)
    print "Wrote %s (%d bytes)" % (pcap_file, len(frame))

    # Send via tcpreplay (allowed by sudo)
    print ""
    print "Sending via tcpreplay..."
    os.system("sudo tcpreplay -i %s %s" % (iface, pcap_file))
    time.sleep(0.5)

    # Poll hw_status for tx_done
    print "Polling..."
    st = 0
    for i in range(200):
        time.sleep(0.05)
        st = regread(HW_ST)
        if (st >> 2) & 1:
            print "  tx_done at poll %d, status=0x%08X" % (i + 1, st)
            break
    else:
        print "  TIMEOUT, status=0x%08X" % st

    # Read TX snoop
    w0h = regread(HW_W0H)
    w0l = regread(HW_W0L)
    w1h = regread(HW_W1H)
    w1l = regread(HW_W1L)

    print ""
    print "TX[0] = %08X_%08X" % (w0h, w0l)
    print "TX[1] = %08X_%08X" % (w1h, w1l)

    twc = (st >> 16) & 0x3F
    print "tx_word_cnt = %d" % twc
    print ""
    print "Note: For network path, TX snoop captures Ethernet headers."
    print "READBACK data is in TX words 3+ (beyond 2-word snoop)."
    print "tx_done=1 confirms SoC processed the packet."
    print ""
    print "To capture response packet, run in another terminal:"
    print "  sudo tcpdump -i %s -XX -c 1 ether proto 0x88b5" % iface
