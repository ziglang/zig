/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2008,	Jeffrey Roberson <jeff@freebsd.org>
 * All rights reserved.
 *
 * Copyright (c) 2008 Nokia Corporation
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
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

#ifndef _SYS_CPUSET_H_
#define	_SYS_CPUSET_H_

#include <sys/_cpuset.h>

#include <sys/_bitset.h>
#include <sys/bitset.h>

#define	_NCPUBITS	_BITSET_BITS
#define	_NCPUWORDS	__bitset_words(CPU_SETSIZE)

#define	CPUSETBUFSIZ	((2 + sizeof(long) * 2) * _NCPUWORDS)

#define	CPU_CLR(n, p)			__BIT_CLR(CPU_SETSIZE, n, p)
#define	CPU_COPY(f, t)			__BIT_COPY(CPU_SETSIZE, f, t)
#define	CPU_ISSET(n, p)			__BIT_ISSET(CPU_SETSIZE, n, p)
#define	CPU_SET(n, p)			__BIT_SET(CPU_SETSIZE, n, p)
#define	CPU_ZERO(p) 			__BIT_ZERO(CPU_SETSIZE, p)
#define	CPU_FILL(p) 			__BIT_FILL(CPU_SETSIZE, p)
#define	CPU_SETOF(n, p)			__BIT_SETOF(CPU_SETSIZE, n, p)
#define	CPU_EQUAL(p, c)			(__BIT_CMP(CPU_SETSIZE, p, c) == 0)
#define	CPU_EMPTY(p)			__BIT_EMPTY(CPU_SETSIZE, p)
#define	CPU_ISFULLSET(p)		__BIT_ISFULLSET(CPU_SETSIZE, p)
#define	CPU_SUBSET(p, c)		__BIT_SUBSET(CPU_SETSIZE, p, c)
#define	CPU_OVERLAP(p, c)		__BIT_OVERLAP(CPU_SETSIZE, p, c)
#define	CPU_CMP(p, c)			__BIT_CMP(CPU_SETSIZE, p, c)
#define	CPU_OR(d, s1, s2)		__BIT_OR2(CPU_SETSIZE, d, s1, s2)
#define	CPU_ORNOT(d, s1, s2)		__BIT_ORNOT2(CPU_SETSIZE, d, s1, s2)
#define	CPU_AND(d, s1, s2)		__BIT_AND2(CPU_SETSIZE, d, s1, s2)
#define	CPU_ANDNOT(d, s1, s2)		__BIT_ANDNOT2(CPU_SETSIZE, d, s1, s2)
#define	CPU_XOR(d, s1, s2)		__BIT_XOR2(CPU_SETSIZE, d, s1, s2)
#define	CPU_CLR_ATOMIC(n, p)		__BIT_CLR_ATOMIC(CPU_SETSIZE, n, p)
#define	CPU_SET_ATOMIC(n, p)		__BIT_SET_ATOMIC(CPU_SETSIZE, n, p)
#define	CPU_SET_ATOMIC_ACQ(n, p)	__BIT_SET_ATOMIC_ACQ(CPU_SETSIZE, n, p)
#define	CPU_AND_ATOMIC(n, p)		__BIT_AND_ATOMIC(CPU_SETSIZE, n, p)
#define	CPU_OR_ATOMIC(d, s)		__BIT_OR_ATOMIC(CPU_SETSIZE, d, s)
#define	CPU_COPY_STORE_REL(f, t)	__BIT_COPY_STORE_REL(CPU_SETSIZE, f, t)
#define	CPU_FFS(p)			__BIT_FFS(CPU_SETSIZE, p)
#define	CPU_FLS(p)			__BIT_FLS(CPU_SETSIZE, p)
#define	CPU_FOREACH_ISSET(i, p)		__BIT_FOREACH_ISSET(CPU_SETSIZE, i, p)
#define	CPU_FOREACH_ISCLR(i, p)		__BIT_FOREACH_ISCLR(CPU_SETSIZE, i, p)
#define	CPU_COUNT(p)			((int)__BIT_COUNT(CPU_SETSIZE, p))
#define	CPUSET_FSET			__BITSET_FSET(_NCPUWORDS)
#define	CPUSET_T_INITIALIZER(x)		__BITSET_T_INITIALIZER(x)

#define CPU_ALLOC_SIZE(_s)		__BITSET_SIZE(_s)
#define CPU_ALLOC(_s)			__cpuset_alloc(_s)
#define CPU_FREE(p)			__cpuset_free(p)

#define CPU_ISSET_S(n, _s, p)		__BIT_ISSET((_s) * 8, n, p)
#define CPU_SET_S(n, _s, p)		__BIT_SET((_s) * 8, n, p)
#define CPU_CLR_S(n, _s, p)		__BIT_CLR((_s) * 8, n, p)
#define CPU_ZERO_S(_s, p)		__BIT_ZERO((_s) * 8, p)

#define	CPU_OR_S(_s, d, s1, s2)		__BIT_OR2((_s) * 8, d, s1, s2)
#define	CPU_AND_S(_s, d, s1, s2)	__BIT_AND2((_s) * 8, d, s1, s2)
#define	CPU_XOR_S(_s, d, s1, s2)	__BIT_XOR2((_s) * 8, d, s1, s2)

#define	CPU_COUNT_S(_s, p)		((int)__BIT_COUNT((_s) * 8, p))
#define	CPU_EQUAL_S(_s, p, c)		(__BIT_CMP((_s) * 8, p, c) == 0)

/*
 * Valid cpulevel_t values.
 */
#define	CPU_LEVEL_ROOT		1	/* All system cpus. */
#define	CPU_LEVEL_CPUSET	2	/* Available cpus for which. */
#define	CPU_LEVEL_WHICH		3	/* Actual mask/id for which. */

/*
 * Valid cpuwhich_t values.
 */
#define	CPU_WHICH_TID		1	/* Specifies a thread id. */
#define	CPU_WHICH_PID		2	/* Specifies a process id. */
#define	CPU_WHICH_CPUSET	3	/* Specifies a set id. */
#define	CPU_WHICH_IRQ		4	/* Specifies an irq #. */
#define	CPU_WHICH_JAIL		5	/* Specifies a jail id. */
#define	CPU_WHICH_DOMAIN	6	/* Specifies a NUMA domain id. */
#define	CPU_WHICH_INTRHANDLER	7	/* Specifies an irq # (not ithread). */
#define	CPU_WHICH_ITHREAD	8	/* Specifies an irq's ithread. */
#define	CPU_WHICH_TIDPID	9	/* Specifies a process or thread id. */

/*
 * Reserved cpuset identifiers.
 */
#define	CPUSET_INVALID	-1
#define	CPUSET_DEFAULT	0

#ifdef _KERNEL
#include <sys/queue.h>

LIST_HEAD(setlist, cpuset);
extern u_int cpusetsizemin;

/*
 * cpusets encapsulate cpu binding information for one or more threads.
 *
 * 	a - Accessed with atomics.
 *	s - Set at creation, never modified.  Only a ref required to read.
 *	c - Locked internally by a cpuset lock.
 *
 * The bitmask is only modified while holding the cpuset lock.  It may be
 * read while only a reference is held but the consumer must be prepared
 * to deal with inconsistent results.
 */
struct cpuset {
	volatile u_int		cs_ref;		/* (a) Reference count. */
	int			cs_flags;	/* (s) Flags from below. */
	LIST_ENTRY(cpuset)	cs_link;	/* (c) All identified sets. */
	LIST_ENTRY(cpuset)	cs_siblings;	/* (c) Sibling set link. */
	struct setlist		cs_children;	/* (c) List of children. */
	struct domainset	*cs_domain;	/* (c) NUMA policy. */
	cpusetid_t		cs_id;		/* (s) Id or INVALID. */
	struct cpuset		*cs_parent;	/* (s) Pointer to our parent. */
	cpuset_t		cs_mask;	/* bitmask of valid cpus. */
};

#define CPU_SET_ROOT    0x0001  /* Set is a root set. */
#define CPU_SET_RDONLY  0x0002  /* No modification allowed. */

extern cpuset_t *cpuset_root;
struct prison;
struct proc;
struct thread;

/*
 * Callbacks for copying in/out a cpuset or domainset.  Used for alternate
 * ABIs, like compat32.
 */
struct cpuset_copy_cb {
	int (*cpuset_copyin)(const void *, void *, size_t);
	int (*cpuset_copyout)(const void *, void *, size_t);
};

struct cpuset *cpuset_thread0(void);
struct cpuset *cpuset_ref(struct cpuset *);
void	cpuset_rel(struct cpuset *);
int	cpuset_setthread(lwpid_t id, cpuset_t *);
int	cpuset_setithread(lwpid_t id, int cpu);
int	cpuset_create_root(struct prison *, struct cpuset **);
int	cpuset_setproc_update_set(struct proc *, struct cpuset *);
int	cpuset_which(cpuwhich_t, id_t, struct proc **,
	    struct thread **, struct cpuset **);
void	cpuset_kernthread(struct thread *);

char	*cpusetobj_strprint(char *, const cpuset_t *);
int	cpusetobj_strscan(cpuset_t *, const char *);
#ifdef DDB
void	ddb_display_cpuset(const cpuset_t *);
#endif

#else
__BEGIN_DECLS
int	cpuset(cpusetid_t *);
int	cpuset_setid(cpuwhich_t, id_t, cpusetid_t);
int	cpuset_getid(cpulevel_t, cpuwhich_t, id_t, cpusetid_t *);
int	cpuset_getaffinity(cpulevel_t, cpuwhich_t, id_t, size_t, cpuset_t *);
int	cpuset_setaffinity(cpulevel_t, cpuwhich_t, id_t, size_t, const cpuset_t *);
__END_DECLS
#endif
#endif /* !_SYS_CPUSET_H_ */