/*	$NetBSD: psref.h,v 1.4 2019/05/17 03:34:27 ozaki-r Exp $	*/

/*-
 * Copyright (c) 2016 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Taylor R. Campbell.
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

#ifndef	_SYS_PSREF_H
#define	_SYS_PSREF_H

#ifdef _KERNEL_OPT
#include "opt_psref_debug.h"
#endif

#include <sys/types.h>
#include <sys/queue.h>

struct cpu_info;
struct lwp;

struct psref;
struct psref_class;
struct psref_target;

/*
 * struct psref_target
 *
 *	Bookkeeping for an object to which users can acquire passive
 *	references.  This is compact so that it can easily be embedded
 *	into many multitudes of objects, e.g. IP packet flows.
 *
 *	prt_draining is false on initialization, and may be written
 *	only once, to make it true, when someone has prevented new
 *	references from being created and wants to drain the target in
 *	order to destroy it.
 */
struct psref_target {
	struct psref_class	*prt_class;
	bool			prt_draining;
};

/*
 * struct psref
 *
 *	Bookkeeping for a single passive reference.  There should only
 *	be a few of these per CPU in the system at once, no matter how
 *	many targets are stored, so these are a bit larger than struct
 *	psref_target.  The contents of struct psref may be read and
 *	written only on the local CPU.
 */
struct psref {
	SLIST_ENTRY(psref)		psref_entry;
	void				*psref_debug; /* For debugging */
	const struct psref_target	*psref_target;
	struct lwp			*psref_lwp;
	struct cpu_info			*psref_cpu;
};

#ifdef _KERNEL
void	psref_init(void);

struct psref_class *
	psref_class_create(const char *, int);
void	psref_class_destroy(struct psref_class *);

void	psref_target_init(struct psref_target *, struct psref_class *);
void	psref_target_destroy(struct psref_target *, struct psref_class *);

void	psref_acquire(struct psref *, const struct psref_target *,
	    struct psref_class *);
void	psref_release(struct psref *, const struct psref_target *,
	    struct psref_class *);
void	psref_copy(struct psref *, const struct psref *,
	    struct psref_class *);

/* For use only in assertions.  */
bool	psref_held(const struct psref_target *, struct psref_class *);


#ifdef PSREF_DEBUG
void	psref_debug_barrier(void);
void	psref_debug_init_lwp(struct lwp *);

#define PSREF_DEBUG_BARRIER()		psref_debug_barrier()
#define PSREF_DEBUG_INIT_LWP(l)		psref_debug_init_lwp((l))
#define PSREF_DEBUG_FILL_RETURN_ADDRESS0(psref, addr)	do {		\
	(psref)->psref_debug = (addr);					\
} while (0)
#define PSREF_DEBUG_FILL_RETURN_ADDRESS(psref)	do {			\
	PSREF_DEBUG_FILL_RETURN_ADDRESS0(psref, __builtin_return_address(0));\
} while (0)

#else

#define PSREF_DEBUG_BARRIER()		__nothing
#define PSREF_DEBUG_INIT_LWP(l)		__nothing
#define PSREF_DEBUG_FILL_RETURN_ADDRESS0(psref, addr)	__nothing
#define PSREF_DEBUG_FILL_RETURN_ADDRESS(psref)		__nothing

#endif /* PSREF_DEBUG */

#endif /* _KERNEL */

#endif	/* _SYS_PSREF_H */