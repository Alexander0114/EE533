/*
 * netproc_test.c
 * Lab 8: Network Processor Test Program
 *
 * Loads CPU and GPU programs via register interface,
 * releases reset, and monitors execution status.
 *
 * Build:
 *   gcc -o netproc_test netproc_test.c \
 *       -I../../lib/C/ -I../lib/C/ \
 *       ../../lib/C/common/nf2util.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <net/if.h>
#include <time.h>

#include "common/nf2util.h"

/* ============================================================
 *  Register Addresses (from reg_defines_lab8.pm)
 * ============================================================ */
#define GPU_BASE_ADDR           0x2000100

/* Software registers (host -> FPGA) */
#define GPU_CPU_IMEM_ADDR_REG   0x2000100
#define GPU_CPU_IMEM_DATA_REG   0x2000104
#define GPU_GPU_IMEM_ADDR_REG   0x2000108
#define GPU_GPU_IMEM_DATA_REG   0x200010c
#define GPU_SYS_CTRL_REG        0x2000110

/* Hardware registers (FPGA -> host, read-only) */
#define GPU_GPU_PC_REG          0x2000114
#define GPU_CYCLE_COUNTS_REG    0x2000118
#define GPU_GPU_STATUS_REG      0x200011c
#define GPU_CPU_PC_REG          0x2000120
#define GPU_FIFO_STATUS_REG     0x2000124
#define GPU_CPU_CTRL_REG        0x2000128

/* sys_ctrl bits */
#define SYS_CTRL_CPU_IMEM_WE   (1 << 0)
#define SYS_CTRL_GPU_IMEM_WE   (1 << 1)
#define SYS_CTRL_SYS_RESET     (1 << 2)

/* gpu_status bits */
#define GPU_STATUS_HALTED       (1 << 4)

#define DEFAULT_IFACE  "nf2c0"

static struct nf2device nf2;

/* ============================================================
 *  Helper: write one CPU instruction
 * ============================================================ */
void load_cpu_instr(unsigned addr, unsigned data)
{
	writeReg(&nf2, GPU_CPU_IMEM_ADDR_REG, addr);
	writeReg(&nf2, GPU_CPU_IMEM_DATA_REG, data);
	writeReg(&nf2, GPU_SYS_CTRL_REG, SYS_CTRL_SYS_RESET | SYS_CTRL_CPU_IMEM_WE);
	writeReg(&nf2, GPU_SYS_CTRL_REG, SYS_CTRL_SYS_RESET); /* deassert WE */
}

/* ============================================================
 *  Helper: write one GPU instruction
 * ============================================================ */
void load_gpu_instr(unsigned addr, unsigned data)
{
	writeReg(&nf2, GPU_GPU_IMEM_ADDR_REG, addr);
	writeReg(&nf2, GPU_GPU_IMEM_DATA_REG, data);
	writeReg(&nf2, GPU_SYS_CTRL_REG, SYS_CTRL_SYS_RESET | SYS_CTRL_GPU_IMEM_WE);
	writeReg(&nf2, GPU_SYS_CTRL_REG, SYS_CTRL_SYS_RESET); /* deassert WE */
}

/* ============================================================
 *  CPU Program (23 instructions)
 *
 *  Flow:
 *    1. Build ctrl reg address 0x1000 in R1
 *    2. POLL: wait for packet_ready (ctrl bit 0)
 *    3. Set mode_select=1 (bit 1) via ctrl reg
 *    4. Set mode_select=1, gpu_run=1 (bits 1,3) via ctrl reg
 *    5. GPU_WAIT: poll for gpu_halted (ctrl bit 5)
 *    6. Clear gpu_run, keep mode_select
 *    7. Set send_packet (bit 2) + mode_select
 *    8. WAIT_SEND: wait for packet_ready=0 (send done)
 *    9. Clear ctrl reg, loop back to POLL
 * ============================================================ */
static unsigned cpu_program[] = {
	/* ctrl bits: 0=packet_ready(r), 1=mode_select, 2=send_packet, 3=gpu_run, 4=gpu_rst */
	0x90001001,  /* 0:  ADDI R1, R0, 1           */
	0x9610100C,  /* 1:  LSLI R1, R1, 12          -> R1 = 0x1000 */
	0x20102000,  /* 2:  LW   R2, [R1, 0]         POLL */
	0x92203001,  /* 3:  ANDI R3, R2, 1            check packet_ready */
	0x400C0008,  /* 4:  BLE  POLL (2*4=8)         */
	0x90002012,  /* 5:  ADDI R2, R0, 18           mode_select=1, gpu_rst=1 */
	0x30120000,  /* 6:  SW   R2, [R1, 0]          (reset GPU) */
	0x90002002,  /* 7:  ADDI R2, R0, 2            mode_select=1 (release gpu_rst) */
	0x30120000,  /* 8:  SW   R2, [R1, 0]          */
	0x9000200A,  /* 9:  ADDI R2, R0, 10           mode_select=1, gpu_run=1 */
	0x30120000,  /* 10: SW   R2, [R1, 0]          */
	0x20102000,  /* 11: LW   R2, [R1, 0]         GPU_WAIT */
	0x92203020,  /* 12: ANDI R3, R2, 32           check gpu_halted */
	0x400C002C,  /* 13: BLE  GPU_WAIT (11*4=44)   */
	0x90002002,  /* 14: ADDI R2, R0, 2            mode_select=1 */
	0x30120000,  /* 15: SW   R2, [R1, 0]          */
	0x90002006,  /* 16: ADDI R2, R0, 6            mode_select=1, send_packet=1 */
	0x30120000,  /* 17: SW   R2, [R1, 0]          */
	0x20102000,  /* 18: LW   R2, [R1, 0]         WAIT_SEND */
	0x92203001,  /* 19: ANDI R3, R2, 1            check packet_ready */
	0x94303001,  /* 20: XORI R3, R3, 1            invert */
	0x400C0048,  /* 21: BLE  WAIT_SEND (18*4=72)  */
	0x90002000,  /* 22: ADDI R2, R0, 0            clear ctrl */
	0x30120000,  /* 23: SW   R2, [R1, 0]          */
	0x40040008,  /* 24: B    POLL (2*4=8)         */
};
#define CPU_PROG_LEN (sizeof(cpu_program) / sizeof(cpu_program[0]))

/* ============================================================
 *  GPU Program (12 instructions)
 *
 *  Flow:
 *    1. MOVI R0, 0 (base address)
 *    2. ADDI R1, R0, 1 (increment value = 0x0001)
 *    3. VBCAST R1, R1, lane 3 (broadcast to all 4 int16 lanes)
 *    4. Loop over FIFO words 1..5: load, VADD +1, store
 *    5. HALT
 * ============================================================ */
static unsigned gpu_program[] = {
	0x60000000,  /* 0:  MOVI  R0, 0               */
	0x48400001,  /* 1:  ADDI  R1, R0, 1            */
	0x70420003,  /* 2:  VBCAST R1, R1, lane 3      */
	/* Word 1 */
	0x60800001,  /* 3:  MOVI  R2, 1                */
	0x11040000,  /* 4:  LD    R4, [R2, 0]          */
	0x01081000,  /* 5:  VADD  R4, R4, R1           */
	0x19040000,  /* 6:  ST    R4, [R2, 0]          */
	/* Word 2 */
	0x60800002,  /* 7:  MOVI  R2, 2                */
	0x11040000,  /* 8:  LD    R4, [R2, 0]          */
	0x01081000,  /* 9:  VADD  R4, R4, R1           */
	0x19040000,  /* 10: ST    R4, [R2, 0]          */
	/* Word 3 */
	0x60800003,  /* 11: MOVI  R2, 3                */
	0x11040000,  /* 12: LD    R4, [R2, 0]          */
	0x01081000,  /* 13: VADD  R4, R4, R1           */
	0x19040000,  /* 14: ST    R4, [R2, 0]          */
	/* Word 4 */
	0x60800004,  /* 15: MOVI  R2, 4                */
	0x11040000,  /* 16: LD    R4, [R2, 0]          */
	0x01081000,  /* 17: VADD  R4, R4, R1           */
	0x19040000,  /* 18: ST    R4, [R2, 0]          */
	/* Word 5 */
	0x60800005,  /* 19: MOVI  R2, 5                */
	0x11040000,  /* 20: LD    R4, [R2, 0]          */
	0x01081000,  /* 21: VADD  R4, R4, R1           */
	0x19040000,  /* 22: ST    R4, [R2, 0]          */
	/* Done */
	0x50000000,  /* 23: HALT                       */
};
#define GPU_PROG_LEN (sizeof(gpu_program) / sizeof(gpu_program[0]))

/* ============================================================
 *  Main
 * ============================================================ */
int main(int argc, char *argv[])
{
	unsigned val;
	int i, timeout;

	nf2.device_name = DEFAULT_IFACE;

	if (check_iface(&nf2)) {
		exit(1);
	}
	if (openDescriptor(&nf2)) {
		exit(1);
	}

	printf("=== Lab 8 Network Processor Test ===\n\n");

	/* Step 1: Assert system reset */
	printf("Asserting system reset...\n");
	writeReg(&nf2, GPU_SYS_CTRL_REG, SYS_CTRL_SYS_RESET);

	/* Step 2: Load CPU program */
	printf("Loading CPU program (%d instructions)...\n", CPU_PROG_LEN);
	for (i = 0; i < CPU_PROG_LEN; i++) {
		load_cpu_instr(i, cpu_program[i]);
	}

	/* Step 3: Load GPU program */
	printf("Loading GPU program (%d instructions)...\n", GPU_PROG_LEN);
	for (i = 0; i < GPU_PROG_LEN; i++) {
		load_gpu_instr(i, gpu_program[i]);
	}

	/* Step 4: Release reset (clear sys_ctrl) */
	printf("Releasing reset...\n");
	writeReg(&nf2, GPU_SYS_CTRL_REG, 0);

	/* Step 5: Monitor status */
	printf("\nMonitoring status (press Ctrl-C to stop)...\n\n");

	for (timeout = 0; timeout < 100; timeout++) {
		usleep(100000); /* 100 ms */

		readReg(&nf2, GPU_GPU_PC_REG, &val);
		printf("  GPU PC: %3u", val);

		readReg(&nf2, GPU_GPU_STATUS_REG, &val);
		printf("  Status: 0x%02x (halted=%d, state=%d)",
			val, (val >> 4) & 1, val & 0xf);

		readReg(&nf2, GPU_CYCLE_COUNTS_REG, &val);
		printf("  Cycles: %u\n", val);

		/* Check if GPU has halted */
		readReg(&nf2, GPU_GPU_STATUS_REG, &val);
		if (val & GPU_STATUS_HALTED) {
			printf("\nGPU halted after %d polls.\n", timeout + 1);
			break;
		}
	}

	if (timeout >= 100) {
		printf("\nTimeout: GPU did not halt within 10 seconds.\n");
	}

	/* Final register dump */
	printf("\n=== Final Register State ===\n");
	readReg(&nf2, GPU_SYS_CTRL_REG, &val);
	printf("  SYS_CTRL:     0x%08x\n", val);
	readReg(&nf2, GPU_GPU_PC_REG, &val);
	printf("  GPU_PC:       %u\n", val);
	readReg(&nf2, GPU_CYCLE_COUNTS_REG, &val);
	printf("  CYCLE_COUNTS: %u\n", val);
	readReg(&nf2, GPU_GPU_STATUS_REG, &val);
	printf("  GPU_STATUS:   0x%08x (halted=%d, state=%d)\n",
		val, (val >> 4) & 1, val & 0xf);

	closeDescriptor(&nf2);
	return 0;
}
