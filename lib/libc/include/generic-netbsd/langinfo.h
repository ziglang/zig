/*	$NetBSD: langinfo.h,v 1.10 2013/08/19 08:03:33 joerg Exp $	*/

/*
 * Written by J.T. Conklin <jtc@NetBSD.org>
 * Public domain.
 */

#ifndef _LANGINFO_H_
#define _LANGINFO_H_

#include <sys/cdefs.h>
#include <nl_types.h>

#define D_T_FMT		((nl_item)0)	/* String for formatting date and
					   time */
#define D_FMT		((nl_item)1)	/* Date format string */
#define	T_FMT		((nl_item)2)	/* Time format string */
#define T_FMT_AMPM	((nl_item)3)	/* Time format string with 12 hour
					   clock */
#define AM_STR		((nl_item)4)	/* Ante Meridiem afix */
#define PM_STR		((nl_item)5)	/* Post Meridiem afix */

#define DAY_1		((nl_item)6)	/* Name of the first day of the week */
#define DAY_2		((nl_item)7)
#define DAY_3		((nl_item)8)
#define DAY_4		((nl_item)9)
#define DAY_5		((nl_item)10)
#define DAY_6		((nl_item)11)
#define DAY_7		((nl_item)12)

#define ABDAY_1		((nl_item)13)	/* Abbrev. name of the first day of
					   the week */
#define ABDAY_2		((nl_item)14)
#define ABDAY_3		((nl_item)15)
#define ABDAY_4		((nl_item)16)
#define ABDAY_5		((nl_item)17)
#define ABDAY_6		((nl_item)18)
#define ABDAY_7		((nl_item)19)

#define MON_1		((nl_item)20)	/* Name of the first month */
#define MON_2		((nl_item)21)
#define MON_3		((nl_item)22)
#define MON_4		((nl_item)23)
#define MON_5		((nl_item)24)
#define MON_6		((nl_item)25)
#define MON_7		((nl_item)26)
#define MON_8		((nl_item)27)
#define MON_9		((nl_item)28)
#define MON_10		((nl_item)29)
#define MON_11		((nl_item)30)
#define MON_12		((nl_item)31)

#define ABMON_1		((nl_item)32)	/* Abbrev. name of the first month */
#define ABMON_2		((nl_item)33)
#define ABMON_3		((nl_item)34)
#define ABMON_4		((nl_item)35)
#define ABMON_5		((nl_item)36)
#define ABMON_6		((nl_item)37)
#define ABMON_7		((nl_item)38)
#define ABMON_8		((nl_item)39)
#define ABMON_9		((nl_item)40)
#define ABMON_10	((nl_item)41)
#define ABMON_11	((nl_item)42)
#define ABMON_12	((nl_item)43)

#define RADIXCHAR	((nl_item)44)	/* Radix character */
#define THOUSEP		((nl_item)45)	/* Separator for thousands */
#define YESSTR		((nl_item)46)	/* Affirmitive response for yes/no
					   queries */
#define YESEXPR		((nl_item)47)	/* Affirmitive response for yes/no
					   queries */
#define NOSTR		((nl_item)48)	/* Negative response for yes/no
					   queries */
#define NOEXPR		((nl_item)49)	/* Negative response for yes/no
					   queries */
#define CRNCYSTR	((nl_item)50)	/* Currency symbol */

#define CODESET		((nl_item)51)	/* codeset name */

#define ERA		((nl_item)52)	/* Era description segments */
#define ERA_D_FMT	((nl_item)53)	/* Era date format string */
#define ERA_D_T_FMT	((nl_item)54)	/* Era date and time format string */
#define ERA_T_FMT	((nl_item)55)	/* Era time format string */

#define ALT_DIGITS	((nl_item)56)	/* Alternative symbols for digits */

__BEGIN_DECLS
char *nl_langinfo(nl_item);
__END_DECLS

#if defined(_NETBSD_SOURCE)
#  ifndef __LOCALE_T_DECLARED
typedef struct _locale		*locale_t;
#  define __LOCALE_T_DECLARED
#  endif
__BEGIN_DECLS
char *nl_langinfo_l(nl_item, locale_t);
__END_DECLS
#endif

#endif	/* _LANGINFO_H_ */