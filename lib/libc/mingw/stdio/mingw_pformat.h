#ifndef PFORMAT_H
/*
 * pformat.h
 *
 * $Id: pformat.h,v 1.1 2008/07/28 23:24:20 keithmarshall Exp $
 *
 * A private header, defining the `pformat' API; it is to be included
 * in each compilation unit implementing any of the `printf' family of
 * functions, but serves no useful purpose elsewhere.
 *
 * Written by Keith Marshall <keithmarshall@users.sourceforge.net>
 *
 * This is free software.  You may redistribute and/or modify it as you
 * see fit, without restriction of copyright.
 *
 * This software is provided "as is", in the hope that it may be useful,
 * but WITHOUT WARRANTY OF ANY KIND, not even any implied warranty of
 * MERCHANTABILITY, nor of FITNESS FOR ANY PARTICULAR PURPOSE.  At no
 * time will the author accept any form of liability for any damages,
 * however caused, resulting from the use of this software.
 */
#define PFORMAT_H

/* The following macros reproduce definitions from _mingw.h,
 * so that compilation will not choke, if using any compiler
 * other than the MinGW implementation of GCC.
 */
#ifndef __cdecl
# ifdef __GNUC__
#  define __cdecl __attribute__((__cdecl__))
# else
#  define __cdecl
# endif
#endif

#ifndef __MINGW_GNUC_PREREQ
# if defined __GNUC__ && defined __GNUC_MINOR__
#  define __MINGW_GNUC_PREREQ( major, minor )\
     (__GNUC__ > (major) || (__GNUC__ == (major) && __GNUC_MINOR__ >= (minor)))
# else
#  define __MINGW_GNUC_PREREQ( major, minor )
# endif
#endif

#ifndef  __MINGW_NOTHROW
# if __MINGW_GNUC_PREREQ( 3, 3 )
#  define __MINGW_NOTHROW  __attribute__((__nothrow__))
# else
#  define __MINGW_NOTHROW
# endif
#endif

#ifdef __BUILD_WIDEAPI
#define APICHAR	wchar_t
#else
#define APICHAR char
#endif

/* The following are the declarations specific to the `pformat' API...
 */
#define PFORMAT_TO_FILE     0x2000
#define PFORMAT_NOLIMIT     0x4000

#if defined(__MINGW32__) || defined(__MINGW64__)
 /*
  * Map MinGW specific function names, for use in place of the generic
  * implementation defined equivalent function names.
  */
#ifdef __BUILD_WIDEAPI
# define __pformat        __mingw_wpformat
#define __fputc(X,STR) fputwc((wchar_t) (X), (STR))

# define __printf         __mingw_wprintf
# define __fprintf        __mingw_fwprintf
# define __sprintf        __mingw_swprintf
# define __snprintf       __mingw_snwprintf

# define __vprintf        __mingw_vwprintf
# define __vfprintf       __mingw_vfwprintf
# define __vsprintf       __mingw_vswprintf
# define __vsnprintf      __mingw_vsnwprintf
#else
# define __pformat        __mingw_pformat
#define __fputc(X,STR) fputc((X), (STR))

# define __printf         __mingw_printf
# define __fprintf        __mingw_fprintf
# define __sprintf        __mingw_sprintf
# define __snprintf       __mingw_snprintf

# define __vprintf        __mingw_vprintf
# define __vfprintf       __mingw_vfprintf
# define __vsprintf       __mingw_vsprintf
# define __vsnprintf      __mingw_vsnprintf
#endif /* __BUILD_WIDEAPI */
#endif

int __cdecl __pformat(int, void *, int, const APICHAR *, va_list) __MINGW_NOTHROW;
#endif /* !defined PFORMAT_H */
