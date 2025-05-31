/*	$NetBSD: featuretest.h,v 1.10.66.1 2024/10/11 18:51:20 martin Exp $	*/

/*
 * Written by Klaus Klein <kleink@NetBSD.org>, February 2, 1998.
 * Public domain.
 *
 * NOTE: Do not protect this header against multiple inclusion.  Doing
 * so can have subtle side-effects due to header file inclusion order
 * and testing of e.g. _POSIX_SOURCE vs. _POSIX_C_SOURCE.  Instead,
 * protect each CPP macro that we want to supply.
 */

/*
 * Feature-test macros are defined by several standards, and allow an
 * application to specify what symbols they want the system headers to
 * expose, and hence what standard they want them to conform to.
 * There are two classes of feature-test macros.  The first class
 * specify complete standards, and if one of these is defined, header
 * files will try to conform to the relevant standard.  They are:
 *
 * ANSI macros:
 * _ANSI_SOURCE			ANSI C89
 *
 * POSIX macros:
 * _POSIX_SOURCE == 1		IEEE Std 1003.1 (version?)
 * _POSIX_C_SOURCE == 1		IEEE Std 1003.1-1990
 * _POSIX_C_SOURCE == 2		IEEE Std 1003.2-1992
 * _POSIX_C_SOURCE == 199309L	IEEE Std 1003.1b-1993
 * _POSIX_C_SOURCE == 199506L	ISO/IEC 9945-1:1996
 * _POSIX_C_SOURCE == 200112L	IEEE Std 1003.1-2001
 * _POSIX_C_SOURCE == 200809L   IEEE Std 1003.1-2008
 *
 * X/Open macros:
 * _XOPEN_SOURCE		System Interfaces and Headers, Issue 4, Ver 2
 * _XOPEN_SOURCE_EXTENDED == 1	XSH4.2 UNIX extensions
 * _XOPEN_SOURCE == 500		System Interfaces and Headers, Issue 5
 * _XOPEN_SOURCE == 520		Networking Services (XNS), Issue 5.2
 * _XOPEN_SOURCE == 600		IEEE Std 1003.1-2001, XSI option
 * _XOPEN_SOURCE == 700		IEEE Std 1003.1-2008, XSI option
 *
 * NetBSD macros:
 * _NETBSD_SOURCE == 1		Make all NetBSD features available.
 *
 * If more than one of these "major" feature-test macros is defined,
 * then the set of facilities provided (and namespace used) is the
 * union of that specified by the relevant standards, and in case of
 * conflict, the earlier standard in the above list has precedence (so
 * if both _POSIX_C_SOURCE and _NETBSD_SOURCE are defined, the version
 * of rename() that's used is the POSIX one).  If none of the "major"
 * feature-test macros is defined, _NETBSD_SOURCE is assumed.
 *
 * There are also "minor" feature-test macros, which enable extra
 * functionality in addition to some base standard.  They should be
 * defined along with one of the "major" macros.  The "minor" macros
 * are:
 *
 * _REENTRANT
 * _ISOC99_SOURCE
 * _ISOC11_SOURCE
 * _LARGEFILE_SOURCE		Large File Support
 *		<http://ftp.sas.com/standards/large.file/x_open.20Mar96.html>
 */

#if defined(_POSIX_SOURCE) && !defined(_POSIX_C_SOURCE)
#define _POSIX_C_SOURCE	1L
#endif

#if !defined(_ANSI_SOURCE) && !defined(_POSIX_C_SOURCE) && \
    !defined(_XOPEN_SOURCE) && !defined(_NETBSD_SOURCE)
#define _NETBSD_SOURCE 1
#endif

#if ((_POSIX_C_SOURCE - 0) >= 199506L || (_XOPEN_SOURCE - 0) >= 500) && \
    !defined(_REENTRANT)
#define _REENTRANT
#endif

/*
 * The _XOPEN_SOURCE namespaces are supersets of corresponding
 * _POSIX_C_SOURCE namespaces, so to keep the namespace tests in header
 * files simpler, if _XOPEN_SOURCE is defined but _POSIX_C_SOURCE is
 * not, define _POSIX_C_SOURCE to the corresponding value.
 */
#if defined(_XOPEN_SOURCE) && !defined(_POSIX_C_SOURCE)

/*
 * `[I]f _XOPEN_SOURCE is set equal to 800 and _POSIX_C_SOURCE is set
 *  equal to 202405L, the behavior is the same as if only _XOPEN_SOURCE
 *  is defined and set equal to 800.
 *
 * IEEE Std 1003.1-2024, 2.2.1.2 `The _XOPEN_SOURCE Feature Test Macro'
 * https://pubs.opengroup.org/onlinepubs/9799919799.2024edition/functions/V2_chap02.html#tag_16_02_01_02
 */
#if (_XOPEN_SOURCE - 0) == 800
#define	_POSIX_C_SOURCE	202405L

/*
 * `[I]f _XOPEN_SOURCE is set equal to 700 and _POSIX_C_SOURCE is set
 *  equal to 200809L, the behavior is the same as if only _XOPEN_SOURCE
 *  is defined and set equal to 700.'
 *
 * IEEE Std 1003.1-2008, 2.2.1 `POSIX.1 Symbols', subsection `The
 * _XOPEN_SOURCE Feature Test Macro'
 * https://pubs.opengroup.org/onlinepubs/9699919799.2018edition/functions/V2_chap02.html
 */
#elif (_XOPEN_SOURCE - 0) == 700
#define	_POSIX_C_SOURCE	200809L

/*
 * `[I]f _XOPEN_SOURCE is set equal to 600 and _POSIX_C_SOURCE is set
 *  equal to 200112L, the behavior is the same as if only _XOPEN_SOURCE
 *  is defined and set equal to 600.'
 *
 * IEEE Std 1003.1-2001, 2.2.1 `POSIX.1 Symbols', subsection `The
 * _XOPEN_SOURCE Feature Test Macro'
 * https://pubs.opengroup.org/onlinepubs/007904875/functions/xsh_chap02_02.html
 */
#elif (_XOPEN_SOURCE - 0) == 600
#define	_POSIX_C_SOURCE	200112L

/*
 * `[I]f _XOPEN_SOURCE is set equal to 500 and _POSIX_SOURCE is
 *  defined, or _POSIX_C_SOURCE is set greater than zero and less than
 *  or equal to 199506L, the behaviour is the same as if only
 *  _XOPEN_SOURCE is defined and set equal to 500.'
 *
 * Single UNIX Specification, Version 2, `The Compilation Environment'
 * https://pubs.opengroup.org/onlinepubs/007908799/xsh/compilation.html
 */
#elif (_XOPEN_SOURCE - 0) == 500
#define	_POSIX_C_SOURCE	199506L
#endif

#endif