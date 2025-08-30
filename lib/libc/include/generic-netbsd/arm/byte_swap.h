/*	$NetBSD: byte_swap.h,v 1.16 2017/01/17 11:08:50 rin Exp $	*/

/*-
 * Copyright (c) 1997, 1999, 2002 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Charles M. Hannum, Neil A. Carson, and Jason R. Thorpe.
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

#ifndef _ARM_BYTE_SWAP_H_
#define	_ARM_BYTE_SWAP_H_

#ifdef _LOCORE

#if defined(_ARM_ARCH_6) || defined(_ARM_ARCH_7)

#define	BSWAP16(_src, _dst, _tmp)		\
	rev16	_dst, _src
#define	BSWAP32(_src, _dst, _tmp)		\
	rev	_dst, _src

#else

#define	BSWAP16(_src, _dst, _tmp)		\
	mov	_tmp, _src, ror #8		;\
	orr	_tmp, _tmp, _tmp, lsr #16	;\
	bic	_dst, _tmp, _tmp, lsl #16

#define	BSWAP32(_src, _dst, _tmp)		\
	eor	_tmp, _src, _src, ror #16	;\
	bic	_tmp, _tmp, #0x00FF0000		;\
	mov	_dst, _src, ror #8		;\
	eor	_dst, _dst, _tmp, lsr #8

#endif


#else

#ifdef __GNUC__
#include <sys/types.h>
__BEGIN_DECLS

#define	__BYTE_SWAP_U32_VARIABLE __byte_swap_u32_variable
static __inline uint32_t
__byte_swap_u32_variable(uint32_t v)
{
	uint32_t t1;

#ifdef _ARM_ARCH_6
	if (!__builtin_constant_p(v)) {
		__asm("rev\t%0, %1" : "=r" (v) : "0" (v));
		return v;
	}
#endif

	t1 = v ^ ((v << 16) | (v >> 16));
	t1 &= 0xff00ffffU;
	v = (v >> 8) | (v << 24);
	v ^= (t1 >> 8);

	return v;
}

#define	__BYTE_SWAP_U16_VARIABLE __byte_swap_u16_variable
static __inline uint16_t
__byte_swap_u16_variable(uint16_t v)
{

#ifdef _ARM_ARCH_6
	if (!__builtin_constant_p(v)) {
		uint32_t v32 = v;
		__asm("rev16\t%0, %1" : "=r" (v32) : "0" (v32));
		return (uint16_t)v32;
	}
#elif !defined(__thumb__) && 0	/* gcc produces decent code for this */
	if (!__builtin_constant_p(v)) {
		uint32_t v0 = v;
		__asm volatile(
			"mov	%0, %1, ror #8\n"
			"orr	%0, %0, %0, lsr #16\n"
			"bic	%0, %0, %0, lsl #16"
		: "=&r" (v0)
		: "0" (v0));
		return (uint16_t)v0;
	}
#endif
	v &= 0xffff;
	v = (uint16_t)((v >> 8) | (v << 8));

	return v;
}

__END_DECLS
#endif

#endif	/* _LOCORE */

#endif /* _ARM_BYTE_SWAP_H_ */