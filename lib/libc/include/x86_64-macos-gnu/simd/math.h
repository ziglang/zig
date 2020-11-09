/*! @header
 *  The interfaces declared in this header provide elementwise math operations
 *  on vectors; each lane of the result vector depends only on the data in the
 *  corresponding lane of the argument(s) to the function.
 *
 *  You should not use the C functions declared in this header directly (these
 *  are functions with names like `__tg_cos(x)`). These are merely
 *  implementation details of <tgmath.h> overloading; instead of calling
 *  `__tg_cos(x)`, call `cos(x)`. If you are writing C++, use `simd::cos(x)`.
 *
 *  Note that while these vector functions are relatively recent additions,
 *  scalar fallback is provided for all of them, so they are available even
 *  when targeting older OS versions.
 *
 *  The following functions are available:
 *
 *    C name        C++ name          Notes
 *    ----------------------------------------------------------------------
 *    acos(x)       simd::acos(x)     
 *    asin(x)       simd::asin(x)
 *    atan(x)       simd::atan(x)
 *    atan2(y,x)    simd::atan2(y,x)  The argument order matches the scalar
 *                                    atan2 function, which gives the angle
 *                                    of a line with slope y/x.
 *    cos(x)        simd::cos(x)
 *    sin(x)        simd::sin(x)
 *    tan(x)        simd::tan(x)
 *    
 *    cospi(x)      simd::cospi(x)    Returns cos(pi*x), sin(pi*x), tan(pi*x)
 *    sinpi(x)      simd::sinpi(x)    more efficiently and accurately than
 *    tanpi(x)      simd::tanpi(x)    would otherwise be possible
 *
 *    acosh(x)      simd::acosh(x)
 *    asinh(x)      simd::asinh(x)
 *    atanh(x)      simd::atanh(x)
 *
 *    cosh(x)       simd::cosh(x)
 *    sinh(x)       simd::sinh(x)
 *    tanh(x)       simd::tanh(x)
 *
 *    exp(x)        simd::exp(x)
 *    exp2(x)       simd::exp2(x)
 *    exp10(x)      simd::exp10(x)    More efficient that pow(10,x).
 *    expm1(x)      simd::expm1(x)    exp(x)-1, accurate even for tiny x.
 *
 *    log(x)        simd::log(x)
 *    log2(x)       simd::log2(x)
 *    log10(x)      simd::log10(x)
 *    log1p(x)      simd::log1p(x)    log(1+x), accurate even for tiny x.
 *
 *    fabs(x)       simd::fabs(x)
 *    cbrt(x)       simd::cbrt(x)
 *    sqrt(x)       simd::sqrt(x)
 *    pow(x,y)      simd::pow(x,y)
 *    copysign(x,y) simd::copysign(x,y)
 *    hypot(x,y)    simd::hypot(x,y)  sqrt(x*x + y*y), computed without
 *                                    overflow.1
 *    erf(x)        simd::erf(x)
 *    erfc(x)       simd::erfc(x)
 *    tgamma(x)     simd::tgamma(x)
 *
 *    fmod(x,y)      simd::fmod(x,y)
 *    remainder(x,y) simd::remainder(x,y)
 *
 *    ceil(x)       simd::ceil(x)
 *    floor(x)      simd::floor(x)
 *    rint(x)       simd::rint(x)
 *    round(x)      simd::round(x)
 *    trunc(x)      simd::trunc(x)
 *
 *    fdim(x,y)     simd::fdim(x,y)
 *    fmax(x,y)     simd::fmax(x,y)   When one argument to fmin or fmax is
 *    fmin(x,y)     simd::fmin(x,y)   constant, use it as the *second* (y)
 *                                    argument to get better codegen on some
 *                                    architectures. E.g., write fmin(x,2)
 *                                    instead of fmin(2,x).
 *    fma(x,y,z)    simd::fma(x,y,z)  Fast on arm64 and when targeting AVX2
 *                                    and later; may be quite expensive on
 *                                    older hardware.
 *    simd_muladd(x,y,z) simd::muladd(x,y,z)
 *
 *  @copyright 2014-2017 Apple, Inc. All rights reserved.
 *  @unsorted                                                                 */

#ifndef SIMD_MATH_HEADER
#define SIMD_MATH_HEADER

#include <simd/base.h>
#if SIMD_COMPILER_HAS_REQUIRED_FEATURES
#include <simd/vector_make.h>
#include <simd/logic.h>

#ifdef __cplusplus
extern "C" {
#endif
/*! @abstract Do not call this function; instead use `acos` in C and
 *  Objective-C, and `simd::acos` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_acos(simd_float2 x);
/*! @abstract Do not call this function; instead use `acos` in C and
 *  Objective-C, and `simd::acos` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_acos(simd_float3 x);
/*! @abstract Do not call this function; instead use `acos` in C and
 *  Objective-C, and `simd::acos` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_acos(simd_float4 x);
/*! @abstract Do not call this function; instead use `acos` in C and
 *  Objective-C, and `simd::acos` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_acos(simd_float8 x);
/*! @abstract Do not call this function; instead use `acos` in C and
 *  Objective-C, and `simd::acos` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_acos(simd_float16 x);
/*! @abstract Do not call this function; instead use `acos` in C and
 *  Objective-C, and `simd::acos` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_acos(simd_double2 x);
/*! @abstract Do not call this function; instead use `acos` in C and
 *  Objective-C, and `simd::acos` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_acos(simd_double3 x);
/*! @abstract Do not call this function; instead use `acos` in C and
 *  Objective-C, and `simd::acos` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_acos(simd_double4 x);
/*! @abstract Do not call this function; instead use `acos` in C and
 *  Objective-C, and `simd::acos` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_acos(simd_double8 x);

/*! @abstract Do not call this function; instead use `asin` in C and
 *  Objective-C, and `simd::asin` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_asin(simd_float2 x);
/*! @abstract Do not call this function; instead use `asin` in C and
 *  Objective-C, and `simd::asin` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_asin(simd_float3 x);
/*! @abstract Do not call this function; instead use `asin` in C and
 *  Objective-C, and `simd::asin` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_asin(simd_float4 x);
/*! @abstract Do not call this function; instead use `asin` in C and
 *  Objective-C, and `simd::asin` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_asin(simd_float8 x);
/*! @abstract Do not call this function; instead use `asin` in C and
 *  Objective-C, and `simd::asin` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_asin(simd_float16 x);
/*! @abstract Do not call this function; instead use `asin` in C and
 *  Objective-C, and `simd::asin` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_asin(simd_double2 x);
/*! @abstract Do not call this function; instead use `asin` in C and
 *  Objective-C, and `simd::asin` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_asin(simd_double3 x);
/*! @abstract Do not call this function; instead use `asin` in C and
 *  Objective-C, and `simd::asin` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_asin(simd_double4 x);
/*! @abstract Do not call this function; instead use `asin` in C and
 *  Objective-C, and `simd::asin` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_asin(simd_double8 x);

/*! @abstract Do not call this function; instead use `atan` in C and
 *  Objective-C, and `simd::atan` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_atan(simd_float2 x);
/*! @abstract Do not call this function; instead use `atan` in C and
 *  Objective-C, and `simd::atan` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_atan(simd_float3 x);
/*! @abstract Do not call this function; instead use `atan` in C and
 *  Objective-C, and `simd::atan` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_atan(simd_float4 x);
/*! @abstract Do not call this function; instead use `atan` in C and
 *  Objective-C, and `simd::atan` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_atan(simd_float8 x);
/*! @abstract Do not call this function; instead use `atan` in C and
 *  Objective-C, and `simd::atan` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_atan(simd_float16 x);
/*! @abstract Do not call this function; instead use `atan` in C and
 *  Objective-C, and `simd::atan` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_atan(simd_double2 x);
/*! @abstract Do not call this function; instead use `atan` in C and
 *  Objective-C, and `simd::atan` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_atan(simd_double3 x);
/*! @abstract Do not call this function; instead use `atan` in C and
 *  Objective-C, and `simd::atan` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_atan(simd_double4 x);
/*! @abstract Do not call this function; instead use `atan` in C and
 *  Objective-C, and `simd::atan` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_atan(simd_double8 x);

/*! @abstract Do not call this function; instead use `cos` in C and
 *  Objective-C, and `simd::cos` in C++.                                      */
static inline SIMD_CFUNC simd_float2 __tg_cos(simd_float2 x);
/*! @abstract Do not call this function; instead use `cos` in C and
 *  Objective-C, and `simd::cos` in C++.                                      */
static inline SIMD_CFUNC simd_float3 __tg_cos(simd_float3 x);
/*! @abstract Do not call this function; instead use `cos` in C and
 *  Objective-C, and `simd::cos` in C++.                                      */
static inline SIMD_CFUNC simd_float4 __tg_cos(simd_float4 x);
/*! @abstract Do not call this function; instead use `cos` in C and
 *  Objective-C, and `simd::cos` in C++.                                      */
static inline SIMD_CFUNC simd_float8 __tg_cos(simd_float8 x);
/*! @abstract Do not call this function; instead use `cos` in C and
 *  Objective-C, and `simd::cos` in C++.                                      */
static inline SIMD_CFUNC simd_float16 __tg_cos(simd_float16 x);
/*! @abstract Do not call this function; instead use `cos` in C and
 *  Objective-C, and `simd::cos` in C++.                                      */
static inline SIMD_CFUNC simd_double2 __tg_cos(simd_double2 x);
/*! @abstract Do not call this function; instead use `cos` in C and
 *  Objective-C, and `simd::cos` in C++.                                      */
static inline SIMD_CFUNC simd_double3 __tg_cos(simd_double3 x);
/*! @abstract Do not call this function; instead use `cos` in C and
 *  Objective-C, and `simd::cos` in C++.                                      */
static inline SIMD_CFUNC simd_double4 __tg_cos(simd_double4 x);
/*! @abstract Do not call this function; instead use `cos` in C and
 *  Objective-C, and `simd::cos` in C++.                                      */
static inline SIMD_CFUNC simd_double8 __tg_cos(simd_double8 x);

/*! @abstract Do not call this function; instead use `sin` in C and
 *  Objective-C, and `simd::sin` in C++.                                      */
static inline SIMD_CFUNC simd_float2 __tg_sin(simd_float2 x);
/*! @abstract Do not call this function; instead use `sin` in C and
 *  Objective-C, and `simd::sin` in C++.                                      */
static inline SIMD_CFUNC simd_float3 __tg_sin(simd_float3 x);
/*! @abstract Do not call this function; instead use `sin` in C and
 *  Objective-C, and `simd::sin` in C++.                                      */
static inline SIMD_CFUNC simd_float4 __tg_sin(simd_float4 x);
/*! @abstract Do not call this function; instead use `sin` in C and
 *  Objective-C, and `simd::sin` in C++.                                      */
static inline SIMD_CFUNC simd_float8 __tg_sin(simd_float8 x);
/*! @abstract Do not call this function; instead use `sin` in C and
 *  Objective-C, and `simd::sin` in C++.                                      */
static inline SIMD_CFUNC simd_float16 __tg_sin(simd_float16 x);
/*! @abstract Do not call this function; instead use `sin` in C and
 *  Objective-C, and `simd::sin` in C++.                                      */
static inline SIMD_CFUNC simd_double2 __tg_sin(simd_double2 x);
/*! @abstract Do not call this function; instead use `sin` in C and
 *  Objective-C, and `simd::sin` in C++.                                      */
static inline SIMD_CFUNC simd_double3 __tg_sin(simd_double3 x);
/*! @abstract Do not call this function; instead use `sin` in C and
 *  Objective-C, and `simd::sin` in C++.                                      */
static inline SIMD_CFUNC simd_double4 __tg_sin(simd_double4 x);
/*! @abstract Do not call this function; instead use `sin` in C and
 *  Objective-C, and `simd::sin` in C++.                                      */
static inline SIMD_CFUNC simd_double8 __tg_sin(simd_double8 x);

/*! @abstract Do not call this function; instead use `tan` in C and
 *  Objective-C, and `simd::tan` in C++.                                      */
static inline SIMD_CFUNC simd_float2 __tg_tan(simd_float2 x);
/*! @abstract Do not call this function; instead use `tan` in C and
 *  Objective-C, and `simd::tan` in C++.                                      */
static inline SIMD_CFUNC simd_float3 __tg_tan(simd_float3 x);
/*! @abstract Do not call this function; instead use `tan` in C and
 *  Objective-C, and `simd::tan` in C++.                                      */
static inline SIMD_CFUNC simd_float4 __tg_tan(simd_float4 x);
/*! @abstract Do not call this function; instead use `tan` in C and
 *  Objective-C, and `simd::tan` in C++.                                      */
static inline SIMD_CFUNC simd_float8 __tg_tan(simd_float8 x);
/*! @abstract Do not call this function; instead use `tan` in C and
 *  Objective-C, and `simd::tan` in C++.                                      */
static inline SIMD_CFUNC simd_float16 __tg_tan(simd_float16 x);
/*! @abstract Do not call this function; instead use `tan` in C and
 *  Objective-C, and `simd::tan` in C++.                                      */
static inline SIMD_CFUNC simd_double2 __tg_tan(simd_double2 x);
/*! @abstract Do not call this function; instead use `tan` in C and
 *  Objective-C, and `simd::tan` in C++.                                      */
static inline SIMD_CFUNC simd_double3 __tg_tan(simd_double3 x);
/*! @abstract Do not call this function; instead use `tan` in C and
 *  Objective-C, and `simd::tan` in C++.                                      */
static inline SIMD_CFUNC simd_double4 __tg_tan(simd_double4 x);
/*! @abstract Do not call this function; instead use `tan` in C and
 *  Objective-C, and `simd::tan` in C++.                                      */
static inline SIMD_CFUNC simd_double8 __tg_tan(simd_double8 x);

#if SIMD_LIBRARY_VERSION >= 1
/*! @abstract Do not call this function; instead use `cospi` in C and
 *  Objective-C, and `simd::cospi` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_cospi(simd_float2 x);
/*! @abstract Do not call this function; instead use `cospi` in C and
 *  Objective-C, and `simd::cospi` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_cospi(simd_float3 x);
/*! @abstract Do not call this function; instead use `cospi` in C and
 *  Objective-C, and `simd::cospi` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_cospi(simd_float4 x);
/*! @abstract Do not call this function; instead use `cospi` in C and
 *  Objective-C, and `simd::cospi` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_cospi(simd_float8 x);
/*! @abstract Do not call this function; instead use `cospi` in C and
 *  Objective-C, and `simd::cospi` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_cospi(simd_float16 x);
/*! @abstract Do not call this function; instead use `cospi` in C and
 *  Objective-C, and `simd::cospi` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_cospi(simd_double2 x);
/*! @abstract Do not call this function; instead use `cospi` in C and
 *  Objective-C, and `simd::cospi` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_cospi(simd_double3 x);
/*! @abstract Do not call this function; instead use `cospi` in C and
 *  Objective-C, and `simd::cospi` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_cospi(simd_double4 x);
/*! @abstract Do not call this function; instead use `cospi` in C and
 *  Objective-C, and `simd::cospi` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_cospi(simd_double8 x);
#endif

#if SIMD_LIBRARY_VERSION >= 1
/*! @abstract Do not call this function; instead use `sinpi` in C and
 *  Objective-C, and `simd::sinpi` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_sinpi(simd_float2 x);
/*! @abstract Do not call this function; instead use `sinpi` in C and
 *  Objective-C, and `simd::sinpi` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_sinpi(simd_float3 x);
/*! @abstract Do not call this function; instead use `sinpi` in C and
 *  Objective-C, and `simd::sinpi` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_sinpi(simd_float4 x);
/*! @abstract Do not call this function; instead use `sinpi` in C and
 *  Objective-C, and `simd::sinpi` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_sinpi(simd_float8 x);
/*! @abstract Do not call this function; instead use `sinpi` in C and
 *  Objective-C, and `simd::sinpi` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_sinpi(simd_float16 x);
/*! @abstract Do not call this function; instead use `sinpi` in C and
 *  Objective-C, and `simd::sinpi` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_sinpi(simd_double2 x);
/*! @abstract Do not call this function; instead use `sinpi` in C and
 *  Objective-C, and `simd::sinpi` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_sinpi(simd_double3 x);
/*! @abstract Do not call this function; instead use `sinpi` in C and
 *  Objective-C, and `simd::sinpi` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_sinpi(simd_double4 x);
/*! @abstract Do not call this function; instead use `sinpi` in C and
 *  Objective-C, and `simd::sinpi` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_sinpi(simd_double8 x);
#endif

#if SIMD_LIBRARY_VERSION >= 1
/*! @abstract Do not call this function; instead use `tanpi` in C and
 *  Objective-C, and `simd::tanpi` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_tanpi(simd_float2 x);
/*! @abstract Do not call this function; instead use `tanpi` in C and
 *  Objective-C, and `simd::tanpi` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_tanpi(simd_float3 x);
/*! @abstract Do not call this function; instead use `tanpi` in C and
 *  Objective-C, and `simd::tanpi` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_tanpi(simd_float4 x);
/*! @abstract Do not call this function; instead use `tanpi` in C and
 *  Objective-C, and `simd::tanpi` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_tanpi(simd_float8 x);
/*! @abstract Do not call this function; instead use `tanpi` in C and
 *  Objective-C, and `simd::tanpi` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_tanpi(simd_float16 x);
/*! @abstract Do not call this function; instead use `tanpi` in C and
 *  Objective-C, and `simd::tanpi` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_tanpi(simd_double2 x);
/*! @abstract Do not call this function; instead use `tanpi` in C and
 *  Objective-C, and `simd::tanpi` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_tanpi(simd_double3 x);
/*! @abstract Do not call this function; instead use `tanpi` in C and
 *  Objective-C, and `simd::tanpi` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_tanpi(simd_double4 x);
/*! @abstract Do not call this function; instead use `tanpi` in C and
 *  Objective-C, and `simd::tanpi` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_tanpi(simd_double8 x);
#endif

/*! @abstract Do not call this function; instead use `acosh` in C and
 *  Objective-C, and `simd::acosh` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_acosh(simd_float2 x);
/*! @abstract Do not call this function; instead use `acosh` in C and
 *  Objective-C, and `simd::acosh` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_acosh(simd_float3 x);
/*! @abstract Do not call this function; instead use `acosh` in C and
 *  Objective-C, and `simd::acosh` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_acosh(simd_float4 x);
/*! @abstract Do not call this function; instead use `acosh` in C and
 *  Objective-C, and `simd::acosh` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_acosh(simd_float8 x);
/*! @abstract Do not call this function; instead use `acosh` in C and
 *  Objective-C, and `simd::acosh` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_acosh(simd_float16 x);
/*! @abstract Do not call this function; instead use `acosh` in C and
 *  Objective-C, and `simd::acosh` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_acosh(simd_double2 x);
/*! @abstract Do not call this function; instead use `acosh` in C and
 *  Objective-C, and `simd::acosh` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_acosh(simd_double3 x);
/*! @abstract Do not call this function; instead use `acosh` in C and
 *  Objective-C, and `simd::acosh` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_acosh(simd_double4 x);
/*! @abstract Do not call this function; instead use `acosh` in C and
 *  Objective-C, and `simd::acosh` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_acosh(simd_double8 x);

/*! @abstract Do not call this function; instead use `asinh` in C and
 *  Objective-C, and `simd::asinh` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_asinh(simd_float2 x);
/*! @abstract Do not call this function; instead use `asinh` in C and
 *  Objective-C, and `simd::asinh` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_asinh(simd_float3 x);
/*! @abstract Do not call this function; instead use `asinh` in C and
 *  Objective-C, and `simd::asinh` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_asinh(simd_float4 x);
/*! @abstract Do not call this function; instead use `asinh` in C and
 *  Objective-C, and `simd::asinh` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_asinh(simd_float8 x);
/*! @abstract Do not call this function; instead use `asinh` in C and
 *  Objective-C, and `simd::asinh` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_asinh(simd_float16 x);
/*! @abstract Do not call this function; instead use `asinh` in C and
 *  Objective-C, and `simd::asinh` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_asinh(simd_double2 x);
/*! @abstract Do not call this function; instead use `asinh` in C and
 *  Objective-C, and `simd::asinh` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_asinh(simd_double3 x);
/*! @abstract Do not call this function; instead use `asinh` in C and
 *  Objective-C, and `simd::asinh` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_asinh(simd_double4 x);
/*! @abstract Do not call this function; instead use `asinh` in C and
 *  Objective-C, and `simd::asinh` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_asinh(simd_double8 x);

/*! @abstract Do not call this function; instead use `atanh` in C and
 *  Objective-C, and `simd::atanh` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_atanh(simd_float2 x);
/*! @abstract Do not call this function; instead use `atanh` in C and
 *  Objective-C, and `simd::atanh` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_atanh(simd_float3 x);
/*! @abstract Do not call this function; instead use `atanh` in C and
 *  Objective-C, and `simd::atanh` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_atanh(simd_float4 x);
/*! @abstract Do not call this function; instead use `atanh` in C and
 *  Objective-C, and `simd::atanh` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_atanh(simd_float8 x);
/*! @abstract Do not call this function; instead use `atanh` in C and
 *  Objective-C, and `simd::atanh` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_atanh(simd_float16 x);
/*! @abstract Do not call this function; instead use `atanh` in C and
 *  Objective-C, and `simd::atanh` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_atanh(simd_double2 x);
/*! @abstract Do not call this function; instead use `atanh` in C and
 *  Objective-C, and `simd::atanh` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_atanh(simd_double3 x);
/*! @abstract Do not call this function; instead use `atanh` in C and
 *  Objective-C, and `simd::atanh` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_atanh(simd_double4 x);
/*! @abstract Do not call this function; instead use `atanh` in C and
 *  Objective-C, and `simd::atanh` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_atanh(simd_double8 x);

/*! @abstract Do not call this function; instead use `cosh` in C and
 *  Objective-C, and `simd::cosh` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_cosh(simd_float2 x);
/*! @abstract Do not call this function; instead use `cosh` in C and
 *  Objective-C, and `simd::cosh` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_cosh(simd_float3 x);
/*! @abstract Do not call this function; instead use `cosh` in C and
 *  Objective-C, and `simd::cosh` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_cosh(simd_float4 x);
/*! @abstract Do not call this function; instead use `cosh` in C and
 *  Objective-C, and `simd::cosh` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_cosh(simd_float8 x);
/*! @abstract Do not call this function; instead use `cosh` in C and
 *  Objective-C, and `simd::cosh` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_cosh(simd_float16 x);
/*! @abstract Do not call this function; instead use `cosh` in C and
 *  Objective-C, and `simd::cosh` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_cosh(simd_double2 x);
/*! @abstract Do not call this function; instead use `cosh` in C and
 *  Objective-C, and `simd::cosh` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_cosh(simd_double3 x);
/*! @abstract Do not call this function; instead use `cosh` in C and
 *  Objective-C, and `simd::cosh` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_cosh(simd_double4 x);
/*! @abstract Do not call this function; instead use `cosh` in C and
 *  Objective-C, and `simd::cosh` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_cosh(simd_double8 x);

/*! @abstract Do not call this function; instead use `sinh` in C and
 *  Objective-C, and `simd::sinh` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_sinh(simd_float2 x);
/*! @abstract Do not call this function; instead use `sinh` in C and
 *  Objective-C, and `simd::sinh` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_sinh(simd_float3 x);
/*! @abstract Do not call this function; instead use `sinh` in C and
 *  Objective-C, and `simd::sinh` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_sinh(simd_float4 x);
/*! @abstract Do not call this function; instead use `sinh` in C and
 *  Objective-C, and `simd::sinh` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_sinh(simd_float8 x);
/*! @abstract Do not call this function; instead use `sinh` in C and
 *  Objective-C, and `simd::sinh` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_sinh(simd_float16 x);
/*! @abstract Do not call this function; instead use `sinh` in C and
 *  Objective-C, and `simd::sinh` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_sinh(simd_double2 x);
/*! @abstract Do not call this function; instead use `sinh` in C and
 *  Objective-C, and `simd::sinh` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_sinh(simd_double3 x);
/*! @abstract Do not call this function; instead use `sinh` in C and
 *  Objective-C, and `simd::sinh` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_sinh(simd_double4 x);
/*! @abstract Do not call this function; instead use `sinh` in C and
 *  Objective-C, and `simd::sinh` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_sinh(simd_double8 x);

/*! @abstract Do not call this function; instead use `tanh` in C and
 *  Objective-C, and `simd::tanh` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_tanh(simd_float2 x);
/*! @abstract Do not call this function; instead use `tanh` in C and
 *  Objective-C, and `simd::tanh` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_tanh(simd_float3 x);
/*! @abstract Do not call this function; instead use `tanh` in C and
 *  Objective-C, and `simd::tanh` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_tanh(simd_float4 x);
/*! @abstract Do not call this function; instead use `tanh` in C and
 *  Objective-C, and `simd::tanh` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_tanh(simd_float8 x);
/*! @abstract Do not call this function; instead use `tanh` in C and
 *  Objective-C, and `simd::tanh` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_tanh(simd_float16 x);
/*! @abstract Do not call this function; instead use `tanh` in C and
 *  Objective-C, and `simd::tanh` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_tanh(simd_double2 x);
/*! @abstract Do not call this function; instead use `tanh` in C and
 *  Objective-C, and `simd::tanh` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_tanh(simd_double3 x);
/*! @abstract Do not call this function; instead use `tanh` in C and
 *  Objective-C, and `simd::tanh` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_tanh(simd_double4 x);
/*! @abstract Do not call this function; instead use `tanh` in C and
 *  Objective-C, and `simd::tanh` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_tanh(simd_double8 x);

/*! @abstract Do not call this function; instead use `exp` in C and
 *  Objective-C, and `simd::exp` in C++.                                      */
static inline SIMD_CFUNC simd_float2 __tg_exp(simd_float2 x);
/*! @abstract Do not call this function; instead use `exp` in C and
 *  Objective-C, and `simd::exp` in C++.                                      */
static inline SIMD_CFUNC simd_float3 __tg_exp(simd_float3 x);
/*! @abstract Do not call this function; instead use `exp` in C and
 *  Objective-C, and `simd::exp` in C++.                                      */
static inline SIMD_CFUNC simd_float4 __tg_exp(simd_float4 x);
/*! @abstract Do not call this function; instead use `exp` in C and
 *  Objective-C, and `simd::exp` in C++.                                      */
static inline SIMD_CFUNC simd_float8 __tg_exp(simd_float8 x);
/*! @abstract Do not call this function; instead use `exp` in C and
 *  Objective-C, and `simd::exp` in C++.                                      */
static inline SIMD_CFUNC simd_float16 __tg_exp(simd_float16 x);
/*! @abstract Do not call this function; instead use `exp` in C and
 *  Objective-C, and `simd::exp` in C++.                                      */
static inline SIMD_CFUNC simd_double2 __tg_exp(simd_double2 x);
/*! @abstract Do not call this function; instead use `exp` in C and
 *  Objective-C, and `simd::exp` in C++.                                      */
static inline SIMD_CFUNC simd_double3 __tg_exp(simd_double3 x);
/*! @abstract Do not call this function; instead use `exp` in C and
 *  Objective-C, and `simd::exp` in C++.                                      */
static inline SIMD_CFUNC simd_double4 __tg_exp(simd_double4 x);
/*! @abstract Do not call this function; instead use `exp` in C and
 *  Objective-C, and `simd::exp` in C++.                                      */
static inline SIMD_CFUNC simd_double8 __tg_exp(simd_double8 x);

/*! @abstract Do not call this function; instead use `exp2` in C and
 *  Objective-C, and `simd::exp2` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_exp2(simd_float2 x);
/*! @abstract Do not call this function; instead use `exp2` in C and
 *  Objective-C, and `simd::exp2` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_exp2(simd_float3 x);
/*! @abstract Do not call this function; instead use `exp2` in C and
 *  Objective-C, and `simd::exp2` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_exp2(simd_float4 x);
/*! @abstract Do not call this function; instead use `exp2` in C and
 *  Objective-C, and `simd::exp2` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_exp2(simd_float8 x);
/*! @abstract Do not call this function; instead use `exp2` in C and
 *  Objective-C, and `simd::exp2` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_exp2(simd_float16 x);
/*! @abstract Do not call this function; instead use `exp2` in C and
 *  Objective-C, and `simd::exp2` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_exp2(simd_double2 x);
/*! @abstract Do not call this function; instead use `exp2` in C and
 *  Objective-C, and `simd::exp2` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_exp2(simd_double3 x);
/*! @abstract Do not call this function; instead use `exp2` in C and
 *  Objective-C, and `simd::exp2` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_exp2(simd_double4 x);
/*! @abstract Do not call this function; instead use `exp2` in C and
 *  Objective-C, and `simd::exp2` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_exp2(simd_double8 x);

#if SIMD_LIBRARY_VERSION >= 1
/*! @abstract Do not call this function; instead use `exp10` in C and
 *  Objective-C, and `simd::exp10` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_exp10(simd_float2 x);
/*! @abstract Do not call this function; instead use `exp10` in C and
 *  Objective-C, and `simd::exp10` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_exp10(simd_float3 x);
/*! @abstract Do not call this function; instead use `exp10` in C and
 *  Objective-C, and `simd::exp10` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_exp10(simd_float4 x);
/*! @abstract Do not call this function; instead use `exp10` in C and
 *  Objective-C, and `simd::exp10` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_exp10(simd_float8 x);
/*! @abstract Do not call this function; instead use `exp10` in C and
 *  Objective-C, and `simd::exp10` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_exp10(simd_float16 x);
/*! @abstract Do not call this function; instead use `exp10` in C and
 *  Objective-C, and `simd::exp10` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_exp10(simd_double2 x);
/*! @abstract Do not call this function; instead use `exp10` in C and
 *  Objective-C, and `simd::exp10` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_exp10(simd_double3 x);
/*! @abstract Do not call this function; instead use `exp10` in C and
 *  Objective-C, and `simd::exp10` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_exp10(simd_double4 x);
/*! @abstract Do not call this function; instead use `exp10` in C and
 *  Objective-C, and `simd::exp10` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_exp10(simd_double8 x);
#endif

/*! @abstract Do not call this function; instead use `expm1` in C and
 *  Objective-C, and `simd::expm1` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_expm1(simd_float2 x);
/*! @abstract Do not call this function; instead use `expm1` in C and
 *  Objective-C, and `simd::expm1` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_expm1(simd_float3 x);
/*! @abstract Do not call this function; instead use `expm1` in C and
 *  Objective-C, and `simd::expm1` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_expm1(simd_float4 x);
/*! @abstract Do not call this function; instead use `expm1` in C and
 *  Objective-C, and `simd::expm1` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_expm1(simd_float8 x);
/*! @abstract Do not call this function; instead use `expm1` in C and
 *  Objective-C, and `simd::expm1` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_expm1(simd_float16 x);
/*! @abstract Do not call this function; instead use `expm1` in C and
 *  Objective-C, and `simd::expm1` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_expm1(simd_double2 x);
/*! @abstract Do not call this function; instead use `expm1` in C and
 *  Objective-C, and `simd::expm1` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_expm1(simd_double3 x);
/*! @abstract Do not call this function; instead use `expm1` in C and
 *  Objective-C, and `simd::expm1` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_expm1(simd_double4 x);
/*! @abstract Do not call this function; instead use `expm1` in C and
 *  Objective-C, and `simd::expm1` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_expm1(simd_double8 x);

/*! @abstract Do not call this function; instead use `log` in C and
 *  Objective-C, and `simd::log` in C++.                                      */
static inline SIMD_CFUNC simd_float2 __tg_log(simd_float2 x);
/*! @abstract Do not call this function; instead use `log` in C and
 *  Objective-C, and `simd::log` in C++.                                      */
static inline SIMD_CFUNC simd_float3 __tg_log(simd_float3 x);
/*! @abstract Do not call this function; instead use `log` in C and
 *  Objective-C, and `simd::log` in C++.                                      */
static inline SIMD_CFUNC simd_float4 __tg_log(simd_float4 x);
/*! @abstract Do not call this function; instead use `log` in C and
 *  Objective-C, and `simd::log` in C++.                                      */
static inline SIMD_CFUNC simd_float8 __tg_log(simd_float8 x);
/*! @abstract Do not call this function; instead use `log` in C and
 *  Objective-C, and `simd::log` in C++.                                      */
static inline SIMD_CFUNC simd_float16 __tg_log(simd_float16 x);
/*! @abstract Do not call this function; instead use `log` in C and
 *  Objective-C, and `simd::log` in C++.                                      */
static inline SIMD_CFUNC simd_double2 __tg_log(simd_double2 x);
/*! @abstract Do not call this function; instead use `log` in C and
 *  Objective-C, and `simd::log` in C++.                                      */
static inline SIMD_CFUNC simd_double3 __tg_log(simd_double3 x);
/*! @abstract Do not call this function; instead use `log` in C and
 *  Objective-C, and `simd::log` in C++.                                      */
static inline SIMD_CFUNC simd_double4 __tg_log(simd_double4 x);
/*! @abstract Do not call this function; instead use `log` in C and
 *  Objective-C, and `simd::log` in C++.                                      */
static inline SIMD_CFUNC simd_double8 __tg_log(simd_double8 x);

/*! @abstract Do not call this function; instead use `log2` in C and
 *  Objective-C, and `simd::log2` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_log2(simd_float2 x);
/*! @abstract Do not call this function; instead use `log2` in C and
 *  Objective-C, and `simd::log2` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_log2(simd_float3 x);
/*! @abstract Do not call this function; instead use `log2` in C and
 *  Objective-C, and `simd::log2` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_log2(simd_float4 x);
/*! @abstract Do not call this function; instead use `log2` in C and
 *  Objective-C, and `simd::log2` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_log2(simd_float8 x);
/*! @abstract Do not call this function; instead use `log2` in C and
 *  Objective-C, and `simd::log2` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_log2(simd_float16 x);
/*! @abstract Do not call this function; instead use `log2` in C and
 *  Objective-C, and `simd::log2` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_log2(simd_double2 x);
/*! @abstract Do not call this function; instead use `log2` in C and
 *  Objective-C, and `simd::log2` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_log2(simd_double3 x);
/*! @abstract Do not call this function; instead use `log2` in C and
 *  Objective-C, and `simd::log2` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_log2(simd_double4 x);
/*! @abstract Do not call this function; instead use `log2` in C and
 *  Objective-C, and `simd::log2` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_log2(simd_double8 x);

/*! @abstract Do not call this function; instead use `log10` in C and
 *  Objective-C, and `simd::log10` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_log10(simd_float2 x);
/*! @abstract Do not call this function; instead use `log10` in C and
 *  Objective-C, and `simd::log10` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_log10(simd_float3 x);
/*! @abstract Do not call this function; instead use `log10` in C and
 *  Objective-C, and `simd::log10` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_log10(simd_float4 x);
/*! @abstract Do not call this function; instead use `log10` in C and
 *  Objective-C, and `simd::log10` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_log10(simd_float8 x);
/*! @abstract Do not call this function; instead use `log10` in C and
 *  Objective-C, and `simd::log10` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_log10(simd_float16 x);
/*! @abstract Do not call this function; instead use `log10` in C and
 *  Objective-C, and `simd::log10` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_log10(simd_double2 x);
/*! @abstract Do not call this function; instead use `log10` in C and
 *  Objective-C, and `simd::log10` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_log10(simd_double3 x);
/*! @abstract Do not call this function; instead use `log10` in C and
 *  Objective-C, and `simd::log10` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_log10(simd_double4 x);
/*! @abstract Do not call this function; instead use `log10` in C and
 *  Objective-C, and `simd::log10` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_log10(simd_double8 x);

/*! @abstract Do not call this function; instead use `log1p` in C and
 *  Objective-C, and `simd::log1p` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_log1p(simd_float2 x);
/*! @abstract Do not call this function; instead use `log1p` in C and
 *  Objective-C, and `simd::log1p` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_log1p(simd_float3 x);
/*! @abstract Do not call this function; instead use `log1p` in C and
 *  Objective-C, and `simd::log1p` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_log1p(simd_float4 x);
/*! @abstract Do not call this function; instead use `log1p` in C and
 *  Objective-C, and `simd::log1p` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_log1p(simd_float8 x);
/*! @abstract Do not call this function; instead use `log1p` in C and
 *  Objective-C, and `simd::log1p` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_log1p(simd_float16 x);
/*! @abstract Do not call this function; instead use `log1p` in C and
 *  Objective-C, and `simd::log1p` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_log1p(simd_double2 x);
/*! @abstract Do not call this function; instead use `log1p` in C and
 *  Objective-C, and `simd::log1p` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_log1p(simd_double3 x);
/*! @abstract Do not call this function; instead use `log1p` in C and
 *  Objective-C, and `simd::log1p` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_log1p(simd_double4 x);
/*! @abstract Do not call this function; instead use `log1p` in C and
 *  Objective-C, and `simd::log1p` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_log1p(simd_double8 x);

/*! @abstract Do not call this function; instead use `fabs` in C and
 *  Objective-C, and `simd::fabs` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_fabs(simd_float2 x);
/*! @abstract Do not call this function; instead use `fabs` in C and
 *  Objective-C, and `simd::fabs` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_fabs(simd_float3 x);
/*! @abstract Do not call this function; instead use `fabs` in C and
 *  Objective-C, and `simd::fabs` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_fabs(simd_float4 x);
/*! @abstract Do not call this function; instead use `fabs` in C and
 *  Objective-C, and `simd::fabs` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_fabs(simd_float8 x);
/*! @abstract Do not call this function; instead use `fabs` in C and
 *  Objective-C, and `simd::fabs` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_fabs(simd_float16 x);
/*! @abstract Do not call this function; instead use `fabs` in C and
 *  Objective-C, and `simd::fabs` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_fabs(simd_double2 x);
/*! @abstract Do not call this function; instead use `fabs` in C and
 *  Objective-C, and `simd::fabs` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_fabs(simd_double3 x);
/*! @abstract Do not call this function; instead use `fabs` in C and
 *  Objective-C, and `simd::fabs` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_fabs(simd_double4 x);
/*! @abstract Do not call this function; instead use `fabs` in C and
 *  Objective-C, and `simd::fabs` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_fabs(simd_double8 x);

/*! @abstract Do not call this function; instead use `cbrt` in C and
 *  Objective-C, and `simd::cbrt` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_cbrt(simd_float2 x);
/*! @abstract Do not call this function; instead use `cbrt` in C and
 *  Objective-C, and `simd::cbrt` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_cbrt(simd_float3 x);
/*! @abstract Do not call this function; instead use `cbrt` in C and
 *  Objective-C, and `simd::cbrt` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_cbrt(simd_float4 x);
/*! @abstract Do not call this function; instead use `cbrt` in C and
 *  Objective-C, and `simd::cbrt` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_cbrt(simd_float8 x);
/*! @abstract Do not call this function; instead use `cbrt` in C and
 *  Objective-C, and `simd::cbrt` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_cbrt(simd_float16 x);
/*! @abstract Do not call this function; instead use `cbrt` in C and
 *  Objective-C, and `simd::cbrt` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_cbrt(simd_double2 x);
/*! @abstract Do not call this function; instead use `cbrt` in C and
 *  Objective-C, and `simd::cbrt` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_cbrt(simd_double3 x);
/*! @abstract Do not call this function; instead use `cbrt` in C and
 *  Objective-C, and `simd::cbrt` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_cbrt(simd_double4 x);
/*! @abstract Do not call this function; instead use `cbrt` in C and
 *  Objective-C, and `simd::cbrt` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_cbrt(simd_double8 x);

/*! @abstract Do not call this function; instead use `sqrt` in C and
 *  Objective-C, and `simd::sqrt` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_sqrt(simd_float2 x);
/*! @abstract Do not call this function; instead use `sqrt` in C and
 *  Objective-C, and `simd::sqrt` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_sqrt(simd_float3 x);
/*! @abstract Do not call this function; instead use `sqrt` in C and
 *  Objective-C, and `simd::sqrt` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_sqrt(simd_float4 x);
/*! @abstract Do not call this function; instead use `sqrt` in C and
 *  Objective-C, and `simd::sqrt` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_sqrt(simd_float8 x);
/*! @abstract Do not call this function; instead use `sqrt` in C and
 *  Objective-C, and `simd::sqrt` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_sqrt(simd_float16 x);
/*! @abstract Do not call this function; instead use `sqrt` in C and
 *  Objective-C, and `simd::sqrt` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_sqrt(simd_double2 x);
/*! @abstract Do not call this function; instead use `sqrt` in C and
 *  Objective-C, and `simd::sqrt` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_sqrt(simd_double3 x);
/*! @abstract Do not call this function; instead use `sqrt` in C and
 *  Objective-C, and `simd::sqrt` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_sqrt(simd_double4 x);
/*! @abstract Do not call this function; instead use `sqrt` in C and
 *  Objective-C, and `simd::sqrt` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_sqrt(simd_double8 x);

/*! @abstract Do not call this function; instead use `erf` in C and
 *  Objective-C, and `simd::erf` in C++.                                      */
static inline SIMD_CFUNC simd_float2 __tg_erf(simd_float2 x);
/*! @abstract Do not call this function; instead use `erf` in C and
 *  Objective-C, and `simd::erf` in C++.                                      */
static inline SIMD_CFUNC simd_float3 __tg_erf(simd_float3 x);
/*! @abstract Do not call this function; instead use `erf` in C and
 *  Objective-C, and `simd::erf` in C++.                                      */
static inline SIMD_CFUNC simd_float4 __tg_erf(simd_float4 x);
/*! @abstract Do not call this function; instead use `erf` in C and
 *  Objective-C, and `simd::erf` in C++.                                      */
static inline SIMD_CFUNC simd_float8 __tg_erf(simd_float8 x);
/*! @abstract Do not call this function; instead use `erf` in C and
 *  Objective-C, and `simd::erf` in C++.                                      */
static inline SIMD_CFUNC simd_float16 __tg_erf(simd_float16 x);
/*! @abstract Do not call this function; instead use `erf` in C and
 *  Objective-C, and `simd::erf` in C++.                                      */
static inline SIMD_CFUNC simd_double2 __tg_erf(simd_double2 x);
/*! @abstract Do not call this function; instead use `erf` in C and
 *  Objective-C, and `simd::erf` in C++.                                      */
static inline SIMD_CFUNC simd_double3 __tg_erf(simd_double3 x);
/*! @abstract Do not call this function; instead use `erf` in C and
 *  Objective-C, and `simd::erf` in C++.                                      */
static inline SIMD_CFUNC simd_double4 __tg_erf(simd_double4 x);
/*! @abstract Do not call this function; instead use `erf` in C and
 *  Objective-C, and `simd::erf` in C++.                                      */
static inline SIMD_CFUNC simd_double8 __tg_erf(simd_double8 x);

/*! @abstract Do not call this function; instead use `erfc` in C and
 *  Objective-C, and `simd::erfc` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_erfc(simd_float2 x);
/*! @abstract Do not call this function; instead use `erfc` in C and
 *  Objective-C, and `simd::erfc` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_erfc(simd_float3 x);
/*! @abstract Do not call this function; instead use `erfc` in C and
 *  Objective-C, and `simd::erfc` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_erfc(simd_float4 x);
/*! @abstract Do not call this function; instead use `erfc` in C and
 *  Objective-C, and `simd::erfc` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_erfc(simd_float8 x);
/*! @abstract Do not call this function; instead use `erfc` in C and
 *  Objective-C, and `simd::erfc` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_erfc(simd_float16 x);
/*! @abstract Do not call this function; instead use `erfc` in C and
 *  Objective-C, and `simd::erfc` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_erfc(simd_double2 x);
/*! @abstract Do not call this function; instead use `erfc` in C and
 *  Objective-C, and `simd::erfc` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_erfc(simd_double3 x);
/*! @abstract Do not call this function; instead use `erfc` in C and
 *  Objective-C, and `simd::erfc` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_erfc(simd_double4 x);
/*! @abstract Do not call this function; instead use `erfc` in C and
 *  Objective-C, and `simd::erfc` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_erfc(simd_double8 x);

/*! @abstract Do not call this function; instead use `tgamma` in C and
 *  Objective-C, and `simd::tgamma` in C++.                                   */
static inline SIMD_CFUNC simd_float2 __tg_tgamma(simd_float2 x);
/*! @abstract Do not call this function; instead use `tgamma` in C and
 *  Objective-C, and `simd::tgamma` in C++.                                   */
static inline SIMD_CFUNC simd_float3 __tg_tgamma(simd_float3 x);
/*! @abstract Do not call this function; instead use `tgamma` in C and
 *  Objective-C, and `simd::tgamma` in C++.                                   */
static inline SIMD_CFUNC simd_float4 __tg_tgamma(simd_float4 x);
/*! @abstract Do not call this function; instead use `tgamma` in C and
 *  Objective-C, and `simd::tgamma` in C++.                                   */
static inline SIMD_CFUNC simd_float8 __tg_tgamma(simd_float8 x);
/*! @abstract Do not call this function; instead use `tgamma` in C and
 *  Objective-C, and `simd::tgamma` in C++.                                   */
static inline SIMD_CFUNC simd_float16 __tg_tgamma(simd_float16 x);
/*! @abstract Do not call this function; instead use `tgamma` in C and
 *  Objective-C, and `simd::tgamma` in C++.                                   */
static inline SIMD_CFUNC simd_double2 __tg_tgamma(simd_double2 x);
/*! @abstract Do not call this function; instead use `tgamma` in C and
 *  Objective-C, and `simd::tgamma` in C++.                                   */
static inline SIMD_CFUNC simd_double3 __tg_tgamma(simd_double3 x);
/*! @abstract Do not call this function; instead use `tgamma` in C and
 *  Objective-C, and `simd::tgamma` in C++.                                   */
static inline SIMD_CFUNC simd_double4 __tg_tgamma(simd_double4 x);
/*! @abstract Do not call this function; instead use `tgamma` in C and
 *  Objective-C, and `simd::tgamma` in C++.                                   */
static inline SIMD_CFUNC simd_double8 __tg_tgamma(simd_double8 x);

/*! @abstract Do not call this function; instead use `ceil` in C and
 *  Objective-C, and `simd::ceil` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_ceil(simd_float2 x);
/*! @abstract Do not call this function; instead use `ceil` in C and
 *  Objective-C, and `simd::ceil` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_ceil(simd_float3 x);
/*! @abstract Do not call this function; instead use `ceil` in C and
 *  Objective-C, and `simd::ceil` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_ceil(simd_float4 x);
/*! @abstract Do not call this function; instead use `ceil` in C and
 *  Objective-C, and `simd::ceil` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_ceil(simd_float8 x);
/*! @abstract Do not call this function; instead use `ceil` in C and
 *  Objective-C, and `simd::ceil` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_ceil(simd_float16 x);
/*! @abstract Do not call this function; instead use `ceil` in C and
 *  Objective-C, and `simd::ceil` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_ceil(simd_double2 x);
/*! @abstract Do not call this function; instead use `ceil` in C and
 *  Objective-C, and `simd::ceil` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_ceil(simd_double3 x);
/*! @abstract Do not call this function; instead use `ceil` in C and
 *  Objective-C, and `simd::ceil` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_ceil(simd_double4 x);
/*! @abstract Do not call this function; instead use `ceil` in C and
 *  Objective-C, and `simd::ceil` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_ceil(simd_double8 x);

/*! @abstract Do not call this function; instead use `floor` in C and
 *  Objective-C, and `simd::floor` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_floor(simd_float2 x);
/*! @abstract Do not call this function; instead use `floor` in C and
 *  Objective-C, and `simd::floor` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_floor(simd_float3 x);
/*! @abstract Do not call this function; instead use `floor` in C and
 *  Objective-C, and `simd::floor` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_floor(simd_float4 x);
/*! @abstract Do not call this function; instead use `floor` in C and
 *  Objective-C, and `simd::floor` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_floor(simd_float8 x);
/*! @abstract Do not call this function; instead use `floor` in C and
 *  Objective-C, and `simd::floor` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_floor(simd_float16 x);
/*! @abstract Do not call this function; instead use `floor` in C and
 *  Objective-C, and `simd::floor` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_floor(simd_double2 x);
/*! @abstract Do not call this function; instead use `floor` in C and
 *  Objective-C, and `simd::floor` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_floor(simd_double3 x);
/*! @abstract Do not call this function; instead use `floor` in C and
 *  Objective-C, and `simd::floor` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_floor(simd_double4 x);
/*! @abstract Do not call this function; instead use `floor` in C and
 *  Objective-C, and `simd::floor` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_floor(simd_double8 x);

/*! @abstract Do not call this function; instead use `rint` in C and
 *  Objective-C, and `simd::rint` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_rint(simd_float2 x);
/*! @abstract Do not call this function; instead use `rint` in C and
 *  Objective-C, and `simd::rint` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_rint(simd_float3 x);
/*! @abstract Do not call this function; instead use `rint` in C and
 *  Objective-C, and `simd::rint` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_rint(simd_float4 x);
/*! @abstract Do not call this function; instead use `rint` in C and
 *  Objective-C, and `simd::rint` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_rint(simd_float8 x);
/*! @abstract Do not call this function; instead use `rint` in C and
 *  Objective-C, and `simd::rint` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_rint(simd_float16 x);
/*! @abstract Do not call this function; instead use `rint` in C and
 *  Objective-C, and `simd::rint` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_rint(simd_double2 x);
/*! @abstract Do not call this function; instead use `rint` in C and
 *  Objective-C, and `simd::rint` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_rint(simd_double3 x);
/*! @abstract Do not call this function; instead use `rint` in C and
 *  Objective-C, and `simd::rint` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_rint(simd_double4 x);
/*! @abstract Do not call this function; instead use `rint` in C and
 *  Objective-C, and `simd::rint` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_rint(simd_double8 x);

/*! @abstract Do not call this function; instead use `round` in C and
 *  Objective-C, and `simd::round` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_round(simd_float2 x);
/*! @abstract Do not call this function; instead use `round` in C and
 *  Objective-C, and `simd::round` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_round(simd_float3 x);
/*! @abstract Do not call this function; instead use `round` in C and
 *  Objective-C, and `simd::round` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_round(simd_float4 x);
/*! @abstract Do not call this function; instead use `round` in C and
 *  Objective-C, and `simd::round` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_round(simd_float8 x);
/*! @abstract Do not call this function; instead use `round` in C and
 *  Objective-C, and `simd::round` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_round(simd_float16 x);
/*! @abstract Do not call this function; instead use `round` in C and
 *  Objective-C, and `simd::round` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_round(simd_double2 x);
/*! @abstract Do not call this function; instead use `round` in C and
 *  Objective-C, and `simd::round` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_round(simd_double3 x);
/*! @abstract Do not call this function; instead use `round` in C and
 *  Objective-C, and `simd::round` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_round(simd_double4 x);
/*! @abstract Do not call this function; instead use `round` in C and
 *  Objective-C, and `simd::round` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_round(simd_double8 x);

/*! @abstract Do not call this function; instead use `trunc` in C and
 *  Objective-C, and `simd::trunc` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_trunc(simd_float2 x);
/*! @abstract Do not call this function; instead use `trunc` in C and
 *  Objective-C, and `simd::trunc` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_trunc(simd_float3 x);
/*! @abstract Do not call this function; instead use `trunc` in C and
 *  Objective-C, and `simd::trunc` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_trunc(simd_float4 x);
/*! @abstract Do not call this function; instead use `trunc` in C and
 *  Objective-C, and `simd::trunc` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_trunc(simd_float8 x);
/*! @abstract Do not call this function; instead use `trunc` in C and
 *  Objective-C, and `simd::trunc` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_trunc(simd_float16 x);
/*! @abstract Do not call this function; instead use `trunc` in C and
 *  Objective-C, and `simd::trunc` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_trunc(simd_double2 x);
/*! @abstract Do not call this function; instead use `trunc` in C and
 *  Objective-C, and `simd::trunc` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_trunc(simd_double3 x);
/*! @abstract Do not call this function; instead use `trunc` in C and
 *  Objective-C, and `simd::trunc` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_trunc(simd_double4 x);
/*! @abstract Do not call this function; instead use `trunc` in C and
 *  Objective-C, and `simd::trunc` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_trunc(simd_double8 x);

    
/*! @abstract Do not call this function; instead use `atan2` in C and
 *  Objective-C, and `simd::atan2` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_atan2(simd_float2 y, simd_float2 x);
/*! @abstract Do not call this function; instead use `atan2` in C and
 *  Objective-C, and `simd::atan2` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_atan2(simd_float3 y, simd_float3 x);
/*! @abstract Do not call this function; instead use `atan2` in C and
 *  Objective-C, and `simd::atan2` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_atan2(simd_float4 y, simd_float4 x);
/*! @abstract Do not call this function; instead use `atan2` in C and
 *  Objective-C, and `simd::atan2` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_atan2(simd_float8 y, simd_float8 x);
/*! @abstract Do not call this function; instead use `atan2` in C and
 *  Objective-C, and `simd::atan2` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_atan2(simd_float16 y, simd_float16 x);
/*! @abstract Do not call this function; instead use `atan2` in C and
 *  Objective-C, and `simd::atan2` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_atan2(simd_double2 y, simd_double2 x);
/*! @abstract Do not call this function; instead use `atan2` in C and
 *  Objective-C, and `simd::atan2` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_atan2(simd_double3 y, simd_double3 x);
/*! @abstract Do not call this function; instead use `atan2` in C and
 *  Objective-C, and `simd::atan2` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_atan2(simd_double4 y, simd_double4 x);
/*! @abstract Do not call this function; instead use `atan2` in C and
 *  Objective-C, and `simd::atan2` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_atan2(simd_double8 y, simd_double8 x);

/*! @abstract Do not call this function; instead use `hypot` in C and
 *  Objective-C, and `simd::hypot` in C++.                                    */
static inline SIMD_CFUNC simd_float2 __tg_hypot(simd_float2 x, simd_float2 y);
/*! @abstract Do not call this function; instead use `hypot` in C and
 *  Objective-C, and `simd::hypot` in C++.                                    */
static inline SIMD_CFUNC simd_float3 __tg_hypot(simd_float3 x, simd_float3 y);
/*! @abstract Do not call this function; instead use `hypot` in C and
 *  Objective-C, and `simd::hypot` in C++.                                    */
static inline SIMD_CFUNC simd_float4 __tg_hypot(simd_float4 x, simd_float4 y);
/*! @abstract Do not call this function; instead use `hypot` in C and
 *  Objective-C, and `simd::hypot` in C++.                                    */
static inline SIMD_CFUNC simd_float8 __tg_hypot(simd_float8 x, simd_float8 y);
/*! @abstract Do not call this function; instead use `hypot` in C and
 *  Objective-C, and `simd::hypot` in C++.                                    */
static inline SIMD_CFUNC simd_float16 __tg_hypot(simd_float16 x, simd_float16 y);
/*! @abstract Do not call this function; instead use `hypot` in C and
 *  Objective-C, and `simd::hypot` in C++.                                    */
static inline SIMD_CFUNC simd_double2 __tg_hypot(simd_double2 x, simd_double2 y);
/*! @abstract Do not call this function; instead use `hypot` in C and
 *  Objective-C, and `simd::hypot` in C++.                                    */
static inline SIMD_CFUNC simd_double3 __tg_hypot(simd_double3 x, simd_double3 y);
/*! @abstract Do not call this function; instead use `hypot` in C and
 *  Objective-C, and `simd::hypot` in C++.                                    */
static inline SIMD_CFUNC simd_double4 __tg_hypot(simd_double4 x, simd_double4 y);
/*! @abstract Do not call this function; instead use `hypot` in C and
 *  Objective-C, and `simd::hypot` in C++.                                    */
static inline SIMD_CFUNC simd_double8 __tg_hypot(simd_double8 x, simd_double8 y);

/*! @abstract Do not call this function; instead use `pow` in C and
 *  Objective-C, and `simd::pow` in C++.                                      */
static inline SIMD_CFUNC simd_float2 __tg_pow(simd_float2 x, simd_float2 y);
/*! @abstract Do not call this function; instead use `pow` in C and
 *  Objective-C, and `simd::pow` in C++.                                      */
static inline SIMD_CFUNC simd_float3 __tg_pow(simd_float3 x, simd_float3 y);
/*! @abstract Do not call this function; instead use `pow` in C and
 *  Objective-C, and `simd::pow` in C++.                                      */
static inline SIMD_CFUNC simd_float4 __tg_pow(simd_float4 x, simd_float4 y);
/*! @abstract Do not call this function; instead use `pow` in C and
 *  Objective-C, and `simd::pow` in C++.                                      */
static inline SIMD_CFUNC simd_float8 __tg_pow(simd_float8 x, simd_float8 y);
/*! @abstract Do not call this function; instead use `pow` in C and
 *  Objective-C, and `simd::pow` in C++.                                      */
static inline SIMD_CFUNC simd_float16 __tg_pow(simd_float16 x, simd_float16 y);
/*! @abstract Do not call this function; instead use `pow` in C and
 *  Objective-C, and `simd::pow` in C++.                                      */
static inline SIMD_CFUNC simd_double2 __tg_pow(simd_double2 x, simd_double2 y);
/*! @abstract Do not call this function; instead use `pow` in C and
 *  Objective-C, and `simd::pow` in C++.                                      */
static inline SIMD_CFUNC simd_double3 __tg_pow(simd_double3 x, simd_double3 y);
/*! @abstract Do not call this function; instead use `pow` in C and
 *  Objective-C, and `simd::pow` in C++.                                      */
static inline SIMD_CFUNC simd_double4 __tg_pow(simd_double4 x, simd_double4 y);
/*! @abstract Do not call this function; instead use `pow` in C and
 *  Objective-C, and `simd::pow` in C++.                                      */
static inline SIMD_CFUNC simd_double8 __tg_pow(simd_double8 x, simd_double8 y);

/*! @abstract Do not call this function; instead use `fmod` in C and
 *  Objective-C, and `simd::fmod` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_fmod(simd_float2 x, simd_float2 y);
/*! @abstract Do not call this function; instead use `fmod` in C and
 *  Objective-C, and `simd::fmod` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_fmod(simd_float3 x, simd_float3 y);
/*! @abstract Do not call this function; instead use `fmod` in C and
 *  Objective-C, and `simd::fmod` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_fmod(simd_float4 x, simd_float4 y);
/*! @abstract Do not call this function; instead use `fmod` in C and
 *  Objective-C, and `simd::fmod` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_fmod(simd_float8 x, simd_float8 y);
/*! @abstract Do not call this function; instead use `fmod` in C and
 *  Objective-C, and `simd::fmod` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_fmod(simd_float16 x, simd_float16 y);
/*! @abstract Do not call this function; instead use `fmod` in C and
 *  Objective-C, and `simd::fmod` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_fmod(simd_double2 x, simd_double2 y);
/*! @abstract Do not call this function; instead use `fmod` in C and
 *  Objective-C, and `simd::fmod` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_fmod(simd_double3 x, simd_double3 y);
/*! @abstract Do not call this function; instead use `fmod` in C and
 *  Objective-C, and `simd::fmod` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_fmod(simd_double4 x, simd_double4 y);
/*! @abstract Do not call this function; instead use `fmod` in C and
 *  Objective-C, and `simd::fmod` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_fmod(simd_double8 x, simd_double8 y);

/*! @abstract Do not call this function; instead use `remainder` in C and
 *  Objective-C, and `simd::remainder` in C++.                                */
static inline SIMD_CFUNC simd_float2 __tg_remainder(simd_float2 x, simd_float2 y);
/*! @abstract Do not call this function; instead use `remainder` in C and
 *  Objective-C, and `simd::remainder` in C++.                                */
static inline SIMD_CFUNC simd_float3 __tg_remainder(simd_float3 x, simd_float3 y);
/*! @abstract Do not call this function; instead use `remainder` in C and
 *  Objective-C, and `simd::remainder` in C++.                                */
static inline SIMD_CFUNC simd_float4 __tg_remainder(simd_float4 x, simd_float4 y);
/*! @abstract Do not call this function; instead use `remainder` in C and
 *  Objective-C, and `simd::remainder` in C++.                                */
static inline SIMD_CFUNC simd_float8 __tg_remainder(simd_float8 x, simd_float8 y);
/*! @abstract Do not call this function; instead use `remainder` in C and
 *  Objective-C, and `simd::remainder` in C++.                                */
static inline SIMD_CFUNC simd_float16 __tg_remainder(simd_float16 x, simd_float16 y);
/*! @abstract Do not call this function; instead use `remainder` in C and
 *  Objective-C, and `simd::remainder` in C++.                                */
static inline SIMD_CFUNC simd_double2 __tg_remainder(simd_double2 x, simd_double2 y);
/*! @abstract Do not call this function; instead use `remainder` in C and
 *  Objective-C, and `simd::remainder` in C++.                                */
static inline SIMD_CFUNC simd_double3 __tg_remainder(simd_double3 x, simd_double3 y);
/*! @abstract Do not call this function; instead use `remainder` in C and
 *  Objective-C, and `simd::remainder` in C++.                                */
static inline SIMD_CFUNC simd_double4 __tg_remainder(simd_double4 x, simd_double4 y);
/*! @abstract Do not call this function; instead use `remainder` in C and
 *  Objective-C, and `simd::remainder` in C++.                                */
static inline SIMD_CFUNC simd_double8 __tg_remainder(simd_double8 x, simd_double8 y);

/*! @abstract Do not call this function; instead use `copysign` in C and
 *  Objective-C, and `simd::copysign` in C++.                                 */
static inline SIMD_CFUNC simd_float2 __tg_copysign(simd_float2 x, simd_float2 y);
/*! @abstract Do not call this function; instead use `copysign` in C and
 *  Objective-C, and `simd::copysign` in C++.                                 */
static inline SIMD_CFUNC simd_float3 __tg_copysign(simd_float3 x, simd_float3 y);
/*! @abstract Do not call this function; instead use `copysign` in C and
 *  Objective-C, and `simd::copysign` in C++.                                 */
static inline SIMD_CFUNC simd_float4 __tg_copysign(simd_float4 x, simd_float4 y);
/*! @abstract Do not call this function; instead use `copysign` in C and
 *  Objective-C, and `simd::copysign` in C++.                                 */
static inline SIMD_CFUNC simd_float8 __tg_copysign(simd_float8 x, simd_float8 y);
/*! @abstract Do not call this function; instead use `copysign` in C and
 *  Objective-C, and `simd::copysign` in C++.                                 */
static inline SIMD_CFUNC simd_float16 __tg_copysign(simd_float16 x, simd_float16 y);
/*! @abstract Do not call this function; instead use `copysign` in C and
 *  Objective-C, and `simd::copysign` in C++.                                 */
static inline SIMD_CFUNC simd_double2 __tg_copysign(simd_double2 x, simd_double2 y);
/*! @abstract Do not call this function; instead use `copysign` in C and
 *  Objective-C, and `simd::copysign` in C++.                                 */
static inline SIMD_CFUNC simd_double3 __tg_copysign(simd_double3 x, simd_double3 y);
/*! @abstract Do not call this function; instead use `copysign` in C and
 *  Objective-C, and `simd::copysign` in C++.                                 */
static inline SIMD_CFUNC simd_double4 __tg_copysign(simd_double4 x, simd_double4 y);
/*! @abstract Do not call this function; instead use `copysign` in C and
 *  Objective-C, and `simd::copysign` in C++.                                 */
static inline SIMD_CFUNC simd_double8 __tg_copysign(simd_double8 x, simd_double8 y);

/*! @abstract Do not call this function; instead use `nextafter` in C and
 *  Objective-C, and `simd::nextafter` in C++.                                */
static inline SIMD_CFUNC simd_float2 __tg_nextafter(simd_float2 x, simd_float2 y);
/*! @abstract Do not call this function; instead use `nextafter` in C and
 *  Objective-C, and `simd::nextafter` in C++.                                */
static inline SIMD_CFUNC simd_float3 __tg_nextafter(simd_float3 x, simd_float3 y);
/*! @abstract Do not call this function; instead use `nextafter` in C and
 *  Objective-C, and `simd::nextafter` in C++.                                */
static inline SIMD_CFUNC simd_float4 __tg_nextafter(simd_float4 x, simd_float4 y);
/*! @abstract Do not call this function; instead use `nextafter` in C and
 *  Objective-C, and `simd::nextafter` in C++.                                */
static inline SIMD_CFUNC simd_float8 __tg_nextafter(simd_float8 x, simd_float8 y);
/*! @abstract Do not call this function; instead use `nextafter` in C and
 *  Objective-C, and `simd::nextafter` in C++.                                */
static inline SIMD_CFUNC simd_float16 __tg_nextafter(simd_float16 x, simd_float16 y);
/*! @abstract Do not call this function; instead use `nextafter` in C and
 *  Objective-C, and `simd::nextafter` in C++.                                */
static inline SIMD_CFUNC simd_double2 __tg_nextafter(simd_double2 x, simd_double2 y);
/*! @abstract Do not call this function; instead use `nextafter` in C and
 *  Objective-C, and `simd::nextafter` in C++.                                */
static inline SIMD_CFUNC simd_double3 __tg_nextafter(simd_double3 x, simd_double3 y);
/*! @abstract Do not call this function; instead use `nextafter` in C and
 *  Objective-C, and `simd::nextafter` in C++.                                */
static inline SIMD_CFUNC simd_double4 __tg_nextafter(simd_double4 x, simd_double4 y);
/*! @abstract Do not call this function; instead use `nextafter` in C and
 *  Objective-C, and `simd::nextafter` in C++.                                */
static inline SIMD_CFUNC simd_double8 __tg_nextafter(simd_double8 x, simd_double8 y);

/*! @abstract Do not call this function; instead use `fdim` in C and
 *  Objective-C, and `simd::fdim` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_fdim(simd_float2 x, simd_float2 y);
/*! @abstract Do not call this function; instead use `fdim` in C and
 *  Objective-C, and `simd::fdim` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_fdim(simd_float3 x, simd_float3 y);
/*! @abstract Do not call this function; instead use `fdim` in C and
 *  Objective-C, and `simd::fdim` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_fdim(simd_float4 x, simd_float4 y);
/*! @abstract Do not call this function; instead use `fdim` in C and
 *  Objective-C, and `simd::fdim` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_fdim(simd_float8 x, simd_float8 y);
/*! @abstract Do not call this function; instead use `fdim` in C and
 *  Objective-C, and `simd::fdim` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_fdim(simd_float16 x, simd_float16 y);
/*! @abstract Do not call this function; instead use `fdim` in C and
 *  Objective-C, and `simd::fdim` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_fdim(simd_double2 x, simd_double2 y);
/*! @abstract Do not call this function; instead use `fdim` in C and
 *  Objective-C, and `simd::fdim` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_fdim(simd_double3 x, simd_double3 y);
/*! @abstract Do not call this function; instead use `fdim` in C and
 *  Objective-C, and `simd::fdim` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_fdim(simd_double4 x, simd_double4 y);
/*! @abstract Do not call this function; instead use `fdim` in C and
 *  Objective-C, and `simd::fdim` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_fdim(simd_double8 x, simd_double8 y);

/*! @abstract Do not call this function; instead use `fmax` in C and
 *  Objective-C, and `simd::fmax` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_fmax(simd_float2 x, simd_float2 y);
/*! @abstract Do not call this function; instead use `fmax` in C and
 *  Objective-C, and `simd::fmax` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_fmax(simd_float3 x, simd_float3 y);
/*! @abstract Do not call this function; instead use `fmax` in C and
 *  Objective-C, and `simd::fmax` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_fmax(simd_float4 x, simd_float4 y);
/*! @abstract Do not call this function; instead use `fmax` in C and
 *  Objective-C, and `simd::fmax` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_fmax(simd_float8 x, simd_float8 y);
/*! @abstract Do not call this function; instead use `fmax` in C and
 *  Objective-C, and `simd::fmax` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_fmax(simd_float16 x, simd_float16 y);
/*! @abstract Do not call this function; instead use `fmax` in C and
 *  Objective-C, and `simd::fmax` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_fmax(simd_double2 x, simd_double2 y);
/*! @abstract Do not call this function; instead use `fmax` in C and
 *  Objective-C, and `simd::fmax` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_fmax(simd_double3 x, simd_double3 y);
/*! @abstract Do not call this function; instead use `fmax` in C and
 *  Objective-C, and `simd::fmax` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_fmax(simd_double4 x, simd_double4 y);
/*! @abstract Do not call this function; instead use `fmax` in C and
 *  Objective-C, and `simd::fmax` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_fmax(simd_double8 x, simd_double8 y);

/*! @abstract Do not call this function; instead use `fmin` in C and
 *  Objective-C, and `simd::fmin` in C++.                                     */
static inline SIMD_CFUNC simd_float2 __tg_fmin(simd_float2 x, simd_float2 y);
/*! @abstract Do not call this function; instead use `fmin` in C and
 *  Objective-C, and `simd::fmin` in C++.                                     */
static inline SIMD_CFUNC simd_float3 __tg_fmin(simd_float3 x, simd_float3 y);
/*! @abstract Do not call this function; instead use `fmin` in C and
 *  Objective-C, and `simd::fmin` in C++.                                     */
static inline SIMD_CFUNC simd_float4 __tg_fmin(simd_float4 x, simd_float4 y);
/*! @abstract Do not call this function; instead use `fmin` in C and
 *  Objective-C, and `simd::fmin` in C++.                                     */
static inline SIMD_CFUNC simd_float8 __tg_fmin(simd_float8 x, simd_float8 y);
/*! @abstract Do not call this function; instead use `fmin` in C and
 *  Objective-C, and `simd::fmin` in C++.                                     */
static inline SIMD_CFUNC simd_float16 __tg_fmin(simd_float16 x, simd_float16 y);
/*! @abstract Do not call this function; instead use `fmin` in C and
 *  Objective-C, and `simd::fmin` in C++.                                     */
static inline SIMD_CFUNC simd_double2 __tg_fmin(simd_double2 x, simd_double2 y);
/*! @abstract Do not call this function; instead use `fmin` in C and
 *  Objective-C, and `simd::fmin` in C++.                                     */
static inline SIMD_CFUNC simd_double3 __tg_fmin(simd_double3 x, simd_double3 y);
/*! @abstract Do not call this function; instead use `fmin` in C and
 *  Objective-C, and `simd::fmin` in C++.                                     */
static inline SIMD_CFUNC simd_double4 __tg_fmin(simd_double4 x, simd_double4 y);
/*! @abstract Do not call this function; instead use `fmin` in C and
 *  Objective-C, and `simd::fmin` in C++.                                     */
static inline SIMD_CFUNC simd_double8 __tg_fmin(simd_double8 x, simd_double8 y);


/*! @abstract Do not call this function; instead use `fma` in C and Objective-C,
 *  and `simd::fma` in C++.                                                   */
static inline SIMD_CFUNC simd_float2 __tg_fma(simd_float2 x, simd_float2 y, simd_float2 z);
/*! @abstract Do not call this function; instead use `fma` in C and Objective-C,
 *  and `simd::fma` in C++.                                                   */
static inline SIMD_CFUNC simd_float3 __tg_fma(simd_float3 x, simd_float3 y, simd_float3 z);
/*! @abstract Do not call this function; instead use `fma` in C and Objective-C,
 *  and `simd::fma` in C++.                                                   */
static inline SIMD_CFUNC simd_float4 __tg_fma(simd_float4 x, simd_float4 y, simd_float4 z);
/*! @abstract Do not call this function; instead use `fma` in C and Objective-C,
 *  and `simd::fma` in C++.                                                   */
static inline SIMD_CFUNC simd_float8 __tg_fma(simd_float8 x, simd_float8 y, simd_float8 z);
/*! @abstract Do not call this function; instead use `fma` in C and Objective-C,
 *  and `simd::fma` in C++.                                                   */
static inline SIMD_CFUNC simd_float16 __tg_fma(simd_float16 x, simd_float16 y, simd_float16 z);
/*! @abstract Do not call this function; instead use `fma` in C and Objective-C,
 *  and `simd::fma` in C++.                                                   */
static inline SIMD_CFUNC simd_double2 __tg_fma(simd_double2 x, simd_double2 y, simd_double2 z);
/*! @abstract Do not call this function; instead use `fma` in C and Objective-C,
 *  and `simd::fma` in C++.                                                   */
static inline SIMD_CFUNC simd_double3 __tg_fma(simd_double3 x, simd_double3 y, simd_double3 z);
/*! @abstract Do not call this function; instead use `fma` in C and Objective-C,
 *  and `simd::fma` in C++.                                                   */
static inline SIMD_CFUNC simd_double4 __tg_fma(simd_double4 x, simd_double4 y, simd_double4 z);
/*! @abstract Do not call this function; instead use `fma` in C and Objective-C,
 *  and `simd::fma` in C++.                                                   */
static inline SIMD_CFUNC simd_double8 __tg_fma(simd_double8 x, simd_double8 y, simd_double8 z);
    
/*! @abstract Computes accum + x*y by the most efficient means available;
 *  either a fused multiply add or separate multiply and add instructions.    */
static inline SIMD_CFUNC float simd_muladd(float x, float y, float z);
/*! @abstract Computes accum + x*y by the most efficient means available;
 *  either a fused multiply add or separate multiply and add instructions.    */
static inline SIMD_CFUNC simd_float2 simd_muladd(simd_float2 x, simd_float2 y, simd_float2 z);
/*! @abstract Computes accum + x*y by the most efficient means available;
 *  either a fused multiply add or separate multiply and add instructions.    */
static inline SIMD_CFUNC simd_float3 simd_muladd(simd_float3 x, simd_float3 y, simd_float3 z);
/*! @abstract Computes accum + x*y by the most efficient means available;
 *  either a fused multiply add or separate multiply and add instructions.    */
static inline SIMD_CFUNC simd_float4 simd_muladd(simd_float4 x, simd_float4 y, simd_float4 z);
/*! @abstract Computes accum + x*y by the most efficient means available;
 *  either a fused multiply add or separate multiply and add instructions.    */
static inline SIMD_CFUNC simd_float8 simd_muladd(simd_float8 x, simd_float8 y, simd_float8 z);
/*! @abstract Computes accum + x*y by the most efficient means available;
 *  either a fused multiply add or separate multiply and add instructions.    */
static inline SIMD_CFUNC simd_float16 simd_muladd(simd_float16 x, simd_float16 y, simd_float16 z);
/*! @abstract Computes accum + x*y by the most efficient means available;
 *  either a fused multiply add or separate multiply and add instructions.    */
static inline SIMD_CFUNC double simd_muladd(double x, double y, double z);
/*! @abstract Computes accum + x*y by the most efficient means available;
 *  either a fused multiply add or separate multiply and add instructions.    */
static inline SIMD_CFUNC simd_double2 simd_muladd(simd_double2 x, simd_double2 y, simd_double2 z);
/*! @abstract Computes accum + x*y by the most efficient means available;
 *  either a fused multiply add or separate multiply and add instructions.    */
static inline SIMD_CFUNC simd_double3 simd_muladd(simd_double3 x, simd_double3 y, simd_double3 z);
/*! @abstract Computes accum + x*y by the most efficient means available;
 *  either a fused multiply add or separate multiply and add instructions.    */
static inline SIMD_CFUNC simd_double4 simd_muladd(simd_double4 x, simd_double4 y, simd_double4 z);
/*! @abstract Computes accum + x*y by the most efficient means available;
 *  either a fused multiply add or separate multiply and add instructions.    */
static inline SIMD_CFUNC simd_double8 simd_muladd(simd_double8 x, simd_double8 y, simd_double8 z);
    
#ifdef __cplusplus
} /* extern "C" */

#include <cmath>
/*! @abstract Do not call this function directly; use simd::acos instead.     */
static SIMD_CPPFUNC float __tg_acos(float x) { return ::acos(x); }
/*! @abstract Do not call this function directly; use simd::acos instead.     */
static SIMD_CPPFUNC double __tg_acos(double x) { return ::acos(x); }
/*! @abstract Do not call this function directly; use simd::asin instead.     */
static SIMD_CPPFUNC float __tg_asin(float x) { return ::asin(x); }
/*! @abstract Do not call this function directly; use simd::asin instead.     */
static SIMD_CPPFUNC double __tg_asin(double x) { return ::asin(x); }
/*! @abstract Do not call this function directly; use simd::atan instead.     */
static SIMD_CPPFUNC float __tg_atan(float x) { return ::atan(x); }
/*! @abstract Do not call this function directly; use simd::atan instead.     */
static SIMD_CPPFUNC double __tg_atan(double x) { return ::atan(x); }
/*! @abstract Do not call this function directly; use simd::cos instead.      */
static SIMD_CPPFUNC float __tg_cos(float x) { return ::cos(x); }
/*! @abstract Do not call this function directly; use simd::cos instead.      */
static SIMD_CPPFUNC double __tg_cos(double x) { return ::cos(x); }
/*! @abstract Do not call this function directly; use simd::sin instead.      */
static SIMD_CPPFUNC float __tg_sin(float x) { return ::sin(x); }
/*! @abstract Do not call this function directly; use simd::sin instead.      */
static SIMD_CPPFUNC double __tg_sin(double x) { return ::sin(x); }
/*! @abstract Do not call this function directly; use simd::tan instead.      */
static SIMD_CPPFUNC float __tg_tan(float x) { return ::tan(x); }
/*! @abstract Do not call this function directly; use simd::tan instead.      */
static SIMD_CPPFUNC double __tg_tan(double x) { return ::tan(x); }
/*! @abstract Do not call this function directly; use simd::cospi instead.    */
static SIMD_CPPFUNC float __tg_cospi(float x) { return ::__cospi(x); }
/*! @abstract Do not call this function directly; use simd::cospi instead.    */
static SIMD_CPPFUNC double __tg_cospi(double x) { return ::__cospi(x); }
/*! @abstract Do not call this function directly; use simd::sinpi instead.    */
static SIMD_CPPFUNC float __tg_sinpi(float x) { return ::__sinpi(x); }
/*! @abstract Do not call this function directly; use simd::sinpi instead.    */
static SIMD_CPPFUNC double __tg_sinpi(double x) { return ::__sinpi(x); }
/*! @abstract Do not call this function directly; use simd::tanpi instead.    */
static SIMD_CPPFUNC float __tg_tanpi(float x) { return ::__tanpi(x); }
/*! @abstract Do not call this function directly; use simd::tanpi instead.    */
static SIMD_CPPFUNC double __tg_tanpi(double x) { return ::__tanpi(x); }
/*! @abstract Do not call this function directly; use simd::acosh instead.    */
static SIMD_CPPFUNC float __tg_acosh(float x) { return ::acosh(x); }
/*! @abstract Do not call this function directly; use simd::acosh instead.    */
static SIMD_CPPFUNC double __tg_acosh(double x) { return ::acosh(x); }
/*! @abstract Do not call this function directly; use simd::asinh instead.    */
static SIMD_CPPFUNC float __tg_asinh(float x) { return ::asinh(x); }
/*! @abstract Do not call this function directly; use simd::asinh instead.    */
static SIMD_CPPFUNC double __tg_asinh(double x) { return ::asinh(x); }
/*! @abstract Do not call this function directly; use simd::atanh instead.    */
static SIMD_CPPFUNC float __tg_atanh(float x) { return ::atanh(x); }
/*! @abstract Do not call this function directly; use simd::atanh instead.    */
static SIMD_CPPFUNC double __tg_atanh(double x) { return ::atanh(x); }
/*! @abstract Do not call this function directly; use simd::cosh instead.     */
static SIMD_CPPFUNC float __tg_cosh(float x) { return ::cosh(x); }
/*! @abstract Do not call this function directly; use simd::cosh instead.     */
static SIMD_CPPFUNC double __tg_cosh(double x) { return ::cosh(x); }
/*! @abstract Do not call this function directly; use simd::sinh instead.     */
static SIMD_CPPFUNC float __tg_sinh(float x) { return ::sinh(x); }
/*! @abstract Do not call this function directly; use simd::sinh instead.     */
static SIMD_CPPFUNC double __tg_sinh(double x) { return ::sinh(x); }
/*! @abstract Do not call this function directly; use simd::tanh instead.     */
static SIMD_CPPFUNC float __tg_tanh(float x) { return ::tanh(x); }
/*! @abstract Do not call this function directly; use simd::tanh instead.     */
static SIMD_CPPFUNC double __tg_tanh(double x) { return ::tanh(x); }
/*! @abstract Do not call this function directly; use simd::exp instead.      */
static SIMD_CPPFUNC float __tg_exp(float x) { return ::exp(x); }
/*! @abstract Do not call this function directly; use simd::exp instead.      */
static SIMD_CPPFUNC double __tg_exp(double x) { return ::exp(x); }
/*! @abstract Do not call this function directly; use simd::exp2 instead.     */
static SIMD_CPPFUNC float __tg_exp2(float x) { return ::exp2(x); }
/*! @abstract Do not call this function directly; use simd::exp2 instead.     */
static SIMD_CPPFUNC double __tg_exp2(double x) { return ::exp2(x); }
/*! @abstract Do not call this function directly; use simd::exp10 instead.    */
static SIMD_CPPFUNC float __tg_exp10(float x) { return ::__exp10(x); }
/*! @abstract Do not call this function directly; use simd::exp10 instead.    */
static SIMD_CPPFUNC double __tg_exp10(double x) { return ::__exp10(x); }
/*! @abstract Do not call this function directly; use simd::expm1 instead.    */
static SIMD_CPPFUNC float __tg_expm1(float x) { return ::expm1(x); }
/*! @abstract Do not call this function directly; use simd::expm1 instead.    */
static SIMD_CPPFUNC double __tg_expm1(double x) { return ::expm1(x); }
/*! @abstract Do not call this function directly; use simd::log instead.      */
static SIMD_CPPFUNC float __tg_log(float x) { return ::log(x); }
/*! @abstract Do not call this function directly; use simd::log instead.      */
static SIMD_CPPFUNC double __tg_log(double x) { return ::log(x); }
/*! @abstract Do not call this function directly; use simd::log2 instead.     */
static SIMD_CPPFUNC float __tg_log2(float x) { return ::log2(x); }
/*! @abstract Do not call this function directly; use simd::log2 instead.     */
static SIMD_CPPFUNC double __tg_log2(double x) { return ::log2(x); }
/*! @abstract Do not call this function directly; use simd::log10 instead.    */
static SIMD_CPPFUNC float __tg_log10(float x) { return ::log10(x); }
/*! @abstract Do not call this function directly; use simd::log10 instead.    */
static SIMD_CPPFUNC double __tg_log10(double x) { return ::log10(x); }
/*! @abstract Do not call this function directly; use simd::log1p instead.    */
static SIMD_CPPFUNC float __tg_log1p(float x) { return ::log1p(x); }
/*! @abstract Do not call this function directly; use simd::log1p instead.    */
static SIMD_CPPFUNC double __tg_log1p(double x) { return ::log1p(x); }
/*! @abstract Do not call this function directly; use simd::fabs instead.     */
static SIMD_CPPFUNC float __tg_fabs(float x) { return ::fabs(x); }
/*! @abstract Do not call this function directly; use simd::fabs instead.     */
static SIMD_CPPFUNC double __tg_fabs(double x) { return ::fabs(x); }
/*! @abstract Do not call this function directly; use simd::cbrt instead.     */
static SIMD_CPPFUNC float __tg_cbrt(float x) { return ::cbrt(x); }
/*! @abstract Do not call this function directly; use simd::cbrt instead.     */
static SIMD_CPPFUNC double __tg_cbrt(double x) { return ::cbrt(x); }
/*! @abstract Do not call this function directly; use simd::sqrt instead.     */
static SIMD_CPPFUNC float __tg_sqrt(float x) { return ::sqrt(x); }
/*! @abstract Do not call this function directly; use simd::sqrt instead.     */
static SIMD_CPPFUNC double __tg_sqrt(double x) { return ::sqrt(x); }
/*! @abstract Do not call this function directly; use simd::erf instead.      */
static SIMD_CPPFUNC float __tg_erf(float x) { return ::erf(x); }
/*! @abstract Do not call this function directly; use simd::erf instead.      */
static SIMD_CPPFUNC double __tg_erf(double x) { return ::erf(x); }
/*! @abstract Do not call this function directly; use simd::erfc instead.     */
static SIMD_CPPFUNC float __tg_erfc(float x) { return ::erfc(x); }
/*! @abstract Do not call this function directly; use simd::erfc instead.     */
static SIMD_CPPFUNC double __tg_erfc(double x) { return ::erfc(x); }
/*! @abstract Do not call this function directly; use simd::tgamma instead.   */
static SIMD_CPPFUNC float __tg_tgamma(float x) { return ::tgamma(x); }
/*! @abstract Do not call this function directly; use simd::tgamma instead.   */
static SIMD_CPPFUNC double __tg_tgamma(double x) { return ::tgamma(x); }
/*! @abstract Do not call this function directly; use simd::ceil instead.     */
static SIMD_CPPFUNC float __tg_ceil(float x) { return ::ceil(x); }
/*! @abstract Do not call this function directly; use simd::ceil instead.     */
static SIMD_CPPFUNC double __tg_ceil(double x) { return ::ceil(x); }
/*! @abstract Do not call this function directly; use simd::floor instead.    */
static SIMD_CPPFUNC float __tg_floor(float x) { return ::floor(x); }
/*! @abstract Do not call this function directly; use simd::floor instead.    */
static SIMD_CPPFUNC double __tg_floor(double x) { return ::floor(x); }
/*! @abstract Do not call this function directly; use simd::rint instead.     */
static SIMD_CPPFUNC float __tg_rint(float x) { return ::rint(x); }
/*! @abstract Do not call this function directly; use simd::rint instead.     */
static SIMD_CPPFUNC double __tg_rint(double x) { return ::rint(x); }
/*! @abstract Do not call this function directly; use simd::round instead.    */
static SIMD_CPPFUNC float __tg_round(float x) { return ::round(x); }
/*! @abstract Do not call this function directly; use simd::round instead.    */
static SIMD_CPPFUNC double __tg_round(double x) { return ::round(x); }
/*! @abstract Do not call this function directly; use simd::trunc instead.    */
static SIMD_CPPFUNC float __tg_trunc(float x) { return ::trunc(x); }
/*! @abstract Do not call this function directly; use simd::trunc instead.    */
static SIMD_CPPFUNC double __tg_trunc(double x) { return ::trunc(x); }
/*! @abstract Do not call this function directly; use simd::atan2 instead.    */
static SIMD_CPPFUNC float __tg_atan2(float x, float y) { return ::atan2(x, y); }
/*! @abstract Do not call this function directly; use simd::atan2 instead.    */
static SIMD_CPPFUNC double __tg_atan2(double x, float y) { return ::atan2(x, y); }
/*! @abstract Do not call this function directly; use simd::hypot instead.    */
static SIMD_CPPFUNC float __tg_hypot(float x, float y) { return ::hypot(x, y); }
/*! @abstract Do not call this function directly; use simd::hypot instead.    */
static SIMD_CPPFUNC double __tg_hypot(double x, float y) { return ::hypot(x, y); }
/*! @abstract Do not call this function directly; use simd::pow instead.      */
static SIMD_CPPFUNC float __tg_pow(float x, float y) { return ::pow(x, y); }
/*! @abstract Do not call this function directly; use simd::pow instead.      */
static SIMD_CPPFUNC double __tg_pow(double x, float y) { return ::pow(x, y); }
/*! @abstract Do not call this function directly; use simd::fmod instead.     */
static SIMD_CPPFUNC float __tg_fmod(float x, float y) { return ::fmod(x, y); }
/*! @abstract Do not call this function directly; use simd::fmod instead.     */
static SIMD_CPPFUNC double __tg_fmod(double x, float y) { return ::fmod(x, y); }
/*! @abstract Do not call this function directly; use simd::remainder
 *  instead.                                                                  */
static SIMD_CPPFUNC float __tg_remainder(float x, float y) { return ::remainder(x, y); }
/*! @abstract Do not call this function directly; use simd::remainder
 *  instead.                                                                  */
static SIMD_CPPFUNC double __tg_remainder(double x, float y) { return ::remainder(x, y); }
/*! @abstract Do not call this function directly; use simd::copysign
 *  instead.                                                                  */
static SIMD_CPPFUNC float __tg_copysign(float x, float y) { return ::copysign(x, y); }
/*! @abstract Do not call this function directly; use simd::copysign
 *  instead.                                                                  */
static SIMD_CPPFUNC double __tg_copysign(double x, float y) { return ::copysign(x, y); }
/*! @abstract Do not call this function directly; use simd::nextafter
 *  instead.                                                                  */
static SIMD_CPPFUNC float __tg_nextafter(float x, float y) { return ::nextafter(x, y); }
/*! @abstract Do not call this function directly; use simd::nextafter
 *  instead.                                                                  */
static SIMD_CPPFUNC double __tg_nextafter(double x, float y) { return ::nextafter(x, y); }
/*! @abstract Do not call this function directly; use simd::fdim instead.     */
static SIMD_CPPFUNC float __tg_fdim(float x, float y) { return ::fdim(x, y); }
/*! @abstract Do not call this function directly; use simd::fdim instead.     */
static SIMD_CPPFUNC double __tg_fdim(double x, float y) { return ::fdim(x, y); }
/*! @abstract Do not call this function directly; use simd::fmax instead.     */
static SIMD_CPPFUNC float __tg_fmax(float x, float y) { return ::fmax(x, y); }
/*! @abstract Do not call this function directly; use simd::fmax instead.     */
static SIMD_CPPFUNC double __tg_fmax(double x, float y) { return ::fmax(x, y); }
/*! @abstract Do not call this function directly; use simd::fmin instead.     */
static SIMD_CPPFUNC float __tg_fmin(float x, float y) { return ::fmin(x, y); }
/*! @abstract Do not call this function directly; use simd::fmin instead.     */
static SIMD_CPPFUNC double __tg_fmin(double x, float y) { return ::fmin(x, y); }
/*! @abstract Do not call this function directly; use simd::fma instead.      */
static SIMD_CPPFUNC float __tg_fma(float x, float y, float z) { return ::fma(x, y, z); }
/*! @abstract Do not call this function directly; use simd::fma instead.      */
static SIMD_CPPFUNC double __tg_fma(double x, double y, double z) { return ::fma(x, y, z); }
  
namespace simd {
/*! @abstract Generalizes the <cmath> function acos to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN acos(fptypeN x) { return ::__tg_acos(x); }
  
/*! @abstract Generalizes the <cmath> function asin to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN asin(fptypeN x) { return ::__tg_asin(x); }
  
/*! @abstract Generalizes the <cmath> function atan to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN atan(fptypeN x) { return ::__tg_atan(x); }
  
/*! @abstract Generalizes the <cmath> function cos to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN cos(fptypeN x) { return ::__tg_cos(x); }
  
/*! @abstract Generalizes the <cmath> function sin to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN sin(fptypeN x) { return ::__tg_sin(x); }
  
/*! @abstract Generalizes the <cmath> function tan to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN tan(fptypeN x) { return ::__tg_tan(x); }
  
#if SIMD_LIBRARY_VERSION >= 1
/*! @abstract Generalizes the <cmath> function cospi to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN cospi(fptypeN x) { return ::__tg_cospi(x); }
#endif
  
#if SIMD_LIBRARY_VERSION >= 1
/*! @abstract Generalizes the <cmath> function sinpi to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN sinpi(fptypeN x) { return ::__tg_sinpi(x); }
#endif
  
#if SIMD_LIBRARY_VERSION >= 1
/*! @abstract Generalizes the <cmath> function tanpi to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN tanpi(fptypeN x) { return ::__tg_tanpi(x); }
#endif
  
/*! @abstract Generalizes the <cmath> function acosh to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN acosh(fptypeN x) { return ::__tg_acosh(x); }
  
/*! @abstract Generalizes the <cmath> function asinh to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN asinh(fptypeN x) { return ::__tg_asinh(x); }
  
/*! @abstract Generalizes the <cmath> function atanh to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN atanh(fptypeN x) { return ::__tg_atanh(x); }
  
/*! @abstract Generalizes the <cmath> function cosh to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN cosh(fptypeN x) { return ::__tg_cosh(x); }
  
/*! @abstract Generalizes the <cmath> function sinh to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN sinh(fptypeN x) { return ::__tg_sinh(x); }
  
/*! @abstract Generalizes the <cmath> function tanh to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN tanh(fptypeN x) { return ::__tg_tanh(x); }
  
/*! @abstract Generalizes the <cmath> function exp to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN exp(fptypeN x) { return ::__tg_exp(x); }
  
/*! @abstract Generalizes the <cmath> function exp2 to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN exp2(fptypeN x) { return ::__tg_exp2(x); }
  
#if SIMD_LIBRARY_VERSION >= 1
/*! @abstract Generalizes the <cmath> function exp10 to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN exp10(fptypeN x) { return ::__tg_exp10(x); }
#endif
  
/*! @abstract Generalizes the <cmath> function expm1 to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN expm1(fptypeN x) { return ::__tg_expm1(x); }
  
/*! @abstract Generalizes the <cmath> function log to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN log(fptypeN x) { return ::__tg_log(x); }
  
/*! @abstract Generalizes the <cmath> function log2 to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN log2(fptypeN x) { return ::__tg_log2(x); }
  
/*! @abstract Generalizes the <cmath> function log10 to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN log10(fptypeN x) { return ::__tg_log10(x); }
  
/*! @abstract Generalizes the <cmath> function log1p to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN log1p(fptypeN x) { return ::__tg_log1p(x); }
  
/*! @abstract Generalizes the <cmath> function fabs to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN fabs(fptypeN x) { return ::__tg_fabs(x); }
  
/*! @abstract Generalizes the <cmath> function cbrt to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN cbrt(fptypeN x) { return ::__tg_cbrt(x); }
  
/*! @abstract Generalizes the <cmath> function sqrt to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN sqrt(fptypeN x) { return ::__tg_sqrt(x); }
  
/*! @abstract Generalizes the <cmath> function erf to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN erf(fptypeN x) { return ::__tg_erf(x); }
  
/*! @abstract Generalizes the <cmath> function erfc to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN erfc(fptypeN x) { return ::__tg_erfc(x); }
  
/*! @abstract Generalizes the <cmath> function tgamma to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN tgamma(fptypeN x) { return ::__tg_tgamma(x); }
  
/*! @abstract Generalizes the <cmath> function ceil to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN ceil(fptypeN x) { return ::__tg_ceil(x); }
  
/*! @abstract Generalizes the <cmath> function floor to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN floor(fptypeN x) { return ::__tg_floor(x); }
  
/*! @abstract Generalizes the <cmath> function rint to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN rint(fptypeN x) { return ::__tg_rint(x); }
  
/*! @abstract Generalizes the <cmath> function round to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN round(fptypeN x) { return ::__tg_round(x); }
  
/*! @abstract Generalizes the <cmath> function trunc to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN trunc(fptypeN x) { return ::__tg_trunc(x); }
  
/*! @abstract Generalizes the <cmath> function atan2 to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN atan2(fptypeN y, fptypeN x) { return ::__tg_atan2(y, x); }
    
/*! @abstract Generalizes the <cmath> function hypot to operate on vectors
 *  of floats and doubles.                                                    */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN hypot(fptypeN x, fptypeN y) { return ::__tg_hypot(x, y); }
    
/*! @abstract Generalizes the <cmath> function pow to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN pow(fptypeN x, fptypeN y) { return ::__tg_pow(x, y); }
    
/*! @abstract Generalizes the <cmath> function fmod to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN fmod(fptypeN x, fptypeN y) { return ::__tg_fmod(x, y); }
    
/*! @abstract Generalizes the <cmath> function remainder to operate on
 *  vectors of floats and doubles.                                            */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN remainder(fptypeN x, fptypeN y) { return ::__tg_remainder(x, y); }
    
/*! @abstract Generalizes the <cmath> function copysign to operate on
 *  vectors of floats and doubles.                                            */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN copysign(fptypeN x, fptypeN y) { return ::__tg_copysign(x, y); }
    
/*! @abstract Generalizes the <cmath> function nextafter to operate on
 *  vectors of floats and doubles.                                            */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN nextafter(fptypeN x, fptypeN y) { return ::__tg_nextafter(x, y); }
    
/*! @abstract Generalizes the <cmath> function fdim to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN fdim(fptypeN x, fptypeN y) { return ::__tg_fdim(x, y); }
    
/*! @abstract Generalizes the <cmath> function fmax to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN fmax(fptypeN x, fptypeN y) { return ::__tg_fmax(x, y); }
    
/*! @abstract Generalizes the <cmath> function fmin to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN fmin(fptypeN x, fptypeN y) { return ::__tg_fmin(x, y); }
    
/*! @abstract Generalizes the <cmath> function fma to operate on vectors of
 *  floats and doubles.                                                       */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN fma(fptypeN x, fptypeN y, fptypeN z) { return ::__tg_fma(x, y, z); }
        
/*! @abstract Computes x*y + z by the most efficient means available; either
 *  a fused multiply add or separate multiply and add.                        */
  template <typename fptypeN>
  static SIMD_CPPFUNC fptypeN muladd(fptypeN x, fptypeN y, fptypeN z) { return ::simd_muladd(x, y, z); }
};

extern "C" {
#else
#include <tgmath.h>
/* C and Objective-C, we need some infrastructure to piggyback on tgmath.h    */
static SIMD_OVERLOAD simd_float2 __tg_promote(simd_float2);
static SIMD_OVERLOAD simd_float3 __tg_promote(simd_float3);
static SIMD_OVERLOAD simd_float4 __tg_promote(simd_float4);
static SIMD_OVERLOAD simd_float8 __tg_promote(simd_float8);
static SIMD_OVERLOAD simd_float16 __tg_promote(simd_float16);
static SIMD_OVERLOAD simd_double2 __tg_promote(simd_double2);
static SIMD_OVERLOAD simd_double3 __tg_promote(simd_double3);
static SIMD_OVERLOAD simd_double4 __tg_promote(simd_double4);
static SIMD_OVERLOAD simd_double8 __tg_promote(simd_double8);

/*  Apple extensions to <math.h>, added in macOS 10.9 and iOS 7.0             */
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_10_9   || \
    __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0 || \
    __DRIVERKIT_VERSION_MIN_REQUIRED >= __DRIVERKIT_19_0
static inline SIMD_CFUNC float __tg_cospi(float x) { return __cospif(x); }
static inline SIMD_CFUNC double __tg_cospi(double x) { return __cospi(x); }
#undef cospi
/*! @abstract `cospi(x)` computes `cos(pi * x)` without intermediate rounding.
 *
 *  @discussion Both faster and more accurate than multiplying by `pi` and then
 *  calling `cos`. Defined for `float` and `double` as well as vectors of
 *  floats and doubles as provided by `<simd/simd.h>`.                        */
#define cospi(__x) __tg_cospi(__tg_promote1((__x))(__x))

static inline SIMD_CFUNC float __tg_sinpi(float x) { return __sinpif(x); }
static inline SIMD_CFUNC double __tg_sinpi(double x) { return __sinpi(x); }
#undef sinpi
/*! @abstract `sinpi(x)` computes `sin(pi * x)` without intermediate rounding.
 *
 *  @discussion Both faster and more accurate than multiplying by `pi` and then
 *  calling `sin`. Defined for `float` and `double` as well as vectors
 *  of floats and doubles as provided by `<simd/simd.h>`.                     */
#define sinpi(__x) __tg_sinpi(__tg_promote1((__x))(__x))

static inline SIMD_CFUNC float __tg_tanpi(float x) { return __tanpif(x); }
static inline SIMD_CFUNC double __tg_tanpi(double x) { return __tanpi(x); }
#undef tanpi
/*! @abstract `tanpi(x)` computes `tan(pi * x)` without intermediate rounding.
 *
 *  @discussion Both faster and more accurate than multiplying by `pi` and then
 *  calling `tan`. Defined for `float` and `double` as well as vectors of
 *  floats and doubles as provided by `<simd/simd.h>`.                        */
#define tanpi(__x) __tg_tanpi(__tg_promote1((__x))(__x))

static inline SIMD_CFUNC float __tg_exp10(float x) { return __exp10f(x); }
static inline SIMD_CFUNC double __tg_exp10(double x) { return __exp10(x); }
#undef exp10
/*! @abstract `exp10(x)` computes `10**x` more efficiently and accurately
 *  than `pow(10, x)`.
 *
 *  @discussion Defined for `float` and `double` as well as vectors of floats
 *  and doubles as provided by `<simd/simd.h>`.                               */
#define exp10(__x) __tg_exp10(__tg_promote1((__x))(__x))
#endif

  
#endif /* !__cplusplus */
  
#pragma mark - fabs implementation
static inline SIMD_CFUNC simd_float2 __tg_fabs(simd_float2 x) { return simd_bitselect(0.0, x, 0x7fffffff); }
static inline SIMD_CFUNC simd_float3 __tg_fabs(simd_float3 x) { return simd_bitselect(0.0, x, 0x7fffffff); }
static inline SIMD_CFUNC simd_float4 __tg_fabs(simd_float4 x) { return simd_bitselect(0.0, x, 0x7fffffff); }
static inline SIMD_CFUNC simd_float8 __tg_fabs(simd_float8 x) { return simd_bitselect(0.0, x, 0x7fffffff); }
static inline SIMD_CFUNC simd_float16 __tg_fabs(simd_float16 x) { return simd_bitselect(0.0, x, 0x7fffffff); }
static inline SIMD_CFUNC simd_double2 __tg_fabs(simd_double2 x) { return simd_bitselect(0.0, x, 0x7fffffffffffffffL); }
static inline SIMD_CFUNC simd_double3 __tg_fabs(simd_double3 x) { return simd_bitselect(0.0, x, 0x7fffffffffffffffL); }
static inline SIMD_CFUNC simd_double4 __tg_fabs(simd_double4 x) { return simd_bitselect(0.0, x, 0x7fffffffffffffffL); }
static inline SIMD_CFUNC simd_double8 __tg_fabs(simd_double8 x) { return simd_bitselect(0.0, x, 0x7fffffffffffffffL); }
  
#pragma mark - fmin, fmax implementation
static SIMD_CFUNC simd_float2 __tg_fmin(simd_float2 x, simd_float2 y) {
#if defined __SSE2__
  return simd_make_float2(__tg_fmin(simd_make_float4_undef(x), simd_make_float4_undef(y)));
#elif defined __arm64__
  return vminnm_f32(x, y);
#elif defined __arm__ && __FINITE_MATH_ONLY__
  return vmin_f32(x, y);
#else
  return simd_bitselect(y, x, (x <= y) | (y != y));
#endif
}
  
static SIMD_CFUNC simd_float3 __tg_fmin(simd_float3 x, simd_float3 y) {
  return simd_make_float3(__tg_fmin(simd_make_float4_undef(x), simd_make_float4_undef(y)));
}
  
static SIMD_CFUNC simd_float4 __tg_fmin(simd_float4 x, simd_float4 y) {
#if defined __AVX512DQ__ && defined __AVX512VL__ && !__FINITE_MATH_ONLY__
  return _mm_range_ps(x, y, 4);
#elif defined __SSE2__ && __FINITE_MATH_ONLY__
  return _mm_min_ps(x, y);
#elif defined __SSE2__
  return simd_bitselect(_mm_min_ps(x, y), x, y != y);
#elif defined __arm64__
  return vminnmq_f32(x, y);
#elif defined __arm__ && __FINITE_MATH_ONLY__
  return vminq_f32(x, y);
#else
  return simd_bitselect(y, x, (x <= y) | (y != y));
#endif
}
  
static SIMD_CFUNC simd_float8 __tg_fmin(simd_float8 x, simd_float8 y) {
#if defined __AVX512DQ__ && defined __AVX512VL__ && !__FINITE_MATH_ONLY__
  return _mm256_range_ps(x, y, 4);
#elif defined __AVX__ && __FINITE_MATH_ONLY__
  return _mm256_min_ps(x, y);
#elif defined __AVX__
  return simd_bitselect(_mm256_min_ps(x, y), x, y != y);
#else
  return simd_make_float8(__tg_fmin(x.lo, y.lo), __tg_fmin(x.hi, y.hi));
#endif
}
  
static SIMD_CFUNC simd_float16 __tg_fmin(simd_float16 x, simd_float16 y) {
#if defined __x86_64__ && defined __AVX512DQ__ && !__FINITE_MATH_ONLY__
  return _mm512_range_ps(x, y, 4);
#elif defined __x86_64__ && defined __AVX512F__ && __FINITE_MATH_ONLY__
  return _mm512_min_ps(x, y);
#elif defined __x86_64__ && defined __AVX512F__
  return simd_bitselect(_mm512_min_ps(x, y), x, y != y);
#else
  return simd_make_float16(__tg_fmin(x.lo, y.lo), __tg_fmin(x.hi, y.hi));
#endif
}
  
static SIMD_CFUNC simd_double2 __tg_fmin(simd_double2 x, simd_double2 y) {
#if defined __AVX512DQ__ && defined __AVX512VL__
  return _mm_range_pd(x, y, 4);
#elif defined __SSE2__ && __FINITE_MATH_ONLY__
  return _mm_min_pd(x, y);
#elif defined __SSE2__
  return simd_bitselect(_mm_min_pd(x, y), x, y != y);
#elif defined __arm64__
  return vminnmq_f64(x, y);
#else
  return simd_bitselect(y, x, (x <= y) | (y != y));
#endif
}
  
static SIMD_CFUNC simd_double3 __tg_fmin(simd_double3 x, simd_double3 y) {
  return simd_make_double3(__tg_fmin(simd_make_double4_undef(x), simd_make_double4_undef(y)));
}
  
static SIMD_CFUNC simd_double4 __tg_fmin(simd_double4 x, simd_double4 y) {
#if defined __AVX512DQ__ && defined __AVX512VL__
  return _mm256_range_pd(x, y, 4);
#elif defined __AVX__ && __FINITE_MATH_ONLY__
  return _mm256_min_pd(x, y);
#elif defined __AVX__
  return simd_bitselect(_mm256_min_pd(x, y), x, y != y);
#else
  return simd_make_double4(__tg_fmin(x.lo, y.lo), __tg_fmin(x.hi, y.hi));
#endif
}

static SIMD_CFUNC simd_double8 __tg_fmin(simd_double8 x, simd_double8 y) {
#if defined __x86_64__ && defined __AVX512DQ__
  return _mm512_range_pd(x, y, 4);
#elif defined __x86_64__ && defined __AVX512F__ && __FINITE_MATH_ONLY__
  return _mm512_min_pd(x, y);
#elif defined __x86_64__ && defined __AVX512F__
  return simd_bitselect(_mm512_min_pd(x, y), x, y != y);
#else
  return simd_make_double8(__tg_fmin(x.lo, y.lo), __tg_fmin(x.hi, y.hi));
#endif
}

static SIMD_CFUNC simd_float2 __tg_fmax(simd_float2 x, simd_float2 y) {
#if defined __SSE2__
  return simd_make_float2(__tg_fmax(simd_make_float4_undef(x), simd_make_float4_undef(y)));
#elif defined __arm64__
  return vmaxnm_f32(x, y);
#elif defined __arm__ && __FINITE_MATH_ONLY__
  return vmax_f32(x, y);
#else
  return simd_bitselect(y, x, (x >= y) | (y != y));
#endif
}
  
static SIMD_CFUNC simd_float3 __tg_fmax(simd_float3 x, simd_float3 y) {
  return simd_make_float3(__tg_fmax(simd_make_float4_undef(x), simd_make_float4_undef(y)));
}
  
static SIMD_CFUNC simd_float4 __tg_fmax(simd_float4 x, simd_float4 y) {
#if defined __AVX512DQ__ && defined __AVX512VL__ && !__FINITE_MATH_ONLY__
  return _mm_range_ps(x, y, 5);
#elif defined __SSE2__ && __FINITE_MATH_ONLY__
  return _mm_max_ps(x, y);
#elif defined __SSE2__
  return simd_bitselect(_mm_max_ps(x, y), x, y != y);
#elif defined __arm64__
  return vmaxnmq_f32(x, y);
#elif defined __arm__ && __FINITE_MATH_ONLY__
  return vmaxq_f32(x, y);
#else
  return simd_bitselect(y, x, (x >= y) | (y != y));
#endif
}
  
static SIMD_CFUNC simd_float8 __tg_fmax(simd_float8 x, simd_float8 y) {
#if defined __AVX512DQ__ && defined __AVX512VL__ && !__FINITE_MATH_ONLY__
  return _mm256_range_ps(x, y, 5);
#elif defined __AVX__ && __FINITE_MATH_ONLY__
  return _mm256_max_ps(x, y);
#elif defined __AVX__
  return simd_bitselect(_mm256_max_ps(x, y), x, y != y);
#else
  return simd_make_float8(__tg_fmax(x.lo, y.lo), __tg_fmax(x.hi, y.hi));
#endif
}
  
static SIMD_CFUNC simd_float16 __tg_fmax(simd_float16 x, simd_float16 y) {
#if defined __x86_64__ && defined __AVX512DQ__ && !__FINITE_MATH_ONLY__
  return _mm512_range_ps(x, y, 5);
#elif defined __x86_64__ && defined __AVX512F__ && __FINITE_MATH_ONLY__
  return _mm512_max_ps(x, y);
#elif defined __x86_64__ && defined __AVX512F__
  return simd_bitselect(_mm512_max_ps(x, y), x, y != y);
#else
  return simd_make_float16(__tg_fmax(x.lo, y.lo), __tg_fmax(x.hi, y.hi));
#endif
}
  
static SIMD_CFUNC simd_double2 __tg_fmax(simd_double2 x, simd_double2 y) {
#if defined __AVX512DQ__ && defined __AVX512VL__
  return _mm_range_pd(x, y, 5);
#elif defined __SSE2__ && __FINITE_MATH_ONLY__
  return _mm_max_pd(x, y);
#elif defined __SSE2__
  return simd_bitselect(_mm_max_pd(x, y), x, y != y);
#elif defined __arm64__
  return vmaxnmq_f64(x, y);
#else
  return simd_bitselect(y, x, (x >= y) | (y != y));
#endif
}
  
static SIMD_CFUNC simd_double3 __tg_fmax(simd_double3 x, simd_double3 y) {
  return simd_make_double3(__tg_fmax(simd_make_double4_undef(x), simd_make_double4_undef(y)));
}
  
static SIMD_CFUNC simd_double4 __tg_fmax(simd_double4 x, simd_double4 y) {
#if defined __AVX512DQ__ && defined __AVX512VL__
  return _mm256_range_pd(x, y, 5);
#elif defined __AVX__ && __FINITE_MATH_ONLY__
  return _mm256_max_pd(x, y);
#elif defined __AVX__
  return simd_bitselect(_mm256_max_pd(x, y), x, y != y);
#else
  return simd_make_double4(__tg_fmax(x.lo, y.lo), __tg_fmax(x.hi, y.hi));
#endif
}

static SIMD_CFUNC simd_double8 __tg_fmax(simd_double8 x, simd_double8 y) {
#if defined __x86_64__ && defined __AVX512DQ__
  return _mm512_range_pd(x, y, 5);
#elif defined __x86_64__ && defined __AVX512F__ && __FINITE_MATH_ONLY__
  return _mm512_max_pd(x, y);
#elif defined __x86_64__ && defined __AVX512F__
  return simd_bitselect(_mm512_max_pd(x, y), x, y != y);
#else
  return simd_make_double8(__tg_fmax(x.lo, y.lo), __tg_fmax(x.hi, y.hi));
#endif
}

#pragma mark - copysign implementation
static inline SIMD_CFUNC simd_float2 __tg_copysign(simd_float2 x, simd_float2 y) { return simd_bitselect(y, x, 0x7fffffff); }
static inline SIMD_CFUNC simd_float3 __tg_copysign(simd_float3 x, simd_float3 y) { return simd_bitselect(y, x, 0x7fffffff); }
static inline SIMD_CFUNC simd_float4 __tg_copysign(simd_float4 x, simd_float4 y) { return simd_bitselect(y, x, 0x7fffffff); }
static inline SIMD_CFUNC simd_float8 __tg_copysign(simd_float8 x, simd_float8 y) { return simd_bitselect(y, x, 0x7fffffff); }
static inline SIMD_CFUNC simd_float16 __tg_copysign(simd_float16 x, simd_float16 y) { return simd_bitselect(y, x, 0x7fffffff); }
static inline SIMD_CFUNC simd_double2 __tg_copysign(simd_double2 x, simd_double2 y) { return simd_bitselect(y, x, 0x7fffffffffffffffL); }
static inline SIMD_CFUNC simd_double3 __tg_copysign(simd_double3 x, simd_double3 y) { return simd_bitselect(y, x, 0x7fffffffffffffffL); }
static inline SIMD_CFUNC simd_double4 __tg_copysign(simd_double4 x, simd_double4 y) { return simd_bitselect(y, x, 0x7fffffffffffffffL); }
static inline SIMD_CFUNC simd_double8 __tg_copysign(simd_double8 x, simd_double8 y) { return simd_bitselect(y, x, 0x7fffffffffffffffL); }
  
#pragma mark - sqrt implementation
static SIMD_CFUNC simd_float2 __tg_sqrt(simd_float2 x) {
#if defined __SSE2__
  return simd_make_float2(__tg_sqrt(simd_make_float4_undef(x)));
#elif defined __arm64__
  return vsqrt_f32(x);
#else
  return simd_make_float2(sqrt(x.x), sqrt(x.y));
#endif
}

static SIMD_CFUNC simd_float3 __tg_sqrt(simd_float3 x) {
  return simd_make_float3(__tg_sqrt(simd_make_float4_undef(x)));
}

static SIMD_CFUNC simd_float4 __tg_sqrt(simd_float4 x) {
#if defined __SSE2__
  return _mm_sqrt_ps(x);
#elif defined __arm64__
  return vsqrtq_f32(x);
#else
  return simd_make_float4(__tg_sqrt(x.lo), __tg_sqrt(x.hi));
#endif
}

static SIMD_CFUNC simd_float8 __tg_sqrt(simd_float8 x) {
#if defined __AVX__
  return _mm256_sqrt_ps(x);
#else
  return simd_make_float8(__tg_sqrt(x.lo), __tg_sqrt(x.hi));
#endif
}
  
static SIMD_CFUNC simd_float16 __tg_sqrt(simd_float16 x) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_sqrt_ps(x);
#else
  return simd_make_float16(__tg_sqrt(x.lo), __tg_sqrt(x.hi));
#endif
}

static SIMD_CFUNC simd_double2 __tg_sqrt(simd_double2 x) {
#if defined __SSE2__
  return _mm_sqrt_pd(x);
#elif defined __arm64__
  return vsqrtq_f64(x);
#else
  return simd_make_double2(sqrt(x.x), sqrt(x.y));
#endif
}
  
static SIMD_CFUNC simd_double3 __tg_sqrt(simd_double3 x) {
  return simd_make_double3(__tg_sqrt(simd_make_double4_undef(x)));
}

static SIMD_CFUNC simd_double4 __tg_sqrt(simd_double4 x) {
#if defined __AVX__
  return _mm256_sqrt_pd(x);
#else
  return simd_make_double4(__tg_sqrt(x.lo), __tg_sqrt(x.hi));
#endif
}
  
static SIMD_CFUNC simd_double8 __tg_sqrt(simd_double8 x) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_sqrt_pd(x);
#else
  return simd_make_double8(__tg_sqrt(x.lo), __tg_sqrt(x.hi));
#endif
}
  
#pragma mark - ceil, floor, rint, trunc implementation
static SIMD_CFUNC simd_float2 __tg_ceil(simd_float2 x) {
#if defined __arm64__
  return vrndp_f32(x);
#else
  return simd_make_float2(__tg_ceil(simd_make_float4_undef(x)));
#endif
}
  
static SIMD_CFUNC simd_float3 __tg_ceil(simd_float3 x) {
  return simd_make_float3(__tg_ceil(simd_make_float4_undef(x)));
}
  
#if defined __arm__ && SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_ceil_f4(simd_float4 x);
#endif

static SIMD_CFUNC simd_float4 __tg_ceil(simd_float4 x) {
#if defined __SSE4_1__
  return _mm_round_ps(x, _MM_FROUND_TO_POS_INF | _MM_FROUND_NO_EXC);
#elif defined __arm64__
  return vrndpq_f32(x);
#elif defined __arm__ && SIMD_LIBRARY_VERSION >= 3
  return _simd_ceil_f4(x);
#else
  simd_float4 truncated = __tg_trunc(x);
  simd_float4 adjust = simd_bitselect((simd_float4)0, 1, truncated < x);
  return __tg_copysign(truncated + adjust, x);
#endif
}
 
static SIMD_CFUNC simd_float8 __tg_ceil(simd_float8 x) {
#if defined __AVX__
  return _mm256_round_ps(x, _MM_FROUND_TO_POS_INF | _MM_FROUND_NO_EXC);
#else
  return simd_make_float8(__tg_ceil(x.lo), __tg_ceil(x.hi));
#endif
}
 
static SIMD_CFUNC simd_float16 __tg_ceil(simd_float16 x) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_roundscale_ps(x, _MM_FROUND_TO_POS_INF | _MM_FROUND_NO_EXC);
#else
  return simd_make_float16(__tg_ceil(x.lo), __tg_ceil(x.hi));
#endif
}
  
#if defined __arm__ && SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_ceil_d2(simd_double2 x);
#endif
  
static SIMD_CFUNC simd_double2 __tg_ceil(simd_double2 x) {
#if defined __SSE4_1__
  return _mm_round_pd(x, _MM_FROUND_TO_POS_INF | _MM_FROUND_NO_EXC);
#elif defined __arm64__
  return vrndpq_f64(x);
#elif defined __arm__ && SIMD_LIBRARY_VERSION >= 3
  return _simd_ceil_d2(x);
#else
  simd_double2 truncated = __tg_trunc(x);
  simd_double2 adjust = simd_bitselect((simd_double2)0, 1, truncated < x);
  return __tg_copysign(truncated + adjust, x);
#endif
}
  
static SIMD_CFUNC simd_double3 __tg_ceil(simd_double3 x) {
  return simd_make_double3(__tg_ceil(simd_make_double4_undef(x)));
}
 
static SIMD_CFUNC simd_double4 __tg_ceil(simd_double4 x) {
#if defined __AVX__
  return _mm256_round_pd(x, _MM_FROUND_TO_POS_INF | _MM_FROUND_NO_EXC);
#else
  return simd_make_double4(__tg_ceil(x.lo), __tg_ceil(x.hi));
#endif
}
 
static SIMD_CFUNC simd_double8 __tg_ceil(simd_double8 x) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_roundscale_pd(x, _MM_FROUND_TO_POS_INF | _MM_FROUND_NO_EXC);
#else
  return simd_make_double8(__tg_ceil(x.lo), __tg_ceil(x.hi));
#endif
}

static SIMD_CFUNC simd_float2 __tg_floor(simd_float2 x) {
#if defined __arm64__
  return vrndm_f32(x);
#else
  return simd_make_float2(__tg_floor(simd_make_float4_undef(x)));
#endif
}
  
static SIMD_CFUNC simd_float3 __tg_floor(simd_float3 x) {
  return simd_make_float3(__tg_floor(simd_make_float4_undef(x)));
}
  
#if defined __arm__ && SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_floor_f4(simd_float4 x);
#endif

static SIMD_CFUNC simd_float4 __tg_floor(simd_float4 x) {
#if defined __SSE4_1__
  return _mm_round_ps(x, _MM_FROUND_TO_NEG_INF | _MM_FROUND_NO_EXC);
#elif defined __arm64__
  return vrndmq_f32(x);
#elif defined __arm__ && SIMD_LIBRARY_VERSION >= 3
  return _simd_floor_f4(x);
#else
  simd_float4 truncated = __tg_trunc(x);
  simd_float4 adjust = simd_bitselect((simd_float4)0, 1, truncated > x);
  return truncated - adjust;
#endif
}
 
static SIMD_CFUNC simd_float8 __tg_floor(simd_float8 x) {
#if defined __AVX__
  return _mm256_round_ps(x, _MM_FROUND_TO_NEG_INF | _MM_FROUND_NO_EXC);
#else
  return simd_make_float8(__tg_floor(x.lo), __tg_floor(x.hi));
#endif
}
 
static SIMD_CFUNC simd_float16 __tg_floor(simd_float16 x) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_roundscale_ps(x, _MM_FROUND_TO_NEG_INF | _MM_FROUND_NO_EXC);
#else
  return simd_make_float16(__tg_floor(x.lo), __tg_floor(x.hi));
#endif
}
  
#if defined __arm__ && SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_floor_d2(simd_double2 x);
#endif
  
static SIMD_CFUNC simd_double2 __tg_floor(simd_double2 x) {
#if defined __SSE4_1__
  return _mm_round_pd(x, _MM_FROUND_TO_NEG_INF | _MM_FROUND_NO_EXC);
#elif defined __arm64__
  return vrndmq_f64(x);
#elif defined __arm__ && SIMD_LIBRARY_VERSION >= 3
  return _simd_floor_d2(x);
#else
  simd_double2 truncated = __tg_trunc(x);
  simd_double2 adjust = simd_bitselect((simd_double2)0, 1, truncated > x);
  return truncated - adjust;
#endif
}
  
static SIMD_CFUNC simd_double3 __tg_floor(simd_double3 x) {
  return simd_make_double3(__tg_floor(simd_make_double4_undef(x)));
}
 
static SIMD_CFUNC simd_double4 __tg_floor(simd_double4 x) {
#if defined __AVX__
  return _mm256_round_pd(x, _MM_FROUND_TO_NEG_INF | _MM_FROUND_NO_EXC);
#else
  return simd_make_double4(__tg_floor(x.lo), __tg_floor(x.hi));
#endif
}
 
static SIMD_CFUNC simd_double8 __tg_floor(simd_double8 x) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_roundscale_pd(x, _MM_FROUND_TO_NEG_INF | _MM_FROUND_NO_EXC);
#else
  return simd_make_double8(__tg_floor(x.lo), __tg_floor(x.hi));
#endif
}

static SIMD_CFUNC simd_float2 __tg_rint(simd_float2 x) {
#if defined __arm64__
  return vrndx_f32(x);
#else
  return simd_make_float2(__tg_rint(simd_make_float4_undef(x)));
#endif
}
  
static SIMD_CFUNC simd_float3 __tg_rint(simd_float3 x) {
  return simd_make_float3(__tg_rint(simd_make_float4_undef(x)));
}
  
#if defined __arm__ && SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_rint_f4(simd_float4 x);
#endif

static SIMD_CFUNC simd_float4 __tg_rint(simd_float4 x) {
#if defined __SSE4_1__
  return _mm_round_ps(x, _MM_FROUND_RINT);
#elif defined __arm64__
  return vrndxq_f32(x);
#elif defined __arm__ && SIMD_LIBRARY_VERSION >= 3
  return _simd_rint_f4(x);
#else
  simd_float4 magic = __tg_copysign(0x1.0p23, x);
  simd_int4 x_is_small = __tg_fabs(x) < 0x1.0p23;
  return simd_bitselect(x, (x + magic) - magic, x_is_small & 0x7fffffff);
#endif
}
 
static SIMD_CFUNC simd_float8 __tg_rint(simd_float8 x) {
#if defined __AVX__
  return _mm256_round_ps(x, _MM_FROUND_RINT);
#else
  return simd_make_float8(__tg_rint(x.lo), __tg_rint(x.hi));
#endif
}
 
static SIMD_CFUNC simd_float16 __tg_rint(simd_float16 x) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_roundscale_ps(x, _MM_FROUND_RINT);
#else
  return simd_make_float16(__tg_rint(x.lo), __tg_rint(x.hi));
#endif
}
  
#if defined __arm__ && SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_rint_d2(simd_double2 x);
#endif
  
static SIMD_CFUNC simd_double2 __tg_rint(simd_double2 x) {
#if defined __SSE4_1__
  return _mm_round_pd(x, _MM_FROUND_RINT);
#elif defined __arm64__
  return vrndxq_f64(x);
#elif defined __arm__ && SIMD_LIBRARY_VERSION >= 3
  return _simd_rint_d2(x);
#else
  simd_double2 magic = __tg_copysign(0x1.0p52, x);
  simd_long2 x_is_small = __tg_fabs(x) < 0x1.0p52;
  return simd_bitselect(x, (x + magic) - magic, x_is_small & 0x7fffffffffffffff);
#endif
}
  
static SIMD_CFUNC simd_double3 __tg_rint(simd_double3 x) {
  return simd_make_double3(__tg_rint(simd_make_double4_undef(x)));
}
 
static SIMD_CFUNC simd_double4 __tg_rint(simd_double4 x) {
#if defined __AVX__
  return _mm256_round_pd(x, _MM_FROUND_RINT);
#else
  return simd_make_double4(__tg_rint(x.lo), __tg_rint(x.hi));
#endif
}
 
static SIMD_CFUNC simd_double8 __tg_rint(simd_double8 x) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_roundscale_pd(x, _MM_FROUND_RINT);
#else
  return simd_make_double8(__tg_rint(x.lo), __tg_rint(x.hi));
#endif
}

static SIMD_CFUNC simd_float2 __tg_trunc(simd_float2 x) {
#if defined __arm64__
  return vrnd_f32(x);
#else
  return simd_make_float2(__tg_trunc(simd_make_float4_undef(x)));
#endif
}
  
static SIMD_CFUNC simd_float3 __tg_trunc(simd_float3 x) {
  return simd_make_float3(__tg_trunc(simd_make_float4_undef(x)));
}
  
#if defined __arm__ && SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_trunc_f4(simd_float4 x);
#endif

static SIMD_CFUNC simd_float4 __tg_trunc(simd_float4 x) {
#if defined __SSE4_1__
  return _mm_round_ps(x, _MM_FROUND_TO_ZERO | _MM_FROUND_NO_EXC);
#elif defined __arm64__
  return vrndq_f32(x);
#elif defined __arm__ && SIMD_LIBRARY_VERSION >= 3
  return _simd_trunc_f4(x);
#else
  simd_float4 binade = simd_bitselect(0, x, 0x7f800000);
  simd_int4 mask = (simd_int4)__tg_fmin(-2*binade + 1, -0);
  simd_float4 result = simd_bitselect(0, x, mask);
  return simd_bitselect(x, result, binade < 0x1.0p23);
#endif
}
 
static SIMD_CFUNC simd_float8 __tg_trunc(simd_float8 x) {
#if defined __AVX__
  return _mm256_round_ps(x, _MM_FROUND_TO_ZERO | _MM_FROUND_NO_EXC);
#else
  return simd_make_float8(__tg_trunc(x.lo), __tg_trunc(x.hi));
#endif
}
 
static SIMD_CFUNC simd_float16 __tg_trunc(simd_float16 x) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_roundscale_ps(x, _MM_FROUND_TO_ZERO | _MM_FROUND_NO_EXC);
#else
  return simd_make_float16(__tg_trunc(x.lo), __tg_trunc(x.hi));
#endif
}
  
#if defined __arm__ && SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_trunc_d2(simd_double2 x);
#endif
  
static SIMD_CFUNC simd_double2 __tg_trunc(simd_double2 x) {
#if defined __SSE4_1__
  return _mm_round_pd(x, _MM_FROUND_TO_ZERO | _MM_FROUND_NO_EXC);
#elif defined __arm64__
  return vrndq_f64(x);
#elif defined __arm__ && SIMD_LIBRARY_VERSION >= 3
  return _simd_trunc_d2(x);
#else
  simd_double2 binade = simd_bitselect(0, x, 0x7ff0000000000000);
  simd_long2 mask = (simd_long2)__tg_fmin(-2*binade + 1, -0);
  simd_double2 result = simd_bitselect(0, x, mask);
  return simd_bitselect(x, result, binade < 0x1.0p52);
#endif
}
  
static SIMD_CFUNC simd_double3 __tg_trunc(simd_double3 x) {
  return simd_make_double3(__tg_trunc(simd_make_double4_undef(x)));
}
 
static SIMD_CFUNC simd_double4 __tg_trunc(simd_double4 x) {
#if defined __AVX__
  return _mm256_round_pd(x, _MM_FROUND_TO_ZERO | _MM_FROUND_NO_EXC);
#else
  return simd_make_double4(__tg_trunc(x.lo), __tg_trunc(x.hi));
#endif
}
 
static SIMD_CFUNC simd_double8 __tg_trunc(simd_double8 x) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_roundscale_pd(x, _MM_FROUND_TO_ZERO | _MM_FROUND_NO_EXC);
#else
  return simd_make_double8(__tg_trunc(x.lo), __tg_trunc(x.hi));
#endif
}

#pragma mark - sine, cosine implementation
static inline SIMD_CFUNC simd_float2 __tg_sin(simd_float2 x) {
  return simd_make_float2(__tg_sin(simd_make_float4(x)));
}
  
static inline SIMD_CFUNC simd_float3 __tg_sin(simd_float3 x) {
  return simd_make_float3(__tg_sin(simd_make_float4(x)));
}
  
#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_sin_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_sin(simd_float4 x) {
  return _simd_sin_f4(x);
}
#elif SIMD_LIBRARY_VERSION == 1
extern simd_float4 __sin_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_sin(simd_float4 x) {
  return __sin_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_sin(simd_float4 x) {
  return simd_make_float4(sin(x.x), sin(x.y), sin(x.z), sin(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_sin_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_sin(simd_float8 x) {
  return _simd_sin_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_sin(simd_float8 x) {
  return simd_make_float8(__tg_sin(x.lo), __tg_sin(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_sin_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_sin(simd_float16 x) {
  return _simd_sin_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_sin(simd_float16 x) {
  return simd_make_float16(__tg_sin(x.lo), __tg_sin(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_sin_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_sin(simd_double2 x) {
  return _simd_sin_d2(x);
}
#elif SIMD_LIBRARY_VERSION == 1
extern simd_double2 __sin_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_sin(simd_double2 x) {
  return __sin_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_sin(simd_double2 x) {
  return simd_make_double2(sin(x.x), sin(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_sin(simd_double3 x) {
  return simd_make_double3(__tg_sin(simd_make_double4(x)));
}
  
#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_sin_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_sin(simd_double4 x) {
  return _simd_sin_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_sin(simd_double4 x) {
  return simd_make_double4(__tg_sin(x.lo), __tg_sin(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_sin_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_sin(simd_double8 x) {
  return _simd_sin_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_sin(simd_double8 x) {
  return simd_make_double8(__tg_sin(x.lo), __tg_sin(x.hi));
}
#endif

static inline SIMD_CFUNC simd_float2 __tg_cos(simd_float2 x) {
  return simd_make_float2(__tg_cos(simd_make_float4(x)));
}
  
static inline SIMD_CFUNC simd_float3 __tg_cos(simd_float3 x) {
  return simd_make_float3(__tg_cos(simd_make_float4(x)));
}
  
#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_cos_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_cos(simd_float4 x) {
  return _simd_cos_f4(x);
}
#elif SIMD_LIBRARY_VERSION == 1
extern simd_float4 __cos_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_cos(simd_float4 x) {
  return __cos_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_cos(simd_float4 x) {
  return simd_make_float4(cos(x.x), cos(x.y), cos(x.z), cos(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_cos_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_cos(simd_float8 x) {
  return _simd_cos_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_cos(simd_float8 x) {
  return simd_make_float8(__tg_cos(x.lo), __tg_cos(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_cos_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_cos(simd_float16 x) {
  return _simd_cos_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_cos(simd_float16 x) {
  return simd_make_float16(__tg_cos(x.lo), __tg_cos(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_cos_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_cos(simd_double2 x) {
  return _simd_cos_d2(x);
}
#elif SIMD_LIBRARY_VERSION == 1
extern simd_double2 __cos_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_cos(simd_double2 x) {
  return __cos_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_cos(simd_double2 x) {
  return simd_make_double2(cos(x.x), cos(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_cos(simd_double3 x) {
  return simd_make_double3(__tg_cos(simd_make_double4(x)));
}
  
#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_cos_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_cos(simd_double4 x) {
  return _simd_cos_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_cos(simd_double4 x) {
  return simd_make_double4(__tg_cos(x.lo), __tg_cos(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_cos_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_cos(simd_double8 x) {
  return _simd_cos_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_cos(simd_double8 x) {
  return simd_make_double8(__tg_cos(x.lo), __tg_cos(x.hi));
}
#endif

  
#pragma mark - acos implementation
static inline SIMD_CFUNC simd_float2 __tg_acos(simd_float2 x) {
  return simd_make_float2(__tg_acos(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_acos(simd_float3 x) {
  return simd_make_float3(__tg_acos(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_acos_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_acos(simd_float4 x) {
  return _simd_acos_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_acos(simd_float4 x) {
  return simd_make_float4(acos(x.x), acos(x.y), acos(x.z), acos(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_acos_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_acos(simd_float8 x) {
  return _simd_acos_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_acos(simd_float8 x) {
  return simd_make_float8(__tg_acos(x.lo), __tg_acos(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_acos_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_acos(simd_float16 x) {
  return _simd_acos_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_acos(simd_float16 x) {
  return simd_make_float16(__tg_acos(x.lo), __tg_acos(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_acos_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_acos(simd_double2 x) {
  return _simd_acos_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_acos(simd_double2 x) {
  return simd_make_double2(acos(x.x), acos(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_acos(simd_double3 x) {
  return simd_make_double3(__tg_acos(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_acos_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_acos(simd_double4 x) {
  return _simd_acos_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_acos(simd_double4 x) {
  return simd_make_double4(__tg_acos(x.lo), __tg_acos(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_acos_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_acos(simd_double8 x) {
  return _simd_acos_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_acos(simd_double8 x) {
  return simd_make_double8(__tg_acos(x.lo), __tg_acos(x.hi));
}
#endif

#pragma mark - asin implementation
static inline SIMD_CFUNC simd_float2 __tg_asin(simd_float2 x) {
  return simd_make_float2(__tg_asin(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_asin(simd_float3 x) {
  return simd_make_float3(__tg_asin(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_asin_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_asin(simd_float4 x) {
  return _simd_asin_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_asin(simd_float4 x) {
  return simd_make_float4(asin(x.x), asin(x.y), asin(x.z), asin(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_asin_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_asin(simd_float8 x) {
  return _simd_asin_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_asin(simd_float8 x) {
  return simd_make_float8(__tg_asin(x.lo), __tg_asin(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_asin_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_asin(simd_float16 x) {
  return _simd_asin_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_asin(simd_float16 x) {
  return simd_make_float16(__tg_asin(x.lo), __tg_asin(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_asin_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_asin(simd_double2 x) {
  return _simd_asin_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_asin(simd_double2 x) {
  return simd_make_double2(asin(x.x), asin(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_asin(simd_double3 x) {
  return simd_make_double3(__tg_asin(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_asin_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_asin(simd_double4 x) {
  return _simd_asin_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_asin(simd_double4 x) {
  return simd_make_double4(__tg_asin(x.lo), __tg_asin(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_asin_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_asin(simd_double8 x) {
  return _simd_asin_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_asin(simd_double8 x) {
  return simd_make_double8(__tg_asin(x.lo), __tg_asin(x.hi));
}
#endif

#pragma mark - atan implementation
static inline SIMD_CFUNC simd_float2 __tg_atan(simd_float2 x) {
  return simd_make_float2(__tg_atan(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_atan(simd_float3 x) {
  return simd_make_float3(__tg_atan(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_atan_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_atan(simd_float4 x) {
  return _simd_atan_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_atan(simd_float4 x) {
  return simd_make_float4(atan(x.x), atan(x.y), atan(x.z), atan(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_atan_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_atan(simd_float8 x) {
  return _simd_atan_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_atan(simd_float8 x) {
  return simd_make_float8(__tg_atan(x.lo), __tg_atan(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_atan_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_atan(simd_float16 x) {
  return _simd_atan_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_atan(simd_float16 x) {
  return simd_make_float16(__tg_atan(x.lo), __tg_atan(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_atan_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_atan(simd_double2 x) {
  return _simd_atan_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_atan(simd_double2 x) {
  return simd_make_double2(atan(x.x), atan(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_atan(simd_double3 x) {
  return simd_make_double3(__tg_atan(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_atan_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_atan(simd_double4 x) {
  return _simd_atan_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_atan(simd_double4 x) {
  return simd_make_double4(__tg_atan(x.lo), __tg_atan(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_atan_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_atan(simd_double8 x) {
  return _simd_atan_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_atan(simd_double8 x) {
  return simd_make_double8(__tg_atan(x.lo), __tg_atan(x.hi));
}
#endif

#pragma mark - tan implementation
static inline SIMD_CFUNC simd_float2 __tg_tan(simd_float2 x) {
  return simd_make_float2(__tg_tan(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_tan(simd_float3 x) {
  return simd_make_float3(__tg_tan(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_tan_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_tan(simd_float4 x) {
  return _simd_tan_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_tan(simd_float4 x) {
  return simd_make_float4(tan(x.x), tan(x.y), tan(x.z), tan(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_tan_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_tan(simd_float8 x) {
  return _simd_tan_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_tan(simd_float8 x) {
  return simd_make_float8(__tg_tan(x.lo), __tg_tan(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_tan_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_tan(simd_float16 x) {
  return _simd_tan_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_tan(simd_float16 x) {
  return simd_make_float16(__tg_tan(x.lo), __tg_tan(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_tan_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_tan(simd_double2 x) {
  return _simd_tan_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_tan(simd_double2 x) {
  return simd_make_double2(tan(x.x), tan(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_tan(simd_double3 x) {
  return simd_make_double3(__tg_tan(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_tan_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_tan(simd_double4 x) {
  return _simd_tan_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_tan(simd_double4 x) {
  return simd_make_double4(__tg_tan(x.lo), __tg_tan(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_tan_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_tan(simd_double8 x) {
  return _simd_tan_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_tan(simd_double8 x) {
  return simd_make_double8(__tg_tan(x.lo), __tg_tan(x.hi));
}
#endif

#pragma mark - cospi implementation
#if SIMD_LIBRARY_VERSION >= 1
static inline SIMD_CFUNC simd_float2 __tg_cospi(simd_float2 x) {
  return simd_make_float2(__tg_cospi(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_cospi(simd_float3 x) {
  return simd_make_float3(__tg_cospi(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_cospi_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_cospi(simd_float4 x) {
  return _simd_cospi_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_cospi(simd_float4 x) {
  return simd_make_float4(__cospi(x.x), __cospi(x.y), __cospi(x.z), __cospi(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_cospi_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_cospi(simd_float8 x) {
  return _simd_cospi_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_cospi(simd_float8 x) {
  return simd_make_float8(__tg_cospi(x.lo), __tg_cospi(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_cospi_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_cospi(simd_float16 x) {
  return _simd_cospi_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_cospi(simd_float16 x) {
  return simd_make_float16(__tg_cospi(x.lo), __tg_cospi(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_cospi_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_cospi(simd_double2 x) {
  return _simd_cospi_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_cospi(simd_double2 x) {
  return simd_make_double2(__cospi(x.x), __cospi(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_cospi(simd_double3 x) {
  return simd_make_double3(__tg_cospi(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_cospi_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_cospi(simd_double4 x) {
  return _simd_cospi_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_cospi(simd_double4 x) {
  return simd_make_double4(__tg_cospi(x.lo), __tg_cospi(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_cospi_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_cospi(simd_double8 x) {
  return _simd_cospi_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_cospi(simd_double8 x) {
  return simd_make_double8(__tg_cospi(x.lo), __tg_cospi(x.hi));
}
#endif

#endif /* SIMD_LIBRARY_VERSION */
#pragma mark - sinpi implementation
#if SIMD_LIBRARY_VERSION >= 1
static inline SIMD_CFUNC simd_float2 __tg_sinpi(simd_float2 x) {
  return simd_make_float2(__tg_sinpi(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_sinpi(simd_float3 x) {
  return simd_make_float3(__tg_sinpi(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_sinpi_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_sinpi(simd_float4 x) {
  return _simd_sinpi_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_sinpi(simd_float4 x) {
  return simd_make_float4(__sinpi(x.x), __sinpi(x.y), __sinpi(x.z), __sinpi(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_sinpi_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_sinpi(simd_float8 x) {
  return _simd_sinpi_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_sinpi(simd_float8 x) {
  return simd_make_float8(__tg_sinpi(x.lo), __tg_sinpi(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_sinpi_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_sinpi(simd_float16 x) {
  return _simd_sinpi_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_sinpi(simd_float16 x) {
  return simd_make_float16(__tg_sinpi(x.lo), __tg_sinpi(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_sinpi_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_sinpi(simd_double2 x) {
  return _simd_sinpi_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_sinpi(simd_double2 x) {
  return simd_make_double2(__sinpi(x.x), __sinpi(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_sinpi(simd_double3 x) {
  return simd_make_double3(__tg_sinpi(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_sinpi_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_sinpi(simd_double4 x) {
  return _simd_sinpi_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_sinpi(simd_double4 x) {
  return simd_make_double4(__tg_sinpi(x.lo), __tg_sinpi(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_sinpi_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_sinpi(simd_double8 x) {
  return _simd_sinpi_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_sinpi(simd_double8 x) {
  return simd_make_double8(__tg_sinpi(x.lo), __tg_sinpi(x.hi));
}
#endif

#endif /* SIMD_LIBRARY_VERSION */
#pragma mark - tanpi implementation
#if SIMD_LIBRARY_VERSION >= 1
static inline SIMD_CFUNC simd_float2 __tg_tanpi(simd_float2 x) {
  return simd_make_float2(__tg_tanpi(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_tanpi(simd_float3 x) {
  return simd_make_float3(__tg_tanpi(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_tanpi_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_tanpi(simd_float4 x) {
  return _simd_tanpi_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_tanpi(simd_float4 x) {
  return simd_make_float4(__tanpi(x.x), __tanpi(x.y), __tanpi(x.z), __tanpi(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_tanpi_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_tanpi(simd_float8 x) {
  return _simd_tanpi_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_tanpi(simd_float8 x) {
  return simd_make_float8(__tg_tanpi(x.lo), __tg_tanpi(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_tanpi_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_tanpi(simd_float16 x) {
  return _simd_tanpi_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_tanpi(simd_float16 x) {
  return simd_make_float16(__tg_tanpi(x.lo), __tg_tanpi(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_tanpi_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_tanpi(simd_double2 x) {
  return _simd_tanpi_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_tanpi(simd_double2 x) {
  return simd_make_double2(__tanpi(x.x), __tanpi(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_tanpi(simd_double3 x) {
  return simd_make_double3(__tg_tanpi(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_tanpi_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_tanpi(simd_double4 x) {
  return _simd_tanpi_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_tanpi(simd_double4 x) {
  return simd_make_double4(__tg_tanpi(x.lo), __tg_tanpi(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_tanpi_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_tanpi(simd_double8 x) {
  return _simd_tanpi_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_tanpi(simd_double8 x) {
  return simd_make_double8(__tg_tanpi(x.lo), __tg_tanpi(x.hi));
}
#endif

#endif /* SIMD_LIBRARY_VERSION */
#pragma mark - acosh implementation
static inline SIMD_CFUNC simd_float2 __tg_acosh(simd_float2 x) {
  return simd_make_float2(__tg_acosh(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_acosh(simd_float3 x) {
  return simd_make_float3(__tg_acosh(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_acosh_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_acosh(simd_float4 x) {
  return _simd_acosh_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_acosh(simd_float4 x) {
  return simd_make_float4(acosh(x.x), acosh(x.y), acosh(x.z), acosh(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_acosh_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_acosh(simd_float8 x) {
  return _simd_acosh_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_acosh(simd_float8 x) {
  return simd_make_float8(__tg_acosh(x.lo), __tg_acosh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_acosh_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_acosh(simd_float16 x) {
  return _simd_acosh_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_acosh(simd_float16 x) {
  return simd_make_float16(__tg_acosh(x.lo), __tg_acosh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_acosh_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_acosh(simd_double2 x) {
  return _simd_acosh_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_acosh(simd_double2 x) {
  return simd_make_double2(acosh(x.x), acosh(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_acosh(simd_double3 x) {
  return simd_make_double3(__tg_acosh(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_acosh_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_acosh(simd_double4 x) {
  return _simd_acosh_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_acosh(simd_double4 x) {
  return simd_make_double4(__tg_acosh(x.lo), __tg_acosh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_acosh_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_acosh(simd_double8 x) {
  return _simd_acosh_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_acosh(simd_double8 x) {
  return simd_make_double8(__tg_acosh(x.lo), __tg_acosh(x.hi));
}
#endif

#pragma mark - asinh implementation
static inline SIMD_CFUNC simd_float2 __tg_asinh(simd_float2 x) {
  return simd_make_float2(__tg_asinh(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_asinh(simd_float3 x) {
  return simd_make_float3(__tg_asinh(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_asinh_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_asinh(simd_float4 x) {
  return _simd_asinh_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_asinh(simd_float4 x) {
  return simd_make_float4(asinh(x.x), asinh(x.y), asinh(x.z), asinh(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_asinh_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_asinh(simd_float8 x) {
  return _simd_asinh_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_asinh(simd_float8 x) {
  return simd_make_float8(__tg_asinh(x.lo), __tg_asinh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_asinh_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_asinh(simd_float16 x) {
  return _simd_asinh_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_asinh(simd_float16 x) {
  return simd_make_float16(__tg_asinh(x.lo), __tg_asinh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_asinh_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_asinh(simd_double2 x) {
  return _simd_asinh_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_asinh(simd_double2 x) {
  return simd_make_double2(asinh(x.x), asinh(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_asinh(simd_double3 x) {
  return simd_make_double3(__tg_asinh(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_asinh_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_asinh(simd_double4 x) {
  return _simd_asinh_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_asinh(simd_double4 x) {
  return simd_make_double4(__tg_asinh(x.lo), __tg_asinh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_asinh_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_asinh(simd_double8 x) {
  return _simd_asinh_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_asinh(simd_double8 x) {
  return simd_make_double8(__tg_asinh(x.lo), __tg_asinh(x.hi));
}
#endif

#pragma mark - atanh implementation
static inline SIMD_CFUNC simd_float2 __tg_atanh(simd_float2 x) {
  return simd_make_float2(__tg_atanh(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_atanh(simd_float3 x) {
  return simd_make_float3(__tg_atanh(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_atanh_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_atanh(simd_float4 x) {
  return _simd_atanh_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_atanh(simd_float4 x) {
  return simd_make_float4(atanh(x.x), atanh(x.y), atanh(x.z), atanh(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_atanh_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_atanh(simd_float8 x) {
  return _simd_atanh_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_atanh(simd_float8 x) {
  return simd_make_float8(__tg_atanh(x.lo), __tg_atanh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_atanh_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_atanh(simd_float16 x) {
  return _simd_atanh_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_atanh(simd_float16 x) {
  return simd_make_float16(__tg_atanh(x.lo), __tg_atanh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_atanh_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_atanh(simd_double2 x) {
  return _simd_atanh_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_atanh(simd_double2 x) {
  return simd_make_double2(atanh(x.x), atanh(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_atanh(simd_double3 x) {
  return simd_make_double3(__tg_atanh(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_atanh_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_atanh(simd_double4 x) {
  return _simd_atanh_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_atanh(simd_double4 x) {
  return simd_make_double4(__tg_atanh(x.lo), __tg_atanh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_atanh_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_atanh(simd_double8 x) {
  return _simd_atanh_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_atanh(simd_double8 x) {
  return simd_make_double8(__tg_atanh(x.lo), __tg_atanh(x.hi));
}
#endif

#pragma mark - cosh implementation
static inline SIMD_CFUNC simd_float2 __tg_cosh(simd_float2 x) {
  return simd_make_float2(__tg_cosh(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_cosh(simd_float3 x) {
  return simd_make_float3(__tg_cosh(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_cosh_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_cosh(simd_float4 x) {
  return _simd_cosh_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_cosh(simd_float4 x) {
  return simd_make_float4(cosh(x.x), cosh(x.y), cosh(x.z), cosh(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_cosh_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_cosh(simd_float8 x) {
  return _simd_cosh_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_cosh(simd_float8 x) {
  return simd_make_float8(__tg_cosh(x.lo), __tg_cosh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_cosh_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_cosh(simd_float16 x) {
  return _simd_cosh_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_cosh(simd_float16 x) {
  return simd_make_float16(__tg_cosh(x.lo), __tg_cosh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_cosh_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_cosh(simd_double2 x) {
  return _simd_cosh_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_cosh(simd_double2 x) {
  return simd_make_double2(cosh(x.x), cosh(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_cosh(simd_double3 x) {
  return simd_make_double3(__tg_cosh(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_cosh_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_cosh(simd_double4 x) {
  return _simd_cosh_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_cosh(simd_double4 x) {
  return simd_make_double4(__tg_cosh(x.lo), __tg_cosh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_cosh_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_cosh(simd_double8 x) {
  return _simd_cosh_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_cosh(simd_double8 x) {
  return simd_make_double8(__tg_cosh(x.lo), __tg_cosh(x.hi));
}
#endif

#pragma mark - sinh implementation
static inline SIMD_CFUNC simd_float2 __tg_sinh(simd_float2 x) {
  return simd_make_float2(__tg_sinh(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_sinh(simd_float3 x) {
  return simd_make_float3(__tg_sinh(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_sinh_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_sinh(simd_float4 x) {
  return _simd_sinh_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_sinh(simd_float4 x) {
  return simd_make_float4(sinh(x.x), sinh(x.y), sinh(x.z), sinh(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_sinh_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_sinh(simd_float8 x) {
  return _simd_sinh_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_sinh(simd_float8 x) {
  return simd_make_float8(__tg_sinh(x.lo), __tg_sinh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_sinh_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_sinh(simd_float16 x) {
  return _simd_sinh_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_sinh(simd_float16 x) {
  return simd_make_float16(__tg_sinh(x.lo), __tg_sinh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_sinh_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_sinh(simd_double2 x) {
  return _simd_sinh_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_sinh(simd_double2 x) {
  return simd_make_double2(sinh(x.x), sinh(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_sinh(simd_double3 x) {
  return simd_make_double3(__tg_sinh(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_sinh_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_sinh(simd_double4 x) {
  return _simd_sinh_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_sinh(simd_double4 x) {
  return simd_make_double4(__tg_sinh(x.lo), __tg_sinh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_sinh_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_sinh(simd_double8 x) {
  return _simd_sinh_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_sinh(simd_double8 x) {
  return simd_make_double8(__tg_sinh(x.lo), __tg_sinh(x.hi));
}
#endif

#pragma mark - tanh implementation
static inline SIMD_CFUNC simd_float2 __tg_tanh(simd_float2 x) {
  return simd_make_float2(__tg_tanh(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_tanh(simd_float3 x) {
  return simd_make_float3(__tg_tanh(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_tanh_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_tanh(simd_float4 x) {
  return _simd_tanh_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_tanh(simd_float4 x) {
  return simd_make_float4(tanh(x.x), tanh(x.y), tanh(x.z), tanh(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_tanh_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_tanh(simd_float8 x) {
  return _simd_tanh_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_tanh(simd_float8 x) {
  return simd_make_float8(__tg_tanh(x.lo), __tg_tanh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_tanh_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_tanh(simd_float16 x) {
  return _simd_tanh_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_tanh(simd_float16 x) {
  return simd_make_float16(__tg_tanh(x.lo), __tg_tanh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_tanh_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_tanh(simd_double2 x) {
  return _simd_tanh_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_tanh(simd_double2 x) {
  return simd_make_double2(tanh(x.x), tanh(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_tanh(simd_double3 x) {
  return simd_make_double3(__tg_tanh(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_tanh_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_tanh(simd_double4 x) {
  return _simd_tanh_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_tanh(simd_double4 x) {
  return simd_make_double4(__tg_tanh(x.lo), __tg_tanh(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_tanh_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_tanh(simd_double8 x) {
  return _simd_tanh_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_tanh(simd_double8 x) {
  return simd_make_double8(__tg_tanh(x.lo), __tg_tanh(x.hi));
}
#endif

#pragma mark - exp implementation
static inline SIMD_CFUNC simd_float2 __tg_exp(simd_float2 x) {
  return simd_make_float2(__tg_exp(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_exp(simd_float3 x) {
  return simd_make_float3(__tg_exp(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_exp_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_exp(simd_float4 x) {
  return _simd_exp_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_exp(simd_float4 x) {
  return simd_make_float4(exp(x.x), exp(x.y), exp(x.z), exp(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_exp_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_exp(simd_float8 x) {
  return _simd_exp_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_exp(simd_float8 x) {
  return simd_make_float8(__tg_exp(x.lo), __tg_exp(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_exp_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_exp(simd_float16 x) {
  return _simd_exp_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_exp(simd_float16 x) {
  return simd_make_float16(__tg_exp(x.lo), __tg_exp(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_exp_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_exp(simd_double2 x) {
  return _simd_exp_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_exp(simd_double2 x) {
  return simd_make_double2(exp(x.x), exp(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_exp(simd_double3 x) {
  return simd_make_double3(__tg_exp(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_exp_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_exp(simd_double4 x) {
  return _simd_exp_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_exp(simd_double4 x) {
  return simd_make_double4(__tg_exp(x.lo), __tg_exp(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_exp_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_exp(simd_double8 x) {
  return _simd_exp_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_exp(simd_double8 x) {
  return simd_make_double8(__tg_exp(x.lo), __tg_exp(x.hi));
}
#endif

#pragma mark - exp2 implementation
static inline SIMD_CFUNC simd_float2 __tg_exp2(simd_float2 x) {
  return simd_make_float2(__tg_exp2(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_exp2(simd_float3 x) {
  return simd_make_float3(__tg_exp2(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_exp2_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_exp2(simd_float4 x) {
  return _simd_exp2_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_exp2(simd_float4 x) {
  return simd_make_float4(exp2(x.x), exp2(x.y), exp2(x.z), exp2(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_exp2_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_exp2(simd_float8 x) {
  return _simd_exp2_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_exp2(simd_float8 x) {
  return simd_make_float8(__tg_exp2(x.lo), __tg_exp2(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_exp2_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_exp2(simd_float16 x) {
  return _simd_exp2_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_exp2(simd_float16 x) {
  return simd_make_float16(__tg_exp2(x.lo), __tg_exp2(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_exp2_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_exp2(simd_double2 x) {
  return _simd_exp2_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_exp2(simd_double2 x) {
  return simd_make_double2(exp2(x.x), exp2(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_exp2(simd_double3 x) {
  return simd_make_double3(__tg_exp2(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_exp2_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_exp2(simd_double4 x) {
  return _simd_exp2_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_exp2(simd_double4 x) {
  return simd_make_double4(__tg_exp2(x.lo), __tg_exp2(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_exp2_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_exp2(simd_double8 x) {
  return _simd_exp2_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_exp2(simd_double8 x) {
  return simd_make_double8(__tg_exp2(x.lo), __tg_exp2(x.hi));
}
#endif

#pragma mark - exp10 implementation
#if SIMD_LIBRARY_VERSION >= 1
static inline SIMD_CFUNC simd_float2 __tg_exp10(simd_float2 x) {
  return simd_make_float2(__tg_exp10(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_exp10(simd_float3 x) {
  return simd_make_float3(__tg_exp10(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_exp10_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_exp10(simd_float4 x) {
  return _simd_exp10_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_exp10(simd_float4 x) {
  return simd_make_float4(__exp10(x.x), __exp10(x.y), __exp10(x.z), __exp10(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_exp10_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_exp10(simd_float8 x) {
  return _simd_exp10_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_exp10(simd_float8 x) {
  return simd_make_float8(__tg_exp10(x.lo), __tg_exp10(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_exp10_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_exp10(simd_float16 x) {
  return _simd_exp10_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_exp10(simd_float16 x) {
  return simd_make_float16(__tg_exp10(x.lo), __tg_exp10(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_exp10_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_exp10(simd_double2 x) {
  return _simd_exp10_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_exp10(simd_double2 x) {
  return simd_make_double2(__exp10(x.x), __exp10(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_exp10(simd_double3 x) {
  return simd_make_double3(__tg_exp10(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_exp10_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_exp10(simd_double4 x) {
  return _simd_exp10_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_exp10(simd_double4 x) {
  return simd_make_double4(__tg_exp10(x.lo), __tg_exp10(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_exp10_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_exp10(simd_double8 x) {
  return _simd_exp10_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_exp10(simd_double8 x) {
  return simd_make_double8(__tg_exp10(x.lo), __tg_exp10(x.hi));
}
#endif

#endif /* SIMD_LIBRARY_VERSION */
#pragma mark - expm1 implementation
static inline SIMD_CFUNC simd_float2 __tg_expm1(simd_float2 x) {
  return simd_make_float2(__tg_expm1(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_expm1(simd_float3 x) {
  return simd_make_float3(__tg_expm1(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_expm1_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_expm1(simd_float4 x) {
  return _simd_expm1_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_expm1(simd_float4 x) {
  return simd_make_float4(expm1(x.x), expm1(x.y), expm1(x.z), expm1(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_expm1_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_expm1(simd_float8 x) {
  return _simd_expm1_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_expm1(simd_float8 x) {
  return simd_make_float8(__tg_expm1(x.lo), __tg_expm1(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_expm1_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_expm1(simd_float16 x) {
  return _simd_expm1_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_expm1(simd_float16 x) {
  return simd_make_float16(__tg_expm1(x.lo), __tg_expm1(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_expm1_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_expm1(simd_double2 x) {
  return _simd_expm1_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_expm1(simd_double2 x) {
  return simd_make_double2(expm1(x.x), expm1(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_expm1(simd_double3 x) {
  return simd_make_double3(__tg_expm1(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_expm1_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_expm1(simd_double4 x) {
  return _simd_expm1_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_expm1(simd_double4 x) {
  return simd_make_double4(__tg_expm1(x.lo), __tg_expm1(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_expm1_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_expm1(simd_double8 x) {
  return _simd_expm1_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_expm1(simd_double8 x) {
  return simd_make_double8(__tg_expm1(x.lo), __tg_expm1(x.hi));
}
#endif

#pragma mark - log implementation
static inline SIMD_CFUNC simd_float2 __tg_log(simd_float2 x) {
  return simd_make_float2(__tg_log(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_log(simd_float3 x) {
  return simd_make_float3(__tg_log(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_log_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_log(simd_float4 x) {
  return _simd_log_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_log(simd_float4 x) {
  return simd_make_float4(log(x.x), log(x.y), log(x.z), log(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_log_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_log(simd_float8 x) {
  return _simd_log_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_log(simd_float8 x) {
  return simd_make_float8(__tg_log(x.lo), __tg_log(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_log_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_log(simd_float16 x) {
  return _simd_log_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_log(simd_float16 x) {
  return simd_make_float16(__tg_log(x.lo), __tg_log(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_log_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_log(simd_double2 x) {
  return _simd_log_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_log(simd_double2 x) {
  return simd_make_double2(log(x.x), log(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_log(simd_double3 x) {
  return simd_make_double3(__tg_log(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_log_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_log(simd_double4 x) {
  return _simd_log_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_log(simd_double4 x) {
  return simd_make_double4(__tg_log(x.lo), __tg_log(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_log_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_log(simd_double8 x) {
  return _simd_log_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_log(simd_double8 x) {
  return simd_make_double8(__tg_log(x.lo), __tg_log(x.hi));
}
#endif

#pragma mark - log2 implementation
static inline SIMD_CFUNC simd_float2 __tg_log2(simd_float2 x) {
  return simd_make_float2(__tg_log2(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_log2(simd_float3 x) {
  return simd_make_float3(__tg_log2(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_log2_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_log2(simd_float4 x) {
  return _simd_log2_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_log2(simd_float4 x) {
  return simd_make_float4(log2(x.x), log2(x.y), log2(x.z), log2(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_log2_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_log2(simd_float8 x) {
  return _simd_log2_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_log2(simd_float8 x) {
  return simd_make_float8(__tg_log2(x.lo), __tg_log2(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_log2_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_log2(simd_float16 x) {
  return _simd_log2_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_log2(simd_float16 x) {
  return simd_make_float16(__tg_log2(x.lo), __tg_log2(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_log2_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_log2(simd_double2 x) {
  return _simd_log2_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_log2(simd_double2 x) {
  return simd_make_double2(log2(x.x), log2(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_log2(simd_double3 x) {
  return simd_make_double3(__tg_log2(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_log2_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_log2(simd_double4 x) {
  return _simd_log2_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_log2(simd_double4 x) {
  return simd_make_double4(__tg_log2(x.lo), __tg_log2(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_log2_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_log2(simd_double8 x) {
  return _simd_log2_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_log2(simd_double8 x) {
  return simd_make_double8(__tg_log2(x.lo), __tg_log2(x.hi));
}
#endif

#pragma mark - log10 implementation
static inline SIMD_CFUNC simd_float2 __tg_log10(simd_float2 x) {
  return simd_make_float2(__tg_log10(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_log10(simd_float3 x) {
  return simd_make_float3(__tg_log10(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_log10_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_log10(simd_float4 x) {
  return _simd_log10_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_log10(simd_float4 x) {
  return simd_make_float4(log10(x.x), log10(x.y), log10(x.z), log10(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_log10_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_log10(simd_float8 x) {
  return _simd_log10_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_log10(simd_float8 x) {
  return simd_make_float8(__tg_log10(x.lo), __tg_log10(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_log10_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_log10(simd_float16 x) {
  return _simd_log10_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_log10(simd_float16 x) {
  return simd_make_float16(__tg_log10(x.lo), __tg_log10(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_log10_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_log10(simd_double2 x) {
  return _simd_log10_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_log10(simd_double2 x) {
  return simd_make_double2(log10(x.x), log10(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_log10(simd_double3 x) {
  return simd_make_double3(__tg_log10(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_log10_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_log10(simd_double4 x) {
  return _simd_log10_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_log10(simd_double4 x) {
  return simd_make_double4(__tg_log10(x.lo), __tg_log10(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_log10_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_log10(simd_double8 x) {
  return _simd_log10_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_log10(simd_double8 x) {
  return simd_make_double8(__tg_log10(x.lo), __tg_log10(x.hi));
}
#endif

#pragma mark - log1p implementation
static inline SIMD_CFUNC simd_float2 __tg_log1p(simd_float2 x) {
  return simd_make_float2(__tg_log1p(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_log1p(simd_float3 x) {
  return simd_make_float3(__tg_log1p(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_log1p_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_log1p(simd_float4 x) {
  return _simd_log1p_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_log1p(simd_float4 x) {
  return simd_make_float4(log1p(x.x), log1p(x.y), log1p(x.z), log1p(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_log1p_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_log1p(simd_float8 x) {
  return _simd_log1p_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_log1p(simd_float8 x) {
  return simd_make_float8(__tg_log1p(x.lo), __tg_log1p(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_log1p_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_log1p(simd_float16 x) {
  return _simd_log1p_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_log1p(simd_float16 x) {
  return simd_make_float16(__tg_log1p(x.lo), __tg_log1p(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_log1p_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_log1p(simd_double2 x) {
  return _simd_log1p_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_log1p(simd_double2 x) {
  return simd_make_double2(log1p(x.x), log1p(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_log1p(simd_double3 x) {
  return simd_make_double3(__tg_log1p(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_log1p_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_log1p(simd_double4 x) {
  return _simd_log1p_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_log1p(simd_double4 x) {
  return simd_make_double4(__tg_log1p(x.lo), __tg_log1p(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_log1p_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_log1p(simd_double8 x) {
  return _simd_log1p_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_log1p(simd_double8 x) {
  return simd_make_double8(__tg_log1p(x.lo), __tg_log1p(x.hi));
}
#endif

#pragma mark - cbrt implementation
static inline SIMD_CFUNC simd_float2 __tg_cbrt(simd_float2 x) {
  return simd_make_float2(__tg_cbrt(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_cbrt(simd_float3 x) {
  return simd_make_float3(__tg_cbrt(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_cbrt_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_cbrt(simd_float4 x) {
  return _simd_cbrt_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_cbrt(simd_float4 x) {
  return simd_make_float4(cbrt(x.x), cbrt(x.y), cbrt(x.z), cbrt(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_cbrt_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_cbrt(simd_float8 x) {
  return _simd_cbrt_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_cbrt(simd_float8 x) {
  return simd_make_float8(__tg_cbrt(x.lo), __tg_cbrt(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_cbrt_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_cbrt(simd_float16 x) {
  return _simd_cbrt_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_cbrt(simd_float16 x) {
  return simd_make_float16(__tg_cbrt(x.lo), __tg_cbrt(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_cbrt_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_cbrt(simd_double2 x) {
  return _simd_cbrt_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_cbrt(simd_double2 x) {
  return simd_make_double2(cbrt(x.x), cbrt(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_cbrt(simd_double3 x) {
  return simd_make_double3(__tg_cbrt(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_cbrt_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_cbrt(simd_double4 x) {
  return _simd_cbrt_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_cbrt(simd_double4 x) {
  return simd_make_double4(__tg_cbrt(x.lo), __tg_cbrt(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_cbrt_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_cbrt(simd_double8 x) {
  return _simd_cbrt_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_cbrt(simd_double8 x) {
  return simd_make_double8(__tg_cbrt(x.lo), __tg_cbrt(x.hi));
}
#endif

#pragma mark - erf implementation
static inline SIMD_CFUNC simd_float2 __tg_erf(simd_float2 x) {
  return simd_make_float2(__tg_erf(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_erf(simd_float3 x) {
  return simd_make_float3(__tg_erf(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_erf_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_erf(simd_float4 x) {
  return _simd_erf_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_erf(simd_float4 x) {
  return simd_make_float4(erf(x.x), erf(x.y), erf(x.z), erf(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_erf_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_erf(simd_float8 x) {
  return _simd_erf_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_erf(simd_float8 x) {
  return simd_make_float8(__tg_erf(x.lo), __tg_erf(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_erf_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_erf(simd_float16 x) {
  return _simd_erf_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_erf(simd_float16 x) {
  return simd_make_float16(__tg_erf(x.lo), __tg_erf(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_erf_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_erf(simd_double2 x) {
  return _simd_erf_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_erf(simd_double2 x) {
  return simd_make_double2(erf(x.x), erf(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_erf(simd_double3 x) {
  return simd_make_double3(__tg_erf(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_erf_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_erf(simd_double4 x) {
  return _simd_erf_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_erf(simd_double4 x) {
  return simd_make_double4(__tg_erf(x.lo), __tg_erf(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_erf_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_erf(simd_double8 x) {
  return _simd_erf_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_erf(simd_double8 x) {
  return simd_make_double8(__tg_erf(x.lo), __tg_erf(x.hi));
}
#endif

#pragma mark - erfc implementation
static inline SIMD_CFUNC simd_float2 __tg_erfc(simd_float2 x) {
  return simd_make_float2(__tg_erfc(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_erfc(simd_float3 x) {
  return simd_make_float3(__tg_erfc(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_erfc_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_erfc(simd_float4 x) {
  return _simd_erfc_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_erfc(simd_float4 x) {
  return simd_make_float4(erfc(x.x), erfc(x.y), erfc(x.z), erfc(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_erfc_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_erfc(simd_float8 x) {
  return _simd_erfc_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_erfc(simd_float8 x) {
  return simd_make_float8(__tg_erfc(x.lo), __tg_erfc(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_erfc_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_erfc(simd_float16 x) {
  return _simd_erfc_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_erfc(simd_float16 x) {
  return simd_make_float16(__tg_erfc(x.lo), __tg_erfc(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_erfc_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_erfc(simd_double2 x) {
  return _simd_erfc_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_erfc(simd_double2 x) {
  return simd_make_double2(erfc(x.x), erfc(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_erfc(simd_double3 x) {
  return simd_make_double3(__tg_erfc(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_erfc_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_erfc(simd_double4 x) {
  return _simd_erfc_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_erfc(simd_double4 x) {
  return simd_make_double4(__tg_erfc(x.lo), __tg_erfc(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_erfc_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_erfc(simd_double8 x) {
  return _simd_erfc_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_erfc(simd_double8 x) {
  return simd_make_double8(__tg_erfc(x.lo), __tg_erfc(x.hi));
}
#endif

#pragma mark - tgamma implementation
static inline SIMD_CFUNC simd_float2 __tg_tgamma(simd_float2 x) {
  return simd_make_float2(__tg_tgamma(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_tgamma(simd_float3 x) {
  return simd_make_float3(__tg_tgamma(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_tgamma_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_tgamma(simd_float4 x) {
  return _simd_tgamma_f4(x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_tgamma(simd_float4 x) {
  return simd_make_float4(tgamma(x.x), tgamma(x.y), tgamma(x.z), tgamma(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_tgamma_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_tgamma(simd_float8 x) {
  return _simd_tgamma_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_tgamma(simd_float8 x) {
  return simd_make_float8(__tg_tgamma(x.lo), __tg_tgamma(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_tgamma_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_tgamma(simd_float16 x) {
  return _simd_tgamma_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_tgamma(simd_float16 x) {
  return simd_make_float16(__tg_tgamma(x.lo), __tg_tgamma(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_tgamma_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_tgamma(simd_double2 x) {
  return _simd_tgamma_d2(x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_tgamma(simd_double2 x) {
  return simd_make_double2(tgamma(x.x), tgamma(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_tgamma(simd_double3 x) {
  return simd_make_double3(__tg_tgamma(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_tgamma_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_tgamma(simd_double4 x) {
  return _simd_tgamma_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_tgamma(simd_double4 x) {
  return simd_make_double4(__tg_tgamma(x.lo), __tg_tgamma(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_tgamma_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_tgamma(simd_double8 x) {
  return _simd_tgamma_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_tgamma(simd_double8 x) {
  return simd_make_double8(__tg_tgamma(x.lo), __tg_tgamma(x.hi));
}
#endif

#pragma mark - round implementation
static inline SIMD_CFUNC simd_float2 __tg_round(simd_float2 x) {
  return simd_make_float2(__tg_round(simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_round(simd_float3 x) {
  return simd_make_float3(__tg_round(simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_round_f4(simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_round(simd_float4 x) {
#if defined __arm64__
  return vrndaq_f32(x);
#else
  return _simd_round_f4(x);
#endif
}
#else
static inline SIMD_CFUNC simd_float4 __tg_round(simd_float4 x) {
  return simd_make_float4(round(x.x), round(x.y), round(x.z), round(x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_round_f8(simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_round(simd_float8 x) {
  return _simd_round_f8(x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_round(simd_float8 x) {
  return simd_make_float8(__tg_round(x.lo), __tg_round(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_round_f16(simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_round(simd_float16 x) {
  return _simd_round_f16(x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_round(simd_float16 x) {
  return simd_make_float16(__tg_round(x.lo), __tg_round(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_round_d2(simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_round(simd_double2 x) {
#if defined __arm64__
  return vrndaq_f64(x);
#else
  return _simd_round_d2(x);
#endif
}
#else
static inline SIMD_CFUNC simd_double2 __tg_round(simd_double2 x) {
  return simd_make_double2(round(x.x), round(x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_round(simd_double3 x) {
  return simd_make_double3(__tg_round(simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_round_d4(simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_round(simd_double4 x) {
  return _simd_round_d4(x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_round(simd_double4 x) {
  return simd_make_double4(__tg_round(x.lo), __tg_round(x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_round_d8(simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_round(simd_double8 x) {
  return _simd_round_d8(x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_round(simd_double8 x) {
  return simd_make_double8(__tg_round(x.lo), __tg_round(x.hi));
}
#endif

#pragma mark - atan2 implementation
static inline SIMD_CFUNC simd_float2 __tg_atan2(simd_float2 y, simd_float2 x) {
  return simd_make_float2(__tg_atan2(simd_make_float4(y), simd_make_float4(x)));
}

static inline SIMD_CFUNC simd_float3 __tg_atan2(simd_float3 y, simd_float3 x) {
  return simd_make_float3(__tg_atan2(simd_make_float4(y), simd_make_float4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_atan2_f4(simd_float4 y, simd_float4 x);
static inline SIMD_CFUNC simd_float4 __tg_atan2(simd_float4 y, simd_float4 x) {
  return _simd_atan2_f4(y, x);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_atan2(simd_float4 y, simd_float4 x) {
  return simd_make_float4(atan2(y.x, x.x), atan2(y.y, x.y), atan2(y.z, x.z), atan2(y.w, x.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_atan2_f8(simd_float8 y, simd_float8 x);
static inline SIMD_CFUNC simd_float8 __tg_atan2(simd_float8 y, simd_float8 x) {
  return _simd_atan2_f8(y, x);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_atan2(simd_float8 y, simd_float8 x) {
  return simd_make_float8(__tg_atan2(y.lo, x.lo), __tg_atan2(y.hi, x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_atan2_f16(simd_float16 y, simd_float16 x);
static inline SIMD_CFUNC simd_float16 __tg_atan2(simd_float16 y, simd_float16 x) {
  return _simd_atan2_f16(y, x);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_atan2(simd_float16 y, simd_float16 x) {
  return simd_make_float16(__tg_atan2(y.lo, x.lo), __tg_atan2(y.hi, x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_atan2_d2(simd_double2 y, simd_double2 x);
static inline SIMD_CFUNC simd_double2 __tg_atan2(simd_double2 y, simd_double2 x) {
  return _simd_atan2_d2(y, x);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_atan2(simd_double2 y, simd_double2 x) {
  return simd_make_double2(atan2(y.x, x.x), atan2(y.y, x.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_atan2(simd_double3 y, simd_double3 x) {
  return simd_make_double3(__tg_atan2(simd_make_double4(y), simd_make_double4(x)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_atan2_d4(simd_double4 y, simd_double4 x);
static inline SIMD_CFUNC simd_double4 __tg_atan2(simd_double4 y, simd_double4 x) {
  return _simd_atan2_d4(y, x);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_atan2(simd_double4 y, simd_double4 x) {
  return simd_make_double4(__tg_atan2(y.lo, x.lo), __tg_atan2(y.hi, x.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_atan2_d8(simd_double8 y, simd_double8 x);
static inline SIMD_CFUNC simd_double8 __tg_atan2(simd_double8 y, simd_double8 x) {
  return _simd_atan2_d8(y, x);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_atan2(simd_double8 y, simd_double8 x) {
  return simd_make_double8(__tg_atan2(y.lo, x.lo), __tg_atan2(y.hi, x.hi));
}
#endif

#pragma mark - hypot implementation
static inline SIMD_CFUNC simd_float2 __tg_hypot(simd_float2 x, simd_float2 y) {
  return simd_make_float2(__tg_hypot(simd_make_float4(x), simd_make_float4(y)));
}

static inline SIMD_CFUNC simd_float3 __tg_hypot(simd_float3 x, simd_float3 y) {
  return simd_make_float3(__tg_hypot(simd_make_float4(x), simd_make_float4(y)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_hypot_f4(simd_float4 x, simd_float4 y);
static inline SIMD_CFUNC simd_float4 __tg_hypot(simd_float4 x, simd_float4 y) {
  return _simd_hypot_f4(x, y);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_hypot(simd_float4 x, simd_float4 y) {
  return simd_make_float4(hypot(x.x, y.x), hypot(x.y, y.y), hypot(x.z, y.z), hypot(x.w, y.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_hypot_f8(simd_float8 x, simd_float8 y);
static inline SIMD_CFUNC simd_float8 __tg_hypot(simd_float8 x, simd_float8 y) {
  return _simd_hypot_f8(x, y);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_hypot(simd_float8 x, simd_float8 y) {
  return simd_make_float8(__tg_hypot(x.lo, y.lo), __tg_hypot(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_hypot_f16(simd_float16 x, simd_float16 y);
static inline SIMD_CFUNC simd_float16 __tg_hypot(simd_float16 x, simd_float16 y) {
  return _simd_hypot_f16(x, y);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_hypot(simd_float16 x, simd_float16 y) {
  return simd_make_float16(__tg_hypot(x.lo, y.lo), __tg_hypot(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_hypot_d2(simd_double2 x, simd_double2 y);
static inline SIMD_CFUNC simd_double2 __tg_hypot(simd_double2 x, simd_double2 y) {
  return _simd_hypot_d2(x, y);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_hypot(simd_double2 x, simd_double2 y) {
  return simd_make_double2(hypot(x.x, y.x), hypot(x.y, y.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_hypot(simd_double3 x, simd_double3 y) {
  return simd_make_double3(__tg_hypot(simd_make_double4(x), simd_make_double4(y)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_hypot_d4(simd_double4 x, simd_double4 y);
static inline SIMD_CFUNC simd_double4 __tg_hypot(simd_double4 x, simd_double4 y) {
  return _simd_hypot_d4(x, y);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_hypot(simd_double4 x, simd_double4 y) {
  return simd_make_double4(__tg_hypot(x.lo, y.lo), __tg_hypot(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_hypot_d8(simd_double8 x, simd_double8 y);
static inline SIMD_CFUNC simd_double8 __tg_hypot(simd_double8 x, simd_double8 y) {
  return _simd_hypot_d8(x, y);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_hypot(simd_double8 x, simd_double8 y) {
  return simd_make_double8(__tg_hypot(x.lo, y.lo), __tg_hypot(x.hi, y.hi));
}
#endif

#pragma mark - pow implementation
static inline SIMD_CFUNC simd_float2 __tg_pow(simd_float2 x, simd_float2 y) {
  return simd_make_float2(__tg_pow(simd_make_float4(x), simd_make_float4(y)));
}

static inline SIMD_CFUNC simd_float3 __tg_pow(simd_float3 x, simd_float3 y) {
  return simd_make_float3(__tg_pow(simd_make_float4(x), simd_make_float4(y)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_pow_f4(simd_float4 x, simd_float4 y);
static inline SIMD_CFUNC simd_float4 __tg_pow(simd_float4 x, simd_float4 y) {
  return _simd_pow_f4(x, y);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_pow(simd_float4 x, simd_float4 y) {
  return simd_make_float4(pow(x.x, y.x), pow(x.y, y.y), pow(x.z, y.z), pow(x.w, y.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_pow_f8(simd_float8 x, simd_float8 y);
static inline SIMD_CFUNC simd_float8 __tg_pow(simd_float8 x, simd_float8 y) {
  return _simd_pow_f8(x, y);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_pow(simd_float8 x, simd_float8 y) {
  return simd_make_float8(__tg_pow(x.lo, y.lo), __tg_pow(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_pow_f16(simd_float16 x, simd_float16 y);
static inline SIMD_CFUNC simd_float16 __tg_pow(simd_float16 x, simd_float16 y) {
  return _simd_pow_f16(x, y);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_pow(simd_float16 x, simd_float16 y) {
  return simd_make_float16(__tg_pow(x.lo, y.lo), __tg_pow(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_pow_d2(simd_double2 x, simd_double2 y);
static inline SIMD_CFUNC simd_double2 __tg_pow(simd_double2 x, simd_double2 y) {
  return _simd_pow_d2(x, y);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_pow(simd_double2 x, simd_double2 y) {
  return simd_make_double2(pow(x.x, y.x), pow(x.y, y.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_pow(simd_double3 x, simd_double3 y) {
  return simd_make_double3(__tg_pow(simd_make_double4(x), simd_make_double4(y)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_pow_d4(simd_double4 x, simd_double4 y);
static inline SIMD_CFUNC simd_double4 __tg_pow(simd_double4 x, simd_double4 y) {
  return _simd_pow_d4(x, y);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_pow(simd_double4 x, simd_double4 y) {
  return simd_make_double4(__tg_pow(x.lo, y.lo), __tg_pow(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_pow_d8(simd_double8 x, simd_double8 y);
static inline SIMD_CFUNC simd_double8 __tg_pow(simd_double8 x, simd_double8 y) {
  return _simd_pow_d8(x, y);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_pow(simd_double8 x, simd_double8 y) {
  return simd_make_double8(__tg_pow(x.lo, y.lo), __tg_pow(x.hi, y.hi));
}
#endif

#pragma mark - fmod implementation
static inline SIMD_CFUNC simd_float2 __tg_fmod(simd_float2 x, simd_float2 y) {
  return simd_make_float2(__tg_fmod(simd_make_float4(x), simd_make_float4(y)));
}

static inline SIMD_CFUNC simd_float3 __tg_fmod(simd_float3 x, simd_float3 y) {
  return simd_make_float3(__tg_fmod(simd_make_float4(x), simd_make_float4(y)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_fmod_f4(simd_float4 x, simd_float4 y);
static inline SIMD_CFUNC simd_float4 __tg_fmod(simd_float4 x, simd_float4 y) {
  return _simd_fmod_f4(x, y);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_fmod(simd_float4 x, simd_float4 y) {
  return simd_make_float4(fmod(x.x, y.x), fmod(x.y, y.y), fmod(x.z, y.z), fmod(x.w, y.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_fmod_f8(simd_float8 x, simd_float8 y);
static inline SIMD_CFUNC simd_float8 __tg_fmod(simd_float8 x, simd_float8 y) {
  return _simd_fmod_f8(x, y);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_fmod(simd_float8 x, simd_float8 y) {
  return simd_make_float8(__tg_fmod(x.lo, y.lo), __tg_fmod(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_fmod_f16(simd_float16 x, simd_float16 y);
static inline SIMD_CFUNC simd_float16 __tg_fmod(simd_float16 x, simd_float16 y) {
  return _simd_fmod_f16(x, y);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_fmod(simd_float16 x, simd_float16 y) {
  return simd_make_float16(__tg_fmod(x.lo, y.lo), __tg_fmod(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_fmod_d2(simd_double2 x, simd_double2 y);
static inline SIMD_CFUNC simd_double2 __tg_fmod(simd_double2 x, simd_double2 y) {
  return _simd_fmod_d2(x, y);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_fmod(simd_double2 x, simd_double2 y) {
  return simd_make_double2(fmod(x.x, y.x), fmod(x.y, y.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_fmod(simd_double3 x, simd_double3 y) {
  return simd_make_double3(__tg_fmod(simd_make_double4(x), simd_make_double4(y)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_fmod_d4(simd_double4 x, simd_double4 y);
static inline SIMD_CFUNC simd_double4 __tg_fmod(simd_double4 x, simd_double4 y) {
  return _simd_fmod_d4(x, y);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_fmod(simd_double4 x, simd_double4 y) {
  return simd_make_double4(__tg_fmod(x.lo, y.lo), __tg_fmod(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_fmod_d8(simd_double8 x, simd_double8 y);
static inline SIMD_CFUNC simd_double8 __tg_fmod(simd_double8 x, simd_double8 y) {
  return _simd_fmod_d8(x, y);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_fmod(simd_double8 x, simd_double8 y) {
  return simd_make_double8(__tg_fmod(x.lo, y.lo), __tg_fmod(x.hi, y.hi));
}
#endif

#pragma mark - remainder implementation
static inline SIMD_CFUNC simd_float2 __tg_remainder(simd_float2 x, simd_float2 y) {
  return simd_make_float2(__tg_remainder(simd_make_float4(x), simd_make_float4(y)));
}

static inline SIMD_CFUNC simd_float3 __tg_remainder(simd_float3 x, simd_float3 y) {
  return simd_make_float3(__tg_remainder(simd_make_float4(x), simd_make_float4(y)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_remainder_f4(simd_float4 x, simd_float4 y);
static inline SIMD_CFUNC simd_float4 __tg_remainder(simd_float4 x, simd_float4 y) {
  return _simd_remainder_f4(x, y);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_remainder(simd_float4 x, simd_float4 y) {
  return simd_make_float4(remainder(x.x, y.x), remainder(x.y, y.y), remainder(x.z, y.z), remainder(x.w, y.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_remainder_f8(simd_float8 x, simd_float8 y);
static inline SIMD_CFUNC simd_float8 __tg_remainder(simd_float8 x, simd_float8 y) {
  return _simd_remainder_f8(x, y);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_remainder(simd_float8 x, simd_float8 y) {
  return simd_make_float8(__tg_remainder(x.lo, y.lo), __tg_remainder(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_remainder_f16(simd_float16 x, simd_float16 y);
static inline SIMD_CFUNC simd_float16 __tg_remainder(simd_float16 x, simd_float16 y) {
  return _simd_remainder_f16(x, y);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_remainder(simd_float16 x, simd_float16 y) {
  return simd_make_float16(__tg_remainder(x.lo, y.lo), __tg_remainder(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_remainder_d2(simd_double2 x, simd_double2 y);
static inline SIMD_CFUNC simd_double2 __tg_remainder(simd_double2 x, simd_double2 y) {
  return _simd_remainder_d2(x, y);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_remainder(simd_double2 x, simd_double2 y) {
  return simd_make_double2(remainder(x.x, y.x), remainder(x.y, y.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_remainder(simd_double3 x, simd_double3 y) {
  return simd_make_double3(__tg_remainder(simd_make_double4(x), simd_make_double4(y)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_remainder_d4(simd_double4 x, simd_double4 y);
static inline SIMD_CFUNC simd_double4 __tg_remainder(simd_double4 x, simd_double4 y) {
  return _simd_remainder_d4(x, y);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_remainder(simd_double4 x, simd_double4 y) {
  return simd_make_double4(__tg_remainder(x.lo, y.lo), __tg_remainder(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_remainder_d8(simd_double8 x, simd_double8 y);
static inline SIMD_CFUNC simd_double8 __tg_remainder(simd_double8 x, simd_double8 y) {
  return _simd_remainder_d8(x, y);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_remainder(simd_double8 x, simd_double8 y) {
  return simd_make_double8(__tg_remainder(x.lo, y.lo), __tg_remainder(x.hi, y.hi));
}
#endif

#pragma mark - nextafter implementation
static inline SIMD_CFUNC simd_float2 __tg_nextafter(simd_float2 x, simd_float2 y) {
  return simd_make_float2(__tg_nextafter(simd_make_float4(x), simd_make_float4(y)));
}

static inline SIMD_CFUNC simd_float3 __tg_nextafter(simd_float3 x, simd_float3 y) {
  return simd_make_float3(__tg_nextafter(simd_make_float4(x), simd_make_float4(y)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_nextafter_f4(simd_float4 x, simd_float4 y);
static inline SIMD_CFUNC simd_float4 __tg_nextafter(simd_float4 x, simd_float4 y) {
  return _simd_nextafter_f4(x, y);
}
#else
static inline SIMD_CFUNC simd_float4 __tg_nextafter(simd_float4 x, simd_float4 y) {
  return simd_make_float4(nextafter(x.x, y.x), nextafter(x.y, y.y), nextafter(x.z, y.z), nextafter(x.w, y.w));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_float8 _simd_nextafter_f8(simd_float8 x, simd_float8 y);
static inline SIMD_CFUNC simd_float8 __tg_nextafter(simd_float8 x, simd_float8 y) {
  return _simd_nextafter_f8(x, y);
}
#else
static inline SIMD_CFUNC simd_float8 __tg_nextafter(simd_float8 x, simd_float8 y) {
  return simd_make_float8(__tg_nextafter(x.lo, y.lo), __tg_nextafter(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_float16 _simd_nextafter_f16(simd_float16 x, simd_float16 y);
static inline SIMD_CFUNC simd_float16 __tg_nextafter(simd_float16 x, simd_float16 y) {
  return _simd_nextafter_f16(x, y);
}
#else
static inline SIMD_CFUNC simd_float16 __tg_nextafter(simd_float16 x, simd_float16 y) {
  return simd_make_float16(__tg_nextafter(x.lo, y.lo), __tg_nextafter(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_nextafter_d2(simd_double2 x, simd_double2 y);
static inline SIMD_CFUNC simd_double2 __tg_nextafter(simd_double2 x, simd_double2 y) {
  return _simd_nextafter_d2(x, y);
}
#else
static inline SIMD_CFUNC simd_double2 __tg_nextafter(simd_double2 x, simd_double2 y) {
  return simd_make_double2(nextafter(x.x, y.x), nextafter(x.y, y.y));
}
#endif

static inline SIMD_CFUNC simd_double3 __tg_nextafter(simd_double3 x, simd_double3 y) {
  return simd_make_double3(__tg_nextafter(simd_make_double4(x), simd_make_double4(y)));
}

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX2__
extern simd_double4 _simd_nextafter_d4(simd_double4 x, simd_double4 y);
static inline SIMD_CFUNC simd_double4 __tg_nextafter(simd_double4 x, simd_double4 y) {
  return _simd_nextafter_d4(x, y);
}
#else
static inline SIMD_CFUNC simd_double4 __tg_nextafter(simd_double4 x, simd_double4 y) {
  return simd_make_double4(__tg_nextafter(x.lo, y.lo), __tg_nextafter(x.hi, y.hi));
}
#endif

#if SIMD_LIBRARY_VERSION >= 3 && defined __x86_64__ && defined __AVX512F__
extern simd_double8 _simd_nextafter_d8(simd_double8 x, simd_double8 y);
static inline SIMD_CFUNC simd_double8 __tg_nextafter(simd_double8 x, simd_double8 y) {
  return _simd_nextafter_d8(x, y);
}
#else
static inline SIMD_CFUNC simd_double8 __tg_nextafter(simd_double8 x, simd_double8 y) {
  return simd_make_double8(__tg_nextafter(x.lo, y.lo), __tg_nextafter(x.hi, y.hi));
}
#endif

static inline SIMD_CFUNC simd_float2 __tg_fdim(simd_float2 x, simd_float2 y) { return simd_bitselect(x-y, 0, x<y); }
static inline SIMD_CFUNC simd_float3 __tg_fdim(simd_float3 x, simd_float3 y) { return simd_bitselect(x-y, 0, x<y); }
static inline SIMD_CFUNC simd_float4 __tg_fdim(simd_float4 x, simd_float4 y) { return simd_bitselect(x-y, 0, x<y); }
static inline SIMD_CFUNC simd_float8 __tg_fdim(simd_float8 x, simd_float8 y) { return simd_bitselect(x-y, 0, x<y); }
static inline SIMD_CFUNC simd_float16 __tg_fdim(simd_float16 x, simd_float16 y) { return simd_bitselect(x-y, 0, x<y); }
static inline SIMD_CFUNC simd_double2 __tg_fdim(simd_double2 x, simd_double2 y) { return simd_bitselect(x-y, 0, x<y); }
static inline SIMD_CFUNC simd_double3 __tg_fdim(simd_double3 x, simd_double3 y) { return simd_bitselect(x-y, 0, x<y); }
static inline SIMD_CFUNC simd_double4 __tg_fdim(simd_double4 x, simd_double4 y) { return simd_bitselect(x-y, 0, x<y); }
static inline SIMD_CFUNC simd_double8 __tg_fdim(simd_double8 x, simd_double8 y) { return simd_bitselect(x-y, 0, x<y); }
 
static inline SIMD_CFUNC simd_float2 __tg_fma(simd_float2 x, simd_float2 y, simd_float2 z) {
#if defined __arm64__ || defined __ARM_VFPV4__
  return vfma_f32(z, x, y);
#else
  return simd_make_float2(__tg_fma(simd_make_float4_undef(x), simd_make_float4_undef(y), simd_make_float4_undef(z)));
#endif
}

static inline SIMD_CFUNC simd_float3 __tg_fma(simd_float3 x, simd_float3 y, simd_float3 z) {
  return simd_make_float3(__tg_fma(simd_make_float4(x), simd_make_float4(y), simd_make_float4(z)));
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_float4 _simd_fma_f4(simd_float4 x, simd_float4 y, simd_float4 z);
#endif
static inline SIMD_CFUNC simd_float4 __tg_fma(simd_float4 x, simd_float4 y, simd_float4 z) {
#if defined __arm64__ || defined __ARM_VFPV4__
  return vfmaq_f32(z, x, y);
#elif (defined __i386__ || defined __x86_64__) && defined __FMA__
  return _mm_fmadd_ps(x, y, z);
#elif SIMD_LIBRARY_VERSION >= 3
  return _simd_fma_f4(x, y, z);
#else
  return simd_make_float4(fma(x.x, y.x, z.x), fma(x.y, y.y, z.y), fma(x.z, y.z, z.z), fma(x.w, y.w, z.w));
#endif
}

static inline SIMD_CFUNC simd_float8 __tg_fma(simd_float8 x, simd_float8 y, simd_float8 z) {
#if (defined __i386__ || defined __x86_64__) && defined __FMA__
  return _mm256_fmadd_ps(x, y, z);
#else
  return simd_make_float8(__tg_fma(x.lo, y.lo, z.lo), __tg_fma(x.hi, y.hi, z.hi));
#endif
}

static inline SIMD_CFUNC simd_float16 __tg_fma(simd_float16 x, simd_float16 y, simd_float16 z) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_fmadd_ps(x, y, z);
#else
  return simd_make_float16(__tg_fma(x.lo, y.lo, z.lo), __tg_fma(x.hi, y.hi, z.hi));
#endif
}

#if SIMD_LIBRARY_VERSION >= 3
extern simd_double2 _simd_fma_d2(simd_double2 x, simd_double2 y, simd_double2 z);
#endif
static inline SIMD_CFUNC simd_double2 __tg_fma(simd_double2 x, simd_double2 y, simd_double2 z) {
#if defined __arm64__
  return vfmaq_f64(z, x, y);
#elif (defined __i386__ || defined __x86_64__) && defined __FMA__
  return _mm_fmadd_pd(x, y, z);
#elif SIMD_LIBRARY_VERSION >= 3
  return _simd_fma_d2(x, y, z);
#else
  return simd_make_double2(fma(x.x, y.x, z.x), fma(x.y, y.y, z.y));
#endif
}

static inline SIMD_CFUNC simd_double3 __tg_fma(simd_double3 x, simd_double3 y, simd_double3 z) {
  return simd_make_double3(__tg_fma(simd_make_double4(x), simd_make_double4(y), simd_make_double4(z)));
}

static inline SIMD_CFUNC simd_double4 __tg_fma(simd_double4 x, simd_double4 y, simd_double4 z) {
#if (defined __i386__ || defined __x86_64__) && defined __FMA__
  return _mm256_fmadd_pd(x, y, z);
#else
  return simd_make_double4(__tg_fma(x.lo, y.lo, z.lo), __tg_fma(x.hi, y.hi, z.hi));
#endif
}

static inline SIMD_CFUNC simd_double8 __tg_fma(simd_double8 x, simd_double8 y, simd_double8 z) {
#if defined __x86_64__ && defined __AVX512F__
  return _mm512_fmadd_pd(x, y, z);
#else
  return simd_make_double8(__tg_fma(x.lo, y.lo, z.lo), __tg_fma(x.hi, y.hi, z.hi));
#endif
}

static inline SIMD_CFUNC float simd_muladd(float x, float y, float z) {
#pragma STDC FP_CONTRACT ON
  return x*y + z;
}
static inline SIMD_CFUNC simd_float2 simd_muladd(simd_float2 x, simd_float2 y, simd_float2 z) {
#pragma STDC FP_CONTRACT ON
  return x*y + z;
}
static inline SIMD_CFUNC simd_float3 simd_muladd(simd_float3 x, simd_float3 y, simd_float3 z) {
#pragma STDC FP_CONTRACT ON
  return x*y + z;
}
static inline SIMD_CFUNC simd_float4 simd_muladd(simd_float4 x, simd_float4 y, simd_float4 z) {
#pragma STDC FP_CONTRACT ON
  return x*y + z;
}
static inline SIMD_CFUNC simd_float8 simd_muladd(simd_float8 x, simd_float8 y, simd_float8 z) {
#pragma STDC FP_CONTRACT ON
  return x*y + z;
}
static inline SIMD_CFUNC simd_float16 simd_muladd(simd_float16 x, simd_float16 y, simd_float16 z) {
#pragma STDC FP_CONTRACT ON
  return x*y + z;
}
static inline SIMD_CFUNC double simd_muladd(double x, double y, double z) {
#pragma STDC FP_CONTRACT ON
  return x*y + z;
}
static inline SIMD_CFUNC simd_double2 simd_muladd(simd_double2 x, simd_double2 y, simd_double2 z) {
#pragma STDC FP_CONTRACT ON
  return x*y + z;
}
static inline SIMD_CFUNC simd_double3 simd_muladd(simd_double3 x, simd_double3 y, simd_double3 z) {
#pragma STDC FP_CONTRACT ON
  return x*y + z;
}
static inline SIMD_CFUNC simd_double4 simd_muladd(simd_double4 x, simd_double4 y, simd_double4 z) {
#pragma STDC FP_CONTRACT ON
  return x*y + z;
}
static inline SIMD_CFUNC simd_double8 simd_muladd(simd_double8 x, simd_double8 y, simd_double8 z) {
#pragma STDC FP_CONTRACT ON
  return x*y + z;
}
#ifdef __cplusplus
}      /* extern "C" */
#endif
#endif /* SIMD_COMPILER_HAS_REQUIRED_FEATURES */
#endif /* SIMD_MATH_HEADER */
