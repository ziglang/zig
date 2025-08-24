/*	$NetBSD: timerfd.h,v 1.3 2021/09/21 13:51:46 ryoon Exp $	*/

/*-
 * Copyright (c) 2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe.
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

#ifndef _SYS_TIMERFD_H_
#define	_SYS_TIMERFD_H_

#include <sys/fcntl.h>
#include <sys/ioccom.h>
#include <sys/time.h>

/*
 * Definitions for timerfd_create(2) / timerfd_gettime(2) / timerfd_settime(2).
 * This implementation is API compatible with the Linux interface.
 */

#define	TFD_TIMER_ABSTIME	O_WRONLY
#define	TFD_TIMER_CANCEL_ON_SET	O_RDWR
#define	TFD_CLOEXEC		O_CLOEXEC
#define	TFD_NONBLOCK		O_NONBLOCK

#define	TFD_IOC_SET_TICKS	_IOW('T', 0, uint64_t)

#ifdef _KERNEL
struct lwp;
int	do_timerfd_create(struct lwp *, clockid_t, int, register_t *);
int	do_timerfd_gettime(struct lwp *, int, struct itimerspec *,
	    register_t *);
int	do_timerfd_settime(struct lwp *, int, int, const struct itimerspec *,
	    struct itimerspec *, register_t *);
#else /* ! _KERNEL */
__BEGIN_DECLS
int	timerfd_create(clockid_t, int);
int	timerfd_gettime(int, struct itimerspec *);
int	timerfd_settime(int, int, const struct itimerspec *,
	    struct itimerspec *);
__END_DECLS
#endif /* _KERNEL */

#endif /* _SYS_TIMERFD_H_ */