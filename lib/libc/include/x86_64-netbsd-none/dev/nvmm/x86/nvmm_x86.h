/*	$NetBSD: nvmm_x86.h,v 1.21 2021/03/26 15:59:53 reinoud Exp $	*/

/*
 * Copyright (c) 2018-2020 Maxime Villard, m00nbsd.net
 * All rights reserved.
 *
 * This code is part of the NVMM hypervisor.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NVMM_X86_H_
#define _NVMM_X86_H_

/* -------------------------------------------------------------------------- */

#ifndef ASM_NVMM

struct nvmm_x86_exit_memory {
	int prot;
	gpaddr_t gpa;
	uint8_t inst_len;
	uint8_t inst_bytes[15];
};

struct nvmm_x86_exit_io {
	bool in;
	uint16_t port;
	int8_t seg;
	uint8_t address_size;
	uint8_t operand_size;
	bool rep;
	bool str;
	uint64_t npc;
};

struct nvmm_x86_exit_rdmsr {
	uint32_t msr;
	uint64_t npc;
};

struct nvmm_x86_exit_wrmsr {
	uint32_t msr;
	uint64_t val;
	uint64_t npc;
};

struct nvmm_x86_exit_insn {
	uint64_t npc;
};

struct nvmm_x86_exit_invalid {
	uint64_t hwcode;
};

/* Generic. */
#define NVMM_VCPU_EXIT_NONE		0x0000000000000000ULL
#define NVMM_VCPU_EXIT_STOPPED		0xFFFFFFFFFFFFFFFEULL
#define NVMM_VCPU_EXIT_INVALID		0xFFFFFFFFFFFFFFFFULL
/* x86: operations. */
#define NVMM_VCPU_EXIT_MEMORY		0x0000000000000001ULL
#define NVMM_VCPU_EXIT_IO		0x0000000000000002ULL
/* x86: changes in VCPU state. */
#define NVMM_VCPU_EXIT_SHUTDOWN		0x0000000000001000ULL
#define NVMM_VCPU_EXIT_INT_READY	0x0000000000001001ULL
#define NVMM_VCPU_EXIT_NMI_READY	0x0000000000001002ULL
#define NVMM_VCPU_EXIT_HALTED		0x0000000000001003ULL
#define NVMM_VCPU_EXIT_TPR_CHANGED	0x0000000000001004ULL
/* x86: instructions. */
#define NVMM_VCPU_EXIT_RDMSR		0x0000000000002000ULL
#define NVMM_VCPU_EXIT_WRMSR		0x0000000000002001ULL
#define NVMM_VCPU_EXIT_MONITOR		0x0000000000002002ULL
#define NVMM_VCPU_EXIT_MWAIT		0x0000000000002003ULL
#define NVMM_VCPU_EXIT_CPUID		0x0000000000002004ULL

struct nvmm_x86_exit {
	uint64_t reason;
	union {
		struct nvmm_x86_exit_memory mem;
		struct nvmm_x86_exit_io io;
		struct nvmm_x86_exit_rdmsr rdmsr;
		struct nvmm_x86_exit_wrmsr wrmsr;
		struct nvmm_x86_exit_insn insn;
		struct nvmm_x86_exit_invalid inv;
	} u;
	struct {
		uint64_t rflags;
		uint64_t cr8;
		uint64_t int_shadow:1;
		uint64_t int_window_exiting:1;
		uint64_t nmi_window_exiting:1;
		uint64_t evt_pending:1;
		uint64_t rsvd:60;
	} exitstate;
};

#define NVMM_VCPU_EVENT_EXCP	0
#define NVMM_VCPU_EVENT_INTR	1

struct nvmm_x86_event {
	u_int type;
	uint8_t vector;
	union {
		struct {
			uint64_t error;
		} excp;
	} u;
};

struct nvmm_cap_md {
	uint64_t mach_conf_support;

	uint64_t vcpu_conf_support;
#define NVMM_CAP_ARCH_VCPU_CONF_CPUID	__BIT(0)
#define NVMM_CAP_ARCH_VCPU_CONF_TPR	__BIT(1)

	uint64_t xcr0_mask;
	uint32_t mxcsr_mask;
	uint32_t conf_cpuid_maxops;
	uint64_t rsvd[6];
};

#endif

/* -------------------------------------------------------------------------- */

/*
 * Segment state indexes. We use X64 as naming convention, not to confuse with
 * X86 which originally implied 32bit.
 */

/* Segments. */
#define NVMM_X64_SEG_ES			0
#define NVMM_X64_SEG_CS			1
#define NVMM_X64_SEG_SS			2
#define NVMM_X64_SEG_DS			3
#define NVMM_X64_SEG_FS			4
#define NVMM_X64_SEG_GS			5
#define NVMM_X64_SEG_GDT		6
#define NVMM_X64_SEG_IDT		7
#define NVMM_X64_SEG_LDT		8
#define NVMM_X64_SEG_TR			9
#define NVMM_X64_NSEG			10

/* General Purpose Registers. */
#define NVMM_X64_GPR_RAX		0
#define NVMM_X64_GPR_RCX		1
#define NVMM_X64_GPR_RDX		2
#define NVMM_X64_GPR_RBX		3
#define NVMM_X64_GPR_RSP		4
#define NVMM_X64_GPR_RBP		5
#define NVMM_X64_GPR_RSI		6
#define NVMM_X64_GPR_RDI		7
#define NVMM_X64_GPR_R8			8
#define NVMM_X64_GPR_R9			9
#define NVMM_X64_GPR_R10		10
#define NVMM_X64_GPR_R11		11
#define NVMM_X64_GPR_R12		12
#define NVMM_X64_GPR_R13		13
#define NVMM_X64_GPR_R14		14
#define NVMM_X64_GPR_R15		15
#define NVMM_X64_GPR_RIP		16
#define NVMM_X64_GPR_RFLAGS		17
#define NVMM_X64_NGPR			18

/* Control Registers. */
#define NVMM_X64_CR_CR0			0
#define NVMM_X64_CR_CR2			1
#define NVMM_X64_CR_CR3			2
#define NVMM_X64_CR_CR4			3
#define NVMM_X64_CR_CR8			4
#define NVMM_X64_CR_XCR0		5
#define NVMM_X64_NCR			6

/* Debug Registers. */
#define NVMM_X64_DR_DR0			0
#define NVMM_X64_DR_DR1			1
#define NVMM_X64_DR_DR2			2
#define NVMM_X64_DR_DR3			3
#define NVMM_X64_DR_DR6			4
#define NVMM_X64_DR_DR7			5
#define NVMM_X64_NDR			6

/* MSRs. */
#define NVMM_X64_MSR_EFER		0
#define NVMM_X64_MSR_STAR		1
#define NVMM_X64_MSR_LSTAR		2
#define NVMM_X64_MSR_CSTAR		3
#define NVMM_X64_MSR_SFMASK		4
#define NVMM_X64_MSR_KERNELGSBASE	5
#define NVMM_X64_MSR_SYSENTER_CS	6
#define NVMM_X64_MSR_SYSENTER_ESP	7
#define NVMM_X64_MSR_SYSENTER_EIP	8
#define NVMM_X64_MSR_PAT		9
#define NVMM_X64_MSR_TSC		10
#define NVMM_X64_NMSR			11

#ifndef ASM_NVMM

#include <sys/types.h>
#include <x86/cpu_extended_state.h>

struct nvmm_x64_state_seg {
	uint16_t selector;
	struct {		/* hidden */
		uint16_t type:4;
		uint16_t s:1;
		uint16_t dpl:2;
		uint16_t p:1;
		uint16_t avl:1;
		uint16_t l:1;
		uint16_t def:1;
		uint16_t g:1;
		uint16_t rsvd:4;
	} attrib;
	uint32_t limit;		/* hidden */
	uint64_t base;		/* hidden */
};

struct nvmm_x64_state_intr {
	uint64_t int_shadow:1;
	uint64_t int_window_exiting:1;
	uint64_t nmi_window_exiting:1;
	uint64_t evt_pending:1;
	uint64_t rsvd:60;
};

/* Flags. */
#define NVMM_X64_STATE_SEGS	0x01
#define NVMM_X64_STATE_GPRS	0x02
#define NVMM_X64_STATE_CRS	0x04
#define NVMM_X64_STATE_DRS	0x08
#define NVMM_X64_STATE_MSRS	0x10
#define NVMM_X64_STATE_INTR	0x20
#define NVMM_X64_STATE_FPU	0x40
#define NVMM_X64_STATE_ALL	\
	(NVMM_X64_STATE_SEGS | NVMM_X64_STATE_GPRS | NVMM_X64_STATE_CRS | \
	 NVMM_X64_STATE_DRS | NVMM_X64_STATE_MSRS | NVMM_X64_STATE_INTR | \
	 NVMM_X64_STATE_FPU)

struct nvmm_x64_state {
	struct nvmm_x64_state_seg segs[NVMM_X64_NSEG];
	uint64_t gprs[NVMM_X64_NGPR];
	uint64_t crs[NVMM_X64_NCR];
	uint64_t drs[NVMM_X64_NDR];
	uint64_t msrs[NVMM_X64_NMSR];
	struct nvmm_x64_state_intr intr;
	struct fxsave fpu;
};

#define NVMM_VCPU_CONF_CPUID	NVMM_VCPU_CONF_MD_BEGIN
#define NVMM_VCPU_CONF_TPR	(NVMM_VCPU_CONF_MD_BEGIN + 1)

struct nvmm_vcpu_conf_cpuid {
	/* The options. */
	uint32_t mask:1;
	uint32_t exit:1;
	uint32_t rsvd:30;

	/* The leaf. */
	uint32_t leaf;

	/* The params. */
	union {
		struct {
			struct {
				uint32_t eax;
				uint32_t ebx;
				uint32_t ecx;
				uint32_t edx;
			} set;
			struct {
				uint32_t eax;
				uint32_t ebx;
				uint32_t ecx;
				uint32_t edx;
			} del;
		} mask;
	} u;
};

struct nvmm_vcpu_conf_tpr {
	uint32_t exit_changed:1;
	uint32_t rsvd:31;
};

#define nvmm_vcpu_exit		nvmm_x86_exit
#define nvmm_vcpu_event		nvmm_x86_event
#define nvmm_vcpu_state		nvmm_x64_state

#ifdef _KERNEL
#define NVMM_X86_MACH_NCONF	0
#define NVMM_X86_VCPU_NCONF	2
struct nvmm_x86_cpuid_mask {
	uint32_t eax;
	uint32_t ebx;
	uint32_t ecx;
	uint32_t edx;
};
extern const struct nvmm_x64_state nvmm_x86_reset_state;
extern const struct nvmm_x86_cpuid_mask nvmm_cpuid_00000001;
extern const struct nvmm_x86_cpuid_mask nvmm_cpuid_00000007;
extern const struct nvmm_x86_cpuid_mask nvmm_cpuid_80000001;
extern const struct nvmm_x86_cpuid_mask nvmm_cpuid_80000007;
extern const struct nvmm_x86_cpuid_mask nvmm_cpuid_80000008;
bool nvmm_x86_pat_validate(uint64_t);
#endif

#endif /* ASM_NVMM */

#endif /* _NVMM_X86_H_ */