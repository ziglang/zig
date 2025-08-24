/*	$NetBSD: callout.h,v 1.32 2015/02/07 19:36:42 christos Exp $	*/

/*-
 * Copyright (c) 2000, 2003, 2006, 2007, 2008 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center, and by Andrew Doran.
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

#ifndef _SYS_CALLOUT_H_
#define _SYS_CALLOUT_H_

#include <sys/types.h>

/*
 * The callout implementation is private to kern_timeout.c yet uses
 * caller-supplied storage, as lightweight callout operations are
 * critical to system performance.
 *
 * The size of callout_t must remain constant in order to ensure ABI
 * compatibility for kernel modules: it may become smaller, but must
 * not grow.  If more space is required, rearrange the members of
 * callout_impl_t.
 */
typedef struct callout {
	void	*_c_store[10];
} callout_t;

/* Internal flags. */
#define	CALLOUT_BOUND		0x0001	/* bound to a specific CPU */
#define	CALLOUT_PENDING		0x0002	/* callout is on the queue */
#define	CALLOUT_FIRED		0x0004	/* callout has fired */
#define	CALLOUT_INVOKING	0x0008	/* callout function is being invoked */

/* End-user flags. */
#define	CALLOUT_MPSAFE		0x0100	/* does not need kernel_lock */
#define	CALLOUT_FLAGMASK	0xff00

#define CALLOUT_FMT	"\177\020\
b\00BOUND\0\
b\01PENDING\0\
b\02FIRED\0\
b\03INVOKING\0\
b\10MPSAFE\0"

#ifdef _CALLOUT_PRIVATE

/* The following funkyness is to appease gcc3's strict aliasing. */
struct callout_circq {
	/* next element */
	union {
		struct callout_impl	*elem;
		struct callout_circq	*list;
	} cq_next;
	/* previous element */
	union {
		struct callout_impl	*elem;
		struct callout_circq	*list;
	} cq_prev;
};
#define	cq_next_e	cq_next.elem
#define	cq_prev_e	cq_prev.elem
#define	cq_next_l	cq_next.list
#define	cq_prev_l	cq_prev.list

struct callout_cpu;

typedef struct callout_impl {
	struct callout_circq c_list;		/* linkage on queue */
	void	(*c_func)(void *);		/* function to call */
	void	*c_arg;				/* function argument */
	struct callout_cpu * volatile c_cpu;	/* associated CPU */
	int	c_time;				/* when callout fires */
	u_int	c_flags;			/* state of this entry */
	u_int	c_magic;			/* magic number */
} callout_impl_t;
#define	CALLOUT_MAGIC		0x11deeba1

#endif	/* _CALLOUT_PRIVATE */

#ifdef _KERNEL
struct cpu_info;

void	callout_startup(void);
void	callout_init_cpu(struct cpu_info *);
void	callout_hardclock(void);

void	callout_init(callout_t *, u_int);
void	callout_destroy(callout_t *);
void	callout_setfunc(callout_t *, void (*)(void *), void *);
void	callout_reset(callout_t *, int, void (*)(void *), void *);
void	callout_schedule(callout_t *, int);
bool	callout_stop(callout_t *);
bool	callout_halt(callout_t *, void *);
bool	callout_pending(callout_t *);
bool	callout_expired(callout_t *);
bool	callout_active(callout_t *);
bool	callout_invoking(callout_t *);
void	callout_ack(callout_t *);
void	callout_bind(callout_t *, struct cpu_info *);
#endif	/* _KERNEL */

#endif /* !_SYS_CALLOUT_H_ */