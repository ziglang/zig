/*	$NetBSD: fault.h,v 1.2 2020/06/30 16:28:17 maxv Exp $	*/

/*
 * Copyright (c) 2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Maxime Villard.
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

#ifndef _SYS_FAULT_H_
#define _SYS_FAULT_H_

#ifdef _KERNEL_OPT
#include "opt_fault.h"
#endif

#if !defined(_KERNEL) || defined(FAULT)

#define FAULT_SCOPE_GLOBAL	0
#define FAULT_SCOPE_LWP		1

#define FAULT_MODE_NTH_ONESHOT	0

#define FAULT_NTH_MIN		2

struct fault_ioc_enable {
	int scope;
	int mode;
	union {
		unsigned long nth;
	};
};

struct fault_ioc_disable {
	int scope;
};

struct fault_ioc_getinfo {
	int scope;
	unsigned long nfaults;
};

#define FAULT_IOC_ENABLE	_IOW ('F', 1, struct fault_ioc_enable)
#define FAULT_IOC_DISABLE	_IOW ('F', 2, struct fault_ioc_disable)
#define FAULT_IOC_GETINFO	_IOWR('F', 3, struct fault_ioc_getinfo)

#endif /* !_KERNEL || FAULT */

#ifdef _KERNEL
#ifdef FAULT
bool fault_inject(void);
#else
#define fault_inject() false
#endif
#endif /* _KERNEL */

#endif /* !_SYS_FAULT_H_ */