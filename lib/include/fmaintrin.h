/*===---- fmaintrin.h - FMA intrinsics -------------------------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __IMMINTRIN_H
#error "Never use <fmaintrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __FMAINTRIN_H
#define __FMAINTRIN_H

/* Define the default attributes for the functions in this file. */
#define __DEFAULT_FN_ATTRS128 __attribute__((__always_inline__, __nodebug__, __target__("fma"), __min_vector_width__(128)))
#define __DEFAULT_FN_ATTRS256 __attribute__((__always_inline__, __nodebug__, __target__("fma"), __min_vector_width__(256)))

static __inline__ __m128 __DEFAULT_FN_ATTRS128
_mm_fmadd_ps(__m128 __A, __m128 __B, __m128 __C)
{
  return (__m128)__builtin_ia32_vfmaddps((__v4sf)__A, (__v4sf)__B, (__v4sf)__C);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS128
_mm_fmadd_pd(__m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d)__builtin_ia32_vfmaddpd((__v2df)__A, (__v2df)__B, (__v2df)__C);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS128
_mm_fmadd_ss(__m128 __A, __m128 __B, __m128 __C)
{
  return (__m128)__builtin_ia32_vfmaddss3((__v4sf)__A, (__v4sf)__B, (__v4sf)__C);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS128
_mm_fmadd_sd(__m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d)__builtin_ia32_vfmaddsd3((__v2df)__A, (__v2df)__B, (__v2df)__C);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS128
_mm_fmsub_ps(__m128 __A, __m128 __B, __m128 __C)
{
  return (__m128)__builtin_ia32_vfmaddps((__v4sf)__A, (__v4sf)__B, -(__v4sf)__C);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS128
_mm_fmsub_pd(__m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d)__builtin_ia32_vfmaddpd((__v2df)__A, (__v2df)__B, -(__v2df)__C);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS128
_mm_fmsub_ss(__m128 __A, __m128 __B, __m128 __C)
{
  return (__m128)__builtin_ia32_vfmaddss3((__v4sf)__A, (__v4sf)__B, -(__v4sf)__C);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS128
_mm_fmsub_sd(__m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d)__builtin_ia32_vfmaddsd3((__v2df)__A, (__v2df)__B, -(__v2df)__C);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS128
_mm_fnmadd_ps(__m128 __A, __m128 __B, __m128 __C)
{
  return (__m128)__builtin_ia32_vfmaddps(-(__v4sf)__A, (__v4sf)__B, (__v4sf)__C);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS128
_mm_fnmadd_pd(__m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d)__builtin_ia32_vfmaddpd(-(__v2df)__A, (__v2df)__B, (__v2df)__C);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS128
_mm_fnmadd_ss(__m128 __A, __m128 __B, __m128 __C)
{
  return (__m128)__builtin_ia32_vfmaddss3((__v4sf)__A, -(__v4sf)__B, (__v4sf)__C);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS128
_mm_fnmadd_sd(__m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d)__builtin_ia32_vfmaddsd3((__v2df)__A, -(__v2df)__B, (__v2df)__C);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS128
_mm_fnmsub_ps(__m128 __A, __m128 __B, __m128 __C)
{
  return (__m128)__builtin_ia32_vfmaddps(-(__v4sf)__A, (__v4sf)__B, -(__v4sf)__C);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS128
_mm_fnmsub_pd(__m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d)__builtin_ia32_vfmaddpd(-(__v2df)__A, (__v2df)__B, -(__v2df)__C);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS128
_mm_fnmsub_ss(__m128 __A, __m128 __B, __m128 __C)
{
  return (__m128)__builtin_ia32_vfmaddss3((__v4sf)__A, -(__v4sf)__B, -(__v4sf)__C);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS128
_mm_fnmsub_sd(__m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d)__builtin_ia32_vfmaddsd3((__v2df)__A, -(__v2df)__B, -(__v2df)__C);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS128
_mm_fmaddsub_ps(__m128 __A, __m128 __B, __m128 __C)
{
  return (__m128)__builtin_ia32_vfmaddsubps((__v4sf)__A, (__v4sf)__B, (__v4sf)__C);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS128
_mm_fmaddsub_pd(__m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d)__builtin_ia32_vfmaddsubpd((__v2df)__A, (__v2df)__B, (__v2df)__C);
}

static __inline__ __m128 __DEFAULT_FN_ATTRS128
_mm_fmsubadd_ps(__m128 __A, __m128 __B, __m128 __C)
{
  return (__m128)__builtin_ia32_vfmaddsubps((__v4sf)__A, (__v4sf)__B, -(__v4sf)__C);
}

static __inline__ __m128d __DEFAULT_FN_ATTRS128
_mm_fmsubadd_pd(__m128d __A, __m128d __B, __m128d __C)
{
  return (__m128d)__builtin_ia32_vfmaddsubpd((__v2df)__A, (__v2df)__B, -(__v2df)__C);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS256
_mm256_fmadd_ps(__m256 __A, __m256 __B, __m256 __C)
{
  return (__m256)__builtin_ia32_vfmaddps256((__v8sf)__A, (__v8sf)__B, (__v8sf)__C);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS256
_mm256_fmadd_pd(__m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d)__builtin_ia32_vfmaddpd256((__v4df)__A, (__v4df)__B, (__v4df)__C);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS256
_mm256_fmsub_ps(__m256 __A, __m256 __B, __m256 __C)
{
  return (__m256)__builtin_ia32_vfmaddps256((__v8sf)__A, (__v8sf)__B, -(__v8sf)__C);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS256
_mm256_fmsub_pd(__m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d)__builtin_ia32_vfmaddpd256((__v4df)__A, (__v4df)__B, -(__v4df)__C);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS256
_mm256_fnmadd_ps(__m256 __A, __m256 __B, __m256 __C)
{
  return (__m256)__builtin_ia32_vfmaddps256(-(__v8sf)__A, (__v8sf)__B, (__v8sf)__C);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS256
_mm256_fnmadd_pd(__m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d)__builtin_ia32_vfmaddpd256(-(__v4df)__A, (__v4df)__B, (__v4df)__C);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS256
_mm256_fnmsub_ps(__m256 __A, __m256 __B, __m256 __C)
{
  return (__m256)__builtin_ia32_vfmaddps256(-(__v8sf)__A, (__v8sf)__B, -(__v8sf)__C);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS256
_mm256_fnmsub_pd(__m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d)__builtin_ia32_vfmaddpd256(-(__v4df)__A, (__v4df)__B, -(__v4df)__C);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS256
_mm256_fmaddsub_ps(__m256 __A, __m256 __B, __m256 __C)
{
  return (__m256)__builtin_ia32_vfmaddsubps256((__v8sf)__A, (__v8sf)__B, (__v8sf)__C);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS256
_mm256_fmaddsub_pd(__m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d)__builtin_ia32_vfmaddsubpd256((__v4df)__A, (__v4df)__B, (__v4df)__C);
}

static __inline__ __m256 __DEFAULT_FN_ATTRS256
_mm256_fmsubadd_ps(__m256 __A, __m256 __B, __m256 __C)
{
  return (__m256)__builtin_ia32_vfmaddsubps256((__v8sf)__A, (__v8sf)__B, -(__v8sf)__C);
}

static __inline__ __m256d __DEFAULT_FN_ATTRS256
_mm256_fmsubadd_pd(__m256d __A, __m256d __B, __m256d __C)
{
  return (__m256d)__builtin_ia32_vfmaddsubpd256((__v4df)__A, (__v4df)__B, -(__v4df)__C);
}

#undef __DEFAULT_FN_ATTRS128
#undef __DEFAULT_FN_ATTRS256

#endif /* __FMAINTRIN_H */
