/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *	@(#)callout.h	8.2 (Berkeley) 1/21/94
 */

#ifndef _SYS__CALLOUT_H
#define	_SYS__CALLOUT_H

#include <sys/_types.h>
#include <sys/queue.h>

struct lock_object;

LIST_HEAD(callout_list, callout);
SLIST_HEAD(callout_slist, callout);
TAILQ_HEAD(callout_tailq, callout);

typedef void callout_func_t(void *);

struct callout {
	union {
		LIST_ENTRY(callout) le;
		SLIST_ENTRY(callout) sle;
		TAILQ_ENTRY(callout) tqe;
	} c_links;
	__sbintime_t c_time;			/* ticks to the event */
	__sbintime_t c_precision;		/* delta allowed wrt opt */
	void	*c_arg;				/* function argument */
	callout_func_t *c_func;			/* function to call */
	struct lock_object *c_lock;		/* lock to handle */
	short	c_flags;			/* User State */
	short	c_iflags;			/* Internal State */
	volatile int c_cpu;			/* CPU we're scheduled on */
};

#endif