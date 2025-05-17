/*	$NetBSD: byte_swap.h,v 1.8 2021/04/17 20:12:55 rillig Exp $	*/

/*-
 * Copyright (c) 1998, 2010 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Charles M. Hannum.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Copy of the i386 version. 64 bit versions may be added later.
 */

#ifndef _AMD64_BYTE_SWAP_H_
#define	_AMD64_BYTE_SWAP_H_

#ifdef __x86_64__

#ifdef  __GNUC__
#include <sys/types.h>
__BEGIN_DECLS

#define	__BYTE_SWAP_U64_VARIABLE __byte_swap_u64_variable
static __inline uint64_t __byte_swap_u64_variable(uint64_t);
static __inline uint64_t
__byte_swap_u64_variable(uint64_t x)
{
	__asm volatile ( "bswap %1" : "=r" (x) : "0" (x));
	return (x);
}

#define	__BYTE_SWAP_U32_VARIABLE __byte_swap_u32_variable
static __inline uint32_t __byte_swap_u32_variable(uint32_t);
static __inline uint32_t
__byte_swap_u32_variable(uint32_t x)
{
	__asm volatile ( "bswap %1" : "=r" (x) : "0" (x));
	return (x);
}

#define	__BYTE_SWAP_U16_VARIABLE __byte_swap_u16_variable
static __inline uint16_t __byte_swap_u16_variable(uint16_t);
static __inline uint16_t
__byte_swap_u16_variable(uint16_t x)
{
	__asm volatile ("rorw $8, %w1" : "=r" (x) : "0" (x));
	return (x);
}

__END_DECLS
#endif

#else	/*	__x86_64__	*/

#include <i386/byte_swap.h>

#endif	/*	__x86_64__	*/

#endif /* !_AMD64_BYTE_SWAP_H_ */