/*===---- __clang_hip_math.h - HIP math decls -------------------------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __CLANG_HIP_MATH_H__
#define __CLANG_HIP_MATH_H__

#include <algorithm>
#include <limits.h>
#include <limits>
#include <stdint.h>

#pragma push_macro("__DEVICE__")
#pragma push_macro("__RETURN_TYPE")

// to be consistent with __clang_cuda_math_forward_declares
#define __DEVICE__ static __device__
#define __RETURN_TYPE bool

__DEVICE__
inline uint64_t __make_mantissa_base8(const char *__tagp) {
  uint64_t __r = 0;
  while (__tagp) {
    char __tmp = *__tagp;

    if (__tmp >= '0' && __tmp <= '7')
      __r = (__r * 8u) + __tmp - '0';
    else
      return 0;

    ++__tagp;
  }

  return __r;
}

__DEVICE__
inline uint64_t __make_mantissa_base10(const char *__tagp) {
  uint64_t __r = 0;
  while (__tagp) {
    char __tmp = *__tagp;

    if (__tmp >= '0' && __tmp <= '9')
      __r = (__r * 10u) + __tmp - '0';
    else
      return 0;

    ++__tagp;
  }

  return __r;
}

__DEVICE__
inline uint64_t __make_mantissa_base16(const char *__tagp) {
  uint64_t __r = 0;
  while (__tagp) {
    char __tmp = *__tagp;

    if (__tmp >= '0' && __tmp <= '9')
      __r = (__r * 16u) + __tmp - '0';
    else if (__tmp >= 'a' && __tmp <= 'f')
      __r = (__r * 16u) + __tmp - 'a' + 10;
    else if (__tmp >= 'A' && __tmp <= 'F')
      __r = (__r * 16u) + __tmp - 'A' + 10;
    else
      return 0;

    ++__tagp;
  }

  return __r;
}

__DEVICE__
inline uint64_t __make_mantissa(const char *__tagp) {
  if (!__tagp)
    return 0u;

  if (*__tagp == '0') {
    ++__tagp;

    if (*__tagp == 'x' || *__tagp == 'X')
      return __make_mantissa_base16(__tagp);
    else
      return __make_mantissa_base8(__tagp);
  }

  return __make_mantissa_base10(__tagp);
}

// BEGIN FLOAT
__DEVICE__
inline float abs(float __x) { return __ocml_fabs_f32(__x); }
__DEVICE__
inline float acosf(float __x) { return __ocml_acos_f32(__x); }
__DEVICE__
inline float acoshf(float __x) { return __ocml_acosh_f32(__x); }
__DEVICE__
inline float asinf(float __x) { return __ocml_asin_f32(__x); }
__DEVICE__
inline float asinhf(float __x) { return __ocml_asinh_f32(__x); }
__DEVICE__
inline float atan2f(float __x, float __y) { return __ocml_atan2_f32(__x, __y); }
__DEVICE__
inline float atanf(float __x) { return __ocml_atan_f32(__x); }
__DEVICE__
inline float atanhf(float __x) { return __ocml_atanh_f32(__x); }
__DEVICE__
inline float cbrtf(float __x) { return __ocml_cbrt_f32(__x); }
__DEVICE__
inline float ceilf(float __x) { return __ocml_ceil_f32(__x); }
__DEVICE__
inline float copysignf(float __x, float __y) {
  return __ocml_copysign_f32(__x, __y);
}
__DEVICE__
inline float cosf(float __x) { return __ocml_cos_f32(__x); }
__DEVICE__
inline float coshf(float __x) { return __ocml_cosh_f32(__x); }
__DEVICE__
inline float cospif(float __x) { return __ocml_cospi_f32(__x); }
__DEVICE__
inline float cyl_bessel_i0f(float __x) { return __ocml_i0_f32(__x); }
__DEVICE__
inline float cyl_bessel_i1f(float __x) { return __ocml_i1_f32(__x); }
__DEVICE__
inline float erfcf(float __x) { return __ocml_erfc_f32(__x); }
__DEVICE__
inline float erfcinvf(float __x) { return __ocml_erfcinv_f32(__x); }
__DEVICE__
inline float erfcxf(float __x) { return __ocml_erfcx_f32(__x); }
__DEVICE__
inline float erff(float __x) { return __ocml_erf_f32(__x); }
__DEVICE__
inline float erfinvf(float __x) { return __ocml_erfinv_f32(__x); }
__DEVICE__
inline float exp10f(float __x) { return __ocml_exp10_f32(__x); }
__DEVICE__
inline float exp2f(float __x) { return __ocml_exp2_f32(__x); }
__DEVICE__
inline float expf(float __x) { return __ocml_exp_f32(__x); }
__DEVICE__
inline float expm1f(float __x) { return __ocml_expm1_f32(__x); }
__DEVICE__
inline float fabsf(float __x) { return __ocml_fabs_f32(__x); }
__DEVICE__
inline float fdimf(float __x, float __y) { return __ocml_fdim_f32(__x, __y); }
__DEVICE__
inline float fdividef(float __x, float __y) { return __x / __y; }
__DEVICE__
inline float floorf(float __x) { return __ocml_floor_f32(__x); }
__DEVICE__
inline float fmaf(float __x, float __y, float __z) {
  return __ocml_fma_f32(__x, __y, __z);
}
__DEVICE__
inline float fmaxf(float __x, float __y) { return __ocml_fmax_f32(__x, __y); }
__DEVICE__
inline float fminf(float __x, float __y) { return __ocml_fmin_f32(__x, __y); }
__DEVICE__
inline float fmodf(float __x, float __y) { return __ocml_fmod_f32(__x, __y); }
__DEVICE__
inline float frexpf(float __x, int *__nptr) {
  int __tmp;
  float __r =
      __ocml_frexp_f32(__x, (__attribute__((address_space(5))) int *)&__tmp);
  *__nptr = __tmp;

  return __r;
}
__DEVICE__
inline float hypotf(float __x, float __y) { return __ocml_hypot_f32(__x, __y); }
__DEVICE__
inline int ilogbf(float __x) { return __ocml_ilogb_f32(__x); }
__DEVICE__
inline __RETURN_TYPE isfinite(float __x) { return __ocml_isfinite_f32(__x); }
__DEVICE__
inline __RETURN_TYPE isinf(float __x) { return __ocml_isinf_f32(__x); }
__DEVICE__
inline __RETURN_TYPE isnan(float __x) { return __ocml_isnan_f32(__x); }
__DEVICE__
inline float j0f(float __x) { return __ocml_j0_f32(__x); }
__DEVICE__
inline float j1f(float __x) { return __ocml_j1_f32(__x); }
__DEVICE__
inline float jnf(int __n,
                 float __x) { // TODO: we could use Ahmes multiplication
                              // and the Miller & Brown algorithm
  //       for linear recurrences to get O(log n) steps, but it's unclear if
  //       it'd be beneficial in this case.
  if (__n == 0)
    return j0f(__x);
  if (__n == 1)
    return j1f(__x);

  float __x0 = j0f(__x);
  float __x1 = j1f(__x);
  for (int __i = 1; __i < __n; ++__i) {
    float __x2 = (2 * __i) / __x * __x1 - __x0;
    __x0 = __x1;
    __x1 = __x2;
  }

  return __x1;
}
__DEVICE__
inline float ldexpf(float __x, int __e) { return __ocml_ldexp_f32(__x, __e); }
__DEVICE__
inline float lgammaf(float __x) { return __ocml_lgamma_f32(__x); }
__DEVICE__
inline long long int llrintf(float __x) { return __ocml_rint_f32(__x); }
__DEVICE__
inline long long int llroundf(float __x) { return __ocml_round_f32(__x); }
__DEVICE__
inline float log10f(float __x) { return __ocml_log10_f32(__x); }
__DEVICE__
inline float log1pf(float __x) { return __ocml_log1p_f32(__x); }
__DEVICE__
inline float log2f(float __x) { return __ocml_log2_f32(__x); }
__DEVICE__
inline float logbf(float __x) { return __ocml_logb_f32(__x); }
__DEVICE__
inline float logf(float __x) { return __ocml_log_f32(__x); }
__DEVICE__
inline long int lrintf(float __x) { return __ocml_rint_f32(__x); }
__DEVICE__
inline long int lroundf(float __x) { return __ocml_round_f32(__x); }
__DEVICE__
inline float modff(float __x, float *__iptr) {
  float __tmp;
  float __r =
      __ocml_modf_f32(__x, (__attribute__((address_space(5))) float *)&__tmp);
  *__iptr = __tmp;

  return __r;
}
__DEVICE__
inline float nanf(const char *__tagp) {
  union {
    float val;
    struct ieee_float {
      uint32_t mantissa : 22;
      uint32_t quiet : 1;
      uint32_t exponent : 8;
      uint32_t sign : 1;
    } bits;

    static_assert(sizeof(float) == sizeof(ieee_float), "");
  } __tmp;

  __tmp.bits.sign = 0u;
  __tmp.bits.exponent = ~0u;
  __tmp.bits.quiet = 1u;
  __tmp.bits.mantissa = __make_mantissa(__tagp);

  return __tmp.val;
}
__DEVICE__
inline float nearbyintf(float __x) { return __ocml_nearbyint_f32(__x); }
__DEVICE__
inline float nextafterf(float __x, float __y) {
  return __ocml_nextafter_f32(__x, __y);
}
__DEVICE__
inline float norm3df(float __x, float __y, float __z) {
  return __ocml_len3_f32(__x, __y, __z);
}
__DEVICE__
inline float norm4df(float __x, float __y, float __z, float __w) {
  return __ocml_len4_f32(__x, __y, __z, __w);
}
__DEVICE__
inline float normcdff(float __x) { return __ocml_ncdf_f32(__x); }
__DEVICE__
inline float normcdfinvf(float __x) { return __ocml_ncdfinv_f32(__x); }
__DEVICE__
inline float
normf(int __dim,
      const float *__a) { // TODO: placeholder until OCML adds support.
  float __r = 0;
  while (__dim--) {
    __r += __a[0] * __a[0];
    ++__a;
  }

  return __ocml_sqrt_f32(__r);
}
__DEVICE__
inline float powf(float __x, float __y) { return __ocml_pow_f32(__x, __y); }
__DEVICE__
inline float rcbrtf(float __x) { return __ocml_rcbrt_f32(__x); }
__DEVICE__
inline float remainderf(float __x, float __y) {
  return __ocml_remainder_f32(__x, __y);
}
__DEVICE__
inline float remquof(float __x, float __y, int *__quo) {
  int __tmp;
  float __r = __ocml_remquo_f32(
      __x, __y, (__attribute__((address_space(5))) int *)&__tmp);
  *__quo = __tmp;

  return __r;
}
__DEVICE__
inline float rhypotf(float __x, float __y) {
  return __ocml_rhypot_f32(__x, __y);
}
__DEVICE__
inline float rintf(float __x) { return __ocml_rint_f32(__x); }
__DEVICE__
inline float rnorm3df(float __x, float __y, float __z) {
  return __ocml_rlen3_f32(__x, __y, __z);
}

__DEVICE__
inline float rnorm4df(float __x, float __y, float __z, float __w) {
  return __ocml_rlen4_f32(__x, __y, __z, __w);
}
__DEVICE__
inline float
rnormf(int __dim,
       const float *__a) { // TODO: placeholder until OCML adds support.
  float __r = 0;
  while (__dim--) {
    __r += __a[0] * __a[0];
    ++__a;
  }

  return __ocml_rsqrt_f32(__r);
}
__DEVICE__
inline float roundf(float __x) { return __ocml_round_f32(__x); }
__DEVICE__
inline float rsqrtf(float __x) { return __ocml_rsqrt_f32(__x); }
__DEVICE__
inline float scalblnf(float __x, long int __n) {
  return (__n < INT_MAX) ? __ocml_scalbn_f32(__x, __n)
                         : __ocml_scalb_f32(__x, __n);
}
__DEVICE__
inline float scalbnf(float __x, int __n) { return __ocml_scalbn_f32(__x, __n); }
__DEVICE__
inline __RETURN_TYPE signbit(float __x) { return __ocml_signbit_f32(__x); }
__DEVICE__
inline void sincosf(float __x, float *__sinptr, float *__cosptr) {
  float __tmp;

  *__sinptr =
      __ocml_sincos_f32(__x, (__attribute__((address_space(5))) float *)&__tmp);
  *__cosptr = __tmp;
}
__DEVICE__
inline void sincospif(float __x, float *__sinptr, float *__cosptr) {
  float __tmp;

  *__sinptr = __ocml_sincospi_f32(
      __x, (__attribute__((address_space(5))) float *)&__tmp);
  *__cosptr = __tmp;
}
__DEVICE__
inline float sinf(float __x) { return __ocml_sin_f32(__x); }
__DEVICE__
inline float sinhf(float __x) { return __ocml_sinh_f32(__x); }
__DEVICE__
inline float sinpif(float __x) { return __ocml_sinpi_f32(__x); }
__DEVICE__
inline float sqrtf(float __x) { return __ocml_sqrt_f32(__x); }
__DEVICE__
inline float tanf(float __x) { return __ocml_tan_f32(__x); }
__DEVICE__
inline float tanhf(float __x) { return __ocml_tanh_f32(__x); }
__DEVICE__
inline float tgammaf(float __x) { return __ocml_tgamma_f32(__x); }
__DEVICE__
inline float truncf(float __x) { return __ocml_trunc_f32(__x); }
__DEVICE__
inline float y0f(float __x) { return __ocml_y0_f32(__x); }
__DEVICE__
inline float y1f(float __x) { return __ocml_y1_f32(__x); }
__DEVICE__
inline float ynf(int __n,
                 float __x) { // TODO: we could use Ahmes multiplication
                              // and the Miller & Brown algorithm
  //       for linear recurrences to get O(log n) steps, but it's unclear if
  //       it'd be beneficial in this case. Placeholder until OCML adds
  //       support.
  if (__n == 0)
    return y0f(__x);
  if (__n == 1)
    return y1f(__x);

  float __x0 = y0f(__x);
  float __x1 = y1f(__x);
  for (int __i = 1; __i < __n; ++__i) {
    float __x2 = (2 * __i) / __x * __x1 - __x0;
    __x0 = __x1;
    __x1 = __x2;
  }

  return __x1;
}

// BEGIN INTRINSICS
__DEVICE__
inline float __cosf(float __x) { return __ocml_native_cos_f32(__x); }
__DEVICE__
inline float __exp10f(float __x) { return __ocml_native_exp10_f32(__x); }
__DEVICE__
inline float __expf(float __x) { return __ocml_native_exp_f32(__x); }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline float __fadd_rd(float __x, float __y) {
  return __ocml_add_rtn_f32(__x, __y);
}
#endif
__DEVICE__
inline float __fadd_rn(float __x, float __y) { return __x + __y; }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline float __fadd_ru(float __x, float __y) {
  return __ocml_add_rtp_f32(__x, __y);
}
__DEVICE__
inline float __fadd_rz(float __x, float __y) {
  return __ocml_add_rtz_f32(__x, __y);
}
__DEVICE__
inline float __fdiv_rd(float __x, float __y) {
  return __ocml_div_rtn_f32(__x, __y);
}
#endif
__DEVICE__
inline float __fdiv_rn(float __x, float __y) { return __x / __y; }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline float __fdiv_ru(float __x, float __y) {
  return __ocml_div_rtp_f32(__x, __y);
}
__DEVICE__
inline float __fdiv_rz(float __x, float __y) {
  return __ocml_div_rtz_f32(__x, __y);
}
#endif
__DEVICE__
inline float __fdividef(float __x, float __y) { return __x / __y; }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline float __fmaf_rd(float __x, float __y, float __z) {
  return __ocml_fma_rtn_f32(__x, __y, __z);
}
#endif
__DEVICE__
inline float __fmaf_rn(float __x, float __y, float __z) {
  return __ocml_fma_f32(__x, __y, __z);
}
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline float __fmaf_ru(float __x, float __y, float __z) {
  return __ocml_fma_rtp_f32(__x, __y, __z);
}
__DEVICE__
inline float __fmaf_rz(float __x, float __y, float __z) {
  return __ocml_fma_rtz_f32(__x, __y, __z);
}
__DEVICE__
inline float __fmul_rd(float __x, float __y) {
  return __ocml_mul_rtn_f32(__x, __y);
}
#endif
__DEVICE__
inline float __fmul_rn(float __x, float __y) { return __x * __y; }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline float __fmul_ru(float __x, float __y) {
  return __ocml_mul_rtp_f32(__x, __y);
}
__DEVICE__
inline float __fmul_rz(float __x, float __y) {
  return __ocml_mul_rtz_f32(__x, __y);
}
__DEVICE__
inline float __frcp_rd(float __x) { return __llvm_amdgcn_rcp_f32(__x); }
#endif
__DEVICE__
inline float __frcp_rn(float __x) { return __llvm_amdgcn_rcp_f32(__x); }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline float __frcp_ru(float __x) { return __llvm_amdgcn_rcp_f32(__x); }
__DEVICE__
inline float __frcp_rz(float __x) { return __llvm_amdgcn_rcp_f32(__x); }
#endif
__DEVICE__
inline float __frsqrt_rn(float __x) { return __llvm_amdgcn_rsq_f32(__x); }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline float __fsqrt_rd(float __x) { return __ocml_sqrt_rtn_f32(__x); }
#endif
__DEVICE__
inline float __fsqrt_rn(float __x) { return __ocml_native_sqrt_f32(__x); }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline float __fsqrt_ru(float __x) { return __ocml_sqrt_rtp_f32(__x); }
__DEVICE__
inline float __fsqrt_rz(float __x) { return __ocml_sqrt_rtz_f32(__x); }
__DEVICE__
inline float __fsub_rd(float __x, float __y) {
  return __ocml_sub_rtn_f32(__x, __y);
}
#endif
__DEVICE__
inline float __fsub_rn(float __x, float __y) { return __x - __y; }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline float __fsub_ru(float __x, float __y) {
  return __ocml_sub_rtp_f32(__x, __y);
}
__DEVICE__
inline float __fsub_rz(float __x, float __y) {
  return __ocml_sub_rtz_f32(__x, __y);
}
#endif
__DEVICE__
inline float __log10f(float __x) { return __ocml_native_log10_f32(__x); }
__DEVICE__
inline float __log2f(float __x) { return __ocml_native_log2_f32(__x); }
__DEVICE__
inline float __logf(float __x) { return __ocml_native_log_f32(__x); }
__DEVICE__
inline float __powf(float __x, float __y) { return __ocml_pow_f32(__x, __y); }
__DEVICE__
inline float __saturatef(float __x) {
  return (__x < 0) ? 0 : ((__x > 1) ? 1 : __x);
}
__DEVICE__
inline void __sincosf(float __x, float *__sinptr, float *__cosptr) {
  *__sinptr = __ocml_native_sin_f32(__x);
  *__cosptr = __ocml_native_cos_f32(__x);
}
__DEVICE__
inline float __sinf(float __x) { return __ocml_native_sin_f32(__x); }
__DEVICE__
inline float __tanf(float __x) { return __ocml_tan_f32(__x); }
// END INTRINSICS
// END FLOAT

// BEGIN DOUBLE
__DEVICE__
inline double abs(double __x) { return __ocml_fabs_f64(__x); }
__DEVICE__
inline double acos(double __x) { return __ocml_acos_f64(__x); }
__DEVICE__
inline double acosh(double __x) { return __ocml_acosh_f64(__x); }
__DEVICE__
inline double asin(double __x) { return __ocml_asin_f64(__x); }
__DEVICE__
inline double asinh(double __x) { return __ocml_asinh_f64(__x); }
__DEVICE__
inline double atan(double __x) { return __ocml_atan_f64(__x); }
__DEVICE__
inline double atan2(double __x, double __y) {
  return __ocml_atan2_f64(__x, __y);
}
__DEVICE__
inline double atanh(double __x) { return __ocml_atanh_f64(__x); }
__DEVICE__
inline double cbrt(double __x) { return __ocml_cbrt_f64(__x); }
__DEVICE__
inline double ceil(double __x) { return __ocml_ceil_f64(__x); }
__DEVICE__
inline double copysign(double __x, double __y) {
  return __ocml_copysign_f64(__x, __y);
}
__DEVICE__
inline double cos(double __x) { return __ocml_cos_f64(__x); }
__DEVICE__
inline double cosh(double __x) { return __ocml_cosh_f64(__x); }
__DEVICE__
inline double cospi(double __x) { return __ocml_cospi_f64(__x); }
__DEVICE__
inline double cyl_bessel_i0(double __x) { return __ocml_i0_f64(__x); }
__DEVICE__
inline double cyl_bessel_i1(double __x) { return __ocml_i1_f64(__x); }
__DEVICE__
inline double erf(double __x) { return __ocml_erf_f64(__x); }
__DEVICE__
inline double erfc(double __x) { return __ocml_erfc_f64(__x); }
__DEVICE__
inline double erfcinv(double __x) { return __ocml_erfcinv_f64(__x); }
__DEVICE__
inline double erfcx(double __x) { return __ocml_erfcx_f64(__x); }
__DEVICE__
inline double erfinv(double __x) { return __ocml_erfinv_f64(__x); }
__DEVICE__
inline double exp(double __x) { return __ocml_exp_f64(__x); }
__DEVICE__
inline double exp10(double __x) { return __ocml_exp10_f64(__x); }
__DEVICE__
inline double exp2(double __x) { return __ocml_exp2_f64(__x); }
__DEVICE__
inline double expm1(double __x) { return __ocml_expm1_f64(__x); }
__DEVICE__
inline double fabs(double __x) { return __ocml_fabs_f64(__x); }
__DEVICE__
inline double fdim(double __x, double __y) { return __ocml_fdim_f64(__x, __y); }
__DEVICE__
inline double floor(double __x) { return __ocml_floor_f64(__x); }
__DEVICE__
inline double fma(double __x, double __y, double __z) {
  return __ocml_fma_f64(__x, __y, __z);
}
__DEVICE__
inline double fmax(double __x, double __y) { return __ocml_fmax_f64(__x, __y); }
__DEVICE__
inline double fmin(double __x, double __y) { return __ocml_fmin_f64(__x, __y); }
__DEVICE__
inline double fmod(double __x, double __y) { return __ocml_fmod_f64(__x, __y); }
__DEVICE__
inline double frexp(double __x, int *__nptr) {
  int __tmp;
  double __r =
      __ocml_frexp_f64(__x, (__attribute__((address_space(5))) int *)&__tmp);
  *__nptr = __tmp;

  return __r;
}
__DEVICE__
inline double hypot(double __x, double __y) {
  return __ocml_hypot_f64(__x, __y);
}
__DEVICE__
inline int ilogb(double __x) { return __ocml_ilogb_f64(__x); }
__DEVICE__
inline __RETURN_TYPE isfinite(double __x) { return __ocml_isfinite_f64(__x); }
__DEVICE__
inline __RETURN_TYPE isinf(double __x) { return __ocml_isinf_f64(__x); }
__DEVICE__
inline __RETURN_TYPE isnan(double __x) { return __ocml_isnan_f64(__x); }
__DEVICE__
inline double j0(double __x) { return __ocml_j0_f64(__x); }
__DEVICE__
inline double j1(double __x) { return __ocml_j1_f64(__x); }
__DEVICE__
inline double jn(int __n,
                 double __x) { // TODO: we could use Ahmes multiplication
                               // and the Miller & Brown algorithm
  //       for linear recurrences to get O(log n) steps, but it's unclear if
  //       it'd be beneficial in this case. Placeholder until OCML adds
  //       support.
  if (__n == 0)
    return j0f(__x);
  if (__n == 1)
    return j1f(__x);

  double __x0 = j0f(__x);
  double __x1 = j1f(__x);
  for (int __i = 1; __i < __n; ++__i) {
    double __x2 = (2 * __i) / __x * __x1 - __x0;
    __x0 = __x1;
    __x1 = __x2;
  }

  return __x1;
}
__DEVICE__
inline double ldexp(double __x, int __e) { return __ocml_ldexp_f64(__x, __e); }
__DEVICE__
inline double lgamma(double __x) { return __ocml_lgamma_f64(__x); }
__DEVICE__
inline long long int llrint(double __x) { return __ocml_rint_f64(__x); }
__DEVICE__
inline long long int llround(double __x) { return __ocml_round_f64(__x); }
__DEVICE__
inline double log(double __x) { return __ocml_log_f64(__x); }
__DEVICE__
inline double log10(double __x) { return __ocml_log10_f64(__x); }
__DEVICE__
inline double log1p(double __x) { return __ocml_log1p_f64(__x); }
__DEVICE__
inline double log2(double __x) { return __ocml_log2_f64(__x); }
__DEVICE__
inline double logb(double __x) { return __ocml_logb_f64(__x); }
__DEVICE__
inline long int lrint(double __x) { return __ocml_rint_f64(__x); }
__DEVICE__
inline long int lround(double __x) { return __ocml_round_f64(__x); }
__DEVICE__
inline double modf(double __x, double *__iptr) {
  double __tmp;
  double __r =
      __ocml_modf_f64(__x, (__attribute__((address_space(5))) double *)&__tmp);
  *__iptr = __tmp;

  return __r;
}
__DEVICE__
inline double nan(const char *__tagp) {
#if !_WIN32
  union {
    double val;
    struct ieee_double {
      uint64_t mantissa : 51;
      uint32_t quiet : 1;
      uint32_t exponent : 11;
      uint32_t sign : 1;
    } bits;
    static_assert(sizeof(double) == sizeof(ieee_double), "");
  } __tmp;

  __tmp.bits.sign = 0u;
  __tmp.bits.exponent = ~0u;
  __tmp.bits.quiet = 1u;
  __tmp.bits.mantissa = __make_mantissa(__tagp);

  return __tmp.val;
#else
  static_assert(sizeof(uint64_t) == sizeof(double));
  uint64_t val = __make_mantissa(__tagp);
  val |= 0xFFF << 51;
  return *reinterpret_cast<double *>(&val);
#endif
}
__DEVICE__
inline double nearbyint(double __x) { return __ocml_nearbyint_f64(__x); }
__DEVICE__
inline double nextafter(double __x, double __y) {
  return __ocml_nextafter_f64(__x, __y);
}
__DEVICE__
inline double
norm(int __dim,
     const double *__a) { // TODO: placeholder until OCML adds support.
  double __r = 0;
  while (__dim--) {
    __r += __a[0] * __a[0];
    ++__a;
  }

  return __ocml_sqrt_f64(__r);
}
__DEVICE__
inline double norm3d(double __x, double __y, double __z) {
  return __ocml_len3_f64(__x, __y, __z);
}
__DEVICE__
inline double norm4d(double __x, double __y, double __z, double __w) {
  return __ocml_len4_f64(__x, __y, __z, __w);
}
__DEVICE__
inline double normcdf(double __x) { return __ocml_ncdf_f64(__x); }
__DEVICE__
inline double normcdfinv(double __x) { return __ocml_ncdfinv_f64(__x); }
__DEVICE__
inline double pow(double __x, double __y) { return __ocml_pow_f64(__x, __y); }
__DEVICE__
inline double rcbrt(double __x) { return __ocml_rcbrt_f64(__x); }
__DEVICE__
inline double remainder(double __x, double __y) {
  return __ocml_remainder_f64(__x, __y);
}
__DEVICE__
inline double remquo(double __x, double __y, int *__quo) {
  int __tmp;
  double __r = __ocml_remquo_f64(
      __x, __y, (__attribute__((address_space(5))) int *)&__tmp);
  *__quo = __tmp;

  return __r;
}
__DEVICE__
inline double rhypot(double __x, double __y) {
  return __ocml_rhypot_f64(__x, __y);
}
__DEVICE__
inline double rint(double __x) { return __ocml_rint_f64(__x); }
__DEVICE__
inline double
rnorm(int __dim,
      const double *__a) { // TODO: placeholder until OCML adds support.
  double __r = 0;
  while (__dim--) {
    __r += __a[0] * __a[0];
    ++__a;
  }

  return __ocml_rsqrt_f64(__r);
}
__DEVICE__
inline double rnorm3d(double __x, double __y, double __z) {
  return __ocml_rlen3_f64(__x, __y, __z);
}
__DEVICE__
inline double rnorm4d(double __x, double __y, double __z, double __w) {
  return __ocml_rlen4_f64(__x, __y, __z, __w);
}
__DEVICE__
inline double round(double __x) { return __ocml_round_f64(__x); }
__DEVICE__
inline double rsqrt(double __x) { return __ocml_rsqrt_f64(__x); }
__DEVICE__
inline double scalbln(double __x, long int __n) {
  return (__n < INT_MAX) ? __ocml_scalbn_f64(__x, __n)
                         : __ocml_scalb_f64(__x, __n);
}
__DEVICE__
inline double scalbn(double __x, int __n) {
  return __ocml_scalbn_f64(__x, __n);
}
__DEVICE__
inline __RETURN_TYPE signbit(double __x) { return __ocml_signbit_f64(__x); }
__DEVICE__
inline double sin(double __x) { return __ocml_sin_f64(__x); }
__DEVICE__
inline void sincos(double __x, double *__sinptr, double *__cosptr) {
  double __tmp;
  *__sinptr = __ocml_sincos_f64(
      __x, (__attribute__((address_space(5))) double *)&__tmp);
  *__cosptr = __tmp;
}
__DEVICE__
inline void sincospi(double __x, double *__sinptr, double *__cosptr) {
  double __tmp;
  *__sinptr = __ocml_sincospi_f64(
      __x, (__attribute__((address_space(5))) double *)&__tmp);
  *__cosptr = __tmp;
}
__DEVICE__
inline double sinh(double __x) { return __ocml_sinh_f64(__x); }
__DEVICE__
inline double sinpi(double __x) { return __ocml_sinpi_f64(__x); }
__DEVICE__
inline double sqrt(double __x) { return __ocml_sqrt_f64(__x); }
__DEVICE__
inline double tan(double __x) { return __ocml_tan_f64(__x); }
__DEVICE__
inline double tanh(double __x) { return __ocml_tanh_f64(__x); }
__DEVICE__
inline double tgamma(double __x) { return __ocml_tgamma_f64(__x); }
__DEVICE__
inline double trunc(double __x) { return __ocml_trunc_f64(__x); }
__DEVICE__
inline double y0(double __x) { return __ocml_y0_f64(__x); }
__DEVICE__
inline double y1(double __x) { return __ocml_y1_f64(__x); }
__DEVICE__
inline double yn(int __n,
                 double __x) { // TODO: we could use Ahmes multiplication
                               // and the Miller & Brown algorithm
  //       for linear recurrences to get O(log n) steps, but it's unclear if
  //       it'd be beneficial in this case. Placeholder until OCML adds
  //       support.
  if (__n == 0)
    return j0f(__x);
  if (__n == 1)
    return j1f(__x);

  double __x0 = j0f(__x);
  double __x1 = j1f(__x);
  for (int __i = 1; __i < __n; ++__i) {
    double __x2 = (2 * __i) / __x * __x1 - __x0;
    __x0 = __x1;
    __x1 = __x2;
  }

  return __x1;
}

// BEGIN INTRINSICS
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline double __dadd_rd(double __x, double __y) {
  return __ocml_add_rtn_f64(__x, __y);
}
#endif
__DEVICE__
inline double __dadd_rn(double __x, double __y) { return __x + __y; }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline double __dadd_ru(double __x, double __y) {
  return __ocml_add_rtp_f64(__x, __y);
}
__DEVICE__
inline double __dadd_rz(double __x, double __y) {
  return __ocml_add_rtz_f64(__x, __y);
}
__DEVICE__
inline double __ddiv_rd(double __x, double __y) {
  return __ocml_div_rtn_f64(__x, __y);
}
#endif
__DEVICE__
inline double __ddiv_rn(double __x, double __y) { return __x / __y; }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline double __ddiv_ru(double __x, double __y) {
  return __ocml_div_rtp_f64(__x, __y);
}
__DEVICE__
inline double __ddiv_rz(double __x, double __y) {
  return __ocml_div_rtz_f64(__x, __y);
}
__DEVICE__
inline double __dmul_rd(double __x, double __y) {
  return __ocml_mul_rtn_f64(__x, __y);
}
#endif
__DEVICE__
inline double __dmul_rn(double __x, double __y) { return __x * __y; }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline double __dmul_ru(double __x, double __y) {
  return __ocml_mul_rtp_f64(__x, __y);
}
__DEVICE__
inline double __dmul_rz(double __x, double __y) {
  return __ocml_mul_rtz_f64(__x, __y);
}
__DEVICE__
inline double __drcp_rd(double __x) { return __llvm_amdgcn_rcp_f64(__x); }
#endif
__DEVICE__
inline double __drcp_rn(double __x) { return __llvm_amdgcn_rcp_f64(__x); }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline double __drcp_ru(double __x) { return __llvm_amdgcn_rcp_f64(__x); }
__DEVICE__
inline double __drcp_rz(double __x) { return __llvm_amdgcn_rcp_f64(__x); }
__DEVICE__
inline double __dsqrt_rd(double __x) { return __ocml_sqrt_rtn_f64(__x); }
#endif
__DEVICE__
inline double __dsqrt_rn(double __x) { return __ocml_sqrt_f64(__x); }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline double __dsqrt_ru(double __x) { return __ocml_sqrt_rtp_f64(__x); }
__DEVICE__
inline double __dsqrt_rz(double __x) { return __ocml_sqrt_rtz_f64(__x); }
__DEVICE__
inline double __dsub_rd(double __x, double __y) {
  return __ocml_sub_rtn_f64(__x, __y);
}
#endif
__DEVICE__
inline double __dsub_rn(double __x, double __y) { return __x - __y; }
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline double __dsub_ru(double __x, double __y) {
  return __ocml_sub_rtp_f64(__x, __y);
}
__DEVICE__
inline double __dsub_rz(double __x, double __y) {
  return __ocml_sub_rtz_f64(__x, __y);
}
__DEVICE__
inline double __fma_rd(double __x, double __y, double __z) {
  return __ocml_fma_rtn_f64(__x, __y, __z);
}
#endif
__DEVICE__
inline double __fma_rn(double __x, double __y, double __z) {
  return __ocml_fma_f64(__x, __y, __z);
}
#if defined OCML_BASIC_ROUNDED_OPERATIONS
__DEVICE__
inline double __fma_ru(double __x, double __y, double __z) {
  return __ocml_fma_rtp_f64(__x, __y, __z);
}
__DEVICE__
inline double __fma_rz(double __x, double __y, double __z) {
  return __ocml_fma_rtz_f64(__x, __y, __z);
}
#endif
// END INTRINSICS
// END DOUBLE

// BEGIN INTEGER
__DEVICE__
inline int abs(int __x) {
  int __sgn = __x >> (sizeof(int) * CHAR_BIT - 1);
  return (__x ^ __sgn) - __sgn;
}
__DEVICE__
inline long labs(long __x) {
  long __sgn = __x >> (sizeof(long) * CHAR_BIT - 1);
  return (__x ^ __sgn) - __sgn;
}
__DEVICE__
inline long long llabs(long long __x) {
  long long __sgn = __x >> (sizeof(long long) * CHAR_BIT - 1);
  return (__x ^ __sgn) - __sgn;
}

#if defined(__cplusplus)
__DEVICE__
inline long abs(long __x) { return labs(__x); }
__DEVICE__
inline long long abs(long long __x) { return llabs(__x); }
#endif
// END INTEGER

__DEVICE__
inline _Float16 fma(_Float16 __x, _Float16 __y, _Float16 __z) {
  return __ocml_fma_f16(__x, __y, __z);
}

__DEVICE__
inline float fma(float __x, float __y, float __z) {
  return fmaf(__x, __y, __z);
}

#pragma push_macro("__DEF_FUN1")
#pragma push_macro("__DEF_FUN2")
#pragma push_macro("__DEF_FUNI")
#pragma push_macro("__DEF_FLOAT_FUN2I")
#pragma push_macro("__HIP_OVERLOAD1")
#pragma push_macro("__HIP_OVERLOAD2")

// __hip_enable_if::type is a type function which returns __T if __B is true.
template <bool __B, class __T = void> struct __hip_enable_if {};

template <class __T> struct __hip_enable_if<true, __T> { typedef __T type; };

// __HIP_OVERLOAD1 is used to resolve function calls with integer argument to
// avoid compilation error due to ambibuity. e.g. floor(5) is resolved with
// floor(double).
#define __HIP_OVERLOAD1(__retty, __fn)                                         \
  template <typename __T>                                                      \
  __DEVICE__ typename __hip_enable_if<std::numeric_limits<__T>::is_integer,    \
                                      __retty>::type                           \
  __fn(__T __x) {                                                              \
    return ::__fn((double)__x);                                                \
  }

// __HIP_OVERLOAD2 is used to resolve function calls with mixed float/double
// or integer argument to avoid compilation error due to ambibuity. e.g.
// max(5.0f, 6.0) is resolved with max(double, double).
#define __HIP_OVERLOAD2(__retty, __fn)                                         \
  template <typename __T1, typename __T2>                                      \
  __DEVICE__                                                                   \
      typename __hip_enable_if<std::numeric_limits<__T1>::is_specialized &&    \
                                   std::numeric_limits<__T2>::is_specialized,  \
                               __retty>::type                                  \
      __fn(__T1 __x, __T2 __y) {                                               \
    return __fn((double)__x, (double)__y);                                     \
  }

// Define cmath functions with float argument and returns float.
#define __DEF_FUN1(__retty, __func)                                            \
  __DEVICE__                                                                   \
  inline float __func(float __x) { return __func##f(__x); }                    \
  __HIP_OVERLOAD1(__retty, __func)

// Define cmath functions with float argument and returns __retty.
#define __DEF_FUNI(__retty, __func)                                            \
  __DEVICE__                                                                   \
  inline __retty __func(float __x) { return __func##f(__x); }                  \
  __HIP_OVERLOAD1(__retty, __func)

// define cmath functions with two float arguments.
#define __DEF_FUN2(__retty, __func)                                            \
  __DEVICE__                                                                   \
  inline float __func(float __x, float __y) { return __func##f(__x, __y); }    \
  __HIP_OVERLOAD2(__retty, __func)

__DEF_FUN1(double, acos)
__DEF_FUN1(double, acosh)
__DEF_FUN1(double, asin)
__DEF_FUN1(double, asinh)
__DEF_FUN1(double, atan)
__DEF_FUN2(double, atan2);
__DEF_FUN1(double, atanh)
__DEF_FUN1(double, cbrt)
__DEF_FUN1(double, ceil)
__DEF_FUN2(double, copysign);
__DEF_FUN1(double, cos)
__DEF_FUN1(double, cosh)
__DEF_FUN1(double, erf)
__DEF_FUN1(double, erfc)
__DEF_FUN1(double, exp)
__DEF_FUN1(double, exp2)
__DEF_FUN1(double, expm1)
__DEF_FUN1(double, fabs)
__DEF_FUN2(double, fdim);
__DEF_FUN1(double, floor)
__DEF_FUN2(double, fmax);
__DEF_FUN2(double, fmin);
__DEF_FUN2(double, fmod);
//__HIP_OVERLOAD1(int, fpclassify)
__DEF_FUN2(double, hypot);
__DEF_FUNI(int, ilogb)
__HIP_OVERLOAD1(bool, isfinite)
__HIP_OVERLOAD2(bool, isgreater);
__HIP_OVERLOAD2(bool, isgreaterequal);
__HIP_OVERLOAD1(bool, isinf);
__HIP_OVERLOAD2(bool, isless);
__HIP_OVERLOAD2(bool, islessequal);
__HIP_OVERLOAD2(bool, islessgreater);
__HIP_OVERLOAD1(bool, isnan);
//__HIP_OVERLOAD1(bool, isnormal)
__HIP_OVERLOAD2(bool, isunordered);
__DEF_FUN1(double, lgamma)
__DEF_FUN1(double, log)
__DEF_FUN1(double, log10)
__DEF_FUN1(double, log1p)
__DEF_FUN1(double, log2)
__DEF_FUN1(double, logb)
__DEF_FUNI(long long, llrint)
__DEF_FUNI(long long, llround)
__DEF_FUNI(long, lrint)
__DEF_FUNI(long, lround)
__DEF_FUN1(double, nearbyint);
__DEF_FUN2(double, nextafter);
__DEF_FUN2(double, pow);
__DEF_FUN2(double, remainder);
__DEF_FUN1(double, rint);
__DEF_FUN1(double, round);
__HIP_OVERLOAD1(bool, signbit)
__DEF_FUN1(double, sin)
__DEF_FUN1(double, sinh)
__DEF_FUN1(double, sqrt)
__DEF_FUN1(double, tan)
__DEF_FUN1(double, tanh)
__DEF_FUN1(double, tgamma)
__DEF_FUN1(double, trunc);

// define cmath functions with a float and an integer argument.
#define __DEF_FLOAT_FUN2I(__func)                                              \
  __DEVICE__                                                                   \
  inline float __func(float __x, int __y) { return __func##f(__x, __y); }
__DEF_FLOAT_FUN2I(scalbn)

template <class T> __DEVICE__ inline T min(T __arg1, T __arg2) {
  return (__arg1 < __arg2) ? __arg1 : __arg2;
}

template <class T> __DEVICE__ inline T max(T __arg1, T __arg2) {
  return (__arg1 > __arg2) ? __arg1 : __arg2;
}

__DEVICE__ inline int min(int __arg1, int __arg2) {
  return (__arg1 < __arg2) ? __arg1 : __arg2;
}
__DEVICE__ inline int max(int __arg1, int __arg2) {
  return (__arg1 > __arg2) ? __arg1 : __arg2;
}

__DEVICE__
inline float max(float __x, float __y) { return fmaxf(__x, __y); }

__DEVICE__
inline double max(double __x, double __y) { return fmax(__x, __y); }

__DEVICE__
inline float min(float __x, float __y) { return fminf(__x, __y); }

__DEVICE__
inline double min(double __x, double __y) { return fmin(__x, __y); }

__HIP_OVERLOAD2(double, max)
__HIP_OVERLOAD2(double, min)

__host__ inline static int min(int __arg1, int __arg2) {
  return std::min(__arg1, __arg2);
}

__host__ inline static int max(int __arg1, int __arg2) {
  return std::max(__arg1, __arg2);
}

#pragma pop_macro("__DEF_FUN1")
#pragma pop_macro("__DEF_FUN2")
#pragma pop_macro("__DEF_FUNI")
#pragma pop_macro("__DEF_FLOAT_FUN2I")
#pragma pop_macro("__HIP_OVERLOAD1")
#pragma pop_macro("__HIP_OVERLOAD2")
#pragma pop_macro("__DEVICE__")
#pragma pop_macro("__RETURN_TYPE")

#endif // __CLANG_HIP_MATH_H__
