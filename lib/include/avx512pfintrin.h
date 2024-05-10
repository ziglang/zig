/*===------------- avx512pfintrin.h - PF intrinsics ------------------------===
 *
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */
#ifndef __IMMINTRIN_H
#error "Never use <avx512pfintrin.h> directly; include <immintrin.h> instead."
#endif

#ifndef __AVX512PFINTRIN_H
#define __AVX512PFINTRIN_H

#define _mm512_mask_prefetch_i32gather_pd(index, mask, addr, scale, hint) \
  __builtin_ia32_gatherpfdpd((__mmask8)(mask), (__v8si)(__m256i)(index), \
                             (void const *)(addr), (int)(scale), \
                             (int)(hint))

#define _mm512_prefetch_i32gather_pd(index, addr, scale, hint) \
  __builtin_ia32_gatherpfdpd((__mmask8) -1, (__v8si)(__m256i)(index), \
                             (void const *)(addr), (int)(scale), \
                             (int)(hint))

#define _mm512_mask_prefetch_i32gather_ps(index, mask, addr, scale, hint) \
  __builtin_ia32_gatherpfdps((__mmask16)(mask), \
                             (__v16si)(__m512i)(index), (void const *)(addr), \
                             (int)(scale), (int)(hint))

#define _mm512_prefetch_i32gather_ps(index, addr, scale, hint) \
  __builtin_ia32_gatherpfdps((__mmask16) -1, \
                             (__v16si)(__m512i)(index), (void const *)(addr), \
                             (int)(scale), (int)(hint))

#define _mm512_mask_prefetch_i64gather_pd(index, mask, addr, scale, hint) \
  __builtin_ia32_gatherpfqpd((__mmask8)(mask), (__v8di)(__m512i)(index), \
                             (void const *)(addr), (int)(scale), \
                             (int)(hint))

#define _mm512_prefetch_i64gather_pd(index, addr, scale, hint) \
  __builtin_ia32_gatherpfqpd((__mmask8) -1, (__v8di)(__m512i)(index), \
                             (void const *)(addr), (int)(scale), \
                             (int)(hint))

#define _mm512_mask_prefetch_i64gather_ps(index, mask, addr, scale, hint) \
  __builtin_ia32_gatherpfqps((__mmask8)(mask), (__v8di)(__m512i)(index), \
                             (void const *)(addr), (int)(scale), (int)(hint))

#define _mm512_prefetch_i64gather_ps(index, addr, scale, hint) \
  __builtin_ia32_gatherpfqps((__mmask8) -1, (__v8di)(__m512i)(index), \
                             (void const *)(addr), (int)(scale), (int)(hint))

#define _mm512_prefetch_i32scatter_pd(addr, index, scale, hint) \
  __builtin_ia32_scatterpfdpd((__mmask8)-1, (__v8si)(__m256i)(index), \
                              (void *)(addr), (int)(scale), \
                              (int)(hint))

#define _mm512_mask_prefetch_i32scatter_pd(addr, mask, index, scale, hint) \
  __builtin_ia32_scatterpfdpd((__mmask8)(mask), (__v8si)(__m256i)(index), \
                              (void *)(addr), (int)(scale), \
                              (int)(hint))

#define _mm512_prefetch_i32scatter_ps(addr, index, scale, hint) \
  __builtin_ia32_scatterpfdps((__mmask16)-1, (__v16si)(__m512i)(index), \
                              (void *)(addr), (int)(scale), (int)(hint))

#define _mm512_mask_prefetch_i32scatter_ps(addr, mask, index, scale, hint) \
  __builtin_ia32_scatterpfdps((__mmask16)(mask), \
                              (__v16si)(__m512i)(index), (void *)(addr), \
                              (int)(scale), (int)(hint))

#define _mm512_prefetch_i64scatter_pd(addr, index, scale, hint) \
  __builtin_ia32_scatterpfqpd((__mmask8)-1, (__v8di)(__m512i)(index), \
                              (void *)(addr), (int)(scale), \
                              (int)(hint))

#define _mm512_mask_prefetch_i64scatter_pd(addr, mask, index, scale, hint) \
  __builtin_ia32_scatterpfqpd((__mmask8)(mask), (__v8di)(__m512i)(index), \
                              (void *)(addr), (int)(scale), \
                              (int)(hint))

#define _mm512_prefetch_i64scatter_ps(addr, index, scale, hint) \
  __builtin_ia32_scatterpfqps((__mmask8)-1, (__v8di)(__m512i)(index), \
                              (void *)(addr), (int)(scale), (int)(hint))

#define _mm512_mask_prefetch_i64scatter_ps(addr, mask, index, scale, hint) \
  __builtin_ia32_scatterpfqps((__mmask8)(mask), (__v8di)(__m512i)(index), \
                              (void *)(addr), (int)(scale), (int)(hint))

#endif
