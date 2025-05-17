/*	$NetBSD: fpu.h,v 1.23 2020/10/24 07:14:29 mgorny Exp $	*/

#ifndef	_X86_FPU_H_
#define	_X86_FPU_H_

#include <x86/cpu_extended_state.h>

#ifdef _KERNEL

struct cpu_info;
struct lwp;
struct trapframe;

void fpuinit(struct cpu_info *);
void fpuinit_mxcsr_mask(void);

void fpu_area_save(void *, uint64_t, bool);
void fpu_area_restore(const void *, uint64_t, bool);

void fpu_save(void);

void fpu_set_default_cw(struct lwp *, unsigned int);

void fputrap(struct trapframe *);
void fpudna(struct trapframe *);

void process_xmm_to_s87(const struct fxsave *, struct save87 *);
void process_s87_to_xmm(const struct save87 *, struct fxsave *);

void fpu_clear(struct lwp *, unsigned int);
void fpu_sigreset(struct lwp *);

void fpu_lwp_fork(struct lwp *, struct lwp *);
void fpu_lwp_abandon(struct lwp *l);

void fpu_kern_enter(void);
void fpu_kern_leave(void);

void process_write_fpregs_xmm(struct lwp *, const struct fxsave *);
void process_write_fpregs_s87(struct lwp *, const struct save87 *);

void process_read_fpregs_xmm(struct lwp *, struct fxsave *);
void process_read_fpregs_s87(struct lwp *, struct save87 *);

int process_read_xstate(struct lwp *, struct xstate *);
int process_verify_xstate(const struct xstate *);
int process_write_xstate(struct lwp *, const struct xstate *);

#endif

#endif /* _X86_FPU_H_ */