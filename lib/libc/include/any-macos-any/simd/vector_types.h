/*! @header
 *  This header defines fixed size vector types that are useful both for
 *  graphics and geometry, and for software vectorization without
 *  architecture-specific intrinsics.
 *
 *  These types are based on a clang feature called "Extended vector types"
 *  or "OpenCL vector types" (despite the name, these types work just fine
 *  in C, Objective-C, and C++). There are a few tricks that make these
 *  types nicer to work with than traditional simd intrinsic types:
 *
 *    - Basic arithmetic operators are overloaded to perform lanewise
 *      operations with these types, including both vector-vector and
 *      vector-scalar operations.
 *
 *    - It is possible to access vector components both via array-style
 *      subscripting and by using the "." operator with component names
 *      "x", "y", "z", "w", and permutations thereof.
 *
 *    - There are also some named subvectors: .lo and .hi are the first
 *      and second halves of a vector, and .even and .odd are the even-
 *      and odd-indexed elements of a vector.
 *
 *    - Clang provides some useful builtins that operate on these vector
 *      types: __builtin_shufflevector and __builtin_convertvector.
 *
 *    - The <simd/simd.h> headers define a large assortment of vector and
 *      matrix operations that work on these types.
 *
 *    - You can also use the simd types with the architecture-specific
 *      intrinsics defined in <immintrin.h> and <arm_neon.h>.
 *
 *  The following vector types are defined by this header:
 *
 *    simd_charN   where N is 1, 2, 3, 4, 8, 16, 32, or 64.
 *    simd_ucharN  where N is 1, 2, 3, 4, 8, 16, 32, or 64.
 *    simd_shortN  where N is 1, 2, 3, 4, 8, 16, or 32.
 *    simd_ushortN where N is 1, 2, 3, 4, 8, 16, or 32.
 *    simd_intN    where N is 1, 2, 3, 4, 8, or 16.
 *    simd_uintN   where N is 1, 2, 3, 4, 8, or 16.
 *    simd_floatN  where N is 1, 2, 3, 4, 8, or 16.
 *    simd_longN   where N is 1, 2, 3, 4, or 8.
 *    simd_ulongN  where N is 1, 2, 3, 4, or 8.
 *    simd_doubleN where N is 1, 2, 3, 4, or 8.
 *
 *  These types generally have greater alignment than the underlying scalar
 *  type; they are aligned to either the size of the vector[1] or 16 bytes,
 *  whichever is smaller.
 *
 *    [1] Note that sizeof a three-element vector is the same as sizeof the
 *    corresponding four-element vector, because three-element vectors have
 *    a hidden lane of padding.
 *
 *  In earlier versions of the simd library, the alignment of vectors could
 *  be larger than 16B, up to the "architectural vector size" of 16, 32, or
 *  64B, depending on what options were passed on the command line when
 *  compiling. This super-alignment does not interact well with malloc, and
 *  makes it difficult for libraries to provide a stable API, while conferring
 *  relatively little performance benefit, so it has been relaxed.
 *
 *  For each simd_typeN type where N is not 1 or 3, there is also a
 *  corresponding simd_packed_typeN type that requires only the alignment
 *  matching that of the underlying scalar type. Use this if you need to
 *  work with pointers-to or arrays-of scalar values:
 *
 *    void myFunction(float *pointerToFourFloats) {
 *      // This is a bug, because `pointerToFourFloats` does not satisfy
 *      // the alignment requirements of the `simd_float4` type; attempting
 *      // to dereference (load from) `vecptr` is likely to crash at runtime.
 *      simd_float4 *vecptr = (simd_float4 *)pointerToFourFloats;
 *
 *      // Instead, convert to `simd_packed_float4`:
 *      simd_packed_float4 *vecptr = (simd_packed_float4 *)pointerToFourFloats;
 *      // The `simd_packed_float4` type has the same alignment requirements
 *      // as `float`, so this conversion is safe, and lets us load a vector.
 *      // Note that `simd_packed_float4` can be assigned to `simd_float4`
 *      // without any conversion; they types only behave differently as
 *      // pointers or arrays.
 *      simd_float4 vector = vecptr[0];
 *    }
 *
 *  All of the simd_-prefixed types are also available in the C++ simd::
 *  namespace; simd_char4 can be used as simd::char4, for example. These types
 *  largely match the Metal shader language vector types, except that there
 *  are no vector types larger than 4 elements in Metal.
 *
 *  @copyright 2014-2017 Apple, Inc. All rights reserved.
 *  @unsorted                                                                 */

#ifndef SIMD_VECTOR_TYPES
#define SIMD_VECTOR_TYPES

# include <simd/base.h>
# if SIMD_COMPILER_HAS_REQUIRED_FEATURES

/*  MARK: Basic vector types                                                  */

/*! @group C and Objective-C vector types
 *  @discussion These are the basic types that underpin the simd library.     */

/*! @abstract A scalar 8-bit signed (twos-complement) integer.                */
typedef char simd_char1;

/*! @abstract A vector of two 8-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::char2. The alignment of this type is greater than the alignment of
 *  char; if you need to operate on data buffers that may not be suitably
 *  aligned, you should access them using simd_packed_char2 instead.          */
typedef __attribute__((__ext_vector_type__(2))) char simd_char2;

/*! @abstract A vector of three 8-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::char3. Note that vectors of this type are padded to have the same
 *  size and alignment as simd_char4.                                         */
typedef __attribute__((__ext_vector_type__(3))) char simd_char3;

/*! @abstract A vector of four 8-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::char4. The alignment of this type is greater than the alignment of
 *  char; if you need to operate on data buffers that may not be suitably
 *  aligned, you should access them using simd_packed_char4 instead.          */
typedef __attribute__((__ext_vector_type__(4))) char simd_char4;

/*! @abstract A vector of eight 8-bit signed (twos-complement) integers.
 *  @description In C++ this type is also available as simd::char8. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of char; if you need to operate on data buffers that
 *  may not be suitably aligned, you should access them using
 *  simd_packed_char8 instead.                                                */
typedef __attribute__((__ext_vector_type__(8))) char simd_char8;

/*! @abstract A vector of sixteen 8-bit signed (twos-complement) integers.
 *  @description In C++ this type is also available as simd::char16. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of char; if you need to operate on data buffers that
 *  may not be suitably aligned, you should access them using
 *  simd_packed_char16 instead.                                               */
typedef __attribute__((__ext_vector_type__(16))) char simd_char16;

/*! @abstract A vector of thirty-two 8-bit signed (twos-complement)
 *  integers.
 *  @description In C++ this type is also available as simd::char32. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of char; if you need to operate on data buffers that
 *  may not be suitably aligned, you should access them using
 *  simd_packed_char32 instead.                                               */
typedef __attribute__((__ext_vector_type__(32),__aligned__(16))) char simd_char32;

/*! @abstract A vector of sixty-four 8-bit signed (twos-complement)
 *  integers.
 *  @description In C++ this type is also available as simd::char64. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of char; if you need to operate on data buffers that
 *  may not be suitably aligned, you should access them using
 *  simd_packed_char64 instead.                                               */
typedef __attribute__((__ext_vector_type__(64),__aligned__(16))) char simd_char64;

/*! @abstract A scalar 8-bit unsigned integer.                                */
typedef unsigned char simd_uchar1;

/*! @abstract A vector of two 8-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::uchar2. The alignment of this type is greater than the alignment
 *  of unsigned char; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_uchar2
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(2))) unsigned char simd_uchar2;

/*! @abstract A vector of three 8-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::uchar3. Note that vectors of this type are padded to have the same
 *  size and alignment as simd_uchar4.                                        */
typedef __attribute__((__ext_vector_type__(3))) unsigned char simd_uchar3;

/*! @abstract A vector of four 8-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::uchar4. The alignment of this type is greater than the alignment
 *  of unsigned char; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_uchar4
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(4))) unsigned char simd_uchar4;

/*! @abstract A vector of eight 8-bit unsigned integers.
 *  @description In C++ this type is also available as simd::uchar8. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of unsigned char; if you need to operate on data
 *  buffers that may not be suitably aligned, you should access them using
 *  simd_packed_uchar8 instead.                                               */
typedef __attribute__((__ext_vector_type__(8))) unsigned char simd_uchar8;

/*! @abstract A vector of sixteen 8-bit unsigned integers.
 *  @description In C++ this type is also available as simd::uchar16. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of unsigned char; if you need to operate on data
 *  buffers that may not be suitably aligned, you should access them using
 *  simd_packed_uchar16 instead.                                              */
typedef __attribute__((__ext_vector_type__(16))) unsigned char simd_uchar16;

/*! @abstract A vector of thirty-two 8-bit unsigned integers.
 *  @description In C++ this type is also available as simd::uchar32. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of unsigned char; if you need to operate on data
 *  buffers that may not be suitably aligned, you should access them using
 *  simd_packed_uchar32 instead.                                              */
typedef __attribute__((__ext_vector_type__(32),__aligned__(16))) unsigned char simd_uchar32;

/*! @abstract A vector of sixty-four 8-bit unsigned integers.
 *  @description In C++ this type is also available as simd::uchar64. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of unsigned char; if you need to operate on data
 *  buffers that may not be suitably aligned, you should access them using
 *  simd_packed_uchar64 instead.                                              */
typedef __attribute__((__ext_vector_type__(64),__aligned__(16))) unsigned char simd_uchar64;

/*! @abstract A scalar 16-bit signed (twos-complement) integer.               */
typedef short simd_short1;

/*! @abstract A vector of two 16-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::short2. The alignment of this type is greater than the alignment
 *  of short; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_short2
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(2))) short simd_short2;

/*! @abstract A vector of three 16-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::short3. Note that vectors of this type are padded to have the same
 *  size and alignment as simd_short4.                                        */
typedef __attribute__((__ext_vector_type__(3))) short simd_short3;

/*! @abstract A vector of four 16-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::short4. The alignment of this type is greater than the alignment
 *  of short; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_short4
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(4))) short simd_short4;

/*! @abstract A vector of eight 16-bit signed (twos-complement) integers.
 *  @description In C++ this type is also available as simd::short8. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of short; if you need to operate on data buffers that
 *  may not be suitably aligned, you should access them using
 *  simd_packed_short8 instead.                                               */
typedef __attribute__((__ext_vector_type__(8))) short simd_short8;

/*! @abstract A vector of sixteen 16-bit signed (twos-complement) integers.
 *  @description In C++ this type is also available as simd::short16. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of short; if you need to operate on data buffers that
 *  may not be suitably aligned, you should access them using
 *  simd_packed_short16 instead.                                              */
typedef __attribute__((__ext_vector_type__(16),__aligned__(16))) short simd_short16;

/*! @abstract A vector of thirty-two 16-bit signed (twos-complement)
 *  integers.
 *  @description In C++ this type is also available as simd::short32. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of short; if you need to operate on data buffers that
 *  may not be suitably aligned, you should access them using
 *  simd_packed_short32 instead.                                              */
typedef __attribute__((__ext_vector_type__(32),__aligned__(16))) short simd_short32;

/*! @abstract A scalar 16-bit unsigned integer.                               */
typedef unsigned short simd_ushort1;

/*! @abstract A vector of two 16-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::ushort2. The alignment of this type is greater than the alignment
 *  of unsigned short; if you need to operate on data buffers that may not
 *  be suitably aligned, you should access them using simd_packed_ushort2
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(2))) unsigned short simd_ushort2;

/*! @abstract A vector of three 16-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::ushort3. Note that vectors of this type are padded to have the
 *  same size and alignment as simd_ushort4.                                  */
typedef __attribute__((__ext_vector_type__(3))) unsigned short simd_ushort3;

/*! @abstract A vector of four 16-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::ushort4. The alignment of this type is greater than the alignment
 *  of unsigned short; if you need to operate on data buffers that may not
 *  be suitably aligned, you should access them using simd_packed_ushort4
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(4))) unsigned short simd_ushort4;

/*! @abstract A vector of eight 16-bit unsigned integers.
 *  @description In C++ this type is also available as simd::ushort8. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of unsigned short; if you need to operate on data
 *  buffers that may not be suitably aligned, you should access them using
 *  simd_packed_ushort8 instead.                                              */
typedef __attribute__((__ext_vector_type__(8))) unsigned short simd_ushort8;

/*! @abstract A vector of sixteen 16-bit unsigned integers.
 *  @description In C++ this type is also available as simd::ushort16. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of unsigned short; if you need to operate on data
 *  buffers that may not be suitably aligned, you should access them using
 *  simd_packed_ushort16 instead.                                             */
typedef __attribute__((__ext_vector_type__(16),__aligned__(16))) unsigned short simd_ushort16;

/*! @abstract A vector of thirty-two 16-bit unsigned integers.
 *  @description In C++ this type is also available as simd::ushort32. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of unsigned short; if you need to operate on data
 *  buffers that may not be suitably aligned, you should access them using
 *  simd_packed_ushort32 instead.                                             */
typedef __attribute__((__ext_vector_type__(32),__aligned__(16))) unsigned short simd_ushort32;

/*! @abstract A scalar 32-bit signed (twos-complement) integer.               */
typedef int simd_int1;

/*! @abstract A vector of two 32-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::int2. The alignment of this type is greater than the alignment of
 *  int; if you need to operate on data buffers that may not be suitably
 *  aligned, you should access them using simd_packed_int2 instead.           */
typedef __attribute__((__ext_vector_type__(2))) int simd_int2;

/*! @abstract A vector of three 32-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::int3. Note that vectors of this type are padded to have the same
 *  size and alignment as simd_int4.                                          */
typedef __attribute__((__ext_vector_type__(3))) int simd_int3;

/*! @abstract A vector of four 32-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::int4. The alignment of this type is greater than the alignment of
 *  int; if you need to operate on data buffers that may not be suitably
 *  aligned, you should access them using simd_packed_int4 instead.           */
typedef __attribute__((__ext_vector_type__(4))) int simd_int4;

/*! @abstract A vector of eight 32-bit signed (twos-complement) integers.
 *  @description In C++ this type is also available as simd::int8. This type
 *  is not available in Metal. The alignment of this type is greater than
 *  the alignment of int; if you need to operate on data buffers that may
 *  not be suitably aligned, you should access them using simd_packed_int8
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(8),__aligned__(16))) int simd_int8;

/*! @abstract A vector of sixteen 32-bit signed (twos-complement) integers.
 *  @description In C++ this type is also available as simd::int16. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of int; if you need to operate on data buffers that
 *  may not be suitably aligned, you should access them using
 *  simd_packed_int16 instead.                                                */
typedef __attribute__((__ext_vector_type__(16),__aligned__(16))) int simd_int16;

/*! @abstract A scalar 32-bit unsigned integer.                               */
typedef unsigned int simd_uint1;

/*! @abstract A vector of two 32-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::uint2. The alignment of this type is greater than the alignment of
 *  unsigned int; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_uint2
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(2))) unsigned int simd_uint2;

/*! @abstract A vector of three 32-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::uint3. Note that vectors of this type are padded to have the same
 *  size and alignment as simd_uint4.                                         */
typedef __attribute__((__ext_vector_type__(3))) unsigned int simd_uint3;

/*! @abstract A vector of four 32-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::uint4. The alignment of this type is greater than the alignment of
 *  unsigned int; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_uint4
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(4))) unsigned int simd_uint4;

/*! @abstract A vector of eight 32-bit unsigned integers.
 *  @description In C++ this type is also available as simd::uint8. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of unsigned int; if you need to operate on data
 *  buffers that may not be suitably aligned, you should access them using
 *  simd_packed_uint8 instead.                                                */
typedef __attribute__((__ext_vector_type__(8),__aligned__(16))) unsigned int simd_uint8;

/*! @abstract A vector of sixteen 32-bit unsigned integers.
 *  @description In C++ this type is also available as simd::uint16. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of unsigned int; if you need to operate on data
 *  buffers that may not be suitably aligned, you should access them using
 *  simd_packed_uint16 instead.                                               */
typedef __attribute__((__ext_vector_type__(16),__aligned__(16))) unsigned int simd_uint16;

/*! @abstract A scalar 32-bit floating-point number.                          */
typedef float simd_float1;

/*! @abstract A vector of two 32-bit floating-point numbers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::float2. The alignment of this type is greater than the alignment
 *  of float; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_float2
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(2))) float simd_float2;

/*! @abstract A vector of three 32-bit floating-point numbers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::float3. Note that vectors of this type are padded to have the same
 *  size and alignment as simd_float4.                                        */
typedef __attribute__((__ext_vector_type__(3))) float simd_float3;

/*! @abstract A vector of four 32-bit floating-point numbers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::float4. The alignment of this type is greater than the alignment
 *  of float; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_float4
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(4))) float simd_float4;

/*! @abstract A vector of eight 32-bit floating-point numbers.
 *  @description In C++ this type is also available as simd::float8. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of float; if you need to operate on data buffers that
 *  may not be suitably aligned, you should access them using
 *  simd_packed_float8 instead.                                               */
typedef __attribute__((__ext_vector_type__(8),__aligned__(16))) float simd_float8;

/*! @abstract A vector of sixteen 32-bit floating-point numbers.
 *  @description In C++ this type is also available as simd::float16. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of float; if you need to operate on data buffers that
 *  may not be suitably aligned, you should access them using
 *  simd_packed_float16 instead.                                              */
typedef __attribute__((__ext_vector_type__(16),__aligned__(16))) float simd_float16;

/*! @abstract A scalar 64-bit signed (twos-complement) integer.               */
#if defined __LP64__
typedef long simd_long1;
#else
typedef long long simd_long1;
#endif

/*! @abstract A vector of two 64-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::long2. The alignment of this type is greater than the alignment of
 *  simd_long1; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_long2
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(2))) simd_long1 simd_long2;

/*! @abstract A vector of three 64-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::long3. Note that vectors of this type are padded to have the same
 *  size and alignment as simd_long4.                                         */
typedef __attribute__((__ext_vector_type__(3),__aligned__(16))) simd_long1 simd_long3;

/*! @abstract A vector of four 64-bit signed (twos-complement) integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::long4. The alignment of this type is greater than the alignment of
 *  simd_long1; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_long4
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(4),__aligned__(16))) simd_long1 simd_long4;

/*! @abstract A vector of eight 64-bit signed (twos-complement) integers.
 *  @description In C++ this type is also available as simd::long8. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of simd_long1; if you need to operate on data buffers
 *  that may not be suitably aligned, you should access them using
 *  simd_packed_long8 instead.                                                */
typedef __attribute__((__ext_vector_type__(8),__aligned__(16))) simd_long1 simd_long8;

/*! @abstract A scalar 64-bit unsigned integer.                               */
#if defined __LP64__
typedef unsigned long simd_ulong1;
#else
typedef unsigned long long simd_ulong1;
#endif

/*! @abstract A vector of two 64-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::ulong2. The alignment of this type is greater than the alignment
 *  of simd_ulong1; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_ulong2
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(2))) simd_ulong1 simd_ulong2;

/*! @abstract A vector of three 64-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::ulong3. Note that vectors of this type are padded to have the same
 *  size and alignment as simd_ulong4.                                        */
typedef __attribute__((__ext_vector_type__(3),__aligned__(16))) simd_ulong1 simd_ulong3;

/*! @abstract A vector of four 64-bit unsigned integers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::ulong4. The alignment of this type is greater than the alignment
 *  of simd_ulong1; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_ulong4
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(4),__aligned__(16))) simd_ulong1 simd_ulong4;

/*! @abstract A vector of eight 64-bit unsigned integers.
 *  @description In C++ this type is also available as simd::ulong8. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of simd_ulong1; if you need to operate on data
 *  buffers that may not be suitably aligned, you should access them using
 *  simd_packed_ulong8 instead.                                               */
typedef __attribute__((__ext_vector_type__(8),__aligned__(16))) simd_ulong1 simd_ulong8;

/*! @abstract A scalar 64-bit floating-point number.                          */
typedef double simd_double1;

/*! @abstract A vector of two 64-bit floating-point numbers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::double2. The alignment of this type is greater than the alignment
 *  of double; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_double2
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(2))) double simd_double2;

/*! @abstract A vector of three 64-bit floating-point numbers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::double3. Note that vectors of this type are padded to have the
 *  same size and alignment as simd_double4.                                  */
typedef __attribute__((__ext_vector_type__(3),__aligned__(16))) double simd_double3;

/*! @abstract A vector of four 64-bit floating-point numbers.
 *  @description In C++ and Metal, this type is also available as
 *  simd::double4. The alignment of this type is greater than the alignment
 *  of double; if you need to operate on data buffers that may not be
 *  suitably aligned, you should access them using simd_packed_double4
 *  instead.                                                                  */
typedef __attribute__((__ext_vector_type__(4),__aligned__(16))) double simd_double4;

/*! @abstract A vector of eight 64-bit floating-point numbers.
 *  @description In C++ this type is also available as simd::double8. This
 *  type is not available in Metal. The alignment of this type is greater
 *  than the alignment of double; if you need to operate on data buffers
 *  that may not be suitably aligned, you should access them using
 *  simd_packed_double8 instead.                                              */
typedef __attribute__((__ext_vector_type__(8),__aligned__(16))) double simd_double8;

/*  MARK: C++ vector types                                                    */
#if defined __cplusplus
/*! @group C++ and Metal vector types
 *  @discussion Shorter type names available within the simd:: namespace.
 *  Each of these types is interchangable with the corresponding C type 
 *  with the `simd_` prefix.                                                  */
namespace simd {
  /*! @abstract A scalar 8-bit signed (twos-complement) integer.
   *  @discussion In C and Objective-C, this type is available as
   *  simd_char1.                                                             */
typedef ::simd_char1 char1;
  
  /*! @abstract A vector of two 8-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_char2. The alignment of this type is greater than the alignment
   *  of char; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_char2
   *  instead.                                                                */
typedef ::simd_char2 char2;
  
  /*! @abstract A vector of three 8-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_char3. Vectors of this type are padded to have the same size and
   *  alignment as simd_char4.                                                */
typedef ::simd_char3 char3;
  
  /*! @abstract A vector of four 8-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_char4. The alignment of this type is greater than the alignment
   *  of char; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_char4
   *  instead.                                                                */
typedef ::simd_char4 char4;
  
  /*! @abstract A vector of eight 8-bit signed (twos-complement) integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_char8. The alignment of this type is
   *  greater than the alignment of char; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_char8 instead.                                             */
typedef ::simd_char8 char8;
  
  /*! @abstract A vector of sixteen 8-bit signed (twos-complement) integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_char16. The alignment of this type is
   *  greater than the alignment of char; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_char16 instead.                                            */
typedef ::simd_char16 char16;
  
  /*! @abstract A vector of thirty-two 8-bit signed (twos-complement)
   *  integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_char32. The alignment of this type is
   *  greater than the alignment of char; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_char32 instead.                                            */
typedef ::simd_char32 char32;
  
  /*! @abstract A vector of sixty-four 8-bit signed (twos-complement)
   *  integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_char64. The alignment of this type is
   *  greater than the alignment of char; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_char64 instead.                                            */
typedef ::simd_char64 char64;
  
  /*! @abstract A scalar 8-bit unsigned integer.
   *  @discussion In C and Objective-C, this type is available as
   *  simd_uchar1.                                                            */
typedef ::simd_uchar1 uchar1;
  
  /*! @abstract A vector of two 8-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_uchar2. The alignment of this type is greater than the alignment
   *  of unsigned char; if you need to operate on data buffers that may not
   *  be suitably aligned, you should access them using simd::packed_uchar2
   *  instead.                                                                */
typedef ::simd_uchar2 uchar2;
  
  /*! @abstract A vector of three 8-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_uchar3. Vectors of this type are padded to have the same size and
   *  alignment as simd_uchar4.                                               */
typedef ::simd_uchar3 uchar3;
  
  /*! @abstract A vector of four 8-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_uchar4. The alignment of this type is greater than the alignment
   *  of unsigned char; if you need to operate on data buffers that may not
   *  be suitably aligned, you should access them using simd::packed_uchar4
   *  instead.                                                                */
typedef ::simd_uchar4 uchar4;
  
  /*! @abstract A vector of eight 8-bit unsigned integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_uchar8. The alignment of this type is
   *  greater than the alignment of unsigned char; if you need to operate on
   *  data buffers that may not be suitably aligned, you should access them
   *  using simd::packed_uchar8 instead.                                      */
typedef ::simd_uchar8 uchar8;
  
  /*! @abstract A vector of sixteen 8-bit unsigned integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_uchar16. The alignment of this type is
   *  greater than the alignment of unsigned char; if you need to operate on
   *  data buffers that may not be suitably aligned, you should access them
   *  using simd::packed_uchar16 instead.                                     */
typedef ::simd_uchar16 uchar16;
  
  /*! @abstract A vector of thirty-two 8-bit unsigned integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_uchar32. The alignment of this type is
   *  greater than the alignment of unsigned char; if you need to operate on
   *  data buffers that may not be suitably aligned, you should access them
   *  using simd::packed_uchar32 instead.                                     */
typedef ::simd_uchar32 uchar32;
  
  /*! @abstract A vector of sixty-four 8-bit unsigned integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_uchar64. The alignment of this type is
   *  greater than the alignment of unsigned char; if you need to operate on
   *  data buffers that may not be suitably aligned, you should access them
   *  using simd::packed_uchar64 instead.                                     */
typedef ::simd_uchar64 uchar64;
  
  /*! @abstract A scalar 16-bit signed (twos-complement) integer.
   *  @discussion In C and Objective-C, this type is available as
   *  simd_short1.                                                            */
typedef ::simd_short1 short1;
  
  /*! @abstract A vector of two 16-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_short2. The alignment of this type is greater than the alignment
   *  of short; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_short2
   *  instead.                                                                */
typedef ::simd_short2 short2;
  
  /*! @abstract A vector of three 16-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_short3. Vectors of this type are padded to have the same size and
   *  alignment as simd_short4.                                               */
typedef ::simd_short3 short3;
  
  /*! @abstract A vector of four 16-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_short4. The alignment of this type is greater than the alignment
   *  of short; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_short4
   *  instead.                                                                */
typedef ::simd_short4 short4;
  
  /*! @abstract A vector of eight 16-bit signed (twos-complement) integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_short8. The alignment of this type is
   *  greater than the alignment of short; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_short8 instead.                                            */
typedef ::simd_short8 short8;
  
  /*! @abstract A vector of sixteen 16-bit signed (twos-complement)
   *  integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_short16. The alignment of this type is
   *  greater than the alignment of short; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_short16 instead.                                           */
typedef ::simd_short16 short16;
  
  /*! @abstract A vector of thirty-two 16-bit signed (twos-complement)
   *  integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_short32. The alignment of this type is
   *  greater than the alignment of short; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_short32 instead.                                           */
typedef ::simd_short32 short32;
  
  /*! @abstract A scalar 16-bit unsigned integer.
   *  @discussion In C and Objective-C, this type is available as
   *  simd_ushort1.                                                           */
typedef ::simd_ushort1 ushort1;
  
  /*! @abstract A vector of two 16-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_ushort2. The alignment of this type is greater than the alignment
   *  of unsigned short; if you need to operate on data buffers that may not
   *  be suitably aligned, you should access them using simd::packed_ushort2
   *  instead.                                                                */
typedef ::simd_ushort2 ushort2;
  
  /*! @abstract A vector of three 16-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_ushort3. Vectors of this type are padded to have the same size
   *  and alignment as simd_ushort4.                                          */
typedef ::simd_ushort3 ushort3;
  
  /*! @abstract A vector of four 16-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_ushort4. The alignment of this type is greater than the alignment
   *  of unsigned short; if you need to operate on data buffers that may not
   *  be suitably aligned, you should access them using simd::packed_ushort4
   *  instead.                                                                */
typedef ::simd_ushort4 ushort4;
  
  /*! @abstract A vector of eight 16-bit unsigned integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_ushort8. The alignment of this type is
   *  greater than the alignment of unsigned short; if you need to operate
   *  on data buffers that may not be suitably aligned, you should access
   *  them using simd::packed_ushort8 instead.                                */
typedef ::simd_ushort8 ushort8;
  
  /*! @abstract A vector of sixteen 16-bit unsigned integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_ushort16. The alignment of this type is
   *  greater than the alignment of unsigned short; if you need to operate
   *  on data buffers that may not be suitably aligned, you should access
   *  them using simd::packed_ushort16 instead.                               */
typedef ::simd_ushort16 ushort16;
  
  /*! @abstract A vector of thirty-two 16-bit unsigned integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_ushort32. The alignment of this type is
   *  greater than the alignment of unsigned short; if you need to operate
   *  on data buffers that may not be suitably aligned, you should access
   *  them using simd::packed_ushort32 instead.                               */
typedef ::simd_ushort32 ushort32;
  
  /*! @abstract A scalar 32-bit signed (twos-complement) integer.
   *  @discussion In C and Objective-C, this type is available as simd_int1.  */
typedef ::simd_int1 int1;
  
  /*! @abstract A vector of two 32-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as simd_int2.
   *  The alignment of this type is greater than the alignment of int; if
   *  you need to operate on data buffers that may not be suitably aligned,
   *  you should access them using simd::packed_int2 instead.                 */
typedef ::simd_int2 int2;
  
  /*! @abstract A vector of three 32-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as simd_int3.
   *  Vectors of this type are padded to have the same size and alignment as
   *  simd_int4.                                                              */
typedef ::simd_int3 int3;
  
  /*! @abstract A vector of four 32-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as simd_int4.
   *  The alignment of this type is greater than the alignment of int; if
   *  you need to operate on data buffers that may not be suitably aligned,
   *  you should access them using simd::packed_int4 instead.                 */
typedef ::simd_int4 int4;
  
  /*! @abstract A vector of eight 32-bit signed (twos-complement) integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_int8. The alignment of this type is
   *  greater than the alignment of int; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_int8 instead.                                              */
typedef ::simd_int8 int8;
  
  /*! @abstract A vector of sixteen 32-bit signed (twos-complement)
   *  integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_int16. The alignment of this type is
   *  greater than the alignment of int; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_int16 instead.                                             */
typedef ::simd_int16 int16;
  
  /*! @abstract A scalar 32-bit unsigned integer.
   *  @discussion In C and Objective-C, this type is available as
   *  simd_uint1.                                                             */
typedef ::simd_uint1 uint1;
  
  /*! @abstract A vector of two 32-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_uint2. The alignment of this type is greater than the alignment
   *  of unsigned int; if you need to operate on data buffers that may not
   *  be suitably aligned, you should access them using simd::packed_uint2
   *  instead.                                                                */
typedef ::simd_uint2 uint2;
  
  /*! @abstract A vector of three 32-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_uint3. Vectors of this type are padded to have the same size and
   *  alignment as simd_uint4.                                                */
typedef ::simd_uint3 uint3;
  
  /*! @abstract A vector of four 32-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_uint4. The alignment of this type is greater than the alignment
   *  of unsigned int; if you need to operate on data buffers that may not
   *  be suitably aligned, you should access them using simd::packed_uint4
   *  instead.                                                                */
typedef ::simd_uint4 uint4;
  
  /*! @abstract A vector of eight 32-bit unsigned integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_uint8. The alignment of this type is
   *  greater than the alignment of unsigned int; if you need to operate on
   *  data buffers that may not be suitably aligned, you should access them
   *  using simd::packed_uint8 instead.                                       */
typedef ::simd_uint8 uint8;
  
  /*! @abstract A vector of sixteen 32-bit unsigned integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_uint16. The alignment of this type is
   *  greater than the alignment of unsigned int; if you need to operate on
   *  data buffers that may not be suitably aligned, you should access them
   *  using simd::packed_uint16 instead.                                      */
typedef ::simd_uint16 uint16;
  
  /*! @abstract A scalar 32-bit floating-point number.
   *  @discussion In C and Objective-C, this type is available as
   *  simd_float1.                                                            */
typedef ::simd_float1 float1;
  
  /*! @abstract A vector of two 32-bit floating-point numbers.
   *  @description In C or Objective-C, this type is available as
   *  simd_float2. The alignment of this type is greater than the alignment
   *  of float; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_float2
   *  instead.                                                                */
typedef ::simd_float2 float2;
  
  /*! @abstract A vector of three 32-bit floating-point numbers.
   *  @description In C or Objective-C, this type is available as
   *  simd_float3. Vectors of this type are padded to have the same size and
   *  alignment as simd_float4.                                               */
typedef ::simd_float3 float3;
  
  /*! @abstract A vector of four 32-bit floating-point numbers.
   *  @description In C or Objective-C, this type is available as
   *  simd_float4. The alignment of this type is greater than the alignment
   *  of float; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_float4
   *  instead.                                                                */
typedef ::simd_float4 float4;
  
  /*! @abstract A vector of eight 32-bit floating-point numbers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_float8. The alignment of this type is
   *  greater than the alignment of float; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_float8 instead.                                            */
typedef ::simd_float8 float8;
  
  /*! @abstract A vector of sixteen 32-bit floating-point numbers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_float16. The alignment of this type is
   *  greater than the alignment of float; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_float16 instead.                                           */
typedef ::simd_float16 float16;
  
  /*! @abstract A scalar 64-bit signed (twos-complement) integer.
   *  @discussion In C and Objective-C, this type is available as
   *  simd_long1.                                                             */
typedef ::simd_long1 long1;
  
  /*! @abstract A vector of two 64-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_long2. The alignment of this type is greater than the alignment
   *  of simd_long1; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_long2
   *  instead.                                                                */
typedef ::simd_long2 long2;
  
  /*! @abstract A vector of three 64-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_long3. Vectors of this type are padded to have the same size and
   *  alignment as simd_long4.                                                */
typedef ::simd_long3 long3;
  
  /*! @abstract A vector of four 64-bit signed (twos-complement) integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_long4. The alignment of this type is greater than the alignment
   *  of simd_long1; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_long4
   *  instead.                                                                */
typedef ::simd_long4 long4;
  
  /*! @abstract A vector of eight 64-bit signed (twos-complement) integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_long8. The alignment of this type is
   *  greater than the alignment of simd_long1; if you need to operate on
   *  data buffers that may not be suitably aligned, you should access them
   *  using simd::packed_long8 instead.                                       */
typedef ::simd_long8 long8;
  
  /*! @abstract A scalar 64-bit unsigned integer.
   *  @discussion In C and Objective-C, this type is available as
   *  simd_ulong1.                                                            */
typedef ::simd_ulong1 ulong1;
  
  /*! @abstract A vector of two 64-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_ulong2. The alignment of this type is greater than the alignment
   *  of simd_ulong1; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_ulong2
   *  instead.                                                                */
typedef ::simd_ulong2 ulong2;
  
  /*! @abstract A vector of three 64-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_ulong3. Vectors of this type are padded to have the same size and
   *  alignment as simd_ulong4.                                               */
typedef ::simd_ulong3 ulong3;
  
  /*! @abstract A vector of four 64-bit unsigned integers.
   *  @description In C or Objective-C, this type is available as
   *  simd_ulong4. The alignment of this type is greater than the alignment
   *  of simd_ulong1; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_ulong4
   *  instead.                                                                */
typedef ::simd_ulong4 ulong4;
  
  /*! @abstract A vector of eight 64-bit unsigned integers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_ulong8. The alignment of this type is
   *  greater than the alignment of simd_ulong1; if you need to operate on
   *  data buffers that may not be suitably aligned, you should access them
   *  using simd::packed_ulong8 instead.                                      */
typedef ::simd_ulong8 ulong8;
  
  /*! @abstract A scalar 64-bit floating-point number.
   *  @discussion In C and Objective-C, this type is available as
   *  simd_double1.                                                           */
typedef ::simd_double1 double1;
  
  /*! @abstract A vector of two 64-bit floating-point numbers.
   *  @description In C or Objective-C, this type is available as
   *  simd_double2. The alignment of this type is greater than the alignment
   *  of double; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_double2
   *  instead.                                                                */
typedef ::simd_double2 double2;
  
  /*! @abstract A vector of three 64-bit floating-point numbers.
   *  @description In C or Objective-C, this type is available as
   *  simd_double3. Vectors of this type are padded to have the same size
   *  and alignment as simd_double4.                                          */
typedef ::simd_double3 double3;
  
  /*! @abstract A vector of four 64-bit floating-point numbers.
   *  @description In C or Objective-C, this type is available as
   *  simd_double4. The alignment of this type is greater than the alignment
   *  of double; if you need to operate on data buffers that may not be
   *  suitably aligned, you should access them using simd::packed_double4
   *  instead.                                                                */
typedef ::simd_double4 double4;
  
  /*! @abstract A vector of eight 64-bit floating-point numbers.
   *  @description This type is not available in Metal. In C or Objective-C,
   *  this type is available as simd_double8. The alignment of this type is
   *  greater than the alignment of double; if you need to operate on data
   *  buffers that may not be suitably aligned, you should access them using
   *  simd::packed_double8 instead.                                           */
typedef ::simd_double8 double8;
  
} /* namespace simd::                                                         */
#endif /* __cplusplus                                                         */

/*  MARK: Deprecated vector types                                             */
/*! @group Deprecated vector types
 *  @discussion These are the original types used by earlier versions of the
 *  simd library; they are provided here for compatability with existing source
 *  files. Use the new ("simd_"-prefixed) types for future development.       */

/*! @abstract A vector of two 8-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_char2 or
 *  simd::char2 instead.                                                      */
typedef simd_char2 vector_char2;

/*! @abstract A vector of three 8-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_char3 or
 *  simd::char3 instead.                                                      */
typedef simd_char3 vector_char3;

/*! @abstract A vector of four 8-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_char4 or
 *  simd::char4 instead.                                                      */
typedef simd_char4 vector_char4;

/*! @abstract A vector of eight 8-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_char8 or
 *  simd::char8 instead.                                                      */
typedef simd_char8 vector_char8;

/*! @abstract A vector of sixteen 8-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_char16 or
 *  simd::char16 instead.                                                     */
typedef simd_char16 vector_char16;

/*! @abstract A vector of thirty-two 8-bit signed (twos-complement)
 *  integers.
 *  @description This type is deprecated; you should use simd_char32 or
 *  simd::char32 instead.                                                     */
typedef simd_char32 vector_char32;

/*! @abstract A vector of two 8-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_uchar2 or
 *  simd::uchar2 instead.                                                     */
typedef simd_uchar2 vector_uchar2;

/*! @abstract A vector of three 8-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_uchar3 or
 *  simd::uchar3 instead.                                                     */
typedef simd_uchar3 vector_uchar3;

/*! @abstract A vector of four 8-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_uchar4 or
 *  simd::uchar4 instead.                                                     */
typedef simd_uchar4 vector_uchar4;

/*! @abstract A vector of eight 8-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_uchar8 or
 *  simd::uchar8 instead.                                                     */
typedef simd_uchar8 vector_uchar8;

/*! @abstract A vector of sixteen 8-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_uchar16 or
 *  simd::uchar16 instead.                                                    */
typedef simd_uchar16 vector_uchar16;

/*! @abstract A vector of thirty-two 8-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_uchar32 or
 *  simd::uchar32 instead.                                                    */
typedef simd_uchar32 vector_uchar32;

/*! @abstract A vector of two 16-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_short2 or
 *  simd::short2 instead.                                                     */
typedef simd_short2 vector_short2;

/*! @abstract A vector of three 16-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_short3 or
 *  simd::short3 instead.                                                     */
typedef simd_short3 vector_short3;

/*! @abstract A vector of four 16-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_short4 or
 *  simd::short4 instead.                                                     */
typedef simd_short4 vector_short4;

/*! @abstract A vector of eight 16-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_short8 or
 *  simd::short8 instead.                                                     */
typedef simd_short8 vector_short8;

/*! @abstract A vector of sixteen 16-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_short16 or
 *  simd::short16 instead.                                                    */
typedef simd_short16 vector_short16;

/*! @abstract A vector of thirty-two 16-bit signed (twos-complement)
 *  integers.
 *  @description This type is deprecated; you should use simd_short32 or
 *  simd::short32 instead.                                                    */
typedef simd_short32 vector_short32;

/*! @abstract A vector of two 16-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_ushort2 or
 *  simd::ushort2 instead.                                                    */
typedef simd_ushort2 vector_ushort2;

/*! @abstract A vector of three 16-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_ushort3 or
 *  simd::ushort3 instead.                                                    */
typedef simd_ushort3 vector_ushort3;

/*! @abstract A vector of four 16-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_ushort4 or
 *  simd::ushort4 instead.                                                    */
typedef simd_ushort4 vector_ushort4;

/*! @abstract A vector of eight 16-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_ushort8 or
 *  simd::ushort8 instead.                                                    */
typedef simd_ushort8 vector_ushort8;

/*! @abstract A vector of sixteen 16-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_ushort16 or
 *  simd::ushort16 instead.                                                   */
typedef simd_ushort16 vector_ushort16;

/*! @abstract A vector of thirty-two 16-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_ushort32 or
 *  simd::ushort32 instead.                                                   */
typedef simd_ushort32 vector_ushort32;

/*! @abstract A vector of two 32-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_int2 or
 *  simd::int2 instead.                                                       */
typedef simd_int2 vector_int2;

/*! @abstract A vector of three 32-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_int3 or
 *  simd::int3 instead.                                                       */
typedef simd_int3 vector_int3;

/*! @abstract A vector of four 32-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_int4 or
 *  simd::int4 instead.                                                       */
typedef simd_int4 vector_int4;

/*! @abstract A vector of eight 32-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_int8 or
 *  simd::int8 instead.                                                       */
typedef simd_int8 vector_int8;

/*! @abstract A vector of sixteen 32-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_int16 or
 *  simd::int16 instead.                                                      */
typedef simd_int16 vector_int16;

/*! @abstract A vector of two 32-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_uint2 or
 *  simd::uint2 instead.                                                      */
typedef simd_uint2 vector_uint2;

/*! @abstract A vector of three 32-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_uint3 or
 *  simd::uint3 instead.                                                      */
typedef simd_uint3 vector_uint3;

/*! @abstract A vector of four 32-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_uint4 or
 *  simd::uint4 instead.                                                      */
typedef simd_uint4 vector_uint4;

/*! @abstract A vector of eight 32-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_uint8 or
 *  simd::uint8 instead.                                                      */
typedef simd_uint8 vector_uint8;

/*! @abstract A vector of sixteen 32-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_uint16 or
 *  simd::uint16 instead.                                                     */
typedef simd_uint16 vector_uint16;

/*! @abstract A vector of two 32-bit floating-point numbers.
 *  @description This type is deprecated; you should use simd_float2 or
 *  simd::float2 instead.                                                     */
typedef simd_float2 vector_float2;

/*! @abstract A vector of three 32-bit floating-point numbers.
 *  @description This type is deprecated; you should use simd_float3 or
 *  simd::float3 instead.                                                     */
typedef simd_float3 vector_float3;

/*! @abstract A vector of four 32-bit floating-point numbers.
 *  @description This type is deprecated; you should use simd_float4 or
 *  simd::float4 instead.                                                     */
typedef simd_float4 vector_float4;

/*! @abstract A vector of eight 32-bit floating-point numbers.
 *  @description This type is deprecated; you should use simd_float8 or
 *  simd::float8 instead.                                                     */
typedef simd_float8 vector_float8;

/*! @abstract A vector of sixteen 32-bit floating-point numbers.
 *  @description This type is deprecated; you should use simd_float16 or
 *  simd::float16 instead.                                                    */
typedef simd_float16 vector_float16;

/*! @abstract A scalar 64-bit signed (twos-complement) integer.
 *  @description This type is deprecated; you should use simd_long1 or
 *  simd::long1 instead.                                                      */
typedef simd_long1 vector_long1;

/*! @abstract A vector of two 64-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_long2 or
 *  simd::long2 instead.                                                      */
typedef simd_long2 vector_long2;

/*! @abstract A vector of three 64-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_long3 or
 *  simd::long3 instead.                                                      */
typedef simd_long3 vector_long3;

/*! @abstract A vector of four 64-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_long4 or
 *  simd::long4 instead.                                                      */
typedef simd_long4 vector_long4;

/*! @abstract A vector of eight 64-bit signed (twos-complement) integers.
 *  @description This type is deprecated; you should use simd_long8 or
 *  simd::long8 instead.                                                      */
typedef simd_long8 vector_long8;

/*! @abstract A scalar 64-bit unsigned integer.
 *  @description This type is deprecated; you should use simd_ulong1 or
 *  simd::ulong1 instead.                                                     */
typedef simd_ulong1 vector_ulong1;

/*! @abstract A vector of two 64-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_ulong2 or
 *  simd::ulong2 instead.                                                     */
typedef simd_ulong2 vector_ulong2;

/*! @abstract A vector of three 64-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_ulong3 or
 *  simd::ulong3 instead.                                                     */
typedef simd_ulong3 vector_ulong3;

/*! @abstract A vector of four 64-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_ulong4 or
 *  simd::ulong4 instead.                                                     */
typedef simd_ulong4 vector_ulong4;

/*! @abstract A vector of eight 64-bit unsigned integers.
 *  @description This type is deprecated; you should use simd_ulong8 or
 *  simd::ulong8 instead.                                                     */
typedef simd_ulong8 vector_ulong8;

/*! @abstract A vector of two 64-bit floating-point numbers.
 *  @description This type is deprecated; you should use simd_double2 or
 *  simd::double2 instead.                                                    */
typedef simd_double2 vector_double2;

/*! @abstract A vector of three 64-bit floating-point numbers.
 *  @description This type is deprecated; you should use simd_double3 or
 *  simd::double3 instead.                                                    */
typedef simd_double3 vector_double3;

/*! @abstract A vector of four 64-bit floating-point numbers.
 *  @description This type is deprecated; you should use simd_double4 or
 *  simd::double4 instead.                                                    */
typedef simd_double4 vector_double4;

/*! @abstract A vector of eight 64-bit floating-point numbers.
 *  @description This type is deprecated; you should use simd_double8 or
 *  simd::double8 instead.                                                    */
typedef simd_double8 vector_double8;

# endif /* SIMD_COMPILER_HAS_REQUIRED_FEATURES */
#endif
