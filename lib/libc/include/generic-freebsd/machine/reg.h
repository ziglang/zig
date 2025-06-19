/* $NetBSD: reg.h,v 1.4 2000/06/04 09:30:44 tsubai Exp $	*/

#ifndef _POWERPC_REG_H_
#define	_POWERPC_REG_H_

#include <sys/_types.h>

/* Must match struct trapframe */
struct reg {
	__register_t fixreg[32];
	__register_t lr;
	__register_t cr;
	__register_t xer;
	__register_t ctr;
	__register_t pc;
};

struct fpreg {
	double fpreg[32];
	double fpscr;
};

/* Must match pcb.pcb_vec */
struct vmxreg {
	__uint32_t vr[32][4];
	__uint32_t pad[2];
	__uint32_t vrsave;
	__uint32_t vscr;
};

struct dbreg {
	unsigned int	junk;
};

#ifdef __LP64__
/* Must match struct trapframe */
struct reg32 {
	__int32_t fixreg[32];
	__int32_t lr;
	__int32_t cr;
	__int32_t xer;
	__int32_t ctr;
	__int32_t pc;
};

struct fpreg32 {
	struct fpreg data;
};

struct vmxreg32 {
	struct vmxreg data;
};

struct dbreg32 {
	struct dbreg data;
};

#define __HAVE_REG32
#endif

#ifdef _KERNEL
/*
 * XXX these interfaces are MI, so they should be declared in a MI place.
 */
int	fill_regs(struct thread *, struct reg *);
int	set_regs(struct thread *, struct reg *);
int	fill_fpregs(struct thread *, struct fpreg *);
int	set_fpregs(struct thread *, struct fpreg *);
int	fill_dbregs(struct thread *, struct dbreg *);
int	set_dbregs(struct thread *, struct dbreg *);

/*
 * MD interfaces.
 */
void	cpu_save_thread_regs(struct thread *);

#ifdef COMPAT_FREEBSD32
struct image_params;

int	fill_regs32(struct thread *, struct reg32 *);
int	set_regs32(struct thread *, struct reg32 *);
void	ppc32_setregs(struct thread *, struct image_params *, uintptr_t);

#define	fill_fpregs32(td, reg)	fill_fpregs(td,(struct fpreg *)reg)
#define	set_fpregs32(td, reg)	set_fpregs(td,(struct fpreg *)reg)
#define	fill_dbregs32(td, reg)	fill_dbregs(td,(struct dbreg *)reg)
#define	set_dbregs32(td, reg)	set_dbregs(td,(struct dbreg *)reg)
#endif

#endif

#endif /* _POWERPC_REG_H_ */