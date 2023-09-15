/* Copyright (c) 2014-2017 Apple, Inc. All rights reserved.
 *
 *      Function                        Result
 *      ------------------------------------------------------------------
 *
 *      simd_diagonal_matrix(x)         A square matrix with the vector x
 *                                      as its diagonal.
 *
 *      simd_matrix(c0, c1, ... )       A matrix with the specified vectors
 *                                      as columns.
 *
 *      simd_matrix_from_rows(r0, r1, ... )  A matrix with the specified vectors
 *                                      as rows.
 *
 *      simd_mul(a,x)                   Scalar product a*x.
 *
 *      simd_linear_combination(a,x,b,y)  a*x + b*y.
 *
 *      simd_add(x,y)                   Macro wrapping linear_combination
 *                                      to compute x + y.
 *
 *      simd_sub(x,y)                   Macro wrapping linear_combination
 *                                      to compute x - y.
 *
 *      simd_transpose(x)               Transpose of the matrix x.
 *
 *      simd_trace(x)                   Trace of the matrix x.
 *
 *      simd_determinant(x)             Determinant of the matrix x.
 *
 *      simd_inverse(x)                 Inverse of x if x is non-singular.  If
 *                                      x is singular, the result is undefined.
 *
 *      simd_mul(x,y)                   If x is a matrix, returns the matrix
 *                                      product x*y, where y is either a matrix
 *                                      or a column vector.  If x is a vector,
 *                                      returns the product x*y where x is
 *                                      interpreted as a row vector.
 *
 *      simd_equal(x,y)                 Returns true if and only if every
 *                                      element of x is exactly equal to the
 *                                      corresponding element of y.
 *
 *      simd_almost_equal_elements(x,y,tol)
 *                                      Returns true if and only if for each
 *                                      entry xij in x, the corresponding
 *                                      element yij in y satisfies
 *                                      |xij - yij| <= tol.
 *
 *      simd_almost_equal_elements_relative(x,y,tol)
 *                                      Returns true if and only if for each
 *                                      entry xij in x, the corresponding
 *                                      element yij in y satisfies
 *                                      |xij - yij| <= tol*|xij|.
 *
 *  The header also defines a few useful global matrix objects:
 *  matrix_identity_floatNxM and matrix_identity_doubleNxM, may be used to get
 *  an identity matrix of the specified size.
 *
 *  In C++, we are able to use namespacing to make the functions more concise;
 *  we also overload some common arithmetic operators to work with the matrix
 *  types:
 *
 *      C++ Function                    Equivalent C Function
 *      --------------------------------------------------------------------
 *      simd::inverse                   simd_inverse
 *      simd::transpose                 simd_transpose
 *      operator+                       simd_add
 *      operator-                       simd_sub
 *      operator+=                      N/A
 *      operator-=                      N/A
 *      operator*                       simd_mul or simd_mul
 *      operator*=                      simd_mul or simd_mul
 *      operator==                      simd_equal
 *      operator!=                      !simd_equal
 *      simd::almost_equal_elements     simd_almost_equal_elements
 *      simd::almost_equal_elements_relative  simd_almost_equal_elements_relative
 *
 *  <simd/matrix_types.h> provides constructors for C++ matrix types.
 */

#ifndef SIMD_MATRIX_HEADER
#define SIMD_MATRIX_HEADER

#include <simd/base.h>
#if SIMD_COMPILER_HAS_REQUIRED_FEATURES
#include <simd/matrix_types.h>
#include <simd/geometry.h>
#include <simd/extern.h>
#include <simd/logic.h>

#ifdef __cplusplus
    extern "C" {
#endif

extern const simd_float2x2 matrix_identity_float2x2  __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));
extern const simd_float3x3 matrix_identity_float3x3  __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));
extern const simd_float4x4 matrix_identity_float4x4  __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));
extern const simd_double2x2 matrix_identity_double2x2 __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));
extern const simd_double3x3 matrix_identity_double3x3 __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));
extern const simd_double4x4 matrix_identity_double4x4 __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));

static simd_float2x2 SIMD_CFUNC simd_diagonal_matrix(simd_float2 __x);
static simd_float3x3 SIMD_CFUNC simd_diagonal_matrix(simd_float3 __x);
static simd_float4x4 SIMD_CFUNC simd_diagonal_matrix(simd_float4 __x);
static simd_double2x2 SIMD_CFUNC simd_diagonal_matrix(simd_double2 __x);
static simd_double3x3 SIMD_CFUNC simd_diagonal_matrix(simd_double3 __x);
static simd_double4x4 SIMD_CFUNC simd_diagonal_matrix(simd_double4 __x);
#define matrix_from_diagonal simd_diagonal_matrix

static simd_float2x2 SIMD_CFUNC simd_matrix(simd_float2 col0, simd_float2 col1);
static simd_float3x2 SIMD_CFUNC simd_matrix(simd_float2 col0, simd_float2 col1, simd_float2 col2);
static simd_float4x2 SIMD_CFUNC simd_matrix(simd_float2 col0, simd_float2 col1, simd_float2 col2, simd_float2 col3);
static simd_float2x3 SIMD_CFUNC simd_matrix(simd_float3 col0, simd_float3 col1);
static simd_float3x3 SIMD_CFUNC simd_matrix(simd_float3 col0, simd_float3 col1, simd_float3 col2);
static simd_float4x3 SIMD_CFUNC simd_matrix(simd_float3 col0, simd_float3 col1, simd_float3 col2, simd_float3 col3);
static simd_float2x4 SIMD_CFUNC simd_matrix(simd_float4 col0, simd_float4 col1);
static simd_float3x4 SIMD_CFUNC simd_matrix(simd_float4 col0, simd_float4 col1, simd_float4 col2);
static simd_float4x4 SIMD_CFUNC simd_matrix(simd_float4 col0, simd_float4 col1, simd_float4 col2, simd_float4 col3);
static simd_double2x2 SIMD_CFUNC simd_matrix(simd_double2 col0, simd_double2 col1);
static simd_double3x2 SIMD_CFUNC simd_matrix(simd_double2 col0, simd_double2 col1, simd_double2 col2);
static simd_double4x2 SIMD_CFUNC simd_matrix(simd_double2 col0, simd_double2 col1, simd_double2 col2, simd_double2 col3);
static simd_double2x3 SIMD_CFUNC simd_matrix(simd_double3 col0, simd_double3 col1);
static simd_double3x3 SIMD_CFUNC simd_matrix(simd_double3 col0, simd_double3 col1, simd_double3 col2);
static simd_double4x3 SIMD_CFUNC simd_matrix(simd_double3 col0, simd_double3 col1, simd_double3 col2, simd_double3 col3);
static simd_double2x4 SIMD_CFUNC simd_matrix(simd_double4 col0, simd_double4 col1);
static simd_double3x4 SIMD_CFUNC simd_matrix(simd_double4 col0, simd_double4 col1, simd_double4 col2);
static simd_double4x4 SIMD_CFUNC simd_matrix(simd_double4 col0, simd_double4 col1, simd_double4 col2, simd_double4 col3);
#define matrix_from_columns simd_matrix

static simd_float2x2 SIMD_CFUNC simd_matrix_from_rows(simd_float2 row0, simd_float2 row1);
static simd_float2x3 SIMD_CFUNC simd_matrix_from_rows(simd_float2 row0, simd_float2 row1, simd_float2 row2);
static simd_float2x4 SIMD_CFUNC simd_matrix_from_rows(simd_float2 row0, simd_float2 row1, simd_float2 row2, simd_float2 row3);
static simd_float3x2 SIMD_CFUNC simd_matrix_from_rows(simd_float3 row0, simd_float3 row1);
static simd_float3x3 SIMD_CFUNC simd_matrix_from_rows(simd_float3 row0, simd_float3 row1, simd_float3 row2);
static simd_float3x4 SIMD_CFUNC simd_matrix_from_rows(simd_float3 row0, simd_float3 row1, simd_float3 row2, simd_float3 row3);
static simd_float4x2 SIMD_CFUNC simd_matrix_from_rows(simd_float4 row0, simd_float4 row1);
static simd_float4x3 SIMD_CFUNC simd_matrix_from_rows(simd_float4 row0, simd_float4 row1, simd_float4 row2);
static simd_float4x4 SIMD_CFUNC simd_matrix_from_rows(simd_float4 row0, simd_float4 row1, simd_float4 row2, simd_float4 row3);
static simd_double2x2 SIMD_CFUNC simd_matrix_from_rows(simd_double2 row0, simd_double2 row1);
static simd_double2x3 SIMD_CFUNC simd_matrix_from_rows(simd_double2 row0, simd_double2 row1, simd_double2 row2);
static simd_double2x4 SIMD_CFUNC simd_matrix_from_rows(simd_double2 row0, simd_double2 row1, simd_double2 row2, simd_double2 row3);
static simd_double3x2 SIMD_CFUNC simd_matrix_from_rows(simd_double3 row0, simd_double3 row1);
static simd_double3x3 SIMD_CFUNC simd_matrix_from_rows(simd_double3 row0, simd_double3 row1, simd_double3 row2);
static simd_double3x4 SIMD_CFUNC simd_matrix_from_rows(simd_double3 row0, simd_double3 row1, simd_double3 row2, simd_double3 row3);
static simd_double4x2 SIMD_CFUNC simd_matrix_from_rows(simd_double4 row0, simd_double4 row1);
static simd_double4x3 SIMD_CFUNC simd_matrix_from_rows(simd_double4 row0, simd_double4 row1, simd_double4 row2);
static simd_double4x4 SIMD_CFUNC simd_matrix_from_rows(simd_double4 row0, simd_double4 row1, simd_double4 row2, simd_double4 row3);
#define matrix_from_rows simd_matrix_from_rows
        
static  simd_float3x3 SIMD_NOINLINE simd_matrix3x3(simd_quatf q);
static  simd_float4x4 SIMD_NOINLINE simd_matrix4x4(simd_quatf q);
static simd_double3x3 SIMD_NOINLINE simd_matrix3x3(simd_quatd q);
static simd_double4x4 SIMD_NOINLINE simd_matrix4x4(simd_quatd q);

static simd_float2x2 SIMD_CFUNC simd_mul(float __a, simd_float2x2 __x);
static simd_float3x2 SIMD_CFUNC simd_mul(float __a, simd_float3x2 __x);
static simd_float4x2 SIMD_CFUNC simd_mul(float __a, simd_float4x2 __x);
static simd_float2x3 SIMD_CFUNC simd_mul(float __a, simd_float2x3 __x);
static simd_float3x3 SIMD_CFUNC simd_mul(float __a, simd_float3x3 __x);
static simd_float4x3 SIMD_CFUNC simd_mul(float __a, simd_float4x3 __x);
static simd_float2x4 SIMD_CFUNC simd_mul(float __a, simd_float2x4 __x);
static simd_float3x4 SIMD_CFUNC simd_mul(float __a, simd_float3x4 __x);
static simd_float4x4 SIMD_CFUNC simd_mul(float __a, simd_float4x4 __x);
static simd_double2x2 SIMD_CFUNC simd_mul(double __a, simd_double2x2 __x);
static simd_double3x2 SIMD_CFUNC simd_mul(double __a, simd_double3x2 __x);
static simd_double4x2 SIMD_CFUNC simd_mul(double __a, simd_double4x2 __x);
static simd_double2x3 SIMD_CFUNC simd_mul(double __a, simd_double2x3 __x);
static simd_double3x3 SIMD_CFUNC simd_mul(double __a, simd_double3x3 __x);
static simd_double4x3 SIMD_CFUNC simd_mul(double __a, simd_double4x3 __x);
static simd_double2x4 SIMD_CFUNC simd_mul(double __a, simd_double2x4 __x);
static simd_double3x4 SIMD_CFUNC simd_mul(double __a, simd_double3x4 __x);
static simd_double4x4 SIMD_CFUNC simd_mul(double __a, simd_double4x4 __x);

static simd_float2x2 SIMD_CFUNC simd_linear_combination(float __a, simd_float2x2 __x, float __b, simd_float2x2 __y);
static simd_float3x2 SIMD_CFUNC simd_linear_combination(float __a, simd_float3x2 __x, float __b, simd_float3x2 __y);
static simd_float4x2 SIMD_CFUNC simd_linear_combination(float __a, simd_float4x2 __x, float __b, simd_float4x2 __y);
static simd_float2x3 SIMD_CFUNC simd_linear_combination(float __a, simd_float2x3 __x, float __b, simd_float2x3 __y);
static simd_float3x3 SIMD_CFUNC simd_linear_combination(float __a, simd_float3x3 __x, float __b, simd_float3x3 __y);
static simd_float4x3 SIMD_CFUNC simd_linear_combination(float __a, simd_float4x3 __x, float __b, simd_float4x3 __y);
static simd_float2x4 SIMD_CFUNC simd_linear_combination(float __a, simd_float2x4 __x, float __b, simd_float2x4 __y);
static simd_float3x4 SIMD_CFUNC simd_linear_combination(float __a, simd_float3x4 __x, float __b, simd_float3x4 __y);
static simd_float4x4 SIMD_CFUNC simd_linear_combination(float __a, simd_float4x4 __x, float __b, simd_float4x4 __y);
static simd_double2x2 SIMD_CFUNC simd_linear_combination(double __a, simd_double2x2 __x, double __b, simd_double2x2 __y);
static simd_double3x2 SIMD_CFUNC simd_linear_combination(double __a, simd_double3x2 __x, double __b, simd_double3x2 __y);
static simd_double4x2 SIMD_CFUNC simd_linear_combination(double __a, simd_double4x2 __x, double __b, simd_double4x2 __y);
static simd_double2x3 SIMD_CFUNC simd_linear_combination(double __a, simd_double2x3 __x, double __b, simd_double2x3 __y);
static simd_double3x3 SIMD_CFUNC simd_linear_combination(double __a, simd_double3x3 __x, double __b, simd_double3x3 __y);
static simd_double4x3 SIMD_CFUNC simd_linear_combination(double __a, simd_double4x3 __x, double __b, simd_double4x3 __y);
static simd_double2x4 SIMD_CFUNC simd_linear_combination(double __a, simd_double2x4 __x, double __b, simd_double2x4 __y);
static simd_double3x4 SIMD_CFUNC simd_linear_combination(double __a, simd_double3x4 __x, double __b, simd_double3x4 __y);
static simd_double4x4 SIMD_CFUNC simd_linear_combination(double __a, simd_double4x4 __x, double __b, simd_double4x4 __y);
#define matrix_linear_combination simd_linear_combination
      
static simd_float2x2 SIMD_CFUNC simd_add(simd_float2x2 __x, simd_float2x2 __y);
static simd_float3x2 SIMD_CFUNC simd_add(simd_float3x2 __x, simd_float3x2 __y);
static simd_float4x2 SIMD_CFUNC simd_add(simd_float4x2 __x, simd_float4x2 __y);
static simd_float2x3 SIMD_CFUNC simd_add(simd_float2x3 __x, simd_float2x3 __y);
static simd_float3x3 SIMD_CFUNC simd_add(simd_float3x3 __x, simd_float3x3 __y);
static simd_float4x3 SIMD_CFUNC simd_add(simd_float4x3 __x, simd_float4x3 __y);
static simd_float2x4 SIMD_CFUNC simd_add(simd_float2x4 __x, simd_float2x4 __y);
static simd_float3x4 SIMD_CFUNC simd_add(simd_float3x4 __x, simd_float3x4 __y);
static simd_float4x4 SIMD_CFUNC simd_add(simd_float4x4 __x, simd_float4x4 __y);
static simd_double2x2 SIMD_CFUNC simd_add(simd_double2x2 __x, simd_double2x2 __y);
static simd_double3x2 SIMD_CFUNC simd_add(simd_double3x2 __x, simd_double3x2 __y);
static simd_double4x2 SIMD_CFUNC simd_add(simd_double4x2 __x, simd_double4x2 __y);
static simd_double2x3 SIMD_CFUNC simd_add(simd_double2x3 __x, simd_double2x3 __y);
static simd_double3x3 SIMD_CFUNC simd_add(simd_double3x3 __x, simd_double3x3 __y);
static simd_double4x3 SIMD_CFUNC simd_add(simd_double4x3 __x, simd_double4x3 __y);
static simd_double2x4 SIMD_CFUNC simd_add(simd_double2x4 __x, simd_double2x4 __y);
static simd_double3x4 SIMD_CFUNC simd_add(simd_double3x4 __x, simd_double3x4 __y);
static simd_double4x4 SIMD_CFUNC simd_add(simd_double4x4 __x, simd_double4x4 __y);
#define matrix_add simd_add
      
static simd_float2x2 SIMD_CFUNC simd_sub(simd_float2x2 __x, simd_float2x2 __y);
static simd_float3x2 SIMD_CFUNC simd_sub(simd_float3x2 __x, simd_float3x2 __y);
static simd_float4x2 SIMD_CFUNC simd_sub(simd_float4x2 __x, simd_float4x2 __y);
static simd_float2x3 SIMD_CFUNC simd_sub(simd_float2x3 __x, simd_float2x3 __y);
static simd_float3x3 SIMD_CFUNC simd_sub(simd_float3x3 __x, simd_float3x3 __y);
static simd_float4x3 SIMD_CFUNC simd_sub(simd_float4x3 __x, simd_float4x3 __y);
static simd_float2x4 SIMD_CFUNC simd_sub(simd_float2x4 __x, simd_float2x4 __y);
static simd_float3x4 SIMD_CFUNC simd_sub(simd_float3x4 __x, simd_float3x4 __y);
static simd_float4x4 SIMD_CFUNC simd_sub(simd_float4x4 __x, simd_float4x4 __y);
static simd_double2x2 SIMD_CFUNC simd_sub(simd_double2x2 __x, simd_double2x2 __y);
static simd_double3x2 SIMD_CFUNC simd_sub(simd_double3x2 __x, simd_double3x2 __y);
static simd_double4x2 SIMD_CFUNC simd_sub(simd_double4x2 __x, simd_double4x2 __y);
static simd_double2x3 SIMD_CFUNC simd_sub(simd_double2x3 __x, simd_double2x3 __y);
static simd_double3x3 SIMD_CFUNC simd_sub(simd_double3x3 __x, simd_double3x3 __y);
static simd_double4x3 SIMD_CFUNC simd_sub(simd_double4x3 __x, simd_double4x3 __y);
static simd_double2x4 SIMD_CFUNC simd_sub(simd_double2x4 __x, simd_double2x4 __y);
static simd_double3x4 SIMD_CFUNC simd_sub(simd_double3x4 __x, simd_double3x4 __y);
static simd_double4x4 SIMD_CFUNC simd_sub(simd_double4x4 __x, simd_double4x4 __y);
#define matrix_sub simd_sub

static simd_float2x2 SIMD_CFUNC simd_transpose(simd_float2x2 __x);
static simd_float2x3 SIMD_CFUNC simd_transpose(simd_float3x2 __x);
static simd_float2x4 SIMD_CFUNC simd_transpose(simd_float4x2 __x);
static simd_float3x2 SIMD_CFUNC simd_transpose(simd_float2x3 __x);
static simd_float3x3 SIMD_CFUNC simd_transpose(simd_float3x3 __x);
static simd_float3x4 SIMD_CFUNC simd_transpose(simd_float4x3 __x);
static simd_float4x2 SIMD_CFUNC simd_transpose(simd_float2x4 __x);
static simd_float4x3 SIMD_CFUNC simd_transpose(simd_float3x4 __x);
static simd_float4x4 SIMD_CFUNC simd_transpose(simd_float4x4 __x);
static simd_double2x2 SIMD_CFUNC simd_transpose(simd_double2x2 __x);
static simd_double2x3 SIMD_CFUNC simd_transpose(simd_double3x2 __x);
static simd_double2x4 SIMD_CFUNC simd_transpose(simd_double4x2 __x);
static simd_double3x2 SIMD_CFUNC simd_transpose(simd_double2x3 __x);
static simd_double3x3 SIMD_CFUNC simd_transpose(simd_double3x3 __x);
static simd_double3x4 SIMD_CFUNC simd_transpose(simd_double4x3 __x);
static simd_double4x2 SIMD_CFUNC simd_transpose(simd_double2x4 __x);
static simd_double4x3 SIMD_CFUNC simd_transpose(simd_double3x4 __x);
static simd_double4x4 SIMD_CFUNC simd_transpose(simd_double4x4 __x);
#define matrix_transpose simd_transpose

static float SIMD_CFUNC simd_trace(simd_float2x2 __x);
static float SIMD_CFUNC simd_trace(simd_float3x3 __x);
static float SIMD_CFUNC simd_trace(simd_float4x4 __x);
static double SIMD_CFUNC simd_trace(simd_double2x2 __x);
static double SIMD_CFUNC simd_trace(simd_double3x3 __x);
static double SIMD_CFUNC simd_trace(simd_double4x4 __x);
#define matrix_trace simd_trace

static float SIMD_CFUNC simd_determinant(simd_float2x2 __x);
static float SIMD_CFUNC simd_determinant(simd_float3x3 __x);
static float SIMD_CFUNC simd_determinant(simd_float4x4 __x);
static double SIMD_CFUNC simd_determinant(simd_double2x2 __x);
static double SIMD_CFUNC simd_determinant(simd_double3x3 __x);
static double SIMD_CFUNC simd_determinant(simd_double4x4 __x);
#define matrix_determinant simd_determinant

static simd_float2x2 SIMD_CFUNC simd_inverse(simd_float2x2 __x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));
static simd_float3x3 SIMD_CFUNC simd_inverse(simd_float3x3 __x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));
static simd_float4x4 SIMD_CFUNC simd_inverse(simd_float4x4 __x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));
static simd_double2x2 SIMD_CFUNC simd_inverse(simd_double2x2 __x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));
static simd_double3x3 SIMD_CFUNC simd_inverse(simd_double3x3 __x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));
static simd_double4x4 SIMD_CFUNC simd_inverse(simd_double4x4 __x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0));
#define matrix_invert simd_inverse

static simd_float2 SIMD_CFUNC simd_mul(simd_float2x2 __x, simd_float2 __y);
static simd_float2 SIMD_CFUNC simd_mul(simd_float3x2 __x, simd_float3 __y);
static simd_float2 SIMD_CFUNC simd_mul(simd_float4x2 __x, simd_float4 __y);
static simd_float3 SIMD_CFUNC simd_mul(simd_float2x3 __x, simd_float2 __y);
static simd_float3 SIMD_CFUNC simd_mul(simd_float3x3 __x, simd_float3 __y);
static simd_float3 SIMD_CFUNC simd_mul(simd_float4x3 __x, simd_float4 __y);
static simd_float4 SIMD_CFUNC simd_mul(simd_float2x4 __x, simd_float2 __y);
static simd_float4 SIMD_CFUNC simd_mul(simd_float3x4 __x, simd_float3 __y);
static simd_float4 SIMD_CFUNC simd_mul(simd_float4x4 __x, simd_float4 __y);
static simd_double2 SIMD_CFUNC simd_mul(simd_double2x2 __x, simd_double2 __y);
static simd_double2 SIMD_CFUNC simd_mul(simd_double3x2 __x, simd_double3 __y);
static simd_double2 SIMD_CFUNC simd_mul(simd_double4x2 __x, simd_double4 __y);
static simd_double3 SIMD_CFUNC simd_mul(simd_double2x3 __x, simd_double2 __y);
static simd_double3 SIMD_CFUNC simd_mul(simd_double3x3 __x, simd_double3 __y);
static simd_double3 SIMD_CFUNC simd_mul(simd_double4x3 __x, simd_double4 __y);
static simd_double4 SIMD_CFUNC simd_mul(simd_double2x4 __x, simd_double2 __y);
static simd_double4 SIMD_CFUNC simd_mul(simd_double3x4 __x, simd_double3 __y);
static simd_double4 SIMD_CFUNC simd_mul(simd_double4x4 __x, simd_double4 __y);
static simd_float2 SIMD_CFUNC simd_mul(simd_float2 __x, simd_float2x2 __y);
static simd_float3 SIMD_CFUNC simd_mul(simd_float2 __x, simd_float3x2 __y);
static simd_float4 SIMD_CFUNC simd_mul(simd_float2 __x, simd_float4x2 __y);
static simd_float2 SIMD_CFUNC simd_mul(simd_float3 __x, simd_float2x3 __y);
static simd_float3 SIMD_CFUNC simd_mul(simd_float3 __x, simd_float3x3 __y);
static simd_float4 SIMD_CFUNC simd_mul(simd_float3 __x, simd_float4x3 __y);
static simd_float2 SIMD_CFUNC simd_mul(simd_float4 __x, simd_float2x4 __y);
static simd_float3 SIMD_CFUNC simd_mul(simd_float4 __x, simd_float3x4 __y);
static simd_float4 SIMD_CFUNC simd_mul(simd_float4 __x, simd_float4x4 __y);
static simd_double2 SIMD_CFUNC simd_mul(simd_double2 __x, simd_double2x2 __y);
static simd_double3 SIMD_CFUNC simd_mul(simd_double2 __x, simd_double3x2 __y);
static simd_double4 SIMD_CFUNC simd_mul(simd_double2 __x, simd_double4x2 __y);
static simd_double2 SIMD_CFUNC simd_mul(simd_double3 __x, simd_double2x3 __y);
static simd_double3 SIMD_CFUNC simd_mul(simd_double3 __x, simd_double3x3 __y);
static simd_double4 SIMD_CFUNC simd_mul(simd_double3 __x, simd_double4x3 __y);
static simd_double2 SIMD_CFUNC simd_mul(simd_double4 __x, simd_double2x4 __y);
static simd_double3 SIMD_CFUNC simd_mul(simd_double4 __x, simd_double3x4 __y);
static simd_double4 SIMD_CFUNC simd_mul(simd_double4 __x, simd_double4x4 __y);
static simd_float2x2 SIMD_CFUNC simd_mul(simd_float2x2 __x, simd_float2x2 __y);
static simd_float3x2 SIMD_CFUNC simd_mul(simd_float2x2 __x, simd_float3x2 __y);
static simd_float4x2 SIMD_CFUNC simd_mul(simd_float2x2 __x, simd_float4x2 __y);
static simd_float2x3 SIMD_CFUNC simd_mul(simd_float2x3 __x, simd_float2x2 __y);
static simd_float3x3 SIMD_CFUNC simd_mul(simd_float2x3 __x, simd_float3x2 __y);
static simd_float4x3 SIMD_CFUNC simd_mul(simd_float2x3 __x, simd_float4x2 __y);
static simd_float2x4 SIMD_CFUNC simd_mul(simd_float2x4 __x, simd_float2x2 __y);
static simd_float3x4 SIMD_CFUNC simd_mul(simd_float2x4 __x, simd_float3x2 __y);
static simd_float4x4 SIMD_CFUNC simd_mul(simd_float2x4 __x, simd_float4x2 __y);
static simd_double2x2 SIMD_CFUNC simd_mul(simd_double2x2 __x, simd_double2x2 __y);
static simd_double3x2 SIMD_CFUNC simd_mul(simd_double2x2 __x, simd_double3x2 __y);
static simd_double4x2 SIMD_CFUNC simd_mul(simd_double2x2 __x, simd_double4x2 __y);
static simd_double2x3 SIMD_CFUNC simd_mul(simd_double2x3 __x, simd_double2x2 __y);
static simd_double3x3 SIMD_CFUNC simd_mul(simd_double2x3 __x, simd_double3x2 __y);
static simd_double4x3 SIMD_CFUNC simd_mul(simd_double2x3 __x, simd_double4x2 __y);
static simd_double2x4 SIMD_CFUNC simd_mul(simd_double2x4 __x, simd_double2x2 __y);
static simd_double3x4 SIMD_CFUNC simd_mul(simd_double2x4 __x, simd_double3x2 __y);
static simd_double4x4 SIMD_CFUNC simd_mul(simd_double2x4 __x, simd_double4x2 __y);
static simd_float2x2 SIMD_CFUNC simd_mul(simd_float3x2 __x, simd_float2x3 __y);
static simd_float3x2 SIMD_CFUNC simd_mul(simd_float3x2 __x, simd_float3x3 __y);
static simd_float4x2 SIMD_CFUNC simd_mul(simd_float3x2 __x, simd_float4x3 __y);
static simd_float2x3 SIMD_CFUNC simd_mul(simd_float3x3 __x, simd_float2x3 __y);
static simd_float3x3 SIMD_CFUNC simd_mul(simd_float3x3 __x, simd_float3x3 __y);
static simd_float4x3 SIMD_CFUNC simd_mul(simd_float3x3 __x, simd_float4x3 __y);
static simd_float2x4 SIMD_CFUNC simd_mul(simd_float3x4 __x, simd_float2x3 __y);
static simd_float3x4 SIMD_CFUNC simd_mul(simd_float3x4 __x, simd_float3x3 __y);
static simd_float4x4 SIMD_CFUNC simd_mul(simd_float3x4 __x, simd_float4x3 __y);
static simd_double2x2 SIMD_CFUNC simd_mul(simd_double3x2 __x, simd_double2x3 __y);
static simd_double3x2 SIMD_CFUNC simd_mul(simd_double3x2 __x, simd_double3x3 __y);
static simd_double4x2 SIMD_CFUNC simd_mul(simd_double3x2 __x, simd_double4x3 __y);
static simd_double2x3 SIMD_CFUNC simd_mul(simd_double3x3 __x, simd_double2x3 __y);
static simd_double3x3 SIMD_CFUNC simd_mul(simd_double3x3 __x, simd_double3x3 __y);
static simd_double4x3 SIMD_CFUNC simd_mul(simd_double3x3 __x, simd_double4x3 __y);
static simd_double2x4 SIMD_CFUNC simd_mul(simd_double3x4 __x, simd_double2x3 __y);
static simd_double3x4 SIMD_CFUNC simd_mul(simd_double3x4 __x, simd_double3x3 __y);
static simd_double4x4 SIMD_CFUNC simd_mul(simd_double3x4 __x, simd_double4x3 __y);
static simd_float2x2 SIMD_CFUNC simd_mul(simd_float4x2 __x, simd_float2x4 __y);
static simd_float3x2 SIMD_CFUNC simd_mul(simd_float4x2 __x, simd_float3x4 __y);
static simd_float4x2 SIMD_CFUNC simd_mul(simd_float4x2 __x, simd_float4x4 __y);
static simd_float2x3 SIMD_CFUNC simd_mul(simd_float4x3 __x, simd_float2x4 __y);
static simd_float3x3 SIMD_CFUNC simd_mul(simd_float4x3 __x, simd_float3x4 __y);
static simd_float4x3 SIMD_CFUNC simd_mul(simd_float4x3 __x, simd_float4x4 __y);
static simd_float2x4 SIMD_CFUNC simd_mul(simd_float4x4 __x, simd_float2x4 __y);
static simd_float3x4 SIMD_CFUNC simd_mul(simd_float4x4 __x, simd_float3x4 __y);
static simd_float4x4 SIMD_CFUNC simd_mul(simd_float4x4 __x, simd_float4x4 __y);
static simd_double2x2 SIMD_CFUNC simd_mul(simd_double4x2 __x, simd_double2x4 __y);
static simd_double3x2 SIMD_CFUNC simd_mul(simd_double4x2 __x, simd_double3x4 __y);
static simd_double4x2 SIMD_CFUNC simd_mul(simd_double4x2 __x, simd_double4x4 __y);
static simd_double2x3 SIMD_CFUNC simd_mul(simd_double4x3 __x, simd_double2x4 __y);
static simd_double3x3 SIMD_CFUNC simd_mul(simd_double4x3 __x, simd_double3x4 __y);
static simd_double4x3 SIMD_CFUNC simd_mul(simd_double4x3 __x, simd_double4x4 __y);
static simd_double2x4 SIMD_CFUNC simd_mul(simd_double4x4 __x, simd_double2x4 __y);
static simd_double3x4 SIMD_CFUNC simd_mul(simd_double4x4 __x, simd_double3x4 __y);
static simd_double4x4 SIMD_CFUNC simd_mul(simd_double4x4 __x, simd_double4x4 __y);
    
static simd_bool SIMD_CFUNC simd_equal(simd_float2x2 __x, simd_float2x2 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_float2x3 __x, simd_float2x3 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_float2x4 __x, simd_float2x4 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_float3x2 __x, simd_float3x2 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_float3x3 __x, simd_float3x3 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_float3x4 __x, simd_float3x4 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_float4x2 __x, simd_float4x2 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_float4x3 __x, simd_float4x3 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_float4x4 __x, simd_float4x4 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_double2x2 __x, simd_double2x2 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_double2x3 __x, simd_double2x3 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_double2x4 __x, simd_double2x4 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_double3x2 __x, simd_double3x2 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_double3x3 __x, simd_double3x3 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_double3x4 __x, simd_double3x4 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_double4x2 __x, simd_double4x2 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_double4x3 __x, simd_double4x3 __y);
static simd_bool SIMD_CFUNC simd_equal(simd_double4x4 __x, simd_double4x4 __y);
#define matrix_equal simd_equal
      
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float2x2 __x, simd_float2x2 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float2x3 __x, simd_float2x3 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float2x4 __x, simd_float2x4 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float3x2 __x, simd_float3x2 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float3x3 __x, simd_float3x3 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float3x4 __x, simd_float3x4 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float4x2 __x, simd_float4x2 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float4x3 __x, simd_float4x3 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float4x4 __x, simd_float4x4 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double2x2 __x, simd_double2x2 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double2x3 __x, simd_double2x3 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double2x4 __x, simd_double2x4 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double3x2 __x, simd_double3x2 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double3x3 __x, simd_double3x3 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double3x4 __x, simd_double3x4 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double4x2 __x, simd_double4x2 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double4x3 __x, simd_double4x3 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double4x4 __x, simd_double4x4 __y, double __tol);
#define matrix_almost_equal_elements simd_almost_equal_elements
      
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float2x2 __x, simd_float2x2 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float2x3 __x, simd_float2x3 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float2x4 __x, simd_float2x4 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float3x2 __x, simd_float3x2 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float3x3 __x, simd_float3x3 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float3x4 __x, simd_float3x4 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float4x2 __x, simd_float4x2 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float4x3 __x, simd_float4x3 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float4x4 __x, simd_float4x4 __y, float __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double2x2 __x, simd_double2x2 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double2x3 __x, simd_double2x3 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double2x4 __x, simd_double2x4 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double3x2 __x, simd_double3x2 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double3x3 __x, simd_double3x3 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double3x4 __x, simd_double3x4 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double4x2 __x, simd_double4x2 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double4x3 __x, simd_double4x3 __y, double __tol);
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double4x4 __x, simd_double4x4 __y, double __tol);
#define matrix_almost_equal_elements_relative simd_almost_equal_elements_relative

#ifdef __cplusplus
} /* extern "C" */

namespace simd {
  static SIMD_CPPFUNC float2x2 operator+(const float2x2 x, const float2x2 y) { return float2x2(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC float2x3 operator+(const float2x3 x, const float2x3 y) { return float2x3(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC float2x4 operator+(const float2x4 x, const float2x4 y) { return float2x4(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC float3x2 operator+(const float3x2 x, const float3x2 y) { return float3x2(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC float3x3 operator+(const float3x3 x, const float3x3 y) { return float3x3(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC float3x4 operator+(const float3x4 x, const float3x4 y) { return float3x4(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC float4x2 operator+(const float4x2 x, const float4x2 y) { return float4x2(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC float4x3 operator+(const float4x3 x, const float4x3 y) { return float4x3(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC float4x4 operator+(const float4x4 x, const float4x4 y) { return float4x4(::simd_linear_combination(1, x, 1, y)); }
  
  static SIMD_CPPFUNC float2x2 operator-(const float2x2 x, const float2x2 y) { return float2x2(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC float2x3 operator-(const float2x3 x, const float2x3 y) { return float2x3(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC float2x4 operator-(const float2x4 x, const float2x4 y) { return float2x4(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC float3x2 operator-(const float3x2 x, const float3x2 y) { return float3x2(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC float3x3 operator-(const float3x3 x, const float3x3 y) { return float3x3(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC float3x4 operator-(const float3x4 x, const float3x4 y) { return float3x4(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC float4x2 operator-(const float4x2 x, const float4x2 y) { return float4x2(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC float4x3 operator-(const float4x3 x, const float4x3 y) { return float4x3(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC float4x4 operator-(const float4x4 x, const float4x4 y) { return float4x4(::simd_linear_combination(1, x, -1, y)); }
  
  static SIMD_INLINE SIMD_NODEBUG float2x2& operator+=(float2x2& x, const float2x2 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float2x3& operator+=(float2x3& x, const float2x3 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float2x4& operator+=(float2x4& x, const float2x4 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x2& operator+=(float3x2& x, const float3x2 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x3& operator+=(float3x3& x, const float3x3 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x4& operator+=(float3x4& x, const float3x4 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x2& operator+=(float4x2& x, const float4x2 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x3& operator+=(float4x3& x, const float4x3 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x4& operator+=(float4x4& x, const float4x4 y) { x = x + y; return x; }
  
  static SIMD_INLINE SIMD_NODEBUG float2x2& operator-=(float2x2& x, const float2x2 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float2x3& operator-=(float2x3& x, const float2x3 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float2x4& operator-=(float2x4& x, const float2x4 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x2& operator-=(float3x2& x, const float3x2 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x3& operator-=(float3x3& x, const float3x3 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x4& operator-=(float3x4& x, const float3x4 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x2& operator-=(float4x2& x, const float4x2 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x3& operator-=(float4x3& x, const float4x3 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x4& operator-=(float4x4& x, const float4x4 y) { x = x - y; return x; }
  
  static SIMD_CPPFUNC float2x2 transpose(const float2x2 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC float2x3 transpose(const float3x2 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC float2x4 transpose(const float4x2 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC float3x2 transpose(const float2x3 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC float3x3 transpose(const float3x3 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC float3x4 transpose(const float4x3 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC float4x2 transpose(const float2x4 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC float4x3 transpose(const float3x4 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC float4x4 transpose(const float4x4 x) { return ::simd_transpose(x); }

  static SIMD_CPPFUNC float trace(const float2x2 x) { return ::simd_trace(x); }
  static SIMD_CPPFUNC float trace(const float3x3 x) { return ::simd_trace(x); }
  static SIMD_CPPFUNC float trace(const float4x4 x) { return ::simd_trace(x); }

  static SIMD_CPPFUNC float determinant(const float2x2 x) { return ::simd_determinant(x); }
  static SIMD_CPPFUNC float determinant(const float3x3 x) { return ::simd_determinant(x); }
  static SIMD_CPPFUNC float determinant(const float4x4 x) { return ::simd_determinant(x); }
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgcc-compat"
  static SIMD_CPPFUNC float2x2 inverse(const float2x2 x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0)) { return ::simd_inverse(x); }
  static SIMD_CPPFUNC float3x3 inverse(const float3x3 x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0)) { return ::simd_inverse(x); }
  static SIMD_CPPFUNC float4x4 inverse(const float4x4 x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0)) { return ::simd_inverse(x); }
#pragma clang diagnostic pop
  
  static SIMD_CPPFUNC float2x2 operator*(const float a, const float2x2 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float2x3 operator*(const float a, const float2x3 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float2x4 operator*(const float a, const float2x4 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float3x2 operator*(const float a, const float3x2 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float3x3 operator*(const float a, const float3x3 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float3x4 operator*(const float a, const float3x4 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float4x2 operator*(const float a, const float4x2 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float4x3 operator*(const float a, const float4x3 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float4x4 operator*(const float a, const float4x4 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float2x2 operator*(const float2x2 x, const float a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float2x3 operator*(const float2x3 x, const float a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float2x4 operator*(const float2x4 x, const float a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float3x2 operator*(const float3x2 x, const float a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float3x3 operator*(const float3x3 x, const float a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float3x4 operator*(const float3x4 x, const float a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float4x2 operator*(const float4x2 x, const float a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float4x3 operator*(const float4x3 x, const float a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC float4x4 operator*(const float4x4 x, const float a) { return ::simd_mul(a, x); }
  static SIMD_INLINE SIMD_NODEBUG float2x2& operator*=(float2x2& x, const float a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG float2x3& operator*=(float2x3& x, const float a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG float2x4& operator*=(float2x4& x, const float a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x2& operator*=(float3x2& x, const float a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x3& operator*=(float3x3& x, const float a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x4& operator*=(float3x4& x, const float a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x2& operator*=(float4x2& x, const float a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x3& operator*=(float4x3& x, const float a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x4& operator*=(float4x4& x, const float a) { x = ::simd_mul(a, x); return x; }
  
  static SIMD_CPPFUNC float2 operator*(const float2 x, const float2x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3 operator*(const float2 x, const float3x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4 operator*(const float2 x, const float4x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2 operator*(const float3 x, const float2x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3 operator*(const float3 x, const float3x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4 operator*(const float3 x, const float4x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2 operator*(const float4 x, const float2x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3 operator*(const float4 x, const float3x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4 operator*(const float4 x, const float4x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2 operator*(const float2x2 x, const float2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2 operator*(const float3x2 x, const float3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2 operator*(const float4x2 x, const float4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3 operator*(const float2x3 x, const float2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3 operator*(const float3x3 x, const float3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3 operator*(const float4x3 x, const float4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4 operator*(const float2x4 x, const float2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4 operator*(const float3x4 x, const float3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4 operator*(const float4x4 x, const float4 y) { return ::simd_mul(x, y); }
  static SIMD_INLINE SIMD_NODEBUG float2& operator*=(float2& x, const float2x2 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG float3& operator*=(float3& x, const float3x3 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG float4& operator*=(float4& x, const float4x4 y) { x = ::simd_mul(x, y); return x; }
  
  static SIMD_CPPFUNC float2x2 operator*(const float2x2 x, const float2x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3x2 operator*(const float2x2 x, const float3x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4x2 operator*(const float2x2 x, const float4x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2x3 operator*(const float2x3 x, const float2x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3x3 operator*(const float2x3 x, const float3x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4x3 operator*(const float2x3 x, const float4x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2x4 operator*(const float2x4 x, const float2x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3x4 operator*(const float2x4 x, const float3x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4x4 operator*(const float2x4 x, const float4x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2x2 operator*(const float3x2 x, const float2x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3x2 operator*(const float3x2 x, const float3x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4x2 operator*(const float3x2 x, const float4x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2x3 operator*(const float3x3 x, const float2x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3x3 operator*(const float3x3 x, const float3x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4x3 operator*(const float3x3 x, const float4x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2x4 operator*(const float3x4 x, const float2x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3x4 operator*(const float3x4 x, const float3x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4x4 operator*(const float3x4 x, const float4x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2x2 operator*(const float4x2 x, const float2x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3x2 operator*(const float4x2 x, const float3x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4x2 operator*(const float4x2 x, const float4x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2x3 operator*(const float4x3 x, const float2x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3x3 operator*(const float4x3 x, const float3x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4x3 operator*(const float4x3 x, const float4x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float2x4 operator*(const float4x4 x, const float2x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float3x4 operator*(const float4x4 x, const float3x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC float4x4 operator*(const float4x4 x, const float4x4 y) { return ::simd_mul(x, y); }
  static SIMD_INLINE SIMD_NODEBUG float2x2& operator*=(float2x2& x, const float2x2 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG float2x3& operator*=(float2x3& x, const float2x2 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG float2x4& operator*=(float2x4& x, const float2x2 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x2& operator*=(float3x2& x, const float3x3 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x3& operator*=(float3x3& x, const float3x3 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG float3x4& operator*=(float3x4& x, const float3x3 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x2& operator*=(float4x2& x, const float4x4 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x3& operator*=(float4x3& x, const float4x4 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG float4x4& operator*=(float4x4& x, const float4x4 y) { x = ::simd_mul(x, y); return x; }
  
  static SIMD_CPPFUNC bool operator==(const float2x2& x, const float2x2& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const float2x3& x, const float2x3& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const float2x4& x, const float2x4& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const float3x2& x, const float3x2& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const float3x3& x, const float3x3& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const float3x4& x, const float3x4& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const float4x2& x, const float4x2& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const float4x3& x, const float4x3& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const float4x4& x, const float4x4& y) { return ::simd_equal(x, y); }
  
  static SIMD_CPPFUNC bool operator!=(const float2x2& x, const float2x2& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const float2x3& x, const float2x3& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const float2x4& x, const float2x4& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const float3x2& x, const float3x2& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const float3x3& x, const float3x3& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const float3x4& x, const float3x4& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const float4x2& x, const float4x2& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const float4x3& x, const float4x3& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const float4x4& x, const float4x4& y) { return !(x == y); }
  
  static SIMD_CPPFUNC bool almost_equal_elements(const float2x2 x, const float2x2 y, const float tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const float2x3 x, const float2x3 y, const float tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const float2x4 x, const float2x4 y, const float tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const float3x2 x, const float3x2 y, const float tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const float3x3 x, const float3x3 y, const float tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const float3x4 x, const float3x4 y, const float tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const float4x2 x, const float4x2 y, const float tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const float4x3 x, const float4x3 y, const float tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const float4x4 x, const float4x4 y, const float tol) { return ::simd_almost_equal_elements(x, y, tol); }
    
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const float2x2 x, const float2x2 y, const float tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const float2x3 x, const float2x3 y, const float tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const float2x4 x, const float2x4 y, const float tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const float3x2 x, const float3x2 y, const float tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const float3x3 x, const float3x3 y, const float tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const float3x4 x, const float3x4 y, const float tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const float4x2 x, const float4x2 y, const float tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const float4x3 x, const float4x3 y, const float tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const float4x4 x, const float4x4 y, const float tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  
  static SIMD_CPPFUNC double2x2 operator+(const double2x2 x, const double2x2 y) { return double2x2(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC double2x3 operator+(const double2x3 x, const double2x3 y) { return double2x3(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC double2x4 operator+(const double2x4 x, const double2x4 y) { return double2x4(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC double3x2 operator+(const double3x2 x, const double3x2 y) { return double3x2(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC double3x3 operator+(const double3x3 x, const double3x3 y) { return double3x3(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC double3x4 operator+(const double3x4 x, const double3x4 y) { return double3x4(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC double4x2 operator+(const double4x2 x, const double4x2 y) { return double4x2(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC double4x3 operator+(const double4x3 x, const double4x3 y) { return double4x3(::simd_linear_combination(1, x, 1, y)); }
  static SIMD_CPPFUNC double4x4 operator+(const double4x4 x, const double4x4 y) { return double4x4(::simd_linear_combination(1, x, 1, y)); }
  
  static SIMD_CPPFUNC double2x2 operator-(const double2x2 x, const double2x2 y) { return double2x2(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC double2x3 operator-(const double2x3 x, const double2x3 y) { return double2x3(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC double2x4 operator-(const double2x4 x, const double2x4 y) { return double2x4(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC double3x2 operator-(const double3x2 x, const double3x2 y) { return double3x2(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC double3x3 operator-(const double3x3 x, const double3x3 y) { return double3x3(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC double3x4 operator-(const double3x4 x, const double3x4 y) { return double3x4(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC double4x2 operator-(const double4x2 x, const double4x2 y) { return double4x2(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC double4x3 operator-(const double4x3 x, const double4x3 y) { return double4x3(::simd_linear_combination(1, x, -1, y)); }
  static SIMD_CPPFUNC double4x4 operator-(const double4x4 x, const double4x4 y) { return double4x4(::simd_linear_combination(1, x, -1, y)); }
  
  static SIMD_INLINE SIMD_NODEBUG double2x2& operator+=(double2x2& x, const double2x2 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double2x3& operator+=(double2x3& x, const double2x3 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double2x4& operator+=(double2x4& x, const double2x4 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x2& operator+=(double3x2& x, const double3x2 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x3& operator+=(double3x3& x, const double3x3 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x4& operator+=(double3x4& x, const double3x4 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x2& operator+=(double4x2& x, const double4x2 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x3& operator+=(double4x3& x, const double4x3 y) { x = x + y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x4& operator+=(double4x4& x, const double4x4 y) { x = x + y; return x; }
  
  static SIMD_INLINE SIMD_NODEBUG double2x2& operator-=(double2x2& x, const double2x2 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double2x3& operator-=(double2x3& x, const double2x3 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double2x4& operator-=(double2x4& x, const double2x4 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x2& operator-=(double3x2& x, const double3x2 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x3& operator-=(double3x3& x, const double3x3 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x4& operator-=(double3x4& x, const double3x4 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x2& operator-=(double4x2& x, const double4x2 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x3& operator-=(double4x3& x, const double4x3 y) { x = x - y; return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x4& operator-=(double4x4& x, const double4x4 y) { x = x - y; return x; }
  
  static SIMD_CPPFUNC double2x2 transpose(const double2x2 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC double2x3 transpose(const double3x2 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC double2x4 transpose(const double4x2 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC double3x2 transpose(const double2x3 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC double3x3 transpose(const double3x3 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC double3x4 transpose(const double4x3 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC double4x2 transpose(const double2x4 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC double4x3 transpose(const double3x4 x) { return ::simd_transpose(x); }
  static SIMD_CPPFUNC double4x4 transpose(const double4x4 x) { return ::simd_transpose(x); }

  static SIMD_CPPFUNC double trace(const double2x2 x) { return ::simd_trace(x); }
  static SIMD_CPPFUNC double trace(const double3x3 x) { return ::simd_trace(x); }
  static SIMD_CPPFUNC double trace(const double4x4 x) { return ::simd_trace(x); }

  static SIMD_CPPFUNC double determinant(const double2x2 x) { return ::simd_determinant(x); }
  static SIMD_CPPFUNC double determinant(const double3x3 x) { return ::simd_determinant(x); }
  static SIMD_CPPFUNC double determinant(const double4x4 x) { return ::simd_determinant(x); }
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgcc-compat"
  static SIMD_CPPFUNC double2x2 inverse(const double2x2 x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0)) { return ::simd_inverse(x); }
  static SIMD_CPPFUNC double3x3 inverse(const double3x3 x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0)) { return ::simd_inverse(x); }
  static SIMD_CPPFUNC double4x4 inverse(const double4x4 x) __API_AVAILABLE(macos(10.10), ios(8.0), watchos(2.0), tvos(9.0)) { return ::simd_inverse(x); }
#pragma clang diagnostic pop
  
  static SIMD_CPPFUNC double2x2 operator*(const double a, const double2x2 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double2x3 operator*(const double a, const double2x3 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double2x4 operator*(const double a, const double2x4 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double3x2 operator*(const double a, const double3x2 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double3x3 operator*(const double a, const double3x3 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double3x4 operator*(const double a, const double3x4 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double4x2 operator*(const double a, const double4x2 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double4x3 operator*(const double a, const double4x3 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double4x4 operator*(const double a, const double4x4 x) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double2x2 operator*(const double2x2 x, const double a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double2x3 operator*(const double2x3 x, const double a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double2x4 operator*(const double2x4 x, const double a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double3x2 operator*(const double3x2 x, const double a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double3x3 operator*(const double3x3 x, const double a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double3x4 operator*(const double3x4 x, const double a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double4x2 operator*(const double4x2 x, const double a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double4x3 operator*(const double4x3 x, const double a) { return ::simd_mul(a, x); }
  static SIMD_CPPFUNC double4x4 operator*(const double4x4 x, const double a) { return ::simd_mul(a, x); }
  static SIMD_INLINE SIMD_NODEBUG double2x2& operator*=(double2x2& x, const double a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG double2x3& operator*=(double2x3& x, const double a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG double2x4& operator*=(double2x4& x, const double a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x2& operator*=(double3x2& x, const double a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x3& operator*=(double3x3& x, const double a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x4& operator*=(double3x4& x, const double a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x2& operator*=(double4x2& x, const double a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x3& operator*=(double4x3& x, const double a) { x = ::simd_mul(a, x); return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x4& operator*=(double4x4& x, const double a) { x = ::simd_mul(a, x); return x; }
  
  static SIMD_CPPFUNC double2 operator*(const double2 x, const double2x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3 operator*(const double2 x, const double3x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4 operator*(const double2 x, const double4x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2 operator*(const double3 x, const double2x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3 operator*(const double3 x, const double3x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4 operator*(const double3 x, const double4x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2 operator*(const double4 x, const double2x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3 operator*(const double4 x, const double3x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4 operator*(const double4 x, const double4x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2 operator*(const double2x2 x, const double2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2 operator*(const double3x2 x, const double3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2 operator*(const double4x2 x, const double4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3 operator*(const double2x3 x, const double2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3 operator*(const double3x3 x, const double3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3 operator*(const double4x3 x, const double4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4 operator*(const double2x4 x, const double2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4 operator*(const double3x4 x, const double3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4 operator*(const double4x4 x, const double4 y) { return ::simd_mul(x, y); }
  static SIMD_INLINE SIMD_NODEBUG double2& operator*=(double2& x, const double2x2 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG double3& operator*=(double3& x, const double3x3 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG double4& operator*=(double4& x, const double4x4 y) { x = ::simd_mul(x, y); return x; }
  
  static SIMD_CPPFUNC double2x2 operator*(const double2x2 x, const double2x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3x2 operator*(const double2x2 x, const double3x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4x2 operator*(const double2x2 x, const double4x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2x3 operator*(const double2x3 x, const double2x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3x3 operator*(const double2x3 x, const double3x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4x3 operator*(const double2x3 x, const double4x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2x4 operator*(const double2x4 x, const double2x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3x4 operator*(const double2x4 x, const double3x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4x4 operator*(const double2x4 x, const double4x2 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2x2 operator*(const double3x2 x, const double2x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3x2 operator*(const double3x2 x, const double3x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4x2 operator*(const double3x2 x, const double4x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2x3 operator*(const double3x3 x, const double2x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3x3 operator*(const double3x3 x, const double3x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4x3 operator*(const double3x3 x, const double4x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2x4 operator*(const double3x4 x, const double2x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3x4 operator*(const double3x4 x, const double3x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4x4 operator*(const double3x4 x, const double4x3 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2x2 operator*(const double4x2 x, const double2x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3x2 operator*(const double4x2 x, const double3x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4x2 operator*(const double4x2 x, const double4x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2x3 operator*(const double4x3 x, const double2x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3x3 operator*(const double4x3 x, const double3x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4x3 operator*(const double4x3 x, const double4x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double2x4 operator*(const double4x4 x, const double2x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double3x4 operator*(const double4x4 x, const double3x4 y) { return ::simd_mul(x, y); }
  static SIMD_CPPFUNC double4x4 operator*(const double4x4 x, const double4x4 y) { return ::simd_mul(x, y); }
  static SIMD_INLINE SIMD_NODEBUG double2x2& operator*=(double2x2& x, const double2x2 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG double2x3& operator*=(double2x3& x, const double2x2 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG double2x4& operator*=(double2x4& x, const double2x2 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x2& operator*=(double3x2& x, const double3x3 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x3& operator*=(double3x3& x, const double3x3 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG double3x4& operator*=(double3x4& x, const double3x3 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x2& operator*=(double4x2& x, const double4x4 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x3& operator*=(double4x3& x, const double4x4 y) { x = ::simd_mul(x, y); return x; }
  static SIMD_INLINE SIMD_NODEBUG double4x4& operator*=(double4x4& x, const double4x4 y) { x = ::simd_mul(x, y); return x; }
  
  static SIMD_CPPFUNC bool operator==(const double2x2& x, const double2x2& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const double2x3& x, const double2x3& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const double2x4& x, const double2x4& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const double3x2& x, const double3x2& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const double3x3& x, const double3x3& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const double3x4& x, const double3x4& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const double4x2& x, const double4x2& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const double4x3& x, const double4x3& y) { return ::simd_equal(x, y); }
  static SIMD_CPPFUNC bool operator==(const double4x4& x, const double4x4& y) { return ::simd_equal(x, y); }
  
  static SIMD_CPPFUNC bool operator!=(const double2x2& x, const double2x2& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const double2x3& x, const double2x3& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const double2x4& x, const double2x4& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const double3x2& x, const double3x2& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const double3x3& x, const double3x3& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const double3x4& x, const double3x4& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const double4x2& x, const double4x2& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const double4x3& x, const double4x3& y) { return !(x == y); }
  static SIMD_CPPFUNC bool operator!=(const double4x4& x, const double4x4& y) { return !(x == y); }
  
  static SIMD_CPPFUNC bool almost_equal_elements(const double2x2 x, const double2x2 y, const double tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const double2x3 x, const double2x3 y, const double tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const double2x4 x, const double2x4 y, const double tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const double3x2 x, const double3x2 y, const double tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const double3x3 x, const double3x3 y, const double tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const double3x4 x, const double3x4 y, const double tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const double4x2 x, const double4x2 y, const double tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const double4x3 x, const double4x3 y, const double tol) { return ::simd_almost_equal_elements(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements(const double4x4 x, const double4x4 y, const double tol) { return ::simd_almost_equal_elements(x, y, tol); }
  
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const double2x2 x, const double2x2 y, const double tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const double2x3 x, const double2x3 y, const double tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const double2x4 x, const double2x4 y, const double tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const double3x2 x, const double3x2 y, const double tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const double3x3 x, const double3x3 y, const double tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const double3x4 x, const double3x4 y, const double tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const double4x2 x, const double4x2 y, const double tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const double4x3 x, const double4x3 y, const double tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
  static SIMD_CPPFUNC bool almost_equal_elements_relative(const double4x4 x, const double4x4 y, const double tol) { return ::simd_almost_equal_elements_relative(x, y, tol); }
}

extern "C" {
#endif /* __cplusplus */

#pragma mark - Implementation

static  simd_float2x2 SIMD_CFUNC simd_diagonal_matrix(simd_float2  __x) {  simd_float2x2 __r = { .columns[0] = {__x.x,0}, .columns[1] = {0,__x.y} }; return __r; }
static simd_double2x2 SIMD_CFUNC simd_diagonal_matrix(simd_double2 __x) { simd_double2x2 __r = { .columns[0] = {__x.x,0}, .columns[1] = {0,__x.y} }; return __r; }
static  simd_float3x3 SIMD_CFUNC simd_diagonal_matrix(simd_float3  __x) {  simd_float3x3 __r = { .columns[0] = {__x.x,0,0}, .columns[1] = {0,__x.y,0}, .columns[2] = {0,0,__x.z} }; return __r; }
static simd_double3x3 SIMD_CFUNC simd_diagonal_matrix(simd_double3 __x) { simd_double3x3 __r = { .columns[0] = {__x.x,0,0}, .columns[1] = {0,__x.y,0}, .columns[2] = {0,0,__x.z} }; return __r; }
static  simd_float4x4 SIMD_CFUNC simd_diagonal_matrix(simd_float4  __x) {  simd_float4x4 __r = { .columns[0] = {__x.x,0,0,0}, .columns[1] = {0,__x.y,0,0}, .columns[2] = {0,0,__x.z,0}, .columns[3] = {0,0,0,__x.w} }; return __r; }
static simd_double4x4 SIMD_CFUNC simd_diagonal_matrix(simd_double4 __x) { simd_double4x4 __r = { .columns[0] = {__x.x,0,0,0}, .columns[1] = {0,__x.y,0,0}, .columns[2] = {0,0,__x.z,0}, .columns[3] = {0,0,0,__x.w} }; return __r; }

static  simd_float2x2 SIMD_CFUNC simd_matrix(simd_float2  col0, simd_float2  col1) {  simd_float2x2 __r = { .columns[0] = col0, .columns[1] = col1 }; return __r; }
static  simd_float2x3 SIMD_CFUNC simd_matrix(simd_float3  col0, simd_float3  col1) {  simd_float2x3 __r = { .columns[0] = col0, .columns[1] = col1 }; return __r; }
static  simd_float2x4 SIMD_CFUNC simd_matrix(simd_float4  col0, simd_float4  col1) {  simd_float2x4 __r = { .columns[0] = col0, .columns[1] = col1 }; return __r; }
static simd_double2x2 SIMD_CFUNC simd_matrix(simd_double2 col0, simd_double2 col1) { simd_double2x2 __r = { .columns[0] = col0, .columns[1] = col1 }; return __r; }
static simd_double2x3 SIMD_CFUNC simd_matrix(simd_double3 col0, simd_double3 col1) { simd_double2x3 __r = { .columns[0] = col0, .columns[1] = col1 }; return __r; }
static simd_double2x4 SIMD_CFUNC simd_matrix(simd_double4 col0, simd_double4 col1) { simd_double2x4 __r = { .columns[0] = col0, .columns[1] = col1 }; return __r; }
static  simd_float3x2 SIMD_CFUNC simd_matrix(simd_float2  col0, simd_float2  col1, simd_float2  col2) {  simd_float3x2 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2 }; return __r; }
static  simd_float3x3 SIMD_CFUNC simd_matrix(simd_float3  col0, simd_float3  col1, simd_float3  col2) {  simd_float3x3 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2 }; return __r; }
static  simd_float3x4 SIMD_CFUNC simd_matrix(simd_float4  col0, simd_float4  col1, simd_float4  col2) {  simd_float3x4 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2 }; return __r; }
static simd_double3x2 SIMD_CFUNC simd_matrix(simd_double2 col0, simd_double2 col1, simd_double2 col2) { simd_double3x2 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2 }; return __r; }
static simd_double3x3 SIMD_CFUNC simd_matrix(simd_double3 col0, simd_double3 col1, simd_double3 col2) { simd_double3x3 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2 }; return __r; }
static simd_double3x4 SIMD_CFUNC simd_matrix(simd_double4 col0, simd_double4 col1, simd_double4 col2) { simd_double3x4 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2 }; return __r; }
static  simd_float4x2 SIMD_CFUNC simd_matrix(simd_float2  col0, simd_float2  col1, simd_float2  col2, simd_float2  col3) {  simd_float4x2 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2, .columns[3] = col3 }; return __r; }
static  simd_float4x3 SIMD_CFUNC simd_matrix(simd_float3  col0, simd_float3  col1, simd_float3  col2, simd_float3  col3) {  simd_float4x3 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2, .columns[3] = col3 }; return __r; }
static  simd_float4x4 SIMD_CFUNC simd_matrix(simd_float4  col0, simd_float4  col1, simd_float4  col2, simd_float4  col3) {  simd_float4x4 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2, .columns[3] = col3 }; return __r; }
static simd_double4x2 SIMD_CFUNC simd_matrix(simd_double2 col0, simd_double2 col1, simd_double2 col2, simd_double2 col3) { simd_double4x2 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2, .columns[3] = col3 }; return __r; }
static simd_double4x3 SIMD_CFUNC simd_matrix(simd_double3 col0, simd_double3 col1, simd_double3 col2, simd_double3 col3) { simd_double4x3 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2, .columns[3] = col3 }; return __r; }
static simd_double4x4 SIMD_CFUNC simd_matrix(simd_double4 col0, simd_double4 col1, simd_double4 col2, simd_double4 col3) { simd_double4x4 __r = { .columns[0] = col0, .columns[1] = col1, .columns[2] = col2, .columns[3] = col3 }; return __r; }

static  simd_float2x2 SIMD_CFUNC simd_matrix_from_rows(simd_float2  row0, simd_float2  row1) { return simd_transpose(simd_matrix(row0, row1)); }
static  simd_float3x2 SIMD_CFUNC simd_matrix_from_rows(simd_float3  row0, simd_float3  row1) { return simd_transpose(simd_matrix(row0, row1)); }
static  simd_float4x2 SIMD_CFUNC simd_matrix_from_rows(simd_float4  row0, simd_float4  row1) { return simd_transpose(simd_matrix(row0, row1)); }
static simd_double2x2 SIMD_CFUNC simd_matrix_from_rows(simd_double2 row0, simd_double2 row1) { return simd_transpose(simd_matrix(row0, row1)); }
static simd_double3x2 SIMD_CFUNC simd_matrix_from_rows(simd_double3 row0, simd_double3 row1) { return simd_transpose(simd_matrix(row0, row1)); }
static simd_double4x2 SIMD_CFUNC simd_matrix_from_rows(simd_double4 row0, simd_double4 row1) { return simd_transpose(simd_matrix(row0, row1)); }
static  simd_float2x3 SIMD_CFUNC simd_matrix_from_rows(simd_float2  row0, simd_float2  row1, simd_float2  row2) { return simd_transpose(simd_matrix(row0, row1, row2)); }
static  simd_float3x3 SIMD_CFUNC simd_matrix_from_rows(simd_float3  row0, simd_float3  row1, simd_float3  row2) { return simd_transpose(simd_matrix(row0, row1, row2)); }
static  simd_float4x3 SIMD_CFUNC simd_matrix_from_rows(simd_float4  row0, simd_float4  row1, simd_float4  row2) { return simd_transpose(simd_matrix(row0, row1, row2)); }
static simd_double2x3 SIMD_CFUNC simd_matrix_from_rows(simd_double2 row0, simd_double2 row1, simd_double2 row2) { return simd_transpose(simd_matrix(row0, row1, row2)); }
static simd_double3x3 SIMD_CFUNC simd_matrix_from_rows(simd_double3 row0, simd_double3 row1, simd_double3 row2) { return simd_transpose(simd_matrix(row0, row1, row2)); }
static simd_double4x3 SIMD_CFUNC simd_matrix_from_rows(simd_double4 row0, simd_double4 row1, simd_double4 row2) { return simd_transpose(simd_matrix(row0, row1, row2)); }
static  simd_float2x4 SIMD_CFUNC simd_matrix_from_rows(simd_float2  row0, simd_float2  row1, simd_float2  row2, simd_float2  row3) { return simd_transpose(simd_matrix(row0, row1, row2, row3)); }
static  simd_float3x4 SIMD_CFUNC simd_matrix_from_rows(simd_float3  row0, simd_float3  row1, simd_float3  row2, simd_float3  row3) { return simd_transpose(simd_matrix(row0, row1, row2, row3)); }
static  simd_float4x4 SIMD_CFUNC simd_matrix_from_rows(simd_float4  row0, simd_float4  row1, simd_float4  row2, simd_float4  row3) { return simd_transpose(simd_matrix(row0, row1, row2, row3)); }
static simd_double2x4 SIMD_CFUNC simd_matrix_from_rows(simd_double2 row0, simd_double2 row1, simd_double2 row2, simd_double2 row3) { return simd_transpose(simd_matrix(row0, row1, row2, row3)); }
static simd_double3x4 SIMD_CFUNC simd_matrix_from_rows(simd_double3 row0, simd_double3 row1, simd_double3 row2, simd_double3 row3) { return simd_transpose(simd_matrix(row0, row1, row2, row3)); }
static simd_double4x4 SIMD_CFUNC simd_matrix_from_rows(simd_double4 row0, simd_double4 row1, simd_double4 row2, simd_double4 row3) { return simd_transpose(simd_matrix(row0, row1, row2, row3)); }
  
static  simd_float3x3 SIMD_NOINLINE simd_matrix3x3(simd_quatf q) {
  simd_float4x4 r = simd_matrix4x4(q);
  return (simd_float3x3){ r.columns[0].xyz, r.columns[1].xyz, r.columns[2].xyz };
}

static  simd_float4x4 SIMD_NOINLINE simd_matrix4x4(simd_quatf q) {
  simd_float4 v = q.vector;
  simd_float4x4 r = {
    .columns[0] = { v.x*v.x - v.y*v.y - v.z*v.z + v.w*v.w,
                        2*(v.x*v.y + v.z*v.w),
                        2*(v.x*v.z - v.y*v.w), 0 },
    .columns[1] = {     2*(v.x*v.y - v.z*v.w),
                    v.y*v.y - v.z*v.z + v.w*v.w - v.x*v.x,
                        2*(v.y*v.z + v.x*v.w), 0 },
    .columns[2] = {     2*(v.z*v.x + v.y*v.w),
                        2*(v.y*v.z - v.x*v.w),
                    v.z*v.z + v.w*v.w - v.x*v.x - v.y*v.y, 0 },
    .columns[3] = { 0, 0, 0, 1 }
  };
  return r;
}
  
static simd_double3x3 SIMD_NOINLINE simd_matrix3x3(simd_quatd q) {
  simd_double4x4 r = simd_matrix4x4(q);
  return (simd_double3x3){ r.columns[0].xyz, r.columns[1].xyz, r.columns[2].xyz };
}

static simd_double4x4 SIMD_NOINLINE simd_matrix4x4(simd_quatd q) {
  simd_double4 v = q.vector;
  simd_double4x4 r = {
    .columns[0] = { v.x*v.x - v.y*v.y - v.z*v.z + v.w*v.w,
                        2*(v.x*v.y + v.z*v.w),
                        2*(v.x*v.z - v.y*v.w), 0 },
    .columns[1] = {     2*(v.x*v.y - v.z*v.w),
                    v.y*v.y - v.z*v.z + v.w*v.w - v.x*v.x,
                        2*(v.y*v.z + v.x*v.w), 0 },
    .columns[2] = {     2*(v.z*v.x + v.y*v.w),
                        2*(v.y*v.z - v.x*v.w),
                    v.z*v.z + v.w*v.w - v.x*v.x - v.y*v.y, 0 },
    .columns[3] = { 0, 0, 0, 1 }
  };
  return r;
}

static  simd_float2x2 SIMD_CFUNC matrix_scale(float  __a,  simd_float2x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static  simd_float3x2 SIMD_CFUNC matrix_scale(float  __a,  simd_float3x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static  simd_float4x2 SIMD_CFUNC matrix_scale(float  __a,  simd_float4x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }
static  simd_float2x3 SIMD_CFUNC matrix_scale(float  __a,  simd_float2x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static  simd_float3x3 SIMD_CFUNC matrix_scale(float  __a,  simd_float3x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static  simd_float4x3 SIMD_CFUNC matrix_scale(float  __a,  simd_float4x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }
static  simd_float2x4 SIMD_CFUNC matrix_scale(float  __a,  simd_float2x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static  simd_float3x4 SIMD_CFUNC matrix_scale(float  __a,  simd_float3x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static  simd_float4x4 SIMD_CFUNC matrix_scale(float  __a,  simd_float4x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }
static simd_double2x2 SIMD_CFUNC matrix_scale(double __a, simd_double2x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static simd_double3x2 SIMD_CFUNC matrix_scale(double __a, simd_double3x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static simd_double4x2 SIMD_CFUNC matrix_scale(double __a, simd_double4x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }
static simd_double2x3 SIMD_CFUNC matrix_scale(double __a, simd_double2x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static simd_double3x3 SIMD_CFUNC matrix_scale(double __a, simd_double3x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static simd_double4x3 SIMD_CFUNC matrix_scale(double __a, simd_double4x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }
static simd_double2x4 SIMD_CFUNC matrix_scale(double __a, simd_double2x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static simd_double3x4 SIMD_CFUNC matrix_scale(double __a, simd_double3x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static simd_double4x4 SIMD_CFUNC matrix_scale(double __a, simd_double4x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }
  
static  simd_float2x2 SIMD_CFUNC simd_mul(float  __a,  simd_float2x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static  simd_float3x2 SIMD_CFUNC simd_mul(float  __a,  simd_float3x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static  simd_float4x2 SIMD_CFUNC simd_mul(float  __a,  simd_float4x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }
static  simd_float2x3 SIMD_CFUNC simd_mul(float  __a,  simd_float2x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static  simd_float3x3 SIMD_CFUNC simd_mul(float  __a,  simd_float3x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static  simd_float4x3 SIMD_CFUNC simd_mul(float  __a,  simd_float4x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }
static  simd_float2x4 SIMD_CFUNC simd_mul(float  __a,  simd_float2x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static  simd_float3x4 SIMD_CFUNC simd_mul(float  __a,  simd_float3x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static  simd_float4x4 SIMD_CFUNC simd_mul(float  __a,  simd_float4x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }
static simd_double2x2 SIMD_CFUNC simd_mul(double __a, simd_double2x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static simd_double3x2 SIMD_CFUNC simd_mul(double __a, simd_double3x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static simd_double4x2 SIMD_CFUNC simd_mul(double __a, simd_double4x2 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }
static simd_double2x3 SIMD_CFUNC simd_mul(double __a, simd_double2x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static simd_double3x3 SIMD_CFUNC simd_mul(double __a, simd_double3x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static simd_double4x3 SIMD_CFUNC simd_mul(double __a, simd_double4x3 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }
static simd_double2x4 SIMD_CFUNC simd_mul(double __a, simd_double2x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; return __x; }
static simd_double3x4 SIMD_CFUNC simd_mul(double __a, simd_double3x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; return __x; }
static simd_double4x4 SIMD_CFUNC simd_mul(double __a, simd_double4x4 __x) { __x.columns[0] *= __a; __x.columns[1] *= __a; __x.columns[2] *= __a; __x.columns[3] *= __a; return __x; }

static  simd_float2x2 SIMD_CFUNC simd_linear_combination(float  __a,  simd_float2x2 __x, float  __b,  simd_float2x2 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    return __x;
}
static  simd_float3x2 SIMD_CFUNC simd_linear_combination(float  __a,  simd_float3x2 __x, float  __b,  simd_float3x2 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    return __x;
}
static  simd_float4x2 SIMD_CFUNC simd_linear_combination(float  __a,  simd_float4x2 __x, float  __b,  simd_float4x2 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    __x.columns[3] = __a*__x.columns[3] + __b*__y.columns[3];
    return __x;
}
static  simd_float2x3 SIMD_CFUNC simd_linear_combination(float  __a,  simd_float2x3 __x, float  __b,  simd_float2x3 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    return __x;
}
static  simd_float3x3 SIMD_CFUNC simd_linear_combination(float  __a,  simd_float3x3 __x, float  __b,  simd_float3x3 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    return __x;
}
static  simd_float4x3 SIMD_CFUNC simd_linear_combination(float  __a,  simd_float4x3 __x, float  __b,  simd_float4x3 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    __x.columns[3] = __a*__x.columns[3] + __b*__y.columns[3];
    return __x;
}
static  simd_float2x4 SIMD_CFUNC simd_linear_combination(float  __a,  simd_float2x4 __x, float  __b,  simd_float2x4 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    return __x;
}
static  simd_float3x4 SIMD_CFUNC simd_linear_combination(float  __a,  simd_float3x4 __x, float  __b,  simd_float3x4 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    return __x;
}
static  simd_float4x4 SIMD_CFUNC simd_linear_combination(float  __a,  simd_float4x4 __x, float  __b,  simd_float4x4 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    __x.columns[3] = __a*__x.columns[3] + __b*__y.columns[3];
    return __x;
}
static simd_double2x2 SIMD_CFUNC simd_linear_combination(double __a, simd_double2x2 __x, double __b, simd_double2x2 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    return __x;
}
static simd_double3x2 SIMD_CFUNC simd_linear_combination(double __a, simd_double3x2 __x, double __b, simd_double3x2 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    return __x;
}
static simd_double4x2 SIMD_CFUNC simd_linear_combination(double __a, simd_double4x2 __x, double __b, simd_double4x2 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    __x.columns[3] = __a*__x.columns[3] + __b*__y.columns[3];
    return __x;
}
static simd_double2x3 SIMD_CFUNC simd_linear_combination(double __a, simd_double2x3 __x, double __b, simd_double2x3 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    return __x;
}
static simd_double3x3 SIMD_CFUNC simd_linear_combination(double __a, simd_double3x3 __x, double __b, simd_double3x3 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    return __x;
}
static simd_double4x3 SIMD_CFUNC simd_linear_combination(double __a, simd_double4x3 __x, double __b, simd_double4x3 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    __x.columns[3] = __a*__x.columns[3] + __b*__y.columns[3];
    return __x;
}
static simd_double2x4 SIMD_CFUNC simd_linear_combination(double __a, simd_double2x4 __x, double __b, simd_double2x4 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    return __x;
}
static simd_double3x4 SIMD_CFUNC simd_linear_combination(double __a, simd_double3x4 __x, double __b, simd_double3x4 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    return __x;
}
static simd_double4x4 SIMD_CFUNC simd_linear_combination(double __a, simd_double4x4 __x, double __b, simd_double4x4 __y) {
    __x.columns[0] = __a*__x.columns[0] + __b*__y.columns[0];
    __x.columns[1] = __a*__x.columns[1] + __b*__y.columns[1];
    __x.columns[2] = __a*__x.columns[2] + __b*__y.columns[2];
    __x.columns[3] = __a*__x.columns[3] + __b*__y.columns[3];
    return __x;
}
  
static simd_float2x2 SIMD_CFUNC simd_add(simd_float2x2 __x, simd_float2x2 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_float3x2 SIMD_CFUNC simd_add(simd_float3x2 __x, simd_float3x2 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_float4x2 SIMD_CFUNC simd_add(simd_float4x2 __x, simd_float4x2 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_float2x3 SIMD_CFUNC simd_add(simd_float2x3 __x, simd_float2x3 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_float3x3 SIMD_CFUNC simd_add(simd_float3x3 __x, simd_float3x3 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_float4x3 SIMD_CFUNC simd_add(simd_float4x3 __x, simd_float4x3 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_float2x4 SIMD_CFUNC simd_add(simd_float2x4 __x, simd_float2x4 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_float3x4 SIMD_CFUNC simd_add(simd_float3x4 __x, simd_float3x4 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_float4x4 SIMD_CFUNC simd_add(simd_float4x4 __x, simd_float4x4 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_double2x2 SIMD_CFUNC simd_add(simd_double2x2 __x, simd_double2x2 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_double3x2 SIMD_CFUNC simd_add(simd_double3x2 __x, simd_double3x2 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_double4x2 SIMD_CFUNC simd_add(simd_double4x2 __x, simd_double4x2 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_double2x3 SIMD_CFUNC simd_add(simd_double2x3 __x, simd_double2x3 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_double3x3 SIMD_CFUNC simd_add(simd_double3x3 __x, simd_double3x3 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_double4x3 SIMD_CFUNC simd_add(simd_double4x3 __x, simd_double4x3 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_double2x4 SIMD_CFUNC simd_add(simd_double2x4 __x, simd_double2x4 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_double3x4 SIMD_CFUNC simd_add(simd_double3x4 __x, simd_double3x4 __y) { return simd_linear_combination(1, __x, 1, __y); }
static simd_double4x4 SIMD_CFUNC simd_add(simd_double4x4 __x, simd_double4x4 __y) { return simd_linear_combination(1, __x, 1, __y); }
      
static simd_float2x2 SIMD_CFUNC simd_sub(simd_float2x2 __x, simd_float2x2 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_float3x2 SIMD_CFUNC simd_sub(simd_float3x2 __x, simd_float3x2 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_float4x2 SIMD_CFUNC simd_sub(simd_float4x2 __x, simd_float4x2 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_float2x3 SIMD_CFUNC simd_sub(simd_float2x3 __x, simd_float2x3 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_float3x3 SIMD_CFUNC simd_sub(simd_float3x3 __x, simd_float3x3 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_float4x3 SIMD_CFUNC simd_sub(simd_float4x3 __x, simd_float4x3 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_float2x4 SIMD_CFUNC simd_sub(simd_float2x4 __x, simd_float2x4 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_float3x4 SIMD_CFUNC simd_sub(simd_float3x4 __x, simd_float3x4 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_float4x4 SIMD_CFUNC simd_sub(simd_float4x4 __x, simd_float4x4 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_double2x2 SIMD_CFUNC simd_sub(simd_double2x2 __x, simd_double2x2 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_double3x2 SIMD_CFUNC simd_sub(simd_double3x2 __x, simd_double3x2 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_double4x2 SIMD_CFUNC simd_sub(simd_double4x2 __x, simd_double4x2 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_double2x3 SIMD_CFUNC simd_sub(simd_double2x3 __x, simd_double2x3 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_double3x3 SIMD_CFUNC simd_sub(simd_double3x3 __x, simd_double3x3 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_double4x3 SIMD_CFUNC simd_sub(simd_double4x3 __x, simd_double4x3 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_double2x4 SIMD_CFUNC simd_sub(simd_double2x4 __x, simd_double2x4 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_double3x4 SIMD_CFUNC simd_sub(simd_double3x4 __x, simd_double3x4 __y) { return simd_linear_combination(1, __x, -1, __y); }
static simd_double4x4 SIMD_CFUNC simd_sub(simd_double4x4 __x, simd_double4x4 __y) { return simd_linear_combination(1, __x, -1, __y); }

static simd_float2x2 SIMD_CFUNC simd_transpose(simd_float2x2 __x) {
    simd_float4 __x0, __x1;
    __x0.xy = __x.columns[0];
    __x1.xy = __x.columns[1];
#if defined __SSE__
    simd_float4 __r01 = _mm_unpacklo_ps(__x0, __x1);
#elif defined __ARM_NEON__
    simd_float4 __r01 = vzip1q_f32(__x0, __x1);
#else
    simd_float4 __r01 = { __x0[0], __x1[0], __x0[1], __x1[1] };
#endif
    return simd_matrix(__r01.lo, __r01.hi);
}
    
static simd_float3x2 SIMD_CFUNC simd_transpose(simd_float2x3 __x) {
    simd_float4 __x0, __x1;
    __x0.xyz = __x.columns[0];
    __x1.xyz = __x.columns[1];
#if defined __SSE__
    simd_float4 __r01 = _mm_unpacklo_ps(__x0, __x1);
    simd_float4 __r2x = _mm_unpackhi_ps(__x0, __x1);
#elif defined __ARM_NEON__
    simd_float4 __r01 = vzip1q_f32(__x0, __x1);
    simd_float4 __r2x = vzip2q_f32(__x0, __x1);
#else
    simd_float4 __r01 = { __x0[0], __x1[0], __x0[1], __x1[1] };
    simd_float4 __r2x = { __x0[2], __x1[2] };
#endif
    return simd_matrix(__r01.lo, __r01.hi, __r2x.lo);
}
    
static simd_float4x2 SIMD_CFUNC simd_transpose(simd_float2x4 __x) {
#if defined __SSE__
    simd_float4 __r01 = _mm_unpacklo_ps(__x.columns[0], __x.columns[1]);
    simd_float4 __r23 = _mm_unpackhi_ps(__x.columns[0], __x.columns[1]);
#elif defined __ARM_NEON__
    simd_float4 __r01 = vzip1q_f32(__x.columns[0], __x.columns[1]);
    simd_float4 __r23 = vzip2q_f32(__x.columns[0], __x.columns[1]);
#else
    simd_float4 __r01 = { __x.columns[0][0], __x.columns[1][0], __x.columns[0][1], __x.columns[1][1] };
    simd_float4 __r23 = { __x.columns[0][2], __x.columns[1][2], __x.columns[0][3], __x.columns[1][3] };
#endif
    return simd_matrix(__r01.lo, __r01.hi, __r23.lo, __r23.hi);
}
    
static simd_float2x3 SIMD_CFUNC simd_transpose(simd_float3x2 __x) {
    simd_float4 __x0, __x1, __x2;
    __x0.xy = __x.columns[0];
    __x1.xy = __x.columns[1];
    __x2.xy = __x.columns[2];
#if defined __SSE__
    simd_float4 __t = _mm_unpacklo_ps(__x0, __x1);
    simd_float4 __r0 = _mm_shuffle_ps(__t,__x2,0xc4);
    simd_float4 __r1 = _mm_shuffle_ps(__t,__x2,0xde);
#elif defined __ARM_NEON__
    simd_float4 padding = { 0 };
    simd_float4 __t0 = vzip1q_f32(__x0,__x2);
    simd_float4 __t1 = vzip1q_f32(__x1,padding);
    simd_float4 __r0 = vzip1q_f32(__t0,__t1);
    simd_float4 __r1 = vzip2q_f32(__t0,__t1);
#else
    simd_float4 __r0 = { __x0[0], __x1[0], __x2[0] };
    simd_float4 __r1 = { __x0[1], __x1[1], __x2[1] };
#endif
    return simd_matrix(__r0.xyz, __r1.xyz);
}
    
static simd_float3x3 SIMD_CFUNC simd_transpose(simd_float3x3 __x) {
    simd_float4 __x0, __x1, __x2;
    __x0.xyz = __x.columns[0];
    __x1.xyz = __x.columns[1];
    __x2.xyz = __x.columns[2];
#if defined __SSE__
    simd_float4 __t0 = _mm_unpacklo_ps(__x0, __x1);
    simd_float4 __t1 = _mm_unpackhi_ps(__x0, __x1);
    simd_float4 __r0 = __t0; __r0.hi = __x2.lo;
    simd_float4 __r1 = _mm_shuffle_ps(__t0, __x2, 0xde);
    simd_float4 __r2 = __x2; __r2.lo = __t1.lo;
#elif defined __ARM_NEON__
    simd_float4 padding = { 0 };
    simd_float4 __t0 = vzip1q_f32(__x0,__x2);
    simd_float4 __t1 = vzip2q_f32(__x0,__x2);
    simd_float4 __t2 = vzip1q_f32(__x1,padding);
    simd_float4 __t3 = vzip2q_f32(__x1,padding);
    simd_float4 __r0 = vzip1q_f32(__t0,__t2);
    simd_float4 __r1 = vzip2q_f32(__t0,__t2);
    simd_float4 __r2 = vzip1q_f32(__t1,__t3);
#else
    simd_float4 __r0 = {__x0[0], __x1[0], __x2[0]};
    simd_float4 __r1 = {__x0[1], __x1[1], __x2[1]};
    simd_float4 __r2 = {__x0[2], __x1[2], __x2[2]};
#endif
    return simd_matrix(__r0.xyz, __r1.xyz, __r2.xyz);
}
    
static simd_float4x3 SIMD_CFUNC simd_transpose(simd_float3x4 __x) {
#if defined __SSE__
    simd_float4 __t0 = _mm_unpacklo_ps(__x.columns[0],__x.columns[1]); /* 00 10 01 11 */
    simd_float4 __t1 = _mm_unpackhi_ps(__x.columns[0],__x.columns[1]); /* 02 12 03 13 */
    simd_float4 __r0 = __t0; __r0.hi = __x.columns[2].lo;
    simd_float4 __r1 = _mm_shuffle_ps(__t0, __x.columns[2], 0xde);
    simd_float4 __r2 = __x.columns[2]; __r2.lo = __t1.lo;
    simd_float4 __r3 = _mm_shuffle_ps(__t1, __x.columns[2], 0xfe);
#elif defined __ARM_NEON__
    simd_float4 padding = { 0 };
    simd_float4 __t0 = vzip1q_f32(__x.columns[0],__x.columns[2]);
    simd_float4 __t1 = vzip2q_f32(__x.columns[0],__x.columns[2]);
    simd_float4 __t2 = vzip1q_f32(__x.columns[1],padding);
    simd_float4 __t3 = vzip2q_f32(__x.columns[1],padding);
    simd_float4 __r0 = vzip1q_f32(__t0,__t2);
    simd_float4 __r1 = vzip2q_f32(__t0,__t2);
    simd_float4 __r2 = vzip1q_f32(__t1,__t3);
    simd_float4 __r3 = vzip2q_f32(__t1,__t3);
#else
    simd_float4 __r0 = {__x.columns[0][0], __x.columns[1][0], __x.columns[2][0]};
    simd_float4 __r1 = {__x.columns[0][1], __x.columns[1][1], __x.columns[2][1]};
    simd_float4 __r2 = {__x.columns[0][2], __x.columns[1][2], __x.columns[2][2]};
    simd_float4 __r3 = {__x.columns[0][3], __x.columns[1][3], __x.columns[2][3]};
#endif
    return simd_matrix(__r0.xyz, __r1.xyz, __r2.xyz, __r3.xyz);
}

static simd_float2x4 SIMD_CFUNC simd_transpose(simd_float4x2 __x) {
    simd_float4 __x0, __x1, __x2, __x3;
    __x0.xy = __x.columns[0];
    __x1.xy = __x.columns[1];
    __x2.xy = __x.columns[2];
    __x3.xy = __x.columns[3];
#if defined __SSE__
    simd_float4 __t0 = _mm_unpacklo_ps(__x0,__x2);
    simd_float4 __t1 = _mm_unpacklo_ps(__x1,__x3);
    simd_float4 __r0 = _mm_unpacklo_ps(__t0,__t1);
    simd_float4 __r1 = _mm_unpackhi_ps(__t0,__t1);
#elif defined __ARM_NEON__
    simd_float4 __t0 = vzip1q_f32(__x0,__x2);
    simd_float4 __t1 = vzip1q_f32(__x1,__x3);
    simd_float4 __r0 = vzip1q_f32(__t0,__t1);
    simd_float4 __r1 = vzip2q_f32(__t0,__t1);
#else
    simd_float4 __r0 = {__x.columns[0][0], __x.columns[1][0], __x.columns[2][0], __x.columns[3][0]};
    simd_float4 __r1 = {__x.columns[0][1], __x.columns[1][1], __x.columns[2][1], __x.columns[3][1]};
#endif
    return simd_matrix(__r0,__r1);
}

static simd_float3x4 SIMD_CFUNC simd_transpose(simd_float4x3 __x) {
    simd_float4 __x0, __x1, __x2, __x3;
    __x0.xyz = __x.columns[0];
    __x1.xyz = __x.columns[1];
    __x2.xyz = __x.columns[2];
    __x3.xyz = __x.columns[3];
#if defined __SSE__
    simd_float4 __t0 = _mm_unpacklo_ps(__x0,__x2);
    simd_float4 __t1 = _mm_unpackhi_ps(__x0,__x2);
    simd_float4 __t2 = _mm_unpacklo_ps(__x1,__x3);
    simd_float4 __t3 = _mm_unpackhi_ps(__x1,__x3);
    simd_float4 __r0 = _mm_unpacklo_ps(__t0,__t2);
    simd_float4 __r1 = _mm_unpackhi_ps(__t0,__t2);
    simd_float4 __r2 = _mm_unpacklo_ps(__t1,__t3);
#elif defined __ARM_NEON__
    simd_float4 __t0 = vzip1q_f32(__x0,__x2);
    simd_float4 __t1 = vzip2q_f32(__x0,__x2);
    simd_float4 __t2 = vzip1q_f32(__x1,__x3);
    simd_float4 __t3 = vzip2q_f32(__x1,__x3);
    simd_float4 __r0 = vzip1q_f32(__t0,__t2);
    simd_float4 __r1 = vzip2q_f32(__t0,__t2);
    simd_float4 __r2 = vzip1q_f32(__t1,__t3);
#else
    simd_float4 __r0 = {__x.columns[0][0], __x.columns[1][0], __x.columns[2][0], __x.columns[3][0]};
    simd_float4 __r1 = {__x.columns[0][1], __x.columns[1][1], __x.columns[2][1], __x.columns[3][1]};
    simd_float4 __r2 = {__x.columns[0][2], __x.columns[1][2], __x.columns[2][2], __x.columns[3][2]};
#endif
    return simd_matrix(__r0,__r1,__r2);
}

static simd_float4x4 SIMD_CFUNC simd_transpose(simd_float4x4 __x) {
#if defined __SSE__
    simd_float4 __t0 = _mm_unpacklo_ps(__x.columns[0],__x.columns[2]);
    simd_float4 __t1 = _mm_unpackhi_ps(__x.columns[0],__x.columns[2]);
    simd_float4 __t2 = _mm_unpacklo_ps(__x.columns[1],__x.columns[3]);
    simd_float4 __t3 = _mm_unpackhi_ps(__x.columns[1],__x.columns[3]);
    simd_float4 __r0 = _mm_unpacklo_ps(__t0,__t2);
    simd_float4 __r1 = _mm_unpackhi_ps(__t0,__t2);
    simd_float4 __r2 = _mm_unpacklo_ps(__t1,__t3);
    simd_float4 __r3 = _mm_unpackhi_ps(__t1,__t3);
#elif defined __ARM_NEON__
    simd_float4 __t0 = vzip1q_f32(__x.columns[0],__x.columns[2]);
    simd_float4 __t1 = vzip2q_f32(__x.columns[0],__x.columns[2]);
    simd_float4 __t2 = vzip1q_f32(__x.columns[1],__x.columns[3]);
    simd_float4 __t3 = vzip2q_f32(__x.columns[1],__x.columns[3]);
    simd_float4 __r0 = vzip1q_f32(__t0,__t2);
    simd_float4 __r1 = vzip2q_f32(__t0,__t2);
    simd_float4 __r2 = vzip1q_f32(__t1,__t3);
    simd_float4 __r3 = vzip2q_f32(__t1,__t3);
#else
    simd_float4 __r0 = {__x.columns[0][0], __x.columns[1][0], __x.columns[2][0], __x.columns[3][0]};
    simd_float4 __r1 = {__x.columns[0][1], __x.columns[1][1], __x.columns[2][1], __x.columns[3][1]};
    simd_float4 __r2 = {__x.columns[0][2], __x.columns[1][2], __x.columns[2][2], __x.columns[3][2]};
    simd_float4 __r3 = {__x.columns[0][3], __x.columns[1][3], __x.columns[2][3], __x.columns[3][3]};
#endif
    return simd_matrix(__r0,__r1,__r2,__r3);
}

static simd_double2x2 SIMD_CFUNC simd_transpose(simd_double2x2 __x) {
    simd_double2 __x0, __x1;
    __x0 = __x.columns[0];
    __x1 = __x.columns[1];
#if defined __ARM_NEON__
    simd_double2 __r0 = vzip1q_f64(__x0, __x1);
    simd_double2 __r1 = vzip2q_f64(__x0, __x1);
#else
    simd_double2 __r0 = { __x0[0], __x1[0] };
    simd_double2 __r1 = { __x0[1], __x1[1] };
#endif
    return simd_matrix(__r0, __r1);
}

static simd_double3x2 SIMD_CFUNC simd_transpose(simd_double2x3 __x) {
    simd_double4 __x0, __x1;
    __x0.xyz = __x.columns[0];
    __x1.xyz = __x.columns[1];
#if defined __ARM_NEON__
    simd_double2 __r0 = vzip1q_f64(__x0.lo,__x1.lo);
    simd_double2 __r1 = vzip2q_f64(__x0.lo,__x1.lo);
    simd_double2 __r2 = vzip1q_f64(__x0.hi,__x1.hi);
#else
    simd_double2 __r0 = {__x0[0], __x1[0]};
    simd_double2 __r1 = {__x0[1], __x1[1]};
    simd_double2 __r2 = {__x0[2], __x1[2]};
#endif
    return simd_matrix(__r0,__r1,__r2);
}

static simd_double4x2 SIMD_CFUNC simd_transpose(simd_double2x4 __x) {
    simd_double4 __x0, __x1;
    __x0 = __x.columns[0];
    __x1 = __x.columns[1];
#if defined __ARM_NEON__
    simd_double2 __r0 = vzip1q_f64(__x0.lo,__x1.lo);
    simd_double2 __r1 = vzip2q_f64(__x0.lo,__x1.lo);
    simd_double2 __r2 = vzip1q_f64(__x0.hi,__x1.hi);
    simd_double2 __r3 = vzip2q_f64(__x0.hi,__x1.hi);
#else
    simd_double2 __r0 = {__x0[0], __x1[0]};
    simd_double2 __r1 = {__x0[1], __x1[1]};
    simd_double2 __r2 = {__x0[2], __x1[2]};
    simd_double2 __r3 = {__x0[3], __x1[3]};
#endif
    return simd_matrix(__r0,__r1,__r2,__r3);
}

static simd_double2x3 SIMD_CFUNC simd_transpose(simd_double3x2 __x) {
    simd_double2 __x0, __x1, __x2;
    __x0 = __x.columns[0];
    __x1 = __x.columns[1];
    __x2 = __x.columns[2];
#if defined __ARM_NEON__
    simd_double2 padding = { 0 };
    simd_double4 __r0,__r1;
    __r0.lo = vzip1q_f64(__x0,__x1);
    __r1.lo = vzip2q_f64(__x0,__x1);
    __r0.hi = vzip1q_f64(__x2,padding);
    __r1.hi = vzip2q_f64(__x2,padding);
#else
    simd_double4 __r0 = {__x0[0], __x1[0], __x2[0]};
    simd_double4 __r1 = {__x0[1], __x1[1], __x2[1]};
#endif
    return simd_matrix(__r0.xyz,__r1.xyz);
}

static simd_double3x3 SIMD_CFUNC simd_transpose(simd_double3x3 __x) {
    simd_double4 __x0, __x1, __x2;
    __x0.xyz = __x.columns[0];
    __x1.xyz = __x.columns[1];
    __x2.xyz = __x.columns[2];
#if defined __ARM_NEON__
    simd_double2 padding = { 0 };
    simd_double4 __r0,__r1,__r2;
    __r0.lo = vzip1q_f64(__x0.lo,__x1.lo);
    __r1.lo = vzip2q_f64(__x0.lo,__x1.lo);
    __r2.lo = vzip1q_f64(__x0.hi,__x1.hi);
    __r0.hi = vzip1q_f64(__x2.lo,padding);
    __r1.hi = vzip2q_f64(__x2.lo,padding);
    __r2.hi = vzip1q_f64(__x2.hi,padding);
#else
    simd_double4 __r0 = {__x0[0], __x1[0], __x2[0]};
    simd_double4 __r1 = {__x0[1], __x1[1], __x2[1]};
    simd_double4 __r2 = {__x0[2], __x1[2], __x2[2]};
#endif
    return simd_matrix(__r0.xyz,__r1.xyz,__r2.xyz);
}

static simd_double4x3 SIMD_CFUNC simd_transpose(simd_double3x4 __x) {
    simd_double4 __x0, __x1, __x2;
    __x0 = __x.columns[0];
    __x1 = __x.columns[1];
    __x2 = __x.columns[2];
#if defined __ARM_NEON__
    simd_double2 padding = { 0 };
    simd_double4 __r0,__r1,__r2,__r3;
    __r0.lo = vzip1q_f64(__x0.lo,__x1.lo);
    __r1.lo = vzip2q_f64(__x0.lo,__x1.lo);
    __r2.lo = vzip1q_f64(__x0.hi,__x1.hi);
    __r3.lo = vzip2q_f64(__x0.hi,__x1.hi);
    __r0.hi = vzip1q_f64(__x2.lo,padding);
    __r1.hi = vzip2q_f64(__x2.lo,padding);
    __r2.hi = vzip1q_f64(__x2.hi,padding);
    __r3.hi = vzip2q_f64(__x2.hi,padding);
#else
    simd_double4 __r0 = {__x0[0], __x1[0], __x2[0]};
    simd_double4 __r1 = {__x0[1], __x1[1], __x2[1]};
    simd_double4 __r2 = {__x0[2], __x1[2], __x2[2]};
    simd_double4 __r3 = {__x0[3], __x1[3], __x2[3]};
#endif
    return simd_matrix(__r0.xyz,__r1.xyz,__r2.xyz,__r3.xyz);
}

static simd_double2x4 SIMD_CFUNC simd_transpose(simd_double4x2 __x) {
    simd_double2 __x0, __x1, __x2, __x3;
    __x0 = __x.columns[0];
    __x1 = __x.columns[1];
    __x2 = __x.columns[2];
    __x3 = __x.columns[3];
#if defined __ARM_NEON__
    simd_double4 __r0,__r1;
    __r0.lo = vzip1q_f64(__x0,__x1);
    __r1.lo = vzip2q_f64(__x0,__x1);
    __r0.hi = vzip1q_f64(__x2,__x3);
    __r1.hi = vzip2q_f64(__x2,__x3);
#else
    simd_double4 __r0 = {__x0[0], __x1[0], __x2[0], __x3[0]};
    simd_double4 __r1 = {__x0[1], __x1[1], __x2[1], __x3[1]};
#endif
    return simd_matrix(__r0,__r1);
}

static simd_double3x4 SIMD_CFUNC simd_transpose(simd_double4x3 __x) {
    simd_double4 __x0, __x1, __x2, __x3;
    __x0.xyz = __x.columns[0];
    __x1.xyz = __x.columns[1];
    __x2.xyz = __x.columns[2];
    __x3.xyz = __x.columns[3];
#if defined __ARM_NEON__
    simd_double4 __r0,__r1,__r2;
    __r0.lo = vzip1q_f64(__x0.lo,__x1.lo);
    __r1.lo = vzip2q_f64(__x0.lo,__x1.lo);
    __r2.lo = vzip1q_f64(__x0.hi,__x1.hi);
    __r0.hi = vzip1q_f64(__x2.lo,__x3.lo);
    __r1.hi = vzip2q_f64(__x2.lo,__x3.lo);
    __r2.hi = vzip1q_f64(__x2.hi,__x3.hi);
#else
    simd_double4 __r0 = {__x0[0], __x1[0], __x2[0], __x3[0]};
    simd_double4 __r1 = {__x0[1], __x1[1], __x2[1], __x3[1]};
    simd_double4 __r2 = {__x0[2], __x1[2], __x2[2], __x3[2]};
#endif
    return simd_matrix(__r0,__r1,__r2);
}

static simd_double4x4 SIMD_CFUNC simd_transpose(simd_double4x4 __x) {
    simd_double4 __x0, __x1, __x2, __x3;
    __x0 = __x.columns[0];
    __x1 = __x.columns[1];
    __x2 = __x.columns[2];
    __x3 = __x.columns[3];
#if defined __ARM_NEON__
    simd_double4 __r0,__r1,__r2,__r3;
    __r0.lo = vzip1q_f64(__x0.lo,__x1.lo);
    __r1.lo = vzip2q_f64(__x0.lo,__x1.lo);
    __r2.lo = vzip1q_f64(__x0.hi,__x1.hi);
    __r3.lo = vzip2q_f64(__x0.hi,__x1.hi);
    __r0.hi = vzip1q_f64(__x2.lo,__x3.lo);
    __r1.hi = vzip2q_f64(__x2.lo,__x3.lo);
    __r2.hi = vzip1q_f64(__x2.hi,__x3.hi);
    __r3.hi = vzip2q_f64(__x2.hi,__x3.hi);
#else
    simd_double4 __r0 = {__x0[0], __x1[0], __x2[0], __x3[0]};
    simd_double4 __r1 = {__x0[1], __x1[1], __x2[1], __x3[1]};
    simd_double4 __r2 = {__x0[2], __x1[2], __x2[2], __x3[2]};
    simd_double4 __r3 = {__x0[3], __x1[3], __x2[3], __x3[3]};
#endif
    return simd_matrix(__r0,__r1,__r2,__r3);
}

static  simd_float3 SIMD_CFUNC __rotate1( simd_float3 __x) { return __builtin_shufflevector(__x,__x,1,2,0); }
static  simd_float3 SIMD_CFUNC __rotate2( simd_float3 __x) { return __builtin_shufflevector(__x,__x,2,0,1); }
static  simd_float4 SIMD_CFUNC __rotate1( simd_float4 __x) { return __builtin_shufflevector(__x,__x,1,2,3,0); }
static  simd_float4 SIMD_CFUNC __rotate2( simd_float4 __x) { return __builtin_shufflevector(__x,__x,2,3,0,1); }
static  simd_float4 SIMD_CFUNC __rotate3( simd_float4 __x) { return __builtin_shufflevector(__x,__x,3,0,1,2); }
static simd_double3 SIMD_CFUNC __rotate1(simd_double3 __x) { return __builtin_shufflevector(__x,__x,1,2,0); }
static simd_double3 SIMD_CFUNC __rotate2(simd_double3 __x) { return __builtin_shufflevector(__x,__x,2,0,1); }
static simd_double4 SIMD_CFUNC __rotate1(simd_double4 __x) { return __builtin_shufflevector(__x,__x,1,2,3,0); }
static simd_double4 SIMD_CFUNC __rotate2(simd_double4 __x) { return __builtin_shufflevector(__x,__x,2,3,0,1); }
static simd_double4 SIMD_CFUNC __rotate3(simd_double4 __x) { return __builtin_shufflevector(__x,__x,3,0,1,2); }

static  float SIMD_CFUNC simd_trace( simd_float2x2 __x) { return __x.columns[0][0] + __x.columns[1][1]; }
static double SIMD_CFUNC simd_trace(simd_double2x2 __x) { return __x.columns[0][0] + __x.columns[1][1]; }
static  float SIMD_CFUNC simd_trace( simd_float3x3 __x) { return __x.columns[0][0] + __x.columns[1][1] + __x.columns[2][2]; }
static double SIMD_CFUNC simd_trace(simd_double3x3 __x) { return __x.columns[0][0] + __x.columns[1][1] + __x.columns[2][2]; }
static  float SIMD_CFUNC simd_trace( simd_float4x4 __x) { return __x.columns[0][0] + __x.columns[1][1] + __x.columns[2][2] + __x.columns[3][3]; }
static double SIMD_CFUNC simd_trace(simd_double4x4 __x) { return __x.columns[0][0] + __x.columns[1][1] + __x.columns[2][2] + __x.columns[3][3]; }

static  float SIMD_CFUNC simd_determinant( simd_float2x2 __x) { return __x.columns[0][0]*__x.columns[1][1] - __x.columns[0][1]*__x.columns[1][0]; }
static double SIMD_CFUNC simd_determinant(simd_double2x2 __x) { return __x.columns[0][0]*__x.columns[1][1] - __x.columns[0][1]*__x.columns[1][0]; }
static  float SIMD_CFUNC simd_determinant( simd_float3x3 __x) { return simd_reduce_add(__x.columns[0]*(__rotate1(__x.columns[1])*__rotate2(__x.columns[2]) - __rotate2(__x.columns[1])*__rotate1(__x.columns[2]))); }
static double SIMD_CFUNC simd_determinant(simd_double3x3 __x) { return simd_reduce_add(__x.columns[0]*(__rotate1(__x.columns[1])*__rotate2(__x.columns[2]) - __rotate2(__x.columns[1])*__rotate1(__x.columns[2]))); }
static  float SIMD_CFUNC simd_determinant( simd_float4x4 __x) {
    simd_float4 codet = __x.columns[0]*(__rotate1(__x.columns[1])*(__rotate2(__x.columns[2])*__rotate3(__x.columns[3])-__rotate3(__x.columns[2])*__rotate2(__x.columns[3])) +
                                          __rotate2(__x.columns[1])*(__rotate3(__x.columns[2])*__rotate1(__x.columns[3])-__rotate1(__x.columns[2])*__rotate3(__x.columns[3])) +
                                          __rotate3(__x.columns[1])*(__rotate1(__x.columns[2])*__rotate2(__x.columns[3])-__rotate2(__x.columns[2])*__rotate1(__x.columns[3])));
    return simd_reduce_add(codet.even - codet.odd);
}
static double SIMD_CFUNC simd_determinant(simd_double4x4 __x) {
    simd_double4 codet = __x.columns[0]*(__rotate1(__x.columns[1])*(__rotate2(__x.columns[2])*__rotate3(__x.columns[3])-__rotate3(__x.columns[2])*__rotate2(__x.columns[3])) +
                                           __rotate2(__x.columns[1])*(__rotate3(__x.columns[2])*__rotate1(__x.columns[3])-__rotate1(__x.columns[2])*__rotate3(__x.columns[3])) +
                                           __rotate3(__x.columns[1])*(__rotate1(__x.columns[2])*__rotate2(__x.columns[3])-__rotate2(__x.columns[2])*__rotate1(__x.columns[3])));
    return simd_reduce_add(codet.even - codet.odd);
}

static  simd_float2x2 SIMD_CFUNC simd_inverse( simd_float2x2 __x) { return __invert_f2(__x); }
static  simd_float3x3 SIMD_CFUNC simd_inverse( simd_float3x3 __x) { return __invert_f3(__x); }
static  simd_float4x4 SIMD_CFUNC simd_inverse( simd_float4x4 __x) { return __invert_f4(__x); }
static simd_double2x2 SIMD_CFUNC simd_inverse(simd_double2x2 __x) { return __invert_d2(__x); }
static simd_double3x3 SIMD_CFUNC simd_inverse(simd_double3x3 __x) { return __invert_d3(__x); }
static simd_double4x4 SIMD_CFUNC simd_inverse(simd_double4x4 __x) { return __invert_d4(__x); }

static  simd_float2 SIMD_CFUNC simd_mul( simd_float2x2 __x,  simd_float2 __y) {  simd_float2 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); return __r; }
static  simd_float3 SIMD_CFUNC simd_mul( simd_float2x3 __x,  simd_float2 __y) {  simd_float3 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); return __r; }
static  simd_float4 SIMD_CFUNC simd_mul( simd_float2x4 __x,  simd_float2 __y) {  simd_float4 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); return __r; }
static  simd_float2 SIMD_CFUNC simd_mul( simd_float3x2 __x,  simd_float3 __y) {  simd_float2 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); return __r; }
static  simd_float3 SIMD_CFUNC simd_mul( simd_float3x3 __x,  simd_float3 __y) {  simd_float3 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); return __r; }
static  simd_float4 SIMD_CFUNC simd_mul( simd_float3x4 __x,  simd_float3 __y) {  simd_float4 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); return __r; }
static  simd_float2 SIMD_CFUNC simd_mul( simd_float4x2 __x,  simd_float4 __y) {  simd_float2 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); __r = simd_muladd( __x.columns[3], __y[3],__r); return __r; }
static  simd_float3 SIMD_CFUNC simd_mul( simd_float4x3 __x,  simd_float4 __y) {  simd_float3 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); __r = simd_muladd( __x.columns[3], __y[3],__r); return __r; }
static  simd_float4 SIMD_CFUNC simd_mul( simd_float4x4 __x,  simd_float4 __y) {  simd_float4 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); __r = simd_muladd( __x.columns[3], __y[3],__r); return __r; }
static simd_double2 SIMD_CFUNC simd_mul(simd_double2x2 __x, simd_double2 __y) { simd_double2 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); return __r; }
static simd_double3 SIMD_CFUNC simd_mul(simd_double2x3 __x, simd_double2 __y) { simd_double3 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); return __r; }
static simd_double4 SIMD_CFUNC simd_mul(simd_double2x4 __x, simd_double2 __y) { simd_double4 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); return __r; }
static simd_double2 SIMD_CFUNC simd_mul(simd_double3x2 __x, simd_double3 __y) { simd_double2 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); return __r; }
static simd_double3 SIMD_CFUNC simd_mul(simd_double3x3 __x, simd_double3 __y) { simd_double3 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); return __r; }
static simd_double4 SIMD_CFUNC simd_mul(simd_double3x4 __x, simd_double3 __y) { simd_double4 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); return __r; }
static simd_double2 SIMD_CFUNC simd_mul(simd_double4x2 __x, simd_double4 __y) { simd_double2 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); __r = simd_muladd( __x.columns[3], __y[3],__r); return __r; }
static simd_double3 SIMD_CFUNC simd_mul(simd_double4x3 __x, simd_double4 __y) { simd_double3 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); __r = simd_muladd( __x.columns[3], __y[3],__r); return __r; }
static simd_double4 SIMD_CFUNC simd_mul(simd_double4x4 __x, simd_double4 __y) { simd_double4 __r = __x.columns[0]*__y[0]; __r = simd_muladd( __x.columns[1], __y[1],__r); __r = simd_muladd( __x.columns[2], __y[2],__r); __r = simd_muladd( __x.columns[3], __y[3],__r); return __r; }

static  simd_float2 SIMD_CFUNC simd_mul( simd_float2 __x,  simd_float2x2 __y) { return simd_mul(simd_transpose(__y), __x); }
static  simd_float3 SIMD_CFUNC simd_mul( simd_float2 __x,  simd_float3x2 __y) { return simd_mul(simd_transpose(__y), __x); }
static  simd_float4 SIMD_CFUNC simd_mul( simd_float2 __x,  simd_float4x2 __y) { return simd_mul(simd_transpose(__y), __x); }
static  simd_float2 SIMD_CFUNC simd_mul( simd_float3 __x,  simd_float2x3 __y) { return simd_mul(simd_transpose(__y), __x); }
static  simd_float3 SIMD_CFUNC simd_mul( simd_float3 __x,  simd_float3x3 __y) { return simd_mul(simd_transpose(__y), __x); }
static  simd_float4 SIMD_CFUNC simd_mul( simd_float3 __x,  simd_float4x3 __y) { return simd_mul(simd_transpose(__y), __x); }
static  simd_float2 SIMD_CFUNC simd_mul( simd_float4 __x,  simd_float2x4 __y) { return simd_mul(simd_transpose(__y), __x); }
static  simd_float3 SIMD_CFUNC simd_mul( simd_float4 __x,  simd_float3x4 __y) { return simd_mul(simd_transpose(__y), __x); }
static  simd_float4 SIMD_CFUNC simd_mul( simd_float4 __x,  simd_float4x4 __y) { return simd_mul(simd_transpose(__y), __x); }
static simd_double2 SIMD_CFUNC simd_mul(simd_double2 __x, simd_double2x2 __y) { return simd_mul(simd_transpose(__y), __x); }
static simd_double3 SIMD_CFUNC simd_mul(simd_double2 __x, simd_double3x2 __y) { return simd_mul(simd_transpose(__y), __x); }
static simd_double4 SIMD_CFUNC simd_mul(simd_double2 __x, simd_double4x2 __y) { return simd_mul(simd_transpose(__y), __x); }
static simd_double2 SIMD_CFUNC simd_mul(simd_double3 __x, simd_double2x3 __y) { return simd_mul(simd_transpose(__y), __x); }
static simd_double3 SIMD_CFUNC simd_mul(simd_double3 __x, simd_double3x3 __y) { return simd_mul(simd_transpose(__y), __x); }
static simd_double4 SIMD_CFUNC simd_mul(simd_double3 __x, simd_double4x3 __y) { return simd_mul(simd_transpose(__y), __x); }
static simd_double2 SIMD_CFUNC simd_mul(simd_double4 __x, simd_double2x4 __y) { return simd_mul(simd_transpose(__y), __x); }
static simd_double3 SIMD_CFUNC simd_mul(simd_double4 __x, simd_double3x4 __y) { return simd_mul(simd_transpose(__y), __x); }
static simd_double4 SIMD_CFUNC simd_mul(simd_double4 __x, simd_double4x4 __y) { return simd_mul(simd_transpose(__y), __x); }

static  simd_float2x2 SIMD_CFUNC simd_mul( simd_float2x2 __x,  simd_float2x2 __y) {  simd_float2x2 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double2x2 SIMD_CFUNC simd_mul(simd_double2x2 __x, simd_double2x2 __y) { simd_double2x2 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float2x3 SIMD_CFUNC simd_mul( simd_float2x3 __x,  simd_float2x2 __y) {  simd_float2x3 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double2x3 SIMD_CFUNC simd_mul(simd_double2x3 __x, simd_double2x2 __y) { simd_double2x3 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float2x4 SIMD_CFUNC simd_mul( simd_float2x4 __x,  simd_float2x2 __y) {  simd_float2x4 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double2x4 SIMD_CFUNC simd_mul(simd_double2x4 __x, simd_double2x2 __y) { simd_double2x4 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float2x2 SIMD_CFUNC simd_mul( simd_float3x2 __x,  simd_float2x3 __y) {  simd_float2x2 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double2x2 SIMD_CFUNC simd_mul(simd_double3x2 __x, simd_double2x3 __y) { simd_double2x2 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float2x3 SIMD_CFUNC simd_mul( simd_float3x3 __x,  simd_float2x3 __y) {  simd_float2x3 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double2x3 SIMD_CFUNC simd_mul(simd_double3x3 __x, simd_double2x3 __y) { simd_double2x3 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float2x4 SIMD_CFUNC simd_mul( simd_float3x4 __x,  simd_float2x3 __y) {  simd_float2x4 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double2x4 SIMD_CFUNC simd_mul(simd_double3x4 __x, simd_double2x3 __y) { simd_double2x4 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float2x2 SIMD_CFUNC simd_mul( simd_float4x2 __x,  simd_float2x4 __y) {  simd_float2x2 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double2x2 SIMD_CFUNC simd_mul(simd_double4x2 __x, simd_double2x4 __y) { simd_double2x2 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float2x3 SIMD_CFUNC simd_mul( simd_float4x3 __x,  simd_float2x4 __y) {  simd_float2x3 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double2x3 SIMD_CFUNC simd_mul(simd_double4x3 __x, simd_double2x4 __y) { simd_double2x3 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float2x4 SIMD_CFUNC simd_mul( simd_float4x4 __x,  simd_float2x4 __y) {  simd_float2x4 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double2x4 SIMD_CFUNC simd_mul(simd_double4x4 __x, simd_double2x4 __y) { simd_double2x4 __r; for (int i=0; i<2; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }

static  simd_float3x2 SIMD_CFUNC simd_mul( simd_float2x2 __x,  simd_float3x2 __y) {  simd_float3x2 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double3x2 SIMD_CFUNC simd_mul(simd_double2x2 __x, simd_double3x2 __y) { simd_double3x2 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float3x3 SIMD_CFUNC simd_mul( simd_float2x3 __x,  simd_float3x2 __y) {  simd_float3x3 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double3x3 SIMD_CFUNC simd_mul(simd_double2x3 __x, simd_double3x2 __y) { simd_double3x3 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float3x4 SIMD_CFUNC simd_mul( simd_float2x4 __x,  simd_float3x2 __y) {  simd_float3x4 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double3x4 SIMD_CFUNC simd_mul(simd_double2x4 __x, simd_double3x2 __y) { simd_double3x4 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float3x2 SIMD_CFUNC simd_mul( simd_float3x2 __x,  simd_float3x3 __y) {  simd_float3x2 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double3x2 SIMD_CFUNC simd_mul(simd_double3x2 __x, simd_double3x3 __y) { simd_double3x2 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float3x3 SIMD_CFUNC simd_mul( simd_float3x3 __x,  simd_float3x3 __y) {  simd_float3x3 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double3x3 SIMD_CFUNC simd_mul(simd_double3x3 __x, simd_double3x3 __y) { simd_double3x3 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float3x4 SIMD_CFUNC simd_mul( simd_float3x4 __x,  simd_float3x3 __y) {  simd_float3x4 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double3x4 SIMD_CFUNC simd_mul(simd_double3x4 __x, simd_double3x3 __y) { simd_double3x4 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float3x2 SIMD_CFUNC simd_mul( simd_float4x2 __x,  simd_float3x4 __y) {  simd_float3x2 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double3x2 SIMD_CFUNC simd_mul(simd_double4x2 __x, simd_double3x4 __y) { simd_double3x2 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float3x3 SIMD_CFUNC simd_mul( simd_float4x3 __x,  simd_float3x4 __y) {  simd_float3x3 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double3x3 SIMD_CFUNC simd_mul(simd_double4x3 __x, simd_double3x4 __y) { simd_double3x3 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float3x4 SIMD_CFUNC simd_mul( simd_float4x4 __x,  simd_float3x4 __y) {  simd_float3x4 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double3x4 SIMD_CFUNC simd_mul(simd_double4x4 __x, simd_double3x4 __y) { simd_double3x4 __r; for (int i=0; i<3; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }

static  simd_float4x2 SIMD_CFUNC simd_mul( simd_float2x2 __x,  simd_float4x2 __y) {  simd_float4x2 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double4x2 SIMD_CFUNC simd_mul(simd_double2x2 __x, simd_double4x2 __y) { simd_double4x2 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float4x3 SIMD_CFUNC simd_mul( simd_float2x3 __x,  simd_float4x2 __y) {  simd_float4x3 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double4x3 SIMD_CFUNC simd_mul(simd_double2x3 __x, simd_double4x2 __y) { simd_double4x3 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float4x4 SIMD_CFUNC simd_mul( simd_float2x4 __x,  simd_float4x2 __y) {  simd_float4x4 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double4x4 SIMD_CFUNC simd_mul(simd_double2x4 __x, simd_double4x2 __y) { simd_double4x4 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float4x2 SIMD_CFUNC simd_mul( simd_float3x2 __x,  simd_float4x3 __y) {  simd_float4x2 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double4x2 SIMD_CFUNC simd_mul(simd_double3x2 __x, simd_double4x3 __y) { simd_double4x2 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float4x3 SIMD_CFUNC simd_mul( simd_float3x3 __x,  simd_float4x3 __y) {  simd_float4x3 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double4x3 SIMD_CFUNC simd_mul(simd_double3x3 __x, simd_double4x3 __y) { simd_double4x3 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float4x4 SIMD_CFUNC simd_mul( simd_float3x4 __x,  simd_float4x3 __y) {  simd_float4x4 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double4x4 SIMD_CFUNC simd_mul(simd_double3x4 __x, simd_double4x3 __y) { simd_double4x4 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float4x2 SIMD_CFUNC simd_mul( simd_float4x2 __x,  simd_float4x4 __y) {  simd_float4x2 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double4x2 SIMD_CFUNC simd_mul(simd_double4x2 __x, simd_double4x4 __y) { simd_double4x2 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float4x3 SIMD_CFUNC simd_mul( simd_float4x3 __x,  simd_float4x4 __y) {  simd_float4x3 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double4x3 SIMD_CFUNC simd_mul(simd_double4x3 __x, simd_double4x4 __y) { simd_double4x3 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static  simd_float4x4 SIMD_CFUNC simd_mul( simd_float4x4 __x,  simd_float4x4 __y) {  simd_float4x4 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
static simd_double4x4 SIMD_CFUNC simd_mul(simd_double4x4 __x, simd_double4x4 __y) { simd_double4x4 __r; for (int i=0; i<4; ++i) __r.columns[i] = simd_mul(__x, __y.columns[i]); return __r; }
  
static  simd_float2 SIMD_CFUNC matrix_multiply( simd_float2x2 __x,  simd_float2 __y) { return simd_mul(__x, __y); }
static  simd_float3 SIMD_CFUNC matrix_multiply( simd_float2x3 __x,  simd_float2 __y) { return simd_mul(__x, __y); }
static  simd_float4 SIMD_CFUNC matrix_multiply( simd_float2x4 __x,  simd_float2 __y) { return simd_mul(__x, __y); }
static  simd_float2 SIMD_CFUNC matrix_multiply( simd_float3x2 __x,  simd_float3 __y) { return simd_mul(__x, __y); }
static  simd_float3 SIMD_CFUNC matrix_multiply( simd_float3x3 __x,  simd_float3 __y) { return simd_mul(__x, __y); }
static  simd_float4 SIMD_CFUNC matrix_multiply( simd_float3x4 __x,  simd_float3 __y) { return simd_mul(__x, __y); }
static  simd_float2 SIMD_CFUNC matrix_multiply( simd_float4x2 __x,  simd_float4 __y) { return simd_mul(__x, __y); }
static  simd_float3 SIMD_CFUNC matrix_multiply( simd_float4x3 __x,  simd_float4 __y) { return simd_mul(__x, __y); }
static  simd_float4 SIMD_CFUNC matrix_multiply( simd_float4x4 __x,  simd_float4 __y) { return simd_mul(__x, __y); }
static simd_double2 SIMD_CFUNC matrix_multiply(simd_double2x2 __x, simd_double2 __y) { return simd_mul(__x, __y); }
static simd_double3 SIMD_CFUNC matrix_multiply(simd_double2x3 __x, simd_double2 __y) { return simd_mul(__x, __y); }
static simd_double4 SIMD_CFUNC matrix_multiply(simd_double2x4 __x, simd_double2 __y) { return simd_mul(__x, __y); }
static simd_double2 SIMD_CFUNC matrix_multiply(simd_double3x2 __x, simd_double3 __y) { return simd_mul(__x, __y); }
static simd_double3 SIMD_CFUNC matrix_multiply(simd_double3x3 __x, simd_double3 __y) { return simd_mul(__x, __y); }
static simd_double4 SIMD_CFUNC matrix_multiply(simd_double3x4 __x, simd_double3 __y) { return simd_mul(__x, __y); }
static simd_double2 SIMD_CFUNC matrix_multiply(simd_double4x2 __x, simd_double4 __y) { return simd_mul(__x, __y); }
static simd_double3 SIMD_CFUNC matrix_multiply(simd_double4x3 __x, simd_double4 __y) { return simd_mul(__x, __y); }
static simd_double4 SIMD_CFUNC matrix_multiply(simd_double4x4 __x, simd_double4 __y) { return simd_mul(__x, __y); }
  
static  simd_float2 SIMD_CFUNC matrix_multiply( simd_float2 __x,  simd_float2x2 __y) { return simd_mul(__x, __y); }
static  simd_float3 SIMD_CFUNC matrix_multiply( simd_float2 __x,  simd_float3x2 __y) { return simd_mul(__x, __y); }
static  simd_float4 SIMD_CFUNC matrix_multiply( simd_float2 __x,  simd_float4x2 __y) { return simd_mul(__x, __y); }
static  simd_float2 SIMD_CFUNC matrix_multiply( simd_float3 __x,  simd_float2x3 __y) { return simd_mul(__x, __y); }
static  simd_float3 SIMD_CFUNC matrix_multiply( simd_float3 __x,  simd_float3x3 __y) { return simd_mul(__x, __y); }
static  simd_float4 SIMD_CFUNC matrix_multiply( simd_float3 __x,  simd_float4x3 __y) { return simd_mul(__x, __y); }
static  simd_float2 SIMD_CFUNC matrix_multiply( simd_float4 __x,  simd_float2x4 __y) { return simd_mul(__x, __y); }
static  simd_float3 SIMD_CFUNC matrix_multiply( simd_float4 __x,  simd_float3x4 __y) { return simd_mul(__x, __y); }
static  simd_float4 SIMD_CFUNC matrix_multiply( simd_float4 __x,  simd_float4x4 __y) { return simd_mul(__x, __y); }
static simd_double2 SIMD_CFUNC matrix_multiply(simd_double2 __x, simd_double2x2 __y) { return simd_mul(__x, __y); }
static simd_double3 SIMD_CFUNC matrix_multiply(simd_double2 __x, simd_double3x2 __y) { return simd_mul(__x, __y); }
static simd_double4 SIMD_CFUNC matrix_multiply(simd_double2 __x, simd_double4x2 __y) { return simd_mul(__x, __y); }
static simd_double2 SIMD_CFUNC matrix_multiply(simd_double3 __x, simd_double2x3 __y) { return simd_mul(__x, __y); }
static simd_double3 SIMD_CFUNC matrix_multiply(simd_double3 __x, simd_double3x3 __y) { return simd_mul(__x, __y); }
static simd_double4 SIMD_CFUNC matrix_multiply(simd_double3 __x, simd_double4x3 __y) { return simd_mul(__x, __y); }
static simd_double2 SIMD_CFUNC matrix_multiply(simd_double4 __x, simd_double2x4 __y) { return simd_mul(__x, __y); }
static simd_double3 SIMD_CFUNC matrix_multiply(simd_double4 __x, simd_double3x4 __y) { return simd_mul(__x, __y); }
static simd_double4 SIMD_CFUNC matrix_multiply(simd_double4 __x, simd_double4x4 __y) { return simd_mul(__x, __y); }
  
static  simd_float2x2 SIMD_CFUNC matrix_multiply( simd_float2x2 __x,  simd_float2x2 __y) { return simd_mul(__x, __y); }
static simd_double2x2 SIMD_CFUNC matrix_multiply(simd_double2x2 __x, simd_double2x2 __y) { return simd_mul(__x, __y); }
static  simd_float2x3 SIMD_CFUNC matrix_multiply( simd_float2x3 __x,  simd_float2x2 __y) { return simd_mul(__x, __y); }
static simd_double2x3 SIMD_CFUNC matrix_multiply(simd_double2x3 __x, simd_double2x2 __y) { return simd_mul(__x, __y); }
static  simd_float2x4 SIMD_CFUNC matrix_multiply( simd_float2x4 __x,  simd_float2x2 __y) { return simd_mul(__x, __y); }
static simd_double2x4 SIMD_CFUNC matrix_multiply(simd_double2x4 __x, simd_double2x2 __y) { return simd_mul(__x, __y); }
static  simd_float2x2 SIMD_CFUNC matrix_multiply( simd_float3x2 __x,  simd_float2x3 __y) { return simd_mul(__x, __y); }
static simd_double2x2 SIMD_CFUNC matrix_multiply(simd_double3x2 __x, simd_double2x3 __y) { return simd_mul(__x, __y); }
static  simd_float2x3 SIMD_CFUNC matrix_multiply( simd_float3x3 __x,  simd_float2x3 __y) { return simd_mul(__x, __y); }
static simd_double2x3 SIMD_CFUNC matrix_multiply(simd_double3x3 __x, simd_double2x3 __y) { return simd_mul(__x, __y); }
static  simd_float2x4 SIMD_CFUNC matrix_multiply( simd_float3x4 __x,  simd_float2x3 __y) { return simd_mul(__x, __y); }
static simd_double2x4 SIMD_CFUNC matrix_multiply(simd_double3x4 __x, simd_double2x3 __y) { return simd_mul(__x, __y); }
static  simd_float2x2 SIMD_CFUNC matrix_multiply( simd_float4x2 __x,  simd_float2x4 __y) { return simd_mul(__x, __y); }
static simd_double2x2 SIMD_CFUNC matrix_multiply(simd_double4x2 __x, simd_double2x4 __y) { return simd_mul(__x, __y); }
static  simd_float2x3 SIMD_CFUNC matrix_multiply( simd_float4x3 __x,  simd_float2x4 __y) { return simd_mul(__x, __y); }
static simd_double2x3 SIMD_CFUNC matrix_multiply(simd_double4x3 __x, simd_double2x4 __y) { return simd_mul(__x, __y); }
static  simd_float2x4 SIMD_CFUNC matrix_multiply( simd_float4x4 __x,  simd_float2x4 __y) { return simd_mul(__x, __y); }
static simd_double2x4 SIMD_CFUNC matrix_multiply(simd_double4x4 __x, simd_double2x4 __y) { return simd_mul(__x, __y); }
  
static  simd_float3x2 SIMD_CFUNC matrix_multiply( simd_float2x2 __x,  simd_float3x2 __y) { return simd_mul(__x, __y); }
static simd_double3x2 SIMD_CFUNC matrix_multiply(simd_double2x2 __x, simd_double3x2 __y) { return simd_mul(__x, __y); }
static  simd_float3x3 SIMD_CFUNC matrix_multiply( simd_float2x3 __x,  simd_float3x2 __y) { return simd_mul(__x, __y); }
static simd_double3x3 SIMD_CFUNC matrix_multiply(simd_double2x3 __x, simd_double3x2 __y) { return simd_mul(__x, __y); }
static  simd_float3x4 SIMD_CFUNC matrix_multiply( simd_float2x4 __x,  simd_float3x2 __y) { return simd_mul(__x, __y); }
static simd_double3x4 SIMD_CFUNC matrix_multiply(simd_double2x4 __x, simd_double3x2 __y) { return simd_mul(__x, __y); }
static  simd_float3x2 SIMD_CFUNC matrix_multiply( simd_float3x2 __x,  simd_float3x3 __y) { return simd_mul(__x, __y); }
static simd_double3x2 SIMD_CFUNC matrix_multiply(simd_double3x2 __x, simd_double3x3 __y) { return simd_mul(__x, __y); }
static  simd_float3x3 SIMD_CFUNC matrix_multiply( simd_float3x3 __x,  simd_float3x3 __y) { return simd_mul(__x, __y); }
static simd_double3x3 SIMD_CFUNC matrix_multiply(simd_double3x3 __x, simd_double3x3 __y) { return simd_mul(__x, __y); }
static  simd_float3x4 SIMD_CFUNC matrix_multiply( simd_float3x4 __x,  simd_float3x3 __y) { return simd_mul(__x, __y); }
static simd_double3x4 SIMD_CFUNC matrix_multiply(simd_double3x4 __x, simd_double3x3 __y) { return simd_mul(__x, __y); }
static  simd_float3x2 SIMD_CFUNC matrix_multiply( simd_float4x2 __x,  simd_float3x4 __y) { return simd_mul(__x, __y); }
static simd_double3x2 SIMD_CFUNC matrix_multiply(simd_double4x2 __x, simd_double3x4 __y) { return simd_mul(__x, __y); }
static  simd_float3x3 SIMD_CFUNC matrix_multiply( simd_float4x3 __x,  simd_float3x4 __y) { return simd_mul(__x, __y); }
static simd_double3x3 SIMD_CFUNC matrix_multiply(simd_double4x3 __x, simd_double3x4 __y) { return simd_mul(__x, __y); }
static  simd_float3x4 SIMD_CFUNC matrix_multiply( simd_float4x4 __x,  simd_float3x4 __y) { return simd_mul(__x, __y); }
static simd_double3x4 SIMD_CFUNC matrix_multiply(simd_double4x4 __x, simd_double3x4 __y) { return simd_mul(__x, __y); }
  
static  simd_float4x2 SIMD_CFUNC matrix_multiply( simd_float2x2 __x,  simd_float4x2 __y) { return simd_mul(__x, __y); }
static simd_double4x2 SIMD_CFUNC matrix_multiply(simd_double2x2 __x, simd_double4x2 __y) { return simd_mul(__x, __y); }
static  simd_float4x3 SIMD_CFUNC matrix_multiply( simd_float2x3 __x,  simd_float4x2 __y) { return simd_mul(__x, __y); }
static simd_double4x3 SIMD_CFUNC matrix_multiply(simd_double2x3 __x, simd_double4x2 __y) { return simd_mul(__x, __y); }
static  simd_float4x4 SIMD_CFUNC matrix_multiply( simd_float2x4 __x,  simd_float4x2 __y) { return simd_mul(__x, __y); }
static simd_double4x4 SIMD_CFUNC matrix_multiply(simd_double2x4 __x, simd_double4x2 __y) { return simd_mul(__x, __y); }
static  simd_float4x2 SIMD_CFUNC matrix_multiply( simd_float3x2 __x,  simd_float4x3 __y) { return simd_mul(__x, __y); }
static simd_double4x2 SIMD_CFUNC matrix_multiply(simd_double3x2 __x, simd_double4x3 __y) { return simd_mul(__x, __y); }
static  simd_float4x3 SIMD_CFUNC matrix_multiply( simd_float3x3 __x,  simd_float4x3 __y) { return simd_mul(__x, __y); }
static simd_double4x3 SIMD_CFUNC matrix_multiply(simd_double3x3 __x, simd_double4x3 __y) { return simd_mul(__x, __y); }
static  simd_float4x4 SIMD_CFUNC matrix_multiply( simd_float3x4 __x,  simd_float4x3 __y) { return simd_mul(__x, __y); }
static simd_double4x4 SIMD_CFUNC matrix_multiply(simd_double3x4 __x, simd_double4x3 __y) { return simd_mul(__x, __y); }
static  simd_float4x2 SIMD_CFUNC matrix_multiply( simd_float4x2 __x,  simd_float4x4 __y) { return simd_mul(__x, __y); }
static simd_double4x2 SIMD_CFUNC matrix_multiply(simd_double4x2 __x, simd_double4x4 __y) { return simd_mul(__x, __y); }
static  simd_float4x3 SIMD_CFUNC matrix_multiply( simd_float4x3 __x,  simd_float4x4 __y) { return simd_mul(__x, __y); }
static simd_double4x3 SIMD_CFUNC matrix_multiply(simd_double4x3 __x, simd_double4x4 __y) { return simd_mul(__x, __y); }
static  simd_float4x4 SIMD_CFUNC matrix_multiply( simd_float4x4 __x,  simd_float4x4 __y) { return simd_mul(__x, __y); }
static simd_double4x4 SIMD_CFUNC matrix_multiply(simd_double4x4 __x, simd_double4x4 __y) { return simd_mul(__x, __y); }

static simd_bool SIMD_CFUNC simd_equal(simd_float2x2 __x, simd_float2x2 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_float2x3 __x, simd_float2x3 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_float2x4 __x, simd_float2x4 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_float3x2 __x, simd_float3x2 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_float3x3 __x, simd_float3x3 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_float3x4 __x, simd_float3x4 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_float4x2 __x, simd_float4x2 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]) &
                      (__x.columns[3] == __y.columns[3]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_float4x3 __x, simd_float4x3 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]) &
                      (__x.columns[3] == __y.columns[3]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_float4x4 __x, simd_float4x4 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]) &
                      (__x.columns[3] == __y.columns[3]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_double2x2 __x, simd_double2x2 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_double2x3 __x, simd_double2x3 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_double2x4 __x, simd_double2x4 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_double3x2 __x, simd_double3x2 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_double3x3 __x, simd_double3x3 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_double3x4 __x, simd_double3x4 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_double4x2 __x, simd_double4x2 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]) &
                      (__x.columns[3] == __y.columns[3]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_double4x3 __x, simd_double4x3 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]) &
                      (__x.columns[3] == __y.columns[3]));
}
static simd_bool SIMD_CFUNC simd_equal(simd_double4x4 __x, simd_double4x4 __y) {
    return simd_all((__x.columns[0] == __y.columns[0]) &
                      (__x.columns[1] == __y.columns[1]) &
                      (__x.columns[2] == __y.columns[2]) &
                      (__x.columns[3] == __y.columns[3]));
}

static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float2x2 __x, simd_float2x2 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float2x3 __x, simd_float2x3 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float2x4 __x, simd_float2x4 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float3x2 __x, simd_float3x2 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float3x3 __x, simd_float3x3 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float3x4 __x, simd_float3x4 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float4x2 __x, simd_float4x2 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float4x3 __x, simd_float4x3 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_float4x4 __x, simd_float4x4 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double2x2 __x, simd_double2x2 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double2x3 __x, simd_double2x3 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double2x4 __x, simd_double2x4 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double3x2 __x, simd_double3x2 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double3x3 __x, simd_double3x3 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double3x4 __x, simd_double3x4 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double4x2 __x, simd_double4x2 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double4x3 __x, simd_double4x3 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements(simd_double4x4 __x, simd_double4x4 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol));
}

static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float2x2 __x, simd_float2x2 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float2x3 __x, simd_float2x3 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float2x4 __x, simd_float2x4 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float3x2 __x, simd_float3x2 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float3x3 __x, simd_float3x3 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float3x4 __x, simd_float3x4 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float4x2 __x, simd_float4x2 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol*__tg_fabs(__x.columns[3])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float4x3 __x, simd_float4x3 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol*__tg_fabs(__x.columns[3])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_float4x4 __x, simd_float4x4 __y, float __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol*__tg_fabs(__x.columns[3])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double2x2 __x, simd_double2x2 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double2x3 __x, simd_double2x3 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double2x4 __x, simd_double2x4 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double3x2 __x, simd_double3x2 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double3x3 __x, simd_double3x3 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double3x4 __x, simd_double3x4 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double4x2 __x, simd_double4x2 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol*__tg_fabs(__x.columns[3])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double4x3 __x, simd_double4x3 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol*__tg_fabs(__x.columns[3])));
}
static simd_bool SIMD_CFUNC simd_almost_equal_elements_relative(simd_double4x4 __x, simd_double4x4 __y, double __tol) {
    return simd_all((__tg_fabs(__x.columns[0] - __y.columns[0]) <= __tol*__tg_fabs(__x.columns[0])) &
                      (__tg_fabs(__x.columns[1] - __y.columns[1]) <= __tol*__tg_fabs(__x.columns[1])) &
                      (__tg_fabs(__x.columns[2] - __y.columns[2]) <= __tol*__tg_fabs(__x.columns[2])) &
                      (__tg_fabs(__x.columns[3] - __y.columns[3]) <= __tol*__tg_fabs(__x.columns[3])));
}
    
#ifdef __cplusplus
}
#endif
#endif /* SIMD_COMPILER_HAS_REQUIRED_FEATURES */
#endif /* __SIMD_HEADER__ */
