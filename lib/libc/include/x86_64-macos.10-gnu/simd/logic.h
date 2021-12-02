/*! @header
 *  The interfaces declared in this header provide logical and bitwise
 *  operations on vectors.  Some of these function operate elementwise,
 *  and some produce a scalar result that depends on all lanes of the input.
 *
 *  For functions returning a boolean value, the return type in C and
 *  Objective-C is _Bool; for C++ it is bool.
 *
 *      Function                    Result
 *      ------------------------------------------------------------------
 *      simd_all(comparison)        True if and only if the comparison is true
 *                                  in every vector lane.  e.g.:
 *
 *                                      if (simd_all(x == 0.0f)) {
 *                                          // executed if every lane of x
 *                                          // contains zero.
 *                                      }
 *
 *                                  The precise function of simd_all is to
 *                                  return the high-order bit of the result
 *                                  of a horizontal bitwise AND of all vector
 *                                  lanes.
 *
 *      simd_any(comparison)        True if and only if the comparison is true
 *                                  in at least one vector lane.  e.g.:
 *
 *                                      if (simd_any(x < 0.0f)) {
 *                                          // executed if any lane of x
 *                                          // contains a negative value.
 *                                      }
 *
 *                                  The precise function of simd_all is to
 *                                  return the high-order bit of the result
 *                                  of a horizontal bitwise OR of all vector
 *                                  lanes.
 *
 *      simd_select(x,y,mask)       For each lane in the result, selects the
 *                                  corresponding element of x if the high-
 *                                  order bit of the corresponding element of
 *                                  mask is 0, and the corresponding element
 *                                  of y otherwise.
 *
 *      simd_bitselect(x,y,mask)    For each bit in the result, selects the
 *                                  corresponding bit of x if the corresponding
 *                                  bit of mask is clear, and the corresponding
 *                                  of y otherwise.
 *
 *  In C++, these functions are available under the simd:: namespace:
 *
 *      C++ Function                    Equivalent C Function
 *      --------------------------------------------------------------------
 *      simd::all(comparison)           simd_all(comparison)
 *      simd::any(comparison)           simd_any(comparison)
 *      simd::select(x,y,mask)          simd_select(x,y,mask)
 *      simd::bitselect(x,y,mask)       simd_bitselect(x,y,mask)
 *
 *  @copyright 2014-2017 Apple, Inc. All rights reserved.
 *  @unsorted                                                                 */

#ifndef SIMD_LOGIC_HEADER
#define SIMD_LOGIC_HEADER

#include <simd/base.h>
#if SIMD_COMPILER_HAS_REQUIRED_FEATURES
#include <simd/vector_make.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_char2 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_char3 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_char4 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_char8 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_char16 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_char32 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_char64 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar2 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar3 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar4 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar8 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar16 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar32 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar64 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_short2 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_short3 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_short4 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_short8 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_short16 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_short32 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort2 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort3 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort4 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort8 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort16 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort32 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_int2 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_int3 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_int4 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_int8 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_int16 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uint2 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uint3 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uint4 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uint8 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_uint16 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_long2 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_long3 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_long4 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_long8 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_ulong2 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_ulong3 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_ulong4 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_any(simd_ulong8 x);
/*! @abstract True if and only if the high-order bit of any lane of the
 *  vector is set.
 *  @discussion Deprecated. Use simd_any instead.                             */
#define vector_any simd_any

/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_char2 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_char3 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_char4 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_char8 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_char16 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_char32 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_char64 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar2 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar3 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar4 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar8 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar16 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar32 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar64 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_short2 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_short3 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_short4 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_short8 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_short16 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_short32 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort2 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort3 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort4 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort8 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort16 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort32 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_int2 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_int3 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_int4 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_int8 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_int16 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uint2 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uint3 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uint4 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uint8 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_uint16 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_long2 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_long3 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_long4 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_long8 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_ulong2 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_ulong3 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_ulong4 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.                                                            */
static inline SIMD_CFUNC simd_bool simd_all(simd_ulong8 x);
/*! @abstract True if and only if the high-order bit of every lane of the
 *  vector is set.
 *  @discussion Deprecated. Use simd_all instead.                             */
#define vector_all simd_all

/*! @abstract For each lane in the result, selects the corresponding element
 *  of x or y according to whether the high-order bit of the corresponding
 *  lane of mask is 0 or 1, respectively.                                     */
static inline SIMD_CFUNC simd_float2 simd_select(simd_float2 x, simd_float2 y, simd_int2 mask);
/*! @abstract For each lane in the result, selects the corresponding element
 *  of x or y according to whether the high-order bit of the corresponding
 *  lane of mask is 0 or 1, respectively.                                     */
static inline SIMD_CFUNC simd_float3 simd_select(simd_float3 x, simd_float3 y, simd_int3 mask);
/*! @abstract For each lane in the result, selects the corresponding element
 *  of x or y according to whether the high-order bit of the corresponding
 *  lane of mask is 0 or 1, respectively.                                     */
static inline SIMD_CFUNC simd_float4 simd_select(simd_float4 x, simd_float4 y, simd_int4 mask);
/*! @abstract For each lane in the result, selects the corresponding element
 *  of x or y according to whether the high-order bit of the corresponding
 *  lane of mask is 0 or 1, respectively.                                     */
static inline SIMD_CFUNC simd_float8 simd_select(simd_float8 x, simd_float8 y, simd_int8 mask);
/*! @abstract For each lane in the result, selects the corresponding element
 *  of x or y according to whether the high-order bit of the corresponding
 *  lane of mask is 0 or 1, respectively.                                     */
static inline SIMD_CFUNC simd_float16 simd_select(simd_float16 x, simd_float16 y, simd_int16 mask);
/*! @abstract For each lane in the result, selects the corresponding element
 *  of x or y according to whether the high-order bit of the corresponding
 *  lane of mask is 0 or 1, respectively.                                     */
static inline SIMD_CFUNC simd_double2 simd_select(simd_double2 x, simd_double2 y, simd_long2 mask);
/*! @abstract For each lane in the result, selects the corresponding element
 *  of x or y according to whether the high-order bit of the corresponding
 *  lane of mask is 0 or 1, respectively.                                     */
static inline SIMD_CFUNC simd_double3 simd_select(simd_double3 x, simd_double3 y, simd_long3 mask);
/*! @abstract For each lane in the result, selects the corresponding element
 *  of x or y according to whether the high-order bit of the corresponding
 *  lane of mask is 0 or 1, respectively.                                     */
static inline SIMD_CFUNC simd_double4 simd_select(simd_double4 x, simd_double4 y, simd_long4 mask);
/*! @abstract For each lane in the result, selects the corresponding element
 *  of x or y according to whether the high-order bit of the corresponding
 *  lane of mask is 0 or 1, respectively.                                     */
static inline SIMD_CFUNC simd_double8 simd_select(simd_double8 x, simd_double8 y, simd_long8 mask);
/*! @abstract For each lane in the result, selects the corresponding element
 *  of x or y according to whether the high-order bit of the corresponding
 *  lane of mask is 0 or 1, respectively.
 *  @discussion Deprecated. Use simd_select instead.                          */
#define vector_select simd_select
  
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_char2 simd_bitselect(simd_char2 x, simd_char2 y, simd_char2 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_char3 simd_bitselect(simd_char3 x, simd_char3 y, simd_char3 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_char4 simd_bitselect(simd_char4 x, simd_char4 y, simd_char4 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_char8 simd_bitselect(simd_char8 x, simd_char8 y, simd_char8 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_char16 simd_bitselect(simd_char16 x, simd_char16 y, simd_char16 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_char32 simd_bitselect(simd_char32 x, simd_char32 y, simd_char32 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_char64 simd_bitselect(simd_char64 x, simd_char64 y, simd_char64 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uchar2 simd_bitselect(simd_uchar2 x, simd_uchar2 y, simd_char2 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uchar3 simd_bitselect(simd_uchar3 x, simd_uchar3 y, simd_char3 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uchar4 simd_bitselect(simd_uchar4 x, simd_uchar4 y, simd_char4 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uchar8 simd_bitselect(simd_uchar8 x, simd_uchar8 y, simd_char8 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uchar16 simd_bitselect(simd_uchar16 x, simd_uchar16 y, simd_char16 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uchar32 simd_bitselect(simd_uchar32 x, simd_uchar32 y, simd_char32 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uchar64 simd_bitselect(simd_uchar64 x, simd_uchar64 y, simd_char64 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_short2 simd_bitselect(simd_short2 x, simd_short2 y, simd_short2 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_short3 simd_bitselect(simd_short3 x, simd_short3 y, simd_short3 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_short4 simd_bitselect(simd_short4 x, simd_short4 y, simd_short4 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_short8 simd_bitselect(simd_short8 x, simd_short8 y, simd_short8 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_short16 simd_bitselect(simd_short16 x, simd_short16 y, simd_short16 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_short32 simd_bitselect(simd_short32 x, simd_short32 y, simd_short32 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_ushort2 simd_bitselect(simd_ushort2 x, simd_ushort2 y, simd_short2 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_ushort3 simd_bitselect(simd_ushort3 x, simd_ushort3 y, simd_short3 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_ushort4 simd_bitselect(simd_ushort4 x, simd_ushort4 y, simd_short4 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_ushort8 simd_bitselect(simd_ushort8 x, simd_ushort8 y, simd_short8 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_ushort16 simd_bitselect(simd_ushort16 x, simd_ushort16 y, simd_short16 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_ushort32 simd_bitselect(simd_ushort32 x, simd_ushort32 y, simd_short32 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_int2 simd_bitselect(simd_int2 x, simd_int2 y, simd_int2 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_int3 simd_bitselect(simd_int3 x, simd_int3 y, simd_int3 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_int4 simd_bitselect(simd_int4 x, simd_int4 y, simd_int4 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_int8 simd_bitselect(simd_int8 x, simd_int8 y, simd_int8 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_int16 simd_bitselect(simd_int16 x, simd_int16 y, simd_int16 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uint2 simd_bitselect(simd_uint2 x, simd_uint2 y, simd_int2 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uint3 simd_bitselect(simd_uint3 x, simd_uint3 y, simd_int3 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uint4 simd_bitselect(simd_uint4 x, simd_uint4 y, simd_int4 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uint8 simd_bitselect(simd_uint8 x, simd_uint8 y, simd_int8 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_uint16 simd_bitselect(simd_uint16 x, simd_uint16 y, simd_int16 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_float2 simd_bitselect(simd_float2 x, simd_float2 y, simd_int2 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_float3 simd_bitselect(simd_float3 x, simd_float3 y, simd_int3 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_float4 simd_bitselect(simd_float4 x, simd_float4 y, simd_int4 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_float8 simd_bitselect(simd_float8 x, simd_float8 y, simd_int8 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_float16 simd_bitselect(simd_float16 x, simd_float16 y, simd_int16 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_long2 simd_bitselect(simd_long2 x, simd_long2 y, simd_long2 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_long3 simd_bitselect(simd_long3 x, simd_long3 y, simd_long3 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_long4 simd_bitselect(simd_long4 x, simd_long4 y, simd_long4 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_long8 simd_bitselect(simd_long8 x, simd_long8 y, simd_long8 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_ulong2 simd_bitselect(simd_ulong2 x, simd_ulong2 y, simd_long2 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_ulong3 simd_bitselect(simd_ulong3 x, simd_ulong3 y, simd_long3 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_ulong4 simd_bitselect(simd_ulong4 x, simd_ulong4 y, simd_long4 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_ulong8 simd_bitselect(simd_ulong8 x, simd_ulong8 y, simd_long8 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_double2 simd_bitselect(simd_double2 x, simd_double2 y, simd_long2 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_double3 simd_bitselect(simd_double3 x, simd_double3 y, simd_long3 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_double4 simd_bitselect(simd_double4 x, simd_double4 y, simd_long4 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.                                                             */
static inline SIMD_CFUNC simd_double8 simd_bitselect(simd_double8 x, simd_double8 y, simd_long8 mask);
/*! @abstract For each bit in the result, selects the corresponding bit of x
 *  or y according to whether the corresponding bit of mask is 0 or 1,
 *  respectively.
 *  @discussion Deprecated. Use simd_bitselect instead.                       */
#define vector_bitselect simd_bitselect

#ifdef __cplusplus
} /* extern "C" */

namespace simd {
  /*! @abstract True if and only if the high-order bit of every lane is set.  */
  template <typename inttypeN> static SIMD_CPPFUNC simd_bool all(const inttypeN predicate) { return ::simd_all(predicate); }
  /*! @abstract True if and only if the high-order bit of any lane is set.    */
  template <typename inttypeN> static SIMD_CPPFUNC simd_bool any(const inttypeN predicate) { return ::simd_any(predicate); }
  /*! @abstract Each lane of the result is selected from the corresponding lane
   *  of x or y according to whether the high-order bit of the corresponding
   *  lane of mask is 0 or 1, respectively.                                   */
  template <typename inttypeN, typename fptypeN> static SIMD_CPPFUNC fptypeN select(const fptypeN x, const fptypeN y, const inttypeN predicate) { return ::simd_select(x,y,predicate); }
  /*! @abstract For each bit in the result, selects the corresponding bit of x
   *  or y according to whether the corresponding bit of mask is 0 or 1,
   *  respectively.                                                           */
  template <typename inttypeN, typename typeN> static SIMD_CPPFUNC typeN bitselect(const typeN x, const typeN y, const inttypeN mask) { return ::simd_bitselect(x,y,mask); }
}

extern "C" {
#endif /* __cplusplus */

#pragma mark - Implementations

static inline SIMD_CFUNC simd_bool simd_any(simd_char2 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_char16_undef(x)) & 0x3);
#elif defined __arm64__
  return simd_any(x.xyxy);
#else
  union { uint16_t i; simd_char2 v; } u = { .v = x };
  return (u.i & 0x8080);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_char3 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_char16_undef(x)) & 0x7);
#elif defined __arm64__
  return simd_any(x.xyzz);
#else
  union { uint32_t i; simd_char3 v; } u = { .v = x };
  return (u.i & 0x808080);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_char4 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_char16_undef(x)) & 0xf);
#elif defined __arm64__
  return simd_any(x.xyzwxyzw);
#else
  union { uint32_t i; simd_char4 v; } u = { .v = x };
  return (u.i & 0x80808080);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_char8 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_char16_undef(x)) & 0xff);
#elif defined __arm64__
  return vmaxv_u8(x) & 0x80;
#else
  union { uint64_t i; simd_char8 v; } u = { .v = x };
  return (u.i & 0x8080808080808080);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_char16 x) {
#if defined __SSE2__
  return _mm_movemask_epi8(x);
#elif defined __arm64__
  return vmaxvq_u8(x) & 0x80;
#else
  return simd_any(x.lo | x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_char32 x) {
#if defined __AVX2__
  return _mm256_movemask_epi8(x);
#else
  return simd_any(x.lo | x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_char64 x) {
  return simd_any(x.lo | x.hi);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar2 x) {
  return simd_any((simd_char2)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar3 x) {
  return simd_any((simd_char3)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar4 x) {
  return simd_any((simd_char4)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar8 x) {
  return simd_any((simd_char8)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar16 x) {
  return simd_any((simd_char16)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar32 x) {
  return simd_any((simd_char32)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uchar64 x) {
  return simd_any((simd_char64)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_short2 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_short8_undef(x)) & 0xa);
#elif defined __arm64__
  return simd_any(x.xyxy);
#else
  union { uint32_t i; simd_short2 v; } u = { .v = x };
  return (u.i & 0x80008000);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_short3 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_short8_undef(x)) & 0x2a);
#elif defined __arm64__
  return simd_any(x.xyzz);
#else
  union { uint64_t i; simd_short3 v; } u = { .v = x };
  return (u.i & 0x800080008000);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_short4 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_short8_undef(x)) & 0xaa);
#elif defined __arm64__
  return vmaxv_u16(x) & 0x8000;
#else
  union { uint64_t i; simd_short4 v; } u = { .v = x };
  return (u.i & 0x8000800080008000);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_short8 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(x) & 0xaaaa);
#elif defined __arm64__
  return vmaxvq_u16(x) & 0x8000;
#else
  return simd_any(x.lo | x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_short16 x) {
#if defined __AVX2__
  return (_mm256_movemask_epi8(x) & 0xaaaaaaaa);
#else
  return simd_any(x.lo | x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_short32 x) {
  return simd_any(x.lo | x.hi);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort2 x) {
  return simd_any((simd_short2)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort3 x) {
  return simd_any((simd_short3)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort4 x) {
  return simd_any((simd_short4)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort8 x) {
  return simd_any((simd_short8)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort16 x) {
  return simd_any((simd_short16)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_ushort32 x) {
  return simd_any((simd_short32)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_int2 x) {
#if defined __SSE2__
  return (_mm_movemask_ps(simd_make_int4_undef(x)) & 0x3);
#elif defined __arm64__
  return vmaxv_u32(x) & 0x80000000;
#else
  union { uint64_t i; simd_int2 v; } u = { .v = x };
  return (u.i & 0x8000000080000000);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_int3 x) {
#if defined __SSE2__
  return (_mm_movemask_ps(simd_make_int4_undef(x)) & 0x7);
#elif defined __arm64__
  return simd_any(x.xyzz);
#else
  return (x.x | x.y | x.z) & 0x80000000;
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_int4 x) {
#if defined __SSE2__
  return _mm_movemask_ps(x);
#elif defined __arm64__
  return vmaxvq_u32(x) & 0x80000000;
#else
  return simd_any(x.lo | x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_int8 x) {
#if defined __AVX__
  return _mm256_movemask_ps(x);
#else
  return simd_any(x.lo | x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_int16 x) {
  return simd_any(x.lo | x.hi);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uint2 x) {
  return simd_any((simd_int2)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uint3 x) {
  return simd_any((simd_int3)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uint4 x) {
  return simd_any((simd_int4)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uint8 x) {
  return simd_any((simd_int8)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_uint16 x) {
  return simd_any((simd_int16)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_long2 x) {
#if defined __SSE2__
  return _mm_movemask_pd(x);
#elif defined __arm64__
  return (x.x | x.y) & 0x8000000000000000U;
#else
  return (x.x | x.y) & 0x8000000000000000U;
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_long3 x) {
#if defined __AVX__
  return (_mm256_movemask_pd(simd_make_long4_undef(x)) & 0x7);
#else
  return (x.x | x.y | x.z) & 0x8000000000000000U;
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_long4 x) {
#if defined __AVX__
  return _mm256_movemask_pd(x);
#else
  return simd_any(x.lo | x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_any(simd_long8 x) {
  return simd_any(x.lo | x.hi);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_ulong2 x) {
  return simd_any((simd_long2)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_ulong3 x) {
  return simd_any((simd_long3)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_ulong4 x) {
  return simd_any((simd_long4)x);
}
static inline SIMD_CFUNC simd_bool simd_any(simd_ulong8 x) {
  return simd_any((simd_long8)x);
}
  
static inline SIMD_CFUNC simd_bool simd_all(simd_char2 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_char16_undef(x)) & 0x3) == 0x3;
#elif defined __arm64__
  return simd_all(x.xyxy);
#else
  union { uint16_t i; simd_char2 v; } u = { .v = x };
  return (u.i & 0x8080) == 0x8080;
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_char3 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_char16_undef(x)) & 0x7) == 0x7;
#elif defined __arm64__
  return simd_all(x.xyzz);
#else
  union { uint32_t i; simd_char3 v; } u = { .v = x };
  return (u.i & 0x808080) == 0x808080;
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_char4 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_char16_undef(x)) & 0xf) == 0xf;
#elif defined __arm64__
  return simd_all(x.xyzwxyzw);
#else
  union { uint32_t i; simd_char4 v; } u = { .v = x };
  return (u.i & 0x80808080) == 0x80808080;
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_char8 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_char16_undef(x)) & 0xff) == 0xff;
#elif defined __arm64__
  return vminv_u8(x) & 0x80;
#else
  union { uint64_t i; simd_char8 v; } u = { .v = x };
  return (u.i & 0x8080808080808080) == 0x8080808080808080;
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_char16 x) {
#if defined __SSE2__
  return _mm_movemask_epi8(x) == 0xffff;
#elif defined __arm64__
  return vminvq_u8(x) & 0x80;
#else
  return simd_all(x.lo & x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_char32 x) {
#if defined __AVX2__
  return _mm256_movemask_epi8(x) == 0xffffffff;
#else
  return simd_all(x.lo & x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_char64 x) {
  return simd_all(x.lo & x.hi);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar2 x) {
  return simd_all((simd_char2)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar3 x) {
  return simd_all((simd_char3)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar4 x) {
  return simd_all((simd_char4)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar8 x) {
  return simd_all((simd_char8)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar16 x) {
  return simd_all((simd_char16)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar32 x) {
  return simd_all((simd_char32)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uchar64 x) {
  return simd_all((simd_char64)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_short2 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_short8_undef(x)) & 0xa) == 0xa;
#elif defined __arm64__
  return simd_all(x.xyxy);
#else
  union { uint32_t i; simd_short2 v; } u = { .v = x };
  return (u.i & 0x80008000) == 0x80008000;
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_short3 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_short8_undef(x)) & 0x2a) == 0x2a;
#elif defined __arm64__
  return simd_all(x.xyzz);
#else
  union { uint64_t i; simd_short3 v; } u = { .v = x };
  return (u.i & 0x800080008000) == 0x800080008000;
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_short4 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(simd_make_short8_undef(x)) & 0xaa) == 0xaa;
#elif defined __arm64__
  return vminv_u16(x) & 0x8000;
#else
  union { uint64_t i; simd_short4 v; } u = { .v = x };
  return (u.i & 0x8000800080008000) == 0x8000800080008000;
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_short8 x) {
#if defined __SSE2__
  return (_mm_movemask_epi8(x) & 0xaaaa) == 0xaaaa;
#elif defined __arm64__
  return vminvq_u16(x) & 0x8000;
#else
  return simd_all(x.lo & x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_short16 x) {
#if defined __AVX2__
  return (_mm256_movemask_epi8(x) & 0xaaaaaaaa) == 0xaaaaaaaa;
#else
  return simd_all(x.lo & x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_short32 x) {
  return simd_all(x.lo & x.hi);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort2 x) {
  return simd_all((simd_short2)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort3 x) {
  return simd_all((simd_short3)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort4 x) {
  return simd_all((simd_short4)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort8 x) {
  return simd_all((simd_short8)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort16 x) {
  return simd_all((simd_short16)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_ushort32 x) {
  return simd_all((simd_short32)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_int2 x) {
#if defined __SSE2__
  return (_mm_movemask_ps(simd_make_int4_undef(x)) & 0x3) == 0x3;
#elif defined __arm64__
  return vminv_u32(x) & 0x80000000;
#else
  union { uint64_t i; simd_int2 v; } u = { .v = x };
  return (u.i & 0x8000000080000000) == 0x8000000080000000;
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_int3 x) {
#if defined __SSE2__
  return (_mm_movemask_ps(simd_make_int4_undef(x)) & 0x7) == 0x7;
#elif defined __arm64__
  return simd_all(x.xyzz);
#else
  return (x.x & x.y & x.z) & 0x80000000;
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_int4 x) {
#if defined __SSE2__
  return _mm_movemask_ps(x) == 0xf;
#elif defined __arm64__
  return vminvq_u32(x) & 0x80000000;
#else
  return simd_all(x.lo & x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_int8 x) {
#if defined __AVX__
  return _mm256_movemask_ps(x) == 0xff;
#else
  return simd_all(x.lo & x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_int16 x) {
  return simd_all(x.lo & x.hi);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uint2 x) {
  return simd_all((simd_int2)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uint3 x) {
  return simd_all((simd_int3)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uint4 x) {
  return simd_all((simd_int4)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uint8 x) {
  return simd_all((simd_int8)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_uint16 x) {
  return simd_all((simd_int16)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_long2 x) {
#if defined __SSE2__
  return _mm_movemask_pd(x) == 0x3;
#elif defined __arm64__
  return (x.x & x.y) & 0x8000000000000000U;
#else
  return (x.x & x.y) & 0x8000000000000000U;
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_long3 x) {
#if defined __AVX__
  return (_mm256_movemask_pd(simd_make_long4_undef(x)) & 0x7) == 0x7;
#else
  return (x.x & x.y & x.z) & 0x8000000000000000U;
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_long4 x) {
#if defined __AVX__
  return _mm256_movemask_pd(x) == 0xf;
#else
  return simd_all(x.lo & x.hi);
#endif
}
static inline SIMD_CFUNC simd_bool simd_all(simd_long8 x) {
  return simd_all(x.lo & x.hi);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_ulong2 x) {
  return simd_all((simd_long2)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_ulong3 x) {
  return simd_all((simd_long3)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_ulong4 x) {
  return simd_all((simd_long4)x);
}
static inline SIMD_CFUNC simd_bool simd_all(simd_ulong8 x) {
  return simd_all((simd_long8)x);
}
  
static inline SIMD_CFUNC simd_float2 simd_select(simd_float2 x, simd_float2 y, simd_int2 mask) {
  return simd_make_float2(simd_select(simd_make_float4_undef(x), simd_make_float4_undef(y), simd_make_int4_undef(mask)));
}
static inline SIMD_CFUNC simd_float3 simd_select(simd_float3 x, simd_float3 y, simd_int3 mask) {
  return simd_make_float3(simd_select(simd_make_float4_undef(x), simd_make_float4_undef(y), simd_make_int4_undef(mask)));
}
static inline SIMD_CFUNC simd_float4 simd_select(simd_float4 x, simd_float4 y, simd_int4 mask) {
#if defined __SSE4_1__
  return _mm_blendv_ps(x, y, mask);
#else
  return simd_bitselect(x, y, mask >> 31);
#endif
}
static inline SIMD_CFUNC simd_float8 simd_select(simd_float8 x, simd_float8 y, simd_int8 mask) {
#if defined __AVX__
  return _mm256_blendv_ps(x, y, mask);
#else
  return simd_bitselect(x, y, mask >> 31);
#endif
}
static inline SIMD_CFUNC simd_float16 simd_select(simd_float16 x, simd_float16 y, simd_int16 mask) {
  return simd_bitselect(x, y, mask >> 31);
}
static inline SIMD_CFUNC simd_double2 simd_select(simd_double2 x, simd_double2 y, simd_long2 mask) {
#if defined __SSE4_1__
  return _mm_blendv_pd(x, y, mask);
#else
  return simd_bitselect(x, y, mask >> 63);
#endif
}
static inline SIMD_CFUNC simd_double3 simd_select(simd_double3 x, simd_double3 y, simd_long3 mask) {
  return simd_make_double3(simd_select(simd_make_double4_undef(x), simd_make_double4_undef(y), simd_make_long4_undef(mask)));
}
static inline SIMD_CFUNC simd_double4 simd_select(simd_double4 x, simd_double4 y, simd_long4 mask) {
#if defined __AVX__
  return _mm256_blendv_pd(x, y, mask);
#else
  return simd_bitselect(x, y, mask >> 63);
#endif
}
static inline SIMD_CFUNC simd_double8 simd_select(simd_double8 x, simd_double8 y, simd_long8 mask) {
  return simd_bitselect(x, y, mask >> 63);
}
  
static inline SIMD_CFUNC simd_char2 simd_bitselect(simd_char2 x, simd_char2 y, simd_char2 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_char3 simd_bitselect(simd_char3 x, simd_char3 y, simd_char3 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_char4 simd_bitselect(simd_char4 x, simd_char4 y, simd_char4 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_char8 simd_bitselect(simd_char8 x, simd_char8 y, simd_char8 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_char16 simd_bitselect(simd_char16 x, simd_char16 y, simd_char16 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_char32 simd_bitselect(simd_char32 x, simd_char32 y, simd_char32 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_char64 simd_bitselect(simd_char64 x, simd_char64 y, simd_char64 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_uchar2 simd_bitselect(simd_uchar2 x, simd_uchar2 y, simd_char2 mask) {
  return (simd_uchar2)simd_bitselect((simd_char2)x, (simd_char2)y, mask);
}
static inline SIMD_CFUNC simd_uchar3 simd_bitselect(simd_uchar3 x, simd_uchar3 y, simd_char3 mask) {
  return (simd_uchar3)simd_bitselect((simd_char3)x, (simd_char3)y, mask);
}
static inline SIMD_CFUNC simd_uchar4 simd_bitselect(simd_uchar4 x, simd_uchar4 y, simd_char4 mask) {
  return (simd_uchar4)simd_bitselect((simd_char4)x, (simd_char4)y, mask);
}
static inline SIMD_CFUNC simd_uchar8 simd_bitselect(simd_uchar8 x, simd_uchar8 y, simd_char8 mask) {
  return (simd_uchar8)simd_bitselect((simd_char8)x, (simd_char8)y, mask);
}
static inline SIMD_CFUNC simd_uchar16 simd_bitselect(simd_uchar16 x, simd_uchar16 y, simd_char16 mask) {
  return (simd_uchar16)simd_bitselect((simd_char16)x, (simd_char16)y, mask);
}
static inline SIMD_CFUNC simd_uchar32 simd_bitselect(simd_uchar32 x, simd_uchar32 y, simd_char32 mask) {
  return (simd_uchar32)simd_bitselect((simd_char32)x, (simd_char32)y, mask);
}
static inline SIMD_CFUNC simd_uchar64 simd_bitselect(simd_uchar64 x, simd_uchar64 y, simd_char64 mask) {
  return (simd_uchar64)simd_bitselect((simd_char64)x, (simd_char64)y, mask);
}
static inline SIMD_CFUNC simd_short2 simd_bitselect(simd_short2 x, simd_short2 y, simd_short2 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_short3 simd_bitselect(simd_short3 x, simd_short3 y, simd_short3 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_short4 simd_bitselect(simd_short4 x, simd_short4 y, simd_short4 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_short8 simd_bitselect(simd_short8 x, simd_short8 y, simd_short8 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_short16 simd_bitselect(simd_short16 x, simd_short16 y, simd_short16 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_short32 simd_bitselect(simd_short32 x, simd_short32 y, simd_short32 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_ushort2 simd_bitselect(simd_ushort2 x, simd_ushort2 y, simd_short2 mask) {
  return (simd_ushort2)simd_bitselect((simd_short2)x, (simd_short2)y, mask);
}
static inline SIMD_CFUNC simd_ushort3 simd_bitselect(simd_ushort3 x, simd_ushort3 y, simd_short3 mask) {
  return (simd_ushort3)simd_bitselect((simd_short3)x, (simd_short3)y, mask);
}
static inline SIMD_CFUNC simd_ushort4 simd_bitselect(simd_ushort4 x, simd_ushort4 y, simd_short4 mask) {
  return (simd_ushort4)simd_bitselect((simd_short4)x, (simd_short4)y, mask);
}
static inline SIMD_CFUNC simd_ushort8 simd_bitselect(simd_ushort8 x, simd_ushort8 y, simd_short8 mask) {
  return (simd_ushort8)simd_bitselect((simd_short8)x, (simd_short8)y, mask);
}
static inline SIMD_CFUNC simd_ushort16 simd_bitselect(simd_ushort16 x, simd_ushort16 y, simd_short16 mask) {
  return (simd_ushort16)simd_bitselect((simd_short16)x, (simd_short16)y, mask);
}
static inline SIMD_CFUNC simd_ushort32 simd_bitselect(simd_ushort32 x, simd_ushort32 y, simd_short32 mask) {
  return (simd_ushort32)simd_bitselect((simd_short32)x, (simd_short32)y, mask);
}
static inline SIMD_CFUNC simd_int2 simd_bitselect(simd_int2 x, simd_int2 y, simd_int2 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_int3 simd_bitselect(simd_int3 x, simd_int3 y, simd_int3 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_int4 simd_bitselect(simd_int4 x, simd_int4 y, simd_int4 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_int8 simd_bitselect(simd_int8 x, simd_int8 y, simd_int8 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_int16 simd_bitselect(simd_int16 x, simd_int16 y, simd_int16 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_uint2 simd_bitselect(simd_uint2 x, simd_uint2 y, simd_int2 mask) {
  return (simd_uint2)simd_bitselect((simd_int2)x, (simd_int2)y, mask);
}
static inline SIMD_CFUNC simd_uint3 simd_bitselect(simd_uint3 x, simd_uint3 y, simd_int3 mask) {
  return (simd_uint3)simd_bitselect((simd_int3)x, (simd_int3)y, mask);
}
static inline SIMD_CFUNC simd_uint4 simd_bitselect(simd_uint4 x, simd_uint4 y, simd_int4 mask) {
  return (simd_uint4)simd_bitselect((simd_int4)x, (simd_int4)y, mask);
}
static inline SIMD_CFUNC simd_uint8 simd_bitselect(simd_uint8 x, simd_uint8 y, simd_int8 mask) {
  return (simd_uint8)simd_bitselect((simd_int8)x, (simd_int8)y, mask);
}
static inline SIMD_CFUNC simd_uint16 simd_bitselect(simd_uint16 x, simd_uint16 y, simd_int16 mask) {
  return (simd_uint16)simd_bitselect((simd_int16)x, (simd_int16)y, mask);
}
static inline SIMD_CFUNC simd_float2 simd_bitselect(simd_float2 x, simd_float2 y, simd_int2 mask) {
  return (simd_float2)simd_bitselect((simd_int2)x, (simd_int2)y, mask);
}
static inline SIMD_CFUNC simd_float3 simd_bitselect(simd_float3 x, simd_float3 y, simd_int3 mask) {
  return (simd_float3)simd_bitselect((simd_int3)x, (simd_int3)y, mask);
}
static inline SIMD_CFUNC simd_float4 simd_bitselect(simd_float4 x, simd_float4 y, simd_int4 mask) {
  return (simd_float4)simd_bitselect((simd_int4)x, (simd_int4)y, mask);
}
static inline SIMD_CFUNC simd_float8 simd_bitselect(simd_float8 x, simd_float8 y, simd_int8 mask) {
  return (simd_float8)simd_bitselect((simd_int8)x, (simd_int8)y, mask);
}
static inline SIMD_CFUNC simd_float16 simd_bitselect(simd_float16 x, simd_float16 y, simd_int16 mask) {
  return (simd_float16)simd_bitselect((simd_int16)x, (simd_int16)y, mask);
}
static inline SIMD_CFUNC simd_long2 simd_bitselect(simd_long2 x, simd_long2 y, simd_long2 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_long3 simd_bitselect(simd_long3 x, simd_long3 y, simd_long3 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_long4 simd_bitselect(simd_long4 x, simd_long4 y, simd_long4 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_long8 simd_bitselect(simd_long8 x, simd_long8 y, simd_long8 mask) {
  return (x & ~mask) | (y & mask);
}
static inline SIMD_CFUNC simd_ulong2 simd_bitselect(simd_ulong2 x, simd_ulong2 y, simd_long2 mask) {
  return (simd_ulong2)simd_bitselect((simd_long2)x, (simd_long2)y, mask);
}
static inline SIMD_CFUNC simd_ulong3 simd_bitselect(simd_ulong3 x, simd_ulong3 y, simd_long3 mask) {
  return (simd_ulong3)simd_bitselect((simd_long3)x, (simd_long3)y, mask);
}
static inline SIMD_CFUNC simd_ulong4 simd_bitselect(simd_ulong4 x, simd_ulong4 y, simd_long4 mask) {
  return (simd_ulong4)simd_bitselect((simd_long4)x, (simd_long4)y, mask);
}
static inline SIMD_CFUNC simd_ulong8 simd_bitselect(simd_ulong8 x, simd_ulong8 y, simd_long8 mask) {
  return (simd_ulong8)simd_bitselect((simd_long8)x, (simd_long8)y, mask);
}
static inline SIMD_CFUNC simd_double2 simd_bitselect(simd_double2 x, simd_double2 y, simd_long2 mask) {
  return (simd_double2)simd_bitselect((simd_long2)x, (simd_long2)y, mask);
}
static inline SIMD_CFUNC simd_double3 simd_bitselect(simd_double3 x, simd_double3 y, simd_long3 mask) {
  return (simd_double3)simd_bitselect((simd_long3)x, (simd_long3)y, mask);
}
static inline SIMD_CFUNC simd_double4 simd_bitselect(simd_double4 x, simd_double4 y, simd_long4 mask) {
  return (simd_double4)simd_bitselect((simd_long4)x, (simd_long4)y, mask);
}
static inline SIMD_CFUNC simd_double8 simd_bitselect(simd_double8 x, simd_double8 y, simd_long8 mask) {
  return (simd_double8)simd_bitselect((simd_long8)x, (simd_long8)y, mask);
}

#ifdef __cplusplus
}
#endif
#endif /* SIMD_COMPILER_HAS_REQUIRED_FEATURES */
#endif /* __SIMD_LOGIC_HEADER__ */