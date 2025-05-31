/*	$NetBSD: reg.h,v 1.14 2021/08/13 20:47:55 andvar Exp $	*/

#ifndef _POWERPC_REG_H_
#define _POWERPC_REG_H_

/*
 *  Register Usage according the SVR4 ABI for PPC.
 *
 *  Register	Usage
 *  r0		Volatile register which may be modified during function linkage
 *  r1		Stack frame pointer, always valid
 *  r2		System-reserved register
 *  r3-r4	Volatile registers used for parameter passing and return values
 *  r5-r10	Volatile registers used for parameter passing
 *  r11-r12	Volatile register which may be modified during function linkage
 *  r13		Small data area pointer register
 *  f0		Volatile register
 *  f1		Volatile registers used for parameter passing and return values
 *  f2-f8	Volatile registers used for parameter passing
 *  f9-f13	Volatile registers
 *
 *  [Start of callee-saved registers]
 *  r14-r30	Registers used for local variables
 *  r31		Used for local variable or "environment pointers"
 *  f14-f31	Registers used for local variables
 *
 *
 *  Register Usage according the ELF64 ABI (PowerOpen/AIX) for PPC.
 *
 *  Register	Usage
 *  r0		Volatile register which may be modified during function linkage
 *  r1		Stack frame pointer, always valid
 *  r2		TOC pointer
 *  r3		Volatile register used for parameter passing and return value
 *  r4-r10	Volatile registers used for parameter passing
 *  r11		Volatile register used in calls by pointer and as an
 *		environment pointer for languages which require one
 *  r12		Volatile register used for exception handling and glink code
 *  r13		Reserved for use as system thread ID
 *
 *  f0		Volatile register
 *  f1-f4	Volatile registers used for parameter passing and return values
 *  f5-f13	Volatile registers used for parameter passing

 *  [Start of callee-saved registers]
 *  r14-r31	Registers used for local variables
 *  f14-f31	Registers used for local variables
 *
 */

struct reg {				/* base registers */
	__register_t fixreg[32];
	__register_t lr;			/* Link Register */
	int cr;				/* Condition Register */
	int xer;			/* SPR 1 */
	__register_t ctr;			/* Count Register */
	__register_t pc;			/* Program Counter */
};

struct fpreg {				/* Floating Point registers */
#ifdef _KERNEL
	uint64_t fpreg[32];
	uint64_t fpscr;			/* Status and Control Register */
#else
	double fpreg[32];
	double fpscr;			/* Status and Control Register */
#endif
};

struct vreg {				/* Vector registers */
	uint32_t vreg[32][4];
	__register_t vrsave;		/* SPR 256 */
	__register_t spare[2];		/* filler */
	__register_t vscr;		/* Vector Status And Control Register */
};

#endif /* _POWERPC_REG_H_ */