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

#ifndef __I386_MCONTEXT_H_
#define __I386_MCONTEXT_H_

#include <sys/cdefs.h> /* __DARWIN_UNIX03 */
#include <sys/appleapiopts.h>
#include <mach/machine/_structs.h>

#ifndef _STRUCT_MCONTEXT32
#if __DARWIN_UNIX03
#define _STRUCT_MCONTEXT32      struct __darwin_mcontext32
_STRUCT_MCONTEXT32
{
	_STRUCT_X86_EXCEPTION_STATE32   __es;
	_STRUCT_X86_THREAD_STATE32      __ss;
	_STRUCT_X86_FLOAT_STATE32       __fs;
};

#define _STRUCT_MCONTEXT_AVX32  struct __darwin_mcontext_avx32
_STRUCT_MCONTEXT_AVX32
{
	_STRUCT_X86_EXCEPTION_STATE32   __es;
	_STRUCT_X86_THREAD_STATE32      __ss;
	_STRUCT_X86_AVX_STATE32         __fs;
};

#if defined(_STRUCT_X86_AVX512_STATE32)
#define _STRUCT_MCONTEXT_AVX512_32      struct __darwin_mcontext_avx512_32
_STRUCT_MCONTEXT_AVX512_32
{
	_STRUCT_X86_EXCEPTION_STATE32   __es;
	_STRUCT_X86_THREAD_STATE32      __ss;
	_STRUCT_X86_AVX512_STATE32      __fs;
};
#endif /* _STRUCT_X86_AVX512_STATE32 */

#else /* !__DARWIN_UNIX03 */
#define _STRUCT_MCONTEXT32      struct mcontext32
_STRUCT_MCONTEXT32
{
	_STRUCT_X86_EXCEPTION_STATE32   es;
	_STRUCT_X86_THREAD_STATE32      ss;
	_STRUCT_X86_FLOAT_STATE32       fs;
};

#define _STRUCT_MCONTEXT_AVX32  struct mcontext_avx32
_STRUCT_MCONTEXT_AVX32
{
	_STRUCT_X86_EXCEPTION_STATE32   es;
	_STRUCT_X86_THREAD_STATE32      ss;
	_STRUCT_X86_AVX_STATE32         fs;
};

#if defined(_STRUCT_X86_AVX512_STATE32)
#define _STRUCT_MCONTEXT_AVX512_32      struct mcontext_avx512_32
_STRUCT_MCONTEXT_AVX512_32
{
	_STRUCT_X86_EXCEPTION_STATE32   es;
	_STRUCT_X86_THREAD_STATE32      ss;
	_STRUCT_X86_AVX512_STATE32      fs;
};
#endif /* _STRUCT_X86_AVX512_STATE32 */

#endif /* __DARWIN_UNIX03 */
#endif /* _STRUCT_MCONTEXT32 */

#ifndef _STRUCT_MCONTEXT64
#if __DARWIN_UNIX03
#define _STRUCT_MCONTEXT64      struct __darwin_mcontext64
_STRUCT_MCONTEXT64
{
	_STRUCT_X86_EXCEPTION_STATE64   __es;
	_STRUCT_X86_THREAD_STATE64      __ss;
	_STRUCT_X86_FLOAT_STATE64       __fs;
};

#define _STRUCT_MCONTEXT64_FULL      struct __darwin_mcontext64_full
_STRUCT_MCONTEXT64_FULL
{
	_STRUCT_X86_EXCEPTION_STATE64   __es;
	_STRUCT_X86_THREAD_FULL_STATE64 __ss;
	_STRUCT_X86_FLOAT_STATE64       __fs;
};

#define _STRUCT_MCONTEXT_AVX64  struct __darwin_mcontext_avx64
_STRUCT_MCONTEXT_AVX64
{
	_STRUCT_X86_EXCEPTION_STATE64   __es;
	_STRUCT_X86_THREAD_STATE64      __ss;
	_STRUCT_X86_AVX_STATE64         __fs;
};

#define _STRUCT_MCONTEXT_AVX64_FULL  struct __darwin_mcontext_avx64_full
_STRUCT_MCONTEXT_AVX64_FULL
{
	_STRUCT_X86_EXCEPTION_STATE64   __es;
	_STRUCT_X86_THREAD_FULL_STATE64 __ss;
	_STRUCT_X86_AVX_STATE64         __fs;
};

#if defined(_STRUCT_X86_AVX512_STATE64)
#define _STRUCT_MCONTEXT_AVX512_64      struct __darwin_mcontext_avx512_64
_STRUCT_MCONTEXT_AVX512_64
{
	_STRUCT_X86_EXCEPTION_STATE64   __es;
	_STRUCT_X86_THREAD_STATE64      __ss;
	_STRUCT_X86_AVX512_STATE64      __fs;
};

#define _STRUCT_MCONTEXT_AVX512_64_FULL      struct __darwin_mcontext_avx512_64_full
_STRUCT_MCONTEXT_AVX512_64_FULL
{
	_STRUCT_X86_EXCEPTION_STATE64   __es;
	_STRUCT_X86_THREAD_FULL_STATE64 __ss;
	_STRUCT_X86_AVX512_STATE64      __fs;
};
#endif /* _STRUCT_X86_AVX512_STATE64 */

#else /* !__DARWIN_UNIX03 */
#define _STRUCT_MCONTEXT64      struct mcontext64
_STRUCT_MCONTEXT64
{
	_STRUCT_X86_EXCEPTION_STATE64   es;
	_STRUCT_X86_THREAD_STATE64      ss;
	_STRUCT_X86_FLOAT_STATE64       fs;
};

#define _STRUCT_MCONTEXT64_FULL      struct mcontext64_full
_STRUCT_MCONTEXT64_FULL
{
	_STRUCT_X86_EXCEPTION_STATE64   es;
	_STRUCT_X86_THREAD_FULL_STATE64 ss;
	_STRUCT_X86_FLOAT_STATE64       fs;
};

#define _STRUCT_MCONTEXT_AVX64  struct mcontext_avx64
_STRUCT_MCONTEXT_AVX64
{
	_STRUCT_X86_EXCEPTION_STATE64   es;
	_STRUCT_X86_THREAD_STATE64      ss;
	_STRUCT_X86_AVX_STATE64         fs;
};

#define _STRUCT_MCONTEXT_AVX64_FULL  struct mcontext_avx64_full
_STRUCT_MCONTEXT_AVX64_FULL
{
	_STRUCT_X86_EXCEPTION_STATE64   es;
	_STRUCT_X86_THREAD_FULL_STATE64 ss;
	_STRUCT_X86_AVX_STATE64         fs;
};

#if defined(_STRUCT_X86_AVX512_STATE64)
#define _STRUCT_MCONTEXT_AVX512_64      struct mcontext_avx512_64
_STRUCT_MCONTEXT_AVX512_64
{
	_STRUCT_X86_EXCEPTION_STATE64   es;
	_STRUCT_X86_THREAD_STATE64      ss;
	_STRUCT_X86_AVX512_STATE64      fs;
};

#define _STRUCT_MCONTEXT_AVX512_64_FULL      struct mcontext_avx512_64_full
_STRUCT_MCONTEXT_AVX512_64_FULL
{
	_STRUCT_X86_EXCEPTION_STATE64   es;
	_STRUCT_X86_THREAD_FULL_STATE64 ss;
	_STRUCT_X86_AVX512_STATE64      fs;
};
#endif /* _STRUCT_X86_AVX512_STATE64 */

#endif /* __DARWIN_UNIX03 */
#endif /* _STRUCT_MCONTEXT64 */


#ifndef _MCONTEXT_T
#define _MCONTEXT_T
#if defined(__LP64__)
typedef _STRUCT_MCONTEXT64      *mcontext_t;
#define _STRUCT_MCONTEXT _STRUCT_MCONTEXT64
#else
typedef _STRUCT_MCONTEXT32      *mcontext_t;
#define _STRUCT_MCONTEXT        _STRUCT_MCONTEXT32
#endif
#endif /* _MCONTEXT_T */

#endif /* __I386_MCONTEXT_H_ */