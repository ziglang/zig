/*	$NetBSD: aio.h,v 1.7 2009/01/13 15:11:09 christos Exp $	*/

/*
 * Copyright (c) 2007, Mindaugas Rasiukevicius <rmind at NetBSD org>
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef	_AIO_H_
#define	_AIO_H_

#include <fcntl.h>
#include <signal.h>
#include <time.h>

#include <sys/cdefs.h>
#include <sys/signal.h>

#include <sys/aio.h>

__BEGIN_DECLS
int	aio_cancel(int, struct aiocb *);
int	aio_error(const struct aiocb *);
int	aio_fsync(int, struct aiocb *);
int	aio_read(struct aiocb *);
ssize_t	aio_return(struct aiocb *);
#ifndef __LIBC12_SOURCE__
int	aio_suspend(const struct aiocb * const [], int,
    const struct timespec *) __RENAME(__aio_suspend50);
#endif
int	aio_write(struct aiocb *);
int	lio_listio(int, struct aiocb * const * __restrict,
		    int, struct sigevent * __restrict);
__END_DECLS

#endif	/* _AIO_H_ */