/*	$NetBSD: ptrace.h,v 1.26 2020/05/30 08:41:23 maxv Exp $	*/

/*
 * Copyright (c) 2001 Wasabi Systems, Inc.
 * All rights reserved.
 *
 * Written by Jason R. Thorpe for Wasabi Systems, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed for the NetBSD Project by
 *	Wasabi Systems, Inc.
 * 4. The name of Wasabi Systems, Inc. may not be used to endorse
 *    or promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY WASABI SYSTEMS, INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL WASABI SYSTEMS, INC
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copyright (c) 1993 Christopher G. Demetriou
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Christopher G. Demetriou.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _I386_PTRACE_H_
#define	_I386_PTRACE_H_

/*
 * i386-dependent ptrace definitions
 */
#define	PT_STEP		(PT_FIRSTMACH + 0)
#define	PT_GETREGS	(PT_FIRSTMACH + 1)
#define	PT_SETREGS	(PT_FIRSTMACH + 2)
#define	PT_GETFPREGS	(PT_FIRSTMACH + 3)
#define	PT_SETFPREGS	(PT_FIRSTMACH + 4)

/* We have machine-dependent process tracing needs. */
#define	__HAVE_PTRACE_MACHDEP

/* We have machine-dependent procfs nodes. */
#define	__HAVE_PROCFS_MACHDEP

/* The machine-dependent ptrace(2) requests. */
#define	PT_GETXMMREGS		(PT_FIRSTMACH + 5)
#define	PT_SETXMMREGS		(PT_FIRSTMACH + 6)
#define	PT_GETDBREGS		(PT_FIRSTMACH + 7)
#define	PT_SETDBREGS		(PT_FIRSTMACH + 8)
#define	PT_SETSTEP		(PT_FIRSTMACH + 9)
#define	PT_CLEARSTEP		(PT_FIRSTMACH + 10)
#define	PT_GETXSTATE		(PT_FIRSTMACH + 11)
#define	PT_SETXSTATE		(PT_FIRSTMACH + 12)

#define PT_MACHDEP_STRINGS \
	"PT_STEP", \
	"PT_GETREGS", \
	"PT_SETREGS", \
	"PT_GETFPREGS", \
	"PT_SETFPREGS", \
	"PT_GETXMMREGS", \
	"PT_SETXMMREGS", \
	"PT_GETDBREGS", \
	"PT_SETDBREGS", \
	"PT_SETSTEP", \
	"PT_CLEARSTEP", \
	"PT_GETXSTATE", \
	"PT_SETXSTATE"

#include <machine/reg.h>
#define PTRACE_REG_PC(r)	(r)->r_eip
#define PTRACE_REG_FP(r)	(r)->r_ebp
#define PTRACE_REG_SET_PC(r, v)	(r)->r_eip = (v)
#define PTRACE_REG_SP(r)	(r)->r_esp
#define PTRACE_REG_INTRV(r)	(r)->r_eax

#define PTRACE_ILLEGAL_ASM	__asm __volatile ("ud2" : : : "memory")

#define PTRACE_BREAKPOINT	((const uint8_t[]) { 0xcc })
#define PTRACE_BREAKPOINT_ASM	__asm __volatile ("int3" : : : "memory")
#define PTRACE_BREAKPOINT_SIZE	1
#define PTRACE_BREAKPOINT_ADJ	sizeof(PTRACE_BREAKPOINT)

#ifdef _KERNEL

/*
 * These are used in sys_ptrace() to find good ptrace(2) requests.
 */
#define	PTRACE_MACHDEP_REQUEST_CASES					\
	case PT_GETXMMREGS:						\
	case PT_SETXMMREGS:						\
	case PT_GETXSTATE:						\
	case PT_SETXSTATE:

/*
 * These are used to define machine-dependent procfs node types.
 */
#define	PROCFS_MACHDEP_NODE_TYPES					\
	Pmachdep_xmmregs,	/* extended FP register set */

/*
 * These are used in switch statements to catch machine-dependent
 * procfs node types.
 */
#define	PROCFS_MACHDEP_NODETYPE_CASES					\
	case Pmachdep_xmmregs:

/*
 * These are used to protect a privileged process's state.
 */
#define	PROCFS_MACHDEP_PROTECT_CASES					\
	case Pmachdep_xmmregs:

/*
 * These are used to define the machine-dependent procfs nodes.
 */
#define	PROCFS_MACHDEP_NODETYPE_DEFNS					\
	{ DT_REG, N("xmmregs"), Pmachdep_xmmregs,			\
	  procfs_machdep_validxmmregs },

#define PT32_GETXSTATE		PT_GETXSTATE
#define COREDUMP_MACHDEP_LWP_NOTES(l, ns, name)				\
{									\
	struct xstate xstate;						\
	memset(&xstate, 0, sizeof(xstate));				\
	if (!process_read_xstate(l, &xstate))				\
	{								\
		ELFNAMEEND(coredump_savenote)(ns,			\
		    CONCAT(CONCAT(PT, ELFSIZE), _GETXSTATE), name,	\
		    &xstate, sizeof(xstate));				\
	}								\
}

struct xmmregs;

/* Functions used by both ptrace(2) and procfs. */
int	process_machdep_doxmmregs(struct lwp *, struct lwp *, struct uio *);
int	process_machdep_validxmmregs(struct proc *);
int	process_machdep_doxstate(struct lwp *, struct lwp *, struct uio *);
int	process_machdep_validxstate(struct proc *);

/* Functions used by procfs. */
struct mount;
struct pfsnode;
int	procfs_machdep_doxmmregs(struct lwp *, struct lwp *,
	    struct pfsnode *, struct uio *);
int	procfs_machdep_validxmmregs(struct lwp *, struct mount *);

/*
 * The fpregs structure contains an fxsave area, which must have 16-byte
 * alignment.
 */
#define PTRACE_REGS_ALIGN __aligned(16)

#endif /* _KERNEL */

#endif /* _I386_PTRACE_H_ */