/*! @header
 *  @copyright 2015-2016 Apple, Inc. All rights reserved.
 *  @unsorted                                                                 */

#ifndef SIMD_TYPES
#define SIMD_TYPES

#include <simd/vector_types.h>
#if SIMD_COMPILER_HAS_REQUIRED_FEATURES

/*! @group Matrices
 *  @discussion
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

/*! @abstract A matrix with 2 rows and 2 columns.                             */
typedef struct { simd_float2 columns[2]; } simd_float2x2;

/*! @abstract A matrix with 2 rows and 3 columns.                             */
typedef struct { simd_float2 columns[3]; } simd_float3x2;

/*! @abstract A matrix with 2 rows and 4 columns.                             */
typedef struct { simd_float2 columns[4]; } simd_float4x2;

/*! @abstract A matrix with 3 rows and 2 columns.                             */
typedef struct { simd_float3 columns[2]; } simd_float2x3;

/*! @abstract A matrix with 3 rows and 3 columns.                             */
typedef struct { simd_float3 columns[3]; } simd_float3x3;

/*! @abstract A matrix with 3 rows and 4 columns.                             */
typedef struct { simd_float3 columns[4]; } simd_float4x3;

/*! @abstract A matrix with 4 rows and 2 columns.                             */
typedef struct { simd_float4 columns[2]; } simd_float2x4;

/*! @abstract A matrix with 4 rows and 3 columns.                             */
typedef struct { simd_float4 columns[3]; } simd_float3x4;

/*! @abstract A matrix with 4 rows and 4 columns.                             */
typedef struct { simd_float4 columns[4]; } simd_float4x4;

/*! @abstract A matrix with 2 rows and 2 columns.                             */
typedef struct { simd_double2 columns[2]; } simd_double2x2;

/*! @abstract A matrix with 2 rows and 3 columns.                             */
typedef struct { simd_double2 columns[3]; } simd_double3x2;

/*! @abstract A matrix with 2 rows and 4 columns.                             */
typedef struct { simd_double2 columns[4]; } simd_double4x2;

/*! @abstract A matrix with 3 rows and 2 columns.                             */
typedef struct { simd_double3 columns[2]; } simd_double2x3;

/*! @abstract A matrix with 3 rows and 3 columns.                             */
typedef struct { simd_double3 columns[3]; } simd_double3x3;

/*! @abstract A matrix with 3 rows and 4 columns.                             */
typedef struct { simd_double3 columns[4]; } simd_double4x3;

/*! @abstract A matrix with 4 rows and 2 columns.                             */
typedef struct { simd_double4 columns[2]; } simd_double2x4;

/*! @abstract A matrix with 4 rows and 3 columns.                             */
typedef struct { simd_double4 columns[3]; } simd_double3x4;

/*! @abstract A matrix with 4 rows and 4 columns.                             */
typedef struct { simd_double4 columns[4]; } simd_double4x4;


/*! @group Quaternions
 *  @discussion Unlike vectors, quaternions are not raw clang extended-vector
 *  types, because if they were you'd be able to intermix them with vectors
 *  in arithmetic operations freely, but the arithmetic would not do what you
 *  want it to do (it would simply perform the arithmetic operation
 *  componentwise on the quaternion and vector).
 *
 *  Quaternions aren't unions in C/Obj-C, because then the C++ types couldn't
 *  inherit from the C types, which would make intermixing rather painful (you
 *  can't inherit from a union).  This means that we can't provide nice member
 *  access like .real and .imag; you need to use functions to access the pieces
 *  of a quaternion instead.
 *
 *  This also means that you need to use functions instead of operators to do
 *  arithmetic with quaternions in C and Obj-C.  In C++, we are able to provide
 *  operator overloads for arithmetic.
 *
 *  Internally, a quaternion is represented as a vector of four elements.  The
 *  first three elements are the "imaginary" (or "vector") part of the
 *  quaternion, and the last element is the "real" (or "scalar") part.  As with
 *  everything simd, you will generally get better performance if you avoid
 *  using the internal storage details of the type, and instead treat these
 *  quaternions as abstract mathematical objects once they are created.
 *
 *  While the C types are defined here, the operations on quaternions and the
 *  C++ quaternion types are defined in <simd/quaternion.h>                   */

/*! @abstract A single-precision quaternion.                                  */
typedef struct {  simd_float4 vector; } simd_quatf;

/*! @abstract A double-precision quaternion.                                  */
typedef struct { simd_double4 vector; } simd_quatd;

#endif /* SIMD_COMPILER_HAS_REQUIRED_FEATURES */
#endif /* SIMD_TYPES */
