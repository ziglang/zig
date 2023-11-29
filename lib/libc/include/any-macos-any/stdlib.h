/*
 * Copyright (c) 2000, 2002 - 2008 Apple Inc. All rights reserved.
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
/*-
 * Copyright (c) 1990, 1993
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
 *	@(#)stdlib.h	8.5 (Berkeley) 5/19/95
 */

#ifndef _STDLIB_H_
#define _STDLIB_H_

#include <Availability.h>
#include <sys/cdefs.h>

#include <_types.h>
#if !defined(_ANSI_SOURCE)
#include <sys/wait.h>
#if (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
#include <alloca.h>
#endif /* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
#endif /* !_ANSI_SOURCE */

/* DO NOT REMOVE THIS COMMENT: fixincludes needs to see:
 * _GCC_SIZE_T */
#include <sys/_types/_size_t.h>

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
#include <sys/_types/_ct_rune_t.h>
#include <sys/_types/_rune_t.h>
#endif	/* !_ANSI_SOURCE && (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */

#include <sys/_types/_wchar_t.h>

typedef struct {
	int quot;		/* quotient */
	int rem;		/* remainder */
} div_t;

typedef struct {
	long quot;		/* quotient */
	long rem;		/* remainder */
} ldiv_t;

#if !__DARWIN_NO_LONG_LONG
typedef struct {
	long long quot;
	long long rem;
} lldiv_t;
#endif /* !__DARWIN_NO_LONG_LONG */

#include <sys/_types/_null.h>

#define	EXIT_FAILURE	1
#define	EXIT_SUCCESS	0

#define	RAND_MAX	0x7fffffff

#ifdef _USE_EXTENDED_LOCALES_
#include <_xlocale.h>
#endif /* _USE_EXTENDED_LOCALES_ */

#ifndef MB_CUR_MAX
#ifdef _USE_EXTENDED_LOCALES_
#define	MB_CUR_MAX	(___mb_cur_max())
#ifndef MB_CUR_MAX_L
#define	MB_CUR_MAX_L(x)	(___mb_cur_max_l(x))
#endif /* !MB_CUR_MAX_L */
#else /* !_USE_EXTENDED_LOCALES_ */
extern int __mb_cur_max;
#define	MB_CUR_MAX	__mb_cur_max
#endif /* _USE_EXTENDED_LOCALES_ */
#endif /* MB_CUR_MAX */

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)) \
    && defined(_USE_EXTENDED_LOCALES_) && !defined(MB_CUR_MAX_L)
#define	MB_CUR_MAX_L(x)	(___mb_cur_max_l(x))
#endif

#include <malloc/_malloc.h>

__BEGIN_DECLS
void	 abort(void) __cold __dead2;
int	 abs(int) __pure2;
int	 atexit(void (* _Nonnull)(void));
double	 atof(const char *);
int	 atoi(const char *);
long	 atol(const char *);
#if !__DARWIN_NO_LONG_LONG
long long
	 atoll(const char *);
#endif /* !__DARWIN_NO_LONG_LONG */
void	*bsearch(const void *__key, const void *__base, size_t __nel,
	    size_t __width, int (* _Nonnull __compar)(const void *, const void *));
/* calloc is now declared in _malloc.h */
div_t	 div(int, int) __pure2;
void	 exit(int) __dead2;
/* free is now declared in _malloc.h */
char	*getenv(const char *);
long	 labs(long) __pure2;
ldiv_t	 ldiv(long, long) __pure2;
#if !__DARWIN_NO_LONG_LONG
long long
	 llabs(long long);
lldiv_t	 lldiv(long long, long long);
#endif /* !__DARWIN_NO_LONG_LONG */
/* malloc is now declared in _malloc.h */
int	 mblen(const char *__s, size_t __n);
size_t	 mbstowcs(wchar_t * __restrict , const char * __restrict, size_t);
int	 mbtowc(wchar_t * __restrict, const char * __restrict, size_t);
/* posix_memalign is now declared in _malloc.h */
void	 qsort(void *__base, size_t __nel, size_t __width,
	    int (* _Nonnull __compar)(const void *, const void *));
int	 rand(void) __swift_unavailable("Use arc4random instead.");
/* realloc is now declared in _malloc.h */
void	 srand(unsigned) __swift_unavailable("Use arc4random instead.");
double	 strtod(const char *, char **) __DARWIN_ALIAS(strtod);
float	 strtof(const char *, char **) __DARWIN_ALIAS(strtof);
long	 strtol(const char *__str, char **__endptr, int __base);
long double
	 strtold(const char *, char **);
#if !__DARWIN_NO_LONG_LONG
long long 
	 strtoll(const char *__str, char **__endptr, int __base);
#endif /* !__DARWIN_NO_LONG_LONG */
unsigned long
	 strtoul(const char *__str, char **__endptr, int __base);
#if !__DARWIN_NO_LONG_LONG
unsigned long long
	 strtoull(const char *__str, char **__endptr, int __base);
#endif /* !__DARWIN_NO_LONG_LONG */

__swift_unavailable("Use posix_spawn APIs or NSTask instead. (On iOS, process spawning is unavailable.)")
__API_AVAILABLE(macos(10.0)) __IOS_PROHIBITED
__WATCHOS_PROHIBITED __TVOS_PROHIBITED
int	 system(const char *) __DARWIN_ALIAS_C(system);


size_t	 wcstombs(char * __restrict, const wchar_t * __restrict, size_t);
int	 wctomb(char *, wchar_t);

#ifndef _ANSI_SOURCE
void	_Exit(int) __dead2;
long	 a64l(const char *);
double	 drand48(void);
char	*ecvt(double, int, int *__restrict, int *__restrict); /* LEGACY */
double	 erand48(unsigned short[3]);
char	*fcvt(double, int, int *__restrict, int *__restrict); /* LEGACY */
char	*gcvt(double, int, char *); /* LEGACY */
int	 getsubopt(char **, char * const *, char **);
int	 grantpt(int);
#if __DARWIN_UNIX03
char	*initstate(unsigned, char *, size_t); /* no  __DARWIN_ALIAS needed */
#else /* !__DARWIN_UNIX03 */
char	*initstate(unsigned long, char *, long);
#endif /* __DARWIN_UNIX03 */
long	 jrand48(unsigned short[3]) __swift_unavailable("Use arc4random instead.");
char	*l64a(long);
void	 lcong48(unsigned short[7]);
long	 lrand48(void) __swift_unavailable("Use arc4random instead.");
#if !defined(_POSIX_C_SOURCE)
__deprecated_msg("This function is provided for compatibility reasons only.  Due to security concerns inherent in the design of mktemp(3), it is highly recommended that you use mkstemp(3) instead.")
#endif
char	*mktemp(char *);
int	 mkstemp(char *);
long	 mrand48(void) __swift_unavailable("Use arc4random instead.");
long	 nrand48(unsigned short[3]) __swift_unavailable("Use arc4random instead.");
int	 posix_openpt(int);
char	*ptsname(int);

#if (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
int ptsname_r(int fildes, char *buffer, size_t buflen) __API_AVAILABLE(macos(10.13.4), ios(11.3), tvos(11.3), watchos(4.3));
#endif

int	 putenv(char *) __DARWIN_ALIAS(putenv);
long	 random(void) __swift_unavailable("Use arc4random instead.");
int	 rand_r(unsigned *) __swift_unavailable("Use arc4random instead.");
#if (__DARWIN_UNIX03 && !defined(_POSIX_C_SOURCE)) || defined(_DARWIN_C_SOURCE) || defined(_DARWIN_BETTER_REALPATH)
char	*realpath(const char * __restrict, char * __restrict) __DARWIN_EXTSN(realpath);
#else /* (!__DARWIN_UNIX03 || _POSIX_C_SOURCE) && !_DARWIN_C_SOURCE && !_DARWIN_BETTER_REALPATH */
char	*realpath(const char * __restrict, char * __restrict) __DARWIN_ALIAS(realpath);
#endif /* (__DARWIN_UNIX03 && _POSIX_C_SOURCE) || _DARWIN_C_SOURCE || _DARWIN_BETTER_REALPATH */
unsigned short
	*seed48(unsigned short[3]);
int	 setenv(const char * __name, const char * __value, int __overwrite) __DARWIN_ALIAS(setenv);
#if __DARWIN_UNIX03
void	 setkey(const char *) __DARWIN_ALIAS(setkey);
#else /* !__DARWIN_UNIX03 */
int	 setkey(const char *);
#endif /* __DARWIN_UNIX03 */
char	*setstate(const char *);
void	 srand48(long);
#if __DARWIN_UNIX03
void	 srandom(unsigned);
#else /* !__DARWIN_UNIX03 */
void	 srandom(unsigned long);
#endif /* __DARWIN_UNIX03 */
int	 unlockpt(int);
#if __DARWIN_UNIX03
int	 unsetenv(const char *) __DARWIN_ALIAS(unsetenv);
#else /* !__DARWIN_UNIX03 */
void	 unsetenv(const char *);
#endif /* __DARWIN_UNIX03 */
#endif	/* !_ANSI_SOURCE */
__END_DECLS

#if !defined(_ANSI_SOURCE) && (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
#include <machine/types.h>
#include <sys/_types/_dev_t.h>
#include <sys/_types/_mode_t.h>
#include <_types/_uint32_t.h>

__BEGIN_DECLS
uint32_t arc4random(void);
void	 arc4random_addrandom(unsigned char * /*dat*/, int /*datlen*/)
    __OSX_DEPRECATED(10.0, 10.12, "use arc4random_stir")
    __IOS_DEPRECATED(2.0, 10.0, "use arc4random_stir")
    __TVOS_DEPRECATED(2.0, 10.0, "use arc4random_stir")
    __WATCHOS_DEPRECATED(1.0, 3.0, "use arc4random_stir");
void	 arc4random_buf(void * __buf, size_t __nbytes) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
void	 arc4random_stir(void);
uint32_t
	 arc4random_uniform(uint32_t __upper_bound) __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
#ifdef __BLOCKS__
int	 atexit_b(void (^ _Nonnull)(void)) __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);

#ifdef __BLOCKS__
#if __has_attribute(noescape)
#define __bsearch_noescape __attribute__((__noescape__))
#else
#define __bsearch_noescape
#endif
#endif /* __BLOCKS__ */
void	*bsearch_b(const void *__key, const void *__base, size_t __nel,
	    size_t __width, int (^ _Nonnull __compar)(const void *, const void *) __bsearch_noescape)
	    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
#endif /* __BLOCKS__ */

	 /* getcap(3) functions */
char	*cgetcap(char *, const char *, int);
int	 cgetclose(void);
int	 cgetent(char **, char **, const char *);
int	 cgetfirst(char **, char **);
int	 cgetmatch(const char *, const char *);
int	 cgetnext(char **, char **);
int	 cgetnum(char *, const char *, long *);
int	 cgetset(const char *);
int	 cgetstr(char *, const char *, char **);
int	 cgetustr(char *, const char *, char **);

int	 daemon(int, int) __DARWIN_1050(daemon) __OSX_AVAILABLE_BUT_DEPRECATED_MSG(__MAC_10_0, __MAC_10_5, __IPHONE_2_0, __IPHONE_2_0, "Use posix_spawn APIs instead.") __WATCHOS_PROHIBITED __TVOS_PROHIBITED;
char	*devname(dev_t, mode_t);
char	*devname_r(dev_t, mode_t, char *buf, int len);
char	*getbsize(int *, long *);
int	 getloadavg(double [], int);
const char
	*getprogname(void);
void	 setprogname(const char *);

#ifdef __BLOCKS__
#if __has_attribute(noescape)
#define __sort_noescape __attribute__((__noescape__))
#else
#define __sort_noescape
#endif
#endif /* __BLOCKS__ */

int	 heapsort(void *__base, size_t __nel, size_t __width,
	    int (* _Nonnull __compar)(const void *, const void *));
#ifdef __BLOCKS__
int	 heapsort_b(void *__base, size_t __nel, size_t __width,
	    int (^ _Nonnull __compar)(const void *, const void *) __sort_noescape)
	    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
#endif /* __BLOCKS__ */
int	 mergesort(void *__base, size_t __nel, size_t __width,
	    int (* _Nonnull __compar)(const void *, const void *));
#ifdef __BLOCKS__
int	 mergesort_b(void *__base, size_t __nel, size_t __width,
	    int (^ _Nonnull __compar)(const void *, const void *) __sort_noescape)
	    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
#endif /* __BLOCKS__ */
void	 psort(void *__base, size_t __nel, size_t __width,
	    int (* _Nonnull __compar)(const void *, const void *))
	    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
#ifdef __BLOCKS__
void	 psort_b(void *__base, size_t __nel, size_t __width,
	    int (^ _Nonnull __compar)(const void *, const void *) __sort_noescape)
	    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
#endif /* __BLOCKS__ */
void	 psort_r(void *__base, size_t __nel, size_t __width, void *,
	    int (* _Nonnull __compar)(void *, const void *, const void *))
	    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
#ifdef __BLOCKS__
void	 qsort_b(void *__base, size_t __nel, size_t __width,
	    int (^ _Nonnull __compar)(const void *, const void *) __sort_noescape)
	    __OSX_AVAILABLE_STARTING(__MAC_10_6, __IPHONE_3_2);
#endif /* __BLOCKS__ */
void	 qsort_r(void *__base, size_t __nel, size_t __width, void *,
	    int (* _Nonnull __compar)(void *, const void *, const void *));
int	 radixsort(const unsigned char **__base, int __nel, const unsigned char *__table,
	    unsigned __endbyte);
int	rpmatch(const char *)
	__API_AVAILABLE(macos(10.15), ios(13.0), tvos(13.0), watchos(6.0));
int	 sradixsort(const unsigned char **__base, int __nel, const unsigned char *__table,
	    unsigned __endbyte);
void	 sranddev(void);
void	 srandomdev(void);
void	*reallocf(void *__ptr, size_t __size) __alloc_size(2);
long long
	strtonum(const char *__numstr, long long __minval, long long __maxval, const char **__errstrp)
	__API_AVAILABLE(macos(11.0), ios(14.0), tvos(14.0), watchos(7.0));
#if !__DARWIN_NO_LONG_LONG
long long
	 strtoq(const char *__str, char **__endptr, int __base);
unsigned long long
	 strtouq(const char *__str, char **__endptr, int __base);
#endif /* !__DARWIN_NO_LONG_LONG */
extern char *suboptarg;		/* getsubopt(3) external variable */
/* valloc is now declared in _malloc.h */
__END_DECLS
#endif	/* !_ANSI_SOURCE && !_POSIX_SOURCE */

__BEGIN_DECLS
/* Poison the following routines if -fshort-wchar is set */
#if !defined(__cplusplus) && defined(__WCHAR_MAX__) && __WCHAR_MAX__ <= 0xffffU
#pragma GCC poison mbstowcs mbtowc wcstombs wctomb
#endif
__END_DECLS

#ifdef _USE_EXTENDED_LOCALES_
#include <xlocale/_stdlib.h>
#endif /* _USE_EXTENDED_LOCALES_ */

#endif /* _STDLIB_H_ */
