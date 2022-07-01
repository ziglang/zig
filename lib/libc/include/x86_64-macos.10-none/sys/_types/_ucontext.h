/*
 * Copyright (c) 2003-2012 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
#ifndef _STRUCT_UCONTEXT

#include <sys/cdefs.h> /* __DARWIN_UNIX03 */

#if __DARWIN_UNIX03
#define _STRUCT_UCONTEXT        struct __darwin_ucontext
#else /* !__DARWIN_UNIX03 */
#define _STRUCT_UCONTEXT        struct ucontext
#endif /* __DARWIN_UNIX03 */

#include <machine/types.h> /* __darwin_size_t */
#include <machine/_mcontext.h> /* _STRUCT_MCONTEXT */
#include <sys/_types.h> /* __darwin_sigset_t */

_STRUCT_UCONTEXT
{
	int                     uc_onstack;
	__darwin_sigset_t       uc_sigmask;     /* signal mask used by this context */
	_STRUCT_SIGALTSTACK     uc_stack;       /* stack used by this context */
	_STRUCT_UCONTEXT        *uc_link;       /* pointer to resuming context */
	__darwin_size_t         uc_mcsize;      /* size of the machine context passed in */
	_STRUCT_MCONTEXT        *uc_mcontext;   /* pointer to machine specific context */
#ifdef _XOPEN_SOURCE
	_STRUCT_MCONTEXT        __mcontext_data;
#endif /* _XOPEN_SOURCE */
};

/* user context */
typedef _STRUCT_UCONTEXT        ucontext_t;     /* [???] user context */

#endif /* _STRUCT_UCONTEXT */