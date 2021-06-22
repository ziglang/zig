/*===---- wasm_simd128.h - WebAssembly portable SIMD intrinsics ------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __WASM_SIMD128_H
#define __WASM_SIMD128_H

#include <stdbool.h>
#include <stdint.h>

// User-facing type
typedef int32_t v128_t __attribute__((__vector_size__(16), __aligned__(16)));

// Internal types determined by clang builtin definitions
typedef int32_t __v128_u __attribute__((__vector_size__(16), __aligned__(1)));
typedef signed char __i8x16
    __attribute__((__vector_size__(16), __aligned__(16)));
typedef unsigned char __u8x16
    __attribute__((__vector_size__(16), __aligned__(16)));
typedef short __i16x8 __attribute__((__vector_size__(16), __aligned__(16)));
typedef unsigned short __u16x8
    __attribute__((__vector_size__(16), __aligned__(16)));
typedef int __i32x4 __attribute__((__vector_size__(16), __aligned__(16)));
typedef unsigned int __u32x4
    __attribute__((__vector_size__(16), __aligned__(16)));
typedef long long __i64x2 __attribute__((__vector_size__(16), __aligned__(16)));
typedef unsigned long long __u64x2
    __attribute__((__vector_size__(16), __aligned__(16)));
typedef float __f32x4 __attribute__((__vector_size__(16), __aligned__(16)));
typedef double __f64x2 __attribute__((__vector_size__(16), __aligned__(16)));

typedef signed char __i8x8 __attribute__((__vector_size__(8), __aligned__(8)));
typedef unsigned char __u8x8
    __attribute__((__vector_size__(8), __aligned__(8)));
typedef short __i16x4 __attribute__((__vector_size__(8), __aligned__(8)));
typedef unsigned short __u16x4
    __attribute__((__vector_size__(8), __aligned__(8)));

#define __DEFAULT_FN_ATTRS                                                     \
  __attribute__((__always_inline__, __nodebug__, __target__("simd128"),        \
                 __min_vector_width__(128)))

#define __REQUIRE_CONSTANT(e)                                                  \
  _Static_assert(__builtin_constant_p(e), "Expected constant")

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_v128_load(const void *__mem) {
  // UB-free unaligned access copied from xmmintrin.h
  struct __wasm_v128_load_struct {
    __v128_u __v;
  } __attribute__((__packed__, __may_alias__));
  return ((const struct __wasm_v128_load_struct *)__mem)->__v;
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_v8x16_load_splat(const void *__mem) {
  struct __wasm_v8x16_load_splat_struct {
    uint8_t __v;
  } __attribute__((__packed__, __may_alias__));
  uint8_t __v = ((const struct __wasm_v8x16_load_splat_struct *)__mem)->__v;
  return (v128_t)(__u8x16){__v, __v, __v, __v, __v, __v, __v, __v,
                           __v, __v, __v, __v, __v, __v, __v, __v};
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_v16x8_load_splat(const void *__mem) {
  struct __wasm_v16x8_load_splat_struct {
    uint16_t __v;
  } __attribute__((__packed__, __may_alias__));
  uint16_t __v = ((const struct __wasm_v16x8_load_splat_struct *)__mem)->__v;
  return (v128_t)(__u16x8){__v, __v, __v, __v, __v, __v, __v, __v};
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_v32x4_load_splat(const void *__mem) {
  struct __wasm_v32x4_load_splat_struct {
    uint32_t __v;
  } __attribute__((__packed__, __may_alias__));
  uint32_t __v = ((const struct __wasm_v32x4_load_splat_struct *)__mem)->__v;
  return (v128_t)(__u32x4){__v, __v, __v, __v};
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_v64x2_load_splat(const void *__mem) {
  struct __wasm_v64x2_load_splat_struct {
    uint64_t __v;
  } __attribute__((__packed__, __may_alias__));
  uint64_t __v = ((const struct __wasm_v64x2_load_splat_struct *)__mem)->__v;
  return (v128_t)(__u64x2){__v, __v};
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i16x8_load_8x8(const void *__mem) {
  typedef int8_t __i8x8 __attribute__((__vector_size__(8), __aligned__(8)));
  struct __wasm_i16x8_load_8x8_struct {
    __i8x8 __v;
  } __attribute__((__packed__, __may_alias__));
  __i8x8 __v = ((const struct __wasm_i16x8_load_8x8_struct *)__mem)->__v;
  return (v128_t) __builtin_convertvector(__v, __i16x8);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_u16x8_load_8x8(const void *__mem) {
  typedef uint8_t __u8x8 __attribute__((__vector_size__(8), __aligned__(8)));
  struct __wasm_u16x8_load_8x8_struct {
    __u8x8 __v;
  } __attribute__((__packed__, __may_alias__));
  __u8x8 __v = ((const struct __wasm_u16x8_load_8x8_struct *)__mem)->__v;
  return (v128_t) __builtin_convertvector(__v, __u16x8);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i32x4_load_16x4(const void *__mem) {
  typedef int16_t __i16x4 __attribute__((__vector_size__(8), __aligned__(8)));
  struct __wasm_i32x4_load_16x4_struct {
    __i16x4 __v;
  } __attribute__((__packed__, __may_alias__));
  __i16x4 __v = ((const struct __wasm_i32x4_load_16x4_struct *)__mem)->__v;
  return (v128_t) __builtin_convertvector(__v, __i32x4);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_u32x4_load_16x4(const void *__mem) {
  typedef uint16_t __u16x4 __attribute__((__vector_size__(8), __aligned__(8)));
  struct __wasm_u32x4_load_16x4_struct {
    __u16x4 __v;
  } __attribute__((__packed__, __may_alias__));
  __u16x4 __v = ((const struct __wasm_u32x4_load_16x4_struct *)__mem)->__v;
  return (v128_t) __builtin_convertvector(__v, __u32x4);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i64x2_load_32x2(const void *__mem) {
  typedef int32_t __i32x2 __attribute__((__vector_size__(8), __aligned__(8)));
  struct __wasm_i64x2_load_32x2_struct {
    __i32x2 __v;
  } __attribute__((__packed__, __may_alias__));
  __i32x2 __v = ((const struct __wasm_i64x2_load_32x2_struct *)__mem)->__v;
  return (v128_t) __builtin_convertvector(__v, __i64x2);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_u64x2_load_32x2(const void *__mem) {
  typedef uint32_t __u32x2 __attribute__((__vector_size__(8), __aligned__(8)));
  struct __wasm_u64x2_load_32x2_struct {
    __u32x2 __v;
  } __attribute__((__packed__, __may_alias__));
  __u32x2 __v = ((const struct __wasm_u64x2_load_32x2_struct *)__mem)->__v;
  return (v128_t) __builtin_convertvector(__v, __u64x2);
}

static __inline__ void __DEFAULT_FN_ATTRS wasm_v128_store(void *__mem,
                                                          v128_t __a) {
  // UB-free unaligned access copied from xmmintrin.h
  struct __wasm_v128_store_struct {
    __v128_u __v;
  } __attribute__((__packed__, __may_alias__));
  ((struct __wasm_v128_store_struct *)__mem)->__v = __a;
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i8x16_make(int8_t __c0, int8_t __c1, int8_t __c2, int8_t __c3, int8_t __c4,
                int8_t __c5, int8_t __c6, int8_t __c7, int8_t __c8, int8_t __c9,
                int8_t __c10, int8_t __c11, int8_t __c12, int8_t __c13,
                int8_t __c14, int8_t __c15) {
  return (v128_t)(__i8x16){__c0,  __c1,  __c2,  __c3, __c4,  __c5,
                           __c6,  __c7,  __c8,  __c9, __c10, __c11,
                           __c12, __c13, __c14, __c15};
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i16x8_make(int16_t __c0, int16_t __c1, int16_t __c2, int16_t __c3,
                int16_t __c4, int16_t __c5, int16_t __c6, int16_t __c7) {
  return (v128_t)(__i16x8){__c0, __c1, __c2, __c3, __c4, __c5, __c6, __c7};
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_make(int32_t __c0,
                                                            int32_t __c1,
                                                            int32_t __c2,
                                                            int32_t __c3) {
  return (v128_t)(__i32x4){__c0, __c1, __c2, __c3};
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_make(float __c0,
                                                            float __c1,
                                                            float __c2,
                                                            float __c3) {
  return (v128_t)(__f32x4){__c0, __c1, __c2, __c3};
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i64x2_make(int64_t __c0,
                                                            int64_t __c1) {
  return (v128_t)(__i64x2){__c0, __c1};
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_make(double __c0,
                                                            double __c1) {
  return (v128_t)(__f64x2){__c0, __c1};
}

#define wasm_i8x16_const(__c0, __c1, __c2, __c3, __c4, __c5, __c6, __c7, __c8, \
                         __c9, __c10, __c11, __c12, __c13, __c14, __c15)       \
  __extension__({                                                              \
    __REQUIRE_CONSTANT(__c0);                                                  \
    __REQUIRE_CONSTANT(__c1);                                                  \
    __REQUIRE_CONSTANT(__c2);                                                  \
    __REQUIRE_CONSTANT(__c3);                                                  \
    __REQUIRE_CONSTANT(__c4);                                                  \
    __REQUIRE_CONSTANT(__c5);                                                  \
    __REQUIRE_CONSTANT(__c6);                                                  \
    __REQUIRE_CONSTANT(__c7);                                                  \
    __REQUIRE_CONSTANT(__c8);                                                  \
    __REQUIRE_CONSTANT(__c9);                                                  \
    __REQUIRE_CONSTANT(__c10);                                                 \
    __REQUIRE_CONSTANT(__c11);                                                 \
    __REQUIRE_CONSTANT(__c12);                                                 \
    __REQUIRE_CONSTANT(__c13);                                                 \
    __REQUIRE_CONSTANT(__c14);                                                 \
    __REQUIRE_CONSTANT(__c15);                                                 \
    (v128_t)(__i8x16){__c0, __c1, __c2,  __c3,  __c4,  __c5,  __c6,  __c7,     \
                      __c8, __c9, __c10, __c11, __c12, __c13, __c14, __c15};   \
  })

#define wasm_i16x8_const(__c0, __c1, __c2, __c3, __c4, __c5, __c6, __c7)       \
  __extension__({                                                              \
    __REQUIRE_CONSTANT(__c0);                                                  \
    __REQUIRE_CONSTANT(__c1);                                                  \
    __REQUIRE_CONSTANT(__c2);                                                  \
    __REQUIRE_CONSTANT(__c3);                                                  \
    __REQUIRE_CONSTANT(__c4);                                                  \
    __REQUIRE_CONSTANT(__c5);                                                  \
    __REQUIRE_CONSTANT(__c6);                                                  \
    __REQUIRE_CONSTANT(__c7);                                                  \
    (v128_t)(__i16x8){__c0, __c1, __c2, __c3, __c4, __c5, __c6, __c7};         \
  })

#define wasm_i32x4_const(__c0, __c1, __c2, __c3)                               \
  __extension__({                                                              \
    __REQUIRE_CONSTANT(__c0);                                                  \
    __REQUIRE_CONSTANT(__c1);                                                  \
    __REQUIRE_CONSTANT(__c2);                                                  \
    __REQUIRE_CONSTANT(__c3);                                                  \
    (v128_t)(__i32x4){__c0, __c1, __c2, __c3};                                 \
  })

#define wasm_f32x4_const(__c0, __c1, __c2, __c3)                               \
  __extension__({                                                              \
    __REQUIRE_CONSTANT(__c0);                                                  \
    __REQUIRE_CONSTANT(__c1);                                                  \
    __REQUIRE_CONSTANT(__c2);                                                  \
    __REQUIRE_CONSTANT(__c3);                                                  \
    (v128_t)(__f32x4){__c0, __c1, __c2, __c3};                                 \
  })

#define wasm_i64x2_const(__c0, __c1)                                           \
  __extension__({                                                              \
    __REQUIRE_CONSTANT(__c0);                                                  \
    __REQUIRE_CONSTANT(__c1);                                                  \
    (v128_t)(__i64x2){__c0, __c1};                                             \
  })

#define wasm_f64x2_const(__c0, __c1)                                           \
  __extension__({                                                              \
    __REQUIRE_CONSTANT(__c0);                                                  \
    __REQUIRE_CONSTANT(__c1);                                                  \
    (v128_t)(__f64x2){__c0, __c1};                                             \
  })

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_splat(int8_t __a) {
  return (v128_t)(__i8x16){__a, __a, __a, __a, __a, __a, __a, __a,
                           __a, __a, __a, __a, __a, __a, __a, __a};
}

#define wasm_i8x16_extract_lane(__a, __i)                                      \
  (__builtin_wasm_extract_lane_s_i8x16((__i8x16)(__a), __i))

#define wasm_u8x16_extract_lane(__a, __i)                                      \
  (__builtin_wasm_extract_lane_u_i8x16((__u8x16)(__a), __i))

#define wasm_i8x16_replace_lane(__a, __i, __b)                                 \
  ((v128_t)__builtin_wasm_replace_lane_i8x16((__i8x16)(__a), __i, __b))

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_splat(int16_t __a) {
  return (v128_t)(__i16x8){__a, __a, __a, __a, __a, __a, __a, __a};
}

#define wasm_i16x8_extract_lane(__a, __i)                                      \
  (__builtin_wasm_extract_lane_s_i16x8((__i16x8)(__a), __i))

#define wasm_u16x8_extract_lane(__a, __i)                                      \
  (__builtin_wasm_extract_lane_u_i16x8((__u16x8)(__a), __i))

#define wasm_i16x8_replace_lane(__a, __i, __b)                                 \
  ((v128_t)__builtin_wasm_replace_lane_i16x8((__i16x8)(__a), __i, __b))

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_splat(int32_t __a) {
  return (v128_t)(__i32x4){__a, __a, __a, __a};
}

#define wasm_i32x4_extract_lane(__a, __i)                                      \
  (__builtin_wasm_extract_lane_i32x4((__i32x4)(__a), __i))

#define wasm_i32x4_replace_lane(__a, __i, __b)                                 \
  ((v128_t)__builtin_wasm_replace_lane_i32x4((__i32x4)(__a), __i, __b))

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i64x2_splat(int64_t __a) {
  return (v128_t)(__i64x2){__a, __a};
}

#define wasm_i64x2_extract_lane(__a, __i)                                      \
  (__builtin_wasm_extract_lane_i64x2((__i64x2)(__a), __i))

#define wasm_i64x2_replace_lane(__a, __i, __b)                                 \
  ((v128_t)__builtin_wasm_replace_lane_i64x2((__i64x2)(__a), __i, __b))

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_splat(float __a) {
  return (v128_t)(__f32x4){__a, __a, __a, __a};
}

#define wasm_f32x4_extract_lane(__a, __i)                                      \
  (__builtin_wasm_extract_lane_f32x4((__f32x4)(__a), __i))

#define wasm_f32x4_replace_lane(__a, __i, __b)                                 \
  ((v128_t)__builtin_wasm_replace_lane_f32x4((__f32x4)(__a), __i, __b))

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_splat(double __a) {
  return (v128_t)(__f64x2){__a, __a};
}

#define wasm_f64x2_extract_lane(__a, __i)                                      \
  (__builtin_wasm_extract_lane_f64x2((__f64x2)(__a), __i))

#define wasm_f64x2_replace_lane(__a, __i, __b)                                 \
  ((v128_t)__builtin_wasm_replace_lane_f64x2((__f64x2)(__a), __i, __b))

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_eq(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i8x16)__a == (__i8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_ne(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i8x16)__a != (__i8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_lt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i8x16)__a < (__i8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u8x16_lt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u8x16)__a < (__u8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_gt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i8x16)__a > (__i8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u8x16_gt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u8x16)__a > (__u8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_le(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i8x16)__a <= (__i8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u8x16_le(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u8x16)__a <= (__u8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_ge(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i8x16)__a >= (__i8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u8x16_ge(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u8x16)__a >= (__u8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_eq(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i16x8)__a == (__i16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_ne(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u16x8)__a != (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_lt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i16x8)__a < (__i16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u16x8_lt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u16x8)__a < (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_gt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i16x8)__a > (__i16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u16x8_gt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u16x8)__a > (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_le(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i16x8)__a <= (__i16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u16x8_le(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u16x8)__a <= (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_ge(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i16x8)__a >= (__i16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u16x8_ge(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u16x8)__a >= (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_eq(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i32x4)__a == (__i32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_ne(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i32x4)__a != (__i32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_lt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i32x4)__a < (__i32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u32x4_lt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u32x4)__a < (__u32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_gt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i32x4)__a > (__i32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u32x4_gt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u32x4)__a > (__u32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_le(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i32x4)__a <= (__i32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u32x4_le(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u32x4)__a <= (__u32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_ge(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__i32x4)__a >= (__i32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u32x4_ge(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__u32x4)__a >= (__u32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_eq(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f32x4)__a == (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_ne(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f32x4)__a != (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_lt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f32x4)__a < (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_gt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f32x4)__a > (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_le(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f32x4)__a <= (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_ge(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f32x4)__a >= (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_eq(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f64x2)__a == (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_ne(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f64x2)__a != (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_lt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f64x2)__a < (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_gt(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f64x2)__a > (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_le(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f64x2)__a <= (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_ge(v128_t __a,
                                                          v128_t __b) {
  return (v128_t)((__f64x2)__a >= (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_v128_not(v128_t __a) {
  return ~__a;
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_v128_and(v128_t __a,
                                                          v128_t __b) {
  return __a & __b;
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_v128_or(v128_t __a,
                                                         v128_t __b) {
  return __a | __b;
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_v128_xor(v128_t __a,
                                                          v128_t __b) {
  return __a ^ __b;
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_v128_andnot(v128_t __a,
                                                             v128_t __b) {
  return __a & ~__b;
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_v128_bitselect(v128_t __a,
                                                                v128_t __b,
                                                                v128_t __mask) {
  return (v128_t)__builtin_wasm_bitselect((__i32x4)__a, (__i32x4)__b,
                                          (__i32x4)__mask);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_abs(v128_t __a) {
  return (v128_t)__builtin_wasm_abs_i8x16((__i8x16)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_neg(v128_t __a) {
  return (v128_t)(-(__u8x16)__a);
}

static __inline__ bool __DEFAULT_FN_ATTRS wasm_i8x16_any_true(v128_t __a) {
  return __builtin_wasm_any_true_i8x16((__i8x16)__a);
}

static __inline__ bool __DEFAULT_FN_ATTRS wasm_i8x16_all_true(v128_t __a) {
  return __builtin_wasm_all_true_i8x16((__i8x16)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_shl(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__i8x16)__a << __b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_shr(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__i8x16)__a >> __b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u8x16_shr(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__u8x16)__a >> __b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_add(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__u8x16)__a + (__u8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i8x16_add_saturate(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_add_saturate_s_i8x16((__i8x16)__a,
                                                     (__i8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_u8x16_add_saturate(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_add_saturate_u_i8x16((__u8x16)__a,
                                                     (__u8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_sub(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__u8x16)__a - (__u8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i8x16_sub_saturate(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_sub_saturate_s_i8x16((__i8x16)__a,
                                                     (__i8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_u8x16_sub_saturate(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_sub_saturate_u_i8x16((__u8x16)__a,
                                                     (__u8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_min(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_min_s_i8x16((__i8x16)__a, (__i8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u8x16_min(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_min_u_i8x16((__u8x16)__a, (__u8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i8x16_max(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_max_s_i8x16((__i8x16)__a, (__i8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u8x16_max(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_max_u_i8x16((__u8x16)__a, (__u8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u8x16_avgr(v128_t __a,
                                                            v128_t __b) {
  return (v128_t)__builtin_wasm_avgr_u_i8x16((__u8x16)__a, (__u8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_abs(v128_t __a) {
  return (v128_t)__builtin_wasm_abs_i16x8((__i16x8)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_neg(v128_t __a) {
  return (v128_t)(-(__u16x8)__a);
}

static __inline__ bool __DEFAULT_FN_ATTRS wasm_i16x8_any_true(v128_t __a) {
  return __builtin_wasm_any_true_i16x8((__i16x8)__a);
}

static __inline__ bool __DEFAULT_FN_ATTRS wasm_i16x8_all_true(v128_t __a) {
  return __builtin_wasm_all_true_i16x8((__i16x8)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_shl(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__i16x8)__a << __b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_shr(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__i16x8)__a >> __b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u16x8_shr(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__u16x8)__a >> __b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_add(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__u16x8)__a + (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i16x8_add_saturate(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_add_saturate_s_i16x8((__i16x8)__a,
                                                     (__i16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_u16x8_add_saturate(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_add_saturate_u_i16x8((__u16x8)__a,
                                                     (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_sub(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__i16x8)__a - (__i16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i16x8_sub_saturate(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_sub_saturate_s_i16x8((__i16x8)__a,
                                                     (__i16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_u16x8_sub_saturate(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_sub_saturate_u_i16x8((__u16x8)__a,
                                                     (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_mul(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__u16x8)__a * (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_min(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_min_s_i16x8((__i16x8)__a, (__i16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u16x8_min(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_min_u_i16x8((__u16x8)__a, (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i16x8_max(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_max_s_i16x8((__i16x8)__a, (__i16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u16x8_max(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_max_u_i16x8((__u16x8)__a, (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u16x8_avgr(v128_t __a,
                                                            v128_t __b) {
  return (v128_t)__builtin_wasm_avgr_u_i16x8((__u16x8)__a, (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_abs(v128_t __a) {
  return (v128_t)__builtin_wasm_abs_i32x4((__i32x4)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_neg(v128_t __a) {
  return (v128_t)(-(__u32x4)__a);
}

static __inline__ bool __DEFAULT_FN_ATTRS wasm_i32x4_any_true(v128_t __a) {
  return __builtin_wasm_any_true_i32x4((__i32x4)__a);
}

static __inline__ bool __DEFAULT_FN_ATTRS wasm_i32x4_all_true(v128_t __a) {
  return __builtin_wasm_all_true_i32x4((__i32x4)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_shl(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__i32x4)__a << __b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_shr(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__i32x4)__a >> __b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u32x4_shr(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__u32x4)__a >> __b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_add(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__u32x4)__a + (__u32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_sub(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__u32x4)__a - (__u32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_mul(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__u32x4)__a * (__u32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_min(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_min_s_i32x4((__i32x4)__a, (__i32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u32x4_min(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_min_u_i32x4((__u32x4)__a, (__u32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i32x4_max(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_max_s_i32x4((__i32x4)__a, (__i32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u32x4_max(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_max_u_i32x4((__u32x4)__a, (__u32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i64x2_neg(v128_t __a) {
  return (v128_t)(-(__u64x2)__a);
}

#ifdef __wasm_unimplemented_simd128__

static __inline__ bool __DEFAULT_FN_ATTRS wasm_i64x2_any_true(v128_t __a) {
  return __builtin_wasm_any_true_i64x2((__i64x2)__a);
}

static __inline__ bool __DEFAULT_FN_ATTRS wasm_i64x2_all_true(v128_t __a) {
  return __builtin_wasm_all_true_i64x2((__i64x2)__a);
}

#endif // __wasm_unimplemented_simd128__

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i64x2_shl(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__i64x2)__a << (int64_t)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i64x2_shr(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__i64x2)__a >> (int64_t)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_u64x2_shr(v128_t __a,
                                                           int32_t __b) {
  return (v128_t)((__u64x2)__a >> (int64_t)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i64x2_add(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__u64x2)__a + (__u64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i64x2_sub(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__u64x2)__a - (__u64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_i64x2_mul(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__u64x2)__a * (__u64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_abs(v128_t __a) {
  return (v128_t)__builtin_wasm_abs_f32x4((__f32x4)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_neg(v128_t __a) {
  return (v128_t)(-(__f32x4)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_sqrt(v128_t __a) {
  return (v128_t)__builtin_wasm_sqrt_f32x4((__f32x4)__a);
}

#ifdef __wasm_unimplemented_simd128__

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_qfma(v128_t __a,
                                                            v128_t __b,
                                                            v128_t __c) {
  return (v128_t)__builtin_wasm_qfma_f32x4((__f32x4)__a, (__f32x4)__b,
                                           (__f32x4)__c);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_qfms(v128_t __a,
                                                            v128_t __b,
                                                            v128_t __c) {
  return (v128_t)__builtin_wasm_qfms_f32x4((__f32x4)__a, (__f32x4)__b,
                                           (__f32x4)__c);
}

#endif // __wasm_unimplemented_simd128__

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_add(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__f32x4)__a + (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_sub(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__f32x4)__a - (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_mul(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__f32x4)__a * (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_div(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__f32x4)__a / (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_min(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_min_f32x4((__f32x4)__a, (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_max(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_max_f32x4((__f32x4)__a, (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_pmin(v128_t __a,
                                                            v128_t __b) {
  return (v128_t)__builtin_wasm_pmin_f32x4((__f32x4)__a, (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f32x4_pmax(v128_t __a,
                                                            v128_t __b) {
  return (v128_t)__builtin_wasm_pmax_f32x4((__f32x4)__a, (__f32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_abs(v128_t __a) {
  return (v128_t)__builtin_wasm_abs_f64x2((__f64x2)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_neg(v128_t __a) {
  return (v128_t)(-(__f64x2)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_sqrt(v128_t __a) {
  return (v128_t)__builtin_wasm_sqrt_f64x2((__f64x2)__a);
}

#ifdef __wasm_unimplemented_simd128__

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_qfma(v128_t __a,
                                                            v128_t __b,
                                                            v128_t __c) {
  return (v128_t)__builtin_wasm_qfma_f64x2((__f64x2)__a, (__f64x2)__b,
                                           (__f64x2)__c);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_qfms(v128_t __a,
                                                            v128_t __b,
                                                            v128_t __c) {
  return (v128_t)__builtin_wasm_qfms_f64x2((__f64x2)__a, (__f64x2)__b,
                                           (__f64x2)__c);
}

#endif // __wasm_unimplemented_simd128__

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_add(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__f64x2)__a + (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_sub(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__f64x2)__a - (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_mul(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__f64x2)__a * (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_div(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)((__f64x2)__a / (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_min(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_min_f64x2((__f64x2)__a, (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_max(v128_t __a,
                                                           v128_t __b) {
  return (v128_t)__builtin_wasm_max_f64x2((__f64x2)__a, (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_pmin(v128_t __a,
                                                            v128_t __b) {
  return (v128_t)__builtin_wasm_pmin_f64x2((__f64x2)__a, (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_f64x2_pmax(v128_t __a,
                                                            v128_t __b) {
  return (v128_t)__builtin_wasm_pmax_f64x2((__f64x2)__a, (__f64x2)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i32x4_trunc_saturate_f32x4(v128_t __a) {
  return (v128_t)__builtin_wasm_trunc_saturate_s_i32x4_f32x4((__f32x4)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_u32x4_trunc_saturate_f32x4(v128_t __a) {
  return (v128_t)__builtin_wasm_trunc_saturate_u_i32x4_f32x4((__f32x4)__a);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_f32x4_convert_i32x4(v128_t __a) {
  return (v128_t) __builtin_convertvector((__i32x4)__a, __f32x4);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_f32x4_convert_u32x4(v128_t __a) {
  return (v128_t) __builtin_convertvector((__u32x4)__a, __f32x4);
}

#define wasm_v8x16_shuffle(__a, __b, __c0, __c1, __c2, __c3, __c4, __c5, __c6, \
                           __c7, __c8, __c9, __c10, __c11, __c12, __c13,       \
                           __c14, __c15)                                       \
  ((v128_t)__builtin_wasm_shuffle_v8x16(                                       \
      (__i8x16)(__a), (__i8x16)(__b), __c0, __c1, __c2, __c3, __c4, __c5,      \
      __c6, __c7, __c8, __c9, __c10, __c11, __c12, __c13, __c14, __c15))

#define wasm_v16x8_shuffle(__a, __b, __c0, __c1, __c2, __c3, __c4, __c5, __c6, \
                           __c7)                                               \
  ((v128_t)__builtin_wasm_shuffle_v8x16(                                       \
      (__i8x16)(__a), (__i8x16)(__b), (__c0)*2, (__c0)*2 + 1, (__c1)*2,        \
      (__c1)*2 + 1, (__c2)*2, (__c2)*2 + 1, (__c3)*2, (__c3)*2 + 1, (__c4)*2,  \
      (__c4)*2 + 1, (__c5)*2, (__c5)*2 + 1, (__c6)*2, (__c6)*2 + 1, (__c7)*2,  \
      (__c7)*2 + 1))

#define wasm_v32x4_shuffle(__a, __b, __c0, __c1, __c2, __c3)                   \
  ((v128_t)__builtin_wasm_shuffle_v8x16(                                       \
      (__i8x16)(__a), (__i8x16)(__b), (__c0)*4, (__c0)*4 + 1, (__c0)*4 + 2,    \
      (__c0)*4 + 3, (__c1)*4, (__c1)*4 + 1, (__c1)*4 + 2, (__c1)*4 + 3,        \
      (__c2)*4, (__c2)*4 + 1, (__c2)*4 + 2, (__c2)*4 + 3, (__c3)*4,            \
      (__c3)*4 + 1, (__c3)*4 + 2, (__c3)*4 + 3))

#define wasm_v64x2_shuffle(__a, __b, __c0, __c1)                               \
  ((v128_t)__builtin_wasm_shuffle_v8x16(                                       \
      (__i8x16)(__a), (__i8x16)(__b), (__c0)*8, (__c0)*8 + 1, (__c0)*8 + 2,    \
      (__c0)*8 + 3, (__c0)*8 + 4, (__c0)*8 + 5, (__c0)*8 + 6, (__c0)*8 + 7,    \
      (__c1)*8, (__c1)*8 + 1, (__c1)*8 + 2, (__c1)*8 + 3, (__c1)*8 + 4,        \
      (__c1)*8 + 5, (__c1)*8 + 6, (__c1)*8 + 7))

static __inline__ v128_t __DEFAULT_FN_ATTRS wasm_v8x16_swizzle(v128_t __a,
                                                               v128_t __b) {
  return (v128_t)__builtin_wasm_swizzle_v8x16((__i8x16)__a, (__i8x16)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i8x16_narrow_i16x8(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_narrow_s_i8x16_i16x8((__i16x8)__a,
                                                     (__i16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_u8x16_narrow_i16x8(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_narrow_u_i8x16_i16x8((__u16x8)__a,
                                                     (__u16x8)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i16x8_narrow_i32x4(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_narrow_s_i16x8_i32x4((__i32x4)__a,
                                                     (__i32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_u16x8_narrow_i32x4(v128_t __a, v128_t __b) {
  return (v128_t)__builtin_wasm_narrow_u_i16x8_i32x4((__u32x4)__a,
                                                     (__u32x4)__b);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i16x8_widen_low_i8x16(v128_t __a) {
  return (v128_t) __builtin_convertvector(
      (__i8x8){((__i8x16)__a)[0], ((__i8x16)__a)[1], ((__i8x16)__a)[2],
               ((__i8x16)__a)[3], ((__i8x16)__a)[4], ((__i8x16)__a)[5],
               ((__i8x16)__a)[6], ((__i8x16)__a)[7]},
      __i16x8);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i16x8_widen_high_i8x16(v128_t __a) {
  return (v128_t) __builtin_convertvector(
      (__i8x8){((__i8x16)__a)[8], ((__i8x16)__a)[9], ((__i8x16)__a)[10],
               ((__i8x16)__a)[11], ((__i8x16)__a)[12], ((__i8x16)__a)[13],
               ((__i8x16)__a)[14], ((__i8x16)__a)[15]},
      __i16x8);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i16x8_widen_low_u8x16(v128_t __a) {
  return (v128_t) __builtin_convertvector(
      (__u8x8){((__u8x16)__a)[0], ((__u8x16)__a)[1], ((__u8x16)__a)[2],
               ((__u8x16)__a)[3], ((__u8x16)__a)[4], ((__u8x16)__a)[5],
               ((__u8x16)__a)[6], ((__u8x16)__a)[7]},
      __u16x8);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i16x8_widen_high_u8x16(v128_t __a) {
  return (v128_t) __builtin_convertvector(
      (__u8x8){((__u8x16)__a)[8], ((__u8x16)__a)[9], ((__u8x16)__a)[10],
               ((__u8x16)__a)[11], ((__u8x16)__a)[12], ((__u8x16)__a)[13],
               ((__u8x16)__a)[14], ((__u8x16)__a)[15]},
      __u16x8);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i32x4_widen_low_i16x8(v128_t __a) {
  return (v128_t) __builtin_convertvector(
      (__i16x4){((__i16x8)__a)[0], ((__i16x8)__a)[1], ((__i16x8)__a)[2],
                ((__i16x8)__a)[3]},
      __i32x4);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i32x4_widen_high_i16x8(v128_t __a) {
  return (v128_t) __builtin_convertvector(
      (__i16x4){((__i16x8)__a)[4], ((__i16x8)__a)[5], ((__i16x8)__a)[6],
                ((__i16x8)__a)[7]},
      __i32x4);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i32x4_widen_low_u16x8(v128_t __a) {
  return (v128_t) __builtin_convertvector(
      (__u16x4){((__u16x8)__a)[0], ((__u16x8)__a)[1], ((__u16x8)__a)[2],
                ((__u16x8)__a)[3]},
      __u32x4);
}

static __inline__ v128_t __DEFAULT_FN_ATTRS
wasm_i32x4_widen_high_u16x8(v128_t __a) {
  return (v128_t) __builtin_convertvector(
      (__u16x4){((__u16x8)__a)[4], ((__u16x8)__a)[5], ((__u16x8)__a)[6],
                ((__u16x8)__a)[7]},
      __u32x4);
}

// Undefine helper macros
#undef __DEFAULT_FN_ATTRS

#endif // __WASM_SIMD128_H
