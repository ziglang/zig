/*	$NetBSD: uio.h,v 1.36 2011/07/27 13:20:07 uebayasi Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1993, 1994
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
 *	@(#)uio.h	8.5 (Berkeley) 2/22/94
 */

#ifndef _SYS_UIO_H_
#define	_SYS_UIO_H_

#ifdef _KERNEL
#ifndef __UIO_EXPOSE
#define __UIO_EXPOSE
#endif
#endif

#include <machine/ansi.h>
#include <sys/featuretest.h>

#ifdef	_BSD_SIZE_T_
typedef	_BSD_SIZE_T_	size_t;
#undef	_BSD_SIZE_T_
#endif

#ifdef	_BSD_SSIZE_T_
typedef	_BSD_SSIZE_T_	ssize_t;
#undef	_BSD_SSIZE_T_
#endif

struct iovec {
	void	*iov_base;	/* Base address. */
	size_t	 iov_len;	/* Length. */
};

#if defined(_NETBSD_SOURCE)
#include <sys/ansi.h>

#ifndef	off_t
typedef	__off_t		off_t;	/* file offset */
#define	off_t		__off_t
#endif

enum	uio_rw { UIO_READ, UIO_WRITE };

/* Segment flag values. */
enum uio_seg {
	UIO_USERSPACE,		/* from user data space */
	UIO_SYSSPACE		/* from system space */
};

#ifdef __UIO_EXPOSE

struct vmspace;

struct uio {
	struct	iovec *uio_iov;	/* pointer to array of iovecs */
	int	uio_iovcnt;	/* number of iovecs in array */
	off_t	uio_offset;	/* offset into file this uio corresponds to */
	size_t	uio_resid;	/* residual i/o count */
	enum	uio_rw uio_rw;	/* see above */
	struct	vmspace *uio_vmspace;
};
#define	UIO_SETUP_SYSSPACE(uio)	uio_setup_sysspace(uio)

#endif /* __UIO_EXPOSE */

/*
 * Limits
 */
/* Deprecated: use IOV_MAX from <limits.h> instead. */
#define UIO_MAXIOV	1024		/* max 1K of iov's */
#endif /* _NETBSD_SOURCE */

#ifdef _KERNEL

/* 8 on stack, more will be dynamically allocated. */
#define UIO_SMALLIOV	8

void uio_setup_sysspace(struct uio *);
#endif

#ifndef	_KERNEL
#include <sys/cdefs.h>

__BEGIN_DECLS
#if defined(_NETBSD_SOURCE)
ssize_t preadv(int, const struct iovec *, int, off_t);
ssize_t pwritev(int, const struct iovec *, int, off_t);
#endif /* _NETBSD_SOURCE */
ssize_t	readv(int, const struct iovec *, int);
ssize_t	writev(int, const struct iovec *, int);
__END_DECLS
#else
int ureadc(int, struct uio *);
#endif /* !_KERNEL */

#endif /* !_SYS_UIO_H_ */