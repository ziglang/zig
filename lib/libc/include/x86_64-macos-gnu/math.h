/*
 * Copyright (c) 2002-2017 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * The contents of this file constitute Original Code as defined in and
 * are subject to the Apple Public Source License Version 1.1 (the
 * "License").  You may not use this file except in compliance with the
 * License.  Please obtain a copy of the License at
 * http://www.apple.com/publicsource and read it before using this file.
 * 
 * This Original Code and all software distributed under the License are
 * distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE OR NON-INFRINGEMENT.  Please see the
 * License for the specific language governing rights and limitations
 * under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#ifndef __MATH_H__
#define __MATH_H__

#ifndef __MATH__
#define __MATH__
#endif

#include <sys/cdefs.h>
#include <Availability.h>

__BEGIN_DECLS

/******************************************************************************
 * Floating point data types                                                  *
 ******************************************************************************/

/*  Define float_t and double_t per C standard, ISO/IEC 9899:2011 7.12 2,
    taking advantage of GCC's __FLT_EVAL_METHOD__ (which a compiler may
    define anytime and GCC does) that shadows FLT_EVAL_METHOD (which a
    compiler must define only in float.h).                                    */
#if __FLT_EVAL_METHOD__ == 0
    typedef float float_t;
    typedef double double_t;
#elif __FLT_EVAL_METHOD__ == 1
    typedef double float_t;
    typedef double double_t;
#elif __FLT_EVAL_METHOD__ == 2 || __FLT_EVAL_METHOD__ == -1
    typedef long double float_t;
    typedef long double double_t;
#else /* __FLT_EVAL_METHOD__ */
#   error "Unsupported value of __FLT_EVAL_METHOD__."
#endif /* __FLT_EVAL_METHOD__ */

#if defined(__GNUC__)
#   define    HUGE_VAL     __builtin_huge_val()
#   define    HUGE_VALF    __builtin_huge_valf()
#   define    HUGE_VALL    __builtin_huge_vall()
#   define    NAN          __builtin_nanf("0x7fc00000")
#else
#   define    HUGE_VAL     1e500
#   define    HUGE_VALF    1e50f
#   define    HUGE_VALL    1e5000L
#   define    NAN          __nan()
#endif

#define INFINITY    HUGE_VALF

/******************************************************************************
 *      Taxonomy of floating point data types                                 *
 ******************************************************************************/

#define FP_NAN          1
#define FP_INFINITE     2
#define FP_ZERO         3
#define FP_NORMAL       4
#define FP_SUBNORMAL    5
#define FP_SUPERNORMAL  6 /* legacy PowerPC support; this is otherwise unused */

#if defined __arm64__ || defined __ARM_VFPV4__
/*  On these architectures, fma(), fmaf( ), and fmal( ) are generally about as
    fast as (or faster than) separate multiply and add of the same operands.  */
#   define FP_FAST_FMA     1
#   define FP_FAST_FMAF    1
#   define FP_FAST_FMAL    1
#elif (defined __i386__ || defined __x86_64__) && (defined __FMA__ || defined __AVX512F__)
/*  When targeting the FMA ISA extension, fma() and fmaf( ) are generally
    about as fast as (or faster than) separate multiply and add of the same
    operands, but fmal( ) may be more costly.                                 */
#   define FP_FAST_FMA     1
#   define FP_FAST_FMAF    1
#   undef  FP_FAST_FMAL
#else
/*  On these architectures, fma( ), fmaf( ), and fmal( ) function calls are
    significantly more costly than separate multiply and add operations.      */
#   undef  FP_FAST_FMA
#   undef  FP_FAST_FMAF
#   undef  FP_FAST_FMAL
#endif

/* The values returned by `ilogb' for 0 and NaN respectively. */
#define FP_ILOGB0      (-2147483647 - 1)
#define FP_ILOGBNAN    (-2147483647 - 1)

/* Bitmasks for the math_errhandling macro.  */
#define MATH_ERRNO        1    /* errno set by math functions.  */
#define MATH_ERREXCEPT    2    /* Exceptions raised by math functions.  */

#define math_errhandling (__math_errhandling())
extern int __math_errhandling(void);

/******************************************************************************
 *                                                                            *
 *                              Inquiry macros                                *
 *                                                                            *
 *  fpclassify      Returns one of the FP_* values.                           *
 *  isnormal        Non-zero if and only if the argument x is normalized.     *
 *  isfinite        Non-zero if and only if the argument x is finite.         *
 *  isnan           Non-zero if and only if the argument x is a NaN.          *
 *  signbit         Non-zero if and only if the sign of the argument x is     *
 *                  negative.  This includes, NaNs, infinities and zeros.     *
 *                                                                            *
 ******************************************************************************/

#define fpclassify(x)                                                    \
    ( sizeof(x) == sizeof(float)  ? __fpclassifyf((float)(x))            \
    : sizeof(x) == sizeof(double) ? __fpclassifyd((double)(x))           \
                                  : __fpclassifyl((long double)(x)))

extern int __fpclassifyf(float);
extern int __fpclassifyd(double);
extern int __fpclassifyl(long double);

#if (defined(__GNUC__) && 0 == __FINITE_MATH_ONLY__)
/*  These inline functions may fail to return expected results if unsafe
    math optimizations like those enabled by -ffast-math are turned on.
    Thus, (somewhat surprisingly) you only get the fast inline
    implementations if such compiler options are NOT enabled.  This is
    because the inline functions require the compiler to be adhering to
    the standard in order to work properly; -ffast-math, among other
    things, implies that NaNs don't happen, which allows the compiler to
    optimize away checks like x != x, which might lead to things like
    isnan(NaN) returning false.                                               
 
    Thus, if you compile with -ffast-math, actual function calls are
    generated for these utilities.                                            */
    
#define isnormal(x)                                                      \
    ( sizeof(x) == sizeof(float)  ? __inline_isnormalf((float)(x))       \
    : sizeof(x) == sizeof(double) ? __inline_isnormald((double)(x))      \
                                  : __inline_isnormall((long double)(x)))

#define isfinite(x)                                                      \
    ( sizeof(x) == sizeof(float)  ? __inline_isfinitef((float)(x))       \
    : sizeof(x) == sizeof(double) ? __inline_isfinited((double)(x))      \
                                  : __inline_isfinitel((long double)(x)))

#define isinf(x)                                                         \
    ( sizeof(x) == sizeof(float)  ? __inline_isinff((float)(x))          \
    : sizeof(x) == sizeof(double) ? __inline_isinfd((double)(x))         \
                                  : __inline_isinfl((long double)(x)))

#define isnan(x)                                                         \
    ( sizeof(x) == sizeof(float)  ? __inline_isnanf((float)(x))          \
    : sizeof(x) == sizeof(double) ? __inline_isnand((double)(x))         \
                                  : __inline_isnanl((long double)(x)))

#define signbit(x)                                                       \
    ( sizeof(x) == sizeof(float)  ? __inline_signbitf((float)(x))        \
    : sizeof(x) == sizeof(double) ? __inline_signbitd((double)(x))       \
                                  : __inline_signbitl((long double)(x)))

__header_always_inline int __inline_isfinitef(float);
__header_always_inline int __inline_isfinited(double);
__header_always_inline int __inline_isfinitel(long double);
__header_always_inline int __inline_isinff(float);
__header_always_inline int __inline_isinfd(double);
__header_always_inline int __inline_isinfl(long double);
__header_always_inline int __inline_isnanf(float);
__header_always_inline int __inline_isnand(double);
__header_always_inline int __inline_isnanl(long double);
__header_always_inline int __inline_isnormalf(float);
__header_always_inline int __inline_isnormald(double);
__header_always_inline int __inline_isnormall(long double);
__header_always_inline int __inline_signbitf(float);
__header_always_inline int __inline_signbitd(double);
__header_always_inline int __inline_signbitl(long double);
    
__header_always_inline int __inline_isfinitef(float __x) {
    return __x == __x && __builtin_fabsf(__x) != __builtin_inff();
}
__header_always_inline int __inline_isfinited(double __x) {
    return __x == __x && __builtin_fabs(__x) != __builtin_inf();
}
__header_always_inline int __inline_isfinitel(long double __x) {
    return __x == __x && __builtin_fabsl(__x) != __builtin_infl();
}
__header_always_inline int __inline_isinff(float __x) {
    return __builtin_fabsf(__x) == __builtin_inff();
}
__header_always_inline int __inline_isinfd(double __x) {
    return __builtin_fabs(__x) == __builtin_inf();
}
__header_always_inline int __inline_isinfl(long double __x) {
    return __builtin_fabsl(__x) == __builtin_infl();
}
__header_always_inline int __inline_isnanf(float __x) {
    return __x != __x;
}
__header_always_inline int __inline_isnand(double __x) {
    return __x != __x;
}
__header_always_inline int __inline_isnanl(long double __x) {
    return __x != __x;
}
__header_always_inline int __inline_signbitf(float __x) {
    union { float __f; unsigned int __u; } __u;
    __u.__f = __x;
    return (int)(__u.__u >> 31);
}
__header_always_inline int __inline_signbitd(double __x) {
    union { double __f; unsigned long long __u; } __u;
    __u.__f = __x;
    return (int)(__u.__u >> 63);
}
#if defined __i386__ || defined __x86_64__
__header_always_inline int __inline_signbitl(long double __x) {
    union {
        long double __ld;
        struct{ unsigned long long __m; unsigned short __sexp; } __p;
    } __u;
    __u.__ld = __x;
    return (int)(__u.__p.__sexp >> 15);
}
#else
__header_always_inline int __inline_signbitl(long double __x) {
    union { long double __f; unsigned long long __u;} __u;
    __u.__f = __x;
    return (int)(__u.__u >> 63);
}
#endif
__header_always_inline int __inline_isnormalf(float __x) {
    return __inline_isfinitef(__x) && __builtin_fabsf(__x) >= __FLT_MIN__;
}
__header_always_inline int __inline_isnormald(double __x) {
    return __inline_isfinited(__x) && __builtin_fabs(__x) >= __DBL_MIN__;
}
__header_always_inline int __inline_isnormall(long double __x) {
    return __inline_isfinitel(__x) && __builtin_fabsl(__x) >= __LDBL_MIN__;
}
    
#else /* defined(__GNUC__) && 0 == __FINITE_MATH_ONLY__ */

/*  Implementations making function calls to fall back on when -ffast-math
    or similar is specified.  These are not available in iOS versions prior
    to 6.0.  If you need them, you must target that version or later.         */
    
#define isnormal(x)                                               \
    ( sizeof(x) == sizeof(float)  ? __isnormalf((float)(x))       \
    : sizeof(x) == sizeof(double) ? __isnormald((double)(x))      \
                                  : __isnormall((long double)(x)))
    
#define isfinite(x)                                               \
    ( sizeof(x) == sizeof(float)  ? __isfinitef((float)(x))       \
    : sizeof(x) == sizeof(double) ? __isfinited((double)(x))      \
                                  : __isfinitel((long double)(x)))
    
#define isinf(x)                                                  \
    ( sizeof(x) == sizeof(float)  ? __isinff((float)(x))          \
    : sizeof(x) == sizeof(double) ? __isinfd((double)(x))         \
                                  : __isinfl((long double)(x)))
    
#define isnan(x)                                                  \
    ( sizeof(x) == sizeof(float)  ? __isnanf((float)(x))          \
    : sizeof(x) == sizeof(double) ? __isnand((double)(x))         \
                                  : __isnanl((long double)(x)))
    
#define signbit(x)                                                \
    ( sizeof(x) == sizeof(float)  ? __signbitf((float)(x))        \
    : sizeof(x) == sizeof(double) ? __signbitd((double)(x))       \
                                  : __signbitl((long double)(x)))
    
extern int __isnormalf(float);
extern int __isnormald(double);
extern int __isnormall(long double);
extern int __isfinitef(float);
extern int __isfinited(double);
extern int __isfinitel(long double);
extern int __isinff(float);
extern int __isinfd(double);
extern int __isinfl(long double);
extern int __isnanf(float);
extern int __isnand(double);
extern int __isnanl(long double);
extern int __signbitf(float);
extern int __signbitd(double);
extern int __signbitl(long double);

#endif /* defined(__GNUC__) && 0 == __FINITE_MATH_ONLY__ */

/******************************************************************************
 *                                                                            *
 *                              Math Functions                                *
 *                                                                            *
 ******************************************************************************/
    
extern float acosf(float);
extern double acos(double);
extern long double acosl(long double);
    
extern float asinf(float);
extern double asin(double);
extern long double asinl(long double);
    
extern float atanf(float);
extern double atan(double);
extern long double atanl(long double);
    
extern float atan2f(float, float);
extern double atan2(double, double);
extern long double atan2l(long double, long double);
    
extern float cosf(float);
extern double cos(double);
extern long double cosl(long double);
    
extern float sinf(float);
extern double sin(double);
extern long double sinl(long double);
    
extern float tanf(float);
extern double tan(double);
extern long double tanl(long double);
    
extern float acoshf(float);
extern double acosh(double);
extern long double acoshl(long double);
    
extern float asinhf(float);
extern double asinh(double);
extern long double asinhl(long double);
    
extern float atanhf(float);
extern double atanh(double);
extern long double atanhl(long double);
    
extern float coshf(float);
extern double cosh(double);
extern long double coshl(long double);
    
extern float sinhf(float);
extern double sinh(double);
extern long double sinhl(long double);
    
extern float tanhf(float);
extern double tanh(double);
extern long double tanhl(long double);
    
extern float expf(float);
extern double exp(double);
extern long double expl(long double);

extern float exp2f(float);
extern double exp2(double); 
extern long double exp2l(long double); 

extern float expm1f(float);
extern double expm1(double); 
extern long double expm1l(long double); 

extern float logf(float);
extern double log(double);
extern long double logl(long double);

extern float log10f(float);
extern double log10(double);
extern long double log10l(long double);

extern float log2f(float);
extern double log2(double);
extern long double log2l(long double);

extern float log1pf(float);
extern double log1p(double);
extern long double log1pl(long double);

extern float logbf(float);
extern double logb(double);
extern long double logbl(long double);

extern float modff(float, float *);
extern double modf(double, double *);
extern long double modfl(long double, long double *);

extern float ldexpf(float, int);
extern double ldexp(double, int);
extern long double ldexpl(long double, int);

extern float frexpf(float, int *);
extern double frexp(double, int *);
extern long double frexpl(long double, int *);

extern int ilogbf(float);
extern int ilogb(double);
extern int ilogbl(long double);

extern float scalbnf(float, int);
extern double scalbn(double, int);
extern long double scalbnl(long double, int);

extern float scalblnf(float, long int);
extern double scalbln(double, long int);
extern long double scalblnl(long double, long int);

extern float fabsf(float);
extern double fabs(double);
extern long double fabsl(long double);

extern float cbrtf(float);
extern double cbrt(double);
extern long double cbrtl(long double);

extern float hypotf(float, float);
extern double hypot(double, double);
extern long double hypotl(long double, long double);

extern float powf(float, float);
extern double pow(double, double);
extern long double powl(long double, long double);

extern float sqrtf(float);
extern double sqrt(double);
extern long double sqrtl(long double);

extern float erff(float);
extern double erf(double);
extern long double erfl(long double);

extern float erfcf(float);
extern double erfc(double);
extern long double erfcl(long double);

/*	lgammaf, lgamma, and lgammal are not thread-safe. The thread-safe
    variants lgammaf_r, lgamma_r, and lgammal_r are made available if
    you define the _REENTRANT symbol before including <math.h>                */
extern float lgammaf(float);
extern double lgamma(double);
extern long double lgammal(long double);

extern float tgammaf(float);
extern double tgamma(double);
extern long double tgammal(long double);

extern float ceilf(float);
extern double ceil(double);
extern long double ceill(long double);

extern float floorf(float);
extern double floor(double);
extern long double floorl(long double);

extern float nearbyintf(float);
extern double nearbyint(double);
extern long double nearbyintl(long double);

extern float rintf(float);
extern double rint(double);
extern long double rintl(long double);

extern long int lrintf(float);
extern long int lrint(double);
extern long int lrintl(long double);

extern float roundf(float);
extern double round(double);
extern long double roundl(long double);

extern long int lroundf(float);
extern long int lround(double);
extern long int lroundl(long double);
    
/*  long long is not part of C90. Make sure you are passing -std=c99 or
    -std=gnu99 or higher if you need these functions returning long longs     */
#if !(__DARWIN_NO_LONG_LONG)
extern long long int llrintf(float);
extern long long int llrint(double);
extern long long int llrintl(long double);

extern long long int llroundf(float);
extern long long int llround(double);
extern long long int llroundl(long double);
#endif /* !(__DARWIN_NO_LONG_LONG) */

extern float truncf(float);
extern double trunc(double);
extern long double truncl(long double);

extern float fmodf(float, float);
extern double fmod(double, double);
extern long double fmodl(long double, long double);

extern float remainderf(float, float);
extern double remainder(double, double);
extern long double remainderl(long double, long double);

extern float remquof(float, float, int *);
extern double remquo(double, double, int *);
extern long double remquol(long double, long double, int *);

extern float copysignf(float, float);
extern double copysign(double, double);
extern long double copysignl(long double, long double);

extern float nanf(const char *);
extern double nan(const char *);
extern long double nanl(const char *);

extern float nextafterf(float, float);
extern double nextafter(double, double);
extern long double nextafterl(long double, long double);

extern double nexttoward(double, long double);
extern float nexttowardf(float, long double);
extern long double nexttowardl(long double, long double);

extern float fdimf(float, float);
extern double fdim(double, double);
extern long double fdiml(long double, long double);

extern float fmaxf(float, float);
extern double fmax(double, double);
extern long double fmaxl(long double, long double);

extern float fminf(float, float);
extern double fmin(double, double);
extern long double fminl(long double, long double);

extern float fmaf(float, float, float);
extern double fma(double, double, double);
extern long double fmal(long double, long double, long double);

#define isgreater(x, y) __builtin_isgreater((x),(y))
#define isgreaterequal(x, y) __builtin_isgreaterequal((x),(y))
#define isless(x, y) __builtin_isless((x),(y))
#define islessequal(x, y) __builtin_islessequal((x),(y))
#define islessgreater(x, y) __builtin_islessgreater((x),(y))
#define isunordered(x, y) __builtin_isunordered((x),(y))

/* Deprecated functions; use the INFINITY and NAN macros instead.             */
extern float __inff(void)
__API_DEPRECATED("use `(float)INFINITY` instead", macos(10.0, 10.9)) __API_UNAVAILABLE(ios, watchos, tvos);
extern double __inf(void)
__API_DEPRECATED("use `INFINITY` instead", macos(10.0, 10.9)) __API_UNAVAILABLE(ios, watchos, tvos);
extern long double __infl(void)
__API_DEPRECATED("use `(long double)INFINITY` instead", macos(10.0, 10.9)) __API_UNAVAILABLE(ios, watchos, tvos);
extern float __nan(void)
__API_DEPRECATED("use `NAN` instead", macos(10.0, 10.14)) __API_UNAVAILABLE(ios, watchos, tvos);

/******************************************************************************
 *  Reentrant variants of lgamma[fl]                                          *
 ******************************************************************************/

#ifdef _REENTRANT
/*  Reentrant variants of the lgamma[fl] functions.                           */
extern float lgammaf_r(float, int *) __API_AVAILABLE(macos(10.6), ios(3.1));
extern double lgamma_r(double, int *) __API_AVAILABLE(macos(10.6), ios(3.1));
extern long double lgammal_r(long double, int *) __API_AVAILABLE(macos(10.6), ios(3.1));
#endif /* _REENTRANT */

/******************************************************************************
 *  Apple extensions to the C standard                                        *
 ******************************************************************************/

/*  Because these functions are not specified by any relevant standard, they
    are prefixed with __, which places them in the implementor's namespace, so
    they should not conflict with any developer or third-party code.  If they
    are added to a relevant standard in the future, un-prefixed names may be
    added to the library and they may be moved out of this section of the
    header.                                                                   
 
    Because these functions are non-standard, they may not be available on non-
    Apple platforms.                                                          */

/*  __exp10(x) returns 10**x.  Edge cases match those of exp( ) and exp2( ).  */
extern float __exp10f(float) __API_AVAILABLE(macos(10.9), ios(7.0));
extern double __exp10(double) __API_AVAILABLE(macos(10.9), ios(7.0));

/*  __sincos(x,sinp,cosp) computes the sine and cosine of x with a single
    function call, storing the sine in the memory pointed to by sinp, and
    the cosine in the memory pointed to by cosp. Edge cases match those of
    separate calls to sin( ) and cos( ).                                      */
__header_always_inline void __sincosf(float __x, float *__sinp, float *__cosp);
__header_always_inline void __sincos(double __x, double *__sinp, double *__cosp);

/*  __sinpi(x) returns the sine of pi times x; __cospi(x) and __tanpi(x) return
    the cosine and tangent, respectively.  These functions can produce a more
    accurate answer than expressions of the form sin(M_PI * x) because they
    avoid any loss of precision that results from rounding the result of the
    multiplication M_PI * x.  They may also be significantly more efficient in
    some cases because the argument reduction for these functions is easier
    to compute.  Consult the man pages for edge case details.                 */
extern float __cospif(float) __API_AVAILABLE(macos(10.9), ios(7.0));
extern double __cospi(double) __API_AVAILABLE(macos(10.9), ios(7.0));
extern float __sinpif(float) __API_AVAILABLE(macos(10.9), ios(7.0));
extern double __sinpi(double) __API_AVAILABLE(macos(10.9), ios(7.0));
extern float __tanpif(float) __API_AVAILABLE(macos(10.9), ios(7.0));
extern double __tanpi(double) __API_AVAILABLE(macos(10.9), ios(7.0));

#if (defined __MAC_OS_X_VERSION_MIN_REQUIRED && __MAC_OS_X_VERSION_MIN_REQUIRED < 1090) || \
    (defined __IPHONE_OS_VERSION_MIN_REQUIRED && __IPHONE_OS_VERSION_MIN_REQUIRED < 70000)
/*  __sincos and __sincosf were introduced in OSX 10.9 and iOS 7.0.  When
    targeting an older system, we simply split them up into discrete calls
    to sin( ) and cos( ).                                                     */
__header_always_inline void __sincosf(float __x, float *__sinp, float *__cosp) {
  *__sinp = sinf(__x);
  *__cosp = cosf(__x);
}

__header_always_inline void __sincos(double __x, double *__sinp, double *__cosp) {
  *__sinp = sin(__x);
  *__cosp = cos(__x);
}
#else
/*  __sincospi(x,sinp,cosp) computes the sine and cosine of pi times x with a
    single function call, storing the sine in the memory pointed to by sinp,
    and the cosine in the memory pointed to by cosp.  Edge cases match those
    of separate calls to __sinpi( ) and __cospi( ), and are documented in the
    man pages.
 
    These functions were introduced in OSX 10.9 and iOS 7.0.  Because they are
    implemented as header inlines, weak-linking does not function as normal,
    and they are simply hidden when targeting earlier OS versions.            */
__header_always_inline void __sincospif(float __x, float *__sinp, float *__cosp);
__header_always_inline void __sincospi(double __x, double *__sinp, double *__cosp);

/*  Implementation details of __sincos and __sincospi allowing them to return
    two results while allowing the compiler to optimize away unnecessary load-
    store traffic.  Although these interfaces are exposed in the math.h header
    to allow compilers to generate better code, users should call __sincos[f]
    and __sincospi[f] instead and allow the compiler to emit these calls.     */
struct __float2 { float __sinval; float __cosval; };
struct __double2 { double __sinval; double __cosval; };

extern struct __float2 __sincosf_stret(float);
extern struct __double2 __sincos_stret(double);
extern struct __float2 __sincospif_stret(float);
extern struct __double2 __sincospi_stret(double);

__header_always_inline void __sincosf(float __x, float *__sinp, float *__cosp) {
    const struct __float2 __stret = __sincosf_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}

__header_always_inline void __sincos(double __x, double *__sinp, double *__cosp) {
    const struct __double2 __stret = __sincos_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}

__header_always_inline void __sincospif(float __x, float *__sinp, float *__cosp) {
    const struct __float2 __stret = __sincospif_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}

__header_always_inline void __sincospi(double __x, double *__sinp, double *__cosp) {
    const struct __double2 __stret = __sincospi_stret(__x);
    *__sinp = __stret.__sinval; *__cosp = __stret.__cosval;
}
#endif

/******************************************************************************
 *  POSIX/UNIX extensions to the C standard                                   *
 ******************************************************************************/

#if __DARWIN_C_LEVEL >= 199506L
extern double j0(double) __API_AVAILABLE(macos(10.0), ios(3.2));
extern double j1(double) __API_AVAILABLE(macos(10.0), ios(3.2));
extern double jn(int, double) __API_AVAILABLE(macos(10.0), ios(3.2));
extern double y0(double) __API_AVAILABLE(macos(10.0), ios(3.2));
extern double y1(double) __API_AVAILABLE(macos(10.0), ios(3.2));
extern double yn(int, double) __API_AVAILABLE(macos(10.0), ios(3.2));
extern double scalb(double, double); 
extern int signgam;

/*  Even though these might be more useful as long doubles, POSIX requires
    that they be double-precision literals.                                   */
#define M_E         2.71828182845904523536028747135266250   /* e              */
#define M_LOG2E     1.44269504088896340735992468100189214   /* log2(e)        */
#define M_LOG10E    0.434294481903251827651128918916605082  /* log10(e)       */
#define M_LN2       0.693147180559945309417232121458176568  /* loge(2)        */
#define M_LN10      2.30258509299404568401799145468436421   /* loge(10)       */
#define M_PI        3.14159265358979323846264338327950288   /* pi             */
#define M_PI_2      1.57079632679489661923132169163975144   /* pi/2           */
#define M_PI_4      0.785398163397448309615660845819875721  /* pi/4           */
#define M_1_PI      0.318309886183790671537767526745028724  /* 1/pi           */
#define M_2_PI      0.636619772367581343075535053490057448  /* 2/pi           */
#define M_2_SQRTPI  1.12837916709551257389615890312154517   /* 2/sqrt(pi)     */
#define M_SQRT2     1.41421356237309504880168872420969808   /* sqrt(2)        */
#define M_SQRT1_2   0.707106781186547524400844362104849039  /* 1/sqrt(2)      */

#define MAXFLOAT    0x1.fffffep+127f
#endif /* __DARWIN_C_LEVEL >= 199506L */

/*  Long-double versions of M_E, etc for convenience on Intel where long-
    double is not the same as double.  Define __MATH_LONG_DOUBLE_CONSTANTS
    to make these constants available.                                        */
#if defined __MATH_LONG_DOUBLE_CONSTANTS
#define M_El        0xa.df85458a2bb4a9bp-2L
#define M_LOG2El    0xb.8aa3b295c17f0bcp-3L
#define M_LOG10El   0xd.e5bd8a937287195p-5L
#define M_LN2l      0xb.17217f7d1cf79acp-4L
#define M_LN10l     0x9.35d8dddaaa8ac17p-2L
#define M_PIl       0xc.90fdaa22168c235p-2L
#define M_PI_2l     0xc.90fdaa22168c235p-3L
#define M_PI_4l     0xc.90fdaa22168c235p-4L
#define M_1_PIl     0xa.2f9836e4e44152ap-5L
#define M_2_PIl     0xa.2f9836e4e44152ap-4L
#define M_2_SQRTPIl 0x9.06eba8214db688dp-3L
#define M_SQRT2l    0xb.504f333f9de6484p-3L
#define M_SQRT1_2l  0xb.504f333f9de6484p-4L
#endif /* defined __MATH_LONG_DOUBLE_CONSTANTS */

/******************************************************************************
 *  Legacy BSD extensions to the C standard                                   *
 ******************************************************************************/

#if __DARWIN_C_LEVEL >= __DARWIN_C_FULL
#define FP_SNAN		FP_NAN
#define FP_QNAN		FP_NAN
#define	HUGE		MAXFLOAT
#define X_TLOSS		1.41484755040568800000e+16 
#define	DOMAIN		1
#define	SING		2
#define	OVERFLOW	3
#define	UNDERFLOW	4
#define	TLOSS		5
#define	PLOSS		6

/* Legacy BSD API; use the C99 `lrint( )` function instead.                   */
extern long int rinttol(double)
__API_DEPRECATED_WITH_REPLACEMENT("lrint", macos(10.0, 10.9)) __API_UNAVAILABLE(ios, watchos, tvos);
/* Legacy BSD API; use the C99 `lround( )` function instead.                  */
extern long int roundtol(double)
__API_DEPRECATED_WITH_REPLACEMENT("lround", macos(10.0, 10.9)) __API_UNAVAILABLE(ios, watchos, tvos);
/* Legacy BSD API; use the C99 `remainder( )` function instead.               */
extern double drem(double, double)
__API_DEPRECATED_WITH_REPLACEMENT("remainder", macos(10.0, 10.9)) __API_UNAVAILABLE(ios, watchos, tvos);
/* Legacy BSD API; use the C99 `isfinite( )` macro instead.                   */
extern int finite(double)
__API_DEPRECATED("Use `isfinite((double)x)` instead.", macos(10.0, 10.9)) __API_UNAVAILABLE(ios, watchos, tvos);
/* Legacy BSD API; use the C99 `tgamma( )` function instead.                  */
extern double gamma(double)
__API_DEPRECATED_WITH_REPLACEMENT("tgamma", macos(10.0, 10.9)) __API_UNAVAILABLE(ios, watchos, tvos);
/* Legacy BSD API; use `2*frexp( )` or `scalbn(x, -ilogb(x))` instead.        */
extern double significand(double)
__API_DEPRECATED("Use `2*frexp( )` or `scalbn(x, -ilogb(x))` instead.", macos(10.0, 10.9)) __API_UNAVAILABLE(ios, watchos, tvos);

#if !defined __cplusplus
struct exception {
    int type;
    char *name;
    double arg1;
    double arg2;
    double retval;
};

#endif /* !defined __cplusplus */
#endif /* __DARWIN_C_LEVEL >= __DARWIN_C_FULL */

__END_DECLS
#endif /* __MATH_H__ */
