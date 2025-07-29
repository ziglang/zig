/* $NetBSD: mcontext.h,v 1.6 2020/03/14 16:12:16 skrll Exp $ */

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef _RISCV_MCONTEXT_H_
#define _RISCV_MCONTEXT_H_

/*
 */

#define	_NGREG	32		/* GR1-31 */
#define	_NFREG	33		/* F0-31, FCSR */

/*
 * This fragment is common to <riscv/mcontext.h> and <riscv/reg.h>
 */
#ifndef _BSD_FPREG_T_
union __fpreg {
		__uint64_t u_u64;
		double u_d;
};
#define _BSD_FPREG_T_	union __fpreg
#endif

typedef	__uint64_t	__greg_t;
typedef	__greg_t	__gregset_t[_NGREG];
typedef	__uint32_t	__greg32_t;
typedef	__greg32_t	__gregset32_t[_NGREG];
typedef _BSD_FPREG_T_	__fregset_t[_NFREG];

#define	_REG_X1		0
#define	_REG_X2		1
#define	_REG_X3		2
#define	_REG_X4		3
#define	_REG_X5		4
#define	_REG_X6		5
#define	_REG_X7		6
#define	_REG_X8		7
#define	_REG_X9		8
#define	_REG_X10	9
#define	_REG_X11	10
#define	_REG_X12	11
#define	_REG_X13	12
#define	_REG_X14	13
#define	_REG_X15	14
#define	_REG_X16	15
#define	_REG_X17	16
#define	_REG_X18	17
#define	_REG_X19	18
#define	_REG_X20	19
#define	_REG_X21	20
#define	_REG_X22	21
#define	_REG_X23	22
#define	_REG_X24	23
#define	_REG_X25	24
#define	_REG_X26	25
#define	_REG_X27	26
#define	_REG_X28	27
#define	_REG_X29	28
#define	_REG_X30	29
#define	_REG_X31	30
#define	_REG_PC		31

#define	_REG_RA		_REG_X1
#define	_REG_SP		_REG_X2
#define	_REG_GP		_REG_X3
#define	_REG_TP		_REG_X4
#define	_REG_S0		_REG_X8
#define	_REG_RV		_REG_X10
#define	_REG_A0		_REG_X10

#define	_REG_F0		0
#define	_REG_FPCSR	32

typedef struct {
	__gregset_t	__gregs;	/* General Purpose Register set */
	__fregset_t	__fregs;	/* Floating Point Register set */
	__greg_t	__private;	/* copy of l_private */
	__greg_t	__spare[8];	/* future proof */
} mcontext_t;

typedef struct {
	__gregset32_t	__gregs;	/* General Purpose Register set */
	__fregset_t	__fregs;	/* Floating Point Register set */
	__greg32_t	__private;	/* copy of l_private */
	__greg32_t	__spare[8];	/* future proof */
} mcontext32_t;

/* Machine-dependent uc_flags */
#define	_UC_SETSTACK	0x00010000	/* see <sys/ucontext.h> */
#define	_UC_CLRSTACK	0x00020000	/* see <sys/ucontext.h> */
#define	_UC_TLSBASE	0x00080000	/* see <sys/ucontext.h> */

#define _UC_MACHINE_SP(uc)	((uc)->uc_mcontext.__gregs[_REG_SP])
#define _UC_MACHINE_FP(uc)	((uc)->uc_mcontext.__gregs[_REG_S0])
#define _UC_MACHINE_PC(uc)	((uc)->uc_mcontext.__gregs[_REG_PC])
#define _UC_MACHINE_INTRV(uc)	((uc)->uc_mcontext.__gregs[_REG_RV])

#define	_UC_MACHINE_SET_PC(uc, pc)	_UC_MACHINE_PC(uc) = (pc)

#if defined(_RTLD_SOURCE) || defined(_LIBC_SOURCE) || defined(__LIBPTHREAD_SOURCE__)
#include <sys/tls.h>

/*
 * On RISCV, since displacements are signed 12-bit values, the TCB pointer is
 * not and points to the first static entry.
 */
#define	TLS_TP_OFFSET	0x0
#define	TLS_DTV_OFFSET	0x800
__CTASSERT(TLS_TP_OFFSET + sizeof(struct tls_tcb) < 0x800);

static __inline void *
__lwp_getprivate_fast(void)
{
	void *__tp;
	__asm("move %0,tp" : "=r"(__tp));
	return __tp;
}

static __inline void *
__lwp_gettcb_fast(void)
{
	void *__tcb;

	__asm __volatile(
		"addi %[__tcb],tp,%[__offset]"
	    :	[__tcb] "=r" (__tcb)
	    :	[__offset] "n" (-(TLS_TP_OFFSET + sizeof(struct tls_tcb))));

	return __tcb;
}

static __inline void
__lwp_settcb(void *__tcb)
{
	__asm __volatile(
		"addi tp,%[__tcb],%[__offset]"
	    :
	    :	[__tcb] "r" (__tcb),
		[__offset] "n" (TLS_TP_OFFSET + sizeof(struct tls_tcb)));
}
#endif /* _RTLD_SOURCE || _LIBC_SOURCE || __LIBPTHREAD_SOURCE__ */

#endif /* !_RISCV_MCONTEXT_H_ */