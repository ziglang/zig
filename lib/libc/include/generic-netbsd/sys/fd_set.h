/*	$NetBSD: fd_set.h,v 1.7 2018/06/24 12:05:40 kamil Exp $	*/

/*-
 * Copyright (c) 1992, 1993
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
 *	from: @(#)types.h	8.4 (Berkeley) 1/21/94
 */

#ifndef _SYS_FD_SET_H_
#define	_SYS_FD_SET_H_

#include <sys/cdefs.h>
#include <sys/featuretest.h>
#include <machine/int_types.h>

/*
 * Implementation dependent defines, hidden from user space.
 * POSIX does not specify them.
 */

typedef	__uint32_t	__fd_mask;

/* 32 = 2 ^ 5 */
#define	__NFDBITS	(32)
#define	__NFDSHIFT	(5)
#define	__NFDMASK	(__NFDBITS - 1)

/*
 * Select uses bit fields of file descriptors.  These macros manipulate
 * such bit fields.  Note: FD_SETSIZE may be defined by the user.
 */

#ifndef	FD_SETSIZE
#define	FD_SETSIZE	256
#endif

#define	__NFD_LEN(a)	(((a) + (__NFDBITS - 1)) / __NFDBITS)
#define	__NFD_SIZE	__NFD_LEN(FD_SETSIZE)
#define	__NFD_BYTES(a)	(__NFD_LEN(a) * sizeof(__fd_mask))

typedef	struct fd_set {
	__fd_mask	fds_bits[__NFD_SIZE];
} fd_set;

#define	FD_SET(n, p)	\
    ((p)->fds_bits[(unsigned)(n) >> __NFDSHIFT] |= (1U << ((n) & __NFDMASK)))
#define	FD_CLR(n, p)	\
    ((p)->fds_bits[(unsigned)(n) >> __NFDSHIFT] &= ~(1U << ((n) & __NFDMASK)))
#define	FD_ISSET(n, p)	\
    ((p)->fds_bits[(unsigned)(n) >> __NFDSHIFT] & (1U << ((n) & __NFDMASK)))
#if __GNUC_PREREQ__(2, 95)
#define	FD_ZERO(p)	(void)__builtin_memset((p), 0, sizeof(*(p)))
#else
#define	FD_ZERO(p)	do {						\
	fd_set *__fds = (p);						\
	unsigned int __i;						\
	for (__i = 0; __i < __NFD_SIZE; __i++)				\
		__fds->fds_bits[__i] = 0;				\
	} while (/* CONSTCOND */ 0)
#endif /* GCC 2.95 */

/*
 * Expose our internals if we are not required to hide them.
 */
#if defined(_NETBSD_SOURCE)

#define	fd_mask		__fd_mask
#define	NFDBITS		__NFDBITS

#if __GNUC_PREREQ__(2, 95)
#define	FD_COPY(f, t)	(void)__builtin_memcpy((t), (f), sizeof(*(f)))
#else
#define	FD_COPY(f, t)	do {						\
	fd_set *__f = (f), *__t = (t);					\
	unsigned int __i;						\
	for (__i = 0; __i < __NFD_SIZE; __i++)				\
		__t->fds_bits[__i] = __f->fds_bits[__i];		\
	} while (/* CONSTCOND */ 0)
#endif /* GCC 2.95 */

#endif /* _NETBSD_SOURCE */

#endif /* _SYS_FD_SET_H_ */