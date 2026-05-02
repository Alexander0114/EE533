; ===================================================================
; CPU Control Program for Network Processor (Lab 8)
; Target: ARM_Processor_4T (4-thread barrel, 5-stage pipeline)
; ===================================================================
;
; Register allocation:
;   R0 = 0       (zero register, BRAM init)
;   R1 = 0x1000  (ctrl register base address)
;   R2 = scratch  (ctrl values / loaded data)
;   R3 = scratch  (bit test results)
;
; Control register (0x1000) bit map:
;   Bit 0:  packet_ready  (R)     - FIFO has a complete packet
;   Bit 1:  mode_select   (RW)    - 0=network, 1=processor
;   Bit 2:  send_packet   (W)     - pulse to trigger output FSM
;   Bit 3:  gpu_run       (RW)    - start/stop GPU
;   Bit 4:  gpu_rst       (RW)    - GPU reset
;   Bit 5:  gpu_halted    (R)     - GPU has halted
;   [13:6]: head_ptr      (R)
;   [21:14]:tail_ptr      (R)
;
; Instruction format: [31:28 OP] [27:24 ALUC] [23:20 Rs1] [19:16 Rs2] [15:12 Rd] [11:0 Imm12]
; OP: 1001=ALU_imm, 0010=LW, 0011=SW, 0100=Branch, 1000=CMP
; ALUC: 0000=ADD, 0010=AND, 0100=XOR, 0110=LSL
; BType (in Rs2[3:2]): 01=always, 10=GE, 11=LE
; Branch target: byte address (word_addr * 4), loaded into PC[8:2]
;
; ===================================================================

; --- Initialization ---
; Build ctrl register base address 0x1000 in R1

; Addr 0: ADDI R1, R0, 1
;   R1 = 0 + 1 = 1
;   Encoding: 9000_1001
    ADDI R1, R0, #1             ; 90001001

; Addr 1: LSLI R1, R1, 12
;   R1 = 1 << 12 = 0x1000
;   Encoding: 9610_100C
    LSLI R1, R1, #12            ; 9610100C

; --- POLL: Wait for packet_ready ---

; Addr 2: LW R2, [R1, #0]
;   R2 = Mem[0x1000] = ctrl register value
;   Encoding: 2010_2000
POLL:
    LW   R2, [R1, #0]           ; 20102000

; Addr 3: ANDI R3, R2, 1
;   R3 = R2 & 1 = packet_ready bit
;   Z=1 if no packet, Z=0 if packet ready
;   Encoding: 9220_3001
    ANDI R3, R2, #1              ; 92203001

; Addr 4: BLE POLL (byte addr 2*4=8)
;   If Z=1 (no packet), branch back to POLL
;   Encoding: 400C_0008
    BLE  #8                      ; 400C0008

; --- Set mode_select = 1 (switch FIFO to processor mode) ---

; Addr 5: ADDI R2, R0, 2
;   R2 = 0x02 = 0b00000010 (mode_select=1)
;   Encoding: 9000_2002
    ADDI R2, R0, #2              ; 90002002

; Addr 6: SW R2, [R1, #0]
;   ctrl_reg = 0x02
;   Encoding: 3012_0000
    SW   R2, [R1, #0]            ; 30120000

; --- Start GPU (gpu_run=1, mode_select=1) ---

; Addr 7: ADDI R2, R0, 10
;   R2 = 0x0A = 0b00001010 (gpu_run=1, mode_select=1)
;   Encoding: 9000_200A
    ADDI R2, R0, #10             ; 9000200A

; Addr 8: SW R2, [R1, #0]
;   ctrl_reg = 0x0A
;   Encoding: 3012_0000
    SW   R2, [R1, #0]            ; 30120000

; --- GPU_WAIT: Poll for gpu_halted ---

; Addr 9: LW R2, [R1, #0]
;   R2 = ctrl register value
;   Encoding: 2010_2000
GPU_WAIT:
    LW   R2, [R1, #0]           ; 20102000

; Addr 10: ANDI R3, R2, 32
;   R3 = R2 & 0x20 = gpu_halted bit (bit 5)
;   Z=1 if GPU still running, Z=0 if halted
;   Encoding: 9220_3020
    ANDI R3, R2, #32             ; 92203020

; Addr 11: BLE GPU_WAIT (byte addr 9*4=36)
;   If Z=1 (GPU not halted), keep polling
;   Encoding: 400C_0024
    BLE  #36                     ; 400C0024

; --- Stop GPU, keep mode_select ---

; Addr 12: ADDI R2, R0, 2
;   R2 = 0x02 (gpu_run=0, mode_select=1)
;   Encoding: 9000_2002
    ADDI R2, R0, #2              ; 90002002

; Addr 13: SW R2, [R1, #0]
;   Encoding: 3012_0000
    SW   R2, [R1, #0]            ; 30120000

; --- Trigger send_packet ---

; Addr 14: ADDI R2, R0, 6
;   R2 = 0x06 = 0b00000110 (send_packet=1, mode_select=1)
;   Encoding: 9000_2006
    ADDI R2, R0, #6              ; 90002006

; Addr 15: SW R2, [R1, #0]
;   send_packet pulse triggers output FSM
;   Encoding: 3012_0000
    SW   R2, [R1, #0]            ; 30120000

; --- WAIT_SEND: Wait for output FSM to finish ---
; packet_ready (packet_in_fifo) clears when send_done fires.
; We must wait before clearing mode_select, otherwise the CPU
; might see stale packet_ready=1 and re-process the same packet.

; Addr 16: LW R2, [R1, #0]
;   R2 = ctrl register value
;   Encoding: 2010_2000
WAIT_SEND:
    LW   R2, [R1, #0]           ; 20102000

; Addr 17: ANDI R3, R2, 1
;   R3 = packet_ready bit
;   Encoding: 9220_3001
    ANDI R3, R2, #1              ; 92203001

; Addr 18: XORI R3, R3, 1
;   Invert: R3=0 (Z=1) if packet_ready still set, R3=1 (Z=0) if cleared
;   Encoding: 9430_3001
    XORI R3, R3, #1              ; 94303001

; Addr 19: BLE WAIT_SEND (byte addr 16*4=64)
;   If Z=1 (packet_ready still set), keep waiting
;   Encoding: 400C_0040
    BLE  #64                     ; 400C0040

; --- Clear mode_select, return FIFO to network mode ---

; Addr 20: ADDI R2, R0, 0
;   R2 = 0x00 (all control bits cleared)
;   Encoding: 9000_2000
    ADDI R2, R0, #0              ; 90002000

; Addr 21: SW R2, [R1, #0]
;   Encoding: 3012_0000
    SW   R2, [R1, #0]            ; 30120000

; --- Loop back to wait for next packet ---

; Addr 22: B POLL (byte addr 2*4=8)
;   Unconditional branch (BType=01)
;   Encoding: 4004_0008
    B    #8                      ; 40040008
