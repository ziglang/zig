/*-
 * Copyright (c) 2001 Alexey Zelkin <phantom@FreeBSD.org>
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
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD: /repoman/r/ncvs/src/include/langinfo.h,v 1.6 2002/09/18 05:54:25 mike Exp $
 */

#ifndef _LANGINFO_H_
#define	_LANGINFO_H_

#include <_types.h>
#include <_types/_nl_item.h>

#define	CODESET		0	/* codeset name */
#define	D_T_FMT		1	/* string for formatting date and time */
#define	D_FMT		2	/* date format string */
#define	T_FMT		3	/* time format string */
#define	T_FMT_AMPM	4	/* a.m. or p.m. time formatting string */
#define	AM_STR		5	/* Ante Meridian affix */
#define	PM_STR		6	/* Post Meridian affix */

/* week day names */
#define	DAY_1		7
#define	DAY_2		8
#define	DAY_3		9
#define	DAY_4		10
#define	DAY_5		11
#define	DAY_6		12
#define	DAY_7		13

/* abbreviated week day names */
#define	ABDAY_1		14
#define	ABDAY_2		15
#define	ABDAY_3		16
#define	ABDAY_4		17
#define	ABDAY_5		18
#define	ABDAY_6		19
#define	ABDAY_7		20

/* month names */
#define	MON_1		21
#define	MON_2		22
#define	MON_3		23
#define	MON_4		24
#define	MON_5		25
#define	MON_6		26
#define	MON_7		27
#define	MON_8		28
#define	MON_9		29
#define	MON_10		30
#define	MON_11		31
#define	MON_12		32

/* abbreviated month names */
#define	ABMON_1		33
#define	ABMON_2		34
#define	ABMON_3		35
#define	ABMON_4		36
#define	ABMON_5		37
#define	ABMON_6		38
#define	ABMON_7		39
#define	ABMON_8		40
#define	ABMON_9		41
#define	ABMON_10	42
#define	ABMON_11	43
#define	ABMON_12	44

#define	ERA		45	/* era description segments */
#define	ERA_D_FMT	46	/* era date format string */
#define	ERA_D_T_FMT	47	/* era date and time format string */
#define	ERA_T_FMT	48	/* era time format string */
#define	ALT_DIGITS	49	/* alternative symbols for digits */

#define	RADIXCHAR	50	/* radix char */
#define	THOUSEP		51	/* separator for thousands */

#define	YESEXPR		52	/* affirmative response expression */
#define	NOEXPR		53	/* negative response expression */

#if (__DARWIN_C_LEVEL > __DARWIN_C_ANSI && __DARWIN_C_LEVEL < 200112L) || __DARWIN_C_LEVEL == __DARWIN_C_FULL
#define	YESSTR		54	/* affirmative response for yes/no queries */
#define	NOSTR		55	/* negative response for yes/no queries */
#endif

#define	CRNCYSTR	56	/* currency symbol */

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
#define	D_MD_ORDER	57	/* month/day order (local extension) */
#endif

__BEGIN_DECLS
char	*nl_langinfo(nl_item);
__END_DECLS

#ifdef _USE_EXTENDED_LOCALES_
#include <xlocale/_langinfo.h>
#endif /* _USE_EXTENDED_LOCALES_ */

#endif /* !_LANGINFO_H_ */
