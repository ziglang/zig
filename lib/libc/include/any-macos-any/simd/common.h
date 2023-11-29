/*! @header
 *  The interfaces declared in this header provide "common" elementwise
 *  operations that are neither math nor logic functions.  These are available
 *  only for floating-point vectors and scalars, except for min, max, abs,
 *  clamp, and the reduce operations, which also support integer vectors.
 *
 *      simd_abs(x)             Absolute value of x.  Also available as fabs
 *                              for floating-point vectors.  If x is the
 *                              smallest signed integer, x is returned.
 *
 *      simd_max(x,y)           Returns the maximum of x and y.  Also available
 *                              as fmax for floating-point vectors.
 *
 *      simd_min(x,y)           Returns the minimum of x and y.  Also available
 *                              as fmin for floating-point vectors.
 *
 *      simd_clamp(x,min,max)   x clamped to the range [min, max].
 *
 *      simd_sign(x)            -1 if x is less than zero, 0 if x is zero or
 *                              NaN, and +1 if x is greater than zero.
 *
 *      simd_mix(x,y,t)         If t is not in the range [0,1], the result is
 *      simd_lerp(x,y,t)        undefined.  Otherwise the result is x+(y-x)*t,
 *                              which linearly interpolates between x and y.
 *
 *      simd_recip(x)           An approximation to 1/x.  If x is very near the
 *                              limits of representable values, or is infinity
 *                              or NaN, the result is undefined.  There are
 *                              two variants of this function:
 *
 *                                  simd_precise_recip(x)
 *
 *                              and
 *
 *                                  simd_fast_recip(x).
 *
 *                              The "precise" variant is accurate to a few ULPs,
 *                              whereas the "fast" variant may have as little
 *                              as 11 bits of accuracy in float and about 22
 *                              bits in double.
 *
 *                              The function simd_recip(x) resolves to
 *                              simd_precise_recip(x) ordinarily, but to
 *                              simd_fast_recip(x) when used in a translation
 *                              unit compiled with -ffast-math (when
 *                              -ffast-math is in effect, you may still use the
 *                              precise version of this function by calling it
 *                              explicitly by name).
 *
 *      simd_rsqrt(x)           An approximation to 1/sqrt(x).  If x is
 *                              infinity or NaN, the result is undefined.
 *                              There are two variants of this function:
 *
 *                                  simd_precise_rsqrt(x)
 *
 *                              and
 *
 *                                  simd_fast_rsqrt(x).
 *
 *                              The "precise" variant is accurate to a few ULPs,
 *                              whereas the "fast" variant may have as little
 *                              as 11 bits of accuracy in float and about 22
 *                              bits in double.
 *
 *                              The function simd_rsqrt(x) resolves to
 *                              simd_precise_rsqrt(x) ordinarily, but to
 *                              simd_fast_rsqrt(x) when used in a translation
 *                              unit compiled with -ffast-math (when
 *                              -ffast-math is in effect, you may still use the
 *                              precise version of this function by calling it
 *                              explicitly by name).
 *
 *      simd_fract(x)           The "fractional part" of x, which lies strictly
 *                              in the range [0, 0x1.fffffep-1].
 *
 *      simd_step(edge,x)       0 if x < edge, and 1 otherwise.
 *
 *      simd_smoothstep(edge0,edge1,x) 0 if x <= edge0, 1 if x >= edge1, and
 *                              a Hermite interpolation between 0 and 1 if
 *                              edge0 < x < edge1.
 *
 *      simd_reduce_add(x)      Sum of the elements of x.
 *
 *      simd_reduce_min(x)      Minimum of the elements of x.
 *
 *      simd_reduce_max(x)      Maximum of the elements of x.
 *
 *      simd_equal(x,y)         True if and only if every lane of x is equal
 *                              to the corresponding lane of y.
 *
 *  The following common functions are available in the simd:: namespace:
 *
 *      C++ Function                    Equivalent C Function
 *      --------------------------------------------------------------------
 *      simd::abs(x)                    simd_abs(x)
 *      simd::max(x,y)                  simd_max(x,y)
 *      simd::min(x,y)                  simd_min(x,y)
 *      simd::clamp(x,min,max)          simd_clamp(x,min,max)
 *      simd::sign(x)                   simd_sign(x)
 *      simd::mix(x,y,t)                simd_mix(x,y,t)
 *      simd::lerp(x,y,t)               simd_lerp(x,y,t)
 *      simd::recip(x)                  simd_recip(x)
 *      simd::rsqrt(x)                  simd_rsqrt(x)
 *      simd::fract(x)                  simd_fract(x)
 *      simd::step(edge,x)              simd_step(edge,x)
 *      simd::smoothstep(e0,e1,x)       simd_smoothstep(e0,e1,x)
 *      simd::reduce_add(x)             simd_reduce_add(x)
 *      simd::reduce_max(x)             simd_reduce_max(x)
 *      simd::reduce_min(x)             simd_reduce_min(x)
 *      simd::equal(x,y)                simd_equal(x,y)
 *
 *      simd::precise::recip(x)         simd_precise_recip(x)
 *      simd::precise::rsqrt(x)         simd_precise_rsqrt(x)
 *
 *      simd::fast::recip(x)            simd_fast_recip(x)
 *      simd::fast::rsqrt(x)            simd_fast_rsqrt(x)
 *
 *  @copyright 2014-2017 Apple, Inc. All rights reserved.
 *  @unsorted                                                                 */

#ifndef SIMD_COMMON_HEADER
#define SIMD_COMMON_HEADER

#include <simd/base.h>
#if SIMD_COMPILER_HAS_REQUIRED_FEATURES
#include <simd/vector_make.h>
#include <simd/logic.h>
#include <simd/math.h>

#ifdef __cplusplus
extern "C" {
#endif

/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_char2 simd_abs(simd_char2 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_char3 simd_abs(simd_char3 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_char4 simd_abs(simd_char4 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_char8 simd_abs(simd_char8 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_char16 simd_abs(simd_char16 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_char32 simd_abs(simd_char32 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_char64 simd_abs(simd_char64 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_short2 simd_abs(simd_short2 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_short3 simd_abs(simd_short3 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_short4 simd_abs(simd_short4 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_short8 simd_abs(simd_short8 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_short16 simd_abs(simd_short16 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_short32 simd_abs(simd_short32 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_int2 simd_abs(simd_int2 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_int3 simd_abs(simd_int3 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_int4 simd_abs(simd_int4 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_int8 simd_abs(simd_int8 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_int16 simd_abs(simd_int16 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_float2 simd_abs(simd_float2 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_float3 simd_abs(simd_float3 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_float4 simd_abs(simd_float4 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_float8 simd_abs(simd_float8 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_float16 simd_abs(simd_float16 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_long2 simd_abs(simd_long2 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_long3 simd_abs(simd_long3 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_long4 simd_abs(simd_long4 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_long8 simd_abs(simd_long8 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_double2 simd_abs(simd_double2 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_double3 simd_abs(simd_double3 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_double4 simd_abs(simd_double4 x);
/*! @abstract The elementwise absolute value of x.                            */
static inline SIMD_CFUNC simd_double8 simd_abs(simd_double8 x);
/*! @abstract The elementwise absolute value of x.
 *  @discussion Deprecated. Use simd_abs(x) instead.                          */
#define vector_abs simd_abs
  
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_char2 simd_max(simd_char2 x, simd_char2 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_char3 simd_max(simd_char3 x, simd_char3 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_char4 simd_max(simd_char4 x, simd_char4 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_char8 simd_max(simd_char8 x, simd_char8 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_char16 simd_max(simd_char16 x, simd_char16 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_char32 simd_max(simd_char32 x, simd_char32 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_char64 simd_max(simd_char64 x, simd_char64 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uchar2 simd_max(simd_uchar2 x, simd_uchar2 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uchar3 simd_max(simd_uchar3 x, simd_uchar3 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uchar4 simd_max(simd_uchar4 x, simd_uchar4 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uchar8 simd_max(simd_uchar8 x, simd_uchar8 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uchar16 simd_max(simd_uchar16 x, simd_uchar16 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uchar32 simd_max(simd_uchar32 x, simd_uchar32 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uchar64 simd_max(simd_uchar64 x, simd_uchar64 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_short2 simd_max(simd_short2 x, simd_short2 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_short3 simd_max(simd_short3 x, simd_short3 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_short4 simd_max(simd_short4 x, simd_short4 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_short8 simd_max(simd_short8 x, simd_short8 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_short16 simd_max(simd_short16 x, simd_short16 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_short32 simd_max(simd_short32 x, simd_short32 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_ushort2 simd_max(simd_ushort2 x, simd_ushort2 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_ushort3 simd_max(simd_ushort3 x, simd_ushort3 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_ushort4 simd_max(simd_ushort4 x, simd_ushort4 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_ushort8 simd_max(simd_ushort8 x, simd_ushort8 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_ushort16 simd_max(simd_ushort16 x, simd_ushort16 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_ushort32 simd_max(simd_ushort32 x, simd_ushort32 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_int2 simd_max(simd_int2 x, simd_int2 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_int3 simd_max(simd_int3 x, simd_int3 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_int4 simd_max(simd_int4 x, simd_int4 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_int8 simd_max(simd_int8 x, simd_int8 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_int16 simd_max(simd_int16 x, simd_int16 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uint2 simd_max(simd_uint2 x, simd_uint2 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uint3 simd_max(simd_uint3 x, simd_uint3 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uint4 simd_max(simd_uint4 x, simd_uint4 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uint8 simd_max(simd_uint8 x, simd_uint8 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_uint16 simd_max(simd_uint16 x, simd_uint16 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC float simd_max(float x, float y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_float2 simd_max(simd_float2 x, simd_float2 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_float3 simd_max(simd_float3 x, simd_float3 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_float4 simd_max(simd_float4 x, simd_float4 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_float8 simd_max(simd_float8 x, simd_float8 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_float16 simd_max(simd_float16 x, simd_float16 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_long2 simd_max(simd_long2 x, simd_long2 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_long3 simd_max(simd_long3 x, simd_long3 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_long4 simd_max(simd_long4 x, simd_long4 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_long8 simd_max(simd_long8 x, simd_long8 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_ulong2 simd_max(simd_ulong2 x, simd_ulong2 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_ulong3 simd_max(simd_ulong3 x, simd_ulong3 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_ulong4 simd_max(simd_ulong4 x, simd_ulong4 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_ulong8 simd_max(simd_ulong8 x, simd_ulong8 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC double simd_max(double x, double y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_double2 simd_max(simd_double2 x, simd_double2 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_double3 simd_max(simd_double3 x, simd_double3 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_double4 simd_max(simd_double4 x, simd_double4 y);
/*! @abstract The elementwise maximum of x and y.                             */
static inline SIMD_CFUNC simd_double8 simd_max(simd_double8 x, simd_double8 y);
/*! @abstract The elementwise maximum of x and y.
 *  @discussion Deprecated. Use simd_max(x,y) instead.                        */
#define vector_max simd_max

/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_char2 simd_min(simd_char2 x, simd_char2 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_char3 simd_min(simd_char3 x, simd_char3 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_char4 simd_min(simd_char4 x, simd_char4 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_char8 simd_min(simd_char8 x, simd_char8 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_char16 simd_min(simd_char16 x, simd_char16 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_char32 simd_min(simd_char32 x, simd_char32 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_char64 simd_min(simd_char64 x, simd_char64 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uchar2 simd_min(simd_uchar2 x, simd_uchar2 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uchar3 simd_min(simd_uchar3 x, simd_uchar3 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uchar4 simd_min(simd_uchar4 x, simd_uchar4 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uchar8 simd_min(simd_uchar8 x, simd_uchar8 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uchar16 simd_min(simd_uchar16 x, simd_uchar16 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uchar32 simd_min(simd_uchar32 x, simd_uchar32 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uchar64 simd_min(simd_uchar64 x, simd_uchar64 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_short2 simd_min(simd_short2 x, simd_short2 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_short3 simd_min(simd_short3 x, simd_short3 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_short4 simd_min(simd_short4 x, simd_short4 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_short8 simd_min(simd_short8 x, simd_short8 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_short16 simd_min(simd_short16 x, simd_short16 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_short32 simd_min(simd_short32 x, simd_short32 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_ushort2 simd_min(simd_ushort2 x, simd_ushort2 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_ushort3 simd_min(simd_ushort3 x, simd_ushort3 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_ushort4 simd_min(simd_ushort4 x, simd_ushort4 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_ushort8 simd_min(simd_ushort8 x, simd_ushort8 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_ushort16 simd_min(simd_ushort16 x, simd_ushort16 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_ushort32 simd_min(simd_ushort32 x, simd_ushort32 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_int2 simd_min(simd_int2 x, simd_int2 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_int3 simd_min(simd_int3 x, simd_int3 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_int4 simd_min(simd_int4 x, simd_int4 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_int8 simd_min(simd_int8 x, simd_int8 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_int16 simd_min(simd_int16 x, simd_int16 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uint2 simd_min(simd_uint2 x, simd_uint2 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uint3 simd_min(simd_uint3 x, simd_uint3 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uint4 simd_min(simd_uint4 x, simd_uint4 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uint8 simd_min(simd_uint8 x, simd_uint8 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_uint16 simd_min(simd_uint16 x, simd_uint16 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC float simd_min(float x, float y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_float2 simd_min(simd_float2 x, simd_float2 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_float3 simd_min(simd_float3 x, simd_float3 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_float4 simd_min(simd_float4 x, simd_float4 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_float8 simd_min(simd_float8 x, simd_float8 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_float16 simd_min(simd_float16 x, simd_float16 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_long2 simd_min(simd_long2 x, simd_long2 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_long3 simd_min(simd_long3 x, simd_long3 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_long4 simd_min(simd_long4 x, simd_long4 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_long8 simd_min(simd_long8 x, simd_long8 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_ulong2 simd_min(simd_ulong2 x, simd_ulong2 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_ulong3 simd_min(simd_ulong3 x, simd_ulong3 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_ulong4 simd_min(simd_ulong4 x, simd_ulong4 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_ulong8 simd_min(simd_ulong8 x, simd_ulong8 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC double simd_min(double x, double y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_double2 simd_min(simd_double2 x, simd_double2 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_double3 simd_min(simd_double3 x, simd_double3 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_double4 simd_min(simd_double4 x, simd_double4 y);
/*! @abstract The elementwise minimum of x and y.                             */
static inline SIMD_CFUNC simd_double8 simd_min(simd_double8 x, simd_double8 y);
/*! @abstract The elementwise minimum of x and y.
 *  @discussion Deprecated. Use simd_min(x,y) instead.                        */
#define vector_min simd_min

  
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_char2 simd_clamp(simd_char2 x, simd_char2 min, simd_char2 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_char3 simd_clamp(simd_char3 x, simd_char3 min, simd_char3 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_char4 simd_clamp(simd_char4 x, simd_char4 min, simd_char4 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_char8 simd_clamp(simd_char8 x, simd_char8 min, simd_char8 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_char16 simd_clamp(simd_char16 x, simd_char16 min, simd_char16 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_char32 simd_clamp(simd_char32 x, simd_char32 min, simd_char32 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_char64 simd_clamp(simd_char64 x, simd_char64 min, simd_char64 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uchar2 simd_clamp(simd_uchar2 x, simd_uchar2 min, simd_uchar2 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uchar3 simd_clamp(simd_uchar3 x, simd_uchar3 min, simd_uchar3 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uchar4 simd_clamp(simd_uchar4 x, simd_uchar4 min, simd_uchar4 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uchar8 simd_clamp(simd_uchar8 x, simd_uchar8 min, simd_uchar8 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uchar16 simd_clamp(simd_uchar16 x, simd_uchar16 min, simd_uchar16 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uchar32 simd_clamp(simd_uchar32 x, simd_uchar32 min, simd_uchar32 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uchar64 simd_clamp(simd_uchar64 x, simd_uchar64 min, simd_uchar64 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_short2 simd_clamp(simd_short2 x, simd_short2 min, simd_short2 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_short3 simd_clamp(simd_short3 x, simd_short3 min, simd_short3 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_short4 simd_clamp(simd_short4 x, simd_short4 min, simd_short4 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_short8 simd_clamp(simd_short8 x, simd_short8 min, simd_short8 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_short16 simd_clamp(simd_short16 x, simd_short16 min, simd_short16 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_short32 simd_clamp(simd_short32 x, simd_short32 min, simd_short32 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_ushort2 simd_clamp(simd_ushort2 x, simd_ushort2 min, simd_ushort2 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_ushort3 simd_clamp(simd_ushort3 x, simd_ushort3 min, simd_ushort3 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_ushort4 simd_clamp(simd_ushort4 x, simd_ushort4 min, simd_ushort4 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_ushort8 simd_clamp(simd_ushort8 x, simd_ushort8 min, simd_ushort8 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_ushort16 simd_clamp(simd_ushort16 x, simd_ushort16 min, simd_ushort16 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_ushort32 simd_clamp(simd_ushort32 x, simd_ushort32 min, simd_ushort32 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_int2 simd_clamp(simd_int2 x, simd_int2 min, simd_int2 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_int3 simd_clamp(simd_int3 x, simd_int3 min, simd_int3 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_int4 simd_clamp(simd_int4 x, simd_int4 min, simd_int4 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_int8 simd_clamp(simd_int8 x, simd_int8 min, simd_int8 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_int16 simd_clamp(simd_int16 x, simd_int16 min, simd_int16 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uint2 simd_clamp(simd_uint2 x, simd_uint2 min, simd_uint2 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uint3 simd_clamp(simd_uint3 x, simd_uint3 min, simd_uint3 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uint4 simd_clamp(simd_uint4 x, simd_uint4 min, simd_uint4 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uint8 simd_clamp(simd_uint8 x, simd_uint8 min, simd_uint8 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_uint16 simd_clamp(simd_uint16 x, simd_uint16 min, simd_uint16 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC float simd_clamp(float x, float min, float max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_float2 simd_clamp(simd_float2 x, simd_float2 min, simd_float2 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_float3 simd_clamp(simd_float3 x, simd_float3 min, simd_float3 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_float4 simd_clamp(simd_float4 x, simd_float4 min, simd_float4 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_float8 simd_clamp(simd_float8 x, simd_float8 min, simd_float8 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_float16 simd_clamp(simd_float16 x, simd_float16 min, simd_float16 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_long2 simd_clamp(simd_long2 x, simd_long2 min, simd_long2 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_long3 simd_clamp(simd_long3 x, simd_long3 min, simd_long3 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_long4 simd_clamp(simd_long4 x, simd_long4 min, simd_long4 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_long8 simd_clamp(simd_long8 x, simd_long8 min, simd_long8 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_ulong2 simd_clamp(simd_ulong2 x, simd_ulong2 min, simd_ulong2 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_ulong3 simd_clamp(simd_ulong3 x, simd_ulong3 min, simd_ulong3 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_ulong4 simd_clamp(simd_ulong4 x, simd_ulong4 min, simd_ulong4 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_ulong8 simd_clamp(simd_ulong8 x, simd_ulong8 min, simd_ulong8 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC double simd_clamp(double x, double min, double max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_double2 simd_clamp(simd_double2 x, simd_double2 min, simd_double2 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_double3 simd_clamp(simd_double3 x, simd_double3 min, simd_double3 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_double4 simd_clamp(simd_double4 x, simd_double4 min, simd_double4 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Note that if you want to clamp all lanes to the same range,
 *  you can use a scalar value for min and max.                               */
static inline SIMD_CFUNC simd_double8 simd_clamp(simd_double8 x, simd_double8 min, simd_double8 max);
/*! @abstract x clamped to the range [min, max].
 *  @discussion Deprecated. Use simd_clamp(x,min,max) instead.                */
#define vector_clamp simd_clamp
  
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.      */
static inline SIMD_CFUNC float simd_sign(float x);
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.      */
static inline SIMD_CFUNC simd_float2 simd_sign(simd_float2 x);
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.      */
static inline SIMD_CFUNC simd_float3 simd_sign(simd_float3 x);
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.      */
static inline SIMD_CFUNC simd_float4 simd_sign(simd_float4 x);
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.      */
static inline SIMD_CFUNC simd_float8 simd_sign(simd_float8 x);
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.      */
static inline SIMD_CFUNC simd_float16 simd_sign(simd_float16 x);
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.      */
static inline SIMD_CFUNC double simd_sign(double x);
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.      */
static inline SIMD_CFUNC simd_double2 simd_sign(simd_double2 x);
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.      */
static inline SIMD_CFUNC simd_double3 simd_sign(simd_double3 x);
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.      */
static inline SIMD_CFUNC simd_double4 simd_sign(simd_double4 x);
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.      */
static inline SIMD_CFUNC simd_double8 simd_sign(simd_double8 x);
/*! @abstract -1 if x is negative, +1 if x is positive, and 0 otherwise.
 *  @discussion Deprecated. Use simd_sign(x) instead.                         */
#define vector_sign simd_sign

/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1                                                        */
static inline SIMD_CFUNC float simd_mix(float x, float y, float t);
/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1                                                        */
static inline SIMD_CFUNC simd_float2 simd_mix(simd_float2 x, simd_float2 y, simd_float2 t);
/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1                                                        */
static inline SIMD_CFUNC simd_float3 simd_mix(simd_float3 x, simd_float3 y, simd_float3 t);
/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1                                                        */
static inline SIMD_CFUNC simd_float4 simd_mix(simd_float4 x, simd_float4 y, simd_float4 t);
/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1                                                        */
static inline SIMD_CFUNC simd_float8 simd_mix(simd_float8 x, simd_float8 y, simd_float8 t);
/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1                                                        */
static inline SIMD_CFUNC simd_float16 simd_mix(simd_float16 x, simd_float16 y, simd_float16 t);
/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1                                                        */
static inline SIMD_CFUNC double simd_mix(double x, double y, double t);
/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1                                                        */
static inline SIMD_CFUNC simd_double2 simd_mix(simd_double2 x, simd_double2 y, simd_double2 t);
/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1                                                        */
static inline SIMD_CFUNC simd_double3 simd_mix(simd_double3 x, simd_double3 y, simd_double3 t);
/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1                                                        */
static inline SIMD_CFUNC simd_double4 simd_mix(simd_double4 x, simd_double4 y, simd_double4 t);
/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1                                                        */
static inline SIMD_CFUNC simd_double8 simd_mix(simd_double8 x, simd_double8 y, simd_double8 t);
/*! @abstract Linearly interpolates between x and y, taking the value x when
 *  t=0 and y when t=1
 *  @discussion Deprecated. Use simd_mix(x, y, t) instead.                    */
#define vector_mix simd_mix
#define simd_lerp simd_mix

/*! @abstract A good approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  a few units in the last place (ULPs).                                     */
static inline SIMD_CFUNC float simd_precise_recip(float x);
/*! @abstract A good approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  a few units in the last place (ULPs).                                     */
static inline SIMD_CFUNC simd_float2 simd_precise_recip(simd_float2 x);
/*! @abstract A good approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  a few units in the last place (ULPs).                                     */
static inline SIMD_CFUNC simd_float3 simd_precise_recip(simd_float3 x);
/*! @abstract A good approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  a few units in the last place (ULPs).                                     */
static inline SIMD_CFUNC simd_float4 simd_precise_recip(simd_float4 x);
/*! @abstract A good approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  a few units in the last place (ULPs).                                     */
static inline SIMD_CFUNC simd_float8 simd_precise_recip(simd_float8 x);
/*! @abstract A good approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  a few units in the last place (ULPs).                                     */
static inline SIMD_CFUNC simd_float16 simd_precise_recip(simd_float16 x);
/*! @abstract A good approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  a few units in the last place (ULPs).                                     */
static inline SIMD_CFUNC double simd_precise_recip(double x);
/*! @abstract A good approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  a few units in the last place (ULPs).                                     */
static inline SIMD_CFUNC simd_double2 simd_precise_recip(simd_double2 x);
/*! @abstract A good approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  a few units in the last place (ULPs).                                     */
static inline SIMD_CFUNC simd_double3 simd_precise_recip(simd_double3 x);
/*! @abstract A good approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  a few units in the last place (ULPs).                                     */
static inline SIMD_CFUNC simd_double4 simd_precise_recip(simd_double4 x);
/*! @abstract A good approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  a few units in the last place (ULPs).                                     */
static inline SIMD_CFUNC simd_double8 simd_precise_recip(simd_double8 x);
/*! @abstract A good approximation to 1/x.
 *  @discussion Deprecated. Use simd_precise_recip(x) instead.                */
#define vector_precise_recip simd_precise_recip

/*! @abstract A fast approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  at least 11 bits for float and 22 bits for double.                        */
static inline SIMD_CFUNC float simd_fast_recip(float x);
/*! @abstract A fast approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  at least 11 bits for float and 22 bits for double.                        */
static inline SIMD_CFUNC simd_float2 simd_fast_recip(simd_float2 x);
/*! @abstract A fast approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  at least 11 bits for float and 22 bits for double.                        */
static inline SIMD_CFUNC simd_float3 simd_fast_recip(simd_float3 x);
/*! @abstract A fast approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  at least 11 bits for float and 22 bits for double.                        */
static inline SIMD_CFUNC simd_float4 simd_fast_recip(simd_float4 x);
/*! @abstract A fast approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  at least 11 bits for float and 22 bits for double.                        */
static inline SIMD_CFUNC simd_float8 simd_fast_recip(simd_float8 x);
/*! @abstract A fast approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  at least 11 bits for float and 22 bits for double.                        */
static inline SIMD_CFUNC simd_float16 simd_fast_recip(simd_float16 x);
/*! @abstract A fast approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  at least 11 bits for float and 22 bits for double.                        */
static inline SIMD_CFUNC double simd_fast_recip(double x);
/*! @abstract A fast approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  at least 11 bits for float and 22 bits for double.                        */
static inline SIMD_CFUNC simd_double2 simd_fast_recip(simd_double2 x);
/*! @abstract A fast approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  at least 11 bits for float and 22 bits for double.                        */
static inline SIMD_CFUNC simd_double3 simd_fast_recip(simd_double3 x);
/*! @abstract A fast approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  at least 11 bits for float and 22 bits for double.                        */
static inline SIMD_CFUNC simd_double4 simd_fast_recip(simd_double4 x);
/*! @abstract A fast approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow; otherwise this function is accurate to
 *  at least 11 bits for float and 22 bits for double.                        */
static inline SIMD_CFUNC simd_double8 simd_fast_recip(simd_double8 x);
/*! @abstract A fast approximation to 1/x.
 *  @discussion Deprecated. Use simd_fast_recip(x) instead.                   */
#define vector_fast_recip simd_fast_recip

/*! @abstract An approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow. This function maps to
 *  simd_fast_recip(x) if -ffast-math is specified, and to
 *  simd_precise_recip(x) otherwise.                                          */
static inline SIMD_CFUNC float simd_recip(float x);
/*! @abstract An approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow. This function maps to
 *  simd_fast_recip(x) if -ffast-math is specified, and to
 *  simd_precise_recip(x) otherwise.                                          */
static inline SIMD_CFUNC simd_float2 simd_recip(simd_float2 x);
/*! @abstract An approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow. This function maps to
 *  simd_fast_recip(x) if -ffast-math is specified, and to
 *  simd_precise_recip(x) otherwise.                                          */
static inline SIMD_CFUNC simd_float3 simd_recip(simd_float3 x);
/*! @abstract An approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow. This function maps to
 *  simd_fast_recip(x) if -ffast-math is specified, and to
 *  simd_precise_recip(x) otherwise.                                          */
static inline SIMD_CFUNC simd_float4 simd_recip(simd_float4 x);
/*! @abstract An approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow. This function maps to
 *  simd_fast_recip(x) if -ffast-math is specified, and to
 *  simd_precise_recip(x) otherwise.                                          */
static inline SIMD_CFUNC simd_float8 simd_recip(simd_float8 x);
/*! @abstract An approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow. This function maps to
 *  simd_fast_recip(x) if -ffast-math is specified, and to
 *  simd_precise_recip(x) otherwise.                                          */
static inline SIMD_CFUNC simd_float16 simd_recip(simd_float16 x);
/*! @abstract An approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow. This function maps to
 *  simd_fast_recip(x) if -ffast-math is specified, and to
 *  simd_precise_recip(x) otherwise.                                          */
static inline SIMD_CFUNC double simd_recip(double x);
/*! @abstract An approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow. This function maps to
 *  simd_fast_recip(x) if -ffast-math is specified, and to
 *  simd_precise_recip(x) otherwise.                                          */
static inline SIMD_CFUNC simd_double2 simd_recip(simd_double2 x);
/*! @abstract An approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow. This function maps to
 *  simd_fast_recip(x) if -ffast-math is specified, and to
 *  simd_precise_recip(x) otherwise.                                          */
static inline SIMD_CFUNC simd_double3 simd_recip(simd_double3 x);
/*! @abstract An approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow. This function maps to
 *  simd_fast_recip(x) if -ffast-math is specified, and to
 *  simd_precise_recip(x) otherwise.                                          */
static inline SIMD_CFUNC simd_double4 simd_recip(simd_double4 x);
/*! @abstract An approximation to 1/x.
 *  @discussion If x is very close to the limits of representation, the
 *  result may overflow or underflow. This function maps to
 *  simd_fast_recip(x) if -ffast-math is specified, and to
 *  simd_precise_recip(x) otherwise.                                          */
static inline SIMD_CFUNC simd_double8 simd_recip(simd_double8 x);
/*! @abstract An approximation to 1/x.
 *  @discussion Deprecated. Use simd_recip(x) instead.                        */
#define vector_recip simd_recip

/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion This function is accurate to a few units in the last place
 *  (ULPs).                                                                   */
static inline SIMD_CFUNC float simd_precise_rsqrt(float x);
/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion This function is accurate to a few units in the last place
 *  (ULPs).                                                                   */
static inline SIMD_CFUNC simd_float2 simd_precise_rsqrt(simd_float2 x);
/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion This function is accurate to a few units in the last place
 *  (ULPs).                                                                   */
static inline SIMD_CFUNC simd_float3 simd_precise_rsqrt(simd_float3 x);
/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion This function is accurate to a few units in the last place
 *  (ULPs).                                                                   */
static inline SIMD_CFUNC simd_float4 simd_precise_rsqrt(simd_float4 x);
/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion This function is accurate to a few units in the last place
 *  (ULPs).                                                                   */
static inline SIMD_CFUNC simd_float8 simd_precise_rsqrt(simd_float8 x);
/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion This function is accurate to a few units in the last place
 *  (ULPs).                                                                   */
static inline SIMD_CFUNC simd_float16 simd_precise_rsqrt(simd_float16 x);
/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion This function is accurate to a few units in the last place
 *  (ULPs).                                                                   */
static inline SIMD_CFUNC double simd_precise_rsqrt(double x);
/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion This function is accurate to a few units in the last place
 *  (ULPs).                                                                   */
static inline SIMD_CFUNC simd_double2 simd_precise_rsqrt(simd_double2 x);
/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion This function is accurate to a few units in the last place
 *  (ULPs).                                                                   */
static inline SIMD_CFUNC simd_double3 simd_precise_rsqrt(simd_double3 x);
/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion This function is accurate to a few units in the last place
 *  (ULPs).                                                                   */
static inline SIMD_CFUNC simd_double4 simd_precise_rsqrt(simd_double4 x);
/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion This function is accurate to a few units in the last place
 *  (ULPs).                                                                   */
static inline SIMD_CFUNC simd_double8 simd_precise_rsqrt(simd_double8 x);
/*! @abstract A good approximation to 1/sqrt(x).
 *  @discussion Deprecated. Use simd_precise_rsqrt(x) instead.                */
#define vector_precise_rsqrt simd_precise_rsqrt

/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion This function is accurate to at least 11 bits for float and
 *  22 bits for double.                                                       */
static inline SIMD_CFUNC float simd_fast_rsqrt(float x);
/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion This function is accurate to at least 11 bits for float and
 *  22 bits for double.                                                       */
static inline SIMD_CFUNC simd_float2 simd_fast_rsqrt(simd_float2 x);
/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion This function is accurate to at least 11 bits for float and
 *  22 bits for double.                                                       */
static inline SIMD_CFUNC simd_float3 simd_fast_rsqrt(simd_float3 x);
/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion This function is accurate to at least 11 bits for float and
 *  22 bits for double.                                                       */
static inline SIMD_CFUNC simd_float4 simd_fast_rsqrt(simd_float4 x);
/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion This function is accurate to at least 11 bits for float and
 *  22 bits for double.                                                       */
static inline SIMD_CFUNC simd_float8 simd_fast_rsqrt(simd_float8 x);
/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion This function is accurate to at least 11 bits for float and
 *  22 bits for double.                                                       */
static inline SIMD_CFUNC simd_float16 simd_fast_rsqrt(simd_float16 x);
/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion This function is accurate to at least 11 bits for float and
 *  22 bits for double.                                                       */
static inline SIMD_CFUNC double simd_fast_rsqrt(double x);
/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion This function is accurate to at least 11 bits for float and
 *  22 bits for double.                                                       */
static inline SIMD_CFUNC simd_double2 simd_fast_rsqrt(simd_double2 x);
/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion This function is accurate to at least 11 bits for float and
 *  22 bits for double.                                                       */
static inline SIMD_CFUNC simd_double3 simd_fast_rsqrt(simd_double3 x);
/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion This function is accurate to at least 11 bits for float and
 *  22 bits for double.                                                       */
static inline SIMD_CFUNC simd_double4 simd_fast_rsqrt(simd_double4 x);
/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion This function is accurate to at least 11 bits for float and
 *  22 bits for double.                                                       */
static inline SIMD_CFUNC simd_double8 simd_fast_rsqrt(simd_double8 x);
/*! @abstract A fast approximation to 1/sqrt(x).
 *  @discussion Deprecated. Use simd_fast_rsqrt(x) instead.                   */
#define vector_fast_rsqrt simd_fast_rsqrt

/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion This function maps to simd_fast_recip(x) if -ffast-math is
 *  specified, and to simd_precise_recip(x) otherwise.                        */
static inline SIMD_CFUNC float simd_rsqrt(float x);
/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion This function maps to simd_fast_recip(x) if -ffast-math is
 *  specified, and to simd_precise_recip(x) otherwise.                        */
static inline SIMD_CFUNC simd_float2 simd_rsqrt(simd_float2 x);
/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion This function maps to simd_fast_recip(x) if -ffast-math is
 *  specified, and to simd_precise_recip(x) otherwise.                        */
static inline SIMD_CFUNC simd_float3 simd_rsqrt(simd_float3 x);
/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion This function maps to simd_fast_recip(x) if -ffast-math is
 *  specified, and to simd_precise_recip(x) otherwise.                        */
static inline SIMD_CFUNC simd_float4 simd_rsqrt(simd_float4 x);
/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion This function maps to simd_fast_recip(x) if -ffast-math is
 *  specified, and to simd_precise_recip(x) otherwise.                        */
static inline SIMD_CFUNC simd_float8 simd_rsqrt(simd_float8 x);
/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion This function maps to simd_fast_recip(x) if -ffast-math is
 *  specified, and to simd_precise_recip(x) otherwise.                        */
static inline SIMD_CFUNC simd_float16 simd_rsqrt(simd_float16 x);
/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion This function maps to simd_fast_recip(x) if -ffast-math is
 *  specified, and to simd_precise_recip(x) otherwise.                        */
static inline SIMD_CFUNC double simd_rsqrt(double x);
/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion This function maps to simd_fast_recip(x) if -ffast-math is
 *  specified, and to simd_precise_recip(x) otherwise.                        */
static inline SIMD_CFUNC simd_double2 simd_rsqrt(simd_double2 x);
/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion This function maps to simd_fast_recip(x) if -ffast-math is
 *  specified, and to simd_precise_recip(x) otherwise.                        */
static inline SIMD_CFUNC simd_double3 simd_rsqrt(simd_double3 x);
/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion This function maps to simd_fast_recip(x) if -ffast-math is
 *  specified, and to simd_precise_recip(x) otherwise.                        */
static inline SIMD_CFUNC simd_double4 simd_rsqrt(simd_double4 x);
/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion This function maps to simd_fast_recip(x) if -ffast-math is
 *  specified, and to simd_precise_recip(x) otherwise.                        */
static inline SIMD_CFUNC simd_double8 simd_rsqrt(simd_double8 x);
/*! @abstract An approximation to 1/sqrt(x).
 *  @discussion Deprecated. Use simd_rsqrt(x) instead.                        */
#define vector_rsqrt simd_rsqrt

/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion floor(x) + fract(x) is *approximately* equal to x. If x is
 *  positive and finite, then the two values are exactly equal.               */
static inline SIMD_CFUNC float simd_fract(float x);
/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion floor(x) + fract(x) is *approximately* equal to x. If x is
 *  positive and finite, then the two values are exactly equal.               */
static inline SIMD_CFUNC simd_float2 simd_fract(simd_float2 x);
/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion floor(x) + fract(x) is *approximately* equal to x. If x is
 *  positive and finite, then the two values are exactly equal.               */
static inline SIMD_CFUNC simd_float3 simd_fract(simd_float3 x);
/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion floor(x) + fract(x) is *approximately* equal to x. If x is
 *  positive and finite, then the two values are exactly equal.               */
static inline SIMD_CFUNC simd_float4 simd_fract(simd_float4 x);
/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion floor(x) + fract(x) is *approximately* equal to x. If x is
 *  positive and finite, then the two values are exactly equal.               */
static inline SIMD_CFUNC simd_float8 simd_fract(simd_float8 x);
/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion floor(x) + fract(x) is *approximately* equal to x. If x is
 *  positive and finite, then the two values are exactly equal.               */
static inline SIMD_CFUNC simd_float16 simd_fract(simd_float16 x);
/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion floor(x) + fract(x) is *approximately* equal to x. If x is
 *  positive and finite, then the two values are exactly equal.               */
static inline SIMD_CFUNC double simd_fract(double x);
/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion floor(x) + fract(x) is *approximately* equal to x. If x is
 *  positive and finite, then the two values are exactly equal.               */
static inline SIMD_CFUNC simd_double2 simd_fract(simd_double2 x);
/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion floor(x) + fract(x) is *approximately* equal to x. If x is
 *  positive and finite, then the two values are exactly equal.               */
static inline SIMD_CFUNC simd_double3 simd_fract(simd_double3 x);
/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion floor(x) + fract(x) is *approximately* equal to x. If x is
 *  positive and finite, then the two values are exactly equal.               */
static inline SIMD_CFUNC simd_double4 simd_fract(simd_double4 x);
/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion floor(x) + fract(x) is *approximately* equal to x. If x is
 *  positive and finite, then the two values are exactly equal.               */
static inline SIMD_CFUNC simd_double8 simd_fract(simd_double8 x);
/*! @abstract The "fractional part" of x, lying in the range [0, 1).
 *  @discussion Deprecated. Use simd_fract(x) instead.                        */
#define vector_fract simd_fract

/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Use a scalar value for edge if you want to apply the same
 *  threshold to all lanes.                                                   */
static inline SIMD_CFUNC float simd_step(float edge, float x);
/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Use a scalar value for edge if you want to apply the same
 *  threshold to all lanes.                                                   */
static inline SIMD_CFUNC simd_float2 simd_step(simd_float2 edge, simd_float2 x);
/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Use a scalar value for edge if you want to apply the same
 *  threshold to all lanes.                                                   */
static inline SIMD_CFUNC simd_float3 simd_step(simd_float3 edge, simd_float3 x);
/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Use a scalar value for edge if you want to apply the same
 *  threshold to all lanes.                                                   */
static inline SIMD_CFUNC simd_float4 simd_step(simd_float4 edge, simd_float4 x);
/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Use a scalar value for edge if you want to apply the same
 *  threshold to all lanes.                                                   */
static inline SIMD_CFUNC simd_float8 simd_step(simd_float8 edge, simd_float8 x);
/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Use a scalar value for edge if you want to apply the same
 *  threshold to all lanes.                                                   */
static inline SIMD_CFUNC simd_float16 simd_step(simd_float16 edge, simd_float16 x);
/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Use a scalar value for edge if you want to apply the same
 *  threshold to all lanes.                                                   */
static inline SIMD_CFUNC double simd_step(double edge, double x);
/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Use a scalar value for edge if you want to apply the same
 *  threshold to all lanes.                                                   */
static inline SIMD_CFUNC simd_double2 simd_step(simd_double2 edge, simd_double2 x);
/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Use a scalar value for edge if you want to apply the same
 *  threshold to all lanes.                                                   */
static inline SIMD_CFUNC simd_double3 simd_step(simd_double3 edge, simd_double3 x);
/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Use a scalar value for edge if you want to apply the same
 *  threshold to all lanes.                                                   */
static inline SIMD_CFUNC simd_double4 simd_step(simd_double4 edge, simd_double4 x);
/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Use a scalar value for edge if you want to apply the same
 *  threshold to all lanes.                                                   */
static inline SIMD_CFUNC simd_double8 simd_step(simd_double8 edge, simd_double8 x);
/*! @abstract 0 if x < edge, and 1 otherwise.
 *  @discussion Deprecated. Use simd_step(edge, x) instead.                   */
#define vector_step simd_step

/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion You can use a scalar value for edge0 and edge1 if you want
 *  to clamp all lanes at the same points.                                    */
static inline SIMD_CFUNC float simd_smoothstep(float edge0, float edge1, float x);
/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion You can use a scalar value for edge0 and edge1 if you want
 *  to clamp all lanes at the same points.                                    */
static inline SIMD_CFUNC simd_float2 simd_smoothstep(simd_float2 edge0, simd_float2 edge1, simd_float2 x);
/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion You can use a scalar value for edge0 and edge1 if you want
 *  to clamp all lanes at the same points.                                    */
static inline SIMD_CFUNC simd_float3 simd_smoothstep(simd_float3 edge0, simd_float3 edge1, simd_float3 x);
/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion You can use a scalar value for edge0 and edge1 if you want
 *  to clamp all lanes at the same points.                                    */
static inline SIMD_CFUNC simd_float4 simd_smoothstep(simd_float4 edge0, simd_float4 edge1, simd_float4 x);
/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion You can use a scalar value for edge0 and edge1 if you want
 *  to clamp all lanes at the same points.                                    */
static inline SIMD_CFUNC simd_float8 simd_smoothstep(simd_float8 edge0, simd_float8 edge1, simd_float8 x);
/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion You can use a scalar value for edge0 and edge1 if you want
 *  to clamp all lanes at the same points.                                    */
static inline SIMD_CFUNC simd_float16 simd_smoothstep(simd_float16 edge0, simd_float16 edge1, simd_float16 x);
/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion You can use a scalar value for edge0 and edge1 if you want
 *  to clamp all lanes at the same points.                                    */
static inline SIMD_CFUNC double simd_smoothstep(double edge0, double edge1, double x);
/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion You can use a scalar value for edge0 and edge1 if you want
 *  to clamp all lanes at the same points.                                    */
static inline SIMD_CFUNC simd_double2 simd_smoothstep(simd_double2 edge0, simd_double2 edge1, simd_double2 x);
/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion You can use a scalar value for edge0 and edge1 if you want
 *  to clamp all lanes at the same points.                                    */
static inline SIMD_CFUNC simd_double3 simd_smoothstep(simd_double3 edge0, simd_double3 edge1, simd_double3 x);
/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion You can use a scalar value for edge0 and edge1 if you want
 *  to clamp all lanes at the same points.                                    */
static inline SIMD_CFUNC simd_double4 simd_smoothstep(simd_double4 edge0, simd_double4 edge1, simd_double4 x);
/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion You can use a scalar value for edge0 and edge1 if you want
 *  to clamp all lanes at the same points.                                    */
static inline SIMD_CFUNC simd_double8 simd_smoothstep(simd_double8 edge0, simd_double8 edge1, simd_double8 x);
/*! @abstract Interpolates smoothly between 0 at edge0 and 1 at edge1
 *  @discussion Deprecated. Use simd_smoothstep(edge0, edge1, x) instead.     */
#define vector_smoothstep simd_smoothstep

/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC char simd_reduce_add(simd_char2 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC char simd_reduce_add(simd_char3 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC char simd_reduce_add(simd_char4 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC char simd_reduce_add(simd_char8 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC char simd_reduce_add(simd_char16 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC char simd_reduce_add(simd_char32 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC char simd_reduce_add(simd_char64 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar2 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar3 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar4 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar8 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar16 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar32 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar64 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC short simd_reduce_add(simd_short2 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC short simd_reduce_add(simd_short3 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC short simd_reduce_add(simd_short4 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC short simd_reduce_add(simd_short8 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC short simd_reduce_add(simd_short16 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC short simd_reduce_add(simd_short32 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort2 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort3 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort4 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort8 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort16 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort32 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC int simd_reduce_add(simd_int2 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC int simd_reduce_add(simd_int3 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC int simd_reduce_add(simd_int4 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC int simd_reduce_add(simd_int8 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC int simd_reduce_add(simd_int16 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned int simd_reduce_add(simd_uint2 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned int simd_reduce_add(simd_uint3 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned int simd_reduce_add(simd_uint4 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned int simd_reduce_add(simd_uint8 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC unsigned int simd_reduce_add(simd_uint16 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC float simd_reduce_add(simd_float2 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC float simd_reduce_add(simd_float3 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC float simd_reduce_add(simd_float4 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC float simd_reduce_add(simd_float8 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC float simd_reduce_add(simd_float16 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC simd_long1 simd_reduce_add(simd_long2 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC simd_long1 simd_reduce_add(simd_long3 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC simd_long1 simd_reduce_add(simd_long4 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC simd_long1 simd_reduce_add(simd_long8 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_add(simd_ulong2 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_add(simd_ulong3 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_add(simd_ulong4 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_add(simd_ulong8 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC double simd_reduce_add(simd_double2 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC double simd_reduce_add(simd_double3 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC double simd_reduce_add(simd_double4 x);
/*! @abstract Sum of elements in x.
 *  @discussion This computation may overflow; especial for 8-bit types you
 *  may need to convert to a wider type before reducing.                      */
static inline SIMD_CFUNC double simd_reduce_add(simd_double8 x);
/*! @abstract Sum of elements in x.
 *  @discussion Deprecated. Use simd_add(x) instead.                          */
#define vector_reduce_add simd_reduce_add
  
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_min(simd_char2 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_min(simd_char3 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_min(simd_char4 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_min(simd_char8 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_min(simd_char16 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_min(simd_char32 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_min(simd_char64 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar2 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar3 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar4 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar8 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar16 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar32 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar64 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_min(simd_short2 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_min(simd_short3 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_min(simd_short4 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_min(simd_short8 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_min(simd_short16 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_min(simd_short32 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort2 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort3 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort4 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort8 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort16 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort32 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC int simd_reduce_min(simd_int2 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC int simd_reduce_min(simd_int3 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC int simd_reduce_min(simd_int4 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC int simd_reduce_min(simd_int8 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC int simd_reduce_min(simd_int16 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned int simd_reduce_min(simd_uint2 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned int simd_reduce_min(simd_uint3 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned int simd_reduce_min(simd_uint4 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned int simd_reduce_min(simd_uint8 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC unsigned int simd_reduce_min(simd_uint16 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC float simd_reduce_min(simd_float2 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC float simd_reduce_min(simd_float3 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC float simd_reduce_min(simd_float4 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC float simd_reduce_min(simd_float8 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC float simd_reduce_min(simd_float16 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC simd_long1 simd_reduce_min(simd_long2 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC simd_long1 simd_reduce_min(simd_long3 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC simd_long1 simd_reduce_min(simd_long4 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC simd_long1 simd_reduce_min(simd_long8 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_min(simd_ulong2 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_min(simd_ulong3 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_min(simd_ulong4 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_min(simd_ulong8 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC double simd_reduce_min(simd_double2 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC double simd_reduce_min(simd_double3 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC double simd_reduce_min(simd_double4 x);
/*! @abstract Minimum of elements in x.                                       */
static inline SIMD_CFUNC double simd_reduce_min(simd_double8 x);
/*! @abstract Minimum of elements in x.
 *  @discussion Deprecated. Use simd_min(x) instead.                          */
#define vector_reduce_min simd_reduce_min
  
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_max(simd_char2 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_max(simd_char3 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_max(simd_char4 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_max(simd_char8 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_max(simd_char16 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_max(simd_char32 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC char simd_reduce_max(simd_char64 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar2 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar3 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar4 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar8 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar16 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar32 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar64 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_max(simd_short2 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_max(simd_short3 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_max(simd_short4 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_max(simd_short8 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_max(simd_short16 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC short simd_reduce_max(simd_short32 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort2 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort3 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort4 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort8 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort16 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort32 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC int simd_reduce_max(simd_int2 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC int simd_reduce_max(simd_int3 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC int simd_reduce_max(simd_int4 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC int simd_reduce_max(simd_int8 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC int simd_reduce_max(simd_int16 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned int simd_reduce_max(simd_uint2 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned int simd_reduce_max(simd_uint3 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned int simd_reduce_max(simd_uint4 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned int simd_reduce_max(simd_uint8 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC unsigned int simd_reduce_max(simd_uint16 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC float simd_reduce_max(simd_float2 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC float simd_reduce_max(simd_float3 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC float simd_reduce_max(simd_float4 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC float simd_reduce_max(simd_float8 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC float simd_reduce_max(simd_float16 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC simd_long1 simd_reduce_max(simd_long2 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC simd_long1 simd_reduce_max(simd_long3 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC simd_long1 simd_reduce_max(simd_long4 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC simd_long1 simd_reduce_max(simd_long8 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_max(simd_ulong2 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_max(simd_ulong3 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_max(simd_ulong4 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC simd_ulong1 simd_reduce_max(simd_ulong8 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC double simd_reduce_max(simd_double2 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC double simd_reduce_max(simd_double3 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC double simd_reduce_max(simd_double4 x);
/*! @abstract Maximum of elements in x.                                       */
static inline SIMD_CFUNC double simd_reduce_max(simd_double8 x);
/*! @abstract Maximum of elements in x.
 *  @discussion Deprecated. Use simd_max(x) instead.                          */
#define vector_reduce_max simd_reduce_max
  
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_char2 x, simd_char2 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_char3 x, simd_char3 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_char4 x, simd_char4 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_char8 x, simd_char8 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_char16 x, simd_char16 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_char32 x, simd_char32 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_char64 x, simd_char64 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uchar2 x, simd_uchar2 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uchar3 x, simd_uchar3 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uchar4 x, simd_uchar4 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uchar8 x, simd_uchar8 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uchar16 x, simd_uchar16 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uchar32 x, simd_uchar32 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uchar64 x, simd_uchar64 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_short2 x, simd_short2 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_short3 x, simd_short3 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_short4 x, simd_short4 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_short8 x, simd_short8 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_short16 x, simd_short16 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_short32 x, simd_short32 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_ushort2 x, simd_ushort2 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_ushort3 x, simd_ushort3 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_ushort4 x, simd_ushort4 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_ushort8 x, simd_ushort8 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_ushort16 x, simd_ushort16 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_ushort32 x, simd_ushort32 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_int2 x, simd_int2 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_int3 x, simd_int3 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_int4 x, simd_int4 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_int8 x, simd_int8 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_int16 x, simd_int16 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uint2 x, simd_uint2 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uint3 x, simd_uint3 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uint4 x, simd_uint4 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uint8 x, simd_uint8 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_uint16 x, simd_uint16 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_float2 x, simd_float2 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_float3 x, simd_float3 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_float4 x, simd_float4 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_float8 x, simd_float8 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_float16 x, simd_float16 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_long2 x, simd_long2 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_long3 x, simd_long3 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_long4 x, simd_long4 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_long8 x, simd_long8 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_ulong2 x, simd_ulong2 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_ulong3 x, simd_ulong3 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_ulong4 x, simd_ulong4 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_ulong8 x, simd_ulong8 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_double2 x, simd_double2 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_double3 x, simd_double3 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_double4 x, simd_double4 y) {
  return simd_all(x == y);
}
/*! @abstract True if and only if each lane of x is equal to the
 *  corresponding lane of y.                                                  */
static inline SIMD_CFUNC simd_bool simd_equal(simd_double8 x, simd_double8 y) {
  return simd_all(x == y);
}
  
#ifdef __cplusplus
} /* extern "C" */

namespace simd {
  /*! @abstract The lanewise absolute value of x.                             */
  template <typename typeN> static SIMD_CPPFUNC typeN abs(const typeN x) { return ::simd_abs(x); }
  /*! @abstract The lanewise maximum of x and y.                              */
  template <typename typeN> static SIMD_CPPFUNC typeN max(const typeN x, const typeN y) { return ::simd_max(x,y); }
  /*! @abstract The lanewise minimum of x and y.                              */
  template <typename typeN> static SIMD_CPPFUNC typeN min(const typeN x, const typeN y) { return ::simd_min(x,y); }
  /*! @abstract x clamped to the interval [min, max].                         */
  template <typename typeN> static SIMD_CPPFUNC typeN clamp(const typeN x, const typeN min, const typeN max) { return ::simd_clamp(x,min,max); }
  /*! @abstract -1 if x < 0, +1 if x > 0, and 0 otherwise.                    */
  template <typename fptypeN> static SIMD_CPPFUNC fptypeN sign(const fptypeN x) { return ::simd_sign(x); }
  /*! @abstract Linearly interpolates between x and y, taking the value x when t=0 and y when t=1 */
  template <typename fptypeN> static SIMD_CPPFUNC fptypeN mix(const fptypeN x, const fptypeN y, const fptypeN t) { return ::simd_mix(x,y,t); }
  template <typename fptypeN> static SIMD_CPPFUNC fptypeN lerp(const fptypeN x, const fptypeN y, const fptypeN t) { return ::simd_mix(x,y,t); }
  /*! @abstract An approximation to 1/x.                                      */
  template <typename fptypeN> static SIMD_CPPFUNC fptypeN recip(const fptypeN x) { return simd_recip(x); }
  /*! @abstract An approximation to 1/sqrt(x).                                */
  template <typename fptypeN> static SIMD_CPPFUNC fptypeN rsqrt(const fptypeN x) { return simd_rsqrt(x); }
  /*! @abstract The "fracional part" of x, in the range [0,1).                */
  template <typename fptypeN> static SIMD_CPPFUNC fptypeN fract(const fptypeN x) { return ::simd_fract(x); }
  /*! @abstract 0 if x < edge, 1 otherwise.                                   */
  template <typename fptypeN> static SIMD_CPPFUNC fptypeN step(const fptypeN edge, const fptypeN x) { return ::simd_step(edge,x); }
  /*! @abstract smoothly interpolates from 0 at edge0 to 1 at edge1.          */
  template <typename fptypeN> static SIMD_CPPFUNC fptypeN smoothstep(const fptypeN edge0, const fptypeN edge1, const fptypeN x) { return ::simd_smoothstep(edge0,edge1,x); }
  /*! @abstract True if and only if each lane of x is equal to the
   *  corresponding lane of y.
   *
   *  @discussion This isn't operator== because that's already defined by
   *  the compiler to return a lane mask.                                     */
  template <typename fptypeN> static SIMD_CPPFUNC simd_bool equal(const fptypeN x, const fptypeN y) { return ::simd_equal(x, y); }
#if __cpp_decltype_auto
  /*  If you are targeting an earlier version of the C++ standard that lacks
   decltype_auto support, you may use the C-style simd_reduce_* functions
   instead.                                                                   */
  /*! @abstract The sum of the elements in x. May overflow.                   */
  template <typename typeN> static SIMD_CPPFUNC auto reduce_add(typeN x) { return ::simd_reduce_add(x); }
  /*! @abstract The least element in x.                                       */
  template <typename typeN> static SIMD_CPPFUNC auto reduce_min(typeN x) { return ::simd_reduce_min(x); }
  /*! @abstract The greatest element in x.                                    */
  template <typename typeN> static SIMD_CPPFUNC auto reduce_max(typeN x) { return ::simd_reduce_max(x); }
#endif
  namespace precise {
    /*! @abstract An approximation to 1/x.                                      */
    template <typename fptypeN> static SIMD_CPPFUNC fptypeN recip(const fptypeN x) { return ::simd_precise_recip(x); }
    /*! @abstract An approximation to 1/sqrt(x).                                */
    template <typename fptypeN> static SIMD_CPPFUNC fptypeN rsqrt(const fptypeN x) { return ::simd_precise_rsqrt(x); }
  }
  namespace fast {
    /*! @abstract An approximation to 1/x.                                      */
    template <typename fptypeN> static SIMD_CPPFUNC fptypeN recip(const fptypeN x) { return ::simd_fast_recip(x); }
    /*! @abstract An approximation to 1/sqrt(x).                                */
    template <typename fptypeN> static SIMD_CPPFUNC fptypeN rsqrt(const fptypeN x) { return ::simd_fast_rsqrt(x); }
  }
}

extern "C" {
#endif /* __cplusplus */

#pragma mark - Implementation

static inline SIMD_CFUNC simd_char2 simd_abs(simd_char2 x) {
  return simd_make_char2(simd_abs(simd_make_char8_undef(x)));
}

static inline SIMD_CFUNC simd_char3 simd_abs(simd_char3 x) {
  return simd_make_char3(simd_abs(simd_make_char8_undef(x)));
}

static inline SIMD_CFUNC simd_char4 simd_abs(simd_char4 x) {
  return simd_make_char4(simd_abs(simd_make_char8_undef(x)));
}

static inline SIMD_CFUNC simd_char8 simd_abs(simd_char8 x) {
#if defined __arm__ || defined __arm64__
  return vabs_s8(x);
#else
  return simd_make_char8(simd_abs(simd_make_char16_undef(x)));
#endif
}

static inline SIMD_CFUNC simd_char16 simd_abs(simd_char16 x) {
#if defined __arm__ || defined __arm64__
  return vabsq_s8(x);
#elif defined __SSE4_1__
  return (simd_char16) _mm_abs_epi8((__m128i)x);
#else
  simd_char16 mask = x >> 7; return (x ^ mask) - mask;
#endif
}

static inline SIMD_CFUNC simd_char32 simd_abs(simd_char32 x) {
#if defined __AVX2__
  return _mm256_abs_epi8(x);
#else
  return simd_make_char32(simd_abs(x.lo), simd_abs(x.hi));
#endif
}

static inline SIMD_CFUNC simd_char64 simd_abs(simd_char64 x) {
#if defined __AVX512BW__
  return _mm512_abs_epi8(x);
#else
  return simd_make_char64(simd_abs(x.lo), simd_abs(x.hi));
#endif
}

static inline SIMD_CFUNC simd_short2 simd_abs(simd_short2 x) {
  return simd_make_short2(simd_abs(simd_make_short4_undef(x)));
}

static inline SIMD_CFUNC simd_short3 simd_abs(simd_short3 x) {
  return simd_make_short3(simd_abs(simd_make_short4_undef(x)));
}

static inline SIMD_CFUNC simd_short4 simd_abs(simd_short4 x) {
#if defined __arm__ || defined __arm64__
  return vabs_s16(x);
#else
  return simd_make_short4(simd_abs(simd_make_short8_undef(x)));
#endif
}

static inline SIMD_CFUNC simd_short8 simd_abs(simd_short8 x) {
#if defined __arm__ || defined __arm64__
  return vabsq_s16(x);
#elif defined __SSE4_1__
  return (simd_short8) _mm_abs_epi16((__m128i)x);
#else
  simd_short8 mask = x >> 15; return (x ^ mask) - mask;
#endif
}

static inline SIMD_CFUNC simd_short16 simd_abs(simd_short16 x) {
#if defined __AVX2__
  return _mm256_abs_epi16(x);
#else
  return simd_make_short16(simd_abs(x.lo), simd_abs(x.hi));
#endif
}

static inline SIMD_CFUNC simd_short32 simd_abs(simd_short32 x) {
#if defined __AVX512BW__
  return _mm512_abs_epi16(x);
#else
  return simd_make_short32(simd_abs(x.lo), simd_abs(x.hi));
#endif
}

static inline SIMD_CFUNC simd_int2 simd_abs(simd_int2 x) {
#if defined __arm__ || defined __arm64__
  return vabs_s32(x);
#else
  return simd_make_int2(simd_abs(simd_make_int4_undef(x)));
#endif
}

static inline SIMD_CFUNC simd_int3 simd_abs(simd_int3 x) {
  return simd_make_int3(simd_abs(simd_make_int4_undef(x)));
}

static inline SIMD_CFUNC simd_int4 simd_abs(simd_int4 x) {
#if defined __arm__ || defined __arm64__
  return vabsq_s32(x);
#elif defined __SSE4_1__
  return (simd_int4) _mm_abs_epi32((__m128i)x);
#else
  simd_int4 mask = x >> 31; return (x ^ mask) - mask;
#endif
}

static inline SIMD_CFUNC simd_int8 simd_abs(simd_int8 x) {
#if defined __AVX2__
  return _mm256_abs_epi32(x);
#else
  return simd_make_int8(simd_abs(x.lo), simd_abs(x.hi));
#endif
}

static inline SIMD_CFUNC simd_int16 simd_abs(simd_int16 x) {
#if defined __AVX512F__
  return _mm512_abs_epi32(x);
#else
  return simd_make_int16(simd_abs(x.lo), simd_abs(x.hi));
#endif
}

static inline SIMD_CFUNC simd_float2 simd_abs(simd_float2 x) {
  return __tg_fabs(x);
}

static inline SIMD_CFUNC simd_float3 simd_abs(simd_float3 x) {
  return __tg_fabs(x);
}

static inline SIMD_CFUNC simd_float4 simd_abs(simd_float4 x) {
  return __tg_fabs(x);
}

static inline SIMD_CFUNC simd_float8 simd_abs(simd_float8 x) {
  return __tg_fabs(x);
}

static inline SIMD_CFUNC simd_float16 simd_abs(simd_float16 x) {
  return __tg_fabs(x);
}

static inline SIMD_CFUNC simd_long2 simd_abs(simd_long2 x) {
#if defined __arm64__
  return vabsq_s64(x);
#elif defined __AVX512VL__
  return (simd_long2) _mm_abs_epi64((__m128i)x);
#else
  simd_long2 mask = x >> 63; return (x ^ mask) - mask;
#endif
}

static inline SIMD_CFUNC simd_long3 simd_abs(simd_long3 x) {
  return simd_make_long3(simd_abs(simd_make_long4_undef(x)));
}

static inline SIMD_CFUNC simd_long4 simd_abs(simd_long4 x) {
#if defined __AVX512VL__
  return _mm256_abs_epi64(x);
#else
  return simd_make_long4(simd_abs(x.lo), simd_abs(x.hi));
#endif
}

static inline SIMD_CFUNC simd_long8 simd_abs(simd_long8 x) {
#if defined __AVX512F__
  return _mm512_abs_epi64(x);
#else
  return simd_make_long8(simd_abs(x.lo), simd_abs(x.hi));
#endif
}

static inline SIMD_CFUNC simd_double2 simd_abs(simd_double2 x) {
  return __tg_fabs(x);
}

static inline SIMD_CFUNC simd_double3 simd_abs(simd_double3 x) {
  return __tg_fabs(x);
}

static inline SIMD_CFUNC simd_double4 simd_abs(simd_double4 x) {
  return __tg_fabs(x);
}

static inline SIMD_CFUNC simd_double8 simd_abs(simd_double8 x) {
  return __tg_fabs(x);
}

static inline SIMD_CFUNC simd_char2 simd_min(simd_char2 x, simd_char2 y) {
  return simd_make_char2(simd_min(simd_make_char8_undef(x), simd_make_char8_undef(y)));
}

static inline SIMD_CFUNC simd_char3 simd_min(simd_char3 x, simd_char3 y) {
  return simd_make_char3(simd_min(simd_make_char8_undef(x), simd_make_char8_undef(y)));
}

static inline SIMD_CFUNC simd_char4 simd_min(simd_char4 x, simd_char4 y) {
  return simd_make_char4(simd_min(simd_make_char8_undef(x), simd_make_char8_undef(y)));
}

static inline SIMD_CFUNC simd_char8 simd_min(simd_char8 x, simd_char8 y) {
#if defined __arm__ || defined __arm64__
  return vmin_s8(x, y);
#else
  return simd_make_char8(simd_min(simd_make_char16_undef(x), simd_make_char16_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_char16 simd_min(simd_char16 x, simd_char16 y) {
#if defined __arm__ || defined __arm64__
  return vminq_s8(x, y);
#elif defined __SSE4_1__
  return (simd_char16) _mm_min_epi8((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_char32 simd_min(simd_char32 x, simd_char32 y) {
#if defined __AVX2__
  return _mm256_min_epi8(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_char64 simd_min(simd_char64 x, simd_char64 y) {
#if defined __AVX512BW__
  return _mm512_min_epi8(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_uchar2 simd_min(simd_uchar2 x, simd_uchar2 y) {
  return simd_make_uchar2(simd_min(simd_make_uchar8_undef(x), simd_make_uchar8_undef(y)));
}

static inline SIMD_CFUNC simd_uchar3 simd_min(simd_uchar3 x, simd_uchar3 y) {
  return simd_make_uchar3(simd_min(simd_make_uchar8_undef(x), simd_make_uchar8_undef(y)));
}

static inline SIMD_CFUNC simd_uchar4 simd_min(simd_uchar4 x, simd_uchar4 y) {
  return simd_make_uchar4(simd_min(simd_make_uchar8_undef(x), simd_make_uchar8_undef(y)));
}

static inline SIMD_CFUNC simd_uchar8 simd_min(simd_uchar8 x, simd_uchar8 y) {
#if defined __arm__ || defined __arm64__
  return vmin_u8(x, y);
#else
  return simd_make_uchar8(simd_min(simd_make_uchar16_undef(x), simd_make_uchar16_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_uchar16 simd_min(simd_uchar16 x, simd_uchar16 y) {
#if defined __arm__ || defined __arm64__
  return vminq_u8(x, y);
#elif defined __SSE4_1__
  return (simd_uchar16) _mm_min_epu8((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_uchar32 simd_min(simd_uchar32 x, simd_uchar32 y) {
#if defined __AVX2__
  return _mm256_min_epu8(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_uchar64 simd_min(simd_uchar64 x, simd_uchar64 y) {
#if defined __AVX512BW__
  return _mm512_min_epu8(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_short2 simd_min(simd_short2 x, simd_short2 y) {
  return simd_make_short2(simd_min(simd_make_short4_undef(x), simd_make_short4_undef(y)));
}

static inline SIMD_CFUNC simd_short3 simd_min(simd_short3 x, simd_short3 y) {
  return simd_make_short3(simd_min(simd_make_short4_undef(x), simd_make_short4_undef(y)));
}

static inline SIMD_CFUNC simd_short4 simd_min(simd_short4 x, simd_short4 y) {
#if defined __arm__ || defined __arm64__
  return vmin_s16(x, y);
#else
  return simd_make_short4(simd_min(simd_make_short8_undef(x), simd_make_short8_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_short8 simd_min(simd_short8 x, simd_short8 y) {
#if defined __arm__ || defined __arm64__
  return vminq_s16(x, y);
#elif defined __SSE4_1__
  return (simd_short8) _mm_min_epi16((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_short16 simd_min(simd_short16 x, simd_short16 y) {
#if defined __AVX2__
  return _mm256_min_epi16(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_short32 simd_min(simd_short32 x, simd_short32 y) {
#if defined __AVX512BW__
  return _mm512_min_epi16(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_ushort2 simd_min(simd_ushort2 x, simd_ushort2 y) {
  return simd_make_ushort2(simd_min(simd_make_ushort4_undef(x), simd_make_ushort4_undef(y)));
}

static inline SIMD_CFUNC simd_ushort3 simd_min(simd_ushort3 x, simd_ushort3 y) {
  return simd_make_ushort3(simd_min(simd_make_ushort4_undef(x), simd_make_ushort4_undef(y)));
}

static inline SIMD_CFUNC simd_ushort4 simd_min(simd_ushort4 x, simd_ushort4 y) {
#if defined __arm__ || defined __arm64__
  return vmin_u16(x, y);
#else
  return simd_make_ushort4(simd_min(simd_make_ushort8_undef(x), simd_make_ushort8_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_ushort8 simd_min(simd_ushort8 x, simd_ushort8 y) {
#if defined __arm__ || defined __arm64__
  return vminq_u16(x, y);
#elif defined __SSE4_1__
  return (simd_ushort8) _mm_min_epu16((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_ushort16 simd_min(simd_ushort16 x, simd_ushort16 y) {
#if defined __AVX2__
  return _mm256_min_epu16(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_ushort32 simd_min(simd_ushort32 x, simd_ushort32 y) {
#if defined __AVX512BW__
  return _mm512_min_epu16(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_int2 simd_min(simd_int2 x, simd_int2 y) {
#if defined __arm__ || defined __arm64__
  return vmin_s32(x, y);
#else
  return simd_make_int2(simd_min(simd_make_int4_undef(x), simd_make_int4_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_int3 simd_min(simd_int3 x, simd_int3 y) {
  return simd_make_int3(simd_min(simd_make_int4_undef(x), simd_make_int4_undef(y)));
}

static inline SIMD_CFUNC simd_int4 simd_min(simd_int4 x, simd_int4 y) {
#if defined __arm__ || defined __arm64__
  return vminq_s32(x, y);
#elif defined __SSE4_1__
  return (simd_int4) _mm_min_epi32((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_int8 simd_min(simd_int8 x, simd_int8 y) {
#if defined __AVX2__
  return _mm256_min_epi32(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_int16 simd_min(simd_int16 x, simd_int16 y) {
#if defined __AVX512F__
  return _mm512_min_epi32(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_uint2 simd_min(simd_uint2 x, simd_uint2 y) {
#if defined __arm__ || defined __arm64__
  return vmin_u32(x, y);
#else
  return simd_make_uint2(simd_min(simd_make_uint4_undef(x), simd_make_uint4_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_uint3 simd_min(simd_uint3 x, simd_uint3 y) {
  return simd_make_uint3(simd_min(simd_make_uint4_undef(x), simd_make_uint4_undef(y)));
}

static inline SIMD_CFUNC simd_uint4 simd_min(simd_uint4 x, simd_uint4 y) {
#if defined __arm__ || defined __arm64__
  return vminq_u32(x, y);
#elif defined __SSE4_1__
  return (simd_uint4) _mm_min_epu32((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_uint8 simd_min(simd_uint8 x, simd_uint8 y) {
#if defined __AVX2__
  return _mm256_min_epu32(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_uint16 simd_min(simd_uint16 x, simd_uint16 y) {
#if defined __AVX512F__
  return _mm512_min_epu32(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC float simd_min(float x, float y) {
  return __tg_fmin(x,y);
}

static inline SIMD_CFUNC simd_float2 simd_min(simd_float2 x, simd_float2 y) {
  return __tg_fmin(x,y);
}

static inline SIMD_CFUNC simd_float3 simd_min(simd_float3 x, simd_float3 y) {
  return __tg_fmin(x,y);
}

static inline SIMD_CFUNC simd_float4 simd_min(simd_float4 x, simd_float4 y) {
  return __tg_fmin(x,y);
}

static inline SIMD_CFUNC simd_float8 simd_min(simd_float8 x, simd_float8 y) {
  return __tg_fmin(x,y);
}

static inline SIMD_CFUNC simd_float16 simd_min(simd_float16 x, simd_float16 y) {
  return __tg_fmin(x,y);
}

static inline SIMD_CFUNC simd_long2 simd_min(simd_long2 x, simd_long2 y) {
#if defined __AVX512VL__
  return _mm_min_epi64(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_long3 simd_min(simd_long3 x, simd_long3 y) {
  return simd_make_long3(simd_min(simd_make_long4_undef(x), simd_make_long4_undef(y)));
}

static inline SIMD_CFUNC simd_long4 simd_min(simd_long4 x, simd_long4 y) {
#if defined __AVX512VL__
  return _mm256_min_epi64(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_long8 simd_min(simd_long8 x, simd_long8 y) {
#if defined __AVX512F__
  return _mm512_min_epi64(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_ulong2 simd_min(simd_ulong2 x, simd_ulong2 y) {
#if defined __AVX512VL__
  return _mm_min_epu64(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_ulong3 simd_min(simd_ulong3 x, simd_ulong3 y) {
  return simd_make_ulong3(simd_min(simd_make_ulong4_undef(x), simd_make_ulong4_undef(y)));
}

static inline SIMD_CFUNC simd_ulong4 simd_min(simd_ulong4 x, simd_ulong4 y) {
#if defined __AVX512VL__
  return _mm256_min_epu64(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC simd_ulong8 simd_min(simd_ulong8 x, simd_ulong8 y) {
#if defined __AVX512F__
  return _mm512_min_epu64(x, y);
#else
  return simd_bitselect(x, y, y < x);
#endif
}

static inline SIMD_CFUNC double simd_min(double x, double y) {
  return __tg_fmin(x,y);
}

static inline SIMD_CFUNC simd_double2 simd_min(simd_double2 x, simd_double2 y) {
  return __tg_fmin(x,y);
}

static inline SIMD_CFUNC simd_double3 simd_min(simd_double3 x, simd_double3 y) {
  return __tg_fmin(x,y);
}

static inline SIMD_CFUNC simd_double4 simd_min(simd_double4 x, simd_double4 y) {
  return __tg_fmin(x,y);
}

static inline SIMD_CFUNC simd_double8 simd_min(simd_double8 x, simd_double8 y) {
  return __tg_fmin(x,y);
}

static inline SIMD_CFUNC simd_char2 simd_max(simd_char2 x, simd_char2 y) {
  return simd_make_char2(simd_max(simd_make_char8_undef(x), simd_make_char8_undef(y)));
}

static inline SIMD_CFUNC simd_char3 simd_max(simd_char3 x, simd_char3 y) {
  return simd_make_char3(simd_max(simd_make_char8_undef(x), simd_make_char8_undef(y)));
}

static inline SIMD_CFUNC simd_char4 simd_max(simd_char4 x, simd_char4 y) {
  return simd_make_char4(simd_max(simd_make_char8_undef(x), simd_make_char8_undef(y)));
}

static inline SIMD_CFUNC simd_char8 simd_max(simd_char8 x, simd_char8 y) {
#if defined __arm__ || defined __arm64__
  return vmax_s8(x, y);
#else
  return simd_make_char8(simd_max(simd_make_char16_undef(x), simd_make_char16_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_char16 simd_max(simd_char16 x, simd_char16 y) {
#if defined __arm__ || defined __arm64__
  return vmaxq_s8(x, y);
#elif defined __SSE4_1__
  return (simd_char16) _mm_max_epi8((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_char32 simd_max(simd_char32 x, simd_char32 y) {
#if defined __AVX2__
  return _mm256_max_epi8(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_char64 simd_max(simd_char64 x, simd_char64 y) {
#if defined __AVX512BW__
  return _mm512_max_epi8(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_uchar2 simd_max(simd_uchar2 x, simd_uchar2 y) {
  return simd_make_uchar2(simd_max(simd_make_uchar8_undef(x), simd_make_uchar8_undef(y)));
}

static inline SIMD_CFUNC simd_uchar3 simd_max(simd_uchar3 x, simd_uchar3 y) {
  return simd_make_uchar3(simd_max(simd_make_uchar8_undef(x), simd_make_uchar8_undef(y)));
}

static inline SIMD_CFUNC simd_uchar4 simd_max(simd_uchar4 x, simd_uchar4 y) {
  return simd_make_uchar4(simd_max(simd_make_uchar8_undef(x), simd_make_uchar8_undef(y)));
}

static inline SIMD_CFUNC simd_uchar8 simd_max(simd_uchar8 x, simd_uchar8 y) {
#if defined __arm__ || defined __arm64__
  return vmax_u8(x, y);
#else
  return simd_make_uchar8(simd_max(simd_make_uchar16_undef(x), simd_make_uchar16_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_uchar16 simd_max(simd_uchar16 x, simd_uchar16 y) {
#if defined __arm__ || defined __arm64__
  return vmaxq_u8(x, y);
#elif defined __SSE4_1__
  return (simd_uchar16) _mm_max_epu8((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_uchar32 simd_max(simd_uchar32 x, simd_uchar32 y) {
#if defined __AVX2__
  return _mm256_max_epu8(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_uchar64 simd_max(simd_uchar64 x, simd_uchar64 y) {
#if defined __AVX512BW__
  return _mm512_max_epu8(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_short2 simd_max(simd_short2 x, simd_short2 y) {
  return simd_make_short2(simd_max(simd_make_short4_undef(x), simd_make_short4_undef(y)));
}

static inline SIMD_CFUNC simd_short3 simd_max(simd_short3 x, simd_short3 y) {
  return simd_make_short3(simd_max(simd_make_short4_undef(x), simd_make_short4_undef(y)));
}

static inline SIMD_CFUNC simd_short4 simd_max(simd_short4 x, simd_short4 y) {
#if defined __arm__ || defined __arm64__
  return vmax_s16(x, y);
#else
  return simd_make_short4(simd_max(simd_make_short8_undef(x), simd_make_short8_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_short8 simd_max(simd_short8 x, simd_short8 y) {
#if defined __arm__ || defined __arm64__
  return vmaxq_s16(x, y);
#elif defined __SSE4_1__
  return (simd_short8) _mm_max_epi16((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_short16 simd_max(simd_short16 x, simd_short16 y) {
#if defined __AVX2__
  return _mm256_max_epi16(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_short32 simd_max(simd_short32 x, simd_short32 y) {
#if defined __AVX512BW__
  return _mm512_max_epi16(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_ushort2 simd_max(simd_ushort2 x, simd_ushort2 y) {
  return simd_make_ushort2(simd_max(simd_make_ushort4_undef(x), simd_make_ushort4_undef(y)));
}

static inline SIMD_CFUNC simd_ushort3 simd_max(simd_ushort3 x, simd_ushort3 y) {
  return simd_make_ushort3(simd_max(simd_make_ushort4_undef(x), simd_make_ushort4_undef(y)));
}

static inline SIMD_CFUNC simd_ushort4 simd_max(simd_ushort4 x, simd_ushort4 y) {
#if defined __arm__ || defined __arm64__
  return vmax_u16(x, y);
#else
  return simd_make_ushort4(simd_max(simd_make_ushort8_undef(x), simd_make_ushort8_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_ushort8 simd_max(simd_ushort8 x, simd_ushort8 y) {
#if defined __arm__ || defined __arm64__
  return vmaxq_u16(x, y);
#elif defined __SSE4_1__
  return (simd_ushort8) _mm_max_epu16((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_ushort16 simd_max(simd_ushort16 x, simd_ushort16 y) {
#if defined __AVX2__
  return _mm256_max_epu16(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_ushort32 simd_max(simd_ushort32 x, simd_ushort32 y) {
#if defined __AVX512BW__
  return _mm512_max_epu16(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_int2 simd_max(simd_int2 x, simd_int2 y) {
#if defined __arm__ || defined __arm64__
  return vmax_s32(x, y);
#else
  return simd_make_int2(simd_max(simd_make_int4_undef(x), simd_make_int4_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_int3 simd_max(simd_int3 x, simd_int3 y) {
  return simd_make_int3(simd_max(simd_make_int4_undef(x), simd_make_int4_undef(y)));
}

static inline SIMD_CFUNC simd_int4 simd_max(simd_int4 x, simd_int4 y) {
#if defined __arm__ || defined __arm64__
  return vmaxq_s32(x, y);
#elif defined __SSE4_1__
  return (simd_int4) _mm_max_epi32((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_int8 simd_max(simd_int8 x, simd_int8 y) {
#if defined __AVX2__
  return _mm256_max_epi32(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_int16 simd_max(simd_int16 x, simd_int16 y) {
#if defined __AVX512F__
  return _mm512_max_epi32(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_uint2 simd_max(simd_uint2 x, simd_uint2 y) {
#if defined __arm__ || defined __arm64__
  return vmax_u32(x, y);
#else
  return simd_make_uint2(simd_max(simd_make_uint4_undef(x), simd_make_uint4_undef(y)));
#endif

}

static inline SIMD_CFUNC simd_uint3 simd_max(simd_uint3 x, simd_uint3 y) {
  return simd_make_uint3(simd_max(simd_make_uint4_undef(x), simd_make_uint4_undef(y)));
}

static inline SIMD_CFUNC simd_uint4 simd_max(simd_uint4 x, simd_uint4 y) {
#if defined __arm__ || defined __arm64__
  return vmaxq_u32(x, y);
#elif defined __SSE4_1__
  return (simd_uint4) _mm_max_epu32((__m128i)x, (__m128i)y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_uint8 simd_max(simd_uint8 x, simd_uint8 y) {
#if defined __AVX2__
  return _mm256_max_epu32(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_uint16 simd_max(simd_uint16 x, simd_uint16 y) {
#if defined __AVX512F__
  return _mm512_max_epu32(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC float simd_max(float x, float y) {
  return __tg_fmax(x,y);
}

static inline SIMD_CFUNC simd_float2 simd_max(simd_float2 x, simd_float2 y) {
  return __tg_fmax(x,y);
}

static inline SIMD_CFUNC simd_float3 simd_max(simd_float3 x, simd_float3 y) {
  return __tg_fmax(x,y);
}

static inline SIMD_CFUNC simd_float4 simd_max(simd_float4 x, simd_float4 y) {
  return __tg_fmax(x,y);
}

static inline SIMD_CFUNC simd_float8 simd_max(simd_float8 x, simd_float8 y) {
  return __tg_fmax(x,y);
}

static inline SIMD_CFUNC simd_float16 simd_max(simd_float16 x, simd_float16 y) {
  return __tg_fmax(x,y);
}

static inline SIMD_CFUNC simd_long2 simd_max(simd_long2 x, simd_long2 y) {
#if defined __AVX512VL__
  return _mm_max_epi64(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_long3 simd_max(simd_long3 x, simd_long3 y) {
  return simd_make_long3(simd_max(simd_make_long4_undef(x), simd_make_long4_undef(y)));
}

static inline SIMD_CFUNC simd_long4 simd_max(simd_long4 x, simd_long4 y) {
#if defined __AVX512VL__
  return _mm256_max_epi64(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_long8 simd_max(simd_long8 x, simd_long8 y) {
#if defined __AVX512F__
  return _mm512_max_epi64(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_ulong2 simd_max(simd_ulong2 x, simd_ulong2 y) {
#if defined __AVX512VL__
  return _mm_max_epu64(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_ulong3 simd_max(simd_ulong3 x, simd_ulong3 y) {
  return simd_make_ulong3(simd_max(simd_make_ulong4_undef(x), simd_make_ulong4_undef(y)));
}

static inline SIMD_CFUNC simd_ulong4 simd_max(simd_ulong4 x, simd_ulong4 y) {
#if defined __AVX512VL__
  return _mm256_max_epu64(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC simd_ulong8 simd_max(simd_ulong8 x, simd_ulong8 y) {
#if defined __AVX512F__
  return _mm512_max_epu64(x, y);
#else
  return simd_bitselect(x, y, x < y);
#endif
}

static inline SIMD_CFUNC double simd_max(double x, double y) {
  return __tg_fmax(x,y);
}

static inline SIMD_CFUNC simd_double2 simd_max(simd_double2 x, simd_double2 y) {
  return __tg_fmax(x,y);
}

static inline SIMD_CFUNC simd_double3 simd_max(simd_double3 x, simd_double3 y) {
  return __tg_fmax(x,y);
}

static inline SIMD_CFUNC simd_double4 simd_max(simd_double4 x, simd_double4 y) {
  return __tg_fmax(x,y);
}

static inline SIMD_CFUNC simd_double8 simd_max(simd_double8 x, simd_double8 y) {
  return __tg_fmax(x,y);
}

static inline SIMD_CFUNC simd_char2 simd_clamp(simd_char2 x, simd_char2 min, simd_char2 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_char3 simd_clamp(simd_char3 x, simd_char3 min, simd_char3 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_char4 simd_clamp(simd_char4 x, simd_char4 min, simd_char4 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_char8 simd_clamp(simd_char8 x, simd_char8 min, simd_char8 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_char16 simd_clamp(simd_char16 x, simd_char16 min, simd_char16 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_char32 simd_clamp(simd_char32 x, simd_char32 min, simd_char32 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_char64 simd_clamp(simd_char64 x, simd_char64 min, simd_char64 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uchar2 simd_clamp(simd_uchar2 x, simd_uchar2 min, simd_uchar2 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uchar3 simd_clamp(simd_uchar3 x, simd_uchar3 min, simd_uchar3 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uchar4 simd_clamp(simd_uchar4 x, simd_uchar4 min, simd_uchar4 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uchar8 simd_clamp(simd_uchar8 x, simd_uchar8 min, simd_uchar8 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uchar16 simd_clamp(simd_uchar16 x, simd_uchar16 min, simd_uchar16 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uchar32 simd_clamp(simd_uchar32 x, simd_uchar32 min, simd_uchar32 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uchar64 simd_clamp(simd_uchar64 x, simd_uchar64 min, simd_uchar64 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_short2 simd_clamp(simd_short2 x, simd_short2 min, simd_short2 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_short3 simd_clamp(simd_short3 x, simd_short3 min, simd_short3 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_short4 simd_clamp(simd_short4 x, simd_short4 min, simd_short4 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_short8 simd_clamp(simd_short8 x, simd_short8 min, simd_short8 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_short16 simd_clamp(simd_short16 x, simd_short16 min, simd_short16 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_short32 simd_clamp(simd_short32 x, simd_short32 min, simd_short32 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_ushort2 simd_clamp(simd_ushort2 x, simd_ushort2 min, simd_ushort2 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_ushort3 simd_clamp(simd_ushort3 x, simd_ushort3 min, simd_ushort3 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_ushort4 simd_clamp(simd_ushort4 x, simd_ushort4 min, simd_ushort4 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_ushort8 simd_clamp(simd_ushort8 x, simd_ushort8 min, simd_ushort8 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_ushort16 simd_clamp(simd_ushort16 x, simd_ushort16 min, simd_ushort16 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_ushort32 simd_clamp(simd_ushort32 x, simd_ushort32 min, simd_ushort32 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_int2 simd_clamp(simd_int2 x, simd_int2 min, simd_int2 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_int3 simd_clamp(simd_int3 x, simd_int3 min, simd_int3 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_int4 simd_clamp(simd_int4 x, simd_int4 min, simd_int4 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_int8 simd_clamp(simd_int8 x, simd_int8 min, simd_int8 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_int16 simd_clamp(simd_int16 x, simd_int16 min, simd_int16 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uint2 simd_clamp(simd_uint2 x, simd_uint2 min, simd_uint2 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uint3 simd_clamp(simd_uint3 x, simd_uint3 min, simd_uint3 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uint4 simd_clamp(simd_uint4 x, simd_uint4 min, simd_uint4 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uint8 simd_clamp(simd_uint8 x, simd_uint8 min, simd_uint8 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_uint16 simd_clamp(simd_uint16 x, simd_uint16 min, simd_uint16 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC float simd_clamp(float x, float min, float max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_float2 simd_clamp(simd_float2 x, simd_float2 min, simd_float2 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_float3 simd_clamp(simd_float3 x, simd_float3 min, simd_float3 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_float4 simd_clamp(simd_float4 x, simd_float4 min, simd_float4 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_float8 simd_clamp(simd_float8 x, simd_float8 min, simd_float8 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_float16 simd_clamp(simd_float16 x, simd_float16 min, simd_float16 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_long2 simd_clamp(simd_long2 x, simd_long2 min, simd_long2 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_long3 simd_clamp(simd_long3 x, simd_long3 min, simd_long3 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_long4 simd_clamp(simd_long4 x, simd_long4 min, simd_long4 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_long8 simd_clamp(simd_long8 x, simd_long8 min, simd_long8 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_ulong2 simd_clamp(simd_ulong2 x, simd_ulong2 min, simd_ulong2 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_ulong3 simd_clamp(simd_ulong3 x, simd_ulong3 min, simd_ulong3 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_ulong4 simd_clamp(simd_ulong4 x, simd_ulong4 min, simd_ulong4 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_ulong8 simd_clamp(simd_ulong8 x, simd_ulong8 min, simd_ulong8 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC double simd_clamp(double x, double min, double max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_double2 simd_clamp(simd_double2 x, simd_double2 min, simd_double2 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_double3 simd_clamp(simd_double3 x, simd_double3 min, simd_double3 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_double4 simd_clamp(simd_double4 x, simd_double4 min, simd_double4 max) {
  return simd_min(simd_max(x, min), max);
}

static inline SIMD_CFUNC simd_double8 simd_clamp(simd_double8 x, simd_double8 min, simd_double8 max) {
  return simd_min(simd_max(x, min), max);
}

  
static inline SIMD_CFUNC float simd_sign(float x) {
  return (x == 0 | x != x) ? 0 : copysign(1,x);
}

static inline SIMD_CFUNC simd_float2 simd_sign(simd_float2 x) {
  return simd_bitselect(__tg_copysign(1,x), 0, x == 0 | x != x);
}

static inline SIMD_CFUNC simd_float3 simd_sign(simd_float3 x) {
  return simd_bitselect(__tg_copysign(1,x), 0, x == 0 | x != x);
}

static inline SIMD_CFUNC simd_float4 simd_sign(simd_float4 x) {
  return simd_bitselect(__tg_copysign(1,x), 0, x == 0 | x != x);
}

static inline SIMD_CFUNC simd_float8 simd_sign(simd_float8 x) {
  return simd_bitselect(__tg_copysign(1,x), 0, x == 0 | x != x);
}

static inline SIMD_CFUNC simd_float16 simd_sign(simd_float16 x) {
  return simd_bitselect(__tg_copysign(1,x), 0, x == 0 | x != x);
}

static inline SIMD_CFUNC double simd_sign(double x) {
  return (x == 0 | x != x) ? 0 : copysign(1,x);
}

static inline SIMD_CFUNC simd_double2 simd_sign(simd_double2 x) {
  return simd_bitselect(__tg_copysign(1,x), 0, x == 0 | x != x);
}

static inline SIMD_CFUNC simd_double3 simd_sign(simd_double3 x) {
  return simd_bitselect(__tg_copysign(1,x), 0, x == 0 | x != x);
}

static inline SIMD_CFUNC simd_double4 simd_sign(simd_double4 x) {
  return simd_bitselect(__tg_copysign(1,x), 0, x == 0 | x != x);
}

static inline SIMD_CFUNC simd_double8 simd_sign(simd_double8 x) {
  return simd_bitselect(__tg_copysign(1,x), 0, x == 0 | x != x);
}

static inline SIMD_CFUNC float simd_mix(float x, float y, float t) {
  return x + t*(y - x);
}
  
static inline SIMD_CFUNC simd_float2 simd_mix(simd_float2 x, simd_float2 y, simd_float2 t) {
  return x + t*(y - x);
}
  
static inline SIMD_CFUNC simd_float3 simd_mix(simd_float3 x, simd_float3 y, simd_float3 t) {
  return x + t*(y - x);
}
  
static inline SIMD_CFUNC simd_float4 simd_mix(simd_float4 x, simd_float4 y, simd_float4 t) {
  return x + t*(y - x);
}
  
static inline SIMD_CFUNC simd_float8 simd_mix(simd_float8 x, simd_float8 y, simd_float8 t) {
  return x + t*(y - x);
}
  
static inline SIMD_CFUNC simd_float16 simd_mix(simd_float16 x, simd_float16 y, simd_float16 t) {
  return x + t*(y - x);
}
  
static inline SIMD_CFUNC double simd_mix(double x, double y, double t) {
  return x + t*(y - x);
}
  
static inline SIMD_CFUNC simd_double2 simd_mix(simd_double2 x, simd_double2 y, simd_double2 t) {
  return x + t*(y - x);
}
  
static inline SIMD_CFUNC simd_double3 simd_mix(simd_double3 x, simd_double3 y, simd_double3 t) {
  return x + t*(y - x);
}
  
static inline SIMD_CFUNC simd_double4 simd_mix(simd_double4 x, simd_double4 y, simd_double4 t) {
  return x + t*(y - x);
}
  
static inline SIMD_CFUNC simd_double8 simd_mix(simd_double8 x, simd_double8 y, simd_double8 t) {
  return x + t*(y - x);
}
  
static inline SIMD_CFUNC float simd_recip(float x) {
#if __FAST_MATH__
  return simd_fast_recip(x);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_float2 simd_recip(simd_float2 x) {
#if __FAST_MATH__
  return simd_fast_recip(x);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_float3 simd_recip(simd_float3 x) {
#if __FAST_MATH__
  return simd_fast_recip(x);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_float4 simd_recip(simd_float4 x) {
#if __FAST_MATH__
  return simd_fast_recip(x);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_float8 simd_recip(simd_float8 x) {
#if __FAST_MATH__
  return simd_fast_recip(x);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_float16 simd_recip(simd_float16 x) {
#if __FAST_MATH__
  return simd_fast_recip(x);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC double simd_recip(double x) {
#if __FAST_MATH__
  return simd_fast_recip(x);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_double2 simd_recip(simd_double2 x) {
#if __FAST_MATH__
  return simd_fast_recip(x);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_double3 simd_recip(simd_double3 x) {
#if __FAST_MATH__
  return simd_fast_recip(x);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_double4 simd_recip(simd_double4 x) {
#if __FAST_MATH__
  return simd_fast_recip(x);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_double8 simd_recip(simd_double8 x) {
#if __FAST_MATH__
  return simd_fast_recip(x);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC float simd_fast_recip(float x) {
#if defined __AVX512VL__
  simd_float4 x4 = simd_make_float4(x);
  return ((simd_float4)_mm_rcp14_ss(x4, x4)).x;
#elif defined __SSE__
  return ((simd_float4)_mm_rcp_ss(simd_make_float4(x))).x;
#elif defined __ARM_NEON__
  return simd_fast_recip(simd_make_float2_undef(x)).x;
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_float2 simd_fast_recip(simd_float2 x) {
#if defined __SSE__
  return simd_make_float2(simd_fast_recip(simd_make_float4_undef(x)));
#elif defined __ARM_NEON__
  simd_float2 r = vrecpe_f32(x);
  return r * vrecps_f32(x, r);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_float3 simd_fast_recip(simd_float3 x) {
  return simd_make_float3(simd_fast_recip(simd_make_float4_undef(x)));
}

static inline SIMD_CFUNC simd_float4 simd_fast_recip(simd_float4 x) {
#if defined __AVX512VL__
  return _mm_rcp14_ps(x);
#elif defined __SSE__
  return _mm_rcp_ps(x);
#elif defined __ARM_NEON__
  simd_float4 r = vrecpeq_f32(x);
  return r * vrecpsq_f32(x, r);
#else
  return simd_precise_recip(x);
#endif
}

static inline SIMD_CFUNC simd_float8 simd_fast_recip(simd_float8 x) {
#if defined __AVX512VL__
  return _mm256_rcp14_ps(x);
#elif defined __AVX__
  return _mm256_rcp_ps(x);
#else
  return simd_make_float8(simd_fast_recip(x.lo), simd_fast_recip(x.hi));
#endif
}

static inline SIMD_CFUNC simd_float16 simd_fast_recip(simd_float16 x) {
#if defined __AVX512F__
  return _mm512_rcp14_ps(x);
#else
  return simd_make_float16(simd_fast_recip(x.lo), simd_fast_recip(x.hi));
#endif
}

static inline SIMD_CFUNC double simd_fast_recip(double x) {
  return simd_precise_recip(x);
}

static inline SIMD_CFUNC simd_double2 simd_fast_recip(simd_double2 x) {
  return simd_precise_recip(x);
}

static inline SIMD_CFUNC simd_double3 simd_fast_recip(simd_double3 x) {
  return simd_precise_recip(x);
}

static inline SIMD_CFUNC simd_double4 simd_fast_recip(simd_double4 x) {
  return simd_precise_recip(x);
}

static inline SIMD_CFUNC simd_double8 simd_fast_recip(simd_double8 x) {
  return simd_precise_recip(x);
}

static inline SIMD_CFUNC float simd_precise_recip(float x) {
#if defined __SSE__
  float r = simd_fast_recip(x);
  return r*(2 - (x == 0 ? -INFINITY : x)*r);
#elif defined __ARM_NEON__
  return simd_precise_recip(simd_make_float2_undef(x)).x;
#else
  return 1/x;
#endif
}

static inline SIMD_CFUNC simd_float2 simd_precise_recip(simd_float2 x) {
#if defined __SSE__
  return simd_make_float2(simd_precise_recip(simd_make_float4_undef(x)));
#elif defined __ARM_NEON__
  simd_float2 r = simd_fast_recip(x);
  return r*vrecps_f32(x, r);
#else
  return 1/x;
#endif
}

static inline SIMD_CFUNC simd_float3 simd_precise_recip(simd_float3 x) {
  return simd_make_float3(simd_precise_recip(simd_make_float4_undef(x)));
}

static inline SIMD_CFUNC simd_float4 simd_precise_recip(simd_float4 x) {
#if defined __SSE__
  simd_float4 r = simd_fast_recip(x);
  return r*(2 - simd_bitselect(x, -INFINITY, x == 0)*r);
#elif defined __ARM_NEON__
  simd_float4 r = simd_fast_recip(x);
  return r*vrecpsq_f32(x, r);
#else
  return 1/x;
#endif
}

static inline SIMD_CFUNC simd_float8 simd_precise_recip(simd_float8 x) {
#if defined __AVX__
  simd_float8 r = simd_fast_recip(x);
  return r*(2 - simd_bitselect(x, -INFINITY, x == 0)*r);
#else
  return simd_make_float8(simd_precise_recip(x.lo), simd_precise_recip(x.hi));
#endif
}

static inline SIMD_CFUNC simd_float16 simd_precise_recip(simd_float16 x) {
#if defined __AVX512F__
  simd_float16 r = simd_fast_recip(x);
  return r*(2 - simd_bitselect(x, -INFINITY, x == 0)*r);
#else
  return simd_make_float16(simd_precise_recip(x.lo), simd_precise_recip(x.hi));
#endif
}

static inline SIMD_CFUNC double simd_precise_recip(double x) {
  return 1/x;
}

static inline SIMD_CFUNC simd_double2 simd_precise_recip(simd_double2 x) {
  return 1/x;
}

static inline SIMD_CFUNC simd_double3 simd_precise_recip(simd_double3 x) {
  return 1/x;
}

static inline SIMD_CFUNC simd_double4 simd_precise_recip(simd_double4 x) {
  return 1/x;
}

static inline SIMD_CFUNC simd_double8 simd_precise_recip(simd_double8 x) {
  return 1/x;
}

static inline SIMD_CFUNC float simd_rsqrt(float x) {
#if __FAST_MATH__
  return simd_fast_rsqrt(x);
#else
  return simd_precise_rsqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_float2 simd_rsqrt(simd_float2 x) {
#if __FAST_MATH__
  return simd_fast_rsqrt(x);
#else
  return simd_precise_rsqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_float3 simd_rsqrt(simd_float3 x) {
#if __FAST_MATH__
  return simd_fast_rsqrt(x);
#else
  return simd_precise_rsqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_float4 simd_rsqrt(simd_float4 x) {
#if __FAST_MATH__
  return simd_fast_rsqrt(x);
#else
  return simd_precise_rsqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_float8 simd_rsqrt(simd_float8 x) {
#if __FAST_MATH__
  return simd_fast_rsqrt(x);
#else
  return simd_precise_rsqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_float16 simd_rsqrt(simd_float16 x) {
#if __FAST_MATH__
  return simd_fast_rsqrt(x);
#else
  return simd_precise_rsqrt(x);
#endif
}
  
static inline SIMD_CFUNC double simd_rsqrt(double x) {
#if __FAST_MATH__
  return simd_fast_rsqrt(x);
#else
  return simd_precise_rsqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_double2 simd_rsqrt(simd_double2 x) {
#if __FAST_MATH__
  return simd_fast_rsqrt(x);
#else
  return simd_precise_rsqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_double3 simd_rsqrt(simd_double3 x) {
#if __FAST_MATH__
  return simd_fast_rsqrt(x);
#else
  return simd_precise_rsqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_double4 simd_rsqrt(simd_double4 x) {
#if __FAST_MATH__
  return simd_fast_rsqrt(x);
#else
  return simd_precise_rsqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_double8 simd_rsqrt(simd_double8 x) {
#if __FAST_MATH__
  return simd_fast_rsqrt(x);
#else
  return simd_precise_rsqrt(x);
#endif
}
  
static inline SIMD_CFUNC float simd_fast_rsqrt(float x) {
#if defined __AVX512VL__
  simd_float4 x4 = simd_make_float4(x);
  return ((simd_float4)_mm_rsqrt14_ss(x4, x4)).x;
#elif defined __SSE__
  return ((simd_float4)_mm_rsqrt_ss(simd_make_float4(x))).x;
#elif defined __ARM_NEON__
  return simd_fast_rsqrt(simd_make_float2_undef(x)).x;
#else
  return simd_precise_rsqrt(x);
#endif
}

static inline SIMD_CFUNC simd_float2 simd_fast_rsqrt(simd_float2 x) {
#if defined __SSE__
  return simd_make_float2(simd_fast_rsqrt(simd_make_float4_undef(x)));
#elif defined __ARM_NEON__
  simd_float2 r = vrsqrte_f32(x);
  return r * vrsqrts_f32(x, r*r);
#else
  return simd_precise_rsqrt(x);
#endif
}

static inline SIMD_CFUNC simd_float3 simd_fast_rsqrt(simd_float3 x) {
  return simd_make_float3(simd_fast_rsqrt(simd_make_float4_undef(x)));
}

static inline SIMD_CFUNC simd_float4 simd_fast_rsqrt(simd_float4 x) {
#if defined __AVX512VL__
  return _mm_rsqrt14_ps(x);
#elif defined __SSE__
  return _mm_rsqrt_ps(x);
#elif defined __ARM_NEON__
  simd_float4 r = vrsqrteq_f32(x);
  return r * vrsqrtsq_f32(x, r*r);
#else
  return simd_precise_rsqrt(x);
#endif
}

static inline SIMD_CFUNC simd_float8 simd_fast_rsqrt(simd_float8 x) {
#if defined __AVX512VL__
  return _mm256_rsqrt14_ps(x);
#elif defined __AVX__
  return _mm256_rsqrt_ps(x);
#else
  return simd_make_float8(simd_fast_rsqrt(x.lo), simd_fast_rsqrt(x.hi));
#endif
}

static inline SIMD_CFUNC simd_float16 simd_fast_rsqrt(simd_float16 x) {
#if defined __AVX512F__
  return _mm512_rsqrt14_ps(x);
#else
  return simd_make_float16(simd_fast_rsqrt(x.lo), simd_fast_rsqrt(x.hi));
#endif
}

static inline SIMD_CFUNC double simd_fast_rsqrt(double x) {
  return simd_precise_rsqrt(x);
}

static inline SIMD_CFUNC simd_double2 simd_fast_rsqrt(simd_double2 x) {
  return simd_precise_rsqrt(x);
}

static inline SIMD_CFUNC simd_double3 simd_fast_rsqrt(simd_double3 x) {
  return simd_precise_rsqrt(x);
}

static inline SIMD_CFUNC simd_double4 simd_fast_rsqrt(simd_double4 x) {
  return simd_precise_rsqrt(x);
}

static inline SIMD_CFUNC simd_double8 simd_fast_rsqrt(simd_double8 x) {
  return simd_precise_rsqrt(x);
}

static inline SIMD_CFUNC float simd_precise_rsqrt(float x) {
#if defined __SSE__
  float r = simd_fast_rsqrt(x);
  return r*(1.5f - 0.5f*(r == INFINITY ? -INFINITY : x)*r*r);
#elif defined __ARM_NEON__
  return simd_precise_rsqrt(simd_make_float2_undef(x)).x;
#else
  return 1/sqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_float2 simd_precise_rsqrt(simd_float2 x) {
#if defined __SSE__
  return simd_make_float2(simd_precise_rsqrt(simd_make_float4_undef(x)));
#elif defined __ARM_NEON__
  simd_float2 r = simd_fast_rsqrt(x);
  return r*vrsqrts_f32(x, r*r);
#else
  return 1/__tg_sqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_float3 simd_precise_rsqrt(simd_float3 x) {
  return simd_make_float3(simd_precise_rsqrt(simd_make_float4_undef(x)));
}
  
static inline SIMD_CFUNC simd_float4 simd_precise_rsqrt(simd_float4 x) {
#if defined __SSE__
  simd_float4 r = simd_fast_rsqrt(x);
  return r*(1.5 - 0.5*simd_bitselect(x, -INFINITY, r == INFINITY)*r*r);
#elif defined __ARM_NEON__
  simd_float4 r = simd_fast_rsqrt(x);
  return r*vrsqrtsq_f32(x, r*r);
#else
  return 1/__tg_sqrt(x);
#endif
}
  
static inline SIMD_CFUNC simd_float8 simd_precise_rsqrt(simd_float8 x) {
#if defined __AVX__
  simd_float8 r = simd_fast_rsqrt(x);
  return r*(1.5 - 0.5*simd_bitselect(x, -INFINITY, r == INFINITY)*r*r);
#else
  return simd_make_float8(simd_precise_rsqrt(x.lo), simd_precise_rsqrt(x.hi));
#endif
}
  
static inline SIMD_CFUNC simd_float16 simd_precise_rsqrt(simd_float16 x) {
#if defined __AVX512F__
  simd_float16 r = simd_fast_rsqrt(x);
  return r*(1.5 - 0.5*simd_bitselect(x, -INFINITY, r == INFINITY)*r*r);
#else
  return simd_make_float16(simd_precise_rsqrt(x.lo), simd_precise_rsqrt(x.hi));
#endif
}
  
static inline SIMD_CFUNC double simd_precise_rsqrt(double x) {
  return 1/sqrt(x);
}
  
static inline SIMD_CFUNC simd_double2 simd_precise_rsqrt(simd_double2 x) {
  return 1/__tg_sqrt(x);
}
  
static inline SIMD_CFUNC simd_double3 simd_precise_rsqrt(simd_double3 x) {
  return 1/__tg_sqrt(x);
}
  
static inline SIMD_CFUNC simd_double4 simd_precise_rsqrt(simd_double4 x) {
  return 1/__tg_sqrt(x);
}
  
static inline SIMD_CFUNC simd_double8 simd_precise_rsqrt(simd_double8 x) {
  return 1/__tg_sqrt(x);
}
  
static inline SIMD_CFUNC float simd_fract(float x) {
  return fmin(x - floor(x), 0x1.fffffep-1f);
}

static inline SIMD_CFUNC simd_float2 simd_fract(simd_float2 x) {
  return __tg_fmin(x - __tg_floor(x), 0x1.fffffep-1f);
}

static inline SIMD_CFUNC simd_float3 simd_fract(simd_float3 x) {
  return __tg_fmin(x - __tg_floor(x), 0x1.fffffep-1f);
}

static inline SIMD_CFUNC simd_float4 simd_fract(simd_float4 x) {
  return __tg_fmin(x - __tg_floor(x), 0x1.fffffep-1f);
}

static inline SIMD_CFUNC simd_float8 simd_fract(simd_float8 x) {
  return __tg_fmin(x - __tg_floor(x), 0x1.fffffep-1f);
}

static inline SIMD_CFUNC simd_float16 simd_fract(simd_float16 x) {
  return __tg_fmin(x - __tg_floor(x), 0x1.fffffep-1f);
}

static inline SIMD_CFUNC double simd_fract(double x) {
  return fmin(x - floor(x), 0x1.fffffffffffffp-1);
}

static inline SIMD_CFUNC simd_double2 simd_fract(simd_double2 x) {
  return __tg_fmin(x - __tg_floor(x), 0x1.fffffffffffffp-1);
}

static inline SIMD_CFUNC simd_double3 simd_fract(simd_double3 x) {
  return __tg_fmin(x - __tg_floor(x), 0x1.fffffffffffffp-1);
}

static inline SIMD_CFUNC simd_double4 simd_fract(simd_double4 x) {
  return __tg_fmin(x - __tg_floor(x), 0x1.fffffffffffffp-1);
}

static inline SIMD_CFUNC simd_double8 simd_fract(simd_double8 x) {
  return __tg_fmin(x - __tg_floor(x), 0x1.fffffffffffffp-1);
}

static inline SIMD_CFUNC float simd_step(float edge, float x) {
  return !(x < edge);
}

static inline SIMD_CFUNC simd_float2 simd_step(simd_float2 edge, simd_float2 x) {
  return simd_bitselect((simd_float2)1, 0, x < edge);
}

static inline SIMD_CFUNC simd_float3 simd_step(simd_float3 edge, simd_float3 x) {
  return simd_bitselect((simd_float3)1, 0, x < edge);
}

static inline SIMD_CFUNC simd_float4 simd_step(simd_float4 edge, simd_float4 x) {
  return simd_bitselect((simd_float4)1, 0, x < edge);
}

static inline SIMD_CFUNC simd_float8 simd_step(simd_float8 edge, simd_float8 x) {
  return simd_bitselect((simd_float8)1, 0, x < edge);
}

static inline SIMD_CFUNC simd_float16 simd_step(simd_float16 edge, simd_float16 x) {
  return simd_bitselect((simd_float16)1, 0, x < edge);
}

static inline SIMD_CFUNC double simd_step(double edge, double x) {
  return !(x < edge);
}

static inline SIMD_CFUNC simd_double2 simd_step(simd_double2 edge, simd_double2 x) {
  return simd_bitselect((simd_double2)1, 0, x < edge);
}

static inline SIMD_CFUNC simd_double3 simd_step(simd_double3 edge, simd_double3 x) {
  return simd_bitselect((simd_double3)1, 0, x < edge);
}

static inline SIMD_CFUNC simd_double4 simd_step(simd_double4 edge, simd_double4 x) {
  return simd_bitselect((simd_double4)1, 0, x < edge);
}

static inline SIMD_CFUNC simd_double8 simd_step(simd_double8 edge, simd_double8 x) {
  return simd_bitselect((simd_double8)1, 0, x < edge);
}

static inline SIMD_CFUNC float simd_smoothstep(float edge0, float edge1, float x) {
  float t = simd_clamp((x - edge0)/(edge1 - edge0), 0, 1);
  return t*t*(3 - 2*t);
}

static inline SIMD_CFUNC simd_float2 simd_smoothstep(simd_float2 edge0, simd_float2 edge1, simd_float2 x) {
  simd_float2 t = simd_clamp((x - edge0)/(edge1 - edge0), 0, 1);
  return t*t*(3 - 2*t);
}

static inline SIMD_CFUNC simd_float3 simd_smoothstep(simd_float3 edge0, simd_float3 edge1, simd_float3 x) {
  simd_float3 t = simd_clamp((x - edge0)/(edge1 - edge0), 0, 1);
  return t*t*(3 - 2*t);
}

static inline SIMD_CFUNC simd_float4 simd_smoothstep(simd_float4 edge0, simd_float4 edge1, simd_float4 x) {
  simd_float4 t = simd_clamp((x - edge0)/(edge1 - edge0), 0, 1);
  return t*t*(3 - 2*t);
}

static inline SIMD_CFUNC simd_float8 simd_smoothstep(simd_float8 edge0, simd_float8 edge1, simd_float8 x) {
  simd_float8 t = simd_clamp((x - edge0)/(edge1 - edge0), 0, 1);
  return t*t*(3 - 2*t);
}

static inline SIMD_CFUNC simd_float16 simd_smoothstep(simd_float16 edge0, simd_float16 edge1, simd_float16 x) {
  simd_float16 t = simd_clamp((x - edge0)/(edge1 - edge0), 0, 1);
  return t*t*(3 - 2*t);
}

static inline SIMD_CFUNC double simd_smoothstep(double edge0, double edge1, double x) {
  double t = simd_clamp((x - edge0)/(edge1 - edge0), 0, 1);
  return t*t*(3 - 2*t);
}

static inline SIMD_CFUNC simd_double2 simd_smoothstep(simd_double2 edge0, simd_double2 edge1, simd_double2 x) {
  simd_double2 t = simd_clamp((x - edge0)/(edge1 - edge0), 0, 1);
  return t*t*(3 - 2*t);
}

static inline SIMD_CFUNC simd_double3 simd_smoothstep(simd_double3 edge0, simd_double3 edge1, simd_double3 x) {
  simd_double3 t = simd_clamp((x - edge0)/(edge1 - edge0), 0, 1);
  return t*t*(3 - 2*t);
}

static inline SIMD_CFUNC simd_double4 simd_smoothstep(simd_double4 edge0, simd_double4 edge1, simd_double4 x) {
  simd_double4 t = simd_clamp((x - edge0)/(edge1 - edge0), 0, 1);
  return t*t*(3 - 2*t);
}

static inline SIMD_CFUNC simd_double8 simd_smoothstep(simd_double8 edge0, simd_double8 edge1, simd_double8 x) {
  simd_double8 t = simd_clamp((x - edge0)/(edge1 - edge0), 0, 1);
  return t*t*(3 - 2*t);
}

static inline SIMD_CFUNC char simd_reduce_add(simd_char2 x) {
  return x.x + x.y;
}

static inline SIMD_CFUNC char simd_reduce_add(simd_char3 x) {
  return x.x + x.y + x.z;
}

static inline SIMD_CFUNC char simd_reduce_add(simd_char4 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC char simd_reduce_add(simd_char8 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC char simd_reduce_add(simd_char16 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC char simd_reduce_add(simd_char32 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC char simd_reduce_add(simd_char64 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar2 x) {
  return x.x + x.y;
}

static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar3 x) {
  return x.x + x.y + x.z;
}

static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar4 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar8 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar16 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar32 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned char simd_reduce_add(simd_uchar64 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC short simd_reduce_add(simd_short2 x) {
  return x.x + x.y;
}

static inline SIMD_CFUNC short simd_reduce_add(simd_short3 x) {
  return x.x + x.y + x.z;
}

static inline SIMD_CFUNC short simd_reduce_add(simd_short4 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC short simd_reduce_add(simd_short8 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC short simd_reduce_add(simd_short16 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC short simd_reduce_add(simd_short32 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort2 x) {
  return x.x + x.y;
}

static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort3 x) {
  return x.x + x.y + x.z;
}

static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort4 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort8 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort16 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned short simd_reduce_add(simd_ushort32 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC int simd_reduce_add(simd_int2 x) {
  return x.x + x.y;
}

static inline SIMD_CFUNC int simd_reduce_add(simd_int3 x) {
  return x.x + x.y + x.z;
}

static inline SIMD_CFUNC int simd_reduce_add(simd_int4 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC int simd_reduce_add(simd_int8 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC int simd_reduce_add(simd_int16 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned int simd_reduce_add(simd_uint2 x) {
  return x.x + x.y;
}

static inline SIMD_CFUNC unsigned int simd_reduce_add(simd_uint3 x) {
  return x.x + x.y + x.z;
}

static inline SIMD_CFUNC unsigned int simd_reduce_add(simd_uint4 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned int simd_reduce_add(simd_uint8 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC unsigned int simd_reduce_add(simd_uint16 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC float simd_reduce_add(simd_float2 x) {
  return x.x + x.y;
}

static inline SIMD_CFUNC float simd_reduce_add(simd_float3 x) {
  return x.x + x.y + x.z;
}

static inline SIMD_CFUNC float simd_reduce_add(simd_float4 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC float simd_reduce_add(simd_float8 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC float simd_reduce_add(simd_float16 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC simd_long1 simd_reduce_add(simd_long2 x) {
  return x.x + x.y;
}

static inline SIMD_CFUNC simd_long1 simd_reduce_add(simd_long3 x) {
  return x.x + x.y + x.z;
}

static inline SIMD_CFUNC simd_long1 simd_reduce_add(simd_long4 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC simd_long1 simd_reduce_add(simd_long8 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_add(simd_ulong2 x) {
  return x.x + x.y;
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_add(simd_ulong3 x) {
  return x.x + x.y + x.z;
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_add(simd_ulong4 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_add(simd_ulong8 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC double simd_reduce_add(simd_double2 x) {
  return x.x + x.y;
}

static inline SIMD_CFUNC double simd_reduce_add(simd_double3 x) {
  return x.x + x.y + x.z;
}

static inline SIMD_CFUNC double simd_reduce_add(simd_double4 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC double simd_reduce_add(simd_double8 x) {
  return simd_reduce_add(x.lo + x.hi);
}

static inline SIMD_CFUNC char simd_reduce_min(simd_char2 x) {
  return x.y < x.x ? x.y : x.x;
}

static inline SIMD_CFUNC char simd_reduce_min(simd_char3 x) {
  char t = x.z < x.x ? x.z : x.x;
  return x.y < t ? x.y : t;
}

static inline SIMD_CFUNC char simd_reduce_min(simd_char4 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC char simd_reduce_min(simd_char8 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC char simd_reduce_min(simd_char16 x) {
#if defined __arm64__
  return vminvq_s8(x);
#else
  return simd_reduce_min(simd_min(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC char simd_reduce_min(simd_char32 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC char simd_reduce_min(simd_char64 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar2 x) {
  return x.y < x.x ? x.y : x.x;
}

static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar3 x) {
  unsigned char t = x.z < x.x ? x.z : x.x;
  return x.y < t ? x.y : t;
}

static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar4 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar8 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar16 x) {
#if defined __arm64__
  return vminvq_u8(x);
#else
  return simd_reduce_min(simd_min(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar32 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned char simd_reduce_min(simd_uchar64 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC short simd_reduce_min(simd_short2 x) {
  return x.y < x.x ? x.y : x.x;
}

static inline SIMD_CFUNC short simd_reduce_min(simd_short3 x) {
  short t = x.z < x.x ? x.z : x.x;
  return x.y < t ? x.y : t;
}

static inline SIMD_CFUNC short simd_reduce_min(simd_short4 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC short simd_reduce_min(simd_short8 x) {
#if defined __arm64__
  return vminvq_s16(x);
#else
  return simd_reduce_min(simd_min(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC short simd_reduce_min(simd_short16 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC short simd_reduce_min(simd_short32 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort2 x) {
  return x.y < x.x ? x.y : x.x;
}

static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort3 x) {
  unsigned short t = x.z < x.x ? x.z : x.x;
  return x.y < t ? x.y : t;
}

static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort4 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort8 x) {
#if defined __arm64__
  return vminvq_u16(x);
#else
  return simd_reduce_min(simd_min(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort16 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned short simd_reduce_min(simd_ushort32 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC int simd_reduce_min(simd_int2 x) {
  return x.y < x.x ? x.y : x.x;
}

static inline SIMD_CFUNC int simd_reduce_min(simd_int3 x) {
  int t = x.z < x.x ? x.z : x.x;
  return x.y < t ? x.y : t;
}

static inline SIMD_CFUNC int simd_reduce_min(simd_int4 x) {
#if defined __arm64__
  return vminvq_s32(x);
#else
  return simd_reduce_min(simd_min(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC int simd_reduce_min(simd_int8 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC int simd_reduce_min(simd_int16 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned int simd_reduce_min(simd_uint2 x) {
  return x.y < x.x ? x.y : x.x;
}

static inline SIMD_CFUNC unsigned int simd_reduce_min(simd_uint3 x) {
  unsigned int t = x.z < x.x ? x.z : x.x;
  return x.y < t ? x.y : t;
}

static inline SIMD_CFUNC unsigned int simd_reduce_min(simd_uint4 x) {
#if defined __arm64__
  return vminvq_u32(x);
#else
  return simd_reduce_min(simd_min(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC unsigned int simd_reduce_min(simd_uint8 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned int simd_reduce_min(simd_uint16 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC simd_long1 simd_reduce_min(simd_long2 x) {
  return x.y < x.x ? x.y : x.x;
}

static inline SIMD_CFUNC simd_long1 simd_reduce_min(simd_long3 x) {
  simd_long1 t = x.z < x.x ? x.z : x.x;
  return x.y < t ? x.y : t;
}

static inline SIMD_CFUNC simd_long1 simd_reduce_min(simd_long4 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC simd_long1 simd_reduce_min(simd_long8 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_min(simd_ulong2 x) {
  return x.y < x.x ? x.y : x.x;
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_min(simd_ulong3 x) {
  simd_ulong1 t = x.z < x.x ? x.z : x.x;
  return x.y < t ? x.y : t;
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_min(simd_ulong4 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_min(simd_ulong8 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC float simd_reduce_min(simd_float2 x) {
  return fmin(x.x, x.y);
}

static inline SIMD_CFUNC float simd_reduce_min(simd_float3 x) {
  return fmin(fmin(x.x, x.z), x.y);
}

static inline SIMD_CFUNC float simd_reduce_min(simd_float4 x) {
#if defined __arm64__
  return vminvq_f32(x);
#else
  return simd_reduce_min(simd_min(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC float simd_reduce_min(simd_float8 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC float simd_reduce_min(simd_float16 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC double simd_reduce_min(simd_double2 x) {
#if defined __arm64__
  return vminvq_f64(x);
#else
  return fmin(x.x, x.y);
#endif
}

static inline SIMD_CFUNC double simd_reduce_min(simd_double3 x) {
  return fmin(fmin(x.x, x.z), x.y);
}

static inline SIMD_CFUNC double simd_reduce_min(simd_double4 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC double simd_reduce_min(simd_double8 x) {
  return simd_reduce_min(simd_min(x.lo, x.hi));
}

static inline SIMD_CFUNC char simd_reduce_max(simd_char2 x) {
  return x.y > x.x ? x.y : x.x;
}

static inline SIMD_CFUNC char simd_reduce_max(simd_char3 x) {
  char t = x.z > x.x ? x.z : x.x;
  return x.y > t ? x.y : t;
}

static inline SIMD_CFUNC char simd_reduce_max(simd_char4 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC char simd_reduce_max(simd_char8 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC char simd_reduce_max(simd_char16 x) {
#if defined __arm64__
  return vmaxvq_s8(x);
#else
  return simd_reduce_max(simd_max(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC char simd_reduce_max(simd_char32 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC char simd_reduce_max(simd_char64 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar2 x) {
  return x.y > x.x ? x.y : x.x;
}

static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar3 x) {
  unsigned char t = x.z > x.x ? x.z : x.x;
  return x.y > t ? x.y : t;
}

static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar4 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar8 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar16 x) {
#if defined __arm64__
  return vmaxvq_u8(x);
#else
  return simd_reduce_max(simd_max(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar32 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned char simd_reduce_max(simd_uchar64 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC short simd_reduce_max(simd_short2 x) {
  return x.y > x.x ? x.y : x.x;
}

static inline SIMD_CFUNC short simd_reduce_max(simd_short3 x) {
  short t = x.z > x.x ? x.z : x.x;
  return x.y > t ? x.y : t;
}

static inline SIMD_CFUNC short simd_reduce_max(simd_short4 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC short simd_reduce_max(simd_short8 x) {
#if defined __arm64__
  return vmaxvq_s16(x);
#else
  return simd_reduce_max(simd_max(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC short simd_reduce_max(simd_short16 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC short simd_reduce_max(simd_short32 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort2 x) {
  return x.y > x.x ? x.y : x.x;
}

static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort3 x) {
  unsigned short t = x.z > x.x ? x.z : x.x;
  return x.y > t ? x.y : t;
}

static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort4 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort8 x) {
#if defined __arm64__
  return vmaxvq_u16(x);
#else
  return simd_reduce_max(simd_max(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort16 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned short simd_reduce_max(simd_ushort32 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC int simd_reduce_max(simd_int2 x) {
  return x.y > x.x ? x.y : x.x;
}

static inline SIMD_CFUNC int simd_reduce_max(simd_int3 x) {
  int t = x.z > x.x ? x.z : x.x;
  return x.y > t ? x.y : t;
}

static inline SIMD_CFUNC int simd_reduce_max(simd_int4 x) {
#if defined __arm64__
  return vmaxvq_s32(x);
#else
  return simd_reduce_max(simd_max(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC int simd_reduce_max(simd_int8 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC int simd_reduce_max(simd_int16 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned int simd_reduce_max(simd_uint2 x) {
  return x.y > x.x ? x.y : x.x;
}

static inline SIMD_CFUNC unsigned int simd_reduce_max(simd_uint3 x) {
  unsigned int t = x.z > x.x ? x.z : x.x;
  return x.y > t ? x.y : t;
}

static inline SIMD_CFUNC unsigned int simd_reduce_max(simd_uint4 x) {
#if defined __arm64__
  return vmaxvq_u32(x);
#else
  return simd_reduce_max(simd_max(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC unsigned int simd_reduce_max(simd_uint8 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC unsigned int simd_reduce_max(simd_uint16 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC simd_long1 simd_reduce_max(simd_long2 x) {
  return x.y > x.x ? x.y : x.x;
}

static inline SIMD_CFUNC simd_long1 simd_reduce_max(simd_long3 x) {
  simd_long1 t = x.z > x.x ? x.z : x.x;
  return x.y > t ? x.y : t;
}

static inline SIMD_CFUNC simd_long1 simd_reduce_max(simd_long4 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC simd_long1 simd_reduce_max(simd_long8 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_max(simd_ulong2 x) {
  return x.y > x.x ? x.y : x.x;
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_max(simd_ulong3 x) {
  simd_ulong1 t = x.z > x.x ? x.z : x.x;
  return x.y > t ? x.y : t;
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_max(simd_ulong4 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC simd_ulong1 simd_reduce_max(simd_ulong8 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC float simd_reduce_max(simd_float2 x) {
  return fmax(x.x, x.y);
}

static inline SIMD_CFUNC float simd_reduce_max(simd_float3 x) {
  return fmax(fmax(x.x, x.z), x.y);
}

static inline SIMD_CFUNC float simd_reduce_max(simd_float4 x) {
#if defined __arm64__
  return vmaxvq_f32(x);
#else
  return simd_reduce_max(simd_max(x.lo, x.hi));
#endif
}

static inline SIMD_CFUNC float simd_reduce_max(simd_float8 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC float simd_reduce_max(simd_float16 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC double simd_reduce_max(simd_double2 x) {
#if defined __arm64__
  return vmaxvq_f64(x);
#else
  return fmax(x.x, x.y);
#endif
}

static inline SIMD_CFUNC double simd_reduce_max(simd_double3 x) {
  return fmax(fmax(x.x, x.z), x.y);
}

static inline SIMD_CFUNC double simd_reduce_max(simd_double4 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

static inline SIMD_CFUNC double simd_reduce_max(simd_double8 x) {
  return simd_reduce_max(simd_max(x.lo, x.hi));
}

#ifdef __cplusplus
}
#endif
#endif /* SIMD_COMPILER_HAS_REQUIRED_FEATURES */
#endif /* SIMD_COMMON_HEADER */
