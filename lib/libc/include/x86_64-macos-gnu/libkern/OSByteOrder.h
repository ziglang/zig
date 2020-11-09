/*
 * Copyright (c) 2000-2006 Apple Computer, Inc. All rights reserved.
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

#ifndef _OS_OSBYTEORDER_H
#define _OS_OSBYTEORDER_H

#include <stdint.h>
#include <libkern/_OSByteOrder.h>

/* Macros for swapping constant values in the preprocessing stage. */
#define OSSwapConstInt16(x)     __DARWIN_OSSwapConstInt16(x)
#define OSSwapConstInt32(x)     __DARWIN_OSSwapConstInt32(x)
#define OSSwapConstInt64(x)     __DARWIN_OSSwapConstInt64(x)

#if !defined(__DARWIN_OS_INLINE)
# if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
#        define __DARWIN_OS_INLINE static inline
# elif defined(__MWERKS__) || defined(__cplusplus)
#        define __DARWIN_OS_INLINE static inline
# else
#        define __DARWIN_OS_INLINE static __inline__
# endif
#endif

#if defined(__GNUC__)

#if (defined(__i386__) || defined(__x86_64__))
#include <libkern/i386/OSByteOrder.h>
#elif defined (__arm__) || defined(__arm64__)
#include <libkern/arm/OSByteOrder.h>
#else
#include <libkern/machine/OSByteOrder.h>
#endif

#else /* ! __GNUC__ */

#include <libkern/machine/OSByteOrder.h>

#endif /* __GNUC__ */

#define OSSwapInt16(x)  __DARWIN_OSSwapInt16(x)
#define OSSwapInt32(x)  __DARWIN_OSSwapInt32(x)
#define OSSwapInt64(x)  __DARWIN_OSSwapInt64(x)

enum {
	OSUnknownByteOrder,
	OSLittleEndian,
	OSBigEndian
};

__DARWIN_OS_INLINE
int32_t
OSHostByteOrder(void)
{
#if defined(__LITTLE_ENDIAN__)
	return OSLittleEndian;
#elif defined(__BIG_ENDIAN__)
	return OSBigEndian;
#else
	return OSUnknownByteOrder;
#endif
}

#define OSReadBigInt(x, y)              OSReadBigInt32(x, y)
#define OSWriteBigInt(x, y, z)          OSWriteBigInt32(x, y, z)
#define OSSwapBigToHostInt(x)           OSSwapBigToHostInt32(x)
#define OSSwapHostToBigInt(x)           OSSwapHostToBigInt32(x)
#define OSReadLittleInt(x, y)           OSReadLittleInt32(x, y)
#define OSWriteLittleInt(x, y, z)       OSWriteLittleInt32(x, y, z)
#define OSSwapHostToLittleInt(x)        OSSwapHostToLittleInt32(x)
#define OSSwapLittleToHostInt(x)        OSSwapLittleToHostInt32(x)

/* Functions for loading native endian values. */

__DARWIN_OS_INLINE
uint16_t
_OSReadInt16(
	const volatile void               * base,
	uintptr_t                     byteOffset
	)
{
	return *(volatile uint16_t *)((uintptr_t)base + byteOffset);
}

__DARWIN_OS_INLINE
uint32_t
_OSReadInt32(
	const volatile void               * base,
	uintptr_t                     byteOffset
	)
{
	return *(volatile uint32_t *)((uintptr_t)base + byteOffset);
}

__DARWIN_OS_INLINE
uint64_t
_OSReadInt64(
	const volatile void               * base,
	uintptr_t                     byteOffset
	)
{
	return *(volatile uint64_t *)((uintptr_t)base + byteOffset);
}

/* Functions for storing native endian values. */

__DARWIN_OS_INLINE
void
_OSWriteInt16(
	volatile void               * base,
	uintptr_t                     byteOffset,
	uint16_t                      data
	)
{
	*(volatile uint16_t *)((uintptr_t)base + byteOffset) = data;
}

__DARWIN_OS_INLINE
void
_OSWriteInt32(
	volatile void               * base,
	uintptr_t                     byteOffset,
	uint32_t                      data
	)
{
	*(volatile uint32_t *)((uintptr_t)base + byteOffset) = data;
}

__DARWIN_OS_INLINE
void
_OSWriteInt64(
	volatile void               * base,
	uintptr_t                     byteOffset,
	uint64_t                      data
	)
{
	*(volatile uint64_t *)((uintptr_t)base + byteOffset) = data;
}

#if             defined(__BIG_ENDIAN__)

/* Functions for loading big endian to host endianess. */

#define OSReadBigInt16(base, byteOffset) _OSReadInt16(base, byteOffset)
#define OSReadBigInt32(base, byteOffset) _OSReadInt32(base, byteOffset)
#define OSReadBigInt64(base, byteOffset) _OSReadInt64(base, byteOffset)

/* Functions for storing host endianess to big endian. */

#define OSWriteBigInt16(base, byteOffset, data) _OSWriteInt16(base, byteOffset, data)
#define OSWriteBigInt32(base, byteOffset, data) _OSWriteInt32(base, byteOffset, data)
#define OSWriteBigInt64(base, byteOffset, data) _OSWriteInt64(base, byteOffset, data)

/* Functions for loading little endian to host endianess. */

#define OSReadLittleInt16(base, byteOffset) OSReadSwapInt16(base, byteOffset)
#define OSReadLittleInt32(base, byteOffset) OSReadSwapInt32(base, byteOffset)
#define OSReadLittleInt64(base, byteOffset) OSReadSwapInt64(base, byteOffset)

/* Functions for storing host endianess to little endian. */

#define OSWriteLittleInt16(base, byteOffset, data) OSWriteSwapInt16(base, byteOffset, data)
#define OSWriteLittleInt32(base, byteOffset, data) OSWriteSwapInt32(base, byteOffset, data)
#define OSWriteLittleInt64(base, byteOffset, data) OSWriteSwapInt64(base, byteOffset, data)

/* Host endianess to big endian byte swapping macros for constants. */

#define OSSwapHostToBigConstInt16(x) ((uint16_t)(x))
#define OSSwapHostToBigConstInt32(x) ((uint32_t)(x))
#define OSSwapHostToBigConstInt64(x) ((uint64_t)(x))

/* Generic host endianess to big endian byte swapping functions. */

#define OSSwapHostToBigInt16(x) ((uint16_t)(x))
#define OSSwapHostToBigInt32(x) ((uint32_t)(x))
#define OSSwapHostToBigInt64(x) ((uint64_t)(x))

/* Host endianess to little endian byte swapping macros for constants. */

#define OSSwapHostToLittleConstInt16(x) OSSwapConstInt16(x)
#define OSSwapHostToLittleConstInt32(x) OSSwapConstInt32(x)
#define OSSwapHostToLittleConstInt64(x) OSSwapConstInt64(x)

/* Generic host endianess to little endian byte swapping functions. */

#define OSSwapHostToLittleInt16(x) OSSwapInt16(x)
#define OSSwapHostToLittleInt32(x) OSSwapInt32(x)
#define OSSwapHostToLittleInt64(x) OSSwapInt64(x)

/* Big endian to host endianess byte swapping macros for constants. */

#define OSSwapBigToHostConstInt16(x) ((uint16_t)(x))
#define OSSwapBigToHostConstInt32(x) ((uint32_t)(x))
#define OSSwapBigToHostConstInt64(x) ((uint64_t)(x))

/* Generic big endian to host endianess byte swapping functions. */

#define OSSwapBigToHostInt16(x) ((uint16_t)(x))
#define OSSwapBigToHostInt32(x) ((uint32_t)(x))
#define OSSwapBigToHostInt64(x) ((uint64_t)(x))

/* Little endian to host endianess byte swapping macros for constants. */

#define OSSwapLittleToHostConstInt16(x) OSSwapConstInt16(x)
#define OSSwapLittleToHostConstInt32(x) OSSwapConstInt32(x)
#define OSSwapLittleToHostConstInt64(x) OSSwapConstInt64(x)

/* Generic little endian to host endianess byte swapping functions. */

#define OSSwapLittleToHostInt16(x) OSSwapInt16(x)
#define OSSwapLittleToHostInt32(x) OSSwapInt32(x)
#define OSSwapLittleToHostInt64(x) OSSwapInt64(x)

#elif           defined(__LITTLE_ENDIAN__)

/* Functions for loading big endian to host endianess. */

#define OSReadBigInt16(base, byteOffset) OSReadSwapInt16(base, byteOffset)
#define OSReadBigInt32(base, byteOffset) OSReadSwapInt32(base, byteOffset)
#define OSReadBigInt64(base, byteOffset) OSReadSwapInt64(base, byteOffset)

/* Functions for storing host endianess to big endian. */

#define OSWriteBigInt16(base, byteOffset, data) OSWriteSwapInt16(base, byteOffset, data)
#define OSWriteBigInt32(base, byteOffset, data) OSWriteSwapInt32(base, byteOffset, data)
#define OSWriteBigInt64(base, byteOffset, data) OSWriteSwapInt64(base, byteOffset, data)

/* Functions for loading little endian to host endianess. */

#define OSReadLittleInt16(base, byteOffset) _OSReadInt16(base, byteOffset)
#define OSReadLittleInt32(base, byteOffset) _OSReadInt32(base, byteOffset)
#define OSReadLittleInt64(base, byteOffset) _OSReadInt64(base, byteOffset)

/* Functions for storing host endianess to little endian. */

#define OSWriteLittleInt16(base, byteOffset, data) _OSWriteInt16(base, byteOffset, data)
#define OSWriteLittleInt32(base, byteOffset, data) _OSWriteInt32(base, byteOffset, data)
#define OSWriteLittleInt64(base, byteOffset, data) _OSWriteInt64(base, byteOffset, data)

/* Host endianess to big endian byte swapping macros for constants. */

#define OSSwapHostToBigConstInt16(x) OSSwapConstInt16(x)
#define OSSwapHostToBigConstInt32(x) OSSwapConstInt32(x)
#define OSSwapHostToBigConstInt64(x) OSSwapConstInt64(x)

/* Generic host endianess to big endian byte swapping functions. */

#define OSSwapHostToBigInt16(x) OSSwapInt16(x)
#define OSSwapHostToBigInt32(x) OSSwapInt32(x)
#define OSSwapHostToBigInt64(x) OSSwapInt64(x)

/* Host endianess to little endian byte swapping macros for constants. */

#define OSSwapHostToLittleConstInt16(x) ((uint16_t)(x))
#define OSSwapHostToLittleConstInt32(x) ((uint32_t)(x))
#define OSSwapHostToLittleConstInt64(x) ((uint64_t)(x))

/* Generic host endianess to little endian byte swapping functions. */

#define OSSwapHostToLittleInt16(x) ((uint16_t)(x))
#define OSSwapHostToLittleInt32(x) ((uint32_t)(x))
#define OSSwapHostToLittleInt64(x) ((uint64_t)(x))

/* Big endian to host endianess byte swapping macros for constants. */

#define OSSwapBigToHostConstInt16(x) OSSwapConstInt16(x)
#define OSSwapBigToHostConstInt32(x) OSSwapConstInt32(x)
#define OSSwapBigToHostConstInt64(x) OSSwapConstInt64(x)

/* Generic big endian to host endianess byte swapping functions. */

#define OSSwapBigToHostInt16(x) OSSwapInt16(x)
#define OSSwapBigToHostInt32(x) OSSwapInt32(x)
#define OSSwapBigToHostInt64(x) OSSwapInt64(x)

/* Little endian to host endianess byte swapping macros for constants. */

#define OSSwapLittleToHostConstInt16(x) ((uint16_t)(x))
#define OSSwapLittleToHostConstInt32(x) ((uint32_t)(x))
#define OSSwapLittleToHostConstInt64(x) ((uint64_t)(x))

/* Generic little endian to host endianess byte swapping functions. */

#define OSSwapLittleToHostInt16(x) ((uint16_t)(x))
#define OSSwapLittleToHostInt32(x) ((uint32_t)(x))
#define OSSwapLittleToHostInt64(x) ((uint64_t)(x))

#else
#error Unknown endianess.
#endif

#endif /* ! _OS_OSBYTEORDER_H */
