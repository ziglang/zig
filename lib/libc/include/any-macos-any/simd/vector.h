/*  Copyright (c) 2014 Apple, Inc. All rights reserved.
 *
 *  This header provides small vector (simd) types and basic arithmetic and
 *  math functions that operate on them.
 *
 *  A wide assortment of vector types are provided in <simd/vector_types.h>,
 *  which is included by this header.  The most important (as far as the rest
 *  of this library is concerned) are vector_floatN (where N is 2, 3, 4, 8, or
 *  16), and vector_doubleN (where N is 2, 3, 4, or 8).
 *
 *  All of the vector types are based on what clang call "OpenCL vectors",
 *  defined with the __ext_vector_type__ attribute.  Many C operators "just
 *  work" with these types, so it is not necessary to make function calls
 *  to do basic arithmetic:
 *
 *      simd_float4 x, y;
 *      x = x + y;          // vector sum of x and y.
 *
 *  scalar values are implicitly promoted to vectors (with a "splat"), so it
 *  is possible to easily write expressions involving scalars as well:
 *
 *      simd_float4 x;
 *      x = 2*x;            // scale x by 2.
 *
 *  Besides the basic operations provided by the compiler, this header provides
 *  a set of mathematical and geometric primitives for use with these types.
 *  In C and Objective-C, these functions are prefixed with vector_; in C++,
 *  unprefixed names are available within the simd:: namespace.
 *
 *      simd_float3 x, y;
 *      vector_max(x,y)     // elementwise maximum of x and y
 *      fabs(x)             // same as vector_abs(x)
 *      vector_clamp(x,0,1) // x clamped to the range [0,1].  This has no
 *                          // standard-library analogue, so there is no
 *                          // alternate name.
 *
 *  Matrix and matrix-vector operations are also available in <simd/matrix.h>.
 */

#ifndef __SIMD_VECTOR_HEADER__
#define __SIMD_VECTOR_HEADER__

#include <simd/vector_types.h>
#include <simd/packed.h>
#include <simd/vector_make.h>
#include <simd/logic.h>
#include <simd/math.h>
#include <simd/common.h>
#include <simd/geometry.h>
#include <simd/conversion.h>

#endif