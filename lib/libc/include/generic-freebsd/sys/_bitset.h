/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2008, Jeffrey Roberson <jeff@freebsd.org>
 * All rights reserved.
 *
 * Copyright (c) 2008 Nokia Corporation
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS__BITSET_H_
#define	_SYS__BITSET_H_

/*
 * Macros addressing word and bit within it, tuned to make compiler
 * optimize cases when SETSIZE fits into single machine word.
 */
#define	_BITSET_BITS		(sizeof(long) * 8)

#define	__howmany(x, y)	(((x) + ((y) - 1)) / (y))

#define	__bitset_words(_s)	(__howmany(_s, _BITSET_BITS))

#define	__BITSET_DEFINE(_t, _s)						\
struct _t {								\
        long    __bits[__bitset_words((_s))];				\
}

/*
 * Helper to declare a bitset without it's size being a constant.
 *
 * Sadly we cannot declare a bitset struct with 'bits[]', because it's
 * the only member of the struct and the compiler complains.
 */
#define __BITSET_DEFINE_VAR(_t)	__BITSET_DEFINE(_t, 1)

/*
 * Define a default type that can be used while manually specifying size
 * to every call.
 */

#if defined(_KERNEL) || defined(_WANT_FREEBSD_BITSET)
__BITSET_DEFINE(bitset, 1);

#define	BITSET_DEFINE(_t, _s)	__BITSET_DEFINE(_t, _s)
#define	BITSET_DEFINE_VAR(_t)	__BITSET_DEFINE_VAR(_t)
#endif /* defined(_KERNEL) || defined(_WANT_FREEBSD_BITSET) */

#endif /* !_SYS__BITSET_H_ */