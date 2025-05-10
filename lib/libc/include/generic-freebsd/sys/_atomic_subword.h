/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Kyle Evans <kevans@FreeBSD.org>
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#ifndef _SYS__ATOMIC_SUBWORD_H_
#define	_SYS__ATOMIC_SUBWORD_H_

/*
 * This header is specifically for platforms that either do not have ways to or
 * simply do not do sub-word atomic operations.  These are not ideal as they
 * require a little more effort to make sure our atomic operations are failing
 * because of the bits of the word we're trying to write rather than the rest
 * of the word.
 */
#ifndef _MACHINE_ATOMIC_H_
#error do not include this header, use machine/atomic.h
#endif

#include <machine/endian.h>
#ifndef _KERNEL
#include <stdbool.h>
#endif

#ifndef NBBY
#define	NBBY	8
#endif

#define	_ATOMIC_WORD_ALIGNED(p)		\
    (uint32_t *)((__uintptr_t)(p) - ((__uintptr_t)(p) % 4))

#if _BYTE_ORDER == _BIG_ENDIAN
#define	_ATOMIC_BYTE_SHIFT(p)		\
    ((3 - ((__uintptr_t)(p) % 4)) * NBBY)

#define	_ATOMIC_HWORD_SHIFT(p)		\
    ((2 - ((__uintptr_t)(p) % 4)) * NBBY)
#else
#define	_ATOMIC_BYTE_SHIFT(p)		\
    ((((__uintptr_t)(p) % 4)) * NBBY)

#define	_ATOMIC_HWORD_SHIFT(p)		\
    ((((__uintptr_t)(p) % 4)) * NBBY)
#endif

#ifndef	_atomic_cmpset_masked_word
/*
 * Pass these bad boys a couple words and a mask of the bits you care about,
 * they'll loop until we either succeed or fail because of those bits rather
 * than the ones we're not masking.  old and val should already be preshifted to
 * the proper position.
 */
static __inline int
_atomic_cmpset_masked_word(uint32_t *addr, uint32_t old, uint32_t val,
    uint32_t mask)
{
	int ret;
	uint32_t wcomp;

	wcomp = old;

	/*
	 * We'll attempt the cmpset on the entire word.  Loop here in case the
	 * operation fails due to the other half-word resident in that word,
	 * rather than the half-word we're trying to operate on.  Ideally we
	 * only take one trip through here.  We'll have to recalculate the old
	 * value since it's the other part of the word changing.
	 */
	do {
		old = (*addr & ~mask) | wcomp;
		ret = atomic_fcmpset_32(addr, &old, (old & ~mask) | val);
	} while (ret == 0 && (old & mask) == wcomp);

	return (ret);
}
#endif

#ifndef	_atomic_fcmpset_masked_word
static __inline int
_atomic_fcmpset_masked_word(uint32_t *addr, uint32_t *old, uint32_t val,
    uint32_t mask)
{

	/*
	 * fcmpset_* is documented in atomic(9) to allow spurious failures where
	 * *old == val on ll/sc architectures because the sc may fail due to
	 * parallel writes or other reasons.  We take advantage of that here
	 * and only attempt once, because the caller should be compensating for
	 * that possibility.
	 */
	*old = (*addr & ~mask) | *old;
	return (atomic_fcmpset_32(addr, old, (*old & ~mask) | val));
}
#endif

#ifndef atomic_cmpset_8
static __inline int
atomic_cmpset_8(__volatile uint8_t *addr, uint8_t old, uint8_t val)
{
	int shift;

	shift = _ATOMIC_BYTE_SHIFT(addr);

	return (_atomic_cmpset_masked_word(_ATOMIC_WORD_ALIGNED(addr),
	    old << shift, val << shift, 0xff << shift));
}
#endif

#ifndef atomic_fcmpset_8
static __inline int
atomic_fcmpset_8(__volatile uint8_t *addr, uint8_t *old, uint8_t val)
{
	int ret, shift;
	uint32_t wold;

	shift = _ATOMIC_BYTE_SHIFT(addr);
	wold = *old << shift;
	ret = _atomic_fcmpset_masked_word(_ATOMIC_WORD_ALIGNED(addr),
	    &wold, val << shift, 0xff << shift);
	if (ret == 0)
		*old = (wold >> shift) & 0xff;
	return (ret);
}
#endif

#ifndef atomic_cmpset_16
static __inline int
atomic_cmpset_16(__volatile uint16_t *addr, uint16_t old, uint16_t val)
{
	int shift;

	shift = _ATOMIC_HWORD_SHIFT(addr);

	return (_atomic_cmpset_masked_word(_ATOMIC_WORD_ALIGNED(addr),
	    old << shift, val << shift, 0xffff << shift));
}
#endif

#ifndef atomic_fcmpset_16
static __inline int
atomic_fcmpset_16(__volatile uint16_t *addr, uint16_t *old, uint16_t val)
{
	int ret, shift;
	uint32_t wold;

	shift = _ATOMIC_HWORD_SHIFT(addr);
	wold = *old << shift;
	ret = _atomic_fcmpset_masked_word(_ATOMIC_WORD_ALIGNED(addr),
	    &wold, val << shift, 0xffff << shift);
	if (ret == 0)
		*old = (wold >> shift) & 0xffff;
	return (ret);
}
#endif

#ifndef atomic_load_acq_8
static __inline uint8_t
atomic_load_acq_8(volatile uint8_t *p)
{
	int shift;
	uint8_t ret;

	shift = _ATOMIC_BYTE_SHIFT(p);
	ret = (atomic_load_acq_32(_ATOMIC_WORD_ALIGNED(p)) >> shift) & 0xff;
	return (ret);
}
#endif

#ifndef atomic_load_acq_16
static __inline uint16_t
atomic_load_acq_16(volatile uint16_t *p)
{
	int shift;
	uint16_t ret;

	shift = _ATOMIC_HWORD_SHIFT(p);
	ret = (atomic_load_acq_32(_ATOMIC_WORD_ALIGNED(p)) >> shift) &
	    0xffff;
	return (ret);
}
#endif

#undef _ATOMIC_WORD_ALIGNED
#undef _ATOMIC_BYTE_SHIFT
#undef _ATOMIC_HWORD_SHIFT

/*
 * Provide generic testandset_long implementation based on fcmpset long
 * primitive.  It may not be ideal for any given arch, so machine/atomic.h
 * should define the macro atomic_testandset_long to override with an
 * MD-specific version.
 *
 * (Organizationally, this isn't really subword atomics.  But atomic_common is
 * included too early in machine/atomic.h, so it isn't a good place for derived
 * primitives like this.)
 */
#ifndef atomic_testandset_acq_long
static __inline int
atomic_testandset_acq_long(volatile u_long *p, u_int v)
{
	u_long bit, old;
	bool ret;

	bit = (1ul << (v % (sizeof(*p) * NBBY)));

	old = atomic_load_acq_long(p);
	ret = false;
	while (!ret && (old & bit) == 0)
		ret = atomic_fcmpset_acq_long(p, &old, old | bit);

	return (!ret);
}
#endif

#ifndef atomic_testandset_long
static __inline int
atomic_testandset_long(volatile u_long *p, u_int v)
{
	u_long bit, old;
	bool ret;

	bit = (1ul << (v % (sizeof(*p) * NBBY)));

	old = atomic_load_long(p);
	ret = false;
	while (!ret && (old & bit) == 0)
		ret = atomic_fcmpset_long(p, &old, old | bit);

	return (!ret);
}
#endif

#ifndef atomic_testandclear_long
static __inline int
atomic_testandclear_long(volatile u_long *p, u_int v)
{
	u_long bit, old;
	bool ret;

	bit = (1ul << (v % (sizeof(*p) * NBBY)));

	old = atomic_load_long(p);
	ret = false;
	while (!ret && (old & bit) != 0)
		ret = atomic_fcmpset_long(p, &old, old & ~bit);

	return (ret);
}
#endif

#endif	/* _SYS__ATOMIC_SUBWORD_H_ */