/*	$NetBSD: mcontext.h,v 1.24 2020/10/03 09:56:00 martin Exp $	*/

/*-
 * Copyright (c) 1999, 2002 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Klaus Klein, and by Jason R. Thorpe of Wasabi Systems, Inc.
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

#ifndef _MIPS_MCONTEXT_H_
#define	_MIPS_MCONTEXT_H_

/*
 * General register state
 */
#define	_NGREG		37	/* R0-R31, MDLO, MDHI, CAUSE, PC, SR */

#define	_REG_R0		0
#define	_REG_AT		1
#define	_REG_V0		2
#define	_REG_V1		3
#define	_REG_A0		4
#define	_REG_A1		5
#define	_REG_A2		6
#define	_REG_A3		7
#define	_REG_T0		8
#define	_REG_T1		9
#define	_REG_T2		10
#define	_REG_T3		11
#define	_REG_T4		12
#define	_REG_T5		13
#define	_REG_T6		14
#define	_REG_T7		15
#define	_REG_S0		16
#define	_REG_S1		17
#define	_REG_S2		18
#define	_REG_S3		19
#define	_REG_S4		20
#define	_REG_S5		21
#define	_REG_S6		22
#define	_REG_S7		23
#define	_REG_T8		24
#define	_REG_T9		25
#define	_REG_K0		26
#define	_REG_K1		27
#define	_REG_GP		28
#define	_REG_SP		29
#define	_REG_S8		30
#define	_REG_RA		31

/* XXX: The following conflict with <mips/regnum.h> */
#define	_REG_MDLO	32
#define	_REG_MDHI	33
#define	_REG_CAUSE	34
#define	_REG_EPC	35
#define	_REG_SR		36

#ifndef __ASSEMBLER__

/* Make sure this is signed; we need pointers to be sign-extended. */
#if defined(__mips_n32)
typedef	long long	__greg_t;
#else
typedef	long		__greg_t;
#endif /* __mips_n32 */

typedef	__greg_t	__gregset_t[_NGREG];

/*
 * For the O32/O64 ABI, there are 16 doubles, one at each even FP reg
 * number.  The FP registers themselves are 32-bits.
 *
 * For 64-bit ABIs (include N32), each FP register is a 64-bit double.
 */
typedef	__greg_t	__freg_t;

/*
 * Floating point register state
 */
struct __fpregset_nabi {
	union {
		double	__fp64_dregs[32];
		__freg_t __fp_regs[32];
	} __fp_r;
	__greg_t	__fp_csr;
};
struct __fpregset_oabi {
	union {
		double	__fp_dregs[16];
		float	__fp_fregs[32];
		__int32_t __fp_regs[32];
	} __fp_r;
	unsigned int	__fp_csr;
	unsigned int	__fp_pad;
};

#if __mips_n32 || __mips_n64
typedef struct __fpregset_nabi __fpregset_t;
#else
typedef struct __fpregset_oabi __fpregset_t;
#endif

typedef struct {
	__gregset_t	__gregs;
	__fpregset_t	__fpregs;
	__greg_t	_mc_tlsbase;
#if !__mips_n32
	__greg_t	__mc_unused;
#endif
} mcontext_t;

#if defined(_KERNEL) && !defined(__mips_o32)
typedef	__int32_t	__greg32_t;
typedef __greg32_t	__gregset32_t[_NGREG];

typedef struct {
	__gregset32_t		__gregs;
	struct __fpregset_oabi	__fpregs;
	__greg32_t		_mc_tlsbase;
	__greg32_t		__mc_unused;
} mcontext_o32_t;

typedef struct {
	__gregset_t		__gregs;
	struct __fpregset_nabi	__fpregs;
	__greg_t		_mc_tlsbase;
} mcontext32_t;

#endif /* _KERNEL && _LP64 */

#endif /* !__ASSEMBLER__ */

#define	_UC_MACHINE_PAD		14	/* Padding appended to ucontext_t */

#define	_UC_SETSTACK	0x00010000
#define	_UC_CLRSTACK	0x00020000
#define	_UC_TLSBASE	0x00040000

#define	_UC_MACHINE_SP(uc)	((uc)->uc_mcontext.__gregs[_REG_SP])
#define	_UC_MACHINE_FP(uc)	((uc)->uc_mcontext.__gregs[_REG_S8])
#define	_UC_MACHINE_PC(uc)	((uc)->uc_mcontext.__gregs[_REG_EPC])
#define	_UC_MACHINE_INTRV(uc)	((uc)->uc_mcontext.__gregs[_REG_V0])

#define	_UC_MACHINE_SET_PC(uc, pc)	_UC_MACHINE_PC(uc) = (pc)

#define	_UC_MACHINE32_SP(uc)	_UC_MACHINE_SP(uc)
#define	_UC_MACHINE32_PC(uc)	_UC_MACHINE_PC(uc)
#define	_UC_MACHINE32_INTRV(uc)	_UC_MACHINE_INTRV(uc)
#define	_UC_MACHINE32_PAD	14	/* Padding appended to ucontext32_t */

#define	_UC_MACHINE32_SET_PC(uc, pc)	_UC_MACHINE_PC((uc), (pc))

#define	__UCONTEXT_SIZE_O32	(40 + 296 +  56)	/* 392 */
#define	__UCONTEXT_SIZE_N32	(40 + 568 +  56)	/* 664 */
#define	__UCONTEXT_SIZE_N64	(56 + 576 + 112)	/* 774 */

#ifdef __mips_o32
#define	__UCONTEXT_SIZE		__UCONTEXT_SIZE_O32
#elif __mips_n32
#define	__UCONTEXT_SIZE		__UCONTEXT_SIZE_N32
#elif __mips_n64
#define	__UCONTEXT_SIZE		__UCONTEXT_SIZE_N64
#define	__UCONTEXT32_SIZE	__UCONTEXT_SIZE_N32
#else
#error O64 is not supported
#endif

#if defined(_LIBC_SOURCE) || defined(_RTLD_SOURCE) || defined(__LIBPTHREAD_SOURCE__)
#define	TLS_TP_OFFSET	0x7000
#define	TLS_DTV_OFFSET	0x8000

#include <sys/tls.h>

__CTASSERT(TLS_TP_OFFSET + sizeof(struct tls_tcb) < 0x8000);
__CTASSERT(TLS_TP_OFFSET % sizeof(struct tls_tcb) == 0);

__BEGIN_DECLS

static __inline struct tls_tcb *
__lwp_gettcb_fast(void)
{
	struct tls_tcb *__tcb;

	/*
	 * Only emit a rdhwr $3, $29 so the kernel can quickly emulate it.
	 */
	__asm __volatile(
#if 1
		// For some reason the syscall is much faster than
		// emulating rdhwr $3,$29 on a CN50xx
		"addiu $2,$0,316; syscall; nop; move %[__tcb],$2"
#else
		".set push"
		";.set mips32r2"
		";.p2align 4"
		";ssnop"
		";rdhwr $3,$29"
		";ssnop"
		";move %0,$3"
		";.set pop"
#endif
	    : [__tcb]"=r"(__tcb)
	    :
	    : "v0", "v1", "a3");
	return __tcb - (TLS_TP_OFFSET / sizeof(*__tcb) + 1);
}

void _lwp_setprivate(void *);

static inline void
__lwp_settcb(struct tls_tcb *__tcb)
{
	__tcb += TLS_TP_OFFSET / sizeof(*__tcb) + 1;
	_lwp_setprivate(__tcb);
}
__END_DECLS
#endif

#endif	/* _MIPS_MCONTEXT_H_ */