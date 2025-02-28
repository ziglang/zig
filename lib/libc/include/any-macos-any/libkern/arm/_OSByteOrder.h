/*
 * Copyright (c) 2023 Apple Inc. All rights reserved.
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

#ifndef _OS__OSBYTEORDERARM_H
#define _OS__OSBYTEORDERARM_H

#if defined (__arm__) || defined(__arm64__)

#include <sys/_types.h>

#if !defined(__DARWIN_OS_INLINE)
# if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
#        define __DARWIN_OS_INLINE static inline
# elif defined(__MWERKS__) || defined(__cplusplus)
#        define __DARWIN_OS_INLINE static inline
# else
#        define __DARWIN_OS_INLINE static __inline__
# endif
#endif

/* Generic byte swapping functions. */

__DARWIN_OS_INLINE
__uint16_t
_OSSwapInt16(
	__uint16_t        _data
	)
{
	/* Reduces to 'rev16' with clang */
	return (__uint16_t)(_data << 8 | _data >> 8);
}

__DARWIN_OS_INLINE
__uint32_t
_OSSwapInt32(
	__uint32_t        _data
	)
{
#if defined(__llvm__)
	_data = __builtin_bswap32(_data);
#else
	/* This actually generates the best code */
	_data = (((_data ^ (_data >> 16 | (_data << 16))) & 0xFF00FFFF) >> 8) ^ (_data >> 8 | _data << 24);
#endif

	return _data;
}

__DARWIN_OS_INLINE
__uint64_t
_OSSwapInt64(
	__uint64_t        _data
	)
{
#if defined(__llvm__)
	return __builtin_bswap64(_data);
#else
	union {
		__uint64_t _ull;
		__uint32_t _ul[2];
	} _u;

	/* This actually generates the best code */
	_u._ul[0] = (__uint32_t)(_data >> 32);
	_u._ul[1] = (__uint32_t)(_data & 0xffffffff);
	_u._ul[0] = _OSSwapInt32(_u._ul[0]);
	_u._ul[1] = _OSSwapInt32(_u._ul[1]);
	return _u._ull;
#endif
}

#endif /* defined (__arm__) || defined(__arm64__) */

#endif /* ! _OS__OSBYTEORDERARM_H */
