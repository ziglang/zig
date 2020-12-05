/*
 * Copyright (c) 2000, 2005, 2008 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*
 * Copyright (c) 1989, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
 *
 * This code is derived from software contributed to Berkeley by
 * Paul Borman at Krystal Technologies.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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
 *	@(#)ctype.h	8.4 (Berkeley) 1/21/94
 */

#ifndef	__CTYPE_H_
#define __CTYPE_H_

#include <sys/cdefs.h>
#include <runetype.h>

#define	_CTYPE_A	0x00000100L		/* Alpha */
#define	_CTYPE_C	0x00000200L		/* Control */
#define	_CTYPE_D	0x00000400L		/* Digit */
#define	_CTYPE_G	0x00000800L		/* Graph */
#define	_CTYPE_L	0x00001000L		/* Lower */
#define	_CTYPE_P	0x00002000L		/* Punct */
#define	_CTYPE_S	0x00004000L		/* Space */
#define	_CTYPE_U	0x00008000L		/* Upper */
#define	_CTYPE_X	0x00010000L		/* X digit */
#define	_CTYPE_B	0x00020000L		/* Blank */
#define	_CTYPE_R	0x00040000L		/* Print */
#define	_CTYPE_I	0x00080000L		/* Ideogram */
#define	_CTYPE_T	0x00100000L		/* Special */
#define	_CTYPE_Q	0x00200000L		/* Phonogram */
#define	_CTYPE_SW0	0x20000000L		/* 0 width character */
#define	_CTYPE_SW1	0x40000000L		/* 1 width character */
#define	_CTYPE_SW2	0x80000000L		/* 2 width character */
#define	_CTYPE_SW3	0xc0000000L		/* 3 width character */
#define	_CTYPE_SWM	0xe0000000L		/* Mask for screen width data */
#define	_CTYPE_SWS	30			/* Bits to shift to get width */

#ifdef _NONSTD_SOURCE
/*
 * Backward compatibility
 */
#define	_A		_CTYPE_A		/* Alpha */
#define	_C		_CTYPE_C		/* Control */
#define	_D		_CTYPE_D		/* Digit */
#define	_G		_CTYPE_G		/* Graph */
#define	_L		_CTYPE_L		/* Lower */
#define	_P		_CTYPE_P		/* Punct */
#define	_S		_CTYPE_S		/* Space */
#define	_U		_CTYPE_U		/* Upper */
#define	_X		_CTYPE_X		/* X digit */
#define	_B		_CTYPE_B		/* Blank */
#define	_R		_CTYPE_R		/* Print */
#define	_I		_CTYPE_I		/* Ideogram */
#define	_T		_CTYPE_T		/* Special */
#define	_Q		_CTYPE_Q		/* Phonogram */
#define	_SW0		_CTYPE_SW0		/* 0 width character */
#define	_SW1		_CTYPE_SW1		/* 1 width character */
#define	_SW2		_CTYPE_SW2		/* 2 width character */
#define	_SW3		_CTYPE_SW3		/* 3 width character */
#endif /* _NONSTD_SOURCE */

#define __DARWIN_CTYPE_inline		__header_inline

#define __DARWIN_CTYPE_TOP_inline	__header_inline

/*
 * Use inline functions if we are allowed to and the compiler supports them.
 */
#if !defined(_DONT_USE_CTYPE_INLINE_) && \
    (defined(_USE_CTYPE_INLINE_) || defined(__GNUC__) || defined(__cplusplus))

/* See comments in <machine/_type.h> about __darwin_ct_rune_t. */
__BEGIN_DECLS
unsigned long		___runetype(__darwin_ct_rune_t);
__darwin_ct_rune_t	___tolower(__darwin_ct_rune_t);
__darwin_ct_rune_t	___toupper(__darwin_ct_rune_t);
__END_DECLS

__DARWIN_CTYPE_TOP_inline int
isascii(int _c)
{
	return ((_c & ~0x7F) == 0);
}

#ifdef USE_ASCII
__DARWIN_CTYPE_inline int
__maskrune(__darwin_ct_rune_t _c, unsigned long _f)
{
	return (int)_DefaultRuneLocale.__runetype[_c & 0xff] & (__uint32_t)_f;
}
#else /* !USE_ASCII */
__BEGIN_DECLS
int             	__maskrune(__darwin_ct_rune_t, unsigned long);
__END_DECLS
#endif /* USE_ASCII */

__DARWIN_CTYPE_inline int
__istype(__darwin_ct_rune_t _c, unsigned long _f)
{
#ifdef USE_ASCII
	return !!(__maskrune(_c, _f));
#else /* USE_ASCII */
	return (isascii(_c) ? !!(_DefaultRuneLocale.__runetype[_c] & _f)
		: !!__maskrune(_c, _f));
#endif /* USE_ASCII */
}

__DARWIN_CTYPE_inline __darwin_ct_rune_t
__isctype(__darwin_ct_rune_t _c, unsigned long _f)
{
#ifdef USE_ASCII
	return !!(__maskrune(_c, _f));
#else /* USE_ASCII */
	return (_c < 0 || _c >= _CACHED_RUNES) ? 0 :
		!!(_DefaultRuneLocale.__runetype[_c] & _f);
#endif /* USE_ASCII */
}

#ifdef USE_ASCII
__DARWIN_CTYPE_inline __darwin_ct_rune_t
__toupper(__darwin_ct_rune_t _c)
{
	return _DefaultRuneLocale.__mapupper[_c & 0xff];
}

__DARWIN_CTYPE_inline __darwin_ct_rune_t
__tolower(__darwin_ct_rune_t _c)
{
	return _DefaultRuneLocale.__maplower[_c & 0xff];
}
#else /* !USE_ASCII */
__BEGIN_DECLS
__darwin_ct_rune_t	__toupper(__darwin_ct_rune_t);
__darwin_ct_rune_t	__tolower(__darwin_ct_rune_t);
__END_DECLS
#endif /* USE_ASCII */

__DARWIN_CTYPE_inline int
__wcwidth(__darwin_ct_rune_t _c)
{
	unsigned int _x;

	if (_c == 0)
		return (0);
	_x = (unsigned int)__maskrune(_c, _CTYPE_SWM|_CTYPE_R);
	if ((_x & _CTYPE_SWM) != 0)
		return ((_x & _CTYPE_SWM) >> _CTYPE_SWS);
	return ((_x & _CTYPE_R) != 0 ? 1 : -1);
}

#ifndef _EXTERNALIZE_CTYPE_INLINES_

#define	_tolower(c)	__tolower(c)
#define	_toupper(c)	__toupper(c)

__DARWIN_CTYPE_TOP_inline int
isalnum(int _c)
{
	return (__istype(_c, _CTYPE_A|_CTYPE_D));
}

__DARWIN_CTYPE_TOP_inline int
isalpha(int _c)
{
	return (__istype(_c, _CTYPE_A));
}

__DARWIN_CTYPE_TOP_inline int
isblank(int _c)
{
	return (__istype(_c, _CTYPE_B));
}

__DARWIN_CTYPE_TOP_inline int
iscntrl(int _c)
{
	return (__istype(_c, _CTYPE_C));
}

/* ANSI -- locale independent */
__DARWIN_CTYPE_TOP_inline int
isdigit(int _c)
{
	return (__isctype(_c, _CTYPE_D));
}

__DARWIN_CTYPE_TOP_inline int
isgraph(int _c)
{
	return (__istype(_c, _CTYPE_G));
}

__DARWIN_CTYPE_TOP_inline int
islower(int _c)
{
	return (__istype(_c, _CTYPE_L));
}

__DARWIN_CTYPE_TOP_inline int
isprint(int _c)
{
	return (__istype(_c, _CTYPE_R));
}

__DARWIN_CTYPE_TOP_inline int
ispunct(int _c)
{
	return (__istype(_c, _CTYPE_P));
}

__DARWIN_CTYPE_TOP_inline int
isspace(int _c)
{
	return (__istype(_c, _CTYPE_S));
}

__DARWIN_CTYPE_TOP_inline int
isupper(int _c)
{
	return (__istype(_c, _CTYPE_U));
}

/* ANSI -- locale independent */
__DARWIN_CTYPE_TOP_inline int
isxdigit(int _c)
{
	return (__isctype(_c, _CTYPE_X));
}

__DARWIN_CTYPE_TOP_inline int
toascii(int _c)
{
	return (_c & 0x7F);
}

__DARWIN_CTYPE_TOP_inline int
tolower(int _c)
{
        return (__tolower(_c));
}

__DARWIN_CTYPE_TOP_inline int
toupper(int _c)
{
        return (__toupper(_c));
}

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
__DARWIN_CTYPE_TOP_inline int
digittoint(int _c)
{
	return (__maskrune(_c, 0x0F));
}

__DARWIN_CTYPE_TOP_inline int
ishexnumber(int _c)
{
	return (__istype(_c, _CTYPE_X));
}

__DARWIN_CTYPE_TOP_inline int
isideogram(int _c)
{
	return (__istype(_c, _CTYPE_I));
}

__DARWIN_CTYPE_TOP_inline int
isnumber(int _c)
{
	return (__istype(_c, _CTYPE_D));
}

__DARWIN_CTYPE_TOP_inline int
isphonogram(int _c)
{
	return (__istype(_c, _CTYPE_Q));
}

__DARWIN_CTYPE_TOP_inline int
isrune(int _c)
{
	return (__istype(_c, 0xFFFFFFF0L));
}

__DARWIN_CTYPE_TOP_inline int
isspecial(int _c)
{
	return (__istype(_c, _CTYPE_T));
}
#endif /* !_ANSI_SOURCE && (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#endif /* _EXTERNALIZE_CTYPE_INLINES_ */

#else /* not using inlines */

__BEGIN_DECLS
int     isalnum(int);
int     isalpha(int);
int     isblank(int);
int     iscntrl(int);
int     isdigit(int);
int     isgraph(int);
int     islower(int);
int     isprint(int);
int     ispunct(int);
int     isspace(int);
int     isupper(int);
int     isxdigit(int);
int     tolower(int);
int     toupper(int);
int     isascii(int);
int     toascii(int);

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
int     _tolower(int);
int     _toupper(int);
int     digittoint(int);
int     ishexnumber(int);
int     isideogram(int);
int     isnumber(int);
int     isphonogram(int);
int     isrune(int);
int     isspecial(int);
#endif
__END_DECLS

#endif /* using inlines */

#ifdef _USE_EXTENDED_LOCALES_
#include <xlocale/_ctype.h>
#endif /* _USE_EXTENDED_LOCALES_ */

#endif /* !_CTYPE_H_ */
