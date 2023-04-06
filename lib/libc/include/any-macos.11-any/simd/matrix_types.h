/*  Copyright (c) 2014-2017 Apple, Inc. All rights reserved.
 *
 *  This header defines nine matrix types for each of float and double, which
 *  are intended for use together with the vector types defined in
 *  <simd/vector_types.h>.
 *
 *  For compatibility with common graphics libraries, these matrices are stored
 *  in column-major order, and implemented as arrays of column vectors.
 *  Column-major storage order may seem a little strange if you aren't used to
 *  it, but for most usage the memory layout of the matrices shouldn't matter
 *  at all; instead you should think of matrices as abstract mathematical
 *  objects that you use to perform arithmetic without worrying about the
 *  details of the underlying representation.
 *
 *  WARNING: vectors of length three are internally represented as length four
 *  vectors with one element of padding (for alignment purposes).  This means
 *  that when a floatNx3 or doubleNx3 is viewed as a vector, it appears to
 *  have 4*N elements instead of the expected 3*N (with one padding element
 *  at the end of each column).  The matrix elements are laid out in memory
 *  as follows:
 *
 *      { 0, 1, 2, x, 3, 4, 5, x, ... }
 *
 *  (where the scalar indices used above indicate the conceptual column-
 *  major storage order).  If you aren't monkeying around with the internal
 *  storage details of matrices, you don't need to worry about this at all.
 *  Consider this yet another good reason to avoid doing so.                  */

#ifndef SIMD_MATRIX_TYPES_HEADER
#define SIMD_MATRIX_TYPES_HEADER

#include <simd/types.h>
#if SIMD_COMPILER_HAS_REQUIRED_FEATURES

/*  Matrix types available in C, Objective-C, and C++                         */
typedef simd_float2x2 matrix_float2x2;
typedef simd_float3x2 matrix_float3x2;
typedef simd_float4x2 matrix_float4x2;

typedef simd_float2x3 matrix_float2x3;
typedef simd_float3x3 matrix_float3x3;
typedef simd_float4x3 matrix_float4x3;

typedef simd_float2x4 matrix_float2x4;
typedef simd_float3x4 matrix_float3x4;
typedef simd_float4x4 matrix_float4x4;

typedef simd_double2x2 matrix_double2x2;
typedef simd_double3x2 matrix_double3x2;
typedef simd_double4x2 matrix_double4x2;

typedef simd_double2x3 matrix_double2x3;
typedef simd_double3x3 matrix_double3x3;
typedef simd_double4x3 matrix_double4x3;

typedef simd_double2x4 matrix_double2x4;
typedef simd_double3x4 matrix_double3x4;
typedef simd_double4x4 matrix_double4x4;

#ifdef __cplusplus
#if defined SIMD_MATRIX_HEADER
static  simd_float3x3 SIMD_NOINLINE simd_matrix3x3(simd_quatf q);
static  simd_float4x4 SIMD_NOINLINE simd_matrix4x4(simd_quatf q);
static simd_double3x3 SIMD_NOINLINE simd_matrix3x3(simd_quatd q);
static simd_double4x4 SIMD_NOINLINE simd_matrix4x4(simd_quatd q);
#endif

namespace simd {
  
  struct float2x2 : ::simd_float2x2 {
    float2x2() { columns[0] = 0; columns[1] = 0; }
#if __has_feature(cxx_delegating_constructors)
    float2x2(float diagonal) : float2x2((float2)diagonal) { }
#endif
    float2x2(float2 v) { columns[0] = (float2){v.x,0}; columns[1] = (float2){0,v.y}; }
    float2x2(float2 c0, float2 c1) { columns[0] = c0; columns[1] = c1; }
    float2x2(::simd_float2x2 m) : ::simd_float2x2(m) { }
  };
  
  struct float3x2 : ::simd_float3x2 {
    float3x2() { columns[0] = 0; columns[1] = 0; columns[2] = 0; }
#if __has_feature(cxx_delegating_constructors)
    float3x2(float diagonal) : float3x2((float2)diagonal) { }
#endif
    float3x2(float2 v) { columns[0] = (float2){v.x,0}; columns[1] = (float2){0,v.y}; columns[2] = 0; }
    float3x2(float2 c0, float2 c1, float2 c2) { columns[0] = c0; columns[1] = c1; columns[2] = c2; }
    float3x2(::simd_float3x2 m) : ::simd_float3x2(m) { }
  };
  
  struct float4x2 : ::simd_float4x2 {
    float4x2() { columns[0] = 0; columns[1] = 0; columns[2] = 0; columns[3] = 0; }
#if __has_feature(cxx_delegating_constructors)
    float4x2(float diagonal) : float4x2((float2)diagonal) { }
#endif
    float4x2(float2 v) { columns[0] = (float2){v.x,0}; columns[1] = (float2){0,v.y}; columns[2] = 0; columns[3] = 0; }
    float4x2(float2 c0, float2 c1, float2 c2, float2 c3) { columns[0] = c0; columns[1] = c1; columns[2] = c2; columns[3] = c3; }
    float4x2(::simd_float4x2 m) : ::simd_float4x2(m) { }
  };
  
  struct float2x3 : ::simd_float2x3 {
    float2x3() { columns[0] = 0; columns[1] = 0; }
#if __has_feature(cxx_delegating_constructors)
    float2x3(float diagonal) : float2x3((float2)diagonal) { }
#endif
    float2x3(float2 v) { columns[0] = (float3){v.x,0,0}; columns[1] = (float3){0,v.y,0}; }
    float2x3(float3 c0, float3 c1) { columns[0] = c0; columns[1] = c1; }
    float2x3(::simd_float2x3 m) : ::simd_float2x3(m) { }
  };
  
  struct float3x3 : ::simd_float3x3 {
    float3x3() { columns[0] = 0; columns[1] = 0; columns[2] = 0; }
#if __has_feature(cxx_delegating_constructors)
    float3x3(float diagonal) : float3x3((float3)diagonal) { }
#endif
    float3x3(float3 v) { columns[0] = (float3){v.x,0,0}; columns[1] = (float3){0,v.y,0}; columns[2] = (float3){0,0,v.z}; }
    float3x3(float3 c0, float3 c1, float3 c2) { columns[0] = c0; columns[1] = c1; columns[2] = c2; }
    float3x3(::simd_float3x3 m) : ::simd_float3x3(m) { }
#if defined SIMD_MATRIX_HEADER
    float3x3(::simd_quatf q) : ::simd_float3x3(::simd_matrix3x3(q)) { }
#endif
  };
  
  struct float4x3 : ::simd_float4x3 {
    float4x3() { columns[0] = 0; columns[1] = 0; columns[2] = 0; columns[3] = 0; }
#if __has_feature(cxx_delegating_constructors)
    float4x3(float diagonal) : float4x3((float3)diagonal) { }
#endif
    float4x3(float3 v) { columns[0] = (float3){v.x,0,0}; columns[1] = (float3){0,v.y,0}; columns[2] = (float3){0,0,v.z}; columns[3] = 0; }
    float4x3(float3 c0, float3 c1, float3 c2, float3 c3) { columns[0] = c0; columns[1] = c1; columns[2] = c2; columns[3] = c3; }
    float4x3(::simd_float4x3 m) : ::simd_float4x3(m) { }
  };
  
  struct float2x4 : ::simd_float2x4 {
    float2x4() { columns[0] = 0; columns[1] = 0; }
#if __has_feature(cxx_delegating_constructors)
    float2x4(float diagonal) : float2x4((float2)diagonal) { }
#endif
    float2x4(float2 v) { columns[0] = (float4){v.x,0,0,0}; columns[1] = (float4){0,v.y,0,0}; }
    float2x4(float4 c0, float4 c1) { columns[0] = c0; columns[1] = c1; }
    float2x4(::simd_float2x4 m) : ::simd_float2x4(m) { }
  };
  
  struct float3x4 : ::simd_float3x4 {
    float3x4() { columns[0] = 0; columns[1] = 0; columns[2] = 0; }
#if __has_feature(cxx_delegating_constructors)
    float3x4(float diagonal) : float3x4((float3)diagonal) { }
#endif
    float3x4(float3 v) { columns[0] = (float4){v.x,0,0,0}; columns[1] = (float4){0,v.y,0,0}; columns[2] = (float4){0,0,v.z,0}; }
    float3x4(float4 c0, float4 c1, float4 c2) { columns[0] = c0; columns[1] = c1; columns[2] = c2; }
    float3x4(::simd_float3x4 m) : ::simd_float3x4(m) { }
  };
  
  struct float4x4 : ::simd_float4x4 {
    float4x4() { columns[0] = 0; columns[1] = 0; columns[2] = 0; columns[3] = 0; }
#if __has_feature(cxx_delegating_constructors)
    float4x4(float diagonal) : float4x4((float4)diagonal) { }
#endif
    float4x4(float4 v) { columns[0] = (float4){v.x,0,0,0}; columns[1] = (float4){0,v.y,0,0}; columns[2] = (float4){0,0,v.z,0}; columns[3] = (float4){0,0,0,v.w}; }
    float4x4(float4 c0, float4 c1, float4 c2, float4 c3) { columns[0] = c0; columns[1] = c1; columns[2] = c2; columns[3] = c3; }
    float4x4(::simd_float4x4 m) : ::simd_float4x4(m) { }
#if defined SIMD_MATRIX_HEADER
    float4x4(::simd_quatf q) : ::simd_float4x4(::simd_matrix4x4(q)) { }
#endif
  };
  
  struct double2x2 : ::simd_double2x2 {
    double2x2() { columns[0] = 0; columns[1] = 0; }
#if __has_feature(cxx_delegating_constructors)
    double2x2(double diagonal) : double2x2((double2)diagonal) { }
#endif
    double2x2(double2 v) { columns[0] = (double2){v.x,0}; columns[1] = (double2){0,v.y}; }
    double2x2(double2 c0, double2 c1) { columns[0] = c0; columns[1] = c1; }
    double2x2(::simd_double2x2 m) : ::simd_double2x2(m) { }
  };
  
  struct double3x2 : ::simd_double3x2 {
    double3x2() { columns[0] = 0; columns[1] = 0; columns[2] = 0; }
#if __has_feature(cxx_delegating_constructors)
    double3x2(double diagonal) : double3x2((double2)diagonal) { }
#endif
    double3x2(double2 v) { columns[0] = (double2){v.x,0}; columns[1] = (double2){0,v.y}; columns[2] = 0; }
    double3x2(double2 c0, double2 c1, double2 c2) { columns[0] = c0; columns[1] = c1; columns[2] = c2; }
    double3x2(::simd_double3x2 m) : ::simd_double3x2(m) { }
  };
  
  struct double4x2 : ::simd_double4x2 {
    double4x2() { columns[0] = 0; columns[1] = 0; columns[2] = 0; columns[3] = 0; }
#if __has_feature(cxx_delegating_constructors)
    double4x2(double diagonal) : double4x2((double2)diagonal) { }
#endif
    double4x2(double2 v) { columns[0] = (double2){v.x,0}; columns[1] = (double2){0,v.y}; columns[2] = 0; columns[3] = 0; }
    double4x2(double2 c0, double2 c1, double2 c2, double2 c3) { columns[0] = c0; columns[1] = c1; columns[2] = c2; columns[3] = c3; }
    double4x2(::simd_double4x2 m) : ::simd_double4x2(m) { }
  };
  
  struct double2x3 : ::simd_double2x3 {
    double2x3() { columns[0] = 0; columns[1] = 0; }
#if __has_feature(cxx_delegating_constructors)
    double2x3(double diagonal) : double2x3((double2)diagonal) { }
#endif
    double2x3(double2 v) { columns[0] = (double3){v.x,0,0}; columns[1] = (double3){0,v.y,0}; }
    double2x3(double3 c0, double3 c1) { columns[0] = c0; columns[1] = c1; }
    double2x3(::simd_double2x3 m) : ::simd_double2x3(m) { }
  };
  
  struct double3x3 : ::simd_double3x3 {
    double3x3() { columns[0] = 0; columns[1] = 0; columns[2] = 0; }
#if __has_feature(cxx_delegating_constructors)
    double3x3(double diagonal) : double3x3((double3)diagonal) { }
#endif
    double3x3(double3 v) { columns[0] = (double3){v.x,0,0}; columns[1] = (double3){0,v.y,0}; columns[2] = (double3){0,0,v.z}; }
    double3x3(double3 c0, double3 c1, double3 c2) { columns[0] = c0; columns[1] = c1; columns[2] = c2; }
    double3x3(::simd_double3x3 m) : ::simd_double3x3(m) { }
#if defined SIMD_MATRIX_HEADER
    double3x3(::simd_quatd q) : ::simd_double3x3(::simd_matrix3x3(q)) { }
#endif
  };
  
  struct double4x3 : ::simd_double4x3 {
    double4x3() { columns[0] = 0; columns[1] = 0; columns[2] = 0; columns[3] = 0; }
#if __has_feature(cxx_delegating_constructors)
    double4x3(double diagonal) : double4x3((double3)diagonal) { }
#endif
    double4x3(double3 v) { columns[0] = (double3){v.x,0,0}; columns[1] = (double3){0,v.y,0}; columns[2] = (double3){0,0,v.z}; columns[3] = 0; }
    double4x3(double3 c0, double3 c1, double3 c2, double3 c3) { columns[0] = c0; columns[1] = c1; columns[2] = c2; columns[3] = c3; }
    double4x3(::simd_double4x3 m) : ::simd_double4x3(m) { }
  };
  
  struct double2x4 : ::simd_double2x4 {
    double2x4() { columns[0] = 0; columns[1] = 0; }
#if __has_feature(cxx_delegating_constructors)
    double2x4(double diagonal) : double2x4((double2)diagonal) { }
#endif
    double2x4(double2 v) { columns[0] = (double4){v.x,0,0,0}; columns[1] = (double4){0,v.y,0,0}; }
    double2x4(double4 c0, double4 c1) { columns[0] = c0; columns[1] = c1; }
    double2x4(::simd_double2x4 m) : ::simd_double2x4(m) { }
  };
  
  struct double3x4 : ::simd_double3x4 {
    double3x4() { columns[0] = 0; columns[1] = 0; columns[2] = 0; }
#if __has_feature(cxx_delegating_constructors)
    double3x4(double diagonal) : double3x4((double3)diagonal) { }
#endif
    double3x4(double3 v) { columns[0] = (double4){v.x,0,0,0}; columns[1] = (double4){0,v.y,0,0}; columns[2] = (double4){0,0,v.z,0}; }
    double3x4(double4 c0, double4 c1, double4 c2) { columns[0] = c0; columns[1] = c1; columns[2] = c2; }
    double3x4(::simd_double3x4 m) : ::simd_double3x4(m) { }
  };
  
  struct double4x4 : ::simd_double4x4 {
    double4x4() { columns[0] = 0; columns[1] = 0; columns[2] = 0; columns[3] = 0; }
#if __has_feature(cxx_delegating_constructors)
    double4x4(double diagonal) : double4x4((double4)diagonal) { }
#endif
    double4x4(double4 v) { columns[0] = (double4){v.x,0,0,0}; columns[1] = (double4){0,v.y,0,0}; columns[2] = (double4){0,0,v.z,0}; columns[3] = (double4){0,0,0,v.w}; }
    double4x4(double4 c0, double4 c1, double4 c2, double4 c3) { columns[0] = c0; columns[1] = c1; columns[2] = c2; columns[3] = c3; }
    double4x4(::simd_double4x4 m) : ::simd_double4x4(m) { }
#if defined SIMD_MATRIX_HEADER
    double4x4(::simd_quatd q) : ::simd_double4x4(::simd_matrix4x4(q)) { }
#endif
  };
}
#endif /* __cplusplus */
#endif /* SIMD_COMPILER_HAS_REQUIRED_FEATURES */
#endif /* SIMD_MATRIX_TYPES_HEADER */