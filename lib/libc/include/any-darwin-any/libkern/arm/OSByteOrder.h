/*
 * Copyright (c) 1999-2023 Apple Inc. All rights reserved.
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

#ifndef _OS_OSBYTEORDERARM_H
#define _OS_OSBYTEORDERARM_H

#if defined (__arm__) || defined(__arm64__)

#include <stdint.h>
#include <libkern/arm/_OSByteOrder.h>
#include <sys/_types/_os_inline.h>
#include <arm/arch.h> /* for _ARM_ARCH_6 */

/* Functions for byte reversed loads. */

struct _OSUnalignedU16 {
	volatile uint16_t __val;
} __attribute__((__packed__));

struct _OSUnalignedU32 {
	volatile uint32_t __val;
} __attribute__((__packed__));

struct _OSUnalignedU64 {
	volatile uint64_t __val;
} __attribute__((__packed__));

#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE)
OS_INLINE
uint16_t
_OSReadSwapInt16(
	const volatile void   * _base,
	uintptr_t       _offset
	)
{
	return _OSSwapInt16(((struct _OSUnalignedU16 *)((uintptr_t)_base + _offset))->__val);
}
#else
OS_INLINE
uint16_t
OSReadSwapInt16(
	const volatile void   * _base,
	uintptr_t       _offset
	)
{
	return _OSSwapInt16(((struct _OSUnalignedU16 *)((uintptr_t)_base + _offset))->__val);
}
#endif

#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE)
OS_INLINE
uint32_t
_OSReadSwapInt32(
	const volatile void   * _base,
	uintptr_t       _offset
	)
{
	return _OSSwapInt32(((struct _OSUnalignedU32 *)((uintptr_t)_base + _offset))->__val);
}
#else
OS_INLINE
uint32_t
OSReadSwapInt32(
	const volatile void   * _base,
	uintptr_t       _offset
	)
{
	return _OSSwapInt32(((struct _OSUnalignedU32 *)((uintptr_t)_base + _offset))->__val);
}
#endif

#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE)
OS_INLINE
uint64_t
_OSReadSwapInt64(
	const volatile void   * _base,
	uintptr_t       _offset
	)
{
	return _OSSwapInt64(((struct _OSUnalignedU64 *)((uintptr_t)_base + _offset))->__val);
}
#else
OS_INLINE
uint64_t
OSReadSwapInt64(
	const volatile void   * _base,
	uintptr_t       _offset
	)
{
	return _OSSwapInt64(((struct _OSUnalignedU64 *)((uintptr_t)_base + _offset))->__val);
}
#endif

/* Functions for byte reversed stores. */

#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE)
OS_INLINE
void
_OSWriteSwapInt16(
	volatile void   * _base,
	uintptr_t       _offset,
	uint16_t        _data
	)
{
	((struct _OSUnalignedU16 *)((uintptr_t)_base + _offset))->__val = _OSSwapInt16(_data);
}
#else
OS_INLINE
void
OSWriteSwapInt16(
	volatile void   * _base,
	uintptr_t       _offset,
	uint16_t        _data
	)
{
	((struct _OSUnalignedU16 *)((uintptr_t)_base + _offset))->__val = _OSSwapInt16(_data);
}
#endif

#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE)
OS_INLINE
void
_OSWriteSwapInt32(
	volatile void   * _base,
	uintptr_t       _offset,
	uint32_t        _data
	)
{
	((struct _OSUnalignedU32 *)((uintptr_t)_base + _offset))->__val = _OSSwapInt32(_data);
}
#else
OS_INLINE
void
OSWriteSwapInt32(
	volatile void   * _base,
	uintptr_t       _offset,
	uint32_t        _data
	)
{
	((struct _OSUnalignedU32 *)((uintptr_t)_base + _offset))->__val = _OSSwapInt32(_data);
}
#endif

#if defined(_POSIX_C_SOURCE) || defined(_XOPEN_SOURCE)
OS_INLINE
void
_OSWriteSwapInt64(
	volatile void    * _base,
	uintptr_t        _offset,
	uint64_t         _data
	)
{
	((struct _OSUnalignedU64 *)((uintptr_t)_base + _offset))->__val = _OSSwapInt64(_data);
}
#else
OS_INLINE
void
OSWriteSwapInt64(
	volatile void    * _base,
	uintptr_t        _offset,
	uint64_t         _data
	)
{
	((struct _OSUnalignedU64 *)((uintptr_t)_base + _offset))->__val = _OSSwapInt64(_data);
}
#endif

#endif /* defined (__arm__) || defined(__arm64__) */

#endif /* ! _OS_OSBYTEORDERARM_H */
