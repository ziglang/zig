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

/* Structure used in sigaltstack call. */
#ifndef _STRUCT_SIGALTSTACK

#include <sys/cdefs.h> /* __DARWIN_UNIX03 */

#if __DARWIN_UNIX03
#define _STRUCT_SIGALTSTACK     struct __darwin_sigaltstack
#else /* !__DARWIN_UNIX03 */
#define _STRUCT_SIGALTSTACK     struct sigaltstack
#endif /* __DARWIN_UNIX03 */

#include <machine/types.h> /* __darwin_size_t */

_STRUCT_SIGALTSTACK
{
	void            *ss_sp;         /* signal stack base */
	__darwin_size_t ss_size;        /* signal stack length */
	int             ss_flags;       /* SA_DISABLE and/or SA_ONSTACK */
};
typedef _STRUCT_SIGALTSTACK     stack_t; /* [???] signal stack */

#endif /* _STRUCT_SIGALTSTACK */
