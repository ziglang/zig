/* $NetBSD: byte_swap.h,v 1.5 2020/04/04 21:13:20 christos Exp $ */

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

#ifndef _RISCV_BYTE_SWAP_H_
#define	_RISCV_BYTE_SWAP_H_

#ifdef _LOCORE

#define	BSWAP16(_src, _dst, _tmp)	\
	andi	_dst, _src, 0xff	;\
	slli	_dst, _dst, 8		;\
	srli	_tmp, _src, 8		;\
	and	_tmp, _tmp, 0xff	;\
	ori	_dst, _dst, _tmp

#define BSWAP32(_src, _dst, _tmp)	\
	li	v1, 0xff00		;\
	slli	_dst, _src, 24		;\
	srli	_tmp, _src, 24		;\
	ori	_dst, _dst, _tmp	;\
	and	_tmp, _src, v1		;\
	slli	_tmp, _src, 8		;\
	ori	_dst, _dst, _tmp	;\
	srli	_tmp, _src, 8		;\
	and	_tmp, _tmp, v1		;\
	ori	_dst, _dst, _tmp

#else

#include <sys/types.h>
__BEGIN_DECLS

#define	__BYTE_SWAP_U64_VARIABLE __byte_swap_u64_variable
static __inline uint64_t
__byte_swap_u64_variable(uint64_t v)
{
	const uint64_t m1 = 0x0000ffff0000ffffull;
	const uint64_t m0 = 0x00ff00ff00ff00ffull;

	v = (v >> 32) | (v << 32);
	v = ((v >> 16) & m1) | ((v & m1) << 16);
	v = ((v >> 8) & m0) | ((v & m0) << 8);

	return v;
}

#define	__BYTE_SWAP_U32_VARIABLE __byte_swap_u32_variable
static __inline uint32_t
__byte_swap_u32_variable(uint32_t v)
{
	const uint32_t m = 0xff00ff;

	v = (v >> 16) | (v << 16);
	v = ((v >> 8) & m) | ((v & m) << 8);

	return v;
}

#define	__BYTE_SWAP_U16_VARIABLE __byte_swap_u16_variable
static __inline uint16_t
__byte_swap_u16_variable(uint16_t v)
{
	/*LINTED*/
	return (uint16_t)((v >> 8) | (v << 8));
}

__END_DECLS

#endif	/* _LOCORE */

#endif /* _RISCV_BYTE_SWAP_H_ */