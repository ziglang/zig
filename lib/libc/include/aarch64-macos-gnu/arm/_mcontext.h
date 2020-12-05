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

#ifndef __ARM_MCONTEXT_H_
#define __ARM_MCONTEXT_H_

#include <sys/cdefs.h> /* __DARWIN_UNIX03 */
#include <sys/appleapiopts.h>
#include <mach/machine/_structs.h>

#ifndef _STRUCT_MCONTEXT32
#if __DARWIN_UNIX03
#define _STRUCT_MCONTEXT32        struct __darwin_mcontext32
_STRUCT_MCONTEXT32
{
	_STRUCT_ARM_EXCEPTION_STATE     __es;
	_STRUCT_ARM_THREAD_STATE        __ss;
	_STRUCT_ARM_VFP_STATE           __fs;
};

#else /* !__DARWIN_UNIX03 */
#define _STRUCT_MCONTEXT32        struct mcontext32
_STRUCT_MCONTEXT32
{
	_STRUCT_ARM_EXCEPTION_STATE     es;
	_STRUCT_ARM_THREAD_STATE        ss;
	_STRUCT_ARM_VFP_STATE           fs;
};

#endif /* __DARWIN_UNIX03 */
#endif /* _STRUCT_MCONTEXT32 */


#ifndef _STRUCT_MCONTEXT64
#if __DARWIN_UNIX03
#define _STRUCT_MCONTEXT64      struct __darwin_mcontext64
_STRUCT_MCONTEXT64
{
	_STRUCT_ARM_EXCEPTION_STATE64   __es;
	_STRUCT_ARM_THREAD_STATE64      __ss;
	_STRUCT_ARM_NEON_STATE64        __ns;
};

#else /* !__DARWIN_UNIX03 */
#define _STRUCT_MCONTEXT64      struct mcontext64
_STRUCT_MCONTEXT64
{
	_STRUCT_ARM_EXCEPTION_STATE64   es;
	_STRUCT_ARM_THREAD_STATE64      ss;
	_STRUCT_ARM_NEON_STATE64        ns;
};
#endif /* __DARWIN_UNIX03 */
#endif /* _STRUCT_MCONTEXT32 */

#ifndef _MCONTEXT_T
#define _MCONTEXT_T
#if defined(__arm64__)
typedef _STRUCT_MCONTEXT64      *mcontext_t;
#define _STRUCT_MCONTEXT _STRUCT_MCONTEXT64
#else
typedef _STRUCT_MCONTEXT32      *mcontext_t;
#define _STRUCT_MCONTEXT        _STRUCT_MCONTEXT32
#endif
#endif /* _MCONTEXT_T */

#endif /* __ARM_MCONTEXT_H_ */
