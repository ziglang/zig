/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/*
 * Copyright (C) 2004, 2007-2010, 2011-2012 Synopsys, Inc. (www.synopsys.com)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * Amit Bhor, Sameer Dhavale: Codito Technologies 2004
 */

#ifndef __ASM_ARC_PTRACE_H
#define __ASM_ARC_PTRACE_H

#define PTRACE_GET_THREAD_AREA	25

#ifndef __ASSEMBLY__
/*
 * Userspace ABI: Register state needed by
 *  -ptrace (gdbserver)
 *  -sigcontext (SA_SIGNINFO signal frame)
 *
 * This is to decouple pt_regs from user-space ABI, to be able to change it
 * w/o affecting the ABI.
 *
 * The intermediate pad,pad2 are relics of initial layout based on pt_regs
 * for optimizations when copying pt_regs to/from user_regs_struct.
 * We no longer need them, but can't be changed as they are part of ABI now.
 *
 * Also, sigcontext only care about the scratch regs as that is what we really
 * save/restore for signal handling. However gdb also uses the same struct
 * hence callee regs need to be in there too.
*/
struct user_regs_struct {

	unsigned long pad;
	struct {
		unsigned long bta, lp_start, lp_end, lp_count;
		unsigned long status32, ret, blink, fp, gp;
		unsigned long r12, r11, r10, r9, r8, r7, r6, r5, r4, r3, r2, r1, r0;
		unsigned long sp;
	} scratch;
	unsigned long pad2;
	struct {
		unsigned long r25, r24, r23, r22, r21, r20;
		unsigned long r19, r18, r17, r16, r15, r14, r13;
	} callee;
	unsigned long efa;	/* break pt addr, for break points in delay slots */
	unsigned long stop_pc;	/* give dbg stop_pc after ensuring brkpt trap */
};

struct user_regs_arcv2 {
	unsigned long r30, r58, r59;
};

#endif /* !__ASSEMBLY__ */

#endif /* __ASM_ARC_PTRACE_H */