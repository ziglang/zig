/* $NetBSD: semaphore.h,v 1.5 2016/04/24 19:48:29 dholland Exp $ */

/*-
 * Copyright (c) 2003 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Christos Zoulas.
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

#ifndef _SEMAPHORE_H_
#define _SEMAPHORE_H_

/* POSIX 1003.1b semaphores */

struct _sem_st;
typedef	struct _sem_st *sem_t;

#define	SEM_FAILED	((sem_t *)0)

#include <sys/semaphore.h> /* some kernel-only bits */
#include <sys/time.h>

__BEGIN_DECLS
int	 sem_close(sem_t *);
int	 sem_destroy(sem_t *);
int	 sem_getvalue(sem_t * __restrict, int * __restrict);
int	 sem_init(sem_t *, int, unsigned int);
int	 sem_post(sem_t *);
int	 sem_timedwait(sem_t *, const struct timespec * __restrict);
int	 sem_trywait(sem_t *);
int	 sem_unlink(const char *);
int	 sem_wait(sem_t *);
sem_t	*sem_open(const char *, int, ...);
__END_DECLS

#endif /* !_SEMAPHORE_H_ */