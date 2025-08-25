/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _BSDTYPES_DEFINED
#define _BSDTYPES_DEFINED

/* Make sure __LONG32 is defined.  */
#include <_mingw.h>

typedef unsigned char	u_char;
typedef unsigned short	u_short;
typedef unsigned int	u_int;
#pragma push_macro("u_long")
#undef u_long
typedef unsigned long u_long;
#pragma pop_macro("u_long")

#if defined(__GNUC__) || \
    defined(__GNUG__)
__extension__
#endif /* gcc / g++ */
typedef unsigned long long u_int64;

#endif /* _BSDTYPES_DEFINED */

#if defined (__LP64__) && defined (u_long)
typedef unsigned __LONG32 u_long;
#endif

