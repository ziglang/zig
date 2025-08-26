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
 *	@(#)locale.h	8.1 (Berkeley) 6/2/93
 * $FreeBSD: /repoman/r/ncvs/src/include/locale.h,v 1.7 2002/10/09 09:19:27 tjr Exp $
 */

#ifndef __LOCALE_H_
#define __LOCALE_H_

#include <sys/cdefs.h>
#include <_bounds.h>
#include <_types.h>

_LIBC_SINGLE_BY_DEFAULT()

struct lconv {
	char	*_LIBC_CSTR decimal_point;
	char	*_LIBC_CSTR thousands_sep;
	char	*_LIBC_CSTR grouping;
	char	*_LIBC_CSTR int_curr_symbol;
	char	*_LIBC_CSTR currency_symbol;
	char	*_LIBC_CSTR mon_decimal_point;
	char	*_LIBC_CSTR mon_thousands_sep;
	char	*_LIBC_CSTR mon_grouping;
	char	*_LIBC_CSTR positive_sign;
	char	*_LIBC_CSTR negative_sign;
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

#include <sys/_types/_null.h>

#define LC_ALL_MASK			(  LC_COLLATE_MASK \
					 | LC_CTYPE_MASK \
					 | LC_MESSAGES_MASK \
					 | LC_MONETARY_MASK \
					 | LC_NUMERIC_MASK \
					 | LC_TIME_MASK )
#define LC_COLLATE_MASK			(1 << 0)
#define LC_CTYPE_MASK			(1 << 1)
#define LC_MESSAGES_MASK		(1 << 2)
#define LC_MONETARY_MASK		(1 << 3)
#define LC_NUMERIC_MASK			(1 << 4)
#define LC_TIME_MASK			(1 << 5)

#define _LC_NUM_MASK			6
#define _LC_LAST_MASK			(1 << (_LC_NUM_MASK - 1))

#define LC_GLOBAL_LOCALE		((locale_t)-1)
#define LC_C_LOCALE				((locale_t)NULL)

#include <_types/_locale_t.h>

__BEGIN_DECLS
locale_t	duplocale(locale_t);
int		freelocale(locale_t);
struct lconv	*localeconv(void);
locale_t	newlocale(int, __const char *, locale_t);
locale_t	uselocale(locale_t);
__END_DECLS

#endif /* __LOCALE_H_ */
