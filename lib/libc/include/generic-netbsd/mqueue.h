/*	$NetBSD: mqueue.h,v 1.4 2009/01/11 03:04:12 christos Exp $	*/

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

#ifndef _MQUEUE_H_
#define _MQUEUE_H_

#include <fcntl.h>
#include <signal.h>
#include <time.h>

#include <sys/cdefs.h>
#include <sys/types.h>

#include <sys/mqueue.h>

__BEGIN_DECLS
int	mq_close(mqd_t);
int	mq_getattr(mqd_t, struct mq_attr *);
int	mq_notify(mqd_t, const struct sigevent *);
mqd_t	mq_open(const char *, int, ...);
ssize_t	mq_receive(mqd_t, char *, size_t, unsigned *);
int	mq_send(mqd_t, const char *, size_t, unsigned);
int	mq_setattr(mqd_t, const struct mq_attr * __restrict,
		    struct mq_attr * __restrict);
#ifndef __LIBC12_SOURCE__
ssize_t	mq_timedreceive(mqd_t, char * __restrict, size_t,
    unsigned * __restrict, const struct timespec * __restrict)
    __RENAME(__mq_timedreceive50);
int	mq_timedsend(mqd_t, const char *, size_t, unsigned,
    const struct timespec *) __RENAME(__mq_timedsend50);
#endif
int	mq_unlink(const char *);
__END_DECLS

#endif	/* _MQUEUE_H_ */