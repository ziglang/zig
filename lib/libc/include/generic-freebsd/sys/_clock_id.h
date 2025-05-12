/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2021 Netflix, Inc.
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
 */

#ifndef _SYS_SYS__CLOCK_ID_H
#define	_SYS_SYS__CLOCK_ID_H

/*
 * These macros are shared between time.h and sys/time.h.
 */

/*
 * Note: The values shown below as a comment for the __POSIX_VISIBLE values are
 * the ones FreeBSD traditionally used based on our reading of the POSIX
 * standards. However, glibc uses 199309 for all of them, even those many were
 * not defined there. To remain bug compatible with glibc means more software
 * that relied on the glibc behavior will compile easily on FreeBSD.
 *
 * Also, CLOCK_UPTIME_FAST is improperly visible temporarily for the lang/pocl
 * port until it can be updated properly. It incorrectly assumes that this was a
 * standard value. It will be moved back to the __BSD_VISIBLE section once the
 * issue is corrected.
 */

#if __POSIX_VISIBLE >= 199309		/* 199506 */
#define CLOCK_REALTIME		0
#endif /* __POSIX_VISIBLE >= 199309 */
#ifdef __BSD_VISIBLE
#define CLOCK_VIRTUAL		1
#define CLOCK_PROF		2
#endif /* __BSD_VISIBLE */
#if __POSIX_VISIBLE >= 199309		/* 200112 */
#define CLOCK_MONOTONIC		4
#define CLOCK_UPTIME_FAST	8
#endif /* __POSIX_VISIBLE >= 199309 */
#ifdef __BSD_VISIBLE
/*
 * FreeBSD-specific clocks.
 */
#define CLOCK_UPTIME		5
#define CLOCK_UPTIME_PRECISE	7
#define CLOCK_REALTIME_PRECISE	9
#define CLOCK_REALTIME_FAST	10
#define CLOCK_MONOTONIC_PRECISE	11
#define CLOCK_MONOTONIC_FAST	12
#define CLOCK_SECOND		13
#endif /* __BSD_VISIBLE */

#if __POSIX_VISIBLE >= 199309		/* 200112 */
#define CLOCK_THREAD_CPUTIME_ID	14
#define	CLOCK_PROCESS_CPUTIME_ID 15
#endif /* __POSIX_VISIBLE >= 199309 */

/*
 * Linux compatible names.
 */
#if __BSD_VISIBLE
#define	CLOCK_BOOTTIME		CLOCK_UPTIME
#define	CLOCK_REALTIME_COARSE	CLOCK_REALTIME_FAST
#define	CLOCK_MONOTONIC_COARSE	CLOCK_MONOTONIC_FAST
#endif

#if __BSD_VISIBLE
#define TIMER_RELTIME	0x0	/* relative timer */
#endif
#if __POSIX_VISIBLE >= 199309
#define TIMER_ABSTIME	0x1	/* absolute timer */
#endif /* __POSIX_VISIBLE >= 199309 */

#endif /* _SYS_SYS__CLOCK_ID_H */