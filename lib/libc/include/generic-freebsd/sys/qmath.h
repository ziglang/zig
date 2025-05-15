/*-
 * Copyright (c) 2018 Netflix, Inc.
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * Data types and APIs for fixed-point math based on the "Q" number format.
 *
 * Author: Lawrence Stewart <lstewart@netflix.com>
 *
 * The 3 LSBs of all base data types are reserved for embedded control data:
 *   bits 1-2 specify the radix point shift index i.e. 00,01,10,11 == 1,2,3,4
 *   bit 3 specifies the radix point shift index multiplier as 2 (0) or 16 (1)
 *
 * This scheme can therefore represent Q numbers with [2,4,6,8,16,32,48,64] bits
 * of precision after the binary radix point. The number of bits available for
 * the integral component depends on the underlying storage type chosen.
 */

#ifndef	_SYS_QMATH_H_
#define	_SYS_QMATH_H_

#include <machine/_stdint.h>

typedef int8_t		s8q_t;
typedef uint8_t		u8q_t;
typedef int16_t		s16q_t;
typedef uint16_t	u16q_t;
typedef int32_t		s32q_t;
typedef uint32_t	u32q_t;
typedef int64_t		s64q_t;
typedef uint64_t	u64q_t;
/* typedef int128_t	s128q_t; Not yet */
/* typedef uint128_t	u128q_t; Not yet */
typedef	s64q_t		smaxq_t;
typedef	u64q_t		umaxq_t;

#if defined(__GNUC__) && !defined(__clang__)
/* Ancient GCC hack to de-const, remove when GCC4 is removed. */
#define	Q_BT(q)		__typeof(1 * q)
#else
/* The underlying base type of 'q'. */
#define	Q_BT(q)		__typeof(q)
#endif

/* Type-cast variable 'v' to the same underlying type as 'q'. */
#define	Q_TC(q, v)	((__typeof(q))(v))

/* Number of total bits associated with the data type underlying 'q'. */
#define	Q_NTBITS(q)	((uint32_t)(sizeof(q) << 3))

/* Number of LSBs reserved for control data. */
#define	Q_NCBITS	((uint32_t)3)

/* Number of control-encoded bits reserved for fractional component data. */
#define	Q_NFCBITS(q) \
    ((uint32_t)(((Q_GCRAW(q) & 0x3) + 1) << ((Q_GCRAW(q) & 0x4) ? 4 : 1)))

/* Min/max number of bits that can be reserved for fractional component data. */
#define	Q_MINNFBITS(q)	((uint32_t)(2))
#define	Q_MAXNFBITS(q)	((uint32_t)(Q_NTBITS(q) - Q_SIGNED(q) - Q_NCBITS))

/*
 * Number of bits actually reserved for fractional component data. This can be
 * less than the value returned by Q_NFCBITS() as we treat any excess
 * control-encoded number of bits for the underlying data type as meaning all
 * available bits are reserved for fractional component data i.e. zero int bits.
 */
#define	Q_NFBITS(q) \
    (Q_NFCBITS(q) > Q_MAXNFBITS(q) ? Q_MAXNFBITS(q) : Q_NFCBITS(q))

/* Number of bits available for integer component data. */
#define	Q_NIBITS(q)	((uint32_t)(Q_NTBITS(q) - Q_RPSHFT(q) - Q_SIGNED(q)))

/* The radix point offset relative to the LSB. */
#define	Q_RPSHFT(q)	(Q_NCBITS + Q_NFBITS(q))

/* The sign bit offset relative to the LSB. */
#define	Q_SIGNSHFT(q)	(Q_NTBITS(q) - 1)

/* Set the sign bit to 0 ('isneg' is F) or 1 ('isneg' is T). */
#define	Q_SSIGN(q, isneg) \
    ((q) = ((Q_SIGNED(q) && (isneg)) ?	(q) | (1ULL << Q_SIGNSHFT(q)) : \
					(q) & ~(1ULL << Q_SIGNSHFT(q))))

/* Manipulate the 'q' bits holding control/sign data. */
#define	Q_CRAWMASK(q)	0x7ULL
#define	Q_SRAWMASK(q)	(1ULL << Q_SIGNSHFT(q))
#define	Q_GCRAW(q)	((q) & Q_CRAWMASK(q))
#define	Q_GCVAL(q)	Q_GCRAW(q)
#define	Q_SCVAL(q, cv)	((q) = ((q) & ~Q_CRAWMASK(q)) | (cv))

/* Manipulate the 'q' bits holding combined integer/fractional data. */
#define	Q_IFRAWMASK(q) \
    Q_TC(q, Q_SIGNED(q) ? ~(Q_SRAWMASK(q) | Q_CRAWMASK(q)) : ~Q_CRAWMASK(q))
#define	Q_IFMAXVAL(q)	Q_TC(q, Q_IFRAWMASK(q) >> Q_NCBITS)
#define	Q_IFMINVAL(q)	Q_TC(q, Q_SIGNED(q) ? -Q_IFMAXVAL(q) : 0)
#define	Q_IFVALIMASK(q)	Q_TC(q, ~Q_IFVALFMASK(q))
#define	Q_IFVALFMASK(q)	Q_TC(q, (1ULL << Q_NFBITS(q)) - 1)
#define	Q_GIFRAW(q)	Q_TC(q, (q) & Q_IFRAWMASK(q))
#define	Q_GIFABSVAL(q)	Q_TC(q, Q_GIFRAW(q) >> Q_NCBITS)
#define	Q_GIFVAL(q)	Q_TC(q, Q_LTZ(q) ? -Q_GIFABSVAL(q) : Q_GIFABSVAL(q))
#define	Q_SIFVAL(q, ifv) \
    ((q) = ((q) & (~(Q_SRAWMASK(q) | Q_IFRAWMASK(q)))) | \
    (Q_TC(q, Q_ABS(ifv)) << Q_NCBITS) | \
    (Q_LTZ(ifv) ? 1ULL << Q_SIGNSHFT(q) : 0))
#define	Q_SIFVALS(q, iv, fv) \
    ((q) = ((q) & (~(Q_SRAWMASK(q) | Q_IFRAWMASK(q)))) | \
    (Q_TC(q, Q_ABS(iv)) << Q_RPSHFT(q)) | \
    (Q_TC(q, Q_ABS(fv)) << Q_NCBITS) | \
    (Q_LTZ(iv) || Q_LTZ(fv) ? 1ULL << Q_SIGNSHFT(q) : 0))

/* Manipulate the 'q' bits holding integer data. */
#define	Q_IRAWMASK(q)	Q_TC(q, Q_IFRAWMASK(q) & ~Q_FRAWMASK(q))
#define	Q_IMAXVAL(q)	Q_TC(q, Q_IRAWMASK(q) >> Q_RPSHFT(q))
#define	Q_IMINVAL(q)	Q_TC(q, Q_SIGNED(q) ? -Q_IMAXVAL(q) : 0)
#define	Q_GIRAW(q)	Q_TC(q, (q) & Q_IRAWMASK(q))
#define	Q_GIABSVAL(q)	Q_TC(q, Q_GIRAW(q) >> Q_RPSHFT(q))
#define	Q_GIVAL(q)	Q_TC(q, Q_LTZ(q) ? -Q_GIABSVAL(q) : Q_GIABSVAL(q))
#define	Q_SIVAL(q, iv) \
    ((q) = ((q) & ~(Q_SRAWMASK(q) | Q_IRAWMASK(q))) | \
    (Q_TC(q, Q_ABS(iv)) << Q_RPSHFT(q)) | \
    (Q_LTZ(iv) ? 1ULL << Q_SIGNSHFT(q) : 0))

/* Manipulate the 'q' bits holding fractional data. */
#define	Q_FRAWMASK(q)	Q_TC(q, ((1ULL << Q_NFBITS(q)) - 1) << Q_NCBITS)
#define	Q_FMAXVAL(q)	Q_TC(q, Q_FRAWMASK(q) >> Q_NCBITS)
#define	Q_GFRAW(q)	Q_TC(q, (q) & Q_FRAWMASK(q))
#define	Q_GFABSVAL(q)	Q_TC(q, Q_GFRAW(q) >> Q_NCBITS)
#define	Q_GFVAL(q)	Q_TC(q, Q_LTZ(q) ? -Q_GFABSVAL(q) : Q_GFABSVAL(q))
#define	Q_SFVAL(q, fv) \
    ((q) = ((q) & ~(Q_SRAWMASK(q) | Q_FRAWMASK(q))) | \
    (Q_TC(q, Q_ABS(fv)) << Q_NCBITS) | \
    (Q_LTZ(fv) ? 1ULL << Q_SIGNSHFT(q) : 0))

/*
 * Calculate the number of bits required per 'base' digit, rounding up or down
 * for non power-of-two bases.
 */
#define	Q_BITSPERBASEDOWN(base) (flsll(base) - 1)
#define	Q_BITSPERBASEUP(base) (flsll(base) - (__builtin_popcountll(base) == 1))
#define	Q_BITSPERBASE(base, rnd) Q_BITSPERBASE##rnd(base)

/*
 * Upper bound number of digits required to render 'nbits' worth of integer
 * component bits with numeric base 'base'. Overestimates for power-of-two
 * bases.
 */
#define	Q_NIBITS2NCHARS(nbits, base)					\
({									\
 	int _bitsperbase = Q_BITSPERBASE(base, DOWN);			\
	(((nbits) + _bitsperbase - 1) / _bitsperbase);			\
})

#define	Q_NFBITS2NCHARS(nbits, base) (nbits)

/*
 * Maximum number of chars required to render 'q' as a C-string of base 'base'.
 * Includes space for sign, radix point and NUL-terminator.
 */
#define	Q_MAXSTRLEN(q, base) \
    (2 + Q_NIBITS2NCHARS(Q_NIBITS(q), base) + \
    Q_NFBITS2NCHARS(Q_NFBITS(q), base) + Q_SIGNED(q))

/* Yield the next char from integer bits. */
#define	Q_IBITS2CH(q, bits, base)					\
({									\
    __typeof(bits) _tmp = (bits) / (base);				\
    int _idx = (bits) - (_tmp * (base));				\
    (bits) = _tmp;							\
    "0123456789abcdef"[_idx];						\
})

/* Yield the next char from fractional bits. */
#define	Q_FBITS2CH(q, bits, base)					\
({									\
    int _carry = 0, _idx, _nfbits = Q_NFBITS(q), _shift = 0;		\
    /*									\
     * Normalise enough MSBs to yield the next digit, multiply by the	\
     * base, and truncate residual fractional bits post multiplication.	\
     */									\
    if (_nfbits > Q_BITSPERBASEUP(base)) {				\
        /* Break multiplication into two steps to ensure no overflow. */\
        _shift = _nfbits >> 1;						\
        _carry = (((bits) & ((1ULL << _shift) - 1)) * (base)) >> _shift;\
    }									\
    _idx = ((((bits) >> _shift) * (base)) + _carry) >> (_nfbits - _shift);\
    (bits) *= (base); /* With _idx computed, no overflow concern. */	\
    (bits) &= (1ULL << _nfbits) - 1; /* Exclude residual int bits. */	\
    "0123456789abcdef"[_idx];						\
})

/*
 * Render the C-string representation of 'q' into 's'. Returns a pointer to the
 * final '\0' to allow for easy calculation of the rendered length and easy
 * appending to the C-string.
 */
#define	Q_TOSTR(q, prec, base, s, slen)					\
({									\
	char *_r, *_s = s;						\
	int _i;								\
	if (Q_LTZ(q) && ((ptrdiff_t)(slen)) > 0)			\
		*_s++ = '-';						\
	Q_BT(q) _part = Q_GIABSVAL(q);					\
	_r = _s;							\
	do {								\
		/* Render integer chars in reverse order. */		\
		if ((_s - (s)) < ((ptrdiff_t)(slen)))			\
			*_s++ = Q_IBITS2CH(q, _part, base);		\
		else							\
			_r = NULL;					\
	} while (_part > 0 && _r != NULL);				\
	if (!((_s - (s)) < ((ptrdiff_t)(slen))))			\
		_r = NULL;						\
	_i = (_s - _r) >> 1; /* N digits requires int(N/2) swaps. */	\
	while (_i-- > 0 && _r != NULL) {				\
		/* Work from middle out to reverse integer chars. */	\
		*_s = *(_r + _i); /* Stash LHS char temporarily. */	\
		*(_r + _i) = *(_s - _i - 1); /* Copy RHS char to LHS. */\
		*(_s - _i - 1) = *_s; /* Copy LHS char to RHS. */	\
	}								\
	_i = (prec);							\
	if (_i != 0 && _r != NULL) {					\
		if ((_s - (s)) < ((ptrdiff_t)(slen)))			\
			*_s++ = '.';					\
		else							\
			_r = NULL;					\
		_part = Q_GFABSVAL(q);					\
		if (_i < 0 || _i > (int)Q_NFBITS(q))			\
			_i = Q_NFBITS(q);				\
		while (_i-- > 0 && _r != NULL) {			\
			/* Render fraction chars in correct order. */	\
			if ((_s - (s)) < ((ptrdiff_t)(slen)))		\
				*_s++ = Q_FBITS2CH(q, _part, base);	\
			else						\
				_r = NULL;				\
		}							\
	}								\
	if ((_s - (s)) < ((ptrdiff_t)(slen)) && _r != NULL)		\
		*_s = '\0';						\
	else {								\
		_r = NULL;						\
		if (((ptrdiff_t)(slen)) > 0)				\
			*(s) = '\0';					\
	}								\
	/* Return a pointer to the '\0' or NULL on overflow. */		\
	(_r != NULL ? _s : _r);						\
})

/* Left shift an integral value to align with the int bits of 'q'. */
#define	Q_SHL(q, iv) \
    (Q_LTZ(iv) ? -(int64_t)(Q_ABS(iv) << Q_NFBITS(q)) :	\
    Q_TC(q, iv) << Q_NFBITS(q))

/* Calculate the relative fractional precision between 'a' and 'b' in bits. */
#define	Q_RELPREC(a, b)	((int)Q_NFBITS(a) - (int)Q_NFBITS(b))

/*
 * Determine control bits for the desired 'rpshft' radix point shift. Rounds up
 * to the nearest valid shift supported by the encoding scheme.
 */
#define	Q_CTRLINI(rpshft) \
    (((rpshft) <= 8) ? (((rpshft) - 1) >> 1) : (0x4 | (((rpshft) - 1) >> 4)))

/*
 * Convert decimal fractional value 'dfv' to its binary-encoded representation
 * with 'nfbits' of binary precision. 'dfv' must be passed as a preprocessor
 * literal to preserve leading zeroes. The returned result can be used to set a
 * Q number's fractional bits e.g. using Q_SFVAL().
 */
#define	Q_DFV2BFV(dfv, nfbits)				\
({							\
	uint64_t _bfv = 0, _thresh = 5, _tmp = dfv;	\
	int _i = sizeof(""#dfv) - 1;			\
	/*						\
	 * Compute decimal threshold to determine which \
	 * conversion rounds will yield a binary 1.	\
	 */						\
	while (--_i > 0) {_thresh *= 10;}		\
	_i = (nfbits) - 1;				\
	while (_i >= 0) {				\
		if (_thresh <= _tmp) {			\
			_bfv |= 1ULL << _i;		\
			_tmp = _tmp - _thresh;		\
		}					\
		_i--; _tmp <<= 1;			\
	}						\
	_bfv;						\
})

/*
 * Initialise 'q' with raw integer value 'iv', decimal fractional value 'dfv',
 * and radix point shift 'rpshft'. Must be done in two steps in case 'iv'
 * depends on control bits being set e.g. when passing Q_INTMAX(q) as 'iv'.
 */
#define	Q_INI(q, iv, dfv, rpshft) \
({ \
    (*(q)) = Q_CTRLINI(rpshft); \
    Q_SIFVALS(*(q), iv, Q_DFV2BFV(dfv, Q_NFBITS(*(q)))); \
})

/* Test if 'a' and 'b' fractional precision is the same (T) or not (F). */
#define	Q_PRECEQ(a, b)	(Q_NFBITS(a) == Q_NFBITS(b))

/* Test if 'n' is a signed type (T) or not (F). Works with any numeric type. */
#define	Q_SIGNED(n)	(Q_TC(n, -1) < 0)

/*
 * Test if 'n' is negative. Works with any numeric type that uses the MSB as the
 * sign bit, and also works with Q numbers.
 */
#define	Q_LTZ(n)	(Q_SIGNED(n) && ((n) & Q_SRAWMASK(n)))

/*
 * Return absolute value of 'n'. Works with any standard numeric type that uses
 * the MSB as the sign bit, and is signed/unsigned type safe.
 * Does not work with Q numbers; use Q_QABS() instead.
 */
#define	Q_ABS(n)	(Q_LTZ(n) ? -(n) : (n))

/*
 * Return an absolute value interpretation of 'q'.
 */
#define	Q_QABS(q)	(Q_SIGNED(q) ? (q) & ~Q_SRAWMASK(q) : (q))

/* Convert 'q' to float or double representation. */
#define	Q_Q2F(q)	((float)Q_GIFVAL(q) / (float)(1ULL << Q_NFBITS(q)))
#define	Q_Q2D(q)	((double)Q_GIFVAL(q) / (double)(1ULL << Q_NFBITS(q)))

/* Numerically compare 'a' and 'b' as whole numbers using provided operators. */
#define	Q_QCMPQ(a, b, intcmp, fraccmp) \
    ((Q_GIVAL(a) intcmp Q_GIVAL(b)) || \
    ((Q_GIVAL(a) == Q_GIVAL(b)) && (Q_GFVAL(a) fraccmp Q_GFVAL(b))))

/* Test if 'a' is numerically less than 'b' (T) or not (F). */
#define	Q_QLTQ(a, b)	Q_QCMPQ(a, b, <, <)

/* Test if 'a' is numerically less than or equal to 'b' (T) or not (F). */
#define	Q_QLEQ(a, b)	Q_QCMPQ(a, b, <, <=)

/* Test if 'a' is numerically greater than 'b' (T) or not (F). */
#define	Q_QGTQ(a, b)	Q_QCMPQ(a, b, >, >)

/* Test if 'a' is numerically greater than or equal to 'b' (T) or not (F). */
#define	Q_QGEQ(a, b)	Q_QCMPQ(a, b, >, >=)

/* Test if 'a' is numerically equal to 'b' (T) or not (F). */
#define	Q_QEQ(a, b)	Q_QCMPQ(a, b, ==, ==)

/* Test if 'a' is numerically not equal to 'b' (T) or not (F). */
#define	Q_QNEQ(a, b)	Q_QCMPQ(a, b, !=, !=)

/* Returns the numerically larger of 'a' and 'b'. */
#define	Q_QMAXQ(a, b)	(Q_GT(a, b) ? (a) : (b))

/* Returns the numerically smaller of 'a' and 'b'. */
#define	Q_QMINQ(a, b)	(Q_LT(a, b) ? (a) : (b))

/*
 * Test if 'a' can be represented by 'b' with full accuracy (T) or not (F).
 * The type casting has to be done to a's type so that any truncation caused by
 * the casts will not affect the logic.
 */
#define	Q_QCANREPQ(a, b) \
    ((((Q_LTZ(a) && Q_SIGNED(b)) || !Q_LTZ(a)) && \
    Q_GIABSVAL(a) <= Q_TC(a, Q_IMAXVAL(b)) && \
    Q_GFABSVAL(a) <= Q_TC(a, Q_FMAXVAL(b))) ? \
    0 : EOVERFLOW)

/* Test if raw integer value 'i' can be represented by 'q' (T) or not (F). */
#define	Q_QCANREPI(q, i) \
    ((((Q_LTZ(i) && Q_SIGNED(q)) || !Q_LTZ(i)) && \
    Q_ABS(i) <= Q_TC(i, Q_IMAXVAL(q))) ? 0 : EOVERFLOW)

/*
 * Returns a Q variable debug format string with appropriate modifiers and
 * padding relevant to the underlying Q data type.
 */
#define	Q_DEBUGFMT_(prefmt, postfmt, mod, hexpad)			\
    prefmt								\
    /* Var name + address. */						\
    "\"%s\"@%p"								\
    /* Data type. */							\
    "\n\ttype=%c%dq_t, "						\
    /* Qm.n notation; 'm' = # int bits, 'n' = # frac bits. */		\
    "Qm.n=Q%d.%d, "							\
    /* Radix point shift relative to the underlying data type's LSB. */	\
    "rpshft=%d, "							\
    /* Min/max integer values which can be represented. */		\
    "imin=0x%0" #mod "x, "						\
    "imax=0x%0" #mod "x"						\
    /* Raw hex dump of all bits. */					\
    "\n\tqraw=0x%0" #hexpad #mod "x"					\
    /* Bit masks for int/frac/ctrl bits. */				\
    "\n\timask=0x%0" #hexpad #mod "x, "					\
    "fmask=0x%0" #hexpad #mod "x, "					\
    "cmask=0x%0" #hexpad #mod "x, "					\
    "ifmask=0x%0" #hexpad #mod "x"					\
    /* Hex dump of masked int bits; 'iraw' includes shift */		\
    "\n\tiraw=0x%0" #hexpad #mod "x, "					\
    "iabsval=0x%" #mod "x, "						\
    "ival=0x%" #mod "x"					\
    /* Hex dump of masked frac bits; 'fraw' includes shift */		\
    "\n\tfraw=0x%0" #hexpad #mod "x, "					\
    "fabsval=0x%" #mod "x, "						\
    "fval=0x%" #mod "x"							\
    "%s"								\
    postfmt

#define	Q_DEBUGFMT(q, prefmt, postfmt)					\
      sizeof(q) == 8 ? Q_DEBUGFMT_(prefmt, postfmt, j, 16)	:	\
      sizeof(q) == 4 ? Q_DEBUGFMT_(prefmt, postfmt,  , 8)	:	\
      sizeof(q) == 2 ? Q_DEBUGFMT_(prefmt, postfmt, h, 4)	:	\
      sizeof(q) == 1 ? Q_DEBUGFMT_(prefmt, postfmt, hh, 2)	:	\
      prefmt "\"%s\"@%p: invalid" postfmt				\

/*
 * Returns a format string and data suitable for printf-like rendering
 * e.g. Print to console with a trailing newline: printf(Q_DEBUG(q, "", "\n"));
 */
#define	Q_DEBUG(q, prefmt, postfmt, incfmt)				\
      Q_DEBUGFMT(q, prefmt, postfmt)					\
    , #q								\
    , &(q)								\
    , Q_SIGNED(q) ? 's' : 'u'						\
    , Q_NTBITS(q)							\
    , Q_NIBITS(q)							\
    , Q_NFBITS(q)							\
    , Q_RPSHFT(q)							\
    , Q_IMINVAL(q)							\
    , Q_IMAXVAL(q)							\
    , (q)								\
    , Q_IRAWMASK(q)							\
    , Q_FRAWMASK(q)							\
    , Q_TC(q, Q_CRAWMASK(q))						\
    , Q_IFRAWMASK(q)							\
    , Q_GIRAW(q)							\
    , Q_GIABSVAL(q)							\
    , Q_GIVAL(q)							\
    , Q_GFRAW(q)							\
    , Q_GFABSVAL(q)							\
    , Q_GFVAL(q)							\
    , (incfmt) ? Q_DEBUGFMT(q, "\nfmt:", "") : ""			\

/*
 * If precision differs, attempt to normalise to the greater precision that
 * preserves the integer component of both 'a' and 'b'.
 */
#define	Q_NORMPREC(a, b)						\
({									\
	int _perr = 0, _relprec = Q_RELPREC(*(a), b);			\
	if (_relprec != 0)						\
		_perr = ERANGE; /* XXXLAS: Do precision normalisation! */\
	_perr;								\
})

/* Clone r's control bits and int/frac value into 'l'. */
#define	Q_QCLONEQ(l, r)							\
({									\
	Q_BT(*(l)) _l = Q_GCVAL(r);					\
	int _err = Q_QCANREPQ(r, _l);					\
	if (!_err) {							\
		*(l) = _l;						\
		Q_SIFVAL(*(l), Q_GIFVAL(r));				\
	}								\
	_err;								\
})

/* Copy r's int/frac vals into 'l', retaining 'l's precision and signedness. */
#define	Q_QCPYVALQ(l, r)						\
({									\
	int _err = Q_QCANREPQ(r, *(l));					\
	if (!_err)							\
		Q_SIFVALS(*(l), Q_GIVAL(r), Q_GFVAL(r));		\
	_err;								\
})

#define	Q_QADDSUBQ(a, b, eop)						\
({									\
	int _aserr;							\
	if ((_aserr = Q_NORMPREC(a, b))) while (0); /* NOP */		\
	else if ((eop) == '+') {					\
		if (Q_IFMAXVAL(*(a)) - Q_GIFABSVAL(b) < Q_GIFVAL(*(a)))	\
			_aserr = EOVERFLOW; /* [+/-a + +b] > max(a) */	\
		else							\
			Q_SIFVAL(*(a), Q_GIFVAL(*(a)) + Q_TC(*(a),	\
			    Q_GIFABSVAL(b)));				\
	} else { /* eop == '-' */					\
		if (Q_IFMINVAL(*(a)) + Q_GIFABSVAL(b) > Q_GIFVAL(*(a)))	\
			_aserr = EOVERFLOW; /* [+/-a - +b] < min(a) */	\
		else							\
			Q_SIFVAL(*(a), Q_GIFVAL(*(a)) - Q_TC(*(a),	\
			    Q_GIFABSVAL(b)));				\
	}								\
	_aserr;								\
})
#define	Q_QADDQ(a, b) Q_QADDSUBQ(a, b, (Q_LTZ(b) ? '-' : '+'))
#define	Q_QSUBQ(a, b) Q_QADDSUBQ(a, b, (Q_LTZ(b) ? '+' : '-'))

#define	Q_QDIVQ(a, b)							\
({									\
	int _err;							\
	if ((_err = Q_NORMPREC(a, b))) while (0); /* NOP */		\
	else if (Q_GIFABSVAL(b) == 0 || (!Q_SIGNED(*(a)) && Q_LTZ(b)))	\
		_err = EINVAL; /* Divide by zero or cannot represent. */\
	/* XXXLAS: Handle overflow. */					\
	else if (Q_GIFABSVAL(*(a)) != 0) { /* Result expected. */	\
		Q_SIFVAL(*(a),						\
		    ((Q_GIVAL(*(a)) << Q_NFBITS(*(a))) / Q_GIFVAL(b)) +	\
		    (Q_GFVAL(b) == 0 ? 0 :				\
		    ((Q_GFVAL(*(a)) << Q_NFBITS(*(a))) / Q_GFVAL(b))));	\
	}								\
	_err;								\
})

#define	Q_QMULQ(a, b)							\
({									\
	int _mulerr;							\
	if ((_mulerr = Q_NORMPREC(a, b))) while (0); /* NOP */		\
	else if (!Q_SIGNED(*(a)) && Q_LTZ(b))				\
		_mulerr = EINVAL;					\
	else if (Q_GIFABSVAL(b) != 0 &&					\
	    Q_IFMAXVAL(*(a)) / Q_GIFABSVAL(b) < Q_GIFABSVAL(*(a)))	\
		_mulerr = EOVERFLOW;					\
	else								\
		Q_SIFVAL(*(a), (Q_GIFVAL(*(a)) * Q_GIFVAL(b)) >>	\
		    Q_NFBITS(*(a)));					\
	_mulerr;							\
})

#define	Q_QCPYVALI(q, i)						\
({									\
	int _err = Q_QCANREPI(*(q), i);					\
	if (!_err)							\
		Q_SIFVAL(*(q), Q_SHL(*(q), i));				\
	_err;								\
})

#define	Q_QADDSUBI(q, i, eop)						\
({									\
	int _aserr = 0;							\
	if (Q_NTBITS(*(q)) < (uint32_t)flsll(Q_ABS(i)))			\
		_aserr = EOVERFLOW; /* i cannot fit in q's type. */	\
	else if ((eop) == '+') {					\
		if (Q_IMAXVAL(*(q)) - Q_TC(*(q), Q_ABS(i)) <		\
		    Q_GIVAL(*(q)))					\
			_aserr = EOVERFLOW; /* [+/-q + +i] > max(q) */	\
		else							\
			Q_SIFVAL(*(q), Q_GIFVAL(*(q)) +			\
			    Q_SHL(*(q), Q_ABS(i)));			\
	} else { /* eop == '-' */					\
		if (Q_IMINVAL(*(q)) + Q_ABS(i) > Q_GIVAL(*(q)))		\
			_aserr = EOVERFLOW; /* [+/-q - +i] < min(q) */	\
		else							\
			Q_SIFVAL(*(q), Q_GIFVAL(*(q)) -			\
			    Q_SHL(*(q), Q_ABS(i)));			\
	}								\
	_aserr;								\
})
#define	Q_QADDI(q, i) Q_QADDSUBI(q, i, (Q_LTZ(i) ? '-' : '+'))
#define	Q_QSUBI(q, i) Q_QADDSUBI(q, i, (Q_LTZ(i) ? '+' : '-'))

#define	Q_QDIVI(q, i)							\
({									\
	int _diverr = 0;						\
	if ((i) == 0 || (!Q_SIGNED(*(q)) && Q_LTZ(i)))			\
		_diverr = EINVAL; /* Divide by zero or cannot represent. */\
	else if (Q_GIFABSVAL(*(q)) != 0) { /* Result expected. */	\
		Q_SIFVAL(*(q), Q_GIFVAL(*(q)) / Q_TC(*(q), i));		\
		if (Q_GIFABSVAL(*(q)) == 0)				\
			_diverr = ERANGE; /* q underflow. */		\
	}								\
	_diverr;							\
})

#define	Q_QMULI(q, i)							\
({									\
	int _mulerr = 0;						\
	if (!Q_SIGNED(*(q)) && Q_LTZ(i))				\
		_mulerr = EINVAL; /* Cannot represent. */		\
	else if ((i) != 0 && Q_IFMAXVAL(*(q)) / Q_TC(*(q), Q_ABS(i)) <	\
	    Q_GIFABSVAL(*(q)))						\
		_mulerr = EOVERFLOW;					\
	else								\
		Q_SIFVAL(*(q), Q_GIFVAL(*(q)) * Q_TC(*(q), i));		\
	_mulerr;							\
})

#define	Q_QFRACI(q, in, id)						\
({									\
	uint64_t _tmp;							\
	int _err = 0;							\
	if ((id) == 0)							\
		_err = EINVAL; /* Divide by zero. */			\
	else if ((in) == 0)						\
		Q_SIFVAL(*(q), in);					\
	else if ((_tmp = Q_ABS(in)) > (UINT64_MAX >> Q_RPSHFT(*(q))))	\
		_err = EOVERFLOW; /* _tmp overflow. */			\
	else {								\
		_tmp = Q_SHL(*(q), _tmp) / Q_ABS(id);			\
		if (Q_QCANREPI(*(q), _tmp & Q_IFVALIMASK(*(q))))	\
			_err = EOVERFLOW; /* q overflow. */		\
		else {							\
			Q_SIFVAL(*(q), _tmp);				\
			Q_SSIGN(*(q), (Q_LTZ(in) && !Q_LTZ(id)) ||	\
			    (!Q_LTZ(in) && Q_LTZ(id)));			\
			if (_tmp == 0)					\
				_err = ERANGE; /* q underflow. */	\
		}							\
	}								\
	_err;								\
})

#endif	/* _SYS_QMATH_H_ */