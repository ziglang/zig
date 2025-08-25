/*	$NetBSD: float.h,v 1.12 2009/11/25 08:43:15 martin Exp $ */

#ifndef _SPARC_FLOAT_H_
#define _SPARC_FLOAT_H_

#ifdef _LP64

#define LDBL_MANT_DIG	113
#define	LDBL_EPSILON	1.925929944387235853055977942584927319E-34L
#define	LDBL_DIG	33
#define	LDBL_MIN_EXP	(-16381)
#define	LDBL_MIN	3.3621031431120935062626778173217526026E-4932L
#define	LDBL_MIN_10_EXP	(-4931)
#define	LDBL_MAX_EXP	16384
#define	LDBL_MAX	1.1897314953572317650857593266280070162E4932L
#define	LDBL_MAX_10_EXP	4932

#endif	/* _LP64 */

#include <sys/float_ieee754.h>

#ifdef _LP64

#if !defined(_ANSI_SOURCE) && !defined(_POSIX_C_SOURCE) && \
    !defined(_XOPEN_SOURCE) || \
    ((__STDC_VERSION__ - 0) >= 199901L) || \
    ((_POSIX_C_SOURCE - 0) >= 200112L) || \
    ((_XOPEN_SOURCE  - 0) >= 600) || \
    defined(_ISOC99_SOURCE) || defined(_NETBSD_SOURCE)
#define	DECIMAL_DIG	36
#endif /* !defined(_ANSI_SOURCE) && ... */

#endif	/* _LP64 */

#endif	/* _SPARC64_FLOAT_H_ */