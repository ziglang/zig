/*	$NetBSD: sched.h,v 1.15 2022/08/01 15:16:05 wiz Exp $	*/

/*-
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Nathan J. Williams.
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

#ifndef _SCHED_H_
#define _SCHED_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <sys/sched.h>

/* Required by POSIX 1003.1, section 13.1, lines 12-13. */
#include <time.h>

__BEGIN_DECLS
int	sched_setparam(pid_t, const struct sched_param *);
int	sched_getparam(pid_t, struct sched_param *);
int	sched_setscheduler(pid_t, int, const struct sched_param *);
int	sched_getscheduler(pid_t);
int	sched_get_priority_max(int);
int	sched_get_priority_min(int);
#ifndef __LIBC12_SOURCE__
int	sched_rr_get_interval(pid_t, struct timespec *)
    __RENAME(__sched_rr_get_interval50);
#endif

int	sched_yield(void);
int	__libc_thr_yield(void);
__END_DECLS

#ifndef __LIBPTHREAD_SOURCE__
#define sched_yield		__libc_thr_yield
#endif /* __LIBPTHREAD_SOURCE__ */

__BEGIN_DECLS

#if defined(_NETBSD_SOURCE)

/* Process affinity functions (not portable) */
int	sched_getaffinity_np(pid_t, size_t, cpuset_t *);
int	sched_setaffinity_np(pid_t, size_t, cpuset_t *);

#endif /* _NETBSD_SOURCE */

#if defined(_GNU_SOURCE)

/*
 * Historical functions, not defined in standard
 * Linux man page documents clone() as only available when
 * _GNU_SOURCE is defined
 */
pid_t	 clone(int (*)(void *), void *, int, void *);
#endif /* _GNU_SOURCE */

#if defined(_NETBSD_SOURCE)

pid_t	__clone(int (*)(void *), void *, int, void *);

#endif /* _NETBSD_SOURCE */

__END_DECLS

#endif /* _SCHED_H_ */