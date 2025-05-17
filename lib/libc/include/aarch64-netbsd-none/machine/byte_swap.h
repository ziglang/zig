/* $NetBSD: byte_swap.h,v 1.4 2017/01/17 11:09:36 rin Exp $ */

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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

#ifdef __aarch64__

#ifdef _LOCORE

#define	BSWAP16(_src, _dst)		\
	rev16	_dst, _src
#define	BSWAP32(_src, _dst)		\
	rev	_dst, _src
#define	BSWAP64(_src, _dst)		\
	rev	_dst, _src

#else

#ifdef __GNUC__
#include <sys/types.h>
__BEGIN_DECLS

#define	__BYTE_SWAP_U64_VARIABLE __byte_swap_u64_variable
static __inline uint64_t
__byte_swap_u64_variable(uint64_t v)
{
	if (!__builtin_constant_p(v)) {
		__asm("rev\t%x0, %x1" : "=r" (v) : "0" (v));
		return v;
	}

	v =   ((v & 0x000000ff) << (56 -  0)) | ((v >> (56 -  0)) & 0x000000ff)
	    | ((v & 0x0000ff00) << (48 -  8)) | ((v >> (48 -  8)) & 0x0000ff00) 
	    | ((v & 0x00ff0000) << (40 - 16)) | ((v >> (40 - 16)) & 0x00ff0000)
	    | ((v & 0xff000000) << (32 - 24)) | ((v >> (32 - 24)) & 0xff000000);

	return v;
}

#define	__BYTE_SWAP_U32_VARIABLE __byte_swap_u32_variable
static __inline uint32_t
__byte_swap_u32_variable(uint32_t v)
{
	if (!__builtin_constant_p(v)) {
		__asm("rev\t%w0, %w1" : "=r" (v) : "0" (v));
		return v;
	}

	v =   ((v & 0x00ff) << (24 - 0)) | ((v >> (24 - 0)) & 0x00ff)
	    | ((v & 0xff00) << (16 - 8)) | ((v >> (16 - 8)) & 0xff00);

	return v;
}

#define	__BYTE_SWAP_U16_VARIABLE __byte_swap_u16_variable
static __inline uint16_t
__byte_swap_u16_variable(uint16_t v)
{

	if (!__builtin_constant_p(v)) {
		uint32_t v32 = v;
		__asm("rev16\t%w0, %w1" : "=r" (v32) : "0" (v32));
		return (uint16_t)v32;
	}

	v &= 0xffff;
	v = (uint16_t)((v >> 8) | (v << 8));

	return v;
}

__END_DECLS
#endif

#endif	/* _LOCORE */

#elif defined(__arm__)

#include <arm/asm.h>

#endif

#endif /* _ARM_BYTE_SWAP_H_ */