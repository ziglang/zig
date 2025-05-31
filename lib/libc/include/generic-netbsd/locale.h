/*	$NetBSD: locale.h,v 1.28 2016/04/29 16:26:48 joerg Exp $	*/

/*
 * Copyright (c) 1991, 1993
 *	The Regents of the University of California.  All rights reserved.
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
 *	@(#)locale.h	8.1 (Berkeley) 6/2/93
 */

#ifndef _LOCALE_H_
#define _LOCALE_H_

#include <sys/featuretest.h>

struct lconv {
	char	*decimal_point;
	char	*thousands_sep;
	char	*grouping;
	char	*int_curr_symbol;
	char	*currency_symbol;
	char	*mon_decimal_point;
	char	*mon_thousands_sep;
	char	*mon_grouping;
	char	*positive_sign;
	char	*negative_sign;
	char	int_frac_digits;
	char	frac_digits;
	char	p_cs_precedes;
	char	p_sep_by_space;
	char	n_cs_precedes;
	char	n_sep_by_space;
	char	p_sign_posn;
	char	n_sign_posn;
	char	int_p_cs_precedes;
	char	int_n_cs_precedes;
	char	int_p_sep_by_space;
	char	int_n_sep_by_space;
	char	int_p_sign_posn;
	char	int_n_sign_posn;
};

#include <sys/null.h>

#define	LC_ALL		0
#define	LC_COLLATE	1
#define	LC_CTYPE	2
#define	LC_MONETARY	3
#define	LC_NUMERIC	4
#define	LC_TIME		5
#define LC_MESSAGES	6

#define	_LC_LAST	7		/* marks end */

#include <sys/cdefs.h>

#if (_POSIX_C_SOURCE - 0) >= 200809L || defined(_NETBSD_SOURCE) || \
    defined(__SETLOCALE_SOURCE__)
#  ifndef __LOCALE_T_DECLARED
typedef struct _locale		*locale_t;
#  define __LOCALE_T_DECLARED
#  endif
#endif

__BEGIN_DECLS
struct lconv *localeconv(void);
char *setlocale(int, const char *) __RENAME(__setlocale50);

#if (_POSIX_C_SOURCE - 0) >= 200809L || defined(_NETBSD_SOURCE)
#  ifndef __LOCALE_T_DECLARED
typedef struct _locale		*locale_t;
#  define __LOCALE_T_DECLARED
#  endif
#define	LC_ALL_MASK		((int)~0)
#define	LC_COLLATE_MASK		((int)(1 << LC_COLLATE))
#define	LC_CTYPE_MASK		((int)(1 << LC_CTYPE))
#define	LC_MONETARY_MASK	((int)(1 << LC_MONETARY))
#define	LC_NUMERIC_MASK		((int)(1 << LC_NUMERIC))
#define	LC_TIME_MASK		((int)(1 << LC_TIME))
#define	LC_MESSAGES_MASK	((int)(1 << LC_MESSAGES))
locale_t	duplocale(locale_t);
void		freelocale(locale_t);
struct lconv	*localeconv_l(locale_t);
locale_t	newlocale(int, const char *, locale_t);

extern		       struct _locale	_lc_global_locale;
#define LC_GLOBAL_LOCALE	(&_lc_global_locale)
#endif /* _POSIX_SOURCE >= 200809 || _NETBSD_SOURCE */

#if defined(_NETBSD_SOURCE)
extern		       const struct _locale _lc_C_locale;
#define LC_C_LOCALE		((locale_t)__UNCONST(&_lc_C_locale))
#endif
__END_DECLS

#endif /* _LOCALE_H_ */