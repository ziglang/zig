/*	$NetBSD: eventfd.h,v 1.3 2021/09/21 13:51:46 ryoon Exp $	*/

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

#ifndef _SYS_EVENTFD_H_
#define	_SYS_EVENTFD_H_

#include <sys/fcntl.h>

/*
 * Definitions for eventfd(2).  This implementation is API compatible
 * with the Linux eventfd(2) interface.
 */

typedef uint64_t eventfd_t;

#define	EFD_SEMAPHORE	O_RDWR
#define	EFD_CLOEXEC	O_CLOEXEC
#define	EFD_NONBLOCK	O_NONBLOCK

#ifdef _KERNEL
struct lwp;
int	do_eventfd(struct lwp *, unsigned int, int, register_t *);
#else /* ! _KERNEL */
__BEGIN_DECLS
int	eventfd(unsigned int, int);
int	eventfd_read(int, eventfd_t *);
int	eventfd_write(int, eventfd_t);
__END_DECLS
#endif /* _KERNEL */

#endif /* _SYS_EVENTFD_H_ */