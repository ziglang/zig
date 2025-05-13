/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1991, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *
 *	@(#)types.h	8.6 (Berkeley) 2/19/95
 */

#ifndef _SYS_BITCOUNT_H_
#define	_SYS_BITCOUNT_H_

#include <sys/_types.h>

#ifdef __POPCNT__
#define	__bitcount64(x)	__builtin_popcountll((__uint64_t)(x))
#define	__bitcount32(x)	__builtin_popcount((__uint32_t)(x))
#define	__bitcount16(x)	__builtin_popcount((__uint16_t)(x))
#define	__bitcountl(x)	__builtin_popcountl((unsigned long)(x))
#define	__bitcount(x)	__builtin_popcount((unsigned int)(x))
#else
/*
 * Population count algorithm using SWAR approach
 * - "SIMD Within A Register".
 */
static __inline __uint16_t
__bitcount16(__uint16_t _x)
{

	_x = (_x & 0x5555) + ((_x & 0xaaaa) >> 1);
	_x = (_x & 0x3333) + ((_x & 0xcccc) >> 2);
	_x = (_x + (_x >> 4)) & 0x0f0f;
	_x = (_x + (_x >> 8)) & 0x00ff;
	return (_x);
}

static __inline __uint32_t
__bitcount32(__uint32_t _x)
{

	_x = (_x & 0x55555555) + ((_x & 0xaaaaaaaa) >> 1);
	_x = (_x & 0x33333333) + ((_x & 0xcccccccc) >> 2);
	_x = (_x + (_x >> 4)) & 0x0f0f0f0f;
	_x = (_x + (_x >> 8));
	_x = (_x + (_x >> 16)) & 0x000000ff;
	return (_x);
}

#ifdef __LP64__
static __inline __uint64_t
__bitcount64(__uint64_t _x)
{

	_x = (_x & 0x5555555555555555) + ((_x & 0xaaaaaaaaaaaaaaaa) >> 1);
	_x = (_x & 0x3333333333333333) + ((_x & 0xcccccccccccccccc) >> 2);
	_x = (_x + (_x >> 4)) & 0x0f0f0f0f0f0f0f0f;
	_x = (_x + (_x >> 8));
	_x = (_x + (_x >> 16));
	_x = (_x + (_x >> 32)) & 0x000000ff;
	return (_x);
}

#define	__bitcountl(x)	__bitcount64((unsigned long)(x))
#else
static __inline __uint64_t
__bitcount64(__uint64_t _x)
{

	return (__bitcount32(_x >> 32) + __bitcount32(_x));
}

#define	__bitcountl(x)	__bitcount32((unsigned long)(x))
#endif
#define	__bitcount(x)	__bitcount32((unsigned int)(x))
#endif

#endif /* !_SYS_BITCOUNT_H_ */