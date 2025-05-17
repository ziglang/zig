/*	$NetBSD: mcontext.h,v 1.12 2020/10/04 10:34:18 rin Exp $	*/

/*-
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Klaus Klein.
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

#ifndef _M68K_MCONTEXT_H_
#define _M68K_MCONTEXT_H_

#ifdef _KERNEL
#include <m68k/cpuframe.h>
#endif

/*
 * mcontext extensions to handle signal delivery.
 */
#define _UC_SETSTACK	0x00010000
#define _UC_CLRSTACK	0x00020000

/*
 * General register state
 */
#define	_NGREG		18
typedef int		__greg_t;
typedef	__greg_t	__gregset_t[_NGREG];

#define	_REG_D0	0
#define	_REG_D1	1
#define	_REG_D2	2
#define	_REG_D3	3
#define	_REG_D4	4
#define	_REG_D5	5
#define	_REG_D6	6
#define	_REG_D7	7
#define	_REG_A0	8
#define	_REG_A1	9
#define	_REG_A2	10
#define	_REG_A3	11
#define	_REG_A4	12
#define	_REG_A5	13
#define	_REG_A6	14
#define	_REG_A7	15
#define	_REG_PC	16
#define	_REG_PS	17

typedef struct {
	int	__fp_pcr;
	int	__fp_psr;
	int	__fp_piaddr;
	int	__fp_fpregs[8*3];
} __fpregset_t;

typedef struct {
	__gregset_t	__gregs;	/* General Register set */
	__fpregset_t	__fpregs;	/* Floating Point Register set */
	union {
		long	__mc_state[201];	/* Only need 308 bytes... */
#if defined(_KERNEL) || defined(__M68K_MCONTEXT_PRIVATE)
		struct {
			/* Rest of the frame. */
			unsigned int	__mcf_format;
			unsigned int	__mcf_vector;
			union F_u	__mcf_exframe;
			/* Rest of the FPU frame. */
			union FPF_u1	__mcf_fpf_u1;
			union FPF_u2	__mcf_fpf_u2;
		} __mc_frame;
#endif /* _KERNEL || __M68K_MCONTEXT_PRIVATE */
	}		__mc_pad;
	__greg_t	_mc_tlsbase;
} mcontext_t;

/* Note: no additional padding is to be performed in ucontext_t. */

/* Machine-specific uc_flags value */
#define _UC_M68K_UC_USER 0x40000000
#define	_UC_TLSBASE	0x00080000

#define _UC_MACHINE_SP(uc)	((uc)->uc_mcontext.__gregs[_REG_A7])
#define _UC_MACHINE_FP(uc)	((uc)->uc_mcontext.__gregs[_REG_A6])
#define _UC_MACHINE_PC(uc)	((uc)->uc_mcontext.__gregs[_REG_PC])
#define _UC_MACHINE_INTRV(uc)	((uc)->uc_mcontext.__gregs[_REG_D0])

#define	_UC_MACHINE_SET_PC(uc, pc)	_UC_MACHINE_PC(uc) = (pc)

#define	__UCONTEXT_SIZE	1024

#if defined(_LIBC_SOURCE) || defined(_RTLD_SOURCE) || defined(__LIBPTHREAD_SOURCE__)
#define	TLS_TP_OFFSET	0x7000
#define	TLS_DTV_OFFSET	0x8000

#include <sys/tls.h>

__CTASSERT(TLS_TP_OFFSET + sizeof(struct tls_tcb) < 0x8000);
__CTASSERT(TLS_TP_OFFSET % sizeof(struct tls_tcb) == 0);

__BEGIN_DECLS

void *_lwp_getprivate(void);
void _lwp_setprivate(void *);

static __inline struct tls_tcb *
__lwp_gettcb_fast(void)
{
	unsigned int __tcb = (unsigned int)_lwp_getprivate();
	return (struct tls_tcb *)(uintptr_t)
	    (__tcb - TLS_TP_OFFSET - sizeof(struct tls_tcb));
}

static inline void
__lwp_settcb(struct tls_tcb *__tcb)
{
	__tcb += TLS_TP_OFFSET / sizeof(*__tcb) + 1;
	_lwp_setprivate(__tcb);
}
__END_DECLS
#endif

#endif	/* !_M68K_MCONTEXT_H_ */