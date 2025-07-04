/*-
 * Copyright (c) 2015 The FreeBSD Foundation
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
#include <arm/vfp.h>
#else /* !__arm__ */

#ifndef _MACHINE_VFP_H_
#define	_MACHINE_VFP_H_

/* VFPCR */
#define	VFPCR_AHP		(0x04000000)	/* alt. half-precision: */
#define	VFPCR_DN		(0x02000000)	/* default NaN enable */
#define	VFPCR_FZ		(0x01000000)	/* flush to zero enabled */
#define	VFPCR_INIT		0		/* Default fpcr after exec */

#define	VFPCR_RMODE_OFF		22		/* rounding mode offset */
#define	VFPCR_RMODE_MASK	(0x00c00000)	/* rounding mode mask */
#define	VFPCR_RMODE_RN		(0x00000000)	/* round nearest */
#define	VFPCR_RMODE_RPI		(0x00400000)	/* round to plus infinity */
#define	VFPCR_RMODE_RNI		(0x00800000)	/* round to neg infinity */
#define	VFPCR_RMODE_RM		(0x00c00000)	/* round to zero */

#define	VFPCR_STRIDE_OFF	20		/* vector stride -1 */
#define	VFPCR_STRIDE_MASK	(0x00300000)
#define	VFPCR_LEN_OFF		16		/* vector length -1 */
#define	VFPCR_LEN_MASK		(0x00070000)
#define	VFPCR_IDE		(0x00008000)	/* input subnormal exc enable */
#define	VFPCR_IXE		(0x00001000)	/* inexact exception enable */
#define	VFPCR_UFE		(0x00000800)	/* underflow exception enable */
#define	VFPCR_OFE		(0x00000400)	/* overflow exception enable */
#define	VFPCR_DZE		(0x00000200)	/* div by zero exception en */
#define	VFPCR_IOE		(0x00000100)	/* invalid op exec enable */

#ifndef LOCORE
struct vfpstate {
	__uint128_t	vfp_regs[32];
	uint32_t	vfp_fpcr;
	uint32_t	vfp_fpsr;
};

#ifdef _KERNEL
struct pcb;
struct thread;

void	vfp_init_secondary(void);
void	vfp_enable(void);
void	vfp_disable(void);
void	vfp_discard(struct thread *);
void	vfp_store(struct vfpstate *);
void	vfp_restore(struct vfpstate *);
void	vfp_new_thread(struct thread *, struct thread *, bool);
void	vfp_reset_state(struct thread *, struct pcb *);
void	vfp_restore_state(void);
void	vfp_save_state(struct thread *, struct pcb *);
void	vfp_save_state_savectx(struct pcb *);
void	vfp_save_state_switch(struct thread *);
void	vfp_to_sve_sync(struct thread *);
void	sve_to_vfp_sync(struct thread *);

size_t	sve_max_buf_size(void);
size_t	sve_buf_size(struct thread *);
bool	sve_restore_state(struct thread *);

struct fpu_kern_ctx;

/*
 * Flags for fpu_kern_alloc_ctx(), fpu_kern_enter() and fpu_kern_thread().
 */
#define	FPU_KERN_NORMAL	0x0000
#define	FPU_KERN_NOWAIT	0x0001
#define	FPU_KERN_KTHR	0x0002
#define	FPU_KERN_NOCTX	0x0004

struct fpu_kern_ctx *fpu_kern_alloc_ctx(u_int);
void fpu_kern_free_ctx(struct fpu_kern_ctx *);
void fpu_kern_enter(struct thread *, struct fpu_kern_ctx *, u_int);
int fpu_kern_leave(struct thread *, struct fpu_kern_ctx *);
int fpu_kern_thread(u_int);
int is_fpu_kern_thread(u_int);

struct vfpstate *fpu_save_area_alloc(void);
void fpu_save_area_free(struct vfpstate *fsa);
void fpu_save_area_reset(struct vfpstate *fsa);

/* Convert to and from Aarch32 FPSCR to Aarch64 FPCR/FPSR */
#define VFP_FPSCR_FROM_SRCR(vpsr, vpcr) ((vpsr) | ((vpcr) & 0x7c00000))
#define VFP_FPSR_FROM_FPSCR(vpscr) ((vpscr) &~ 0x7c00000)
#define VFP_FPCR_FROM_FPSCR(vpsrc) ((vpsrc) & 0x7c00000)

#ifdef COMPAT_FREEBSD32
void get_fpcontext32(struct thread *td, mcontext32_vfp_t *mcp);
void set_fpcontext32(struct thread *td, mcontext32_vfp_t *mcp);
#endif

#endif

#endif

#endif /* !_MACHINE_VFP_H_ */

#endif /* !__arm__ */