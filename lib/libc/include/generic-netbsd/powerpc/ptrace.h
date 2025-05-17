/*	$NetBSD: ptrace.h,v 1.19 2021/03/06 08:08:19 rin Exp $	*/

#ifndef _POWERPC_PTRACE_H
#define	_POWERPC_PTRACE_H

#define	PT_STEP		(PT_FIRSTMACH + 0)
#define	PT_GETREGS	(PT_FIRSTMACH + 1)
#define	PT_SETREGS	(PT_FIRSTMACH + 2)
#define	PT_GETFPREGS	(PT_FIRSTMACH + 3)
#define	PT_SETFPREGS	(PT_FIRSTMACH + 4)
#define	PT_GETVECREGS	(PT_FIRSTMACH + 5)
#define	PT_SETVECREGS	(PT_FIRSTMACH + 6)
#define	PT_SETSTEP	(PT_FIRSTMACH + 7)
#define	PT_CLEARSTEP	(PT_FIRSTMACH + 8)

#define	PT_MACHDEP_STRINGS				\
	"PT_STEP",					\
	"PT_GETREGS",		"PT_SETREGS",		\
	"PT_GETFPREGS",		"PT_SETFPREGS",		\
	"PT_GETVECREGS",	"PT_SETVECREGS",	\
	"PT_SETSTEP",		"PT_CLEARSTEP",

#include <machine/reg.h>
#define PTRACE_REG_PC(r)	(r)->pc
#define PTRACE_REG_FP(r)	(r)->fixreg[31]
#define PTRACE_REG_SET_PC(r, v)	(r)->pc = (v)
#define PTRACE_REG_SP(r)	(r)->fixreg[1]
#define PTRACE_REG_INTRV(r)	(r)->fixreg[3]

#ifdef _KERNEL
#ifdef _KERNEL_OPT
#include "opt_altivec.h"
#endif

#if defined(ALTIVEC) || defined(PPC_HAVE_SPE)

/* We have machine-dependent process tracing requests.  */
#define __HAVE_PTRACE_MACHDEP

#define	PTRACE_MACHDEP_REQUEST_CASES \
	case PT_GETVECREGS: \
	case PT_SETVECREGS:

int ptrace_machdep_dorequest(struct lwp *, struct lwp **, int, void *, int);
int process_machdep_dovecregs(struct lwp *, struct lwp *, struct uio *);
int process_machdep_validvecregs(struct proc *);

/* We have machine-dependent procfs nodes.  */
#define __HAVE_PROCFS_MACHDEP

#define	PROCFS_MACHDEP_NODE_TYPES \
	Pmachdep_vecregs,		/* AltiVec register set */

#define	PROCFS_MACHDEP_NODETYPE_CASES \
	case Pmachdep_vecregs:

#define	PROCFS_MACHDEP_PROTECT_CASES \
	case Pmachdep_vecregs:

#define	PROCFS_MACHDEP_NODETYPE_DEFNS \
	{ DT_REG, N("vecregs"), Pmachdep_vecregs, \
	  procfs_machdep_validvecregs },

/* Functions used by procfs.  */
struct mount;
struct pfsnode;
int procfs_machdep_dovecregs(struct lwp *, struct lwp *,
	struct pfsnode *, struct uio *);
int procfs_machdep_validvecregs(struct lwp *, struct mount *);

#endif /* ALTIVEC || PPC_HAVE_SPE */

#if defined(PPC_BOOKE) || defined(PPC_IBM4XX)
int ppc_sstep(struct lwp *, int);
#endif /* PPC_BOOKE || PPC_IBM4XX */
#endif /* _KERNEL */

#define PTRACE_ILLEGAL_ASM	__asm __volatile (".long 0" : : : "memory")

#define PTRACE_BREAKPOINT	((const uint8_t[]) { 0x7f, 0xe0, 0x00, 0x08 })
#define PTRACE_BREAKPOINT_ASM	__asm __volatile("trap")
#define PTRACE_BREAKPOINT_SIZE	4

#endif /* _POWERPC_PTRACE_H */