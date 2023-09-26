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
#include <simd/vector_make.h>
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
    SIMD_CONSTEXPR float2x2() SIMD_NOEXCEPT : ::simd_float2x2((simd_float2x2){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR float2x2(float diagonal) SIMD_NOEXCEPT : float2x2((float2)diagonal) { }
#endif
    SIMD_CONSTEXPR float2x2(float2 v) SIMD_NOEXCEPT :
    ::simd_float2x2((simd_float2x2){(float2){v.x,0}, (float2){0,v.y}}) { }
    SIMD_CONSTEXPR float2x2(float2 c0, float2 c1) SIMD_NOEXCEPT : simd_float2x2((simd_float2x2){c0, c1}) { }
    SIMD_CONSTEXPR float2x2(::simd_float2x2 m) SIMD_NOEXCEPT : ::simd_float2x2(m) { }
  };
  
  struct float3x2 : ::simd_float3x2 {
    SIMD_CONSTEXPR float3x2() SIMD_NOEXCEPT : ::simd_float3x2((simd_float3x2){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR float3x2(float diagonal) SIMD_NOEXCEPT : float3x2((float2)diagonal) { }
#endif
    SIMD_CONSTEXPR float3x2(float2 v) SIMD_NOEXCEPT :
    ::simd_float3x2((simd_float3x2){(float2){v.x,0}, (float2){0,v.y}, (float2){0}}) { }
    SIMD_CONSTEXPR float3x2(float2 c0, float2 c1, float2 c2) SIMD_NOEXCEPT :
    ::simd_float3x2((simd_float3x2){c0, c1, c2}) { }
    SIMD_CONSTEXPR float3x2(::simd_float3x2 m) SIMD_NOEXCEPT : ::simd_float3x2(m) { }
  };
  
  struct float4x2 : ::simd_float4x2 {
    SIMD_CONSTEXPR float4x2() SIMD_NOEXCEPT : ::simd_float4x2((simd_float4x2){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR float4x2(float diagonal) SIMD_NOEXCEPT : float4x2((float2)diagonal) { }
#endif
    SIMD_CONSTEXPR float4x2(float2 v) SIMD_NOEXCEPT :
    ::simd_float4x2((simd_float4x2){(float2){v.x,0}, (float2){0,v.y}, (float2){0}, (float2){0}}) { }
    SIMD_CONSTEXPR float4x2(float2 c0, float2 c1, float2 c2, float2 c3) SIMD_NOEXCEPT :
    ::simd_float4x2((simd_float4x2){c0, c1, c2, c3}) { }
    SIMD_CONSTEXPR float4x2(::simd_float4x2 m) SIMD_NOEXCEPT : ::simd_float4x2(m) { }
  };
  
  struct float2x3 : ::simd_float2x3 {
    SIMD_CONSTEXPR float2x3() SIMD_NOEXCEPT : ::simd_float2x3((simd_float2x3){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR float2x3(float diagonal) SIMD_NOEXCEPT : float2x3((float2)diagonal) { }
#endif
    SIMD_CONSTEXPR float2x3(float2 v) SIMD_NOEXCEPT :
    ::simd_float2x3((simd_float2x3){(float3){v.x,0,0}, (float3){0,v.y,0}}) { }
    SIMD_CONSTEXPR float2x3(float3 c0, float3 c1) SIMD_NOEXCEPT : ::simd_float2x3((simd_float2x3){c0, c1}) { }
    SIMD_CONSTEXPR float2x3(::simd_float2x3 m) SIMD_NOEXCEPT : ::simd_float2x3(m) { }
  };
  
  struct float3x3 : ::simd_float3x3 {
    SIMD_CONSTEXPR float3x3() SIMD_NOEXCEPT : ::simd_float3x3((simd_float3x3){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR float3x3(float diagonal) SIMD_NOEXCEPT : float3x3((float3)diagonal) { }
#endif
    SIMD_CONSTEXPR float3x3(float3 v) SIMD_NOEXCEPT :
    ::simd_float3x3((simd_float3x3){(float3){v.x,0,0}, (float3){0,v.y,0}, (float3){0,0,v.z}}) { }
    SIMD_CONSTEXPR float3x3(float3 c0, float3 c1, float3 c2) SIMD_NOEXCEPT :
    ::simd_float3x3((simd_float3x3){c0, c1, c2}) { }
    SIMD_CONSTEXPR float3x3(::simd_float3x3 m) SIMD_NOEXCEPT : ::simd_float3x3(m) { }
#if defined SIMD_MATRIX_HEADER
    SIMD_CONSTEXPR float3x3(::simd_quatf q) SIMD_NOEXCEPT : ::simd_float3x3(::simd_matrix3x3(q)) { }
#endif
  };
  
  struct float4x3 : ::simd_float4x3 {
    SIMD_CONSTEXPR float4x3() SIMD_NOEXCEPT : ::simd_float4x3((simd_float4x3){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR float4x3(float diagonal) SIMD_NOEXCEPT : float4x3((float3)diagonal) { }
#endif
    SIMD_CONSTEXPR float4x3(float3 v) SIMD_NOEXCEPT :
    ::simd_float4x3((simd_float4x3){(float3){v.x,0,0}, (float3){0,v.y,0}, (float3){0,0,v.z}, (float3){0}}) { }
    SIMD_CONSTEXPR float4x3(float3 c0, float3 c1, float3 c2, float3 c3) SIMD_NOEXCEPT :
    ::simd_float4x3((simd_float4x3){c0, c1, c2, c3}) { }
    SIMD_CONSTEXPR float4x3(::simd_float4x3 m) SIMD_NOEXCEPT : ::simd_float4x3(m) { }
  };
  
  struct float2x4 : ::simd_float2x4 {
    SIMD_CONSTEXPR float2x4() SIMD_NOEXCEPT : ::simd_float2x4((simd_float2x4){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR float2x4(float diagonal) SIMD_NOEXCEPT : float2x4((float2)diagonal) { }
#endif
    SIMD_CONSTEXPR float2x4(float2 v) SIMD_NOEXCEPT :
    ::simd_float2x4((simd_float2x4){(float4){v.x,0,0,0}, (float4){0,v.y,0,0}}) { }
    SIMD_CONSTEXPR float2x4(float4 c0, float4 c1) SIMD_NOEXCEPT : ::simd_float2x4((simd_float2x4){c0, c1}) { }
    SIMD_CONSTEXPR float2x4(::simd_float2x4 m) SIMD_NOEXCEPT : ::simd_float2x4(m) { }
  };
  
  struct float3x4 : ::simd_float3x4 {
    SIMD_CONSTEXPR float3x4() SIMD_NOEXCEPT : ::simd_float3x4((simd_float3x4){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR float3x4(float diagonal) SIMD_NOEXCEPT : float3x4((float3)diagonal) { }
#endif
    SIMD_CONSTEXPR float3x4(float3 v) SIMD_NOEXCEPT :
    ::simd_float3x4((simd_float3x4){(float4){v.x,0,0,0}, (float4){0,v.y,0,0}, (float4){0,0,v.z,0}}) { }
    SIMD_CONSTEXPR float3x4(float4 c0, float4 c1, float4 c2) SIMD_NOEXCEPT :
    ::simd_float3x4((simd_float3x4){c0, c1, c2}) { }
    SIMD_CONSTEXPR float3x4(::simd_float3x4 m) SIMD_NOEXCEPT : ::simd_float3x4(m) { }
  };
  
  struct float4x4 : ::simd_float4x4 {
    SIMD_CONSTEXPR float4x4() SIMD_NOEXCEPT : ::simd_float4x4((simd_float4x4){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR float4x4(float diagonal) SIMD_NOEXCEPT : float4x4((float4)diagonal) { }
#endif
    SIMD_CONSTEXPR float4x4(float4 v) SIMD_NOEXCEPT :
    ::simd_float4x4((simd_float4x4){(float4){v.x,0,0,0}, (float4){0,v.y,0,0}, (float4){0,0,v.z,0}, (float4){0,0,0,v.w}}) { }
    SIMD_CONSTEXPR float4x4(float4 c0, float4 c1, float4 c2, float4 c3) SIMD_NOEXCEPT :
    ::simd_float4x4((simd_float4x4){c0, c1, c2, c3}) { }
    SIMD_CONSTEXPR float4x4(::simd_float4x4 m) SIMD_NOEXCEPT : ::simd_float4x4(m) { }
#if defined SIMD_MATRIX_HEADER
    SIMD_CONSTEXPR float4x4(::simd_quatf q) SIMD_NOEXCEPT : ::simd_float4x4(::simd_matrix4x4(q)) { }
#endif
  };
  
  struct double2x2 : ::simd_double2x2 {
    SIMD_CONSTEXPR double2x2() SIMD_NOEXCEPT : ::simd_double2x2((simd_double2x2){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR double2x2(double diagonal) SIMD_NOEXCEPT : double2x2((double2)diagonal) { }
#endif
    SIMD_CONSTEXPR double2x2(double2 v) SIMD_NOEXCEPT :
    ::simd_double2x2((simd_double2x2){(double2){v.x,0}, (double2){0,v.y}}) { }
    SIMD_CONSTEXPR double2x2(double2 c0, double2 c1) SIMD_NOEXCEPT :
    ::simd_double2x2((simd_double2x2){c0, c1}) { }
    SIMD_CONSTEXPR double2x2(::simd_double2x2 m) SIMD_NOEXCEPT : ::simd_double2x2(m) { }
  };
  
  struct double3x2 : ::simd_double3x2 {
    SIMD_CONSTEXPR double3x2() SIMD_NOEXCEPT : ::simd_double3x2((simd_double3x2){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR double3x2(double diagonal) SIMD_NOEXCEPT : double3x2((double2)diagonal) { }
#endif
    SIMD_CONSTEXPR double3x2(double2 v) SIMD_NOEXCEPT :
    ::simd_double3x2((simd_double3x2){(double2){v.x,0}, (double2){0,v.y}, (double2){0}}) { }
    SIMD_CONSTEXPR double3x2(double2 c0, double2 c1, double2 c2) SIMD_NOEXCEPT :
    ::simd_double3x2((simd_double3x2){c0, c1, c2}) { }
    SIMD_CONSTEXPR double3x2(::simd_double3x2 m) SIMD_NOEXCEPT : ::simd_double3x2(m) { }
  };
  
  struct double4x2 : ::simd_double4x2 {
    SIMD_CONSTEXPR double4x2() SIMD_NOEXCEPT : ::simd_double4x2((simd_double4x2){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR double4x2(double diagonal) SIMD_NOEXCEPT : double4x2((double2)diagonal) { }
#endif
    SIMD_CONSTEXPR double4x2(double2 v) SIMD_NOEXCEPT :
    ::simd_double4x2((simd_double4x2){(double2){v.x,0}, (double2){0,v.y}, (double2){0}, (double2){0}}) { }
    SIMD_CONSTEXPR double4x2(double2 c0, double2 c1, double2 c2, double2 c3) SIMD_NOEXCEPT :
    ::simd_double4x2((simd_double4x2){c0, c1, c2, c3}) { }
    SIMD_CONSTEXPR double4x2(::simd_double4x2 m) SIMD_NOEXCEPT : ::simd_double4x2(m) { }
  };
  
  struct double2x3 : ::simd_double2x3 {
    SIMD_CONSTEXPR double2x3() SIMD_NOEXCEPT : ::simd_double2x3((simd_double2x3){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR double2x3(double diagonal) SIMD_NOEXCEPT : double2x3((double2)diagonal) { }
#endif
    SIMD_CONSTEXPR double2x3(double2 v) SIMD_NOEXCEPT :
    ::simd_double2x3((simd_double2x3){(double3){v.x,0,0}, (double3){0,v.y,0}}) { }
    SIMD_CONSTEXPR double2x3(double3 c0, double3 c1) SIMD_NOEXCEPT :
    ::simd_double2x3((simd_double2x3){c0, c1}) { }
    SIMD_CONSTEXPR double2x3(::simd_double2x3 m) SIMD_NOEXCEPT : ::simd_double2x3(m) { }
  };
  
  struct double3x3 : ::simd_double3x3 {
    SIMD_CONSTEXPR double3x3() SIMD_NOEXCEPT : ::simd_double3x3((simd_double3x3){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR double3x3(double diagonal) SIMD_NOEXCEPT : double3x3((double3)diagonal) { }
#endif
    SIMD_CONSTEXPR double3x3(double3 v) SIMD_NOEXCEPT :
    ::simd_double3x3((simd_double3x3){(double3){v.x,0,0}, (double3){0,v.y,0}, (double3){0,0,v.z}}) { }
    SIMD_CONSTEXPR double3x3(double3 c0, double3 c1, double3 c2) SIMD_NOEXCEPT :
    ::simd_double3x3((simd_double3x3){c0, c1, c2}) { }
    SIMD_CONSTEXPR double3x3(::simd_double3x3 m) SIMD_NOEXCEPT : ::simd_double3x3(m) { }
#if defined SIMD_MATRIX_HEADER
    SIMD_CONSTEXPR double3x3(::simd_quatd q) SIMD_NOEXCEPT : ::simd_double3x3(::simd_matrix3x3(q)) { }
#endif
  };
  
  struct double4x3 : ::simd_double4x3 {
    SIMD_CONSTEXPR double4x3() SIMD_NOEXCEPT : ::simd_double4x3((simd_double4x3){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR double4x3(double diagonal) SIMD_NOEXCEPT : double4x3((double3)diagonal) { }
#endif
    SIMD_CONSTEXPR double4x3(double3 v) SIMD_NOEXCEPT :
    ::simd_double4x3((simd_double4x3){(double3){v.x,0,0}, (double3){0,v.y,0}, (double3){0,0,v.z}, (double3){0}}) { }
    SIMD_CONSTEXPR double4x3(double3 c0, double3 c1, double3 c2, double3 c3) SIMD_NOEXCEPT :
    ::simd_double4x3((simd_double4x3){c0, c1, c2, c3}) { }
    SIMD_CONSTEXPR double4x3(::simd_double4x3 m) SIMD_NOEXCEPT : ::simd_double4x3(m) { }
  };
  
  struct double2x4 : ::simd_double2x4 {
    SIMD_CONSTEXPR double2x4() SIMD_NOEXCEPT : ::simd_double2x4((simd_double2x4){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR double2x4(double diagonal) SIMD_NOEXCEPT : double2x4((double2)diagonal) { }
#endif
    SIMD_CONSTEXPR double2x4(double2 v) SIMD_NOEXCEPT :
    ::simd_double2x4((simd_double2x4){(double4){v.x,0,0,0}, (double4){0,v.y,0,0}}) { }
    SIMD_CONSTEXPR double2x4(double4 c0, double4 c1) SIMD_NOEXCEPT : ::simd_double2x4((simd_double2x4){c0, c1}) { }
    SIMD_CONSTEXPR double2x4(::simd_double2x4 m) SIMD_NOEXCEPT : ::simd_double2x4(m) { }
  };
  
  struct double3x4 : ::simd_double3x4 {
    SIMD_CONSTEXPR double3x4() SIMD_NOEXCEPT : ::simd_double3x4((simd_double3x4){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR double3x4(double diagonal) SIMD_NOEXCEPT : double3x4((double3)diagonal) { }
#endif
    SIMD_CONSTEXPR double3x4(double3 v) SIMD_NOEXCEPT :
    ::simd_double3x4((simd_double3x4){(double4){v.x,0,0,0}, (double4){0,v.y,0,0}, (double4){0,0,v.z,0}}) { }
    SIMD_CONSTEXPR double3x4(double4 c0, double4 c1, double4 c2) SIMD_NOEXCEPT :
    ::simd_double3x4((simd_double3x4){c0, c1, c2}) { }
    SIMD_CONSTEXPR double3x4(::simd_double3x4 m) SIMD_NOEXCEPT : ::simd_double3x4(m) { }
  };
  
  struct double4x4 : ::simd_double4x4 {
    SIMD_CONSTEXPR double4x4() SIMD_NOEXCEPT : ::simd_double4x4((simd_double4x4){0}) { }
#if __has_feature(cxx_delegating_constructors)
    SIMD_CONSTEXPR double4x4(double diagonal) SIMD_NOEXCEPT : double4x4((double4)diagonal) { }
#endif
    SIMD_CONSTEXPR double4x4(double4 v) SIMD_NOEXCEPT :
    ::simd_double4x4((simd_double4x4){(double4){v.x,0,0,0}, (double4){0,v.y,0,0}, (double4){0,0,v.z,0}, (double4){0,0,0,v.w}}) { }
    SIMD_CONSTEXPR double4x4(double4 c0, double4 c1, double4 c2, double4 c3) SIMD_NOEXCEPT :
    ::simd_double4x4((simd_double4x4){c0, c1, c2, c3}) { }
    SIMD_CONSTEXPR double4x4(::simd_double4x4 m) SIMD_NOEXCEPT : ::simd_double4x4(m) { }
#if defined SIMD_MATRIX_HEADER
    SIMD_CONSTEXPR double4x4(::simd_quatd q) SIMD_NOEXCEPT : ::simd_double4x4(::simd_matrix4x4(q)) { }
#endif
  };

/*! @abstract Templated Matrix struct based on scalar type and number of columns and rows.  */
template <typename ScalarType, size_t col, size_t row> struct Matrix {
    //  static const size_t col
    //  static const size_t row
    //  typedef scalar_t
    //  typedef type
};
/*! @abstract Helper type to access the simd type easily.                     */
template <typename ScalarType, size_t col, size_t row>
using Matrix_t = typename Matrix<ScalarType, col, row>::type;

template<> struct Matrix<float, 2, 2> {
    static const size_t col = 2;
    static const size_t row = 2;
    typedef float scalar_t;
    typedef float2x2 type;
};

template<> struct Matrix<float, 3, 2> {
    static const size_t col = 3;
    static const size_t row = 2;
    typedef float scalar_t;
    typedef float3x2 type;
};

template<> struct Matrix<float, 4, 2> {
    static const size_t col = 4;
    static const size_t row = 2;
    typedef float scalar_t;
    typedef float4x2 type;
};

template<> struct Matrix<float, 2, 3> {
    static const size_t col = 2;
    static const size_t row = 3;
    typedef float scalar_t;
    typedef float2x3 type;
};

template<> struct Matrix<float, 3, 3> {
    static const size_t col = 3;
    static const size_t row = 3;
    typedef float scalar_t;
    typedef float3x3 type;
};

template<> struct Matrix<float, 4, 3> {
    static const size_t col = 4;
    static const size_t row = 3;
    typedef float scalar_t;
    typedef float4x3 type;
};

template<> struct Matrix<float, 2, 4> {
    static const size_t col = 2;
    static const size_t row = 4;
    typedef float scalar_t;
    typedef float2x4 type;
};

template<> struct Matrix<float, 3, 4> {
    static const size_t col = 3;
    static const size_t row = 4;
    typedef float scalar_t;
    typedef float3x4 type;
};

template<> struct Matrix<float, 4, 4> {
    static const size_t col = 4;
    static const size_t row = 4;
    typedef float scalar_t;
    typedef float4x4 type;
};

template<> struct Matrix<double, 2, 2> {
    static const size_t col = 2;
    static const size_t row = 2;
    typedef double scalar_t;
    typedef double2x2 type;
};

template<> struct Matrix<double, 3, 2> {
    static const size_t col = 3;
    static const size_t row = 2;
    typedef double scalar_t;
    typedef double3x2 type;
};

template<> struct Matrix<double, 4, 2> {
    static const size_t col = 4;
    static const size_t row = 2;
    typedef double scalar_t;
    typedef double4x2 type;
};

template<> struct Matrix<double, 2, 3> {
    static const size_t col = 2;
    static const size_t row = 3;
    typedef double scalar_t;
    typedef double2x3 type;
};

template<> struct Matrix<double, 3, 3> {
    static const size_t col = 3;
    static const size_t row = 3;
    typedef double scalar_t;
    typedef double3x3 type;
};

template<> struct Matrix<double, 4, 3> {
    static const size_t col = 4;
    static const size_t row = 3;
    typedef double scalar_t;
    typedef double4x3 type;
};

template<> struct Matrix<double, 2, 4> {
    static const size_t col = 2;
    static const size_t row = 4;
    typedef double scalar_t;
    typedef double2x4 type;
};

template<> struct Matrix<double, 3, 4> {
    static const size_t col = 3;
    static const size_t row = 4;
    typedef double scalar_t;
    typedef double3x4 type;
};

template<> struct Matrix<double, 4, 4> {
    static const size_t col = 4;
    static const size_t row = 4;
    typedef double scalar_t;
    typedef double4x4 type;
};

template <> struct get_traits<float2x2>
{
    using type = Matrix<float, 2, 2>;
};

template <> struct get_traits<float3x2>
{
    using type = Matrix<float, 3, 2>;
};

template <> struct get_traits<float4x2>
{
    using type = Matrix<float, 4, 2>;
};

template <> struct get_traits<float2x3>
{
    using type = Matrix<float, 2, 3>;
};

template <> struct get_traits<float3x3>
{
    using type = Matrix<float, 3, 3>;
};

template <> struct get_traits<float4x3>
{
    using type = Matrix<float, 4, 3>;
};

template <> struct get_traits<float2x4>
{
    using type = Matrix<float, 2, 4>;
};

template <> struct get_traits<float3x4>
{
    using type = Matrix<float, 3, 4>;
};

template <> struct get_traits<float4x4>
{
    using type = Matrix<float, 4, 4>;
};

template <> struct get_traits<double2x2>
{
    using type = Matrix<double, 2, 2>;
};

template <> struct get_traits<double3x2>
{
    using type = Matrix<double, 3, 2>;
};

template <> struct get_traits<double4x2>
{
    using type = Matrix<double, 4, 2>;
};

template <> struct get_traits<double2x3>
{
    using type = Matrix<double, 2, 3>;
};

template <> struct get_traits<double3x3>
{
    using type = Matrix<double, 3, 3>;
};

template <> struct get_traits<double4x3>
{
    using type = Matrix<double, 4, 3>;
};

template <> struct get_traits<double2x4>
{
    using type = Matrix<double, 2, 4>;
};

template <> struct get_traits<double3x4>
{
    using type = Matrix<double, 3, 4>;
};

template <> struct get_traits<double4x4>
{
    using type = Matrix<double, 4, 4>;
};

}
#endif /* __cplusplus */
#endif /* SIMD_COMPILER_HAS_REQUIRED_FEATURES */
#endif /* SIMD_MATRIX_TYPES_HEADER */
