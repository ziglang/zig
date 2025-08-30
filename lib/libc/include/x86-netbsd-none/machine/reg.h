/*	$NetBSD: reg.h,v 1.22 2019/05/18 17:41:34 christos Exp $	*/

/*-
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)reg.h	5.5 (Berkeley) 1/18/91
 */

#ifndef _I386_REG_H_
#define _I386_REG_H_

#include <x86/fpu.h>
#include <machine/frame.h>

/*
 * Location of the users' stored
 * registers within appropriate frame of 'trap' and 'syscall', relative to
 * base of stack frame.
 *
 * XXX these should be nuked. They used to be used in the NetBSD/i386 bits
 * of gdb, but no more.
 */

/* When referenced during a trap/exception, registers are at these offsets */

#define	tES	(offsetof(struct trapframe, tf_es) / sizeof (int))
#define	tDS	(offsetof(struct trapframe, tf_ds) / sizeof (int))
#define	tEDI	(offsetof(struct trapframe, tf_edi) / sizeof (int))
#define	tESI	(offsetof(struct trapframe, tf_esi) / sizeof (int))
#define	tEBP	(offsetof(struct trapframe, tf_ebp) / sizeof (int))
#define	tEBX	(offsetof(struct trapframe, tf_ebx) / sizeof (int))
#define	tEDX	(offsetof(struct trapframe, tf_edx) / sizeof (int))
#define	tECX	(offsetof(struct trapframe, tf_ecx) / sizeof (int))
#define	tEAX	(offsetof(struct trapframe, tf_eax) / sizeof (int))

#define	tEIP	(offsetof(struct trapframe, tf_eip) / sizeof (int))
#define	tCS	(offsetof(struct trapframe, tf_cs) / sizeof (int))
#define	tEFLAGS	(offsetof(struct trapframe, tf_eflags) / sizeof (int))
#define	tESP	(offsetof(struct trapframe, tf_esp) / sizeof (int))
#define	tSS	(offsetof(struct trapframe, tf_ss) / sizeof (int))

/*
 * Registers accessible to ptrace(2) syscall for debugger
 * The machine-dependent code for PT_{SET,GET}REGS needs to
 * use whichver order, defined above, is correct, so that it
 * is all invisible to the user.
 */
struct reg {
	int	r_eax;
	int	r_ecx;
	int	r_edx;
	int	r_ebx;
	int	r_esp;
	int	r_ebp;
	int	r_esi;
	int	r_edi;
	int	r_eip;
	int	r_eflags;
	int	r_cs;
	int	r_ss;
	int	r_ds;
	int	r_es;
	int	r_fs;
	int	r_gs;
};

struct fpreg {
	struct save87 fstate;
};
__CTASSERT_NOLINT(sizeof(struct fpreg) == 108);

struct xmmregs {
	struct fxsave fxstate;
};
__CTASSERT(sizeof(struct xmmregs) == 512);

/*
 * Debug Registers
 *
 * DR0-DR3  Debug Address Registers
 * DR4-DR5  Reserved
 * DR6      Debug Status Register
 * DR7      Debug Control Register
 */
struct dbreg {
	int	dr[8];
};

#endif /* !_I386_REG_H_ */