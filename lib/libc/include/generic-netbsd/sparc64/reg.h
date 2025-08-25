/*	$NetBSD: reg.h,v 1.15 2016/12/30 18:30:19 christos Exp $ */

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratory.
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
 *	@(#)reg.h	8.1 (Berkeley) 6/11/93
 */

/*
 * Copyright (c) 1996-2002 Eduardo Horvath.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the author nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
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
 *	@(#)reg.h	8.1 (Berkeley) 6/11/93
 */

#ifndef _MACHINE_REG_H_
#define	_MACHINE_REG_H_

/*
 * Registers passed to trap/syscall/etc.
 * This structure is known to occupy exactly 80 bytes (see locore.s).
 * Note, tf_global[0] is not actually written (since g0 is always 0).
 * (The slot tf_global[0] is used to send a copy of %wim to kernel gdb.
 * This is known as `cheating'.)
 */
struct trapframe32 {
	int	tf_psr;		/* psr */
	int	tf_pc;		/* return pc */
	int	tf_npc;		/* return npc */
	int	tf_y;		/* %y register */
	int	tf_global[8];	/* global registers in trap's caller */
	int	tf_out[8];	/* output registers in trap's caller */
};

/*
 * The v9 trapframe is a bit more complex.  Since we don't get a free 
 * register window with each trap we need some way to keep track of
 * pending traps.
 * (The slot tf_global[0] is used to store the %fp when this is used
 * as a clockframe.  This is known as `cheating'.)
 */

struct trapframe64 {
	int64_t		tf_tstate;	/* tstate register */
	int64_t		tf_pc;		/* return pc */
	int64_t		tf_npc;		/* return npc */
	int64_t		tf_fault;	/* faulting addr -- need somewhere to save it */
	int64_t		tf_kstack;	/* kernel stack of prev tf */
	int		tf_y;		/* %y register -- 32-bits */
	short		tf_tt;		/* What type of trap this was */
	char		tf_pil;		/* What IRQ we're handling */
	char		tf_oldpil;	/* What our old SPL was */
	int64_t		tf_global[8];	/* global registers in trap's caller */
	/* n.b. tf_global[0] is used for fp when this is a clockframe */
	int64_t		tf_out[8];	/* output registers in trap's caller */
	int64_t		tf_local[8];	/* local registers in trap's caller (for debug) */
	int64_t		tf_in[8];	/* in registers in trap's caller (for debug) */
};


/*
 * Register windows.  Each stack pointer (%o6 aka %sp) in each window
 * must ALWAYS point to some place at which it is safe to scribble on
 * 64 bytes.  (If not, your process gets mangled.)  Furthermore, each
 * stack pointer should be aligned on an 8-byte boundary for v8 stacks
 * or a 16-byte boundary (plus the BIAS) for v9 stacks (the kernel
 * as currently coded allows arbitrary alignment, but with a hefty
 * performance penalty).
 */
struct rwindow32 {
	int	rw_local[8];		/* %l0..%l7 */
	int	rw_in[8];		/* %i0..%i7 */
};

/* Don't forget the BIAS!! */
struct rwindow64 {
	int64_t	rw_local[8];		/* %l0..%l7 */
	int64_t	rw_in[8];		/* %i0..%i7 */
};

/*
 * Clone trapframe for now; this seems to be the more useful
 * than the old struct reg above.
 */
struct reg32 {
	int	r_psr;		/* psr */
	int	r_pc;		/* return pc */
	int	r_npc;		/* return npc */
	int	r_y;		/* %y register */
	int	r_global[8];	/* global registers in trap's caller */
	int	r_out[8];	/* output registers in trap's caller */
};

struct reg64 {
	int64_t	r_tstate;	/* tstate register */
	int64_t	r_pc;		/* return pc */
	int64_t	r_npc;		/* return npc */
	int	r_y;		/* %y register -- 32-bits */
	int64_t	r_global[8];	/* global registers in trap's caller */
	int64_t	r_out[8];	/* output registers in trap's caller */
};

#include <machine/fsr.h>

/*
 * FP coprocessor registers.
 *
 * FP_QSIZE is the maximum coprocessor instruction queue depth
 * of any implementation on which the kernel will run.  David Hough:
 * ``I'd suggest allowing 16 ... allowing an indeterminate variable
 * size would be even better''.  Of course, we cannot do that; we
 * need to malloc these.
 *
 * XXXX UltraSPARC processors don't implement a floating point queue.
 */
#define	FP_QSIZE	16
#define ALIGNFPSTATE(f)		((struct fpstate64 *)(((long)(f))&(~SPARC64_BLOCK_ALIGN)))

struct fp_qentry {
	int	*fq_addr;		/* the instruction's address */
	int	fq_instr;		/* the instruction itself */
};

/*
 * The actual FP registers are made accessible (c.f. ptrace(2)) through
 * a `struct fpreg'; <arch/sparc64/sparc64/process_machdep.c> relies on the
 * fact that `fpreg' is a prefix of `fpstate'.
 */
struct fpreg64 {
	u_int	fr_regs[64];		/* our view is 64 32-bit registers */
	int64_t	fr_fsr;			/* %fsr */
	int	fr_gsr;			/* graphics state reg */
};

struct fpstate64 {
	struct fpreg64 fs_reg;
#define fs_regs fs_reg.fr_regs
#define fs_fsr fs_reg.fr_fsr
#define fs_gsr fs_reg.fr_gsr
	int	fs_qsize;		/* actual queue depth */
	struct	fp_qentry fs_queue[FP_QSIZE];	/* queue contents */
};

/*
 * 32-bit fpreg used by 32-bit sparc CPUs
 */
struct fpreg32 {
	u_int	fr_regs[32];		/* our view is 32 32-bit registers */
	int	fr_fsr;			/* %fsr */
};

/* 
 * For 32-bit emulations.
 */
struct fpstate32 {
	struct fpreg32 fs_reg;
	int	fs_qsize;		/* actual queue depth */
	struct	fp_qentry fs_queue[FP_QSIZE];	/* queue contents */
};

#if defined(__arch64__)
/* Here we gotta do naughty things to let gdb work on 32-bit binaries */
#define reg		reg64
#define fpreg		fpreg64
#define fpstate		fpstate64
#define trapframe	trapframe64
#define rwindow		rwindow64
#else
#define reg		reg32
#define fpreg		fpreg32
#define fpstate		fpstate32
#define trapframe	trapframe32
#define rwindow		rwindow32
#endif

#endif /* _MACHINE_REG_H_ */