/* <stdint.h> for the Aro C compiler */

#pragma once


#if __STDC_HOSTED__ && __has_include_next(<stdint.h>)

# include_next <stdint.h>

#else

#define __stdint_int_c_cat(X, Y) X ## Y
#define __stdint_int_c(V, SUFFIX) __stdint_int_c_cat(V, SUFFIX)
#define __stdint_uint_c(V, SUFFIX) __stdint_int_c_cat(V##U, SUFFIX)

#define INTPTR_MIN   (-__INTPTR_MAX__-1)
#define INTPTR_MAX   __INTPTR_MAX__
#define UINTPTR_MAX  __UINTPTR_MAX__
#define PTRDIFF_MIN  (-__PTRDIFF_MAX__-1)
#define PTRDIFF_MAX  __PTRDIFF_MAX__
#define SIZE_MAX     __SIZE_MAX__
#define INTMAX_MIN   (-__INTMAX_MAX__-1)
#define INTMAX_MAX   __INTMAX_MAX__
#define UINTMAX_MAX  __UINTMAX_MAX__
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
# define INTPTR_WIDTH     __INTPTR_WIDTH__
# define UINTPTR_WIDTH    __UINTPTR_WIDTH__
# define INTMAX_WIDTH     __INTMAX_WIDTH__
# define UINTMAX_WIDTH    __UINTMAX_WIDTH__
# define PTRDIFF_WIDTH    __PTRDIFF_WIDTH__
# define SIZE_WIDTH       __SIZE_WIDTH__
# define WCHAR_WIDTH      __WCHAR_WIDTH__
#endif

typedef __INTMAX_TYPE__  intmax_t;
typedef __UINTMAX_TYPE__ uintmax_t;

#ifndef _INTPTR_T
# ifndef __intptr_t_defined
   typedef __INTPTR_TYPE__ intptr_t;
#  define __intptr_t_defined
#  define _INTPTR_T
# endif
#endif

#ifndef _UINTPTR_T
  typedef __UINTPTR_TYPE__ uintptr_t;
# define _UINTPTR_T
#endif


#ifdef __INT64_TYPE__
# ifndef __int8_t_defined /* glibc sys/types.h also defines int64_t*/
   typedef __INT64_TYPE__ int64_t;
# endif /* __int8_t_defined */
  typedef __UINT64_TYPE__ uint64_t;

# undef __int64_c_suffix
# undef __int32_c_suffix
# undef __int16_c_suffix
# undef  __int8_c_suffix
# ifdef __INT64_C_SUFFIX__
#  define __int64_c_suffix __INT64_C_SUFFIX__
#  define __int32_c_suffix __INT64_C_SUFFIX__
#  define __int16_c_suffix __INT64_C_SUFFIX__
#  define  __int8_c_suffix __INT64_C_SUFFIX__
# endif /* __INT64_C_SUFFIX__ */

# ifdef __int64_c_suffix
#  define INT64_C(v) (__stdint_int_c(v, __int64_c_suffix))
#  define UINT64_C(v) (__stdint_uint_c(v, __int64_c_suffix))
# else
#  define INT64_C(v) (v)
#  define UINT64_C(v) (v ## U)
# endif /* __int64_c_suffix */

# define INT64_MAX           INT64_C( 9223372036854775807)
# define INT64_MIN         (-INT64_C( 9223372036854775807)-1)
# define UINT64_MAX         UINT64_C(18446744073709551615)
# if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
#  define UINT64_WIDTH         64
#  define INT64_WIDTH          UINT64_WIDTH
# endif /* __STDC_VERSION__ */

#endif /* __INT64_TYPE__ */

#ifdef __INT32_TYPE__
# ifndef __int8_t_defined /* glibc sys/types.h also defines int32_t*/
   typedef __INT32_TYPE__ int32_t;
# endif /* __int8_t_defined */
  typedef __UINT32_TYPE__ uint32_t;

# undef __int32_c_suffix
# undef __int16_c_suffix
# undef  __int8_c_suffix
# ifdef __INT32_C_SUFFIX__
#  define __int32_c_suffix __INT32_C_SUFFIX__
#  define __int16_c_suffix __INT32_C_SUFFIX__
#  define  __int8_c_suffix __INT32_C_SUFFIX__
# endif /* __INT32_C_SUFFIX__ */

# ifdef __int32_c_suffix
#  define INT32_C(v) (__stdint_int_c(v, __int32_c_suffix))
#  define UINT32_C(v) (__stdint_uint_c(v, __int32_c_suffix))
# else
#  define INT32_C(v) (v)
#  define UINT32_C(v) (v ## U)
# endif /* __int32_c_suffix */

# define INT32_MAX           INT32_C( 2147483647)
# define INT32_MIN         (-INT32_C( 2147483647)-1)
# define UINT32_MAX         UINT32_C(4294967295)
# if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
#  define UINT32_WIDTH         32
#  define INT32_WIDTH          UINT32_WIDTH
# endif /* __STDC_VERSION__ */

#endif /* __INT32_TYPE__ */

#ifdef __INT16_TYPE__
# ifndef __int8_t_defined /* glibc sys/types.h also defines int16_t*/
   typedef __INT16_TYPE__ int16_t;
# endif /* __int8_t_defined */
  typedef __UINT16_TYPE__ uint16_t;

# undef __int16_c_suffix
# undef  __int8_c_suffix
# ifdef __INT16_C_SUFFIX__
#  define __int16_c_suffix __INT16_C_SUFFIX__
#  define  __int8_c_suffix __INT16_C_SUFFIX__
# endif /* __INT16_C_SUFFIX__ */

# ifdef __int16_c_suffix
#  define INT16_C(v) (__stdint_int_c(v, __int16_c_suffix))
#  define UINT16_C(v) (__stdint_uint_c(v, __int16_c_suffix))
# else
#  define INT16_C(v) (v)
#  define UINT16_C(v) (v ## U)
# endif /* __int16_c_suffix */

# define INT16_MAX           INT16_C( 32767)
# define INT16_MIN         (-INT16_C( 32767)-1)
# define UINT16_MAX         UINT16_C(65535)
# if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
#  define UINT16_WIDTH         16
#  define INT16_WIDTH          UINT16_WIDTH
# endif /* __STDC_VERSION__ */

#endif /* __INT16_TYPE__ */

#ifdef __INT8_TYPE__
# ifndef __int8_t_defined /* glibc sys/types.h also defines int8_t*/
   typedef __INT8_TYPE__ int8_t;
# endif /* __int8_t_defined */
  typedef __UINT8_TYPE__ uint8_t;

# undef  __int8_c_suffix
# ifdef __INT8_C_SUFFIX__
#  define  __int8_c_suffix __INT8_C_SUFFIX__
# endif /* __INT8_C_SUFFIX__ */

# ifdef __int8_c_suffix
#  define INT8_C(v) (__stdint_int_c(v, __int8_c_suffix))
#  define UINT8_C(v) (__stdint_uint_c(v, __int8_c_suffix))
# else
#  define INT8_C(v) (v)
#  define UINT8_C(v) (v ## U)
# endif /* __int8_c_suffix */

# define INT8_MAX           INT8_C(127)
# define INT8_MIN         (-INT8_C(127)-1)
# define UINT8_MAX         UINT8_C(255)
# if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
#  define UINT8_WIDTH         8
#  define INT8_WIDTH          UINT8_WIDTH
# endif /* __STDC_VERSION__ */

#endif /* __INT8_TYPE__ */

typedef __INT_LEAST64_TYPE__ int_least64_t;
typedef __INT_LEAST32_TYPE__ int_least32_t;
typedef __INT_LEAST16_TYPE__ int_least16_t;
typedef __INT_LEAST8_TYPE__ int_least8_t;

typedef __UINT_LEAST64_TYPE__ uint_least64_t;
typedef __UINT_LEAST32_TYPE__ uint_least32_t;
typedef __UINT_LEAST16_TYPE__ uint_least16_t;
typedef __UINT_LEAST8_TYPE__ uint_least8_t;

#define INT_LEAST8_MAX __INT_LEAST8_MAX__
#define INT_LEAST8_MIN (-__INT_LEAST8_MAX__-1)
#define UINT_LEAST8_MAX __UINT_LEAST8_MAX__

#define INT_LEAST16_MAX __INT_LEAST16_MAX__
#define INT_LEAST16_MIN (-__INT_LEAST16_MAX__-1)
#define UINT_LEAST16_MAX __UINT_LEAST16_MAX__

#define INT_LEAST32_MAX __INT_LEAST32_MAX__
#define INT_LEAST32_MIN (-__INT_LEAST32_MAX__-1)
#define UINT_LEAST32_MAX __UINT_LEAST32_MAX__

#define INT_LEAST64_MAX __INT_LEAST64_MAX__
#define INT_LEAST64_MIN (-__INT_LEAST64_MAX__-1)
#define UINT_LEAST64_MAX __UINT_LEAST64_MAX__


typedef __INT_FAST64_TYPE__ int_fast64_t;
typedef __INT_FAST32_TYPE__ int_fast32_t;
typedef __INT_FAST16_TYPE__ int_fast16_t;
typedef __INT_FAST8_TYPE__ int_fast8_t;

typedef __UINT_FAST64_TYPE__ uint_fast64_t;
typedef __UINT_FAST32_TYPE__ uint_fast32_t;
typedef __UINT_FAST16_TYPE__ uint_fast16_t;
typedef __UINT_FAST8_TYPE__ uint_fast8_t;

#define INT_FAST8_MAX __INT_FAST8_MAX__
#define INT_FAST8_MIN (-__INT_FAST8_MAX__-1)
#define UINT_FAST8_MAX __UINT_FAST8_MAX__

#define INT_FAST16_MAX __INT_FAST16_MAX__
#define INT_FAST16_MIN (-__INT_FAST16_MAX__-1)
#define UINT_FAST16_MAX __UINT_FAST16_MAX__

#define INT_FAST32_MAX __INT_FAST32_MAX__
#define INT_FAST32_MIN (-__INT_FAST32_MAX__-1)
#define UINT_FAST32_MAX __UINT_FAST32_MAX__

#define INT_FAST64_MAX __INT_FAST64_MAX__
#define INT_FAST64_MIN (-__INT_FAST64_MAX__-1)
#define UINT_FAST64_MAX __UINT_FAST64_MAX__


#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L

#define INT_FAST8_WIDTH   __INT_FAST8_WIDTH__
#define UINT_FAST8_WIDTH  __INT_FAST8_WIDTH__
#define INT_LEAST8_WIDTH  __INT_LEAST8_WIDTH__
#define UINT_LEAST8_WIDTH __INT_LEAST8_WIDTH__

#define INT_FAST16_WIDTH   __INT_FAST16_WIDTH__
#define UINT_FAST16_WIDTH  __INT_FAST16_WIDTH__
#define INT_LEAST16_WIDTH  __INT_LEAST16_WIDTH__
#define UINT_LEAST16_WIDTH __INT_LEAST16_WIDTH__

#define INT_FAST32_WIDTH   __INT_FAST32_WIDTH__
#define UINT_FAST32_WIDTH  __INT_FAST32_WIDTH__
#define INT_LEAST32_WIDTH  __INT_LEAST32_WIDTH__
#define UINT_LEAST32_WIDTH __INT_LEAST32_WIDTH__

#define INT_FAST64_WIDTH   __INT_FAST64_WIDTH__
#define UINT_FAST64_WIDTH  __INT_FAST64_WIDTH__
#define INT_LEAST64_WIDTH  __INT_LEAST64_WIDTH__
#define UINT_LEAST64_WIDTH __INT_LEAST64_WIDTH__

#endif

#ifdef __SIZEOF_INT128__
typedef signed   __int128 int128_t;
typedef unsigned __int128 uint128_t;
typedef signed   __int128 int_fast128_t;
typedef unsigned __int128 uint_fast128_t;
typedef signed   __int128 int_least128_t;
typedef unsigned __int128 uint_least128_t;
# define UINT128_MAX         ((uint128_t)-1)
# define INT128_MAX          ((int128_t)+(UINT128_MAX/2))
# define INT128_MIN          (-INT128_MAX-1)
# define UINT_LEAST128_MAX   UINT128_MAX
# define INT_LEAST128_MAX    INT128_MAX
# define INT_LEAST128_MIN    INT128_MIN
# define UINT_FAST128_MAX    UINT128_MAX
# define INT_FAST128_MAX     INT128_MAX
# define INT_FAST128_MIN     INT128_MIN
# define INT128_WIDTH        128
# define UINT128_WIDTH       128
# define INT_LEAST128_WIDTH  128
# define UINT_LEAST128_WIDTH 128
# define INT_FAST128_WIDTH   128
# define UINT_FAST128_WIDTH  128
# if UINT128_WIDTH > __LLONG_WIDTH__
#  define INT128_C(N)         ((int_least128_t)+N ## WB)
#  define UINT128_C(N)        ((uint_least128_t)+N ## WBU)
# else
#  define INT128_C(N)         ((int_least128_t)+N ## LL)
#  define UINT128_C(N)        ((uint_least128_t)+N ## LLU)
# endif
#endif

#endif /* __STDC_HOSTED__ && __has_include_next(<stdint.h>) */
