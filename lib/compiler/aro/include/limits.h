/* <limits.h> for the Aro C compiler */

#pragma once

/* GlibC will try to include_next GCC's limits.h which will fail.
   Define _GCC_LIMITS_H_ to prevent it.  */
#if defined __GNUC__ && !defined _GCC_LIMITS_H_
#define _GCC_LIMITS_H_
#endif

/* Include the system's limits.h */
#if __STDC_HOSTED__ && __has_include_next(<limits.h>)
#include_next <limits.h>
#endif

#undef SCHAR_MAX
#define SCHAR_MAX __SCHAR_MAX__

#undef SHRT_MAX
#define SHRT_MAX  __SHRT_MAX__

#undef INT_MAX
#define INT_MAX   __INT_MAX__

#undef LONG_MAX
#define LONG_MAX  __LONG_MAX__

#undef SCHAR_MIN
#define SCHAR_MIN (-__SCHAR_MAX__-1)

#undef SHRT_MIN
#define SHRT_MIN  (-__SHRT_MAX__ -1)

#undef INT_MIN
#define INT_MIN   (-__INT_MAX__  -1)

#undef LONG_MIN
#define LONG_MIN  (-__LONG_MAX__ -1L)

#undef UCHAR_MAX
#define UCHAR_MAX (__SCHAR_MAX__*2  +1)

#undef USHRT_MAX
#define USHRT_MAX (__SHRT_MAX__ *2  +1)

#undef UINT_MAX
#define UINT_MAX  (__INT_MAX__  *2U +1U)

#undef ULONG_MAX
#define ULONG_MAX (__LONG_MAX__ *2UL+1UL)

#ifndef MB_LEN_MAX
#define MB_LEN_MAX 1
#endif

#undef CHAR_BIT
#define CHAR_BIT  __CHAR_BIT__

#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L

#undef BOOL_WIDTH
#define BOOL_WIDTH   __BOOL_WIDTH__

#undef CHAR_WIDTH
#define CHAR_WIDTH   CHAR_BIT

#undef SCHAR_WIDTH
#define SCHAR_WIDTH  CHAR_BIT

#undef UCHAR_WIDTH
#define UCHAR_WIDTH  CHAR_BIT

#undef USHRT_WIDTH
#define USHRT_WIDTH  __SHRT_WIDTH__

#undef SHRT_WIDTH
#define SHRT_WIDTH   __SHRT_WIDTH__

#undef UINT_WIDTH
#define UINT_WIDTH   __INT_WIDTH__

#undef INT_WIDTH
#define INT_WIDTH    __INT_WIDTH__

#undef ULONG_WIDTH
#define ULONG_WIDTH  __LONG_WIDTH__

#undef LONG_WIDTH
#define LONG_WIDTH   __LONG_WIDTH__

#undef ULLONG_WIDTH
#define ULLONG_WIDTH __LLONG_WIDTH__

#undef LLONG_WIDTH
#define LLONG_WIDTH  __LLONG_WIDTH__

#undef BITINT_MAXWIDTH
#define BITINT_MAXWIDTH __BITINT_MAXWIDTH__

#endif  /*  defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L */

#undef CHAR_MIN
#undef CHAR_MAX
#ifdef __CHAR_UNSIGNED__
#define CHAR_MIN 0
#define CHAR_MAX UCHAR_MAX
#else
#define CHAR_MIN SCHAR_MIN
#define CHAR_MAX __SCHAR_MAX__
#endif

#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L

#undef  LLONG_MIN
#define LLONG_MIN  (-__LONG_LONG_MAX__-1LL)

#undef  LLONG_MAX
#define LLONG_MAX  __LONG_LONG_MAX__

#undef  ULLONG_MAX
#define ULLONG_MAX (__LONG_LONG_MAX__*2ULL+1ULL)

#endif

