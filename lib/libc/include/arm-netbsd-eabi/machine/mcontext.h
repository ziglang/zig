/*	$NetBSD: mcontext.h,v 1.23 2021/10/06 05:33:15 skrll Exp $	*/

/*-
 * Copyright (c) 2001, 2002 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Klaus Klein and by Jason R. Thorpe of Wasabi Systems, Inc.
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

#ifndef _ARM_MCONTEXT_H_
#define _ARM_MCONTEXT_H_

#include <sys/stdint.h>

/*
 * General register state
 */
#if defined(__aarch64__)
#define _NGREG		35	/* GR0-30, SP, PC, SPSR, TPIDR */
#define _NGREG32	17
typedef __uint64_t	__greg_t;
typedef unsigned int	__greg32_t;

typedef __greg32_t	__gregset32_t[_NGREG32];
#elif defined(__arm__)
#define _NGREG		17
typedef unsigned int	__greg_t;
#endif

typedef __greg_t	__gregset_t[_NGREG];

#define _REG_R0		0
#define _REG_R1		1
#define _REG_R2		2
#define _REG_R3		3
#define _REG_R4		4
#define _REG_R5		5
#define _REG_R6		6
#define _REG_R7		7
#define _REG_R8		8
#define _REG_R9		9
#define _REG_R10	10
#define _REG_R11	11
#define _REG_R12	12
#define _REG_R13	13
#define _REG_R14	14
#define _REG_R15	15
#define _REG_CPSR	16

#define _REG_X0		0
#define _REG_X1		1
#define _REG_X2		2
#define _REG_X3		3
#define _REG_X4		4
#define _REG_X5		5
#define _REG_X6		6
#define _REG_X7		7
#define _REG_X8		8
#define _REG_X9		9
#define _REG_X10	10
#define _REG_X11	11
#define _REG_X12	12
#define _REG_X13	13
#define _REG_X14	14
#define _REG_X15	15
#define _REG_X16	16
#define _REG_X17	17
#define _REG_X18	18
#define _REG_X19	19
#define _REG_X20	20
#define _REG_X21	21
#define _REG_X22	22
#define _REG_X23	23
#define _REG_X24	24
#define _REG_X25	25
#define _REG_X26	26
#define _REG_X27	27
#define _REG_X28	28
#define _REG_X29	29
#define _REG_X30	30
#define _REG_X31	31
#define _REG_ELR	32
#define _REG_SPSR	33
#define _REG_TPIDR	34

/* Convenience synonyms */

#if defined(__aarch64__)
#define _REG_RV		_REG_X0
#define _REG_FP		_REG_X29
#define _REG_LR		_REG_X30
#define _REG_SP		_REG_X31
#define _REG_PC		_REG_ELR
#elif defined(__arm__)
#define _REG_RV		_REG_R0
#define _REG_FP		_REG_R11
#define _REG_SP		_REG_R13
#define _REG_LR		_REG_R14
#define _REG_PC		_REG_R15
#endif

/*
 * Floating point register state
 */
#if defined(__aarch64__)

#define _NFREG	32			/* Number of SIMD registers */

typedef struct {
	union __freg {
		__uint8_t	__b8[16];
		__uint16_t	__h16[8];
		__uint32_t	__s32[4];
		__uint64_t	__d64[2];
		__uint128_t	__q128[1];
	}		__qregs[_NFREG] __aligned(16);
	__uint32_t	__fpcr;		/* FPCR */
	__uint32_t	__fpsr;		/* FPSR */
} __fregset_t;

/* Compat structures */
typedef struct {
#if 1 /* __ARM_EABI__ is default on aarch64 */
	unsigned int	__vfp_fpscr;
	uint64_t	__vfp_fstmx[32];
	unsigned int	__vfp_fpsid;
#else
	unsigned int	__vfp_fpscr;
	unsigned int	__vfp_fstmx[33];
	unsigned int	__vfp_fpsid;
#endif
} __vfpregset32_t;

typedef struct {
	__gregset32_t	__gregs;
	__vfpregset32_t __vfpregs;
	__greg32_t	_mc_tlsbase;
	__greg32_t	_mc_user_tpid;
} mcontext32_t;

typedef struct {
	__gregset_t	__gregs;	/* General Purpose Register set */
	__fregset_t	__fregs;	/* FPU/SIMD Register File */
	__greg_t	__spare[8];	/* future proof */
} mcontext_t;

#elif defined(__arm__)
/* Note: the storage layout of this structure must be identical to ARMFPE! */
typedef struct {
	unsigned int	__fp_fpsr;
	struct {
		unsigned int	__fp_exponent;
		unsigned int	__fp_mantissa_hi;
		unsigned int	__fp_mantissa_lo;
	}		__fp_fr[8];
} __fpregset_t;

typedef struct {
#ifdef __ARM_EABI__
	unsigned int	__vfp_fpscr;
	uint64_t	__vfp_fstmx[32];
	unsigned int	__vfp_fpsid;
#else
	unsigned int	__vfp_fpscr;
	unsigned int	__vfp_fstmx[33];
	unsigned int	__vfp_fpsid;
#endif
} __vfpregset_t;

typedef struct {
	__gregset_t	__gregs;
	union {
		__fpregset_t __fpregs;
		__vfpregset_t __vfpregs;
	} __fpu;
	__greg_t	_mc_tlsbase;
	__greg_t	_mc_user_tpid;
} mcontext_t, mcontext32_t;


#define _UC_MACHINE_PAD	1		/* Padding appended to ucontext_t */

#ifdef __ARM_EABI__
#define	__UCONTEXT_SIZE	(256 + 144)
#else
#define	__UCONTEXT_SIZE	256
#endif

#endif

#if defined(_RTLD_SOURCE) || defined(_LIBC_SOURCE) || \
    defined(__LIBPTHREAD_SOURCE__)

#include <sys/tls.h>

#if defined(__aarch64__)

__BEGIN_DECLS
static __inline void *
__lwp_getprivate_fast(void)
{
	void *__tpidr;
	__asm __volatile("mrs\t%0, tpidr_el0" : "=r"(__tpidr));
	return __tpidr;
}
__END_DECLS

#elif defined(__arm__)

__BEGIN_DECLS
static __inline void *
__lwp_getprivate_fast(void)
{
#if !defined(__thumb__) || defined(_ARM_ARCH_T2)
	extern void *_lwp_getprivate(void);
	void *rv;
	__asm("mrc p15, 0, %0, c13, c0, 3" : "=r"(rv));
	if (__predict_true(rv))
		return rv;
	/*
	 * Some ARM cores are broken and don't raise an undefined fault when an
	 * unrecogized mrc instruction is encountered, but just return zero.
	 * To do deal with that, if we get a zero we (re-)fetch the value using
	 * syscall.
	 */
	return _lwp_getprivate();
#else
	extern void *__aeabi_read_tp(void);
	return __aeabi_read_tp();
#endif /* !__thumb__ || _ARM_ARCH_T2 */
}
__END_DECLS
#endif

#endif /* _RTLD_SOURCE || _LIBC_SOURCE || __LIBPTHREAD_SOURCE__ */

/* Machine-dependent uc_flags */
#define _UC_TLSBASE	0x00080000	/* see <sys/ucontext.h> */

/* Machine-dependent uc_flags for arm */
#define	_UC_ARM_VFP	0x00010000	/* FPU field is VFP */

/* used by signal delivery to indicate status of signal stack */
#define _UC_SETSTACK	0x00020000
#define _UC_CLRSTACK	0x00040000

#define _UC_MACHINE_SP(uc)	((uc)->uc_mcontext.__gregs[_REG_SP])
#define _UC_MACHINE_FP(uc)	((uc)->uc_mcontext.__gregs[_REG_FP])
#define _UC_MACHINE_PC(uc)	((uc)->uc_mcontext.__gregs[_REG_PC])
#define _UC_MACHINE_INTRV(uc)	((uc)->uc_mcontext.__gregs[_REG_RV])

#define _UC_MACHINE_SET_PC(uc, pc)	\
				_UC_MACHINE_PC(uc) = (pc)

#if defined(_KERNEL)
__BEGIN_DECLS
void vfp_getcontext(struct lwp *, mcontext_t *, int *);
void vfp_setcontext(struct lwp *, const mcontext_t *);
__END_DECLS
#endif

#endif	/* !_ARM_MCONTEXT_H_ */