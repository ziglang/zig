/*
 * Copyright (c) 1999-2007 Apple Inc. All rights reserved.
 */

#ifndef _OS_OSBYTEORDERARM_H
#define _OS_OSBYTEORDERARM_H

#include <stdint.h>
#include <arm/arch.h> /* for _ARM_ARCH_6 */

/* Generic byte swapping functions. */

__DARWIN_OS_INLINE
uint16_t
_OSSwapInt16(
	uint16_t        _data
	)
{
	/* Reduces to 'rev16' with clang */
	return (uint16_t)(_data << 8 | _data >> 8);
}

__DARWIN_OS_INLINE
uint32_t
_OSSwapInt32(
	uint32_t        _data
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
uint64_t
_OSSwapInt64(
	uint64_t        _data
	)
{
#if defined(__llvm__)
	return __builtin_bswap64(_data);
#else
	union {
		uint64_t _ull;
		uint32_t _ul[2];
	} _u;

	/* This actually generates the best code */
	_u._ul[0] = (uint32_t)(_data >> 32);
	_u._ul[1] = (uint32_t)(_data & 0xffffffff);
	_u._ul[0] = _OSSwapInt32(_u._ul[0]);
	_u._ul[1] = _OSSwapInt32(_u._ul[1]);
	return _u._ull;
#endif
}

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
__DARWIN_OS_INLINE
uint16_t
_OSReadSwapInt16(
	const volatile void   * _base,
	uintptr_t       _offset
	)
{
	return _OSSwapInt16(((struct _OSUnalignedU16 *)((uintptr_t)_base + _offset))->__val);
}
#else
__DARWIN_OS_INLINE
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
__DARWIN_OS_INLINE
uint32_t
_OSReadSwapInt32(
	const volatile void   * _base,
	uintptr_t       _offset
	)
{
	return _OSSwapInt32(((struct _OSUnalignedU32 *)((uintptr_t)_base + _offset))->__val);
}
#else
__DARWIN_OS_INLINE
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
__DARWIN_OS_INLINE
uint64_t
_OSReadSwapInt64(
	const volatile void   * _base,
	uintptr_t       _offset
	)
{
	return _OSSwapInt64(((struct _OSUnalignedU64 *)((uintptr_t)_base + _offset))->__val);
}
#else
__DARWIN_OS_INLINE
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
__DARWIN_OS_INLINE
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
__DARWIN_OS_INLINE
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
__DARWIN_OS_INLINE
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
__DARWIN_OS_INLINE
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
__DARWIN_OS_INLINE
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
__DARWIN_OS_INLINE
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

#endif /* ! _OS_OSBYTEORDERARM_H */
