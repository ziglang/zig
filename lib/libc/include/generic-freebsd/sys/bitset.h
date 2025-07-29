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

#ifndef _SYS_BITSET_H_
#define	_SYS_BITSET_H_

/*
 * Whether expr is both constant and true.  Result is itself constant.
 * Used to enable optimizations for sets with a known small size.
 */
#define	__constexpr_cond(expr)	(__builtin_constant_p((expr)) && (expr))

#define	__bitset_mask(_s, n)						\
	(1UL << (__constexpr_cond(__bitset_words((_s)) == 1) ?		\
	    (__size_t)(n) : ((n) % _BITSET_BITS)))

#define	__bitset_word(_s, n)						\
	(__constexpr_cond(__bitset_words((_s)) == 1) ?			\
	 0 : ((n) / _BITSET_BITS))

#define	__BIT_CLR(_s, n, p)						\
	((p)->__bits[__bitset_word(_s, n)] &= ~__bitset_mask((_s), (n)))

#define	__BIT_COPY(_s, f, t)	(void)(*(t) = *(f))

#define	__BIT_ISSET(_s, n, p)						\
	((((p)->__bits[__bitset_word(_s, n)] & __bitset_mask((_s), (n))) != 0))

#define	__BIT_SET(_s, n, p)						\
	((p)->__bits[__bitset_word(_s, n)] |= __bitset_mask((_s), (n)))

#define	__BIT_ZERO(_s, p) do {						\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(p)->__bits[__i] = 0L;					\
} while (0)

#define	__BIT_FILL(_s, p) do {						\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(p)->__bits[__i] = -1L;					\
} while (0)

#define	__BIT_SETOF(_s, n, p) do {					\
	__BIT_ZERO(_s, p);						\
	(p)->__bits[__bitset_word(_s, n)] = __bitset_mask((_s), (n));	\
} while (0)

/* Is p empty. */
#define	__BIT_EMPTY(_s, p) __extension__ ({				\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		if ((p)->__bits[__i])					\
			break;						\
	__i == __bitset_words((_s));					\
})

/* Is p full set. */
#define	__BIT_ISFULLSET(_s, p) __extension__ ({				\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		if ((p)->__bits[__i] != (long)-1)			\
			break;						\
	__i == __bitset_words((_s));					\
})

/* Is c a subset of p. */
#define	__BIT_SUBSET(_s, p, c) __extension__ ({				\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		if (((c)->__bits[__i] &					\
		    (p)->__bits[__i]) !=				\
		    (c)->__bits[__i])					\
			break;						\
	__i == __bitset_words((_s));					\
})

/* Are there any common bits between b & c? */
#define	__BIT_OVERLAP(_s, p, c) __extension__ ({	       		\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		if (((c)->__bits[__i] &					\
		    (p)->__bits[__i]) != 0)				\
			break;						\
	__i != __bitset_words((_s));					\
})

/* Compare two sets, returns 0 if equal 1 otherwise. */
#define	__BIT_CMP(_s, p, c) __extension__ ({				\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		if (((c)->__bits[__i] !=				\
		    (p)->__bits[__i]))					\
			break;						\
	__i != __bitset_words((_s));					\
})

#define	__BIT_OR(_s, d, s) do {						\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(d)->__bits[__i] |= (s)->__bits[__i];			\
} while (0)

#define	__BIT_OR2(_s, d, s1, s2) do {					\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(d)->__bits[__i] = (s1)->__bits[__i] | (s2)->__bits[__i];\
} while (0)

#define	__BIT_ORNOT(_s, d, s) do {					\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(d)->__bits[__i] |= ~(s)->__bits[__i];			\
} while (0)

#define	__BIT_ORNOT2(_s, d, s1, s2) do {				\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(d)->__bits[__i] = (s1)->__bits[__i] | ~(s2)->__bits[__i];\
} while (0)

#define	__BIT_AND(_s, d, s) do {					\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(d)->__bits[__i] &= (s)->__bits[__i];			\
} while (0)

#define	__BIT_AND2(_s, d, s1, s2) do {					\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(d)->__bits[__i] = (s1)->__bits[__i] & (s2)->__bits[__i];\
} while (0)

#define	__BIT_ANDNOT(_s, d, s) do {					\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(d)->__bits[__i] &= ~(s)->__bits[__i];			\
} while (0)

#define	__BIT_ANDNOT2(_s, d, s1, s2) do {				\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(d)->__bits[__i] = (s1)->__bits[__i] & ~(s2)->__bits[__i];\
} while (0)

#define	__BIT_XOR(_s, d, s) do {					\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(d)->__bits[__i] ^= (s)->__bits[__i];			\
} while (0)

#define	__BIT_XOR2(_s, d, s1, s2) do {					\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		(d)->__bits[__i] = (s1)->__bits[__i] ^ (s2)->__bits[__i];\
} while (0)

/*
 * Note, the atomic(9) API is not consistent between clear/set and
 * testandclear/testandset in whether the value argument is a mask
 * or a bit index.
 */

#define	__BIT_CLR_ATOMIC(_s, n, p)					\
	atomic_clear_long(&(p)->__bits[__bitset_word(_s, n)],		\
	    __bitset_mask((_s), n))

#define	__BIT_SET_ATOMIC(_s, n, p)					\
	atomic_set_long(&(p)->__bits[__bitset_word(_s, n)],		\
	    __bitset_mask((_s), n))

#define	__BIT_SET_ATOMIC_ACQ(_s, n, p)					\
	atomic_set_acq_long(&(p)->__bits[__bitset_word(_s, n)],		\
	    __bitset_mask((_s), n))

#define	__BIT_TEST_CLR_ATOMIC(_s, n, p)					\
	(atomic_testandclear_long(					\
	    &(p)->__bits[__bitset_word((_s), (n))], (n)) != 0)

#define	__BIT_TEST_SET_ATOMIC(_s, n, p)					\
	(atomic_testandset_long(					\
	    &(p)->__bits[__bitset_word((_s), (n))], (n)) != 0)

/* Convenience functions catering special cases. */
#define	__BIT_AND_ATOMIC(_s, d, s) do {					\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		atomic_clear_long(&(d)->__bits[__i],			\
		    ~(s)->__bits[__i]);					\
} while (0)

#define	__BIT_OR_ATOMIC(_s, d, s) do {					\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		atomic_set_long(&(d)->__bits[__i],			\
		    (s)->__bits[__i]);					\
} while (0)

#define	__BIT_COPY_STORE_REL(_s, f, t) do {				\
	__size_t __i;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		atomic_store_rel_long(&(t)->__bits[__i],		\
		    (f)->__bits[__i]);					\
} while (0)

/*
 * 'start' is a 0-based bit index.  By contrast, and as for ffs(), the returned
 * index is 1-based, 0 being reserved to indicate that no bits are set.
 */
#define	__BIT_FFS_AT(_s, p, start) __extension__ ({			\
	__size_t __i;							\
	long __bit, __mask;						\
									\
	__mask = ~0UL << ((start) % _BITSET_BITS);			\
	__bit = 0;							\
	for (__i = __bitset_word((_s), (start));			\
	    __i < __bitset_words((_s));					\
	    __i++) {							\
		if (((p)->__bits[__i] & __mask) != 0) {			\
			__bit = ffsl((p)->__bits[__i] & __mask);	\
			__bit += __i * _BITSET_BITS;			\
			break;						\
		}							\
		__mask = ~0UL;						\
	}								\
	__bit;								\
})

#define	__BIT_FFS(_s, p) __BIT_FFS_AT((_s), (p), 0)

#define	__BIT_FLS(_s, p) __extension__ ({			       	\
	__size_t __i;							\
	long __bit;							\
									\
	__bit = 0;							\
	for (__i = __bitset_words((_s)); __i > 0; __i--) {		\
		if ((p)->__bits[__i - 1] != 0) {			\
			__bit = flsl((p)->__bits[__i - 1]);		\
			__bit += (__i - 1) * _BITSET_BITS;		\
			break;						\
		}							\
	}								\
	__bit;								\
})

#define	__BIT_COUNT(_s, p) __extension__ ({				\
	__size_t __i;							\
	long __count;							\
									\
	__count = 0;							\
	for (__i = 0; __i < __bitset_words((_s)); __i++)		\
		__count += __bitcountl((p)->__bits[__i]);		\
	__count;							\
})

#define	__BIT_FOREACH_ADVANCE(_s, i, p, op) __extension__ ({		\
	int __found;							\
	for (;;) {							\
		if (__bits != 0) {					\
			int __bit = ffsl(__bits) - 1;			\
			__bits &= ~(1ul << __bit);			\
			(i) = __i * _BITSET_BITS + __bit;		\
			__found = 1;					\
			break;						\
		}							\
		if (++__i == __bitset_words(_s)) {			\
			__found = 0;					\
			break;						\
		}							\
		__bits = op((p)->__bits[__i]);				\
	}								\
	__found != 0;							\
})

/*
 * Non-destructively loop over all set or clear bits in the set.
 */
#define __BIT_FOREACH(_s, i, p, op)					\
	for (long __i = -1, __bits = 0;					\
	    __BIT_FOREACH_ADVANCE(_s, i, p, op); )

#define	__BIT_FOREACH_ISSET(_s, i, p)	__BIT_FOREACH(_s, i, p, )
#define	__BIT_FOREACH_ISCLR(_s, i, p)	__BIT_FOREACH(_s, i, p, ~)

#define	__BITSET_T_INITIALIZER(x)					\
	{ .__bits = { x } }

#define	__BITSET_FSET(n)						\
	[ 0 ... ((n) - 1) ] = (-1L)

#define	__BITSET_SIZE(_s)	(__bitset_words((_s)) * sizeof(long))

#if defined(_KERNEL) || defined(_WANT_FREEBSD_BITSET)
#define	BIT_AND(_s, d, s)			__BIT_AND(_s, d, s)
#define	BIT_AND2(_s, d, s1, s2)			__BIT_AND2(_s, d, s1, s2)
#define	BIT_ANDNOT(_s, d, s)			__BIT_ANDNOT(_s, d, s)
#define	BIT_ANDNOT2(_s, d, s1, s2)		__BIT_ANDNOT2(_s, d, s1, s2)
#define	BIT_AND_ATOMIC(_s, d, s)		__BIT_AND_ATOMIC(_s, d, s)
#define	BIT_CLR(_s, n, p)			__BIT_CLR(_s, n, p)
#define	BIT_CLR_ATOMIC(_s, n, p)		__BIT_CLR_ATOMIC(_s, n, p)
#define	BIT_CMP(_s, p, c)			__BIT_CMP(_s, p, c)
#define	BIT_COPY(_s, f, t)			__BIT_COPY(_s, f, t)
#define	BIT_COPY_STORE_REL(_s, f, t)		__BIT_COPY_STORE_REL(_s, f, t)
#define	BIT_COUNT(_s, p)			__BIT_COUNT(_s, p)
#define	BIT_EMPTY(_s, p)			__BIT_EMPTY(_s, p)
#define	BIT_FFS(_s, p)				__BIT_FFS(_s, p)
#define	BIT_FFS_AT(_s, p, start)		__BIT_FFS_AT(_s, p, start)
#define	BIT_FILL(_s, p)				__BIT_FILL(_s, p)
#define	BIT_FLS(_s, p)				__BIT_FLS(_s, p)
#define	BIT_FOREACH(_s, i, p, op)		__BIT_FOREACH(_s, i, p, op)
#define	BIT_FOREACH_ISCLR(_s, i, p)		__BIT_FOREACH_ISCLR(_s, i, p)
#define	BIT_FOREACH_ISSET(_s, i, p)		__BIT_FOREACH_ISSET(_s, i, p)
#define	BIT_ISFULLSET(_s, p)			__BIT_ISFULLSET(_s, p)
#define	BIT_ISSET(_s, n, p)			__BIT_ISSET(_s, n, p)
#define	BIT_OR(_s, d, s)			__BIT_OR(_s, d, s)
#define	BIT_OR2(_s, d, s1, s2)			__BIT_OR2(_s, d, s1, s2)
#define	BIT_ORNOT(_s, d, s)			__BIT_ORNOT(_s, d, s)
#define	BIT_ORNOT2(_s, d, s1, s2)		__BIT_ORNOT2(_s, d, s1, s2)
#define	BIT_OR_ATOMIC(_s, d, s)			__BIT_OR_ATOMIC(_s, d, s)
#define	BIT_OVERLAP(_s, p, c)			__BIT_OVERLAP(_s, p, c)
#define	BIT_SET(_s, n, p)			__BIT_SET(_s, n, p)
#define	BIT_SETOF(_s, n, p)			__BIT_SETOF(_s, n, p)
#define	BIT_SET_ATOMIC(_s, n, p)		__BIT_SET_ATOMIC(_s, n, p)
#define	BIT_SET_ATOMIC_ACQ(_s, n, p)		__BIT_SET_ATOMIC_ACQ(_s, n, p)
#define	BIT_SUBSET(_s, p, c)			__BIT_SUBSET(_s, p, c)
#define	BIT_TEST_CLR_ATOMIC(_s, n, p)		__BIT_TEST_CLR_ATOMIC(_s, n, p)
#define	BIT_TEST_SET_ATOMIC(_s, n, p)		__BIT_TEST_SET_ATOMIC(_s, n, p)
#define	BIT_XOR(_s, d, s)			__BIT_XOR(_s, d, s)
#define	BIT_XOR2(_s, d, s1, s2)			__BIT_XOR2(_s, d, s1, s2)
#define	BIT_ZERO(_s, p)				__BIT_ZERO(_s, p)

#if defined(_KERNEL)
/*
 * Dynamically allocate a bitset.
 */
#define BITSET_ALLOC(_s, mt, mf)		malloc(__BITSET_SIZE((_s)), mt, (mf))
#define	BITSET_FREE(p, mt)			free(p, mt)
#endif /* _KERNEL */

#define	BITSET_FSET(n)				__BITSET_FSET(n)
#define	BITSET_SIZE(_s)				__BITSET_SIZE(_s)
#define	BITSET_T_INITIALIZER(x)			__BITSET_T_INITIALIZER(x)
#endif /* defined(_KERNEL) || defined(_WANT_FREEBSD_BITSET) */

#endif /* !_SYS_BITSET_H_ */