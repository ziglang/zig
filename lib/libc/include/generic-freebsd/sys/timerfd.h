/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2023 Jake Freeland <jfree@FreeBSD.org>
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

#ifndef _SYS_TIMERFD_H_
#define _SYS_TIMERFD_H_

#include <sys/types.h>
#include <sys/fcntl.h>
/*
 * We only need <sys/timespec.h>, but glibc pollutes the namespace
 * with <time.h>. This pollution is expected by most programs, so
 * reproduce it by including <sys/time.h> here.
 */
#include <sys/time.h>

typedef	uint64_t	timerfd_t;

/* Creation flags. */
#define TFD_NONBLOCK	O_NONBLOCK
#define TFD_CLOEXEC	O_CLOEXEC

/* Timer flags. */
#define	TFD_TIMER_ABSTIME	0x01
#define	TFD_TIMER_CANCEL_ON_SET	0x02

#ifndef _KERNEL

__BEGIN_DECLS
int timerfd_create(int clockid, int flags);
int timerfd_gettime(int fd, struct itimerspec *curr_value);
int timerfd_settime(int fd, int flags, const struct itimerspec *new_value,
    struct itimerspec *old_value);
__END_DECLS

#else /* _KERNEL */

void timerfd_jumped(void);

#endif /* !_KERNEL */

#endif /* !_SYS_TIMERFD_H_ */