/*  Copyright (c) 2014-2017 Apple, Inc. All rights reserved.
 *
 *  The interfaces declared in this header provide conversions between vector
 *  types. The following functions are available:
 *
 *      simd_char(x)      simd_uchar(x)
 *      simd_short(x)     simd_ushort(x)
 *      simd_int(x)       simd_uint(x)
 *      simd_long(x)      simd_ulong(x)
 *      simd_float(x)
 *      simd_double(x)
 *
 *  Each of these functions converts x to a vector whose elements have the
 *  type named by the function, with the same number of elements as x. Unlike
 *  a vector cast, these functions convert the elements to the new element
 *  type. These conversions behave exactly as C scalar conversions, except
 *  that conversions from integer vector types to signed integer vector types
 *  are guaranteed to wrap modulo 2^N (where N is the number of bits in an
 *  element of the result type).
 *
 *  For integer vector types, saturating conversions are also available:
 *
 *      simd_char_sat(x)      simd_uchar_sat(x)
 *      simd_short_sat(x)     simd_ushort_sat(x)
 *      simd_int_sat(x)       simd_uint_sat(x)
 *      simd_long_sat(x)      simd_ulong_sat(x)
 *
 *  These conversions clamp x to the representable range of the result type
 *  before converting.
 *
 *  In C++ the conversion functions are templated in the simd:: namespace.
 *
 *      C++ Function                            Equivalent C Function
 *      -------------------------------------------------------------------
 *      simd::convert<ScalarType>(x)            simd_ScalarType(x)
 *      simd::convert_sat<ScalarType>(x)        simd_ScalarType_sat(x)
 */

#ifndef __SIMD_CONVERSION_HEADER__
#define __SIMD_CONVERSION_HEADER__

#include <simd/base.h>
#if SIMD_COMPILER_HAS_REQUIRED_FEATURES
#include <simd/vector_types.h>
#include <simd/common.h>
#include <simd/logic.h>

#ifdef __cplusplus
extern "C" {
#endif

static simd_char2  SIMD_CFUNC simd_char(simd_char2    __x);
static simd_char3  SIMD_CFUNC simd_char(simd_char3    __x);
static simd_char4  SIMD_CFUNC simd_char(simd_char4    __x);
static simd_char8  SIMD_CFUNC simd_char(simd_char8    __x);
static simd_char16 SIMD_CFUNC simd_char(simd_char16   __x);
static simd_char32 SIMD_CFUNC simd_char(simd_char32   __x);
static simd_char2  SIMD_CFUNC simd_char(simd_uchar2   __x);
static simd_char3  SIMD_CFUNC simd_char(simd_uchar3   __x);
static simd_char4  SIMD_CFUNC simd_char(simd_uchar4   __x);
static simd_char8  SIMD_CFUNC simd_char(simd_uchar8   __x);
static simd_char16 SIMD_CFUNC simd_char(simd_uchar16  __x);
static simd_char32 SIMD_CFUNC simd_char(simd_uchar32  __x);
static simd_char2  SIMD_CFUNC simd_char(simd_short2   __x);
static simd_char3  SIMD_CFUNC simd_char(simd_short3   __x);
static simd_char4  SIMD_CFUNC simd_char(simd_short4   __x);
static simd_char8  SIMD_CFUNC simd_char(simd_short8   __x);
static simd_char16 SIMD_CFUNC simd_char(simd_short16  __x);
static simd_char32 SIMD_CFUNC simd_char(simd_short32  __x);
static simd_char2  SIMD_CFUNC simd_char(simd_ushort2  __x);
static simd_char3  SIMD_CFUNC simd_char(simd_ushort3  __x);
static simd_char4  SIMD_CFUNC simd_char(simd_ushort4  __x);
static simd_char8  SIMD_CFUNC simd_char(simd_ushort8  __x);
static simd_char16 SIMD_CFUNC simd_char(simd_ushort16 __x);
static simd_char32 SIMD_CFUNC simd_char(simd_ushort32 __x);
static simd_char2  SIMD_CFUNC simd_char(simd_int2     __x);
static simd_char3  SIMD_CFUNC simd_char(simd_int3     __x);
static simd_char4  SIMD_CFUNC simd_char(simd_int4     __x);
static simd_char8  SIMD_CFUNC simd_char(simd_int8     __x);
static simd_char16 SIMD_CFUNC simd_char(simd_int16    __x);
static simd_char2  SIMD_CFUNC simd_char(simd_uint2    __x);
static simd_char3  SIMD_CFUNC simd_char(simd_uint3    __x);
static simd_char4  SIMD_CFUNC simd_char(simd_uint4    __x);
static simd_char8  SIMD_CFUNC simd_char(simd_uint8    __x);
static simd_char16 SIMD_CFUNC simd_char(simd_uint16   __x);
static simd_char2  SIMD_CFUNC simd_char(simd_float2   __x);
static simd_char3  SIMD_CFUNC simd_char(simd_float3   __x);
static simd_char4  SIMD_CFUNC simd_char(simd_float4   __x);
static simd_char8  SIMD_CFUNC simd_char(simd_float8   __x);
static simd_char16 SIMD_CFUNC simd_char(simd_float16  __x);
static simd_char2  SIMD_CFUNC simd_char(simd_long2    __x);
static simd_char3  SIMD_CFUNC simd_char(simd_long3    __x);
static simd_char4  SIMD_CFUNC simd_char(simd_long4    __x);
static simd_char8  SIMD_CFUNC simd_char(simd_long8    __x);
static simd_char2  SIMD_CFUNC simd_char(simd_ulong2   __x);
static simd_char3  SIMD_CFUNC simd_char(simd_ulong3   __x);
static simd_char4  SIMD_CFUNC simd_char(simd_ulong4   __x);
static simd_char8  SIMD_CFUNC simd_char(simd_ulong8   __x);
static simd_char2  SIMD_CFUNC simd_char(simd_double2  __x);
static simd_char3  SIMD_CFUNC simd_char(simd_double3  __x);
static simd_char4  SIMD_CFUNC simd_char(simd_double4  __x);
static simd_char8  SIMD_CFUNC simd_char(simd_double8  __x);
static simd_char2  SIMD_CFUNC simd_char_sat(simd_char2    __x);
static simd_char3  SIMD_CFUNC simd_char_sat(simd_char3    __x);
static simd_char4  SIMD_CFUNC simd_char_sat(simd_char4    __x);
static simd_char8  SIMD_CFUNC simd_char_sat(simd_char8    __x);
static simd_char16 SIMD_CFUNC simd_char_sat(simd_char16   __x);
static simd_char32 SIMD_CFUNC simd_char_sat(simd_char32   __x);
static simd_char2  SIMD_CFUNC simd_char_sat(simd_short2   __x);
static simd_char3  SIMD_CFUNC simd_char_sat(simd_short3   __x);
static simd_char4  SIMD_CFUNC simd_char_sat(simd_short4   __x);
static simd_char8  SIMD_CFUNC simd_char_sat(simd_short8   __x);
static simd_char16 SIMD_CFUNC simd_char_sat(simd_short16  __x);
static simd_char32 SIMD_CFUNC simd_char_sat(simd_short32  __x);
static simd_char2  SIMD_CFUNC simd_char_sat(simd_int2     __x);
static simd_char3  SIMD_CFUNC simd_char_sat(simd_int3     __x);
static simd_char4  SIMD_CFUNC simd_char_sat(simd_int4     __x);
static simd_char8  SIMD_CFUNC simd_char_sat(simd_int8     __x);
static simd_char16 SIMD_CFUNC simd_char_sat(simd_int16    __x);
static simd_char2  SIMD_CFUNC simd_char_sat(simd_float2   __x);
static simd_char3  SIMD_CFUNC simd_char_sat(simd_float3   __x);
static simd_char4  SIMD_CFUNC simd_char_sat(simd_float4   __x);
static simd_char8  SIMD_CFUNC simd_char_sat(simd_float8   __x);
static simd_char16 SIMD_CFUNC simd_char_sat(simd_float16  __x);
static simd_char2  SIMD_CFUNC simd_char_sat(simd_long2    __x);
static simd_char3  SIMD_CFUNC simd_char_sat(simd_long3    __x);
static simd_char4  SIMD_CFUNC simd_char_sat(simd_long4    __x);
static simd_char8  SIMD_CFUNC simd_char_sat(simd_long8    __x);
static simd_char2  SIMD_CFUNC simd_char_sat(simd_double2  __x);
static simd_char3  SIMD_CFUNC simd_char_sat(simd_double3  __x);
static simd_char4  SIMD_CFUNC simd_char_sat(simd_double4  __x);
static simd_char8  SIMD_CFUNC simd_char_sat(simd_double8  __x);
static simd_char2  SIMD_CFUNC simd_char_sat(simd_uchar2   __x);
static simd_char3  SIMD_CFUNC simd_char_sat(simd_uchar3   __x);
static simd_char4  SIMD_CFUNC simd_char_sat(simd_uchar4   __x);
static simd_char8  SIMD_CFUNC simd_char_sat(simd_uchar8   __x);
static simd_char16 SIMD_CFUNC simd_char_sat(simd_uchar16  __x);
static simd_char32 SIMD_CFUNC simd_char_sat(simd_uchar32  __x);
static simd_char2  SIMD_CFUNC simd_char_sat(simd_ushort2  __x);
static simd_char3  SIMD_CFUNC simd_char_sat(simd_ushort3  __x);
static simd_char4  SIMD_CFUNC simd_char_sat(simd_ushort4  __x);
static simd_char8  SIMD_CFUNC simd_char_sat(simd_ushort8  __x);
static simd_char16 SIMD_CFUNC simd_char_sat(simd_ushort16 __x);
static simd_char32 SIMD_CFUNC simd_char_sat(simd_ushort32 __x);
static simd_char2  SIMD_CFUNC simd_char_sat(simd_uint2    __x);
static simd_char3  SIMD_CFUNC simd_char_sat(simd_uint3    __x);
static simd_char4  SIMD_CFUNC simd_char_sat(simd_uint4    __x);
static simd_char8  SIMD_CFUNC simd_char_sat(simd_uint8    __x);
static simd_char16 SIMD_CFUNC simd_char_sat(simd_uint16   __x);
static simd_char2  SIMD_CFUNC simd_char_sat(simd_ulong2   __x);
static simd_char3  SIMD_CFUNC simd_char_sat(simd_ulong3   __x);
static simd_char4  SIMD_CFUNC simd_char_sat(simd_ulong4   __x);
static simd_char8  SIMD_CFUNC simd_char_sat(simd_ulong8   __x);
#define vector_char simd_char
#define vector_char_sat simd_char_sat

static simd_uchar2  SIMD_CFUNC simd_uchar(simd_char2    __x);
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_char3    __x);
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_char4    __x);
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_char8    __x);
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_char16   __x);
static simd_uchar32 SIMD_CFUNC simd_uchar(simd_char32   __x);
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_uchar2   __x);
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_uchar3   __x);
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_uchar4   __x);
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_uchar8   __x);
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_uchar16  __x);
static simd_uchar32 SIMD_CFUNC simd_uchar(simd_uchar32  __x);
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_short2   __x);
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_short3   __x);
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_short4   __x);
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_short8   __x);
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_short16  __x);
static simd_uchar32 SIMD_CFUNC simd_uchar(simd_short32  __x);
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_ushort2  __x);
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_ushort3  __x);
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_ushort4  __x);
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_ushort8  __x);
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_ushort16 __x);
static simd_uchar32 SIMD_CFUNC simd_uchar(simd_ushort32 __x);
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_int2     __x);
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_int3     __x);
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_int4     __x);
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_int8     __x);
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_int16    __x);
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_uint2    __x);
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_uint3    __x);
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_uint4    __x);
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_uint8    __x);
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_uint16   __x);
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_float2   __x);
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_float3   __x);
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_float4   __x);
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_float8   __x);
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_float16  __x);
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_long2    __x);
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_long3    __x);
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_long4    __x);
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_long8    __x);
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_ulong2   __x);
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_ulong3   __x);
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_ulong4   __x);
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_ulong8   __x);
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_double2  __x);
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_double3  __x);
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_double4  __x);
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_double8  __x);
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_char2    __x);
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_char3    __x);
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_char4    __x);
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_char8    __x);
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_char16   __x);
static simd_uchar32 SIMD_CFUNC simd_uchar_sat(simd_char32   __x);
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_short2   __x);
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_short3   __x);
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_short4   __x);
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_short8   __x);
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_short16  __x);
static simd_uchar32 SIMD_CFUNC simd_uchar_sat(simd_short32  __x);
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_int2     __x);
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_int3     __x);
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_int4     __x);
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_int8     __x);
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_int16    __x);
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_float2   __x);
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_float3   __x);
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_float4   __x);
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_float8   __x);
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_float16  __x);
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_long2    __x);
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_long3    __x);
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_long4    __x);
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_long8    __x);
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_double2  __x);
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_double3  __x);
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_double4  __x);
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_double8  __x);
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_uchar2   __x);
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_uchar3   __x);
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_uchar4   __x);
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_uchar8   __x);
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_uchar16  __x);
static simd_uchar32 SIMD_CFUNC simd_uchar_sat(simd_uchar32  __x);
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_ushort2  __x);
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_ushort3  __x);
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_ushort4  __x);
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_ushort8  __x);
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_ushort16 __x);
static simd_uchar32 SIMD_CFUNC simd_uchar_sat(simd_ushort32 __x);
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_uint2    __x);
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_uint3    __x);
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_uint4    __x);
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_uint8    __x);
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_uint16   __x);
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_ulong2   __x);
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_ulong3   __x);
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_ulong4   __x);
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_ulong8   __x);
#define vector_uchar simd_uchar
#define vector_uchar_sat simd_uchar_sat

static simd_short2  SIMD_CFUNC simd_short(simd_char2    __x);
static simd_short3  SIMD_CFUNC simd_short(simd_char3    __x);
static simd_short4  SIMD_CFUNC simd_short(simd_char4    __x);
static simd_short8  SIMD_CFUNC simd_short(simd_char8    __x);
static simd_short16 SIMD_CFUNC simd_short(simd_char16   __x);
static simd_short32 SIMD_CFUNC simd_short(simd_char32   __x);
static simd_short2  SIMD_CFUNC simd_short(simd_uchar2   __x);
static simd_short3  SIMD_CFUNC simd_short(simd_uchar3   __x);
static simd_short4  SIMD_CFUNC simd_short(simd_uchar4   __x);
static simd_short8  SIMD_CFUNC simd_short(simd_uchar8   __x);
static simd_short16 SIMD_CFUNC simd_short(simd_uchar16  __x);
static simd_short32 SIMD_CFUNC simd_short(simd_uchar32  __x);
static simd_short2  SIMD_CFUNC simd_short(simd_short2   __x);
static simd_short3  SIMD_CFUNC simd_short(simd_short3   __x);
static simd_short4  SIMD_CFUNC simd_short(simd_short4   __x);
static simd_short8  SIMD_CFUNC simd_short(simd_short8   __x);
static simd_short16 SIMD_CFUNC simd_short(simd_short16  __x);
static simd_short32 SIMD_CFUNC simd_short(simd_short32  __x);
static simd_short2  SIMD_CFUNC simd_short(simd_ushort2  __x);
static simd_short3  SIMD_CFUNC simd_short(simd_ushort3  __x);
static simd_short4  SIMD_CFUNC simd_short(simd_ushort4  __x);
static simd_short8  SIMD_CFUNC simd_short(simd_ushort8  __x);
static simd_short16 SIMD_CFUNC simd_short(simd_ushort16 __x);
static simd_short32 SIMD_CFUNC simd_short(simd_ushort32 __x);
static simd_short2  SIMD_CFUNC simd_short(simd_int2     __x);
static simd_short3  SIMD_CFUNC simd_short(simd_int3     __x);
static simd_short4  SIMD_CFUNC simd_short(simd_int4     __x);
static simd_short8  SIMD_CFUNC simd_short(simd_int8     __x);
static simd_short16 SIMD_CFUNC simd_short(simd_int16    __x);
static simd_short2  SIMD_CFUNC simd_short(simd_uint2    __x);
static simd_short3  SIMD_CFUNC simd_short(simd_uint3    __x);
static simd_short4  SIMD_CFUNC simd_short(simd_uint4    __x);
static simd_short8  SIMD_CFUNC simd_short(simd_uint8    __x);
static simd_short16 SIMD_CFUNC simd_short(simd_uint16   __x);
static simd_short2  SIMD_CFUNC simd_short(simd_float2   __x);
static simd_short3  SIMD_CFUNC simd_short(simd_float3   __x);
static simd_short4  SIMD_CFUNC simd_short(simd_float4   __x);
static simd_short8  SIMD_CFUNC simd_short(simd_float8   __x);
static simd_short16 SIMD_CFUNC simd_short(simd_float16  __x);
static simd_short2  SIMD_CFUNC simd_short(simd_long2    __x);
static simd_short3  SIMD_CFUNC simd_short(simd_long3    __x);
static simd_short4  SIMD_CFUNC simd_short(simd_long4    __x);
static simd_short8  SIMD_CFUNC simd_short(simd_long8    __x);
static simd_short2  SIMD_CFUNC simd_short(simd_ulong2   __x);
static simd_short3  SIMD_CFUNC simd_short(simd_ulong3   __x);
static simd_short4  SIMD_CFUNC simd_short(simd_ulong4   __x);
static simd_short8  SIMD_CFUNC simd_short(simd_ulong8   __x);
static simd_short2  SIMD_CFUNC simd_short(simd_double2  __x);
static simd_short3  SIMD_CFUNC simd_short(simd_double3  __x);
static simd_short4  SIMD_CFUNC simd_short(simd_double4  __x);
static simd_short8  SIMD_CFUNC simd_short(simd_double8  __x);
static simd_short2  SIMD_CFUNC simd_short_sat(simd_char2    __x);
static simd_short3  SIMD_CFUNC simd_short_sat(simd_char3    __x);
static simd_short4  SIMD_CFUNC simd_short_sat(simd_char4    __x);
static simd_short8  SIMD_CFUNC simd_short_sat(simd_char8    __x);
static simd_short16 SIMD_CFUNC simd_short_sat(simd_char16   __x);
static simd_short32 SIMD_CFUNC simd_short_sat(simd_char32   __x);
static simd_short2  SIMD_CFUNC simd_short_sat(simd_short2   __x);
static simd_short3  SIMD_CFUNC simd_short_sat(simd_short3   __x);
static simd_short4  SIMD_CFUNC simd_short_sat(simd_short4   __x);
static simd_short8  SIMD_CFUNC simd_short_sat(simd_short8   __x);
static simd_short16 SIMD_CFUNC simd_short_sat(simd_short16  __x);
static simd_short32 SIMD_CFUNC simd_short_sat(simd_short32  __x);
static simd_short2  SIMD_CFUNC simd_short_sat(simd_int2     __x);
static simd_short3  SIMD_CFUNC simd_short_sat(simd_int3     __x);
static simd_short4  SIMD_CFUNC simd_short_sat(simd_int4     __x);
static simd_short8  SIMD_CFUNC simd_short_sat(simd_int8     __x);
static simd_short16 SIMD_CFUNC simd_short_sat(simd_int16    __x);
static simd_short2  SIMD_CFUNC simd_short_sat(simd_float2   __x);
static simd_short3  SIMD_CFUNC simd_short_sat(simd_float3   __x);
static simd_short4  SIMD_CFUNC simd_short_sat(simd_float4   __x);
static simd_short8  SIMD_CFUNC simd_short_sat(simd_float8   __x);
static simd_short16 SIMD_CFUNC simd_short_sat(simd_float16  __x);
static simd_short2  SIMD_CFUNC simd_short_sat(simd_long2    __x);
static simd_short3  SIMD_CFUNC simd_short_sat(simd_long3    __x);
static simd_short4  SIMD_CFUNC simd_short_sat(simd_long4    __x);
static simd_short8  SIMD_CFUNC simd_short_sat(simd_long8    __x);
static simd_short2  SIMD_CFUNC simd_short_sat(simd_double2  __x);
static simd_short3  SIMD_CFUNC simd_short_sat(simd_double3  __x);
static simd_short4  SIMD_CFUNC simd_short_sat(simd_double4  __x);
static simd_short8  SIMD_CFUNC simd_short_sat(simd_double8  __x);
static simd_short2  SIMD_CFUNC simd_short_sat(simd_uchar2   __x);
static simd_short3  SIMD_CFUNC simd_short_sat(simd_uchar3   __x);
static simd_short4  SIMD_CFUNC simd_short_sat(simd_uchar4   __x);
static simd_short8  SIMD_CFUNC simd_short_sat(simd_uchar8   __x);
static simd_short16 SIMD_CFUNC simd_short_sat(simd_uchar16  __x);
static simd_short32 SIMD_CFUNC simd_short_sat(simd_uchar32  __x);
static simd_short2  SIMD_CFUNC simd_short_sat(simd_ushort2  __x);
static simd_short3  SIMD_CFUNC simd_short_sat(simd_ushort3  __x);
static simd_short4  SIMD_CFUNC simd_short_sat(simd_ushort4  __x);
static simd_short8  SIMD_CFUNC simd_short_sat(simd_ushort8  __x);
static simd_short16 SIMD_CFUNC simd_short_sat(simd_ushort16 __x);
static simd_short32 SIMD_CFUNC simd_short_sat(simd_ushort32 __x);
static simd_short2  SIMD_CFUNC simd_short_sat(simd_uint2    __x);
static simd_short3  SIMD_CFUNC simd_short_sat(simd_uint3    __x);
static simd_short4  SIMD_CFUNC simd_short_sat(simd_uint4    __x);
static simd_short8  SIMD_CFUNC simd_short_sat(simd_uint8    __x);
static simd_short16 SIMD_CFUNC simd_short_sat(simd_uint16   __x);
static simd_short2  SIMD_CFUNC simd_short_sat(simd_ulong2   __x);
static simd_short3  SIMD_CFUNC simd_short_sat(simd_ulong3   __x);
static simd_short4  SIMD_CFUNC simd_short_sat(simd_ulong4   __x);
static simd_short8  SIMD_CFUNC simd_short_sat(simd_ulong8   __x);
#define vector_short simd_short
#define vector_short_sat simd_short_sat

static simd_ushort2  SIMD_CFUNC simd_ushort(simd_char2    __x);
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_char3    __x);
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_char4    __x);
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_char8    __x);
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_char16   __x);
static simd_ushort32 SIMD_CFUNC simd_ushort(simd_char32   __x);
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_uchar2   __x);
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_uchar3   __x);
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_uchar4   __x);
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_uchar8   __x);
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_uchar16  __x);
static simd_ushort32 SIMD_CFUNC simd_ushort(simd_uchar32  __x);
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_short2   __x);
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_short3   __x);
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_short4   __x);
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_short8   __x);
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_short16  __x);
static simd_ushort32 SIMD_CFUNC simd_ushort(simd_short32  __x);
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_ushort2  __x);
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_ushort3  __x);
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_ushort4  __x);
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_ushort8  __x);
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_ushort16 __x);
static simd_ushort32 SIMD_CFUNC simd_ushort(simd_ushort32 __x);
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_int2     __x);
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_int3     __x);
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_int4     __x);
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_int8     __x);
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_int16    __x);
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_uint2    __x);
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_uint3    __x);
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_uint4    __x);
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_uint8    __x);
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_uint16   __x);
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_float2   __x);
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_float3   __x);
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_float4   __x);
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_float8   __x);
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_float16  __x);
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_long2    __x);
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_long3    __x);
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_long4    __x);
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_long8    __x);
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_ulong2   __x);
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_ulong3   __x);
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_ulong4   __x);
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_ulong8   __x);
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_double2  __x);
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_double3  __x);
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_double4  __x);
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_double8  __x);
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_char2    __x);
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_char3    __x);
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_char4    __x);
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_char8    __x);
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_char16   __x);
static simd_ushort32 SIMD_CFUNC simd_ushort_sat(simd_char32   __x);
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_short2   __x);
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_short3   __x);
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_short4   __x);
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_short8   __x);
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_short16  __x);
static simd_ushort32 SIMD_CFUNC simd_ushort_sat(simd_short32  __x);
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_int2     __x);
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_int3     __x);
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_int4     __x);
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_int8     __x);
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_int16    __x);
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_float2   __x);
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_float3   __x);
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_float4   __x);
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_float8   __x);
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_float16  __x);
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_long2    __x);
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_long3    __x);
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_long4    __x);
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_long8    __x);
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_double2  __x);
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_double3  __x);
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_double4  __x);
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_double8  __x);
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_uchar2   __x);
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_uchar3   __x);
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_uchar4   __x);
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_uchar8   __x);
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_uchar16  __x);
static simd_ushort32 SIMD_CFUNC simd_ushort_sat(simd_uchar32  __x);
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_ushort2  __x);
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_ushort3  __x);
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_ushort4  __x);
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_ushort8  __x);
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_ushort16 __x);
static simd_ushort32 SIMD_CFUNC simd_ushort_sat(simd_ushort32 __x);
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_uint2    __x);
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_uint3    __x);
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_uint4    __x);
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_uint8    __x);
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_uint16   __x);
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_ulong2   __x);
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_ulong3   __x);
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_ulong4   __x);
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_ulong8   __x);
#define vector_ushort simd_ushort
#define vector_ushort_sat simd_ushort_sat

static simd_int2  SIMD_CFUNC simd_int(simd_char2    __x);
static simd_int3  SIMD_CFUNC simd_int(simd_char3    __x);
static simd_int4  SIMD_CFUNC simd_int(simd_char4    __x);
static simd_int8  SIMD_CFUNC simd_int(simd_char8    __x);
static simd_int16 SIMD_CFUNC simd_int(simd_char16   __x);
static simd_int2  SIMD_CFUNC simd_int(simd_uchar2   __x);
static simd_int3  SIMD_CFUNC simd_int(simd_uchar3   __x);
static simd_int4  SIMD_CFUNC simd_int(simd_uchar4   __x);
static simd_int8  SIMD_CFUNC simd_int(simd_uchar8   __x);
static simd_int16 SIMD_CFUNC simd_int(simd_uchar16  __x);
static simd_int2  SIMD_CFUNC simd_int(simd_short2   __x);
static simd_int3  SIMD_CFUNC simd_int(simd_short3   __x);
static simd_int4  SIMD_CFUNC simd_int(simd_short4   __x);
static simd_int8  SIMD_CFUNC simd_int(simd_short8   __x);
static simd_int16 SIMD_CFUNC simd_int(simd_short16  __x);
static simd_int2  SIMD_CFUNC simd_int(simd_ushort2  __x);
static simd_int3  SIMD_CFUNC simd_int(simd_ushort3  __x);
static simd_int4  SIMD_CFUNC simd_int(simd_ushort4  __x);
static simd_int8  SIMD_CFUNC simd_int(simd_ushort8  __x);
static simd_int16 SIMD_CFUNC simd_int(simd_ushort16 __x);
static simd_int2  SIMD_CFUNC simd_int(simd_int2     __x);
static simd_int3  SIMD_CFUNC simd_int(simd_int3     __x);
static simd_int4  SIMD_CFUNC simd_int(simd_int4     __x);
static simd_int8  SIMD_CFUNC simd_int(simd_int8     __x);
static simd_int16 SIMD_CFUNC simd_int(simd_int16    __x);
static simd_int2  SIMD_CFUNC simd_int(simd_uint2    __x);
static simd_int3  SIMD_CFUNC simd_int(simd_uint3    __x);
static simd_int4  SIMD_CFUNC simd_int(simd_uint4    __x);
static simd_int8  SIMD_CFUNC simd_int(simd_uint8    __x);
static simd_int16 SIMD_CFUNC simd_int(simd_uint16   __x);
static simd_int2  SIMD_CFUNC simd_int(simd_float2   __x);
static simd_int3  SIMD_CFUNC simd_int(simd_float3   __x);
static simd_int4  SIMD_CFUNC simd_int(simd_float4   __x);
static simd_int8  SIMD_CFUNC simd_int(simd_float8   __x);
static simd_int16 SIMD_CFUNC simd_int(simd_float16  __x);
static simd_int2  SIMD_CFUNC simd_int(simd_long2    __x);
static simd_int3  SIMD_CFUNC simd_int(simd_long3    __x);
static simd_int4  SIMD_CFUNC simd_int(simd_long4    __x);
static simd_int8  SIMD_CFUNC simd_int(simd_long8    __x);
static simd_int2  SIMD_CFUNC simd_int(simd_ulong2   __x);
static simd_int3  SIMD_CFUNC simd_int(simd_ulong3   __x);
static simd_int4  SIMD_CFUNC simd_int(simd_ulong4   __x);
static simd_int8  SIMD_CFUNC simd_int(simd_ulong8   __x);
static simd_int2  SIMD_CFUNC simd_int(simd_double2  __x);
static simd_int3  SIMD_CFUNC simd_int(simd_double3  __x);
static simd_int4  SIMD_CFUNC simd_int(simd_double4  __x);
static simd_int8  SIMD_CFUNC simd_int(simd_double8  __x);
static simd_int2  SIMD_CFUNC simd_int_sat(simd_char2    __x);
static simd_int3  SIMD_CFUNC simd_int_sat(simd_char3    __x);
static simd_int4  SIMD_CFUNC simd_int_sat(simd_char4    __x);
static simd_int8  SIMD_CFUNC simd_int_sat(simd_char8    __x);
static simd_int16 SIMD_CFUNC simd_int_sat(simd_char16   __x);
static simd_int2  SIMD_CFUNC simd_int_sat(simd_short2   __x);
static simd_int3  SIMD_CFUNC simd_int_sat(simd_short3   __x);
static simd_int4  SIMD_CFUNC simd_int_sat(simd_short4   __x);
static simd_int8  SIMD_CFUNC simd_int_sat(simd_short8   __x);
static simd_int16 SIMD_CFUNC simd_int_sat(simd_short16  __x);
static simd_int2  SIMD_CFUNC simd_int_sat(simd_int2     __x);
static simd_int3  SIMD_CFUNC simd_int_sat(simd_int3     __x);
static simd_int4  SIMD_CFUNC simd_int_sat(simd_int4     __x);
static simd_int8  SIMD_CFUNC simd_int_sat(simd_int8     __x);
static simd_int16 SIMD_CFUNC simd_int_sat(simd_int16    __x);
static simd_int2  SIMD_CFUNC simd_int_sat(simd_float2   __x);
static simd_int3  SIMD_CFUNC simd_int_sat(simd_float3   __x);
static simd_int4  SIMD_CFUNC simd_int_sat(simd_float4   __x);
static simd_int8  SIMD_CFUNC simd_int_sat(simd_float8   __x);
static simd_int16 SIMD_CFUNC simd_int_sat(simd_float16  __x);
static simd_int2  SIMD_CFUNC simd_int_sat(simd_long2    __x);
static simd_int3  SIMD_CFUNC simd_int_sat(simd_long3    __x);
static simd_int4  SIMD_CFUNC simd_int_sat(simd_long4    __x);
static simd_int8  SIMD_CFUNC simd_int_sat(simd_long8    __x);
static simd_int2  SIMD_CFUNC simd_int_sat(simd_double2  __x);
static simd_int3  SIMD_CFUNC simd_int_sat(simd_double3  __x);
static simd_int4  SIMD_CFUNC simd_int_sat(simd_double4  __x);
static simd_int8  SIMD_CFUNC simd_int_sat(simd_double8  __x);
static simd_int2  SIMD_CFUNC simd_int_sat(simd_uchar2   __x);
static simd_int3  SIMD_CFUNC simd_int_sat(simd_uchar3   __x);
static simd_int4  SIMD_CFUNC simd_int_sat(simd_uchar4   __x);
static simd_int8  SIMD_CFUNC simd_int_sat(simd_uchar8   __x);
static simd_int16 SIMD_CFUNC simd_int_sat(simd_uchar16  __x);
static simd_int2  SIMD_CFUNC simd_int_sat(simd_ushort2  __x);
static simd_int3  SIMD_CFUNC simd_int_sat(simd_ushort3  __x);
static simd_int4  SIMD_CFUNC simd_int_sat(simd_ushort4  __x);
static simd_int8  SIMD_CFUNC simd_int_sat(simd_ushort8  __x);
static simd_int16 SIMD_CFUNC simd_int_sat(simd_ushort16 __x);
static simd_int2  SIMD_CFUNC simd_int_sat(simd_uint2    __x);
static simd_int3  SIMD_CFUNC simd_int_sat(simd_uint3    __x);
static simd_int4  SIMD_CFUNC simd_int_sat(simd_uint4    __x);
static simd_int8  SIMD_CFUNC simd_int_sat(simd_uint8    __x);
static simd_int16 SIMD_CFUNC simd_int_sat(simd_uint16   __x);
static simd_int2  SIMD_CFUNC simd_int_sat(simd_ulong2   __x);
static simd_int3  SIMD_CFUNC simd_int_sat(simd_ulong3   __x);
static simd_int4  SIMD_CFUNC simd_int_sat(simd_ulong4   __x);
static simd_int8  SIMD_CFUNC simd_int_sat(simd_ulong8   __x);
static simd_int2  SIMD_CFUNC simd_int_rte(simd_float2   __x);
static simd_int3  SIMD_CFUNC simd_int_rte(simd_float3   __x);
static simd_int4  SIMD_CFUNC simd_int_rte(simd_float4   __x);
static simd_int8  SIMD_CFUNC simd_int_rte(simd_float8   __x);
static simd_int16 SIMD_CFUNC simd_int_rte(simd_float16  __x);
#define vector_int simd_int
#define vector_int_sat simd_int_sat

static simd_uint2  SIMD_CFUNC simd_uint(simd_char2    __x);
static simd_uint3  SIMD_CFUNC simd_uint(simd_char3    __x);
static simd_uint4  SIMD_CFUNC simd_uint(simd_char4    __x);
static simd_uint8  SIMD_CFUNC simd_uint(simd_char8    __x);
static simd_uint16 SIMD_CFUNC simd_uint(simd_char16   __x);
static simd_uint2  SIMD_CFUNC simd_uint(simd_uchar2   __x);
static simd_uint3  SIMD_CFUNC simd_uint(simd_uchar3   __x);
static simd_uint4  SIMD_CFUNC simd_uint(simd_uchar4   __x);
static simd_uint8  SIMD_CFUNC simd_uint(simd_uchar8   __x);
static simd_uint16 SIMD_CFUNC simd_uint(simd_uchar16  __x);
static simd_uint2  SIMD_CFUNC simd_uint(simd_short2   __x);
static simd_uint3  SIMD_CFUNC simd_uint(simd_short3   __x);
static simd_uint4  SIMD_CFUNC simd_uint(simd_short4   __x);
static simd_uint8  SIMD_CFUNC simd_uint(simd_short8   __x);
static simd_uint16 SIMD_CFUNC simd_uint(simd_short16  __x);
static simd_uint2  SIMD_CFUNC simd_uint(simd_ushort2  __x);
static simd_uint3  SIMD_CFUNC simd_uint(simd_ushort3  __x);
static simd_uint4  SIMD_CFUNC simd_uint(simd_ushort4  __x);
static simd_uint8  SIMD_CFUNC simd_uint(simd_ushort8  __x);
static simd_uint16 SIMD_CFUNC simd_uint(simd_ushort16 __x);
static simd_uint2  SIMD_CFUNC simd_uint(simd_int2     __x);
static simd_uint3  SIMD_CFUNC simd_uint(simd_int3     __x);
static simd_uint4  SIMD_CFUNC simd_uint(simd_int4     __x);
static simd_uint8  SIMD_CFUNC simd_uint(simd_int8     __x);
static simd_uint16 SIMD_CFUNC simd_uint(simd_int16    __x);
static simd_uint2  SIMD_CFUNC simd_uint(simd_uint2    __x);
static simd_uint3  SIMD_CFUNC simd_uint(simd_uint3    __x);
static simd_uint4  SIMD_CFUNC simd_uint(simd_uint4    __x);
static simd_uint8  SIMD_CFUNC simd_uint(simd_uint8    __x);
static simd_uint16 SIMD_CFUNC simd_uint(simd_uint16   __x);
static simd_uint2  SIMD_CFUNC simd_uint(simd_float2   __x);
static simd_uint3  SIMD_CFUNC simd_uint(simd_float3   __x);
static simd_uint4  SIMD_CFUNC simd_uint(simd_float4   __x);
static simd_uint8  SIMD_CFUNC simd_uint(simd_float8   __x);
static simd_uint16 SIMD_CFUNC simd_uint(simd_float16  __x);
static simd_uint2  SIMD_CFUNC simd_uint(simd_long2    __x);
static simd_uint3  SIMD_CFUNC simd_uint(simd_long3    __x);
static simd_uint4  SIMD_CFUNC simd_uint(simd_long4    __x);
static simd_uint8  SIMD_CFUNC simd_uint(simd_long8    __x);
static simd_uint2  SIMD_CFUNC simd_uint(simd_ulong2   __x);
static simd_uint3  SIMD_CFUNC simd_uint(simd_ulong3   __x);
static simd_uint4  SIMD_CFUNC simd_uint(simd_ulong4   __x);
static simd_uint8  SIMD_CFUNC simd_uint(simd_ulong8   __x);
static simd_uint2  SIMD_CFUNC simd_uint(simd_double2  __x);
static simd_uint3  SIMD_CFUNC simd_uint(simd_double3  __x);
static simd_uint4  SIMD_CFUNC simd_uint(simd_double4  __x);
static simd_uint8  SIMD_CFUNC simd_uint(simd_double8  __x);
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_char2    __x);
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_char3    __x);
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_char4    __x);
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_char8    __x);
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_char16   __x);
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_short2   __x);
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_short3   __x);
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_short4   __x);
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_short8   __x);
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_short16  __x);
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_int2     __x);
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_int3     __x);
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_int4     __x);
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_int8     __x);
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_int16    __x);
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_float2   __x);
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_float3   __x);
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_float4   __x);
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_float8   __x);
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_float16  __x);
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_long2    __x);
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_long3    __x);
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_long4    __x);
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_long8    __x);
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_double2  __x);
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_double3  __x);
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_double4  __x);
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_double8  __x);
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_uchar2   __x);
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_uchar3   __x);
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_uchar4   __x);
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_uchar8   __x);
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_uchar16  __x);
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_ushort2  __x);
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_ushort3  __x);
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_ushort4  __x);
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_ushort8  __x);
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_ushort16 __x);
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_uint2    __x);
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_uint3    __x);
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_uint4    __x);
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_uint8    __x);
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_uint16   __x);
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_ulong2   __x);
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_ulong3   __x);
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_ulong4   __x);
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_ulong8   __x);
#define vector_uint simd_uint
#define vector_uint_sat simd_uint_sat

static simd_float2  SIMD_CFUNC simd_float(simd_char2    __x);
static simd_float3  SIMD_CFUNC simd_float(simd_char3    __x);
static simd_float4  SIMD_CFUNC simd_float(simd_char4    __x);
static simd_float8  SIMD_CFUNC simd_float(simd_char8    __x);
static simd_float16 SIMD_CFUNC simd_float(simd_char16   __x);
static simd_float2  SIMD_CFUNC simd_float(simd_uchar2   __x);
static simd_float3  SIMD_CFUNC simd_float(simd_uchar3   __x);
static simd_float4  SIMD_CFUNC simd_float(simd_uchar4   __x);
static simd_float8  SIMD_CFUNC simd_float(simd_uchar8   __x);
static simd_float16 SIMD_CFUNC simd_float(simd_uchar16  __x);
static simd_float2  SIMD_CFUNC simd_float(simd_short2   __x);
static simd_float3  SIMD_CFUNC simd_float(simd_short3   __x);
static simd_float4  SIMD_CFUNC simd_float(simd_short4   __x);
static simd_float8  SIMD_CFUNC simd_float(simd_short8   __x);
static simd_float16 SIMD_CFUNC simd_float(simd_short16  __x);
static simd_float2  SIMD_CFUNC simd_float(simd_ushort2  __x);
static simd_float3  SIMD_CFUNC simd_float(simd_ushort3  __x);
static simd_float4  SIMD_CFUNC simd_float(simd_ushort4  __x);
static simd_float8  SIMD_CFUNC simd_float(simd_ushort8  __x);
static simd_float16 SIMD_CFUNC simd_float(simd_ushort16 __x);
static simd_float2  SIMD_CFUNC simd_float(simd_int2     __x);
static simd_float3  SIMD_CFUNC simd_float(simd_int3     __x);
static simd_float4  SIMD_CFUNC simd_float(simd_int4     __x);
static simd_float8  SIMD_CFUNC simd_float(simd_int8     __x);
static simd_float16 SIMD_CFUNC simd_float(simd_int16    __x);
static simd_float2  SIMD_CFUNC simd_float(simd_uint2    __x);
static simd_float3  SIMD_CFUNC simd_float(simd_uint3    __x);
static simd_float4  SIMD_CFUNC simd_float(simd_uint4    __x);
static simd_float8  SIMD_CFUNC simd_float(simd_uint8    __x);
static simd_float16 SIMD_CFUNC simd_float(simd_uint16   __x);
static simd_float2  SIMD_CFUNC simd_float(simd_float2   __x);
static simd_float3  SIMD_CFUNC simd_float(simd_float3   __x);
static simd_float4  SIMD_CFUNC simd_float(simd_float4   __x);
static simd_float8  SIMD_CFUNC simd_float(simd_float8   __x);
static simd_float16 SIMD_CFUNC simd_float(simd_float16  __x);
static simd_float2  SIMD_CFUNC simd_float(simd_long2    __x);
static simd_float3  SIMD_CFUNC simd_float(simd_long3    __x);
static simd_float4  SIMD_CFUNC simd_float(simd_long4    __x);
static simd_float8  SIMD_CFUNC simd_float(simd_long8    __x);
static simd_float2  SIMD_CFUNC simd_float(simd_ulong2   __x);
static simd_float3  SIMD_CFUNC simd_float(simd_ulong3   __x);
static simd_float4  SIMD_CFUNC simd_float(simd_ulong4   __x);
static simd_float8  SIMD_CFUNC simd_float(simd_ulong8   __x);
static simd_float2  SIMD_CFUNC simd_float(simd_double2  __x);
static simd_float3  SIMD_CFUNC simd_float(simd_double3  __x);
static simd_float4  SIMD_CFUNC simd_float(simd_double4  __x);
static simd_float8  SIMD_CFUNC simd_float(simd_double8  __x);
#define vector_float simd_float

static simd_long2  SIMD_CFUNC simd_long(simd_char2    __x);
static simd_long3  SIMD_CFUNC simd_long(simd_char3    __x);
static simd_long4  SIMD_CFUNC simd_long(simd_char4    __x);
static simd_long8  SIMD_CFUNC simd_long(simd_char8    __x);
static simd_long2  SIMD_CFUNC simd_long(simd_uchar2   __x);
static simd_long3  SIMD_CFUNC simd_long(simd_uchar3   __x);
static simd_long4  SIMD_CFUNC simd_long(simd_uchar4   __x);
static simd_long8  SIMD_CFUNC simd_long(simd_uchar8   __x);
static simd_long2  SIMD_CFUNC simd_long(simd_short2   __x);
static simd_long3  SIMD_CFUNC simd_long(simd_short3   __x);
static simd_long4  SIMD_CFUNC simd_long(simd_short4   __x);
static simd_long8  SIMD_CFUNC simd_long(simd_short8   __x);
static simd_long2  SIMD_CFUNC simd_long(simd_ushort2  __x);
static simd_long3  SIMD_CFUNC simd_long(simd_ushort3  __x);
static simd_long4  SIMD_CFUNC simd_long(simd_ushort4  __x);
static simd_long8  SIMD_CFUNC simd_long(simd_ushort8  __x);
static simd_long2  SIMD_CFUNC simd_long(simd_int2     __x);
static simd_long3  SIMD_CFUNC simd_long(simd_int3     __x);
static simd_long4  SIMD_CFUNC simd_long(simd_int4     __x);
static simd_long8  SIMD_CFUNC simd_long(simd_int8     __x);
static simd_long2  SIMD_CFUNC simd_long(simd_uint2    __x);
static simd_long3  SIMD_CFUNC simd_long(simd_uint3    __x);
static simd_long4  SIMD_CFUNC simd_long(simd_uint4    __x);
static simd_long8  SIMD_CFUNC simd_long(simd_uint8    __x);
static simd_long2  SIMD_CFUNC simd_long(simd_float2   __x);
static simd_long3  SIMD_CFUNC simd_long(simd_float3   __x);
static simd_long4  SIMD_CFUNC simd_long(simd_float4   __x);
static simd_long8  SIMD_CFUNC simd_long(simd_float8   __x);
static simd_long2  SIMD_CFUNC simd_long(simd_long2    __x);
static simd_long3  SIMD_CFUNC simd_long(simd_long3    __x);
static simd_long4  SIMD_CFUNC simd_long(simd_long4    __x);
static simd_long8  SIMD_CFUNC simd_long(simd_long8    __x);
static simd_long2  SIMD_CFUNC simd_long(simd_ulong2   __x);
static simd_long3  SIMD_CFUNC simd_long(simd_ulong3   __x);
static simd_long4  SIMD_CFUNC simd_long(simd_ulong4   __x);
static simd_long8  SIMD_CFUNC simd_long(simd_ulong8   __x);
static simd_long2  SIMD_CFUNC simd_long(simd_double2  __x);
static simd_long3  SIMD_CFUNC simd_long(simd_double3  __x);
static simd_long4  SIMD_CFUNC simd_long(simd_double4  __x);
static simd_long8  SIMD_CFUNC simd_long(simd_double8  __x);
static simd_long2  SIMD_CFUNC simd_long_sat(simd_char2    __x);
static simd_long3  SIMD_CFUNC simd_long_sat(simd_char3    __x);
static simd_long4  SIMD_CFUNC simd_long_sat(simd_char4    __x);
static simd_long8  SIMD_CFUNC simd_long_sat(simd_char8    __x);
static simd_long2  SIMD_CFUNC simd_long_sat(simd_short2   __x);
static simd_long3  SIMD_CFUNC simd_long_sat(simd_short3   __x);
static simd_long4  SIMD_CFUNC simd_long_sat(simd_short4   __x);
static simd_long8  SIMD_CFUNC simd_long_sat(simd_short8   __x);
static simd_long2  SIMD_CFUNC simd_long_sat(simd_int2     __x);
static simd_long3  SIMD_CFUNC simd_long_sat(simd_int3     __x);
static simd_long4  SIMD_CFUNC simd_long_sat(simd_int4     __x);
static simd_long8  SIMD_CFUNC simd_long_sat(simd_int8     __x);
static simd_long2  SIMD_CFUNC simd_long_sat(simd_float2   __x);
static simd_long3  SIMD_CFUNC simd_long_sat(simd_float3   __x);
static simd_long4  SIMD_CFUNC simd_long_sat(simd_float4   __x);
static simd_long8  SIMD_CFUNC simd_long_sat(simd_float8   __x);
static simd_long2  SIMD_CFUNC simd_long_sat(simd_long2    __x);
static simd_long3  SIMD_CFUNC simd_long_sat(simd_long3    __x);
static simd_long4  SIMD_CFUNC simd_long_sat(simd_long4    __x);
static simd_long8  SIMD_CFUNC simd_long_sat(simd_long8    __x);
static simd_long2  SIMD_CFUNC simd_long_sat(simd_double2  __x);
static simd_long3  SIMD_CFUNC simd_long_sat(simd_double3  __x);
static simd_long4  SIMD_CFUNC simd_long_sat(simd_double4  __x);
static simd_long8  SIMD_CFUNC simd_long_sat(simd_double8  __x);
static simd_long2  SIMD_CFUNC simd_long_sat(simd_uchar2   __x);
static simd_long3  SIMD_CFUNC simd_long_sat(simd_uchar3   __x);
static simd_long4  SIMD_CFUNC simd_long_sat(simd_uchar4   __x);
static simd_long8  SIMD_CFUNC simd_long_sat(simd_uchar8   __x);
static simd_long2  SIMD_CFUNC simd_long_sat(simd_ushort2  __x);
static simd_long3  SIMD_CFUNC simd_long_sat(simd_ushort3  __x);
static simd_long4  SIMD_CFUNC simd_long_sat(simd_ushort4  __x);
static simd_long8  SIMD_CFUNC simd_long_sat(simd_ushort8  __x);
static simd_long2  SIMD_CFUNC simd_long_sat(simd_uint2    __x);
static simd_long3  SIMD_CFUNC simd_long_sat(simd_uint3    __x);
static simd_long4  SIMD_CFUNC simd_long_sat(simd_uint4    __x);
static simd_long8  SIMD_CFUNC simd_long_sat(simd_uint8    __x);
static simd_long2  SIMD_CFUNC simd_long_sat(simd_ulong2   __x);
static simd_long3  SIMD_CFUNC simd_long_sat(simd_ulong3   __x);
static simd_long4  SIMD_CFUNC simd_long_sat(simd_ulong4   __x);
static simd_long8  SIMD_CFUNC simd_long_sat(simd_ulong8   __x);
static simd_long2  SIMD_CFUNC simd_long_rte(simd_double2  __x);
static simd_long3  SIMD_CFUNC simd_long_rte(simd_double3  __x);
static simd_long4  SIMD_CFUNC simd_long_rte(simd_double4  __x);
static simd_long8  SIMD_CFUNC simd_long_rte(simd_double8  __x);
#define vector_long simd_long
#define vector_long_sat simd_long_sat

static simd_ulong2  SIMD_CFUNC simd_ulong(simd_char2    __x);
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_char3    __x);
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_char4    __x);
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_char8    __x);
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_uchar2   __x);
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_uchar3   __x);
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_uchar4   __x);
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_uchar8   __x);
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_short2   __x);
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_short3   __x);
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_short4   __x);
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_short8   __x);
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_ushort2  __x);
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_ushort3  __x);
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_ushort4  __x);
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_ushort8  __x);
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_int2     __x);
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_int3     __x);
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_int4     __x);
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_int8     __x);
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_uint2    __x);
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_uint3    __x);
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_uint4    __x);
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_uint8    __x);
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_float2   __x);
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_float3   __x);
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_float4   __x);
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_float8   __x);
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_long2    __x);
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_long3    __x);
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_long4    __x);
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_long8    __x);
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_ulong2   __x);
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_ulong3   __x);
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_ulong4   __x);
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_ulong8   __x);
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_double2  __x);
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_double3  __x);
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_double4  __x);
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_double8  __x);
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_char2    __x);
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_char3    __x);
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_char4    __x);
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_char8    __x);
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_short2   __x);
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_short3   __x);
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_short4   __x);
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_short8   __x);
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_int2     __x);
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_int3     __x);
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_int4     __x);
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_int8     __x);
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_float2   __x);
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_float3   __x);
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_float4   __x);
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_float8   __x);
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_long2    __x);
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_long3    __x);
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_long4    __x);
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_long8    __x);
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_double2  __x);
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_double3  __x);
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_double4  __x);
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_double8  __x);
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_uchar2   __x);
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_uchar3   __x);
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_uchar4   __x);
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_uchar8   __x);
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_ushort2  __x);
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_ushort3  __x);
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_ushort4  __x);
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_ushort8  __x);
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_uint2    __x);
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_uint3    __x);
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_uint4    __x);
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_uint8    __x);
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_ulong2   __x);
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_ulong3   __x);
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_ulong4   __x);
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_ulong8   __x);
#define vector_ulong simd_ulong
#define vector_ulong_sat simd_ulong_sat

static simd_double2  SIMD_CFUNC simd_double(simd_char2    __x);
static simd_double3  SIMD_CFUNC simd_double(simd_char3    __x);
static simd_double4  SIMD_CFUNC simd_double(simd_char4    __x);
static simd_double8  SIMD_CFUNC simd_double(simd_char8    __x);
static simd_double2  SIMD_CFUNC simd_double(simd_uchar2   __x);
static simd_double3  SIMD_CFUNC simd_double(simd_uchar3   __x);
static simd_double4  SIMD_CFUNC simd_double(simd_uchar4   __x);
static simd_double8  SIMD_CFUNC simd_double(simd_uchar8   __x);
static simd_double2  SIMD_CFUNC simd_double(simd_short2   __x);
static simd_double3  SIMD_CFUNC simd_double(simd_short3   __x);
static simd_double4  SIMD_CFUNC simd_double(simd_short4   __x);
static simd_double8  SIMD_CFUNC simd_double(simd_short8   __x);
static simd_double2  SIMD_CFUNC simd_double(simd_ushort2  __x);
static simd_double3  SIMD_CFUNC simd_double(simd_ushort3  __x);
static simd_double4  SIMD_CFUNC simd_double(simd_ushort4  __x);
static simd_double8  SIMD_CFUNC simd_double(simd_ushort8  __x);
static simd_double2  SIMD_CFUNC simd_double(simd_int2     __x);
static simd_double3  SIMD_CFUNC simd_double(simd_int3     __x);
static simd_double4  SIMD_CFUNC simd_double(simd_int4     __x);
static simd_double8  SIMD_CFUNC simd_double(simd_int8     __x);
static simd_double2  SIMD_CFUNC simd_double(simd_uint2    __x);
static simd_double3  SIMD_CFUNC simd_double(simd_uint3    __x);
static simd_double4  SIMD_CFUNC simd_double(simd_uint4    __x);
static simd_double8  SIMD_CFUNC simd_double(simd_uint8    __x);
static simd_double2  SIMD_CFUNC simd_double(simd_float2   __x);
static simd_double3  SIMD_CFUNC simd_double(simd_float3   __x);
static simd_double4  SIMD_CFUNC simd_double(simd_float4   __x);
static simd_double8  SIMD_CFUNC simd_double(simd_float8   __x);
static simd_double2  SIMD_CFUNC simd_double(simd_long2    __x);
static simd_double3  SIMD_CFUNC simd_double(simd_long3    __x);
static simd_double4  SIMD_CFUNC simd_double(simd_long4    __x);
static simd_double8  SIMD_CFUNC simd_double(simd_long8    __x);
static simd_double2  SIMD_CFUNC simd_double(simd_ulong2   __x);
static simd_double3  SIMD_CFUNC simd_double(simd_ulong3   __x);
static simd_double4  SIMD_CFUNC simd_double(simd_ulong4   __x);
static simd_double8  SIMD_CFUNC simd_double(simd_ulong8   __x);
static simd_double2  SIMD_CFUNC simd_double(simd_double2  __x);
static simd_double3  SIMD_CFUNC simd_double(simd_double3  __x);
static simd_double4  SIMD_CFUNC simd_double(simd_double4  __x);
static simd_double8  SIMD_CFUNC simd_double(simd_double8  __x);
#define vector_double simd_double

static simd_char2   SIMD_CFUNC vector2(char           __x, char           __y) { return (  simd_char2){__x, __y}; }
static simd_uchar2  SIMD_CFUNC vector2(unsigned char  __x, unsigned char  __y) { return ( simd_uchar2){__x, __y}; }
static simd_short2  SIMD_CFUNC vector2(short          __x, short          __y) { return ( simd_short2){__x, __y}; }
static simd_ushort2 SIMD_CFUNC vector2(unsigned short __x, unsigned short __y) { return (simd_ushort2){__x, __y}; }
static simd_int2    SIMD_CFUNC vector2(int            __x, int            __y) { return (   simd_int2){__x, __y}; }
static simd_uint2   SIMD_CFUNC vector2(unsigned int   __x, unsigned int   __y) { return (  simd_uint2){__x, __y}; }
static simd_float2  SIMD_CFUNC vector2(float          __x, float          __y) { return ( simd_float2){__x, __y}; }
static simd_long2   SIMD_CFUNC vector2(simd_long1   __x, simd_long1   __y) { return (  simd_long2){__x, __y}; }
static simd_ulong2  SIMD_CFUNC vector2(simd_ulong1  __x, simd_ulong1  __y) { return ( simd_ulong2){__x, __y}; }
static simd_double2 SIMD_CFUNC vector2(double         __x, double         __y) { return (simd_double2){__x, __y}; }

static simd_char3   SIMD_CFUNC vector3(char           __x, char           __y, char           __z) { return (  simd_char3){__x, __y, __z}; }
static simd_uchar3  SIMD_CFUNC vector3(unsigned char  __x, unsigned char  __y, unsigned char  __z) { return ( simd_uchar3){__x, __y, __z}; }
static simd_short3  SIMD_CFUNC vector3(short          __x, short          __y, short          __z) { return ( simd_short3){__x, __y, __z}; }
static simd_ushort3 SIMD_CFUNC vector3(unsigned short __x, unsigned short __y, unsigned short __z) { return (simd_ushort3){__x, __y, __z}; }
static simd_int3    SIMD_CFUNC vector3(int            __x, int            __y, int            __z) { return (   simd_int3){__x, __y, __z}; }
static simd_uint3   SIMD_CFUNC vector3(unsigned int   __x, unsigned int   __y, unsigned int   __z) { return (  simd_uint3){__x, __y, __z}; }
static simd_float3  SIMD_CFUNC vector3(float          __x, float          __y, float          __z) { return ( simd_float3){__x, __y, __z}; }
static simd_long3   SIMD_CFUNC vector3(simd_long1   __x, simd_long1   __y, simd_long1   __z) { return (  simd_long3){__x, __y, __z}; }
static simd_ulong3  SIMD_CFUNC vector3(simd_ulong1  __x, simd_ulong1  __y, simd_ulong1  __z) { return ( simd_ulong3){__x, __y, __z}; }
static simd_double3 SIMD_CFUNC vector3(double         __x, double         __y, double         __z) { return (simd_double3){__x, __y, __z}; }

static simd_char3   SIMD_CFUNC vector3(simd_char2   __xy, char           __z) { simd_char3   __r; __r.xy = __xy; __r.z = __z; return __r; }
static simd_uchar3  SIMD_CFUNC vector3(simd_uchar2  __xy, unsigned char  __z) { simd_uchar3  __r; __r.xy = __xy; __r.z = __z; return __r; }
static simd_short3  SIMD_CFUNC vector3(simd_short2  __xy, short          __z) { simd_short3  __r; __r.xy = __xy; __r.z = __z; return __r; }
static simd_ushort3 SIMD_CFUNC vector3(simd_ushort2 __xy, unsigned short __z) { simd_ushort3 __r; __r.xy = __xy; __r.z = __z; return __r; }
static simd_int3    SIMD_CFUNC vector3(simd_int2    __xy, int            __z) { simd_int3    __r; __r.xy = __xy; __r.z = __z; return __r; }
static simd_uint3   SIMD_CFUNC vector3(simd_uint2   __xy, unsigned int   __z) { simd_uint3   __r; __r.xy = __xy; __r.z = __z; return __r; }
static simd_float3  SIMD_CFUNC vector3(simd_float2  __xy, float          __z) { simd_float3  __r; __r.xy = __xy; __r.z = __z; return __r; }
static simd_long3   SIMD_CFUNC vector3(simd_long2   __xy, simd_long1   __z) { simd_long3   __r; __r.xy = __xy; __r.z = __z; return __r; }
static simd_ulong3  SIMD_CFUNC vector3(simd_ulong2  __xy, simd_ulong1  __z) { simd_ulong3  __r; __r.xy = __xy; __r.z = __z; return __r; }
static simd_double3 SIMD_CFUNC vector3(simd_double2 __xy, double         __z) { simd_double3 __r; __r.xy = __xy; __r.z = __z; return __r; }

static simd_char4   SIMD_CFUNC vector4(char           __x, char           __y, char           __z, char           __w) { return (  simd_char4){__x, __y, __z, __w}; }
static simd_uchar4  SIMD_CFUNC vector4(unsigned char  __x, unsigned char  __y, unsigned char  __z, unsigned char  __w) { return ( simd_uchar4){__x, __y, __z, __w}; }
static simd_short4  SIMD_CFUNC vector4(short          __x, short          __y, short          __z, short          __w) { return ( simd_short4){__x, __y, __z, __w}; }
static simd_ushort4 SIMD_CFUNC vector4(unsigned short __x, unsigned short __y, unsigned short __z, unsigned short __w) { return (simd_ushort4){__x, __y, __z, __w}; }
static simd_int4    SIMD_CFUNC vector4(int            __x, int            __y, int            __z, int            __w) { return (   simd_int4){__x, __y, __z, __w}; }
static simd_uint4   SIMD_CFUNC vector4(unsigned int   __x, unsigned int   __y, unsigned int   __z, unsigned int   __w) { return (  simd_uint4){__x, __y, __z, __w}; }
static simd_float4  SIMD_CFUNC vector4(float          __x, float          __y, float          __z, float          __w) { return ( simd_float4){__x, __y, __z, __w}; }
static simd_long4   SIMD_CFUNC vector4(simd_long1   __x, simd_long1   __y, simd_long1   __z, simd_long1   __w) { return (  simd_long4){__x, __y, __z, __w}; }
static simd_ulong4  SIMD_CFUNC vector4(simd_ulong1  __x, simd_ulong1  __y, simd_ulong1  __z, simd_ulong1  __w) { return ( simd_ulong4){__x, __y, __z, __w}; }
static simd_double4 SIMD_CFUNC vector4(double         __x, double         __y, double         __z, double         __w) { return (simd_double4){__x, __y, __z, __w}; }

static simd_char4   SIMD_CFUNC vector4(simd_char2   __xy, simd_char2   __zw) { simd_char4   __r; __r.xy = __xy; __r.zw = __zw; return __r; }
static simd_uchar4  SIMD_CFUNC vector4(simd_uchar2  __xy, simd_uchar2  __zw) { simd_uchar4  __r; __r.xy = __xy; __r.zw = __zw; return __r; }
static simd_short4  SIMD_CFUNC vector4(simd_short2  __xy, simd_short2  __zw) { simd_short4  __r; __r.xy = __xy; __r.zw = __zw; return __r; }
static simd_ushort4 SIMD_CFUNC vector4(simd_ushort2 __xy, simd_ushort2 __zw) { simd_ushort4 __r; __r.xy = __xy; __r.zw = __zw; return __r; }
static simd_int4    SIMD_CFUNC vector4(simd_int2    __xy, simd_int2    __zw) { simd_int4    __r; __r.xy = __xy; __r.zw = __zw; return __r; }
static simd_uint4   SIMD_CFUNC vector4(simd_uint2   __xy, simd_uint2   __zw) { simd_uint4   __r; __r.xy = __xy; __r.zw = __zw; return __r; }
static simd_float4  SIMD_CFUNC vector4(simd_float2  __xy, simd_float2  __zw) { simd_float4  __r; __r.xy = __xy; __r.zw = __zw; return __r; }
static simd_long4   SIMD_CFUNC vector4(simd_long2   __xy, simd_long2   __zw) { simd_long4   __r; __r.xy = __xy; __r.zw = __zw; return __r; }
static simd_ulong4  SIMD_CFUNC vector4(simd_ulong2  __xy, simd_ulong2  __zw) { simd_ulong4  __r; __r.xy = __xy; __r.zw = __zw; return __r; }
static simd_double4 SIMD_CFUNC vector4(simd_double2 __xy, simd_double2 __zw) { simd_double4 __r; __r.xy = __xy; __r.zw = __zw; return __r; }

static simd_char4   SIMD_CFUNC vector4(simd_char3   __xyz, char           __w) { simd_char4   __r; __r.xyz = __xyz; __r.w = __w; return __r; }
static simd_uchar4  SIMD_CFUNC vector4(simd_uchar3  __xyz, unsigned char  __w) { simd_uchar4  __r; __r.xyz = __xyz; __r.w = __w; return __r; }
static simd_short4  SIMD_CFUNC vector4(simd_short3  __xyz, short          __w) { simd_short4  __r; __r.xyz = __xyz; __r.w = __w; return __r; }
static simd_ushort4 SIMD_CFUNC vector4(simd_ushort3 __xyz, unsigned short __w) { simd_ushort4 __r; __r.xyz = __xyz; __r.w = __w; return __r; }
static simd_int4    SIMD_CFUNC vector4(simd_int3    __xyz, int            __w) { simd_int4    __r; __r.xyz = __xyz; __r.w = __w; return __r; }
static simd_uint4   SIMD_CFUNC vector4(simd_uint3   __xyz, unsigned int   __w) { simd_uint4   __r; __r.xyz = __xyz; __r.w = __w; return __r; }
static simd_float4  SIMD_CFUNC vector4(simd_float3  __xyz, float          __w) { simd_float4  __r; __r.xyz = __xyz; __r.w = __w; return __r; }
static simd_long4   SIMD_CFUNC vector4(simd_long3   __xyz, simd_long1   __w) { simd_long4   __r; __r.xyz = __xyz; __r.w = __w; return __r; }
static simd_ulong4  SIMD_CFUNC vector4(simd_ulong3  __xyz, simd_ulong1  __w) { simd_ulong4  __r; __r.xyz = __xyz; __r.w = __w; return __r; }
static simd_double4 SIMD_CFUNC vector4(simd_double3 __xyz, double         __w) { simd_double4 __r; __r.xyz = __xyz; __r.w = __w; return __r; }

static simd_char8   SIMD_CFUNC vector8(simd_char4   __lo, simd_char4   __hi) { simd_char8   __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_uchar8  SIMD_CFUNC vector8(simd_uchar4  __lo, simd_uchar4  __hi) { simd_uchar8  __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_short8  SIMD_CFUNC vector8(simd_short4  __lo, simd_short4  __hi) { simd_short8  __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_ushort8 SIMD_CFUNC vector8(simd_ushort4 __lo, simd_ushort4 __hi) { simd_ushort8 __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_int8    SIMD_CFUNC vector8(simd_int4    __lo, simd_int4    __hi) { simd_int8    __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_uint8   SIMD_CFUNC vector8(simd_uint4   __lo, simd_uint4   __hi) { simd_uint8   __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_float8  SIMD_CFUNC vector8(simd_float4  __lo, simd_float4  __hi) { simd_float8  __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_long8   SIMD_CFUNC vector8(simd_long4   __lo, simd_long4   __hi) { simd_long8   __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_ulong8  SIMD_CFUNC vector8(simd_ulong4  __lo, simd_ulong4  __hi) { simd_ulong8  __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_double8 SIMD_CFUNC vector8(simd_double4 __lo, simd_double4 __hi) { simd_double8 __r; __r.lo = __lo; __r.hi = __hi; return __r; }

static simd_char16   SIMD_CFUNC vector16(simd_char8   __lo, simd_char8   __hi) { simd_char16   __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_uchar16  SIMD_CFUNC vector16(simd_uchar8  __lo, simd_uchar8  __hi) { simd_uchar16  __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_short16  SIMD_CFUNC vector16(simd_short8  __lo, simd_short8  __hi) { simd_short16  __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_ushort16 SIMD_CFUNC vector16(simd_ushort8 __lo, simd_ushort8 __hi) { simd_ushort16 __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_int16    SIMD_CFUNC vector16(simd_int8    __lo, simd_int8    __hi) { simd_int16    __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_uint16   SIMD_CFUNC vector16(simd_uint8   __lo, simd_uint8   __hi) { simd_uint16   __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_float16  SIMD_CFUNC vector16(simd_float8  __lo, simd_float8  __hi) { simd_float16  __r; __r.lo = __lo; __r.hi = __hi; return __r; }

static simd_char32   SIMD_CFUNC vector32(simd_char16   __lo, simd_char16   __hi) { simd_char32   __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_uchar32  SIMD_CFUNC vector32(simd_uchar16  __lo, simd_uchar16  __hi) { simd_uchar32  __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_short32  SIMD_CFUNC vector32(simd_short16  __lo, simd_short16  __hi) { simd_short32  __r; __r.lo = __lo; __r.hi = __hi; return __r; }
static simd_ushort32 SIMD_CFUNC vector32(simd_ushort16 __lo, simd_ushort16 __hi) { simd_ushort32 __r; __r.lo = __lo; __r.hi = __hi; return __r; }

#pragma mark - Implementation

static simd_char2  SIMD_CFUNC simd_char(simd_char2    __x) { return __x; }
static simd_char3  SIMD_CFUNC simd_char(simd_char3    __x) { return __x; }
static simd_char4  SIMD_CFUNC simd_char(simd_char4    __x) { return __x; }
static simd_char8  SIMD_CFUNC simd_char(simd_char8    __x) { return __x; }
static simd_char16 SIMD_CFUNC simd_char(simd_char16   __x) { return __x; }
static simd_char32 SIMD_CFUNC simd_char(simd_char32   __x) { return __x; }
static simd_char2  SIMD_CFUNC simd_char(simd_uchar2   __x) { return (simd_char2)__x; }
static simd_char3  SIMD_CFUNC simd_char(simd_uchar3   __x) { return (simd_char3)__x; }
static simd_char4  SIMD_CFUNC simd_char(simd_uchar4   __x) { return (simd_char4)__x; }
static simd_char8  SIMD_CFUNC simd_char(simd_uchar8   __x) { return (simd_char8)__x; }
static simd_char16 SIMD_CFUNC simd_char(simd_uchar16  __x) { return (simd_char16)__x; }
static simd_char32 SIMD_CFUNC simd_char(simd_uchar32  __x) { return (simd_char32)__x; }
static simd_char2  SIMD_CFUNC simd_char(simd_short2   __x) { return __builtin_convertvector(__x & 0xff, simd_char2); }
static simd_char3  SIMD_CFUNC simd_char(simd_short3   __x) { return __builtin_convertvector(__x & 0xff, simd_char3); }
static simd_char4  SIMD_CFUNC simd_char(simd_short4   __x) { return __builtin_convertvector(__x & 0xff, simd_char4); }
static simd_char8  SIMD_CFUNC simd_char(simd_short8   __x) { return __builtin_convertvector(__x & 0xff, simd_char8); }
static simd_char16 SIMD_CFUNC simd_char(simd_short16  __x) { return __builtin_convertvector(__x & 0xff, simd_char16); }
static simd_char32 SIMD_CFUNC simd_char(simd_short32  __x) { return __builtin_convertvector(__x & 0xff, simd_char32); }
static simd_char2  SIMD_CFUNC simd_char(simd_ushort2  __x) { return simd_char(simd_short(__x)); }
static simd_char3  SIMD_CFUNC simd_char(simd_ushort3  __x) { return simd_char(simd_short(__x)); }
static simd_char4  SIMD_CFUNC simd_char(simd_ushort4  __x) { return simd_char(simd_short(__x)); }
static simd_char8  SIMD_CFUNC simd_char(simd_ushort8  __x) { return simd_char(simd_short(__x)); }
static simd_char16 SIMD_CFUNC simd_char(simd_ushort16 __x) { return simd_char(simd_short(__x)); }
static simd_char32 SIMD_CFUNC simd_char(simd_ushort32 __x) { return simd_char(simd_short(__x)); }
static simd_char2  SIMD_CFUNC simd_char(simd_int2     __x) { return simd_char(simd_short(__x)); }
static simd_char3  SIMD_CFUNC simd_char(simd_int3     __x) { return simd_char(simd_short(__x)); }
static simd_char4  SIMD_CFUNC simd_char(simd_int4     __x) { return simd_char(simd_short(__x)); }
static simd_char8  SIMD_CFUNC simd_char(simd_int8     __x) { return simd_char(simd_short(__x)); }
static simd_char16 SIMD_CFUNC simd_char(simd_int16    __x) { return simd_char(simd_short(__x)); }
static simd_char2  SIMD_CFUNC simd_char(simd_uint2    __x) { return simd_char(simd_short(__x)); }
static simd_char3  SIMD_CFUNC simd_char(simd_uint3    __x) { return simd_char(simd_short(__x)); }
static simd_char4  SIMD_CFUNC simd_char(simd_uint4    __x) { return simd_char(simd_short(__x)); }
static simd_char8  SIMD_CFUNC simd_char(simd_uint8    __x) { return simd_char(simd_short(__x)); }
static simd_char16 SIMD_CFUNC simd_char(simd_uint16   __x) { return simd_char(simd_short(__x)); }
static simd_char2  SIMD_CFUNC simd_char(simd_float2   __x) { return simd_char(simd_short(__x)); }
static simd_char3  SIMD_CFUNC simd_char(simd_float3   __x) { return simd_char(simd_short(__x)); }
static simd_char4  SIMD_CFUNC simd_char(simd_float4   __x) { return simd_char(simd_short(__x)); }
static simd_char8  SIMD_CFUNC simd_char(simd_float8   __x) { return simd_char(simd_short(__x)); }
static simd_char16 SIMD_CFUNC simd_char(simd_float16  __x) { return simd_char(simd_short(__x)); }
static simd_char2  SIMD_CFUNC simd_char(simd_long2    __x) { return simd_char(simd_short(__x)); }
static simd_char3  SIMD_CFUNC simd_char(simd_long3    __x) { return simd_char(simd_short(__x)); }
static simd_char4  SIMD_CFUNC simd_char(simd_long4    __x) { return simd_char(simd_short(__x)); }
static simd_char8  SIMD_CFUNC simd_char(simd_long8    __x) { return simd_char(simd_short(__x)); }
static simd_char2  SIMD_CFUNC simd_char(simd_ulong2   __x) { return simd_char(simd_short(__x)); }
static simd_char3  SIMD_CFUNC simd_char(simd_ulong3   __x) { return simd_char(simd_short(__x)); }
static simd_char4  SIMD_CFUNC simd_char(simd_ulong4   __x) { return simd_char(simd_short(__x)); }
static simd_char8  SIMD_CFUNC simd_char(simd_ulong8   __x) { return simd_char(simd_short(__x)); }
static simd_char2  SIMD_CFUNC simd_char(simd_double2  __x) { return simd_char(simd_short(__x)); }
static simd_char3  SIMD_CFUNC simd_char(simd_double3  __x) { return simd_char(simd_short(__x)); }
static simd_char4  SIMD_CFUNC simd_char(simd_double4  __x) { return simd_char(simd_short(__x)); }
static simd_char8  SIMD_CFUNC simd_char(simd_double8  __x) { return simd_char(simd_short(__x)); }
    
static simd_char2  SIMD_CFUNC simd_char_sat(simd_char2    __x) { return __x; }
static simd_char3  SIMD_CFUNC simd_char_sat(simd_char3    __x) { return __x; }
static simd_char4  SIMD_CFUNC simd_char_sat(simd_char4    __x) { return __x; }
static simd_char8  SIMD_CFUNC simd_char_sat(simd_char8    __x) { return __x; }
static simd_char16 SIMD_CFUNC simd_char_sat(simd_char16   __x) { return __x; }
static simd_char32 SIMD_CFUNC simd_char_sat(simd_char32   __x) { return __x; }
static simd_char2  SIMD_CFUNC simd_char_sat(simd_short2   __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char3  SIMD_CFUNC simd_char_sat(simd_short3   __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char4  SIMD_CFUNC simd_char_sat(simd_short4   __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char8  SIMD_CFUNC simd_char_sat(simd_short8   __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char16 SIMD_CFUNC simd_char_sat(simd_short16  __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char32 SIMD_CFUNC simd_char_sat(simd_short32  __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char2  SIMD_CFUNC simd_char_sat(simd_int2     __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char3  SIMD_CFUNC simd_char_sat(simd_int3     __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char4  SIMD_CFUNC simd_char_sat(simd_int4     __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char8  SIMD_CFUNC simd_char_sat(simd_int8     __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char16 SIMD_CFUNC simd_char_sat(simd_int16    __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char2  SIMD_CFUNC simd_char_sat(simd_float2   __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char3  SIMD_CFUNC simd_char_sat(simd_float3   __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char4  SIMD_CFUNC simd_char_sat(simd_float4   __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char8  SIMD_CFUNC simd_char_sat(simd_float8   __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char16 SIMD_CFUNC simd_char_sat(simd_float16  __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char2  SIMD_CFUNC simd_char_sat(simd_long2    __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char3  SIMD_CFUNC simd_char_sat(simd_long3    __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char4  SIMD_CFUNC simd_char_sat(simd_long4    __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char8  SIMD_CFUNC simd_char_sat(simd_long8    __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char2  SIMD_CFUNC simd_char_sat(simd_double2  __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char3  SIMD_CFUNC simd_char_sat(simd_double3  __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char4  SIMD_CFUNC simd_char_sat(simd_double4  __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char8  SIMD_CFUNC simd_char_sat(simd_double8  __x) { return simd_char(simd_clamp(__x,-0x80,0x7f)); }
static simd_char2  SIMD_CFUNC simd_char_sat(simd_uchar2   __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char3  SIMD_CFUNC simd_char_sat(simd_uchar3   __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char4  SIMD_CFUNC simd_char_sat(simd_uchar4   __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char8  SIMD_CFUNC simd_char_sat(simd_uchar8   __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char16 SIMD_CFUNC simd_char_sat(simd_uchar16  __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char32 SIMD_CFUNC simd_char_sat(simd_uchar32  __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char2  SIMD_CFUNC simd_char_sat(simd_ushort2  __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char3  SIMD_CFUNC simd_char_sat(simd_ushort3  __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char4  SIMD_CFUNC simd_char_sat(simd_ushort4  __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char8  SIMD_CFUNC simd_char_sat(simd_ushort8  __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char16 SIMD_CFUNC simd_char_sat(simd_ushort16 __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char32 SIMD_CFUNC simd_char_sat(simd_ushort32 __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char2  SIMD_CFUNC simd_char_sat(simd_uint2    __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char3  SIMD_CFUNC simd_char_sat(simd_uint3    __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char4  SIMD_CFUNC simd_char_sat(simd_uint4    __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char8  SIMD_CFUNC simd_char_sat(simd_uint8    __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char16 SIMD_CFUNC simd_char_sat(simd_uint16   __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char2  SIMD_CFUNC simd_char_sat(simd_ulong2   __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char3  SIMD_CFUNC simd_char_sat(simd_ulong3   __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char4  SIMD_CFUNC simd_char_sat(simd_ulong4   __x) { return simd_char(simd_min(__x,0x7f)); }
static simd_char8  SIMD_CFUNC simd_char_sat(simd_ulong8   __x) { return simd_char(simd_min(__x,0x7f)); }
    

static simd_uchar2  SIMD_CFUNC simd_uchar(simd_char2    __x) { return (simd_uchar2)__x; }
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_char3    __x) { return (simd_uchar3)__x; }
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_char4    __x) { return (simd_uchar4)__x; }
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_char8    __x) { return (simd_uchar8)__x; }
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_char16   __x) { return (simd_uchar16)__x; }
static simd_uchar32 SIMD_CFUNC simd_uchar(simd_char32   __x) { return (simd_uchar32)__x; }
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_uchar2   __x) { return __x; }
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_uchar3   __x) { return __x; }
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_uchar4   __x) { return __x; }
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_uchar8   __x) { return __x; }
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_uchar16  __x) { return __x; }
static simd_uchar32 SIMD_CFUNC simd_uchar(simd_uchar32  __x) { return __x; }
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_short2   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_short3   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_short4   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_short8   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_short16  __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar32 SIMD_CFUNC simd_uchar(simd_short32  __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_ushort2  __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_ushort3  __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_ushort4  __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_ushort8  __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_ushort16 __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar32 SIMD_CFUNC simd_uchar(simd_ushort32 __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_int2     __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_int3     __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_int4     __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_int8     __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_int16    __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_uint2    __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_uint3    __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_uint4    __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_uint8    __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_uint16   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_float2   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_float3   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_float4   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_float8   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar16 SIMD_CFUNC simd_uchar(simd_float16  __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_long2    __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_long3    __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_long4    __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_long8    __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_ulong2   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_ulong3   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_ulong4   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_ulong8   __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar2  SIMD_CFUNC simd_uchar(simd_double2  __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar3  SIMD_CFUNC simd_uchar(simd_double3  __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar4  SIMD_CFUNC simd_uchar(simd_double4  __x) { return simd_uchar(simd_char(__x)); }
static simd_uchar8  SIMD_CFUNC simd_uchar(simd_double8  __x) { return simd_uchar(simd_char(__x)); }
    
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_char2    __x) { return simd_uchar(simd_max(0,__x)); }
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_char3    __x) { return simd_uchar(simd_max(0,__x)); }
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_char4    __x) { return simd_uchar(simd_max(0,__x)); }
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_char8    __x) { return simd_uchar(simd_max(0,__x)); }
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_char16   __x) { return simd_uchar(simd_max(0,__x)); }
static simd_uchar32 SIMD_CFUNC simd_uchar_sat(simd_char32   __x) { return simd_uchar(simd_max(0,__x)); }
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_short2   __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_short3   __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_short4   __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_short8   __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_short16  __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar32 SIMD_CFUNC simd_uchar_sat(simd_short32  __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_int2     __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_int3     __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_int4     __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_int8     __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_int16    __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_float2   __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_float3   __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_float4   __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_float8   __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_float16  __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_long2    __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_long3    __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_long4    __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_long8    __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_double2  __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_double3  __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_double4  __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_double8  __x) { return simd_uchar(simd_clamp(__x,0,0xff)); }
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_uchar2   __x) { return __x; }
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_uchar3   __x) { return __x; }
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_uchar4   __x) { return __x; }
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_uchar8   __x) { return __x; }
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_uchar16  __x) { return __x; }
static simd_uchar32 SIMD_CFUNC simd_uchar_sat(simd_uchar32  __x) { return __x; }
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_ushort2  __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_ushort3  __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_ushort4  __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_ushort8  __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_ushort16 __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar32 SIMD_CFUNC simd_uchar_sat(simd_ushort32 __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_uint2    __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_uint3    __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_uint4    __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_uint8    __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar16 SIMD_CFUNC simd_uchar_sat(simd_uint16   __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar2  SIMD_CFUNC simd_uchar_sat(simd_ulong2   __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar3  SIMD_CFUNC simd_uchar_sat(simd_ulong3   __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar4  SIMD_CFUNC simd_uchar_sat(simd_ulong4   __x) { return simd_uchar(simd_min(__x,0xff)); }
static simd_uchar8  SIMD_CFUNC simd_uchar_sat(simd_ulong8   __x) { return simd_uchar(simd_min(__x,0xff)); }
    

static simd_short2  SIMD_CFUNC simd_short(simd_char2    __x) { return __builtin_convertvector(__x, simd_short2); }
static simd_short3  SIMD_CFUNC simd_short(simd_char3    __x) { return __builtin_convertvector(__x, simd_short3); }
static simd_short4  SIMD_CFUNC simd_short(simd_char4    __x) { return __builtin_convertvector(__x, simd_short4); }
static simd_short8  SIMD_CFUNC simd_short(simd_char8    __x) { return __builtin_convertvector(__x, simd_short8); }
static simd_short16 SIMD_CFUNC simd_short(simd_char16   __x) { return __builtin_convertvector(__x, simd_short16); }
static simd_short32 SIMD_CFUNC simd_short(simd_char32   __x) { return __builtin_convertvector(__x, simd_short32); }
static simd_short2  SIMD_CFUNC simd_short(simd_uchar2   __x) { return __builtin_convertvector(__x, simd_short2); }
static simd_short3  SIMD_CFUNC simd_short(simd_uchar3   __x) { return __builtin_convertvector(__x, simd_short3); }
static simd_short4  SIMD_CFUNC simd_short(simd_uchar4   __x) { return __builtin_convertvector(__x, simd_short4); }
static simd_short8  SIMD_CFUNC simd_short(simd_uchar8   __x) { return __builtin_convertvector(__x, simd_short8); }
static simd_short16 SIMD_CFUNC simd_short(simd_uchar16  __x) { return __builtin_convertvector(__x, simd_short16); }
static simd_short32 SIMD_CFUNC simd_short(simd_uchar32  __x) { return __builtin_convertvector(__x, simd_short32); }
static simd_short2  SIMD_CFUNC simd_short(simd_short2   __x) { return __x; }
static simd_short3  SIMD_CFUNC simd_short(simd_short3   __x) { return __x; }
static simd_short4  SIMD_CFUNC simd_short(simd_short4   __x) { return __x; }
static simd_short8  SIMD_CFUNC simd_short(simd_short8   __x) { return __x; }
static simd_short16 SIMD_CFUNC simd_short(simd_short16  __x) { return __x; }
static simd_short32 SIMD_CFUNC simd_short(simd_short32  __x) { return __x; }
static simd_short2  SIMD_CFUNC simd_short(simd_ushort2  __x) { return (simd_short2)__x; }
static simd_short3  SIMD_CFUNC simd_short(simd_ushort3  __x) { return (simd_short3)__x; }
static simd_short4  SIMD_CFUNC simd_short(simd_ushort4  __x) { return (simd_short4)__x; }
static simd_short8  SIMD_CFUNC simd_short(simd_ushort8  __x) { return (simd_short8)__x; }
static simd_short16 SIMD_CFUNC simd_short(simd_ushort16 __x) { return (simd_short16)__x; }
static simd_short32 SIMD_CFUNC simd_short(simd_ushort32 __x) { return (simd_short32)__x; }
static simd_short2  SIMD_CFUNC simd_short(simd_int2     __x) { return __builtin_convertvector(__x & 0xffff, simd_short2); }
static simd_short3  SIMD_CFUNC simd_short(simd_int3     __x) { return __builtin_convertvector(__x & 0xffff, simd_short3); }
static simd_short4  SIMD_CFUNC simd_short(simd_int4     __x) { return __builtin_convertvector(__x & 0xffff, simd_short4); }
static simd_short8  SIMD_CFUNC simd_short(simd_int8     __x) { return __builtin_convertvector(__x & 0xffff, simd_short8); }
static simd_short16 SIMD_CFUNC simd_short(simd_int16    __x) { return __builtin_convertvector(__x & 0xffff, simd_short16); }
static simd_short2  SIMD_CFUNC simd_short(simd_uint2    __x) { return simd_short(simd_int(__x)); }
static simd_short3  SIMD_CFUNC simd_short(simd_uint3    __x) { return simd_short(simd_int(__x)); }
static simd_short4  SIMD_CFUNC simd_short(simd_uint4    __x) { return simd_short(simd_int(__x)); }
static simd_short8  SIMD_CFUNC simd_short(simd_uint8    __x) { return simd_short(simd_int(__x)); }
static simd_short16 SIMD_CFUNC simd_short(simd_uint16   __x) { return simd_short(simd_int(__x)); }
static simd_short2  SIMD_CFUNC simd_short(simd_float2   __x) { return simd_short(simd_int(__x)); }
static simd_short3  SIMD_CFUNC simd_short(simd_float3   __x) { return simd_short(simd_int(__x)); }
static simd_short4  SIMD_CFUNC simd_short(simd_float4   __x) { return simd_short(simd_int(__x)); }
static simd_short8  SIMD_CFUNC simd_short(simd_float8   __x) { return simd_short(simd_int(__x)); }
static simd_short16 SIMD_CFUNC simd_short(simd_float16  __x) { return simd_short(simd_int(__x)); }
static simd_short2  SIMD_CFUNC simd_short(simd_long2    __x) { return simd_short(simd_int(__x)); }
static simd_short3  SIMD_CFUNC simd_short(simd_long3    __x) { return simd_short(simd_int(__x)); }
static simd_short4  SIMD_CFUNC simd_short(simd_long4    __x) { return simd_short(simd_int(__x)); }
static simd_short8  SIMD_CFUNC simd_short(simd_long8    __x) { return simd_short(simd_int(__x)); }
static simd_short2  SIMD_CFUNC simd_short(simd_ulong2   __x) { return simd_short(simd_int(__x)); }
static simd_short3  SIMD_CFUNC simd_short(simd_ulong3   __x) { return simd_short(simd_int(__x)); }
static simd_short4  SIMD_CFUNC simd_short(simd_ulong4   __x) { return simd_short(simd_int(__x)); }
static simd_short8  SIMD_CFUNC simd_short(simd_ulong8   __x) { return simd_short(simd_int(__x)); }
static simd_short2  SIMD_CFUNC simd_short(simd_double2  __x) { return simd_short(simd_int(__x)); }
static simd_short3  SIMD_CFUNC simd_short(simd_double3  __x) { return simd_short(simd_int(__x)); }
static simd_short4  SIMD_CFUNC simd_short(simd_double4  __x) { return simd_short(simd_int(__x)); }
static simd_short8  SIMD_CFUNC simd_short(simd_double8  __x) { return simd_short(simd_int(__x)); }
    
static simd_short2  SIMD_CFUNC simd_short_sat(simd_char2    __x) { return simd_short(__x); }
static simd_short3  SIMD_CFUNC simd_short_sat(simd_char3    __x) { return simd_short(__x); }
static simd_short4  SIMD_CFUNC simd_short_sat(simd_char4    __x) { return simd_short(__x); }
static simd_short8  SIMD_CFUNC simd_short_sat(simd_char8    __x) { return simd_short(__x); }
static simd_short16 SIMD_CFUNC simd_short_sat(simd_char16   __x) { return simd_short(__x); }
static simd_short32 SIMD_CFUNC simd_short_sat(simd_char32   __x) { return simd_short(__x); }
static simd_short2  SIMD_CFUNC simd_short_sat(simd_short2   __x) { return __x; }
static simd_short3  SIMD_CFUNC simd_short_sat(simd_short3   __x) { return __x; }
static simd_short4  SIMD_CFUNC simd_short_sat(simd_short4   __x) { return __x; }
static simd_short8  SIMD_CFUNC simd_short_sat(simd_short8   __x) { return __x; }
static simd_short16 SIMD_CFUNC simd_short_sat(simd_short16  __x) { return __x; }
static simd_short32 SIMD_CFUNC simd_short_sat(simd_short32  __x) { return __x; }
static simd_short2  SIMD_CFUNC simd_short_sat(simd_int2     __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short3  SIMD_CFUNC simd_short_sat(simd_int3     __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short4  SIMD_CFUNC simd_short_sat(simd_int4     __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short8  SIMD_CFUNC simd_short_sat(simd_int8     __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short16 SIMD_CFUNC simd_short_sat(simd_int16    __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short2  SIMD_CFUNC simd_short_sat(simd_float2   __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short3  SIMD_CFUNC simd_short_sat(simd_float3   __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short4  SIMD_CFUNC simd_short_sat(simd_float4   __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short8  SIMD_CFUNC simd_short_sat(simd_float8   __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short16 SIMD_CFUNC simd_short_sat(simd_float16  __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short2  SIMD_CFUNC simd_short_sat(simd_long2    __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short3  SIMD_CFUNC simd_short_sat(simd_long3    __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short4  SIMD_CFUNC simd_short_sat(simd_long4    __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short8  SIMD_CFUNC simd_short_sat(simd_long8    __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short2  SIMD_CFUNC simd_short_sat(simd_double2  __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short3  SIMD_CFUNC simd_short_sat(simd_double3  __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short4  SIMD_CFUNC simd_short_sat(simd_double4  __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short8  SIMD_CFUNC simd_short_sat(simd_double8  __x) { return simd_short(simd_clamp(__x,-0x8000,0x7fff)); }
static simd_short2  SIMD_CFUNC simd_short_sat(simd_uchar2   __x) { return simd_short(__x); }
static simd_short3  SIMD_CFUNC simd_short_sat(simd_uchar3   __x) { return simd_short(__x); }
static simd_short4  SIMD_CFUNC simd_short_sat(simd_uchar4   __x) { return simd_short(__x); }
static simd_short8  SIMD_CFUNC simd_short_sat(simd_uchar8   __x) { return simd_short(__x); }
static simd_short16 SIMD_CFUNC simd_short_sat(simd_uchar16  __x) { return simd_short(__x); }
static simd_short32 SIMD_CFUNC simd_short_sat(simd_uchar32  __x) { return simd_short(__x); }
static simd_short2  SIMD_CFUNC simd_short_sat(simd_ushort2  __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short3  SIMD_CFUNC simd_short_sat(simd_ushort3  __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short4  SIMD_CFUNC simd_short_sat(simd_ushort4  __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short8  SIMD_CFUNC simd_short_sat(simd_ushort8  __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short16 SIMD_CFUNC simd_short_sat(simd_ushort16 __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short32 SIMD_CFUNC simd_short_sat(simd_ushort32 __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short2  SIMD_CFUNC simd_short_sat(simd_uint2    __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short3  SIMD_CFUNC simd_short_sat(simd_uint3    __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short4  SIMD_CFUNC simd_short_sat(simd_uint4    __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short8  SIMD_CFUNC simd_short_sat(simd_uint8    __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short16 SIMD_CFUNC simd_short_sat(simd_uint16   __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short2  SIMD_CFUNC simd_short_sat(simd_ulong2   __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short3  SIMD_CFUNC simd_short_sat(simd_ulong3   __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short4  SIMD_CFUNC simd_short_sat(simd_ulong4   __x) { return simd_short(simd_min(__x,0x7fff)); }
static simd_short8  SIMD_CFUNC simd_short_sat(simd_ulong8   __x) { return simd_short(simd_min(__x,0x7fff)); }
    

static simd_ushort2  SIMD_CFUNC simd_ushort(simd_char2    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_char3    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_char4    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_char8    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_char16   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort32 SIMD_CFUNC simd_ushort(simd_char32   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_uchar2   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_uchar3   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_uchar4   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_uchar8   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_uchar16  __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort32 SIMD_CFUNC simd_ushort(simd_uchar32  __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_short2   __x) { return (simd_ushort2)__x; }
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_short3   __x) { return (simd_ushort3)__x; }
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_short4   __x) { return (simd_ushort4)__x; }
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_short8   __x) { return (simd_ushort8)__x; }
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_short16  __x) { return (simd_ushort16)__x; }
static simd_ushort32 SIMD_CFUNC simd_ushort(simd_short32  __x) { return (simd_ushort32)__x; }
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_ushort2  __x) { return __x; }
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_ushort3  __x) { return __x; }
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_ushort4  __x) { return __x; }
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_ushort8  __x) { return __x; }
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_ushort16 __x) { return __x; }
static simd_ushort32 SIMD_CFUNC simd_ushort(simd_ushort32 __x) { return __x; }
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_int2     __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_int3     __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_int4     __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_int8     __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_int16    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_uint2    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_uint3    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_uint4    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_uint8    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_uint16   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_float2   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_float3   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_float4   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_float8   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort16 SIMD_CFUNC simd_ushort(simd_float16  __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_long2    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_long3    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_long4    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_long8    __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_ulong2   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_ulong3   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_ulong4   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_ulong8   __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort2  SIMD_CFUNC simd_ushort(simd_double2  __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort3  SIMD_CFUNC simd_ushort(simd_double3  __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort4  SIMD_CFUNC simd_ushort(simd_double4  __x) { return simd_ushort(simd_short(__x)); }
static simd_ushort8  SIMD_CFUNC simd_ushort(simd_double8  __x) { return simd_ushort(simd_short(__x)); }
    
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_char2    __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_char3    __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_char4    __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_char8    __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_char16   __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort32 SIMD_CFUNC simd_ushort_sat(simd_char32   __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_short2   __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_short3   __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_short4   __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_short8   __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_short16  __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort32 SIMD_CFUNC simd_ushort_sat(simd_short32  __x) { return simd_ushort(simd_max(__x, 0)); }
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_int2     __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_int3     __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_int4     __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_int8     __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_int16    __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_float2   __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_float3   __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_float4   __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_float8   __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_float16  __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_long2    __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_long3    __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_long4    __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_long8    __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_double2  __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_double3  __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_double4  __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_double8  __x) { return simd_ushort(simd_clamp(__x, 0, 0xffff)); }
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_uchar2   __x) { return simd_ushort(__x); }
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_uchar3   __x) { return simd_ushort(__x); }
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_uchar4   __x) { return simd_ushort(__x); }
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_uchar8   __x) { return simd_ushort(__x); }
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_uchar16  __x) { return simd_ushort(__x); }
static simd_ushort32 SIMD_CFUNC simd_ushort_sat(simd_uchar32  __x) { return simd_ushort(__x); }
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_ushort2  __x) { return __x; }
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_ushort3  __x) { return __x; }
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_ushort4  __x) { return __x; }
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_ushort8  __x) { return __x; }
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_ushort16 __x) { return __x; }
static simd_ushort32 SIMD_CFUNC simd_ushort_sat(simd_ushort32 __x) { return __x; }
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_uint2    __x) { return simd_ushort(simd_min(__x, 0xffff)); }
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_uint3    __x) { return simd_ushort(simd_min(__x, 0xffff)); }
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_uint4    __x) { return simd_ushort(simd_min(__x, 0xffff)); }
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_uint8    __x) { return simd_ushort(simd_min(__x, 0xffff)); }
static simd_ushort16 SIMD_CFUNC simd_ushort_sat(simd_uint16   __x) { return simd_ushort(simd_min(__x, 0xffff)); }
static simd_ushort2  SIMD_CFUNC simd_ushort_sat(simd_ulong2   __x) { return simd_ushort(simd_min(__x, 0xffff)); }
static simd_ushort3  SIMD_CFUNC simd_ushort_sat(simd_ulong3   __x) { return simd_ushort(simd_min(__x, 0xffff)); }
static simd_ushort4  SIMD_CFUNC simd_ushort_sat(simd_ulong4   __x) { return simd_ushort(simd_min(__x, 0xffff)); }
static simd_ushort8  SIMD_CFUNC simd_ushort_sat(simd_ulong8   __x) { return simd_ushort(simd_min(__x, 0xffff)); }
    

static simd_int2  SIMD_CFUNC simd_int(simd_char2    __x) { return __builtin_convertvector(__x, simd_int2); }
static simd_int3  SIMD_CFUNC simd_int(simd_char3    __x) { return __builtin_convertvector(__x, simd_int3); }
static simd_int4  SIMD_CFUNC simd_int(simd_char4    __x) { return __builtin_convertvector(__x, simd_int4); }
static simd_int8  SIMD_CFUNC simd_int(simd_char8    __x) { return __builtin_convertvector(__x, simd_int8); }
static simd_int16 SIMD_CFUNC simd_int(simd_char16   __x) { return __builtin_convertvector(__x, simd_int16); }
static simd_int2  SIMD_CFUNC simd_int(simd_uchar2   __x) { return __builtin_convertvector(__x, simd_int2); }
static simd_int3  SIMD_CFUNC simd_int(simd_uchar3   __x) { return __builtin_convertvector(__x, simd_int3); }
static simd_int4  SIMD_CFUNC simd_int(simd_uchar4   __x) { return __builtin_convertvector(__x, simd_int4); }
static simd_int8  SIMD_CFUNC simd_int(simd_uchar8   __x) { return __builtin_convertvector(__x, simd_int8); }
static simd_int16 SIMD_CFUNC simd_int(simd_uchar16  __x) { return __builtin_convertvector(__x, simd_int16); }
static simd_int2  SIMD_CFUNC simd_int(simd_short2   __x) { return __builtin_convertvector(__x, simd_int2); }
static simd_int3  SIMD_CFUNC simd_int(simd_short3   __x) { return __builtin_convertvector(__x, simd_int3); }
static simd_int4  SIMD_CFUNC simd_int(simd_short4   __x) { return __builtin_convertvector(__x, simd_int4); }
static simd_int8  SIMD_CFUNC simd_int(simd_short8   __x) { return __builtin_convertvector(__x, simd_int8); }
static simd_int16 SIMD_CFUNC simd_int(simd_short16  __x) { return __builtin_convertvector(__x, simd_int16); }
static simd_int2  SIMD_CFUNC simd_int(simd_ushort2  __x) { return __builtin_convertvector(__x, simd_int2); }
static simd_int3  SIMD_CFUNC simd_int(simd_ushort3  __x) { return __builtin_convertvector(__x, simd_int3); }
static simd_int4  SIMD_CFUNC simd_int(simd_ushort4  __x) { return __builtin_convertvector(__x, simd_int4); }
static simd_int8  SIMD_CFUNC simd_int(simd_ushort8  __x) { return __builtin_convertvector(__x, simd_int8); }
static simd_int16 SIMD_CFUNC simd_int(simd_ushort16 __x) { return __builtin_convertvector(__x, simd_int16); }
static simd_int2  SIMD_CFUNC simd_int(simd_int2     __x) { return __x; }
static simd_int3  SIMD_CFUNC simd_int(simd_int3     __x) { return __x; }
static simd_int4  SIMD_CFUNC simd_int(simd_int4     __x) { return __x; }
static simd_int8  SIMD_CFUNC simd_int(simd_int8     __x) { return __x; }
static simd_int16 SIMD_CFUNC simd_int(simd_int16    __x) { return __x; }
static simd_int2  SIMD_CFUNC simd_int(simd_uint2    __x) { return (simd_int2)__x; }
static simd_int3  SIMD_CFUNC simd_int(simd_uint3    __x) { return (simd_int3)__x; }
static simd_int4  SIMD_CFUNC simd_int(simd_uint4    __x) { return (simd_int4)__x; }
static simd_int8  SIMD_CFUNC simd_int(simd_uint8    __x) { return (simd_int8)__x; }
static simd_int16 SIMD_CFUNC simd_int(simd_uint16   __x) { return (simd_int16)__x; }
static simd_int2  SIMD_CFUNC simd_int(simd_float2   __x) { return __builtin_convertvector(__x, simd_int2); }
static simd_int3  SIMD_CFUNC simd_int(simd_float3   __x) { return __builtin_convertvector(__x, simd_int3); }
static simd_int4  SIMD_CFUNC simd_int(simd_float4   __x) { return __builtin_convertvector(__x, simd_int4); }
static simd_int8  SIMD_CFUNC simd_int(simd_float8   __x) { return __builtin_convertvector(__x, simd_int8); }
static simd_int16 SIMD_CFUNC simd_int(simd_float16  __x) { return __builtin_convertvector(__x, simd_int16); }
static simd_int2  SIMD_CFUNC simd_int(simd_long2    __x) { return __builtin_convertvector(__x & 0xffffffff, simd_int2); }
static simd_int3  SIMD_CFUNC simd_int(simd_long3    __x) { return __builtin_convertvector(__x & 0xffffffff, simd_int3); }
static simd_int4  SIMD_CFUNC simd_int(simd_long4    __x) { return __builtin_convertvector(__x & 0xffffffff, simd_int4); }
static simd_int8  SIMD_CFUNC simd_int(simd_long8    __x) { return __builtin_convertvector(__x & 0xffffffff, simd_int8); }
static simd_int2  SIMD_CFUNC simd_int(simd_ulong2   __x) { return simd_int(simd_long(__x)); }
static simd_int3  SIMD_CFUNC simd_int(simd_ulong3   __x) { return simd_int(simd_long(__x)); }
static simd_int4  SIMD_CFUNC simd_int(simd_ulong4   __x) { return simd_int(simd_long(__x)); }
static simd_int8  SIMD_CFUNC simd_int(simd_ulong8   __x) { return simd_int(simd_long(__x)); }
static simd_int2  SIMD_CFUNC simd_int(simd_double2  __x) { return __builtin_convertvector(__x, simd_int2); }
static simd_int3  SIMD_CFUNC simd_int(simd_double3  __x) { return __builtin_convertvector(__x, simd_int3); }
static simd_int4  SIMD_CFUNC simd_int(simd_double4  __x) { return __builtin_convertvector(__x, simd_int4); }
static simd_int8  SIMD_CFUNC simd_int(simd_double8  __x) { return __builtin_convertvector(__x, simd_int8); }
    
static simd_int2  SIMD_CFUNC simd_int_sat(simd_char2    __x) { return simd_int(__x); }
static simd_int3  SIMD_CFUNC simd_int_sat(simd_char3    __x) { return simd_int(__x); }
static simd_int4  SIMD_CFUNC simd_int_sat(simd_char4    __x) { return simd_int(__x); }
static simd_int8  SIMD_CFUNC simd_int_sat(simd_char8    __x) { return simd_int(__x); }
static simd_int16 SIMD_CFUNC simd_int_sat(simd_char16   __x) { return simd_int(__x); }
static simd_int2  SIMD_CFUNC simd_int_sat(simd_short2   __x) { return simd_int(__x); }
static simd_int3  SIMD_CFUNC simd_int_sat(simd_short3   __x) { return simd_int(__x); }
static simd_int4  SIMD_CFUNC simd_int_sat(simd_short4   __x) { return simd_int(__x); }
static simd_int8  SIMD_CFUNC simd_int_sat(simd_short8   __x) { return simd_int(__x); }
static simd_int16 SIMD_CFUNC simd_int_sat(simd_short16  __x) { return simd_int(__x); }
static simd_int2  SIMD_CFUNC simd_int_sat(simd_int2     __x) { return __x; }
static simd_int3  SIMD_CFUNC simd_int_sat(simd_int3     __x) { return __x; }
static simd_int4  SIMD_CFUNC simd_int_sat(simd_int4     __x) { return __x; }
static simd_int8  SIMD_CFUNC simd_int_sat(simd_int8     __x) { return __x; }
static simd_int16 SIMD_CFUNC simd_int_sat(simd_int16    __x) { return __x; }
static simd_int2  SIMD_CFUNC simd_int_sat(simd_float2   __x) { return simd_bitselect(simd_int(simd_max(__x,-0x1.0p31f)), 0x7fffffff, __x >= 0x1.0p31f); }
static simd_int3  SIMD_CFUNC simd_int_sat(simd_float3   __x) { return simd_bitselect(simd_int(simd_max(__x,-0x1.0p31f)), 0x7fffffff, __x >= 0x1.0p31f); }
static simd_int4  SIMD_CFUNC simd_int_sat(simd_float4   __x) { return simd_bitselect(simd_int(simd_max(__x,-0x1.0p31f)), 0x7fffffff, __x >= 0x1.0p31f); }
static simd_int8  SIMD_CFUNC simd_int_sat(simd_float8   __x) { return simd_bitselect(simd_int(simd_max(__x,-0x1.0p31f)), 0x7fffffff, __x >= 0x1.0p31f); }
static simd_int16 SIMD_CFUNC simd_int_sat(simd_float16  __x) { return simd_bitselect(simd_int(simd_max(__x,-0x1.0p31f)), 0x7fffffff, __x >= 0x1.0p31f); }
static simd_int2  SIMD_CFUNC simd_int_sat(simd_long2    __x) { return simd_int(simd_clamp(__x,-0x80000000LL,0x7fffffffLL)); }
static simd_int3  SIMD_CFUNC simd_int_sat(simd_long3    __x) { return simd_int(simd_clamp(__x,-0x80000000LL,0x7fffffffLL)); }
static simd_int4  SIMD_CFUNC simd_int_sat(simd_long4    __x) { return simd_int(simd_clamp(__x,-0x80000000LL,0x7fffffffLL)); }
static simd_int8  SIMD_CFUNC simd_int_sat(simd_long8    __x) { return simd_int(simd_clamp(__x,-0x80000000LL,0x7fffffffLL)); }
static simd_int2  SIMD_CFUNC simd_int_sat(simd_double2  __x) { return simd_int(simd_clamp(__x,-0x1.0p31,0x1.fffffffcp30)); }
static simd_int3  SIMD_CFUNC simd_int_sat(simd_double3  __x) { return simd_int(simd_clamp(__x,-0x1.0p31,0x1.fffffffcp30)); }
static simd_int4  SIMD_CFUNC simd_int_sat(simd_double4  __x) { return simd_int(simd_clamp(__x,-0x1.0p31,0x1.fffffffcp30)); }
static simd_int8  SIMD_CFUNC simd_int_sat(simd_double8  __x) { return simd_int(simd_clamp(__x,-0x1.0p31,0x1.fffffffcp30)); }
static simd_int2  SIMD_CFUNC simd_int_sat(simd_uchar2   __x) { return simd_int(__x); }
static simd_int3  SIMD_CFUNC simd_int_sat(simd_uchar3   __x) { return simd_int(__x); }
static simd_int4  SIMD_CFUNC simd_int_sat(simd_uchar4   __x) { return simd_int(__x); }
static simd_int8  SIMD_CFUNC simd_int_sat(simd_uchar8   __x) { return simd_int(__x); }
static simd_int16 SIMD_CFUNC simd_int_sat(simd_uchar16  __x) { return simd_int(__x); }
static simd_int2  SIMD_CFUNC simd_int_sat(simd_ushort2  __x) { return simd_int(__x); }
static simd_int3  SIMD_CFUNC simd_int_sat(simd_ushort3  __x) { return simd_int(__x); }
static simd_int4  SIMD_CFUNC simd_int_sat(simd_ushort4  __x) { return simd_int(__x); }
static simd_int8  SIMD_CFUNC simd_int_sat(simd_ushort8  __x) { return simd_int(__x); }
static simd_int16 SIMD_CFUNC simd_int_sat(simd_ushort16 __x) { return simd_int(__x); }
static simd_int2  SIMD_CFUNC simd_int_sat(simd_uint2    __x) { return simd_int(simd_min(__x,0x7fffffff)); }
static simd_int3  SIMD_CFUNC simd_int_sat(simd_uint3    __x) { return simd_int(simd_min(__x,0x7fffffff)); }
static simd_int4  SIMD_CFUNC simd_int_sat(simd_uint4    __x) { return simd_int(simd_min(__x,0x7fffffff)); }
static simd_int8  SIMD_CFUNC simd_int_sat(simd_uint8    __x) { return simd_int(simd_min(__x,0x7fffffff)); }
static simd_int16 SIMD_CFUNC simd_int_sat(simd_uint16   __x) { return simd_int(simd_min(__x,0x7fffffff)); }
static simd_int2  SIMD_CFUNC simd_int_sat(simd_ulong2   __x) { return simd_int(simd_min(__x,0x7fffffff)); }
static simd_int3  SIMD_CFUNC simd_int_sat(simd_ulong3   __x) { return simd_int(simd_min(__x,0x7fffffff)); }
static simd_int4  SIMD_CFUNC simd_int_sat(simd_ulong4   __x) { return simd_int(simd_min(__x,0x7fffffff)); }
static simd_int8  SIMD_CFUNC simd_int_sat(simd_ulong8   __x) { return simd_int(simd_min(__x,0x7fffffff)); }
    
static simd_int2  SIMD_CFUNC simd_int_rte(simd_float2   __x) {
#if defined __arm64__
  return vcvtn_s32_f32(__x);
#else
  return simd_make_int2(simd_int_rte(simd_make_float4_undef(__x)));
#endif
}

static simd_int3  SIMD_CFUNC simd_int_rte(simd_float3   __x) {
  return simd_make_int3(simd_int_rte(simd_make_float4_undef(__x)));
}

static simd_int4  SIMD_CFUNC simd_int_rte(simd_float4   __x) {
#if defined __SSE2__
  return _mm_cvtps_epi32(__x);
#elif defined __arm64__
  return vcvtnq_s32_f32(__x);
#else
  simd_float4 magic = __tg_copysign(0x1.0p23, __x);
  simd_int4 x_is_small = __tg_fabs(__x) < 0x1.0p23;
  return __builtin_convertvector(simd_bitselect(__x, (__x + magic) - magic, x_is_small & 0x7fffffff), simd_int4);
#endif
}

static simd_int8  SIMD_CFUNC simd_int_rte(simd_float8   __x) {
#if defined __AVX__
  return _mm256_cvtps_epi32(__x);
#else
  return simd_make_int8(simd_int_rte(__x.lo), simd_int_rte(__x.hi));
#endif
}

static simd_int16 SIMD_CFUNC simd_int_rte(simd_float16  __x) {
#if defined __AVX512F__
  return _mm512_cvt_roundps_epi32(__x, _MM_FROUND_RINT);
#else
  return simd_make_int16(simd_int_rte(__x.lo), simd_int_rte(__x.hi));
#endif
}

static simd_uint2  SIMD_CFUNC simd_uint(simd_char2    __x) { return simd_uint(simd_int(__x)); }
static simd_uint3  SIMD_CFUNC simd_uint(simd_char3    __x) { return simd_uint(simd_int(__x)); }
static simd_uint4  SIMD_CFUNC simd_uint(simd_char4    __x) { return simd_uint(simd_int(__x)); }
static simd_uint8  SIMD_CFUNC simd_uint(simd_char8    __x) { return simd_uint(simd_int(__x)); }
static simd_uint16 SIMD_CFUNC simd_uint(simd_char16   __x) { return simd_uint(simd_int(__x)); }
static simd_uint2  SIMD_CFUNC simd_uint(simd_uchar2   __x) { return simd_uint(simd_int(__x)); }
static simd_uint3  SIMD_CFUNC simd_uint(simd_uchar3   __x) { return simd_uint(simd_int(__x)); }
static simd_uint4  SIMD_CFUNC simd_uint(simd_uchar4   __x) { return simd_uint(simd_int(__x)); }
static simd_uint8  SIMD_CFUNC simd_uint(simd_uchar8   __x) { return simd_uint(simd_int(__x)); }
static simd_uint16 SIMD_CFUNC simd_uint(simd_uchar16  __x) { return simd_uint(simd_int(__x)); }
static simd_uint2  SIMD_CFUNC simd_uint(simd_short2   __x) { return simd_uint(simd_int(__x)); }
static simd_uint3  SIMD_CFUNC simd_uint(simd_short3   __x) { return simd_uint(simd_int(__x)); }
static simd_uint4  SIMD_CFUNC simd_uint(simd_short4   __x) { return simd_uint(simd_int(__x)); }
static simd_uint8  SIMD_CFUNC simd_uint(simd_short8   __x) { return simd_uint(simd_int(__x)); }
static simd_uint16 SIMD_CFUNC simd_uint(simd_short16  __x) { return simd_uint(simd_int(__x)); }
static simd_uint2  SIMD_CFUNC simd_uint(simd_ushort2  __x) { return simd_uint(simd_int(__x)); }
static simd_uint3  SIMD_CFUNC simd_uint(simd_ushort3  __x) { return simd_uint(simd_int(__x)); }
static simd_uint4  SIMD_CFUNC simd_uint(simd_ushort4  __x) { return simd_uint(simd_int(__x)); }
static simd_uint8  SIMD_CFUNC simd_uint(simd_ushort8  __x) { return simd_uint(simd_int(__x)); }
static simd_uint16 SIMD_CFUNC simd_uint(simd_ushort16 __x) { return simd_uint(simd_int(__x)); }
static simd_uint2  SIMD_CFUNC simd_uint(simd_int2     __x) { return (simd_uint2)__x; }
static simd_uint3  SIMD_CFUNC simd_uint(simd_int3     __x) { return (simd_uint3)__x; }
static simd_uint4  SIMD_CFUNC simd_uint(simd_int4     __x) { return (simd_uint4)__x; }
static simd_uint8  SIMD_CFUNC simd_uint(simd_int8     __x) { return (simd_uint8)__x; }
static simd_uint16 SIMD_CFUNC simd_uint(simd_int16    __x) { return (simd_uint16)__x; }
static simd_uint2  SIMD_CFUNC simd_uint(simd_uint2    __x) { return __x; }
static simd_uint3  SIMD_CFUNC simd_uint(simd_uint3    __x) { return __x; }
static simd_uint4  SIMD_CFUNC simd_uint(simd_uint4    __x) { return __x; }
static simd_uint8  SIMD_CFUNC simd_uint(simd_uint8    __x) { return __x; }
static simd_uint16 SIMD_CFUNC simd_uint(simd_uint16   __x) { return __x; }
static simd_uint2  SIMD_CFUNC simd_uint(simd_float2   __x) { simd_int2  __big = __x > 0x1.0p31f; return simd_uint(simd_int(__x - simd_bitselect((simd_float2)0,0x1.0p31f,__big))) + simd_bitselect((simd_uint2)0,0x80000000,__big); }
static simd_uint3  SIMD_CFUNC simd_uint(simd_float3   __x) { simd_int3  __big = __x > 0x1.0p31f; return simd_uint(simd_int(__x - simd_bitselect((simd_float3)0,0x1.0p31f,__big))) + simd_bitselect((simd_uint3)0,0x80000000,__big); }
static simd_uint4  SIMD_CFUNC simd_uint(simd_float4   __x) { simd_int4  __big = __x > 0x1.0p31f; return simd_uint(simd_int(__x - simd_bitselect((simd_float4)0,0x1.0p31f,__big))) + simd_bitselect((simd_uint4)0,0x80000000,__big); }
static simd_uint8  SIMD_CFUNC simd_uint(simd_float8   __x) { simd_int8  __big = __x > 0x1.0p31f; return simd_uint(simd_int(__x - simd_bitselect((simd_float8)0,0x1.0p31f,__big))) + simd_bitselect((simd_uint8)0,0x80000000,__big); }
static simd_uint16 SIMD_CFUNC simd_uint(simd_float16  __x) { simd_int16 __big = __x > 0x1.0p31f; return simd_uint(simd_int(__x - simd_bitselect((simd_float16)0,0x1.0p31f,__big))) + simd_bitselect((simd_uint16)0,0x80000000,__big); }
static simd_uint2  SIMD_CFUNC simd_uint(simd_long2    __x) { return simd_uint(simd_int(__x)); }
static simd_uint3  SIMD_CFUNC simd_uint(simd_long3    __x) { return simd_uint(simd_int(__x)); }
static simd_uint4  SIMD_CFUNC simd_uint(simd_long4    __x) { return simd_uint(simd_int(__x)); }
static simd_uint8  SIMD_CFUNC simd_uint(simd_long8    __x) { return simd_uint(simd_int(__x)); }
static simd_uint2  SIMD_CFUNC simd_uint(simd_ulong2   __x) { return simd_uint(simd_int(__x)); }
static simd_uint3  SIMD_CFUNC simd_uint(simd_ulong3   __x) { return simd_uint(simd_int(__x)); }
static simd_uint4  SIMD_CFUNC simd_uint(simd_ulong4   __x) { return simd_uint(simd_int(__x)); }
static simd_uint8  SIMD_CFUNC simd_uint(simd_ulong8   __x) { return simd_uint(simd_int(__x)); }
static simd_uint2  SIMD_CFUNC simd_uint(simd_double2  __x) { simd_long2 __big = __x > 0x1.fffffffcp30; return simd_uint(simd_int(__x - simd_bitselect((simd_double2)0,0x1.0p31,__big))) + simd_bitselect((simd_uint2)0,0x80000000,simd_int(__big)); }
static simd_uint3  SIMD_CFUNC simd_uint(simd_double3  __x) { simd_long3 __big = __x > 0x1.fffffffcp30; return simd_uint(simd_int(__x - simd_bitselect((simd_double3)0,0x1.0p31,__big))) + simd_bitselect((simd_uint3)0,0x80000000,simd_int(__big)); }
static simd_uint4  SIMD_CFUNC simd_uint(simd_double4  __x) { simd_long4 __big = __x > 0x1.fffffffcp30; return simd_uint(simd_int(__x - simd_bitselect((simd_double4)0,0x1.0p31,__big))) + simd_bitselect((simd_uint4)0,0x80000000,simd_int(__big)); }
static simd_uint8  SIMD_CFUNC simd_uint(simd_double8  __x) { simd_long8 __big = __x > 0x1.fffffffcp30; return simd_uint(simd_int(__x - simd_bitselect((simd_double8)0,0x1.0p31,__big))) + simd_bitselect((simd_uint8)0,0x80000000,simd_int(__big)); }
    
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_char2    __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_char3    __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_char4    __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_char8    __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_char16   __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_short2   __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_short3   __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_short4   __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_short8   __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_short16  __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_int2     __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_int3     __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_int4     __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_int8     __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_int16    __x) { return simd_uint(simd_max(__x,0)); }
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_float2   __x) { return simd_bitselect(simd_uint(simd_max(__x,0)), 0xffffffff, __x >= 0x1.0p32f); }
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_float3   __x) { return simd_bitselect(simd_uint(simd_max(__x,0)), 0xffffffff, __x >= 0x1.0p32f); }
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_float4   __x) { return simd_bitselect(simd_uint(simd_max(__x,0)), 0xffffffff, __x >= 0x1.0p32f); }
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_float8   __x) { return simd_bitselect(simd_uint(simd_max(__x,0)), 0xffffffff, __x >= 0x1.0p32f); }
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_float16  __x) { return simd_bitselect(simd_uint(simd_max(__x,0)), 0xffffffff, __x >= 0x1.0p32f); }
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_long2    __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_long3    __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_long4    __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_long8    __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_double2  __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_double3  __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_double4  __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_double8  __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_uchar2   __x) { return simd_uint(__x); }
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_uchar3   __x) { return simd_uint(__x); }
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_uchar4   __x) { return simd_uint(__x); }
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_uchar8   __x) { return simd_uint(__x); }
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_uchar16  __x) { return simd_uint(__x); }
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_ushort2  __x) { return simd_uint(__x); }
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_ushort3  __x) { return simd_uint(__x); }
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_ushort4  __x) { return simd_uint(__x); }
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_ushort8  __x) { return simd_uint(__x); }
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_ushort16 __x) { return simd_uint(__x); }
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_uint2    __x) { return __x; }
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_uint3    __x) { return __x; }
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_uint4    __x) { return __x; }
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_uint8    __x) { return __x; }
static simd_uint16 SIMD_CFUNC simd_uint_sat(simd_uint16   __x) { return __x; }
static simd_uint2  SIMD_CFUNC simd_uint_sat(simd_ulong2   __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
static simd_uint3  SIMD_CFUNC simd_uint_sat(simd_ulong3   __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
static simd_uint4  SIMD_CFUNC simd_uint_sat(simd_ulong4   __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
static simd_uint8  SIMD_CFUNC simd_uint_sat(simd_ulong8   __x) { return simd_uint(simd_clamp(__x,0,0xffffffff)); }
    

static simd_float2  SIMD_CFUNC simd_float(simd_char2    __x) { return (simd_float2)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float3  SIMD_CFUNC simd_float(simd_char3    __x) { return (simd_float3)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float4  SIMD_CFUNC simd_float(simd_char4    __x) { return (simd_float4)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float8  SIMD_CFUNC simd_float(simd_char8    __x) { return (simd_float8)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float16 SIMD_CFUNC simd_float(simd_char16   __x) { return (simd_float16)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float2  SIMD_CFUNC simd_float(simd_uchar2   __x) { return (simd_float2)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float3  SIMD_CFUNC simd_float(simd_uchar3   __x) { return (simd_float3)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float4  SIMD_CFUNC simd_float(simd_uchar4   __x) { return (simd_float4)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float8  SIMD_CFUNC simd_float(simd_uchar8   __x) { return (simd_float8)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float16 SIMD_CFUNC simd_float(simd_uchar16  __x) { return (simd_float16)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float2  SIMD_CFUNC simd_float(simd_short2   __x) { return (simd_float2)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float3  SIMD_CFUNC simd_float(simd_short3   __x) { return (simd_float3)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float4  SIMD_CFUNC simd_float(simd_short4   __x) { return (simd_float4)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float8  SIMD_CFUNC simd_float(simd_short8   __x) { return (simd_float8)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float16 SIMD_CFUNC simd_float(simd_short16  __x) { return (simd_float16)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float2  SIMD_CFUNC simd_float(simd_ushort2  __x) { return (simd_float2)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float3  SIMD_CFUNC simd_float(simd_ushort3  __x) { return (simd_float3)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float4  SIMD_CFUNC simd_float(simd_ushort4  __x) { return (simd_float4)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float8  SIMD_CFUNC simd_float(simd_ushort8  __x) { return (simd_float8)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float16 SIMD_CFUNC simd_float(simd_ushort16 __x) { return (simd_float16)(simd_int(__x) + 0x4b400000) - 0x1.8p23f; }
static simd_float2  SIMD_CFUNC simd_float(simd_int2     __x) { return __builtin_convertvector(__x,simd_float2); }
static simd_float3  SIMD_CFUNC simd_float(simd_int3     __x) { return __builtin_convertvector(__x,simd_float3); }
static simd_float4  SIMD_CFUNC simd_float(simd_int4     __x) { return __builtin_convertvector(__x,simd_float4); }
static simd_float8  SIMD_CFUNC simd_float(simd_int8     __x) { return __builtin_convertvector(__x,simd_float8); }
static simd_float16 SIMD_CFUNC simd_float(simd_int16    __x) { return __builtin_convertvector(__x,simd_float16); }
static simd_float2  SIMD_CFUNC simd_float(simd_uint2    __x) { return __builtin_convertvector(__x,simd_float2); }
static simd_float3  SIMD_CFUNC simd_float(simd_uint3    __x) { return __builtin_convertvector(__x,simd_float3); }
static simd_float4  SIMD_CFUNC simd_float(simd_uint4    __x) { return __builtin_convertvector(__x,simd_float4); }
static simd_float8  SIMD_CFUNC simd_float(simd_uint8    __x) { return __builtin_convertvector(__x,simd_float8); }
static simd_float16 SIMD_CFUNC simd_float(simd_uint16   __x) { return __builtin_convertvector(__x,simd_float16); }
static simd_float2  SIMD_CFUNC simd_float(simd_float2   __x) { return __x; }
static simd_float3  SIMD_CFUNC simd_float(simd_float3   __x) { return __x; }
static simd_float4  SIMD_CFUNC simd_float(simd_float4   __x) { return __x; }
static simd_float8  SIMD_CFUNC simd_float(simd_float8   __x) { return __x; }
static simd_float16 SIMD_CFUNC simd_float(simd_float16  __x) { return __x; }
static simd_float2  SIMD_CFUNC simd_float(simd_long2    __x) { return __builtin_convertvector(__x,simd_float2); }
static simd_float3  SIMD_CFUNC simd_float(simd_long3    __x) { return __builtin_convertvector(__x,simd_float3); }
static simd_float4  SIMD_CFUNC simd_float(simd_long4    __x) { return __builtin_convertvector(__x,simd_float4); }
static simd_float8  SIMD_CFUNC simd_float(simd_long8    __x) { return __builtin_convertvector(__x,simd_float8); }
static simd_float2  SIMD_CFUNC simd_float(simd_ulong2   __x) { return __builtin_convertvector(__x,simd_float2); }
static simd_float3  SIMD_CFUNC simd_float(simd_ulong3   __x) { return __builtin_convertvector(__x,simd_float3); }
static simd_float4  SIMD_CFUNC simd_float(simd_ulong4   __x) { return __builtin_convertvector(__x,simd_float4); }
static simd_float8  SIMD_CFUNC simd_float(simd_ulong8   __x) { return __builtin_convertvector(__x,simd_float8); }
static simd_float2  SIMD_CFUNC simd_float(simd_double2  __x) { return __builtin_convertvector(__x,simd_float2); }
static simd_float3  SIMD_CFUNC simd_float(simd_double3  __x) { return __builtin_convertvector(__x,simd_float3); }
static simd_float4  SIMD_CFUNC simd_float(simd_double4  __x) { return __builtin_convertvector(__x,simd_float4); }
static simd_float8  SIMD_CFUNC simd_float(simd_double8  __x) { return __builtin_convertvector(__x,simd_float8); }
    

static simd_long2  SIMD_CFUNC simd_long(simd_char2    __x) { return __builtin_convertvector(__x,simd_long2); }
static simd_long3  SIMD_CFUNC simd_long(simd_char3    __x) { return __builtin_convertvector(__x,simd_long3); }
static simd_long4  SIMD_CFUNC simd_long(simd_char4    __x) { return __builtin_convertvector(__x,simd_long4); }
static simd_long8  SIMD_CFUNC simd_long(simd_char8    __x) { return __builtin_convertvector(__x,simd_long8); }
static simd_long2  SIMD_CFUNC simd_long(simd_uchar2   __x) { return __builtin_convertvector(__x,simd_long2); }
static simd_long3  SIMD_CFUNC simd_long(simd_uchar3   __x) { return __builtin_convertvector(__x,simd_long3); }
static simd_long4  SIMD_CFUNC simd_long(simd_uchar4   __x) { return __builtin_convertvector(__x,simd_long4); }
static simd_long8  SIMD_CFUNC simd_long(simd_uchar8   __x) { return __builtin_convertvector(__x,simd_long8); }
static simd_long2  SIMD_CFUNC simd_long(simd_short2   __x) { return __builtin_convertvector(__x,simd_long2); }
static simd_long3  SIMD_CFUNC simd_long(simd_short3   __x) { return __builtin_convertvector(__x,simd_long3); }
static simd_long4  SIMD_CFUNC simd_long(simd_short4   __x) { return __builtin_convertvector(__x,simd_long4); }
static simd_long8  SIMD_CFUNC simd_long(simd_short8   __x) { return __builtin_convertvector(__x,simd_long8); }
static simd_long2  SIMD_CFUNC simd_long(simd_ushort2  __x) { return __builtin_convertvector(__x,simd_long2); }
static simd_long3  SIMD_CFUNC simd_long(simd_ushort3  __x) { return __builtin_convertvector(__x,simd_long3); }
static simd_long4  SIMD_CFUNC simd_long(simd_ushort4  __x) { return __builtin_convertvector(__x,simd_long4); }
static simd_long8  SIMD_CFUNC simd_long(simd_ushort8  __x) { return __builtin_convertvector(__x,simd_long8); }
static simd_long2  SIMD_CFUNC simd_long(simd_int2     __x) { return __builtin_convertvector(__x,simd_long2); }
static simd_long3  SIMD_CFUNC simd_long(simd_int3     __x) { return __builtin_convertvector(__x,simd_long3); }
static simd_long4  SIMD_CFUNC simd_long(simd_int4     __x) { return __builtin_convertvector(__x,simd_long4); }
static simd_long8  SIMD_CFUNC simd_long(simd_int8     __x) { return __builtin_convertvector(__x,simd_long8); }
static simd_long2  SIMD_CFUNC simd_long(simd_uint2    __x) { return __builtin_convertvector(__x,simd_long2); }
static simd_long3  SIMD_CFUNC simd_long(simd_uint3    __x) { return __builtin_convertvector(__x,simd_long3); }
static simd_long4  SIMD_CFUNC simd_long(simd_uint4    __x) { return __builtin_convertvector(__x,simd_long4); }
static simd_long8  SIMD_CFUNC simd_long(simd_uint8    __x) { return __builtin_convertvector(__x,simd_long8); }
static simd_long2  SIMD_CFUNC simd_long(simd_float2   __x) { return __builtin_convertvector(__x,simd_long2); }
static simd_long3  SIMD_CFUNC simd_long(simd_float3   __x) { return __builtin_convertvector(__x,simd_long3); }
static simd_long4  SIMD_CFUNC simd_long(simd_float4   __x) { return __builtin_convertvector(__x,simd_long4); }
static simd_long8  SIMD_CFUNC simd_long(simd_float8   __x) { return __builtin_convertvector(__x,simd_long8); }
static simd_long2  SIMD_CFUNC simd_long(simd_long2    __x) { return __x; }
static simd_long3  SIMD_CFUNC simd_long(simd_long3    __x) { return __x; }
static simd_long4  SIMD_CFUNC simd_long(simd_long4    __x) { return __x; }
static simd_long8  SIMD_CFUNC simd_long(simd_long8    __x) { return __x; }
static simd_long2  SIMD_CFUNC simd_long(simd_ulong2   __x) { return (simd_long2)__x; }
static simd_long3  SIMD_CFUNC simd_long(simd_ulong3   __x) { return (simd_long3)__x; }
static simd_long4  SIMD_CFUNC simd_long(simd_ulong4   __x) { return (simd_long4)__x; }
static simd_long8  SIMD_CFUNC simd_long(simd_ulong8   __x) { return (simd_long8)__x; }
static simd_long2  SIMD_CFUNC simd_long(simd_double2  __x) { return __builtin_convertvector(__x,simd_long2); }
static simd_long3  SIMD_CFUNC simd_long(simd_double3  __x) { return __builtin_convertvector(__x,simd_long3); }
static simd_long4  SIMD_CFUNC simd_long(simd_double4  __x) { return __builtin_convertvector(__x,simd_long4); }
static simd_long8  SIMD_CFUNC simd_long(simd_double8  __x) { return __builtin_convertvector(__x,simd_long8); }
    
static simd_long2  SIMD_CFUNC simd_long_sat(simd_char2    __x) { return simd_long(__x); }
static simd_long3  SIMD_CFUNC simd_long_sat(simd_char3    __x) { return simd_long(__x); }
static simd_long4  SIMD_CFUNC simd_long_sat(simd_char4    __x) { return simd_long(__x); }
static simd_long8  SIMD_CFUNC simd_long_sat(simd_char8    __x) { return simd_long(__x); }
static simd_long2  SIMD_CFUNC simd_long_sat(simd_short2   __x) { return simd_long(__x); }
static simd_long3  SIMD_CFUNC simd_long_sat(simd_short3   __x) { return simd_long(__x); }
static simd_long4  SIMD_CFUNC simd_long_sat(simd_short4   __x) { return simd_long(__x); }
static simd_long8  SIMD_CFUNC simd_long_sat(simd_short8   __x) { return simd_long(__x); }
static simd_long2  SIMD_CFUNC simd_long_sat(simd_int2     __x) { return simd_long(__x); }
static simd_long3  SIMD_CFUNC simd_long_sat(simd_int3     __x) { return simd_long(__x); }
static simd_long4  SIMD_CFUNC simd_long_sat(simd_int4     __x) { return simd_long(__x); }
static simd_long8  SIMD_CFUNC simd_long_sat(simd_int8     __x) { return simd_long(__x); }
static simd_long2  SIMD_CFUNC simd_long_sat(simd_float2   __x) { return simd_bitselect(simd_long(simd_max(__x,-0x1.0p63f)), 0x7fffffffffffffff, simd_long(__x >= 0x1.0p63f)); }
static simd_long3  SIMD_CFUNC simd_long_sat(simd_float3   __x) { return simd_bitselect(simd_long(simd_max(__x,-0x1.0p63f)), 0x7fffffffffffffff, simd_long(__x >= 0x1.0p63f)); }
static simd_long4  SIMD_CFUNC simd_long_sat(simd_float4   __x) { return simd_bitselect(simd_long(simd_max(__x,-0x1.0p63f)), 0x7fffffffffffffff, simd_long(__x >= 0x1.0p63f)); }
static simd_long8  SIMD_CFUNC simd_long_sat(simd_float8   __x) { return simd_bitselect(simd_long(simd_max(__x,-0x1.0p63f)), 0x7fffffffffffffff, simd_long(__x >= 0x1.0p63f)); }
static simd_long2  SIMD_CFUNC simd_long_sat(simd_long2    __x) { return __x; }
static simd_long3  SIMD_CFUNC simd_long_sat(simd_long3    __x) { return __x; }
static simd_long4  SIMD_CFUNC simd_long_sat(simd_long4    __x) { return __x; }
static simd_long8  SIMD_CFUNC simd_long_sat(simd_long8    __x) { return __x; }
static simd_long2  SIMD_CFUNC simd_long_sat(simd_double2  __x) { return simd_bitselect(simd_long(simd_max(__x,-0x1.0p63)), 0x7fffffffffffffff, __x >= 0x1.0p63); }
static simd_long3  SIMD_CFUNC simd_long_sat(simd_double3  __x) { return simd_bitselect(simd_long(simd_max(__x,-0x1.0p63)), 0x7fffffffffffffff, __x >= 0x1.0p63); }
static simd_long4  SIMD_CFUNC simd_long_sat(simd_double4  __x) { return simd_bitselect(simd_long(simd_max(__x,-0x1.0p63)), 0x7fffffffffffffff, __x >= 0x1.0p63); }
static simd_long8  SIMD_CFUNC simd_long_sat(simd_double8  __x) { return simd_bitselect(simd_long(simd_max(__x,-0x1.0p63)), 0x7fffffffffffffff, __x >= 0x1.0p63); }
static simd_long2  SIMD_CFUNC simd_long_sat(simd_uchar2   __x) { return simd_long(__x); }
static simd_long3  SIMD_CFUNC simd_long_sat(simd_uchar3   __x) { return simd_long(__x); }
static simd_long4  SIMD_CFUNC simd_long_sat(simd_uchar4   __x) { return simd_long(__x); }
static simd_long8  SIMD_CFUNC simd_long_sat(simd_uchar8   __x) { return simd_long(__x); }
static simd_long2  SIMD_CFUNC simd_long_sat(simd_ushort2  __x) { return simd_long(__x); }
static simd_long3  SIMD_CFUNC simd_long_sat(simd_ushort3  __x) { return simd_long(__x); }
static simd_long4  SIMD_CFUNC simd_long_sat(simd_ushort4  __x) { return simd_long(__x); }
static simd_long8  SIMD_CFUNC simd_long_sat(simd_ushort8  __x) { return simd_long(__x); }
static simd_long2  SIMD_CFUNC simd_long_sat(simd_uint2    __x) { return simd_long(__x); }
static simd_long3  SIMD_CFUNC simd_long_sat(simd_uint3    __x) { return simd_long(__x); }
static simd_long4  SIMD_CFUNC simd_long_sat(simd_uint4    __x) { return simd_long(__x); }
static simd_long8  SIMD_CFUNC simd_long_sat(simd_uint8    __x) { return simd_long(__x); }
static simd_long2  SIMD_CFUNC simd_long_sat(simd_ulong2   __x) { return simd_long(simd_min(__x,0x7fffffffffffffff)); }
static simd_long3  SIMD_CFUNC simd_long_sat(simd_ulong3   __x) { return simd_long(simd_min(__x,0x7fffffffffffffff)); }
static simd_long4  SIMD_CFUNC simd_long_sat(simd_ulong4   __x) { return simd_long(simd_min(__x,0x7fffffffffffffff)); }
static simd_long8  SIMD_CFUNC simd_long_sat(simd_ulong8   __x) { return simd_long(simd_min(__x,0x7fffffffffffffff)); }
    
static simd_long2  SIMD_CFUNC simd_long_rte(simd_double2  __x) {
#if defined __AVX512F__
  return _mm_cvtpd_epi64(__x);
#elif defined __arm64__
  return vcvtnq_s64_f64(__x);
#else
  simd_double2 magic = __tg_copysign(0x1.0p52, __x);
  simd_long2 x_is_small = __tg_fabs(__x) < 0x1.0p52;
  return __builtin_convertvector(simd_bitselect(__x, (__x + magic) - magic, x_is_small & 0x7fffffffffffffff), simd_long2);
#endif
}

static simd_long3  SIMD_CFUNC simd_long_rte(simd_double3  __x) {
  return simd_make_long3(simd_long_rte(simd_make_double4_undef(__x)));
}

static simd_long4  SIMD_CFUNC simd_long_rte(simd_double4  __x) {
#if defined __AVX512F__
  return _mm256_cvtpd_epi64(__x);
#else
  return simd_make_long4(simd_long_rte(__x.lo), simd_long_rte(__x.hi));
#endif
}

static simd_long8  SIMD_CFUNC simd_long_rte(simd_double8  __x) {
#if defined __AVX512F__
  return _mm512_cvt_roundpd_epi64(__x, _MM_FROUND_RINT);
#else
  return simd_make_long8(simd_long_rte(__x.lo), simd_long_rte(__x.hi));
#endif
}


static simd_ulong2  SIMD_CFUNC simd_ulong(simd_char2    __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_char3    __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_char4    __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_char8    __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_uchar2   __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_uchar3   __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_uchar4   __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_uchar8   __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_short2   __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_short3   __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_short4   __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_short8   __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_ushort2  __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_ushort3  __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_ushort4  __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_ushort8  __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_int2     __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_int3     __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_int4     __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_int8     __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_uint2    __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_uint3    __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_uint4    __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_uint8    __x) { return simd_ulong(simd_long(__x)); }
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_float2   __x) { simd_int2 __big = __x >= 0x1.0p63f; return simd_ulong(simd_long(__x - simd_bitselect((simd_float2)0,0x1.0p63f,__big))) + simd_bitselect((simd_ulong2)0,0x8000000000000000,simd_long(__big)); }
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_float3   __x) { simd_int3 __big = __x >= 0x1.0p63f; return simd_ulong(simd_long(__x - simd_bitselect((simd_float3)0,0x1.0p63f,__big))) + simd_bitselect((simd_ulong3)0,0x8000000000000000,simd_long(__big)); }
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_float4   __x) { simd_int4 __big = __x >= 0x1.0p63f; return simd_ulong(simd_long(__x - simd_bitselect((simd_float4)0,0x1.0p63f,__big))) + simd_bitselect((simd_ulong4)0,0x8000000000000000,simd_long(__big)); }
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_float8   __x) { simd_int8 __big = __x >= 0x1.0p63f; return simd_ulong(simd_long(__x - simd_bitselect((simd_float8)0,0x1.0p63f,__big))) + simd_bitselect((simd_ulong8)0,0x8000000000000000,simd_long(__big)); }
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_long2    __x) { return (simd_ulong2)__x; }
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_long3    __x) { return (simd_ulong3)__x; }
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_long4    __x) { return (simd_ulong4)__x; }
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_long8    __x) { return (simd_ulong8)__x; }
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_ulong2   __x) { return __x; }
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_ulong3   __x) { return __x; }
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_ulong4   __x) { return __x; }
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_ulong8   __x) { return __x; }
static simd_ulong2  SIMD_CFUNC simd_ulong(simd_double2  __x) { simd_long2 __big = __x >= 0x1.0p63; return simd_ulong(simd_long(__x - simd_bitselect((simd_double2)0,0x1.0p63,__big))) + simd_bitselect((simd_ulong2)0,0x8000000000000000,__big); }
static simd_ulong3  SIMD_CFUNC simd_ulong(simd_double3  __x) { simd_long3 __big = __x >= 0x1.0p63; return simd_ulong(simd_long(__x - simd_bitselect((simd_double3)0,0x1.0p63,__big))) + simd_bitselect((simd_ulong3)0,0x8000000000000000,__big); }
static simd_ulong4  SIMD_CFUNC simd_ulong(simd_double4  __x) { simd_long4 __big = __x >= 0x1.0p63; return simd_ulong(simd_long(__x - simd_bitselect((simd_double4)0,0x1.0p63,__big))) + simd_bitselect((simd_ulong4)0,0x8000000000000000,__big); }
static simd_ulong8  SIMD_CFUNC simd_ulong(simd_double8  __x) { simd_long8 __big = __x >= 0x1.0p63; return simd_ulong(simd_long(__x - simd_bitselect((simd_double8)0,0x1.0p63,__big))) + simd_bitselect((simd_ulong8)0,0x8000000000000000,__big); }
    
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_char2    __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_char3    __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_char4    __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_char8    __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_short2   __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_short3   __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_short4   __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_short8   __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_int2     __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_int3     __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_int4     __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_int8     __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_float2   __x) { return simd_bitselect(simd_ulong(simd_max(__x,0.f)), 0xffffffffffffffff, simd_long(__x >= 0x1.0p64f)); }
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_float3   __x) { return simd_bitselect(simd_ulong(simd_max(__x,0.f)), 0xffffffffffffffff, simd_long(__x >= 0x1.0p64f)); }
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_float4   __x) { return simd_bitselect(simd_ulong(simd_max(__x,0.f)), 0xffffffffffffffff, simd_long(__x >= 0x1.0p64f)); }
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_float8   __x) { return simd_bitselect(simd_ulong(simd_max(__x,0.f)), 0xffffffffffffffff, simd_long(__x >= 0x1.0p64f)); }
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_long2    __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_long3    __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_long4    __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_long8    __x) { return simd_ulong(simd_max(__x,0)); }
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_double2  __x) { return simd_bitselect(simd_ulong(simd_max(__x,0.0)), 0xffffffffffffffff, __x >= 0x1.0p64); }
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_double3  __x) { return simd_bitselect(simd_ulong(simd_max(__x,0.0)), 0xffffffffffffffff, __x >= 0x1.0p64); }
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_double4  __x) { return simd_bitselect(simd_ulong(simd_max(__x,0.0)), 0xffffffffffffffff, __x >= 0x1.0p64); }
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_double8  __x) { return simd_bitselect(simd_ulong(simd_max(__x,0.0)), 0xffffffffffffffff, __x >= 0x1.0p64); }
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_uchar2   __x) { return simd_ulong(__x); }
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_uchar3   __x) { return simd_ulong(__x); }
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_uchar4   __x) { return simd_ulong(__x); }
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_uchar8   __x) { return simd_ulong(__x); }
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_ushort2  __x) { return simd_ulong(__x); }
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_ushort3  __x) { return simd_ulong(__x); }
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_ushort4  __x) { return simd_ulong(__x); }
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_ushort8  __x) { return simd_ulong(__x); }
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_uint2    __x) { return simd_ulong(__x); }
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_uint3    __x) { return simd_ulong(__x); }
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_uint4    __x) { return simd_ulong(__x); }
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_uint8    __x) { return simd_ulong(__x); }
static simd_ulong2  SIMD_CFUNC simd_ulong_sat(simd_ulong2   __x) { return __x; }
static simd_ulong3  SIMD_CFUNC simd_ulong_sat(simd_ulong3   __x) { return __x; }
static simd_ulong4  SIMD_CFUNC simd_ulong_sat(simd_ulong4   __x) { return __x; }
static simd_ulong8  SIMD_CFUNC simd_ulong_sat(simd_ulong8   __x) { return __x; }
    

static simd_double2  SIMD_CFUNC simd_double(simd_char2    __x) { return simd_double(simd_int(__x)); }
static simd_double3  SIMD_CFUNC simd_double(simd_char3    __x) { return simd_double(simd_int(__x)); }
static simd_double4  SIMD_CFUNC simd_double(simd_char4    __x) { return simd_double(simd_int(__x)); }
static simd_double8  SIMD_CFUNC simd_double(simd_char8    __x) { return simd_double(simd_int(__x)); }
static simd_double2  SIMD_CFUNC simd_double(simd_uchar2   __x) { return simd_double(simd_int(__x)); }
static simd_double3  SIMD_CFUNC simd_double(simd_uchar3   __x) { return simd_double(simd_int(__x)); }
static simd_double4  SIMD_CFUNC simd_double(simd_uchar4   __x) { return simd_double(simd_int(__x)); }
static simd_double8  SIMD_CFUNC simd_double(simd_uchar8   __x) { return simd_double(simd_int(__x)); }
static simd_double2  SIMD_CFUNC simd_double(simd_short2   __x) { return simd_double(simd_int(__x)); }
static simd_double3  SIMD_CFUNC simd_double(simd_short3   __x) { return simd_double(simd_int(__x)); }
static simd_double4  SIMD_CFUNC simd_double(simd_short4   __x) { return simd_double(simd_int(__x)); }
static simd_double8  SIMD_CFUNC simd_double(simd_short8   __x) { return simd_double(simd_int(__x)); }
static simd_double2  SIMD_CFUNC simd_double(simd_ushort2  __x) { return simd_double(simd_int(__x)); }
static simd_double3  SIMD_CFUNC simd_double(simd_ushort3  __x) { return simd_double(simd_int(__x)); }
static simd_double4  SIMD_CFUNC simd_double(simd_ushort4  __x) { return simd_double(simd_int(__x)); }
static simd_double8  SIMD_CFUNC simd_double(simd_ushort8  __x) { return simd_double(simd_int(__x)); }
static simd_double2  SIMD_CFUNC simd_double(simd_int2     __x) { return __builtin_convertvector(__x, simd_double2); }
static simd_double3  SIMD_CFUNC simd_double(simd_int3     __x) { return __builtin_convertvector(__x, simd_double3); }
static simd_double4  SIMD_CFUNC simd_double(simd_int4     __x) { return __builtin_convertvector(__x, simd_double4); }
static simd_double8  SIMD_CFUNC simd_double(simd_int8     __x) { return __builtin_convertvector(__x, simd_double8); }
static simd_double2  SIMD_CFUNC simd_double(simd_uint2    __x) { return __builtin_convertvector(__x, simd_double2); }
static simd_double3  SIMD_CFUNC simd_double(simd_uint3    __x) { return __builtin_convertvector(__x, simd_double3); }
static simd_double4  SIMD_CFUNC simd_double(simd_uint4    __x) { return __builtin_convertvector(__x, simd_double4); }
static simd_double8  SIMD_CFUNC simd_double(simd_uint8    __x) { return __builtin_convertvector(__x, simd_double8); }
static simd_double2  SIMD_CFUNC simd_double(simd_float2   __x) { return __builtin_convertvector(__x, simd_double2); }
static simd_double3  SIMD_CFUNC simd_double(simd_float3   __x) { return __builtin_convertvector(__x, simd_double3); }
static simd_double4  SIMD_CFUNC simd_double(simd_float4   __x) { return __builtin_convertvector(__x, simd_double4); }
static simd_double8  SIMD_CFUNC simd_double(simd_float8   __x) { return __builtin_convertvector(__x, simd_double8); }
static simd_double2  SIMD_CFUNC simd_double(simd_long2    __x) { return __builtin_convertvector(__x, simd_double2); }
static simd_double3  SIMD_CFUNC simd_double(simd_long3    __x) { return __builtin_convertvector(__x, simd_double3); }
static simd_double4  SIMD_CFUNC simd_double(simd_long4    __x) { return __builtin_convertvector(__x, simd_double4); }
static simd_double8  SIMD_CFUNC simd_double(simd_long8    __x) { return __builtin_convertvector(__x, simd_double8); }
static simd_double2  SIMD_CFUNC simd_double(simd_ulong2   __x) { return __builtin_convertvector(__x, simd_double2); }
static simd_double3  SIMD_CFUNC simd_double(simd_ulong3   __x) { return __builtin_convertvector(__x, simd_double3); }
static simd_double4  SIMD_CFUNC simd_double(simd_ulong4   __x) { return __builtin_convertvector(__x, simd_double4); }
static simd_double8  SIMD_CFUNC simd_double(simd_ulong8   __x) { return __builtin_convertvector(__x, simd_double8); }
static simd_double2  SIMD_CFUNC simd_double(simd_double2  __x) { return __builtin_convertvector(__x, simd_double2); }
static simd_double3  SIMD_CFUNC simd_double(simd_double3  __x) { return __builtin_convertvector(__x, simd_double3); }
static simd_double4  SIMD_CFUNC simd_double(simd_double4  __x) { return __builtin_convertvector(__x, simd_double4); }
static simd_double8  SIMD_CFUNC simd_double(simd_double8  __x) { return __builtin_convertvector(__x, simd_double8); }
    

#ifdef __cplusplus
} // extern "C"

namespace simd {

#if __has_feature(cxx_constexpr)
/*! @abstract Convert a vector to another vector of the ScalarType and the same number of elements. */
template<typename ScalarType, typename typeN>
static constexpr Vector_t<ScalarType, traits<typeN>::count> convert(typeN vector)
{
    if constexpr (traits<typeN>::count == 1)
        return static_cast<Vector_t<ScalarType, traits<typeN>::count>>(vector);
    else if constexpr (std::is_same<ScalarType, char1>::value)
        return simd_char(vector);
    else if constexpr (std::is_same<ScalarType, uchar1>::value)
        return simd_uchar(vector);
    else if constexpr (std::is_same<ScalarType, short1>::value)
        return simd_short(vector);
    else if constexpr (std::is_same<ScalarType, ushort1>::value)
        return simd_ushort(vector);
    else if constexpr (std::is_same<ScalarType, int1>::value)
        return simd_int(vector);
    else if constexpr (std::is_same<ScalarType, uint1>::value)
        return simd_uint(vector);
    else if constexpr (std::is_same<ScalarType, long1>::value)
        return simd_long(vector);
    else if constexpr (std::is_same<ScalarType, ulong1>::value)
        return simd_ulong(vector);
    else if constexpr (std::is_same<ScalarType, float1>::value)
        return simd_float(vector);
    else if constexpr (std::is_same<ScalarType, double1>::value)
        return simd_double(vector);
}

/*! @abstract Convert a vector to another vector of the ScalarType and the same number of elements with saturation.
 *  @discussion When the input value is too large to be represented in the return type, the input value
 *  will be saturated to the maximum value of the return type.  */
template<typename ScalarType, typename typeN>
static constexpr Vector_t<ScalarType, traits<typeN>::count> convert_sat(typeN vector)
{
    static_assert(traits<typeN>::count != 1);
    if constexpr (std::is_same<ScalarType, char1>::value)
        return simd_char_sat(vector);
    else if constexpr (std::is_same<ScalarType, uchar1>::value)
        return simd_uchar_sat(vector);
    else if constexpr (std::is_same<ScalarType, short1>::value)
        return simd_short_sat(vector);
    else if constexpr (std::is_same<ScalarType, ushort1>::value)
        return simd_ushort_sat(vector);
    else if constexpr (std::is_same<ScalarType, int1>::value)
        return simd_int_sat(vector);
    else if constexpr (std::is_same<ScalarType, uint1>::value)
        return simd_uint_sat(vector);
    else if constexpr (std::is_same<ScalarType, long1>::value)
        return simd_long_sat(vector);
    else if constexpr (std::is_same<ScalarType, ulong1>::value)
        return simd_ulong_sat(vector);
    else
        return convert<ScalarType, typeN>(vector);
}
#endif /* __has_feature(cxx_constexpr) */

} /* namespace simd */
#endif // __cplusplus
#endif // SIMD_COMPILER_HAS_REQUIRED_FEATURES
#endif // __SIMD_CONVERSION_HEADER__