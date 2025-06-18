/*-
 * Copyright (c) 2014 Andrew Turner
 * Copyright (c) 2014-2015 The FreeBSD Foundation
 * All rights reserved.
 *
 * This software was developed by Andrew Turner under
 * sponsorship from the FreeBSD Foundation.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifdef __arm__
#include <arm/ucontext.h>
#else /* !__arm__ */

#ifndef _MACHINE_UCONTEXT_H_
#define	_MACHINE_UCONTEXT_H_

struct gpregs {
	__register_t	gp_x[30];
	__register_t	gp_lr;
	__register_t	gp_sp;
	__register_t	gp_elr;
	__uint64_t	gp_spsr;
};

struct fpregs {
	__uint128_t	fp_q[32];
	__uint32_t	fp_sr;
	__uint32_t	fp_cr;
	int		fp_flags;
	int		fp_pad;
};

/*
 * Support for registers that don't fit into gpregs or fpregs, e.g. SVE.
 * There are some registers that have been added so are optional. To support
 * these create an array of headers that point at the register data.
 */
struct arm64_reg_context {
	__uint32_t	ctx_id;
	__uint32_t	ctx_size;
};

#define	ARM64_CTX_END		0xa5a5a5a5
#define	ARM64_CTX_SVE		0x00657673

struct sve_context {
	struct arm64_reg_context sve_ctx;
	__uint16_t	sve_vector_len;
	__uint16_t	sve_flags;
	__uint16_t	sve_reserved[2];
};

struct __mcontext {
	struct gpregs	mc_gpregs;
	struct fpregs	mc_fpregs;
	int		mc_flags;
#define	_MC_FP_VALID	0x1		/* Set when mc_fpregs has valid data */
	int		mc_pad;		/* Padding */
	__uint64_t	mc_ptr;		/* Address of extra_regs struct */
	__uint64_t	mc_spare[7];	/* Space for expansion, set to zero */
};


typedef struct __mcontext mcontext_t;

#ifdef COMPAT_FREEBSD32
#include <compat/freebsd32/freebsd32_signal.h>
typedef struct __mcontext32 {
	uint32_t		mc_gregset[17];
	uint32_t		mc_vfp_size;
	uint32_t		mc_vfp_ptr;
	uint32_t		mc_spare[33];
} mcontext32_t;

typedef struct __ucontext32 {
	sigset_t		uc_sigmask;
	mcontext32_t		uc_mcontext;
	u_int32_t		uc_link;
	struct sigaltstack32	uc_stack;
	u_int32_t		uc_flags;
	u_int32_t		__spare__[4];
} ucontext32_t;

typedef struct __mcontext32_vfp {
	__uint64_t	mcv_reg[32];
	__uint32_t	mcv_fpscr;
} mcontext32_vfp_t;

#endif /* COMPAT_FREEBSD32 */

#endif	/* !_MACHINE_UCONTEXT_H_ */

#endif /* !__arm__ */