/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1987, 1991 Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS__ENDIAN_H_
#define	_SYS__ENDIAN_H_

#if !defined(_MACHINE_ENDIAN_H_) && !defined(_BYTESWAP_H_) && !defined(_ENDIAN_H_)
#error "sys/_endian.h should not be included directly"
#endif

#include <sys/cdefs.h>				/* visibility macros */

/* BSD Compatibility */
#define	_BYTE_ORDER	__BYTE_ORDER__

/*
 * Definitions for byte order, according to byte significance from low
 * address to high. We undefine any prior definition of them because
 * powerpc compilers define _LITTLE_ENDIAN and _BIG_ENDIAN to mean
 * something else.
 */
#undef _LITTLE_ENDIAN
#define	_LITTLE_ENDIAN	__ORDER_LITTLE_ENDIAN__ /* LSB first: 1234 */
#undef _BIG_ENDIAN
#define	_BIG_ENDIAN	__ORDER_BIG_ENDIAN__    /* MSB first: 4321 */
#define	_PDP_ENDIAN	__ORDER_PDP_ENDIAN__    /* LSB first in word,
						 * MSW first in long: 3412 */

/*
 * Define the order of 32-bit words in 64-bit words.
 */
#if _BYTE_ORDER == _LITTLE_ENDIAN
#define	_QUAD_HIGHWORD	1
#define	_QUAD_LOWWORD	0
#elif _BYTE_ORDER == _BIG_ENDIAN
#define	_QUAD_HIGHWORD	0
#define	_QUAD_LOWWORD	1
#else
#error "Unsupported endian"
#endif

/*
 * POSIX Issue 8 will require these for endian.h. Define them there and in the
 * traditional BSD compilation environment. Since issue 8 doesn't yet have an
 * assigned date, use strictly greater than issue 7's date.
 */
#if __BSD_VISIBLE || _POSIX_C_SOURCE > 200809
#define	LITTLE_ENDIAN   _LITTLE_ENDIAN
#define	BIG_ENDIAN      _BIG_ENDIAN
#define	PDP_ENDIAN      _PDP_ENDIAN
#define	BYTE_ORDER      _BYTE_ORDER
#endif

/* bswap primitives, based on compiler builtins */
#define	__bswap16(x)	__builtin_bswap16(x)
#define	__bswap32(x)	__builtin_bswap32(x)
#define	__bswap64(x)	__builtin_bswap64(x)

#if _BYTE_ORDER == _LITTLE_ENDIAN
#define	__ntohl(x)	(__bswap32(x))
#define	__ntohs(x)	(__bswap16(x))
#define	__htonl(x)	(__bswap32(x))
#define	__htons(x)	(__bswap16(x))
#elif _BYTE_ORDER == _BIG_ENDIAN
#define	__htonl(x)	((__uint32_t)(x))
#define	__htons(x)	((__uint16_t)(x))
#define	__ntohl(x)	((__uint32_t)(x))
#define	__ntohs(x)	((__uint16_t)(x))
#endif

/*
 * Host to big endian, host to little endian, big endian to host, and little
 * endian to host byte order functions as detailed in byteorder(9).
 */
#if _BYTE_ORDER == _LITTLE_ENDIAN
#define	htobe16(x)	__bswap16((x))
#define	htobe32(x)	__bswap32((x))
#define	htobe64(x)	__bswap64((x))
#define	htole16(x)	((uint16_t)(x))
#define	htole32(x)	((uint32_t)(x))
#define	htole64(x)	((uint64_t)(x))

#define	be16toh(x)	__bswap16((x))
#define	be32toh(x)	__bswap32((x))
#define	be64toh(x)	__bswap64((x))
#define	le16toh(x)	((uint16_t)(x))
#define	le32toh(x)	((uint32_t)(x))
#define	le64toh(x)	((uint64_t)(x))
#else /* _BYTE_ORDER != _LITTLE_ENDIAN */
#define	htobe16(x)	((uint16_t)(x))
#define	htobe32(x)	((uint32_t)(x))
#define	htobe64(x)	((uint64_t)(x))
#define	htole16(x)	__bswap16((x))
#define	htole32(x)	__bswap32((x))
#define	htole64(x)	__bswap64((x))

#define	be16toh(x)	((uint16_t)(x))
#define	be32toh(x)	((uint32_t)(x))
#define	be64toh(x)	((uint64_t)(x))
#define	le16toh(x)	__bswap16((x))
#define	le32toh(x)	__bswap32((x))
#define	le64toh(x)	__bswap64((x))
#endif /* _BYTE_ORDER == _LITTLE_ENDIAN */

#endif /* _SYS__ENDIAN_H_ */