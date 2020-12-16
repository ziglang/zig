/*===---- __clang_hip_cmath.h - HIP cmath decls -----------------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __CLANG_HIP_CMATH_H__
#define __CLANG_HIP_CMATH_H__

#if !defined(__HIP__)
#error "This file is for HIP and OpenMP AMDGCN device compilation only."
#endif

#if defined(__cplusplus)
#include <limits>
#include <type_traits>
#include <utility>
#endif
#include <limits.h>
#include <stdint.h>

#pragma push_macro("__DEVICE__")
#define __DEVICE__ static __device__ inline __attribute__((always_inline))

// Start with functions that cannot be defined by DEF macros below.
#if defined(__cplusplus)
__DEVICE__ double abs(double __x) { return ::fabs(__x); }
__DEVICE__ float abs(float __x) { return ::fabsf(__x); }
__DEVICE__ long long abs(long long __n) { return ::llabs(__n); }
__DEVICE__ long abs(long __n) { return ::labs(__n); }
__DEVICE__ float fma(float __x, float __y, float __z) {
  return ::fmaf(__x, __y, __z);
}
__DEVICE__ int fpclassify(float __x) {
  return __builtin_fpclassify(FP_NAN, FP_INFINITE, FP_NORMAL, FP_SUBNORMAL,
                              FP_ZERO, __x);
}
__DEVICE__ int fpclassify(double __x) {
  return __builtin_fpclassify(FP_NAN, FP_INFINITE, FP_NORMAL, FP_SUBNORMAL,
                              FP_ZERO, __x);
}
__DEVICE__ float frexp(float __arg, int *__exp) {
  return ::frexpf(__arg, __exp);
}
__DEVICE__ bool isfinite(float __x) { return ::__finitef(__x); }
__DEVICE__ bool isfinite(double __x) { return ::__finite(__x); }
__DEVICE__ bool isgreater(float __x, float __y) {
  return __builtin_isgreater(__x, __y);
}
__DEVICE__ bool isgreater(double __x, double __y) {
  return __builtin_isgreater(__x, __y);
}
__DEVICE__ bool isgreaterequal(float __x, float __y) {
  return __builtin_isgreaterequal(__x, __y);
}
__DEVICE__ bool isgreaterequal(double __x, double __y) {
  return __builtin_isgreaterequal(__x, __y);
}
__DEVICE__ bool isinf(float __x) { return ::__isinff(__x); }
__DEVICE__ bool isinf(double __x) { return ::__isinf(__x); }
__DEVICE__ bool isless(float __x, float __y) {
  return __builtin_isless(__x, __y);
}
__DEVICE__ bool isless(double __x, double __y) {
  return __builtin_isless(__x, __y);
}
__DEVICE__ bool islessequal(float __x, float __y) {
  return __builtin_islessequal(__x, __y);
}
__DEVICE__ bool islessequal(double __x, double __y) {
  return __builtin_islessequal(__x, __y);
}
__DEVICE__ bool islessgreater(float __x, float __y) {
  return __builtin_islessgreater(__x, __y);
}
__DEVICE__ bool islessgreater(double __x, double __y) {
  return __builtin_islessgreater(__x, __y);
}
__DEVICE__ bool isnan(float __x) { return ::__isnanf(__x); }
__DEVICE__ bool isnan(double __x) { return ::__isnan(__x); }
__DEVICE__ bool isnormal(float __x) { return __builtin_isnormal(__x); }
__DEVICE__ bool isnormal(double __x) { return __builtin_isnormal(__x); }
__DEVICE__ bool isunordered(float __x, float __y) {
  return __builtin_isunordered(__x, __y);
}
__DEVICE__ bool isunordered(double __x, double __y) {
  return __builtin_isunordered(__x, __y);
}
__DEVICE__ float modf(float __x, float *__iptr) { return ::modff(__x, __iptr); }
__DEVICE__ float pow(float __base, int __iexp) {
  return ::powif(__base, __iexp);
}
__DEVICE__ double pow(double __base, int __iexp) {
  return ::powi(__base, __iexp);
}
__DEVICE__ float remquo(float __x, float __y, int *__quo) {
  return ::remquof(__x, __y, __quo);
}
__DEVICE__ float scalbln(float __x, long int __n) {
  return ::scalblnf(__x, __n);
}
__DEVICE__ bool signbit(float __x) { return ::__signbitf(__x); }
__DEVICE__ bool signbit(double __x) { return ::__signbit(__x); }

// Notably missing above is nexttoward.  We omit it because
// ocml doesn't provide an implementation, and we don't want to be in the
// business of implementing tricky libm functions in this header.

// Other functions.
__DEVICE__ _Float16 fma(_Float16 __x, _Float16 __y, _Float16 __z) {
  return __ocml_fma_f16(__x, __y, __z);
}
__DEVICE__ _Float16 pow(_Float16 __base, int __iexp) {
  return __ocml_pown_f16(__base, __iexp);
}

// BEGIN DEF_FUN and HIP_OVERLOAD

// BEGIN DEF_FUN

#pragma push_macro("__DEF_FUN1")
#pragma push_macro("__DEF_FUN2")
#pragma push_macro("__DEF_FUN2_FI")

// Define cmath functions with float argument and returns __retty.
#define __DEF_FUN1(__retty, __func)                                            \
  __DEVICE__                                                                   \
  __retty __func(float __x) { return __func##f(__x); }

// Define cmath functions with two float arguments and returns __retty.
#define __DEF_FUN2(__retty, __func)                                            \
  __DEVICE__                                                                   \
  __retty __func(float __x, float __y) { return __func##f(__x, __y); }

// Define cmath functions with a float and an int argument and returns __retty.
#define __DEF_FUN2_FI(__retty, __func)                                         \
  __DEVICE__                                                                   \
  __retty __func(float __x, int __y) { return __func##f(__x, __y); }

__DEF_FUN1(float, acos)
__DEF_FUN1(float, acosh)
__DEF_FUN1(float, asin)
__DEF_FUN1(float, asinh)
__DEF_FUN1(float, atan)
__DEF_FUN2(float, atan2)
__DEF_FUN1(float, atanh)
__DEF_FUN1(float, cbrt)
__DEF_FUN1(float, ceil)
__DEF_FUN2(float, copysign)
__DEF_FUN1(float, cos)
__DEF_FUN1(float, cosh)
__DEF_FUN1(float, erf)
__DEF_FUN1(float, erfc)
__DEF_FUN1(float, exp)
__DEF_FUN1(float, exp2)
__DEF_FUN1(float, expm1)
__DEF_FUN1(float, fabs)
__DEF_FUN2(float, fdim)
__DEF_FUN1(float, floor)
__DEF_FUN2(float, fmax)
__DEF_FUN2(float, fmin)
__DEF_FUN2(float, fmod)
__DEF_FUN2(float, hypot)
__DEF_FUN1(int, ilogb)
__DEF_FUN2_FI(float, ldexp)
__DEF_FUN1(float, lgamma)
__DEF_FUN1(float, log)
__DEF_FUN1(float, log10)
__DEF_FUN1(float, log1p)
__DEF_FUN1(float, log2)
__DEF_FUN1(float, logb)
__DEF_FUN1(long long, llrint)
__DEF_FUN1(long long, llround)
__DEF_FUN1(long, lrint)
__DEF_FUN1(long, lround)
__DEF_FUN1(float, nearbyint)
__DEF_FUN2(float, nextafter)
__DEF_FUN2(float, pow)
__DEF_FUN2(float, remainder)
__DEF_FUN1(float, rint)
__DEF_FUN1(float, round)
__DEF_FUN2_FI(float, scalbn)
__DEF_FUN1(float, sin)
__DEF_FUN1(float, sinh)
__DEF_FUN1(float, sqrt)
__DEF_FUN1(float, tan)
__DEF_FUN1(float, tanh)
__DEF_FUN1(float, tgamma)
__DEF_FUN1(float, trunc)

#pragma pop_macro("__DEF_FUN1")
#pragma pop_macro("__DEF_FUN2")
#pragma pop_macro("__DEF_FUN2_FI")

// END DEF_FUN

// BEGIN HIP_OVERLOAD

#pragma push_macro("__HIP_OVERLOAD1")
#pragma push_macro("__HIP_OVERLOAD2")

// __hip_enable_if::type is a type function which returns __T if __B is true.
template <bool __B, class __T = void> struct __hip_enable_if {};

template <class __T> struct __hip_enable_if<true, __T> { typedef __T type; };

// decltype is only available in C++11 and above.
#if __cplusplus >= 201103L
// __hip_promote
namespace __hip {

template <class _Tp> struct __numeric_type {
  static void __test(...);
  static _Float16 __test(_Float16);
  static float __test(float);
  static double __test(char);
  static double __test(int);
  static double __test(unsigned);
  static double __test(long);
  static double __test(unsigned long);
  static double __test(long long);
  static double __test(unsigned long long);
  static double __test(double);
  // No support for long double, use double instead.
  static double __test(long double);

  typedef decltype(__test(std::declval<_Tp>())) type;
  static const bool value = !std::is_same<type, void>::value;
};

template <> struct __numeric_type<void> { static const bool value = true; };

template <class _A1, class _A2 = void, class _A3 = void,
          bool = __numeric_type<_A1>::value &&__numeric_type<_A2>::value
              &&__numeric_type<_A3>::value>
class __promote_imp {
public:
  static const bool value = false;
};

template <class _A1, class _A2, class _A3>
class __promote_imp<_A1, _A2, _A3, true> {
private:
  typedef typename __promote_imp<_A1>::type __type1;
  typedef typename __promote_imp<_A2>::type __type2;
  typedef typename __promote_imp<_A3>::type __type3;

public:
  typedef decltype(__type1() + __type2() + __type3()) type;
  static const bool value = true;
};

template <class _A1, class _A2> class __promote_imp<_A1, _A2, void, true> {
private:
  typedef typename __promote_imp<_A1>::type __type1;
  typedef typename __promote_imp<_A2>::type __type2;

public:
  typedef decltype(__type1() + __type2()) type;
  static const bool value = true;
};

template <class _A1> class __promote_imp<_A1, void, void, true> {
public:
  typedef typename __numeric_type<_A1>::type type;
  static const bool value = true;
};

template <class _A1, class _A2 = void, class _A3 = void>
class __promote : public __promote_imp<_A1, _A2, _A3> {};

} // namespace __hip
#endif //__cplusplus >= 201103L

// __HIP_OVERLOAD1 is used to resolve function calls with integer argument to
// avoid compilation error due to ambibuity. e.g. floor(5) is resolved with
// floor(double).
#define __HIP_OVERLOAD1(__retty, __fn)                                         \
  template <typename __T>                                                      \
  __DEVICE__ typename __hip_enable_if<std::numeric_limits<__T>::is_integer,    \
                                      __retty>::type                           \
  __fn(__T __x) {                                                              \
    return ::__fn((double)__x);                                                \
  }

// __HIP_OVERLOAD2 is used to resolve function calls with mixed float/double
// or integer argument to avoid compilation error due to ambibuity. e.g.
// max(5.0f, 6.0) is resolved with max(double, double).
#if __cplusplus >= 201103L
#define __HIP_OVERLOAD2(__retty, __fn)                                         \
  template <typename __T1, typename __T2>                                      \
  __DEVICE__ typename __hip_enable_if<                                         \
      std::numeric_limits<__T1>::is_specialized &&                             \
          std::numeric_limits<__T2>::is_specialized,                           \
      typename __hip::__promote<__T1, __T2>::type>::type                       \
  __fn(__T1 __x, __T2 __y) {                                                   \
    typedef typename __hip::__promote<__T1, __T2>::type __result_type;         \
    return __fn((__result_type)__x, (__result_type)__y);                       \
  }
#else
#define __HIP_OVERLOAD2(__retty, __fn)                                         \
  template <typename __T1, typename __T2>                                      \
  __DEVICE__                                                                   \
      typename __hip_enable_if<std::numeric_limits<__T1>::is_specialized &&    \
                                   std::numeric_limits<__T2>::is_specialized,  \
                               __retty>::type                                  \
      __fn(__T1 __x, __T2 __y) {                                               \
    return __fn((double)__x, (double)__y);                                     \
  }
#endif

__HIP_OVERLOAD1(double, abs)
__HIP_OVERLOAD1(double, acos)
__HIP_OVERLOAD1(double, acosh)
__HIP_OVERLOAD1(double, asin)
__HIP_OVERLOAD1(double, asinh)
__HIP_OVERLOAD1(double, atan)
__HIP_OVERLOAD2(double, atan2)
__HIP_OVERLOAD1(double, atanh)
__HIP_OVERLOAD1(double, cbrt)
__HIP_OVERLOAD1(double, ceil)
__HIP_OVERLOAD2(double, copysign)
__HIP_OVERLOAD1(double, cos)
__HIP_OVERLOAD1(double, cosh)
__HIP_OVERLOAD1(double, erf)
__HIP_OVERLOAD1(double, erfc)
__HIP_OVERLOAD1(double, exp)
__HIP_OVERLOAD1(double, exp2)
__HIP_OVERLOAD1(double, expm1)
__HIP_OVERLOAD1(double, fabs)
__HIP_OVERLOAD2(double, fdim)
__HIP_OVERLOAD1(double, floor)
__HIP_OVERLOAD2(double, fmax)
__HIP_OVERLOAD2(double, fmin)
__HIP_OVERLOAD2(double, fmod)
__HIP_OVERLOAD1(int, fpclassify)
__HIP_OVERLOAD2(double, hypot)
__HIP_OVERLOAD1(int, ilogb)
__HIP_OVERLOAD1(bool, isfinite)
__HIP_OVERLOAD2(bool, isgreater)
__HIP_OVERLOAD2(bool, isgreaterequal)
__HIP_OVERLOAD1(bool, isinf)
__HIP_OVERLOAD2(bool, isless)
__HIP_OVERLOAD2(bool, islessequal)
__HIP_OVERLOAD2(bool, islessgreater)
__HIP_OVERLOAD1(bool, isnan)
__HIP_OVERLOAD1(bool, isnormal)
__HIP_OVERLOAD2(bool, isunordered)
__HIP_OVERLOAD1(double, lgamma)
__HIP_OVERLOAD1(double, log)
__HIP_OVERLOAD1(double, log10)
__HIP_OVERLOAD1(double, log1p)
__HIP_OVERLOAD1(double, log2)
__HIP_OVERLOAD1(double, logb)
__HIP_OVERLOAD1(long long, llrint)
__HIP_OVERLOAD1(long long, llround)
__HIP_OVERLOAD1(long, lrint)
__HIP_OVERLOAD1(long, lround)
__HIP_OVERLOAD1(double, nearbyint)
__HIP_OVERLOAD2(double, nextafter)
__HIP_OVERLOAD2(double, pow)
__HIP_OVERLOAD2(double, remainder)
__HIP_OVERLOAD1(double, rint)
__HIP_OVERLOAD1(double, round)
__HIP_OVERLOAD1(bool, signbit)
__HIP_OVERLOAD1(double, sin)
__HIP_OVERLOAD1(double, sinh)
__HIP_OVERLOAD1(double, sqrt)
__HIP_OVERLOAD1(double, tan)
__HIP_OVERLOAD1(double, tanh)
__HIP_OVERLOAD1(double, tgamma)
__HIP_OVERLOAD1(double, trunc)

// Overload these but don't add them to std, they are not part of cmath.
__HIP_OVERLOAD2(double, max)
__HIP_OVERLOAD2(double, min)

// Additional Overloads that don't quite match HIP_OVERLOAD.
#if __cplusplus >= 201103L
template <typename __T1, typename __T2, typename __T3>
__DEVICE__ typename __hip_enable_if<
    std::numeric_limits<__T1>::is_specialized &&
        std::numeric_limits<__T2>::is_specialized &&
        std::numeric_limits<__T3>::is_specialized,
    typename __hip::__promote<__T1, __T2, __T3>::type>::type
fma(__T1 __x, __T2 __y, __T3 __z) {
  typedef typename __hip::__promote<__T1, __T2, __T3>::type __result_type;
  return ::fma((__result_type)__x, (__result_type)__y, (__result_type)__z);
}
#else
template <typename __T1, typename __T2, typename __T3>
__DEVICE__
    typename __hip_enable_if<std::numeric_limits<__T1>::is_specialized &&
                                 std::numeric_limits<__T2>::is_specialized &&
                                 std::numeric_limits<__T3>::is_specialized,
                             double>::type
    fma(__T1 __x, __T2 __y, __T3 __z) {
  return ::fma((double)__x, (double)__y, (double)__z);
}
#endif

template <typename __T>
__DEVICE__
    typename __hip_enable_if<std::numeric_limits<__T>::is_integer, double>::type
    frexp(__T __x, int *__exp) {
  return ::frexp((double)__x, __exp);
}

template <typename __T>
__DEVICE__
    typename __hip_enable_if<std::numeric_limits<__T>::is_integer, double>::type
    ldexp(__T __x, int __exp) {
  return ::ldexp((double)__x, __exp);
}

template <typename __T>
__DEVICE__
    typename __hip_enable_if<std::numeric_limits<__T>::is_integer, double>::type
    modf(__T __x, double *__exp) {
  return ::modf((double)__x, __exp);
}

#if __cplusplus >= 201103L
template <typename __T1, typename __T2>
__DEVICE__
    typename __hip_enable_if<std::numeric_limits<__T1>::is_specialized &&
                                 std::numeric_limits<__T2>::is_specialized,
                             typename __hip::__promote<__T1, __T2>::type>::type
    remquo(__T1 __x, __T2 __y, int *__quo) {
  typedef typename __hip::__promote<__T1, __T2>::type __result_type;
  return ::remquo((__result_type)__x, (__result_type)__y, __quo);
}
#else
template <typename __T1, typename __T2>
__DEVICE__
    typename __hip_enable_if<std::numeric_limits<__T1>::is_specialized &&
                                 std::numeric_limits<__T2>::is_specialized,
                             double>::type
    remquo(__T1 __x, __T2 __y, int *__quo) {
  return ::remquo((double)__x, (double)__y, __quo);
}
#endif

template <typename __T>
__DEVICE__
    typename __hip_enable_if<std::numeric_limits<__T>::is_integer, double>::type
    scalbln(__T __x, long int __exp) {
  return ::scalbln((double)__x, __exp);
}

template <typename __T>
__DEVICE__
    typename __hip_enable_if<std::numeric_limits<__T>::is_integer, double>::type
    scalbn(__T __x, int __exp) {
  return ::scalbn((double)__x, __exp);
}

#pragma pop_macro("__HIP_OVERLOAD1")
#pragma pop_macro("__HIP_OVERLOAD2")

// END HIP_OVERLOAD

// END DEF_FUN and HIP_OVERLOAD

#endif // defined(__cplusplus)

// Define these overloads inside the namespace our standard library uses.
#ifdef _LIBCPP_BEGIN_NAMESPACE_STD
_LIBCPP_BEGIN_NAMESPACE_STD
#else
namespace std {
#ifdef _GLIBCXX_BEGIN_NAMESPACE_VERSION
_GLIBCXX_BEGIN_NAMESPACE_VERSION
#endif
#endif

// Pull the new overloads we defined above into namespace std.
// using ::abs; - This may be considered for C++.
using ::acos;
using ::acosh;
using ::asin;
using ::asinh;
using ::atan;
using ::atan2;
using ::atanh;
using ::cbrt;
using ::ceil;
using ::copysign;
using ::cos;
using ::cosh;
using ::erf;
using ::erfc;
using ::exp;
using ::exp2;
using ::expm1;
using ::fabs;
using ::fdim;
using ::floor;
using ::fma;
using ::fmax;
using ::fmin;
using ::fmod;
using ::fpclassify;
using ::frexp;
using ::hypot;
using ::ilogb;
using ::isfinite;
using ::isgreater;
using ::isgreaterequal;
using ::isless;
using ::islessequal;
using ::islessgreater;
using ::isnormal;
using ::isunordered;
using ::ldexp;
using ::lgamma;
using ::llrint;
using ::llround;
using ::log;
using ::log10;
using ::log1p;
using ::log2;
using ::logb;
using ::lrint;
using ::lround;
using ::modf;
// using ::nan; - This may be considered for C++.
// using ::nanf; - This may be considered for C++.
// using ::nanl; - This is not yet defined.
using ::nearbyint;
using ::nextafter;
// using ::nexttoward; - Omit this since we do not have a definition.
using ::pow;
using ::remainder;
using ::remquo;
using ::rint;
using ::round;
using ::scalbln;
using ::scalbn;
using ::signbit;
using ::sin;
using ::sinh;
using ::sqrt;
using ::tan;
using ::tanh;
using ::tgamma;
using ::trunc;

// Well this is fun: We need to pull these symbols in for libc++, but we can't
// pull them in with libstdc++, because its ::isinf and ::isnan are different
// than its std::isinf and std::isnan.
#ifndef __GLIBCXX__
using ::isinf;
using ::isnan;
#endif

// Finally, pull the "foobarf" functions that HIP defines into std.
using ::acosf;
using ::acoshf;
using ::asinf;
using ::asinhf;
using ::atan2f;
using ::atanf;
using ::atanhf;
using ::cbrtf;
using ::ceilf;
using ::copysignf;
using ::cosf;
using ::coshf;
using ::erfcf;
using ::erff;
using ::exp2f;
using ::expf;
using ::expm1f;
using ::fabsf;
using ::fdimf;
using ::floorf;
using ::fmaf;
using ::fmaxf;
using ::fminf;
using ::fmodf;
using ::frexpf;
using ::hypotf;
using ::ilogbf;
using ::ldexpf;
using ::lgammaf;
using ::llrintf;
using ::llroundf;
using ::log10f;
using ::log1pf;
using ::log2f;
using ::logbf;
using ::logf;
using ::lrintf;
using ::lroundf;
using ::modff;
using ::nearbyintf;
using ::nextafterf;
// using ::nexttowardf; - Omit this since we do not have a definition.
using ::powf;
using ::remainderf;
using ::remquof;
using ::rintf;
using ::roundf;
using ::scalblnf;
using ::scalbnf;
using ::sinf;
using ::sinhf;
using ::sqrtf;
using ::tanf;
using ::tanhf;
using ::tgammaf;
using ::truncf;

#ifdef _LIBCPP_END_NAMESPACE_STD
_LIBCPP_END_NAMESPACE_STD
#else
#ifdef _GLIBCXX_BEGIN_NAMESPACE_VERSION
_GLIBCXX_END_NAMESPACE_VERSION
#endif
} // namespace std
#endif

#pragma pop_macro("__DEVICE__")

#endif // __CLANG_HIP_CMATH_H__
