// -*- C++ -*-
//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef _LIBCPP_MATH_H
#define _LIBCPP_MATH_H

/*
    math.h synopsis

Macros:

    HUGE_VAL
    HUGE_VALF               // C99
    HUGE_VALL               // C99
    INFINITY                // C99
    NAN                     // C99
    FP_INFINITE             // C99
    FP_NAN                  // C99
    FP_NORMAL               // C99
    FP_SUBNORMAL            // C99
    FP_ZERO                 // C99
    FP_FAST_FMA             // C99
    FP_FAST_FMAF            // C99
    FP_FAST_FMAL            // C99
    FP_ILOGB0               // C99
    FP_ILOGBNAN             // C99
    MATH_ERRNO              // C99
    MATH_ERREXCEPT          // C99
    math_errhandling        // C99

Types:

    float_t                 // C99
    double_t                // C99

// C90

floating_point abs(floating_point x);

floating_point acos (arithmetic x);
float          acosf(float x);
long double    acosl(long double x);

floating_point asin (arithmetic x);
float          asinf(float x);
long double    asinl(long double x);

floating_point atan (arithmetic x);
float          atanf(float x);
long double    atanl(long double x);

floating_point atan2 (arithmetic y, arithmetic x);
float          atan2f(float y, float x);
long double    atan2l(long double y, long double x);

floating_point ceil (arithmetic x);
float          ceilf(float x);
long double    ceill(long double x);

floating_point cos (arithmetic x);
float          cosf(float x);
long double    cosl(long double x);

floating_point cosh (arithmetic x);
float          coshf(float x);
long double    coshl(long double x);

floating_point exp (arithmetic x);
float          expf(float x);
long double    expl(long double x);

floating_point fabs (arithmetic x);
float          fabsf(float x);
long double    fabsl(long double x);

floating_point floor (arithmetic x);
float          floorf(float x);
long double    floorl(long double x);

floating_point fmod (arithmetic x, arithmetic y);
float          fmodf(float x, float y);
long double    fmodl(long double x, long double y);

floating_point frexp (arithmetic value, int* exp);
float          frexpf(float value, int* exp);
long double    frexpl(long double value, int* exp);

floating_point ldexp (arithmetic value, int exp);
float          ldexpf(float value, int exp);
long double    ldexpl(long double value, int exp);

floating_point log (arithmetic x);
float          logf(float x);
long double    logl(long double x);

floating_point log10 (arithmetic x);
float          log10f(float x);
long double    log10l(long double x);

floating_point modf (floating_point value, floating_point* iptr);
float          modff(float value, float* iptr);
long double    modfl(long double value, long double* iptr);

floating_point pow (arithmetic x, arithmetic y);
float          powf(float x, float y);
long double    powl(long double x, long double y);

floating_point sin (arithmetic x);
float          sinf(float x);
long double    sinl(long double x);

floating_point sinh (arithmetic x);
float          sinhf(float x);
long double    sinhl(long double x);

floating_point sqrt (arithmetic x);
float          sqrtf(float x);
long double    sqrtl(long double x);

floating_point tan (arithmetic x);
float          tanf(float x);
long double    tanl(long double x);

floating_point tanh (arithmetic x);
float          tanhf(float x);
long double    tanhl(long double x);

//  C99

bool signbit(arithmetic x);

int fpclassify(arithmetic x);

bool isfinite(arithmetic x);
bool isinf(arithmetic x);
bool isnan(arithmetic x);
bool isnormal(arithmetic x);

bool isgreater(arithmetic x, arithmetic y);
bool isgreaterequal(arithmetic x, arithmetic y);
bool isless(arithmetic x, arithmetic y);
bool islessequal(arithmetic x, arithmetic y);
bool islessgreater(arithmetic x, arithmetic y);
bool isunordered(arithmetic x, arithmetic y);

floating_point acosh (arithmetic x);
float          acoshf(float x);
long double    acoshl(long double x);

floating_point asinh (arithmetic x);
float          asinhf(float x);
long double    asinhl(long double x);

floating_point atanh (arithmetic x);
float          atanhf(float x);
long double    atanhl(long double x);

floating_point cbrt (arithmetic x);
float          cbrtf(float x);
long double    cbrtl(long double x);

floating_point copysign (arithmetic x, arithmetic y);
float          copysignf(float x, float y);
long double    copysignl(long double x, long double y);

floating_point erf (arithmetic x);
float          erff(float x);
long double    erfl(long double x);

floating_point erfc (arithmetic x);
float          erfcf(float x);
long double    erfcl(long double x);

floating_point exp2 (arithmetic x);
float          exp2f(float x);
long double    exp2l(long double x);

floating_point expm1 (arithmetic x);
float          expm1f(float x);
long double    expm1l(long double x);

floating_point fdim (arithmetic x, arithmetic y);
float          fdimf(float x, float y);
long double    fdiml(long double x, long double y);

floating_point fma (arithmetic x, arithmetic y, arithmetic z);
float          fmaf(float x, float y, float z);
long double    fmal(long double x, long double y, long double z);

floating_point fmax (arithmetic x, arithmetic y);
float          fmaxf(float x, float y);
long double    fmaxl(long double x, long double y);

floating_point fmin (arithmetic x, arithmetic y);
float          fminf(float x, float y);
long double    fminl(long double x, long double y);

floating_point hypot (arithmetic x, arithmetic y);
float          hypotf(float x, float y);
long double    hypotl(long double x, long double y);

int ilogb (arithmetic x);
int ilogbf(float x);
int ilogbl(long double x);

floating_point lgamma (arithmetic x);
float          lgammaf(float x);
long double    lgammal(long double x);

long long llrint (arithmetic x);
long long llrintf(float x);
long long llrintl(long double x);

long long llround (arithmetic x);
long long llroundf(float x);
long long llroundl(long double x);

floating_point log1p (arithmetic x);
float          log1pf(float x);
long double    log1pl(long double x);

floating_point log2 (arithmetic x);
float          log2f(float x);
long double    log2l(long double x);

floating_point logb (arithmetic x);
float          logbf(float x);
long double    logbl(long double x);

long lrint (arithmetic x);
long lrintf(float x);
long lrintl(long double x);

long lround (arithmetic x);
long lroundf(float x);
long lroundl(long double x);

double      nan (const char* str);
float       nanf(const char* str);
long double nanl(const char* str);

floating_point nearbyint (arithmetic x);
float          nearbyintf(float x);
long double    nearbyintl(long double x);

floating_point nextafter (arithmetic x, arithmetic y);
float          nextafterf(float x, float y);
long double    nextafterl(long double x, long double y);

floating_point nexttoward (arithmetic x, long double y);
float          nexttowardf(float x, long double y);
long double    nexttowardl(long double x, long double y);

floating_point remainder (arithmetic x, arithmetic y);
float          remainderf(float x, float y);
long double    remainderl(long double x, long double y);

floating_point remquo (arithmetic x, arithmetic y, int* pquo);
float          remquof(float x, float y, int* pquo);
long double    remquol(long double x, long double y, int* pquo);

floating_point rint (arithmetic x);
float          rintf(float x);
long double    rintl(long double x);

floating_point round (arithmetic x);
float          roundf(float x);
long double    roundl(long double x);

floating_point scalbln (arithmetic x, long ex);
float          scalblnf(float x, long ex);
long double    scalblnl(long double x, long ex);

floating_point scalbn (arithmetic x, int ex);
float          scalbnf(float x, int ex);
long double    scalbnl(long double x, int ex);

floating_point tgamma (arithmetic x);
float          tgammaf(float x);
long double    tgammal(long double x);

floating_point trunc (arithmetic x);
float          truncf(float x);
long double    truncl(long double x);

*/

#include <__config>

#if !defined(_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER)
#  pragma GCC system_header
#endif

#  if __has_include_next(<math.h>)
#    include_next <math.h>
#  endif

#ifdef __cplusplus

// We support including .h headers inside 'extern "C"' contexts, so switch
// back to C++ linkage before including these C++ headers.
extern "C++" {

#include <__type_traits/enable_if.h>
#include <__type_traits/is_floating_point.h>
#include <__type_traits/is_integral.h>
#include <__type_traits/is_same.h>
#include <__type_traits/promote.h>
#include <limits>
#include <stdlib.h>


#    ifdef fpclassify
#      undef fpclassify
#    endif

#    ifdef signbit
#      undef signbit
#    endif

#    ifdef isfinite
#      undef isfinite
#    endif

#    ifdef isinf
#      undef isinf
#    endif

#    ifdef isnan
#      undef isnan
#    endif

#    ifdef isnormal
#      undef isnormal
#    endif

#    ifdef isgreater
#      undef isgreater
#    endif

#    ifdef isgreaterequal
#      undef isgreaterequal
#    endif

#    ifdef isless
#      undef isless
#    endif

#    ifdef islessequal
#      undef islessequal
#    endif

#    ifdef islessgreater
#      undef islessgreater
#    endif

#    ifdef isunordered
#      undef isunordered
#    endif

// signbit

template <class _A1, std::__enable_if_t<std::is_floating_point<_A1>::value, int> = 0>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI bool signbit(_A1 __x) _NOEXCEPT {
  return __builtin_signbit(__x);
}

template <class _A1, std::__enable_if_t<std::is_integral<_A1>::value && std::is_signed<_A1>::value, int> = 0>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI bool signbit(_A1 __x) _NOEXCEPT {
  return __x < 0;
}

template <class _A1, std::__enable_if_t<std::is_integral<_A1>::value && !std::is_signed<_A1>::value, int> = 0>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI bool signbit(_A1) _NOEXCEPT {
  return false;
}

// fpclassify

template <class _A1, std::__enable_if_t<std::is_floating_point<_A1>::value, int> = 0>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI int fpclassify(_A1 __x) _NOEXCEPT {
  return __builtin_fpclassify(FP_NAN, FP_INFINITE, FP_NORMAL, FP_SUBNORMAL, FP_ZERO, __x);
}

template <class _A1, std::__enable_if_t<std::is_integral<_A1>::value, int> = 0>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI int fpclassify(_A1 __x) _NOEXCEPT {
  return __x == 0 ? FP_ZERO : FP_NORMAL;
}

// The MSVC runtime already provides these functions as templates
#ifndef _LIBCPP_MSVCRT

// isfinite

template <class _A1,
          std::__enable_if_t<std::is_arithmetic<_A1>::value && std::numeric_limits<_A1>::has_infinity, int> = 0>
_LIBCPP_NODISCARD_EXT _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI bool isfinite(_A1 __x) _NOEXCEPT {
  return __builtin_isfinite((typename std::__promote<_A1>::type)__x);
}

template <class _A1,
          std::__enable_if_t<std::is_arithmetic<_A1>::value && !std::numeric_limits<_A1>::has_infinity, int> = 0>
_LIBCPP_NODISCARD_EXT _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI bool isfinite(_A1) _NOEXCEPT {
  return true;
}

// isinf

template <class _A1,
          std::__enable_if_t<std::is_arithmetic<_A1>::value && std::numeric_limits<_A1>::has_infinity, int> = 0>
_LIBCPP_NODISCARD_EXT _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI bool isinf(_A1 __x) _NOEXCEPT {
  return __builtin_isinf((typename std::__promote<_A1>::type)__x);
}

template <class _A1>
_LIBCPP_NODISCARD_EXT _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI
    typename std::enable_if< std::is_arithmetic<_A1>::value && !std::numeric_limits<_A1>::has_infinity, bool>::type
    isinf(_A1) _NOEXCEPT {
  return false;
}

#      ifdef _LIBCPP_PREFERRED_OVERLOAD
_LIBCPP_NODISCARD_EXT inline _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI bool isinf(float __x) _NOEXCEPT {
  return __builtin_isinf(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI _LIBCPP_PREFERRED_OVERLOAD bool isinf(double __x) _NOEXCEPT {
  return __builtin_isinf(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI bool isinf(long double __x) _NOEXCEPT {
  return __builtin_isinf(__x);
}
#      endif

// isnan

template <class _A1, std::__enable_if_t<std::is_floating_point<_A1>::value, int> = 0>
_LIBCPP_NODISCARD_EXT _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI bool isnan(_A1 __x) _NOEXCEPT {
  return __builtin_isnan(__x);
}

template <class _A1, std::__enable_if_t<std::is_integral<_A1>::value, int> = 0>
_LIBCPP_NODISCARD_EXT _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI bool isnan(_A1) _NOEXCEPT {
  return false;
}

#      ifdef _LIBCPP_PREFERRED_OVERLOAD
_LIBCPP_NODISCARD_EXT inline _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI bool isnan(float __x) _NOEXCEPT {
  return __builtin_isnan(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI _LIBCPP_PREFERRED_OVERLOAD bool isnan(double __x) _NOEXCEPT {
  return __builtin_isnan(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI bool isnan(long double __x) _NOEXCEPT {
  return __builtin_isnan(__x);
}
#      endif

// isnormal

template <class _A1, std::__enable_if_t<std::is_floating_point<_A1>::value, int> = 0>
_LIBCPP_NODISCARD_EXT _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI bool isnormal(_A1 __x) _NOEXCEPT {
  return __builtin_isnormal(__x);
}

template <class _A1, std::__enable_if_t<std::is_integral<_A1>::value, int> = 0>
_LIBCPP_NODISCARD_EXT _LIBCPP_CONSTEXPR_SINCE_CXX23 _LIBCPP_HIDE_FROM_ABI bool isnormal(_A1 __x) _NOEXCEPT {
  return __x != 0;
}

// isgreater

template <class _A1,
          class _A2,
          std::__enable_if_t<std::is_arithmetic<_A1>::value && std::is_arithmetic<_A2>::value, int> = 0>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI bool isgreater(_A1 __x, _A2 __y) _NOEXCEPT {
  typedef typename std::__promote<_A1, _A2>::type type;
  return __builtin_isgreater((type)__x, (type)__y);
}

// isgreaterequal

template <class _A1,
          class _A2,
          std::__enable_if_t<std::is_arithmetic<_A1>::value && std::is_arithmetic<_A2>::value, int> = 0>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI bool isgreaterequal(_A1 __x, _A2 __y) _NOEXCEPT {
  typedef typename std::__promote<_A1, _A2>::type type;
  return __builtin_isgreaterequal((type)__x, (type)__y);
}

// isless

template <class _A1,
          class _A2,
          std::__enable_if_t<std::is_arithmetic<_A1>::value && std::is_arithmetic<_A2>::value, int> = 0>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI bool isless(_A1 __x, _A2 __y) _NOEXCEPT {
  typedef typename std::__promote<_A1, _A2>::type type;
  return __builtin_isless((type)__x, (type)__y);
}

// islessequal

template <class _A1,
          class _A2,
          std::__enable_if_t<std::is_arithmetic<_A1>::value && std::is_arithmetic<_A2>::value, int> = 0>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI bool islessequal(_A1 __x, _A2 __y) _NOEXCEPT {
  typedef typename std::__promote<_A1, _A2>::type type;
  return __builtin_islessequal((type)__x, (type)__y);
}

// islessgreater

template <class _A1,
          class _A2,
          std::__enable_if_t<std::is_arithmetic<_A1>::value && std::is_arithmetic<_A2>::value, int> = 0>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI bool islessgreater(_A1 __x, _A2 __y) _NOEXCEPT {
  typedef typename std::__promote<_A1, _A2>::type type;
  return __builtin_islessgreater((type)__x, (type)__y);
}

// isunordered

template <class _A1,
          class _A2,
          std::__enable_if_t<std::is_arithmetic<_A1>::value && std::is_arithmetic<_A2>::value, int> = 0>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI bool isunordered(_A1 __x, _A2 __y) _NOEXCEPT {
  typedef typename std::__promote<_A1, _A2>::type type;
  return __builtin_isunordered((type)__x, (type)__y);
}

#endif // _LIBCPP_MSVCRT

// abs
//
// handled in stdlib.h

// div
//
// handled in stdlib.h

// We have to provide double overloads for <math.h> to work on platforms that don't provide the full set of math
// functions. To make the overload set work with multiple functions that take the same arguments, we make our overloads
// templates. Functions are preferred over function templates during overload resolution, which means that our overload
// will only be selected when the C library doesn't provide one.

// acos

inline _LIBCPP_HIDE_FROM_ABI float       acos(float __x) _NOEXCEPT       {return __builtin_acosf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double acos(double __x) _NOEXCEPT {
  return __builtin_acos(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double acos(long double __x) _NOEXCEPT {return __builtin_acosl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
acos(_A1 __x) _NOEXCEPT {return __builtin_acos((double)__x);}

// asin

inline _LIBCPP_HIDE_FROM_ABI float       asin(float __x) _NOEXCEPT       {return __builtin_asinf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double asin(double __x) _NOEXCEPT {
  return __builtin_asin(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double asin(long double __x) _NOEXCEPT {return __builtin_asinl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
asin(_A1 __x) _NOEXCEPT {return __builtin_asin((double)__x);}

// atan

inline _LIBCPP_HIDE_FROM_ABI float       atan(float __x) _NOEXCEPT       {return __builtin_atanf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double atan(double __x) _NOEXCEPT {
  return __builtin_atan(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double atan(long double __x) _NOEXCEPT {return __builtin_atanl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
atan(_A1 __x) _NOEXCEPT {return __builtin_atan((double)__x);}

// atan2

inline _LIBCPP_HIDE_FROM_ABI float       atan2(float __y, float __x) _NOEXCEPT             {return __builtin_atan2f(__y, __x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double atan2(double __x, double __y) _NOEXCEPT {
  return __builtin_atan2(__x, __y);
}

inline _LIBCPP_HIDE_FROM_ABI long double atan2(long double __y, long double __x) _NOEXCEPT {return __builtin_atan2l(__y, __x);}

template <class _A1, class _A2>
inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value,
    std::__promote<_A1, _A2>
>::type
atan2(_A1 __y, _A2 __x) _NOEXCEPT
{
    typedef typename std::__promote<_A1, _A2>::type __result_type;
    static_assert((!(std::_IsSame<_A1, __result_type>::value &&
                     std::_IsSame<_A2, __result_type>::value)), "");
    return ::atan2((__result_type)__y, (__result_type)__x);
}

// ceil

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI float       ceil(float __x) _NOEXCEPT       {return __builtin_ceilf(__x);}

template <class = int>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI double ceil(double __x) _NOEXCEPT {
  return __builtin_ceil(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI long double ceil(long double __x) _NOEXCEPT {return __builtin_ceill(__x);}

template <class _A1>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
ceil(_A1 __x) _NOEXCEPT {return __builtin_ceil((double)__x);}

// cos

inline _LIBCPP_HIDE_FROM_ABI float       cos(float __x) _NOEXCEPT       {return __builtin_cosf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double cos(double __x) _NOEXCEPT {
  return __builtin_cos(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double cos(long double __x) _NOEXCEPT {return __builtin_cosl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
cos(_A1 __x) _NOEXCEPT {return __builtin_cos((double)__x);}

// cosh

inline _LIBCPP_HIDE_FROM_ABI float       cosh(float __x) _NOEXCEPT       {return __builtin_coshf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double cosh(double __x) _NOEXCEPT {
  return __builtin_cosh(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double cosh(long double __x) _NOEXCEPT {return __builtin_coshl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
cosh(_A1 __x) _NOEXCEPT {return __builtin_cosh((double)__x);}

// exp

inline _LIBCPP_HIDE_FROM_ABI float       exp(float __x) _NOEXCEPT       {return __builtin_expf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double exp(double __x) _NOEXCEPT {
  return __builtin_exp(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double exp(long double __x) _NOEXCEPT {return __builtin_expl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
exp(_A1 __x) _NOEXCEPT {return __builtin_exp((double)__x);}

// fabs

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI float       fabs(float __x) _NOEXCEPT       {return __builtin_fabsf(__x);}

template <class = int>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI double fabs(double __x) _NOEXCEPT {
  return __builtin_fabs(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI long double fabs(long double __x) _NOEXCEPT {return __builtin_fabsl(__x);}

template <class _A1>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
fabs(_A1 __x) _NOEXCEPT {return __builtin_fabs((double)__x);}

// floor

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI float       floor(float __x) _NOEXCEPT       {return __builtin_floorf(__x);}

template <class = int>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI double floor(double __x) _NOEXCEPT {
  return __builtin_floor(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI long double floor(long double __x) _NOEXCEPT {return __builtin_floorl(__x);}

template <class _A1>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
floor(_A1 __x) _NOEXCEPT {return __builtin_floor((double)__x);}

// fmod

inline _LIBCPP_HIDE_FROM_ABI float       fmod(float __x, float __y) _NOEXCEPT             {return __builtin_fmodf(__x, __y);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double fmod(double __x, double __y) _NOEXCEPT {
  return __builtin_fmod(__x, __y);
}

inline _LIBCPP_HIDE_FROM_ABI long double fmod(long double __x, long double __y) _NOEXCEPT {return __builtin_fmodl(__x, __y);}

template <class _A1, class _A2>
inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value,
    std::__promote<_A1, _A2>
>::type
fmod(_A1 __x, _A2 __y) _NOEXCEPT
{
    typedef typename std::__promote<_A1, _A2>::type __result_type;
    static_assert((!(std::_IsSame<_A1, __result_type>::value &&
                     std::_IsSame<_A2, __result_type>::value)), "");
    return ::fmod((__result_type)__x, (__result_type)__y);
}

// frexp

inline _LIBCPP_HIDE_FROM_ABI float       frexp(float __x, int* __e) _NOEXCEPT       {return __builtin_frexpf(__x, __e);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double frexp(double __x, int* __e) _NOEXCEPT {
  return __builtin_frexp(__x, __e);
}

inline _LIBCPP_HIDE_FROM_ABI long double frexp(long double __x, int* __e) _NOEXCEPT {return __builtin_frexpl(__x, __e);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
frexp(_A1 __x, int* __e) _NOEXCEPT {return __builtin_frexp((double)__x, __e);}

// ldexp

inline _LIBCPP_HIDE_FROM_ABI float       ldexp(float __x, int __e) _NOEXCEPT       {return __builtin_ldexpf(__x, __e);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double ldexp(double __x, int __e) _NOEXCEPT {
  return __builtin_ldexp(__x, __e);
}

inline _LIBCPP_HIDE_FROM_ABI long double ldexp(long double __x, int __e) _NOEXCEPT {return __builtin_ldexpl(__x, __e);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
ldexp(_A1 __x, int __e) _NOEXCEPT {return __builtin_ldexp((double)__x, __e);}

// log

inline _LIBCPP_HIDE_FROM_ABI float       log(float __x) _NOEXCEPT       {return __builtin_logf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double log(double __x) _NOEXCEPT {
  return __builtin_log(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double log(long double __x) _NOEXCEPT {return __builtin_logl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
log(_A1 __x) _NOEXCEPT {return __builtin_log((double)__x);}

// log10

inline _LIBCPP_HIDE_FROM_ABI float       log10(float __x) _NOEXCEPT       {return __builtin_log10f(__x);}


template <class = int>
_LIBCPP_HIDE_FROM_ABI double log10(double __x) _NOEXCEPT {
  return __builtin_log10(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double log10(long double __x) _NOEXCEPT {return __builtin_log10l(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
log10(_A1 __x) _NOEXCEPT {return __builtin_log10((double)__x);}

// modf

inline _LIBCPP_HIDE_FROM_ABI float       modf(float __x, float* __y) _NOEXCEPT             {return __builtin_modff(__x, __y);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double modf(double __x, double* __y) _NOEXCEPT {
  return __builtin_modf(__x, __y);
}

inline _LIBCPP_HIDE_FROM_ABI long double modf(long double __x, long double* __y) _NOEXCEPT {return __builtin_modfl(__x, __y);}

// pow

inline _LIBCPP_HIDE_FROM_ABI float       pow(float __x, float __y) _NOEXCEPT             {return __builtin_powf(__x, __y);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double pow(double __x, double __y) _NOEXCEPT {
  return __builtin_pow(__x, __y);
}

inline _LIBCPP_HIDE_FROM_ABI long double pow(long double __x, long double __y) _NOEXCEPT {return __builtin_powl(__x, __y);}

template <class _A1, class _A2>
inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value,
    std::__promote<_A1, _A2>
>::type
pow(_A1 __x, _A2 __y) _NOEXCEPT
{
    typedef typename std::__promote<_A1, _A2>::type __result_type;
    static_assert((!(std::_IsSame<_A1, __result_type>::value &&
                     std::_IsSame<_A2, __result_type>::value)), "");
    return ::pow((__result_type)__x, (__result_type)__y);
}

// sin

inline _LIBCPP_HIDE_FROM_ABI float       sin(float __x) _NOEXCEPT       {return __builtin_sinf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double sin(double __x) _NOEXCEPT {
  return __builtin_sin(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double sin(long double __x) _NOEXCEPT {return __builtin_sinl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
sin(_A1 __x) _NOEXCEPT {return __builtin_sin((double)__x);}

// sinh

inline _LIBCPP_HIDE_FROM_ABI float       sinh(float __x) _NOEXCEPT       {return __builtin_sinhf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double sinh(double __x) _NOEXCEPT {
  return __builtin_sinh(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double sinh(long double __x) _NOEXCEPT {return __builtin_sinhl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
sinh(_A1 __x) _NOEXCEPT {return __builtin_sinh((double)__x);}

// sqrt

inline _LIBCPP_HIDE_FROM_ABI float       sqrt(float __x) _NOEXCEPT       {return __builtin_sqrtf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double sqrt(double __x) _NOEXCEPT {
  return __builtin_sqrt(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double sqrt(long double __x) _NOEXCEPT {return __builtin_sqrtl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
sqrt(_A1 __x) _NOEXCEPT {return __builtin_sqrt((double)__x);}

// tan

inline _LIBCPP_HIDE_FROM_ABI float       tan(float __x) _NOEXCEPT       {return __builtin_tanf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double tan(double __x) _NOEXCEPT {
  return __builtin_tan(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double tan(long double __x) _NOEXCEPT {return __builtin_tanl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
tan(_A1 __x) _NOEXCEPT {return __builtin_tan((double)__x);}

// tanh

inline _LIBCPP_HIDE_FROM_ABI float       tanh(float __x) _NOEXCEPT       {return __builtin_tanhf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double tanh(double __x) _NOEXCEPT {
  return __builtin_tanh(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double tanh(long double __x) _NOEXCEPT {return __builtin_tanhl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
tanh(_A1 __x) _NOEXCEPT {return __builtin_tanh((double)__x);}

// acosh

inline _LIBCPP_HIDE_FROM_ABI float       acosh(float __x) _NOEXCEPT       {return __builtin_acoshf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double acosh(double __x) _NOEXCEPT {
  return __builtin_acosh(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double acosh(long double __x) _NOEXCEPT {return __builtin_acoshl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
acosh(_A1 __x) _NOEXCEPT {return __builtin_acosh((double)__x);}

// asinh

inline _LIBCPP_HIDE_FROM_ABI float       asinh(float __x) _NOEXCEPT       {return __builtin_asinhf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double asinh(double __x) _NOEXCEPT {
  return __builtin_asinh(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double asinh(long double __x) _NOEXCEPT {return __builtin_asinhl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
asinh(_A1 __x) _NOEXCEPT {return __builtin_asinh((double)__x);}

// atanh

inline _LIBCPP_HIDE_FROM_ABI float       atanh(float __x) _NOEXCEPT       {return __builtin_atanhf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double atanh(double __x) _NOEXCEPT {
  return __builtin_atanh(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double atanh(long double __x) _NOEXCEPT {return __builtin_atanhl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
atanh(_A1 __x) _NOEXCEPT {return __builtin_atanh((double)__x);}

// cbrt

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI float       cbrt(float __x) _NOEXCEPT       {return __builtin_cbrtf(__x);}

template <class = int>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI double cbrt(double __x) _NOEXCEPT {
  return __builtin_cbrt(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI long double cbrt(long double __x) _NOEXCEPT {return __builtin_cbrtl(__x);}

template <class _A1>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
cbrt(_A1 __x) _NOEXCEPT {return __builtin_cbrt((double)__x);}

// copysign

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI float copysign(float __x, float __y) _NOEXCEPT {
  return ::__builtin_copysignf(__x, __y);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI long double copysign(long double __x, long double __y) _NOEXCEPT {
  return ::__builtin_copysignl(__x, __y);
}

template <class _A1, class _A2>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value,
    std::__promote<_A1, _A2>
>::type
    copysign(_A1 __x, _A2 __y) _NOEXCEPT {
  return ::__builtin_copysign(__x, __y);
}

// erf

inline _LIBCPP_HIDE_FROM_ABI float       erf(float __x) _NOEXCEPT       {return __builtin_erff(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double erf(double __x) _NOEXCEPT {
  return __builtin_erf(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double erf(long double __x) _NOEXCEPT {return __builtin_erfl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
erf(_A1 __x) _NOEXCEPT {return __builtin_erf((double)__x);}

// erfc

inline _LIBCPP_HIDE_FROM_ABI float       erfc(float __x) _NOEXCEPT       {return __builtin_erfcf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double erfc(double __x) _NOEXCEPT {
  return __builtin_erfc(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double erfc(long double __x) _NOEXCEPT {return __builtin_erfcl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
erfc(_A1 __x) _NOEXCEPT {return __builtin_erfc((double)__x);}

// exp2

inline _LIBCPP_HIDE_FROM_ABI float       exp2(float __x) _NOEXCEPT       {return __builtin_exp2f(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double exp2(double __x) _NOEXCEPT {
  return __builtin_exp2(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double exp2(long double __x) _NOEXCEPT {return __builtin_exp2l(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
exp2(_A1 __x) _NOEXCEPT {return __builtin_exp2((double)__x);}

// expm1

inline _LIBCPP_HIDE_FROM_ABI float       expm1(float __x) _NOEXCEPT       {return __builtin_expm1f(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double expm1(double __x) _NOEXCEPT {
  return __builtin_expm1(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double expm1(long double __x) _NOEXCEPT {return __builtin_expm1l(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
expm1(_A1 __x) _NOEXCEPT {return __builtin_expm1((double)__x);}

// fdim

inline _LIBCPP_HIDE_FROM_ABI float       fdim(float __x, float __y) _NOEXCEPT             {return __builtin_fdimf(__x, __y);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double fdim(double __x, double __y) _NOEXCEPT {
  return __builtin_fdim(__x, __y);
}

inline _LIBCPP_HIDE_FROM_ABI long double fdim(long double __x, long double __y) _NOEXCEPT {return __builtin_fdiml(__x, __y);}

template <class _A1, class _A2>
inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value,
    std::__promote<_A1, _A2>
>::type
fdim(_A1 __x, _A2 __y) _NOEXCEPT
{
    typedef typename std::__promote<_A1, _A2>::type __result_type;
    static_assert((!(std::_IsSame<_A1, __result_type>::value &&
                     std::_IsSame<_A2, __result_type>::value)), "");
    return ::fdim((__result_type)__x, (__result_type)__y);
}

// fma

inline _LIBCPP_HIDE_FROM_ABI float       fma(float __x, float __y, float __z) _NOEXCEPT
{
    return __builtin_fmaf(__x, __y, __z);
}


template <class = int>
_LIBCPP_HIDE_FROM_ABI double fma(double __x, double __y, double __z) _NOEXCEPT {
  return __builtin_fma(__x, __y, __z);
}

inline _LIBCPP_HIDE_FROM_ABI long double fma(long double __x, long double __y, long double __z) _NOEXCEPT
{
    return __builtin_fmal(__x, __y, __z);
}

template <class _A1, class _A2, class _A3>
inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value &&
    std::is_arithmetic<_A3>::value,
    std::__promote<_A1, _A2, _A3>
>::type
fma(_A1 __x, _A2 __y, _A3 __z) _NOEXCEPT
{
    typedef typename std::__promote<_A1, _A2, _A3>::type __result_type;
    static_assert((!(std::_IsSame<_A1, __result_type>::value &&
                     std::_IsSame<_A2, __result_type>::value &&
                     std::_IsSame<_A3, __result_type>::value)), "");
    return __builtin_fma((__result_type)__x, (__result_type)__y, (__result_type)__z);
}

// fmax

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI float       fmax(float __x, float __y) _NOEXCEPT             {return __builtin_fmaxf(__x, __y);}

template <class = int>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI double fmax(double __x, double __y) _NOEXCEPT {
  return __builtin_fmax(__x, __y);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI long double fmax(long double __x, long double __y) _NOEXCEPT {return __builtin_fmaxl(__x, __y);}

template <class _A1, class _A2>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value,
    std::__promote<_A1, _A2>
>::type
fmax(_A1 __x, _A2 __y) _NOEXCEPT
{
    typedef typename std::__promote<_A1, _A2>::type __result_type;
    static_assert((!(std::_IsSame<_A1, __result_type>::value &&
                     std::_IsSame<_A2, __result_type>::value)), "");
    return ::fmax((__result_type)__x, (__result_type)__y);
}

// fmin

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI float       fmin(float __x, float __y) _NOEXCEPT             {return __builtin_fminf(__x, __y);}

template <class = int>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI double fmin(double __x, double __y) _NOEXCEPT {
  return __builtin_fmin(__x, __y);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI long double fmin(long double __x, long double __y) _NOEXCEPT {return __builtin_fminl(__x, __y);}

template <class _A1, class _A2>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value,
    std::__promote<_A1, _A2>
>::type
fmin(_A1 __x, _A2 __y) _NOEXCEPT
{
    typedef typename std::__promote<_A1, _A2>::type __result_type;
    static_assert((!(std::_IsSame<_A1, __result_type>::value &&
                     std::_IsSame<_A2, __result_type>::value)), "");
    return ::fmin((__result_type)__x, (__result_type)__y);
}

// hypot

inline _LIBCPP_HIDE_FROM_ABI float       hypot(float __x, float __y) _NOEXCEPT             {return __builtin_hypotf(__x, __y);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double hypot(double __x, double __y) _NOEXCEPT {
  return __builtin_hypot(__x, __y);
}

inline _LIBCPP_HIDE_FROM_ABI long double hypot(long double __x, long double __y) _NOEXCEPT {return __builtin_hypotl(__x, __y);}

template <class _A1, class _A2>
inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value,
    std::__promote<_A1, _A2>
>::type
hypot(_A1 __x, _A2 __y) _NOEXCEPT
{
    typedef typename std::__promote<_A1, _A2>::type __result_type;
    static_assert((!(std::_IsSame<_A1, __result_type>::value &&
                     std::_IsSame<_A2, __result_type>::value)), "");
    return ::hypot((__result_type)__x, (__result_type)__y);
}

// ilogb

inline _LIBCPP_HIDE_FROM_ABI int ilogb(float __x) _NOEXCEPT       {return __builtin_ilogbf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double ilogb(double __x) _NOEXCEPT {
  return __builtin_ilogb(__x);
}

inline _LIBCPP_HIDE_FROM_ABI int ilogb(long double __x) _NOEXCEPT {return __builtin_ilogbl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, int>::type
ilogb(_A1 __x) _NOEXCEPT {return __builtin_ilogb((double)__x);}

// lgamma

inline _LIBCPP_HIDE_FROM_ABI float       lgamma(float __x) _NOEXCEPT       {return __builtin_lgammaf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double lgamma(double __x) _NOEXCEPT {
  return __builtin_lgamma(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double lgamma(long double __x) _NOEXCEPT {return __builtin_lgammal(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
lgamma(_A1 __x) _NOEXCEPT {return __builtin_lgamma((double)__x);}

// llrint

inline _LIBCPP_HIDE_FROM_ABI long long llrint(float __x) _NOEXCEPT
{
    return __builtin_llrintf(__x);
}

template <class = int>
_LIBCPP_HIDE_FROM_ABI long long llrint(double __x) _NOEXCEPT {
  return __builtin_llrint(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long long llrint(long double __x) _NOEXCEPT
{
    return __builtin_llrintl(__x);
}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, long long>::type
llrint(_A1 __x) _NOEXCEPT
{
    return __builtin_llrint((double)__x);
}

// llround

inline _LIBCPP_HIDE_FROM_ABI long long llround(float __x) _NOEXCEPT
{
    return __builtin_llroundf(__x);
}

template <class = int>
_LIBCPP_HIDE_FROM_ABI long long llround(double __x) _NOEXCEPT {
  return __builtin_llround(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long long llround(long double __x) _NOEXCEPT
{
    return __builtin_llroundl(__x);
}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, long long>::type
llround(_A1 __x) _NOEXCEPT
{
    return __builtin_llround((double)__x);
}

// log1p

inline _LIBCPP_HIDE_FROM_ABI float       log1p(float __x) _NOEXCEPT       {return __builtin_log1pf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double log1p(double __x) _NOEXCEPT {
  return __builtin_log1p(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double log1p(long double __x) _NOEXCEPT {return __builtin_log1pl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
log1p(_A1 __x) _NOEXCEPT {return __builtin_log1p((double)__x);}

// log2

inline _LIBCPP_HIDE_FROM_ABI float       log2(float __x) _NOEXCEPT       {return __builtin_log2f(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double log2(double __x) _NOEXCEPT {
  return __builtin_log2(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double log2(long double __x) _NOEXCEPT {return __builtin_log2l(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
log2(_A1 __x) _NOEXCEPT {return __builtin_log2((double)__x);}

// logb

inline _LIBCPP_HIDE_FROM_ABI float       logb(float __x) _NOEXCEPT       {return __builtin_logbf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double logb(double __x) _NOEXCEPT {
  return __builtin_logb(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double logb(long double __x) _NOEXCEPT {return __builtin_logbl(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
logb(_A1 __x) _NOEXCEPT {return __builtin_logb((double)__x);}

// lrint

inline _LIBCPP_HIDE_FROM_ABI long lrint(float __x) _NOEXCEPT
{
    return __builtin_lrintf(__x);
}

template <class = int>
_LIBCPP_HIDE_FROM_ABI long lrint(double __x) _NOEXCEPT {
  return __builtin_lrint(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long lrint(long double __x) _NOEXCEPT
{
    return __builtin_lrintl(__x);
}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, long>::type
lrint(_A1 __x) _NOEXCEPT
{
    return __builtin_lrint((double)__x);
}

// lround

inline _LIBCPP_HIDE_FROM_ABI long lround(float __x) _NOEXCEPT
{
    return __builtin_lroundf(__x);
}

template <class = int>
_LIBCPP_HIDE_FROM_ABI long lround(double __x) _NOEXCEPT {
  return __builtin_lround(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long lround(long double __x) _NOEXCEPT
{
    return __builtin_lroundl(__x);
}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, long>::type
lround(_A1 __x) _NOEXCEPT
{
    return __builtin_lround((double)__x);
}

// nan

// nearbyint

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI float       nearbyint(float __x) _NOEXCEPT       {return __builtin_nearbyintf(__x);}

template <class = int>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI double nearbyint(double __x) _NOEXCEPT {
  return __builtin_nearbyint(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI long double nearbyint(long double __x) _NOEXCEPT {return __builtin_nearbyintl(__x);}

template <class _A1>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
nearbyint(_A1 __x) _NOEXCEPT {return __builtin_nearbyint((double)__x);}

// nextafter

inline _LIBCPP_HIDE_FROM_ABI float       nextafter(float __x, float __y) _NOEXCEPT             {return __builtin_nextafterf(__x, __y);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double nextafter(double __x, double __y) _NOEXCEPT {
  return __builtin_nextafter(__x, __y);
}

inline _LIBCPP_HIDE_FROM_ABI long double nextafter(long double __x, long double __y) _NOEXCEPT {return __builtin_nextafterl(__x, __y);}

template <class _A1, class _A2>
inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value,
    std::__promote<_A1, _A2>
>::type
nextafter(_A1 __x, _A2 __y) _NOEXCEPT
{
    typedef typename std::__promote<_A1, _A2>::type __result_type;
    static_assert((!(std::_IsSame<_A1, __result_type>::value &&
                     std::_IsSame<_A2, __result_type>::value)), "");
    return ::nextafter((__result_type)__x, (__result_type)__y);
}

// nexttoward

inline _LIBCPP_HIDE_FROM_ABI float       nexttoward(float __x, long double __y) _NOEXCEPT       {return __builtin_nexttowardf(__x, __y);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double nexttoward(double __x, long double __y) _NOEXCEPT {
  return __builtin_nexttoward(__x, __y);
}

inline _LIBCPP_HIDE_FROM_ABI long double nexttoward(long double __x, long double __y) _NOEXCEPT {return __builtin_nexttowardl(__x, __y);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
nexttoward(_A1 __x, long double __y) _NOEXCEPT {return __builtin_nexttoward((double)__x, __y);}

// remainder

inline _LIBCPP_HIDE_FROM_ABI float       remainder(float __x, float __y) _NOEXCEPT             {return __builtin_remainderf(__x, __y);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double remainder(double __x, double __y) _NOEXCEPT {
  return __builtin_remainder(__x, __y);
}

inline _LIBCPP_HIDE_FROM_ABI long double remainder(long double __x, long double __y) _NOEXCEPT {return __builtin_remainderl(__x, __y);}

template <class _A1, class _A2>
inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value,
    std::__promote<_A1, _A2>
>::type
remainder(_A1 __x, _A2 __y) _NOEXCEPT
{
    typedef typename std::__promote<_A1, _A2>::type __result_type;
    static_assert((!(std::_IsSame<_A1, __result_type>::value &&
                     std::_IsSame<_A2, __result_type>::value)), "");
    return ::remainder((__result_type)__x, (__result_type)__y);
}

// remquo

inline _LIBCPP_HIDE_FROM_ABI float       remquo(float __x, float __y, int* __z) _NOEXCEPT             {return __builtin_remquof(__x, __y, __z);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double remquo(double __x, double __y, int* __z) _NOEXCEPT {
  return __builtin_remquo(__x, __y, __z);
}

inline _LIBCPP_HIDE_FROM_ABI long double remquo(long double __x, long double __y, int* __z) _NOEXCEPT {return __builtin_remquol(__x, __y, __z);}

template <class _A1, class _A2>
inline _LIBCPP_HIDE_FROM_ABI
typename std::__enable_if_t
<
    std::is_arithmetic<_A1>::value &&
    std::is_arithmetic<_A2>::value,
    std::__promote<_A1, _A2>
>::type
remquo(_A1 __x, _A2 __y, int* __z) _NOEXCEPT
{
    typedef typename std::__promote<_A1, _A2>::type __result_type;
    static_assert((!(std::_IsSame<_A1, __result_type>::value &&
                     std::_IsSame<_A2, __result_type>::value)), "");
    return ::remquo((__result_type)__x, (__result_type)__y, __z);
}

// rint

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI float       rint(float __x) _NOEXCEPT
{
    return __builtin_rintf(__x);
}

template <class = int>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI double rint(double __x) _NOEXCEPT {
  return __builtin_rint(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI long double rint(long double __x) _NOEXCEPT
{
    return __builtin_rintl(__x);
}

template <class _A1>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
rint(_A1 __x) _NOEXCEPT
{
    return __builtin_rint((double)__x);
}

// round

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI float       round(float __x) _NOEXCEPT
{
    return __builtin_round(__x);
}

template <class = int>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI double round(double __x) _NOEXCEPT {
  return __builtin_round(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI long double round(long double __x) _NOEXCEPT
{
    return __builtin_roundl(__x);
}

template <class _A1>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
round(_A1 __x) _NOEXCEPT
{
    return __builtin_round((double)__x);
}

// scalbln

inline _LIBCPP_HIDE_FROM_ABI float       scalbln(float __x, long __y) _NOEXCEPT       {return __builtin_scalblnf(__x, __y);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double scalbln(double __x, long __y) _NOEXCEPT {
  return __builtin_scalbln(__x, __y);
}

inline _LIBCPP_HIDE_FROM_ABI long double scalbln(long double __x, long __y) _NOEXCEPT {return __builtin_scalblnl(__x, __y);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
scalbln(_A1 __x, long __y) _NOEXCEPT {return __builtin_scalbln((double)__x, __y);}

// scalbn

inline _LIBCPP_HIDE_FROM_ABI float       scalbn(float __x, int __y) _NOEXCEPT       {return __builtin_scalbnf(__x, __y);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double scalbn(double __x, int __y) _NOEXCEPT {
  return __builtin_scalbn(__x, __y);
}

inline _LIBCPP_HIDE_FROM_ABI long double scalbn(long double __x, int __y) _NOEXCEPT {return __builtin_scalbnl(__x, __y);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
scalbn(_A1 __x, int __y) _NOEXCEPT {return __builtin_scalbn((double)__x, __y);}

// tgamma

inline _LIBCPP_HIDE_FROM_ABI float       tgamma(float __x) _NOEXCEPT       {return __builtin_tgammaf(__x);}

template <class = int>
_LIBCPP_HIDE_FROM_ABI double tgamma(double __x) _NOEXCEPT {
  return __builtin_tgamma(__x);
}

inline _LIBCPP_HIDE_FROM_ABI long double tgamma(long double __x) _NOEXCEPT {return __builtin_tgammal(__x);}

template <class _A1>
inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
tgamma(_A1 __x) _NOEXCEPT {return __builtin_tgamma((double)__x);}

// trunc

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI float       trunc(float __x) _NOEXCEPT
{
    return __builtin_trunc(__x);
}

template <class = int>
_LIBCPP_NODISCARD_EXT _LIBCPP_HIDE_FROM_ABI double trunc(double __x) _NOEXCEPT {
  return __builtin_trunc(__x);
}

_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI long double trunc(long double __x) _NOEXCEPT
{
    return __builtin_truncl(__x);
}

template <class _A1>
_LIBCPP_NODISCARD_EXT inline _LIBCPP_HIDE_FROM_ABI
typename std::enable_if<std::is_integral<_A1>::value, double>::type
trunc(_A1 __x) _NOEXCEPT
{
    return __builtin_trunc((double)__x);
}

} // extern "C++"

#endif // __cplusplus

#else // _LIBCPP_MATH_H

// This include lives outside the header guard in order to support an MSVC
// extension which allows users to do:
//
// #define _USE_MATH_DEFINES
// #include <math.h>
//
// and receive the definitions of mathematical constants, even if <math.h>
// has previously been included.
#if defined(_LIBCPP_MSVCRT) && defined(_USE_MATH_DEFINES)
#include_next <math.h>
#endif

#endif // _LIBCPP_MATH_H
