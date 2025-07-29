/*	$NetBSD: resourcevar.h,v 1.57.32.1 2024/10/11 17:12:28 martin Exp $	*/

/*
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)resourcevar.h	8.4 (Berkeley) 1/9/95
 */

#ifndef	_SYS_RESOURCEVAR_H_
#define	_SYS_RESOURCEVAR_H_

#if !defined(_KERNEL) && !defined(_KMEMUSER)
#error "not supposed to be exposed to userland"
#endif

#include <sys/mutex.h>
#include <sys/resource.h>

struct bintime;

/*
 * Kernel per-process accounting / statistics
 */
struct uprof {				/* profile arguments */
	char *	pr_base;		/* buffer base */
	size_t  pr_size;		/* buffer size */
	u_long	pr_off;			/* pc offset */
	u_int   pr_scale;		/* pc scaling */
	u_long	pr_addr;		/* temp storage for addr until AST */
	u_long	pr_ticks;		/* temp storage for ticks until AST */
};

struct pstats {
#define	pstat_startzero	p_ru
	struct	rusage p_ru;		/* stats for this proc */
	struct	rusage p_cru;		/* sum of stats for reaped children */
#define	pstat_endzero	pstat_startcopy

#define	pstat_startcopy	p_timer
	struct	itimerspec p_timer[3];	/* virtual-time timers */
	struct	uprof p_prof;			/* profile arguments */
#define	pstat_endcopy	p_start
	struct	timeval p_start;	/* starting time */
};

#ifdef _KERNEL

/*
 * Process resource limits.  Since this structure is moderately large,
 * but changes infrequently, it is shared copy-on-write after forks.
 *
 * When a separate copy is created, then 'pl_writeable' is set to true,
 * and 'pl_sv_limit' is pointed to the old proc_t::p_limit structure.
 */
struct plimit {
	struct rlimit	pl_rlimit[RLIM_NLIMITS];
	char *		pl_corename;
	size_t		pl_cnlen;
	u_int		pl_refcnt;
	bool		pl_writeable;
	kmutex_t	pl_lock;
	struct plimit *	pl_sv_limit;
};

/* add user profiling from AST XXXSMP */
#define	ADDUPROF(l)							\
	do {								\
		struct proc *_p = (l)->l_proc;				\
		addupc_task((l),					\
		    _p->p_stats->p_prof.pr_addr,			\
		    _p->p_stats->p_prof.pr_ticks);			\
		_p->p_stats->p_prof.pr_ticks = 0;			\
	} while (/* CONSTCOND */ 0)

extern char defcorename[];

extern int security_setidcore_dump;
extern char security_setidcore_path[];
extern uid_t security_setidcore_owner;
extern gid_t security_setidcore_group;
extern mode_t security_setidcore_mode;

void	addupc_intr(struct lwp *, u_long);
void	addupc_task(struct lwp *, u_long, u_int);
void	calcru(struct proc *, struct timeval *, struct timeval *,
	    struct timeval *, struct timeval *);
void	addrulwp(struct lwp *, struct bintime *);

struct plimit *lim_copy(struct plimit *);
void	lim_addref(struct plimit *);
void	lim_privatise(struct proc *);
void	lim_setcorename(struct proc *, char *, size_t);
void	lim_free(struct plimit *);

void	resource_init(void);
void	ruspace(struct proc *);
void	ruadd(struct rusage *, struct rusage *);
void	rulwps(proc_t *, struct rusage *);
struct	pstats *pstatscopy(struct pstats *);
void	pstatsfree(struct pstats *);
extern rlim_t maxdmap;
extern rlim_t maxsmap;

int	getrusage1(struct proc *, int, struct rusage *);

#endif

#endif	/* !_SYS_RESOURCEVAR_H_ */