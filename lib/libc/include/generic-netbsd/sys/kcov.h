/*      $NetBSD: kcov.h,v 1.10 2020/06/05 17:20:57 maxv Exp $        */

/*
 * Copyright (c) 2019-2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Siddharth Muralee.
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

#ifndef _SYS_KCOV_H_
#define _SYS_KCOV_H_

#ifdef _KERNEL_OPT
#include "opt_kcov.h"
#endif

#include <sys/param.h>
#include <sys/types.h>
#include <sys/atomic.h>

#define KCOV_IOC_SETBUFSIZE	_IOW('K', 1, uint64_t)
#define KCOV_IOC_ENABLE		_IOW('K', 2, int)
#define KCOV_IOC_DISABLE	_IO('K', 3)

#define KCOV_IOC_REMOTE_ATTACH	_IOW('K', 10, struct kcov_ioc_remote_attach)
#define KCOV_IOC_REMOTE_DETACH	_IO('K', 11)

struct kcov_ioc_remote_attach {
	uint64_t subsystem;
	uint64_t id;
};

#define KCOV_REMOTE_VHCI	0
#define KCOV_REMOTE_VHCI_ID(bus, port)	\
	(((uint64_t)bus << 32ULL) | ((uint64_t)port & 0xFFFFFFFFULL))

#define KCOV_MODE_NONE		0
#define KCOV_MODE_TRACE_PC	1
#define KCOV_MODE_TRACE_CMP	2

typedef volatile uint64_t kcov_int_t;
#define KCOV_ENTRY_SIZE sizeof(kcov_int_t)

#ifdef _KERNEL
#ifdef KCOV
void kcov_remote_register(uint64_t, uint64_t);
void kcov_remote_enter(uint64_t, uint64_t);
void kcov_remote_leave(uint64_t, uint64_t);
void kcov_silence_enter(void);
void kcov_silence_leave(void);
void kcov_lwp_free(struct lwp *);
#else
#define kcov_remote_register(s, i)	__nothing
#define kcov_remote_enter(s, i)		__nothing
#define kcov_remote_leave(s, i)		__nothing
#define kcov_silence_enter()		__nothing
#define kcov_silence_leave()		__nothing
#define kcov_lwp_free(a) __nothing
#endif
#endif

#endif /* !_SYS_KCOV_H_ */