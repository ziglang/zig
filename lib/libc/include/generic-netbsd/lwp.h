/*	$NetBSD: lwp.h,v 1.13 2017/12/08 01:19:29 christos Exp $	*/

/*-
 * Copyright (c) 2000 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Nathan Williams.
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

#ifndef _LWP_H_
#define _LWP_H_

#include <sys/cdefs.h>
#include <sys/types.h>
#include <sys/ucontext.h>
#include <sys/time.h>

struct lwpctl;

__BEGIN_DECLS
lwpid_t	_lwp_self(void);
int	_lwp_create(const ucontext_t *, unsigned  long, lwpid_t *);
int	_lwp_exit(void);
int	_lwp_wait(lwpid_t, lwpid_t *);
int	_lwp_suspend(lwpid_t);
int	_lwp_continue(lwpid_t);
int	_lwp_wakeup(lwpid_t);
void	_lwp_makecontext(ucontext_t *, void (*)(void *), void *, void *, 
	    caddr_t, size_t);
void	*_lwp_getprivate(void);
void	_lwp_setprivate(void *);
int	_lwp_kill(lwpid_t, int);
int	_lwp_detach(lwpid_t);
#ifndef __LIBC12_SOURCE__
int	_lwp_park(clockid_t, int, struct timespec *, lwpid_t,
    const void *, const void *) __RENAME(___lwp_park60);
#endif
int	_lwp_unpark(lwpid_t, const void *);
ssize_t	_lwp_unpark_all(const lwpid_t *, size_t, const void *);
int	_lwp_setname(lwpid_t, const char *);
int	_lwp_getname(lwpid_t, char *, size_t);
int	_lwp_ctl(int, struct lwpctl **);
__END_DECLS

#endif /* !_LWP_H_ */