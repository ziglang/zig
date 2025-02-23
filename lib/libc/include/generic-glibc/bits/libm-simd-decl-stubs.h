/* Empty definitions required for __MATHCALL_VEC unfolding in mathcalls.h.
   Copyright (C) 2014-2025 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _MATH_H
# error "Never include <bits/libm-simd-decl-stubs.h> directly;\
 include <math.h> instead."
#endif

/* Needed definitions could be generated with:
   for func in $(grep __MATHCALL_VEC math/bits/mathcalls.h |\
		 sed -r "s|__MATHCALL_VEC.?\(||; s|,.*||"); do
     echo "#define __DECL_SIMD_${func}";
     echo "#define __DECL_SIMD_${func}f";
     echo "#define __DECL_SIMD_${func}l";
   done
 */

#ifndef _BITS_LIBM_SIMD_DECL_STUBS_H
#define _BITS_LIBM_SIMD_DECL_STUBS_H 1

#define __DECL_SIMD_cos
#define __DECL_SIMD_cosf
#define __DECL_SIMD_cosl
#define __DECL_SIMD_cosf16
#define __DECL_SIMD_cosf32
#define __DECL_SIMD_cosf64
#define __DECL_SIMD_cosf128
#define __DECL_SIMD_cosf32x
#define __DECL_SIMD_cosf64x
#define __DECL_SIMD_cosf128x

#define __DECL_SIMD_sin
#define __DECL_SIMD_sinf
#define __DECL_SIMD_sinl
#define __DECL_SIMD_sinf16
#define __DECL_SIMD_sinf32
#define __DECL_SIMD_sinf64
#define __DECL_SIMD_sinf128
#define __DECL_SIMD_sinf32x
#define __DECL_SIMD_sinf64x
#define __DECL_SIMD_sinf128x

#define __DECL_SIMD_sincos
#define __DECL_SIMD_sincosf
#define __DECL_SIMD_sincosl
#define __DECL_SIMD_sincosf16
#define __DECL_SIMD_sincosf32
#define __DECL_SIMD_sincosf64
#define __DECL_SIMD_sincosf128
#define __DECL_SIMD_sincosf32x
#define __DECL_SIMD_sincosf64x
#define __DECL_SIMD_sincosf128x

#define __DECL_SIMD_log
#define __DECL_SIMD_logf
#define __DECL_SIMD_logl
#define __DECL_SIMD_logf16
#define __DECL_SIMD_logf32
#define __DECL_SIMD_logf64
#define __DECL_SIMD_logf128
#define __DECL_SIMD_logf32x
#define __DECL_SIMD_logf64x
#define __DECL_SIMD_logf128x

#define __DECL_SIMD_exp
#define __DECL_SIMD_expf
#define __DECL_SIMD_expl
#define __DECL_SIMD_expf16
#define __DECL_SIMD_expf32
#define __DECL_SIMD_expf64
#define __DECL_SIMD_expf128
#define __DECL_SIMD_expf32x
#define __DECL_SIMD_expf64x
#define __DECL_SIMD_expf128x

#define __DECL_SIMD_pow
#define __DECL_SIMD_powf
#define __DECL_SIMD_powl
#define __DECL_SIMD_powf16
#define __DECL_SIMD_powf32
#define __DECL_SIMD_powf64
#define __DECL_SIMD_powf128
#define __DECL_SIMD_powf32x
#define __DECL_SIMD_powf64x
#define __DECL_SIMD_powf128x

#define __DECL_SIMD_acos
#define __DECL_SIMD_acosf
#define __DECL_SIMD_acosl
#define __DECL_SIMD_acosf16
#define __DECL_SIMD_acosf32
#define __DECL_SIMD_acosf64
#define __DECL_SIMD_acosf128
#define __DECL_SIMD_acosf32x
#define __DECL_SIMD_acosf64x
#define __DECL_SIMD_acosf128x

#define __DECL_SIMD_atan
#define __DECL_SIMD_atanf
#define __DECL_SIMD_atanl
#define __DECL_SIMD_atanf16
#define __DECL_SIMD_atanf32
#define __DECL_SIMD_atanf64
#define __DECL_SIMD_atanf128
#define __DECL_SIMD_atanf32x
#define __DECL_SIMD_atanf64x
#define __DECL_SIMD_atanf128x

#define __DECL_SIMD_asin
#define __DECL_SIMD_asinf
#define __DECL_SIMD_asinl
#define __DECL_SIMD_asinf16
#define __DECL_SIMD_asinf32
#define __DECL_SIMD_asinf64
#define __DECL_SIMD_asinf128
#define __DECL_SIMD_asinf32x
#define __DECL_SIMD_asinf64x
#define __DECL_SIMD_asinf128x

#define __DECL_SIMD_hypot
#define __DECL_SIMD_hypotf
#define __DECL_SIMD_hypotl
#define __DECL_SIMD_hypotf16
#define __DECL_SIMD_hypotf32
#define __DECL_SIMD_hypotf64
#define __DECL_SIMD_hypotf128
#define __DECL_SIMD_hypotf32x
#define __DECL_SIMD_hypotf64x
#define __DECL_SIMD_hypotf128x

#define __DECL_SIMD_exp2
#define __DECL_SIMD_exp2f
#define __DECL_SIMD_exp2l
#define __DECL_SIMD_exp2f16
#define __DECL_SIMD_exp2f32
#define __DECL_SIMD_exp2f64
#define __DECL_SIMD_exp2f128
#define __DECL_SIMD_exp2f32x
#define __DECL_SIMD_exp2f64x
#define __DECL_SIMD_exp2f128x

#define __DECL_SIMD_exp10
#define __DECL_SIMD_exp10f
#define __DECL_SIMD_exp10l
#define __DECL_SIMD_exp10f16
#define __DECL_SIMD_exp10f32
#define __DECL_SIMD_exp10f64
#define __DECL_SIMD_exp10f128
#define __DECL_SIMD_exp10f32x
#define __DECL_SIMD_exp10f64x
#define __DECL_SIMD_exp10f128x

#define __DECL_SIMD_cosh
#define __DECL_SIMD_coshf
#define __DECL_SIMD_coshl
#define __DECL_SIMD_coshf16
#define __DECL_SIMD_coshf32
#define __DECL_SIMD_coshf64
#define __DECL_SIMD_coshf128
#define __DECL_SIMD_coshf32x
#define __DECL_SIMD_coshf64x
#define __DECL_SIMD_coshf128x

#define __DECL_SIMD_expm1
#define __DECL_SIMD_expm1f
#define __DECL_SIMD_expm1l
#define __DECL_SIMD_expm1f16
#define __DECL_SIMD_expm1f32
#define __DECL_SIMD_expm1f64
#define __DECL_SIMD_expm1f128
#define __DECL_SIMD_expm1f32x
#define __DECL_SIMD_expm1f64x
#define __DECL_SIMD_expm1f128x

#define __DECL_SIMD_sinh
#define __DECL_SIMD_sinhf
#define __DECL_SIMD_sinhl
#define __DECL_SIMD_sinhf16
#define __DECL_SIMD_sinhf32
#define __DECL_SIMD_sinhf64
#define __DECL_SIMD_sinhf128
#define __DECL_SIMD_sinhf32x
#define __DECL_SIMD_sinhf64x
#define __DECL_SIMD_sinhf128x

#define __DECL_SIMD_cbrt
#define __DECL_SIMD_cbrtf
#define __DECL_SIMD_cbrtl
#define __DECL_SIMD_cbrtf16
#define __DECL_SIMD_cbrtf32
#define __DECL_SIMD_cbrtf64
#define __DECL_SIMD_cbrtf128
#define __DECL_SIMD_cbrtf32x
#define __DECL_SIMD_cbrtf64x
#define __DECL_SIMD_cbrtf128x

#define __DECL_SIMD_atan2
#define __DECL_SIMD_atan2f
#define __DECL_SIMD_atan2l
#define __DECL_SIMD_atan2f16
#define __DECL_SIMD_atan2f32
#define __DECL_SIMD_atan2f64
#define __DECL_SIMD_atan2f128
#define __DECL_SIMD_atan2f32x
#define __DECL_SIMD_atan2f64x
#define __DECL_SIMD_atan2f128x

#define __DECL_SIMD_log10
#define __DECL_SIMD_log10f
#define __DECL_SIMD_log10l
#define __DECL_SIMD_log10f16
#define __DECL_SIMD_log10f32
#define __DECL_SIMD_log10f64
#define __DECL_SIMD_log10f128
#define __DECL_SIMD_log10f32x
#define __DECL_SIMD_log10f64x
#define __DECL_SIMD_log10f128x

#define __DECL_SIMD_log2
#define __DECL_SIMD_log2f
#define __DECL_SIMD_log2l
#define __DECL_SIMD_log2f16
#define __DECL_SIMD_log2f32
#define __DECL_SIMD_log2f64
#define __DECL_SIMD_log2f128
#define __DECL_SIMD_log2f32x
#define __DECL_SIMD_log2f64x
#define __DECL_SIMD_log2f128x

#define __DECL_SIMD_log1p
#define __DECL_SIMD_log1pf
#define __DECL_SIMD_log1pl
#define __DECL_SIMD_log1pf16
#define __DECL_SIMD_log1pf32
#define __DECL_SIMD_log1pf64
#define __DECL_SIMD_log1pf128
#define __DECL_SIMD_log1pf32x
#define __DECL_SIMD_log1pf64x
#define __DECL_SIMD_log1pf128x

#define __DECL_SIMD_logp1
#define __DECL_SIMD_logp1f
#define __DECL_SIMD_logp1l
#define __DECL_SIMD_logp1f16
#define __DECL_SIMD_logp1f32
#define __DECL_SIMD_logp1f64
#define __DECL_SIMD_logp1f128
#define __DECL_SIMD_logp1f32x
#define __DECL_SIMD_logp1f64x
#define __DECL_SIMD_logp1f128x

#define __DECL_SIMD_atanh
#define __DECL_SIMD_atanhf
#define __DECL_SIMD_atanhl
#define __DECL_SIMD_atanhf16
#define __DECL_SIMD_atanhf32
#define __DECL_SIMD_atanhf64
#define __DECL_SIMD_atanhf128
#define __DECL_SIMD_atanhf32x
#define __DECL_SIMD_atanhf64x
#define __DECL_SIMD_atanhf128x

#define __DECL_SIMD_acosh
#define __DECL_SIMD_acoshf
#define __DECL_SIMD_acoshl
#define __DECL_SIMD_acoshf16
#define __DECL_SIMD_acoshf32
#define __DECL_SIMD_acoshf64
#define __DECL_SIMD_acoshf128
#define __DECL_SIMD_acoshf32x
#define __DECL_SIMD_acoshf64x
#define __DECL_SIMD_acoshf128x

#define __DECL_SIMD_erf
#define __DECL_SIMD_erff
#define __DECL_SIMD_erfl
#define __DECL_SIMD_erff16
#define __DECL_SIMD_erff32
#define __DECL_SIMD_erff64
#define __DECL_SIMD_erff128
#define __DECL_SIMD_erff32x
#define __DECL_SIMD_erff64x
#define __DECL_SIMD_erff128x

#define __DECL_SIMD_tanh
#define __DECL_SIMD_tanhf
#define __DECL_SIMD_tanhl
#define __DECL_SIMD_tanhf16
#define __DECL_SIMD_tanhf32
#define __DECL_SIMD_tanhf64
#define __DECL_SIMD_tanhf128
#define __DECL_SIMD_tanhf32x
#define __DECL_SIMD_tanhf64x
#define __DECL_SIMD_tanhf128x

#define __DECL_SIMD_asinh
#define __DECL_SIMD_asinhf
#define __DECL_SIMD_asinhl
#define __DECL_SIMD_asinhf16
#define __DECL_SIMD_asinhf32
#define __DECL_SIMD_asinhf64
#define __DECL_SIMD_asinhf128
#define __DECL_SIMD_asinhf32x
#define __DECL_SIMD_asinhf64x
#define __DECL_SIMD_asinhf128x

#define __DECL_SIMD_erfc
#define __DECL_SIMD_erfcf
#define __DECL_SIMD_erfcl
#define __DECL_SIMD_erfcf16
#define __DECL_SIMD_erfcf32
#define __DECL_SIMD_erfcf64
#define __DECL_SIMD_erfcf128
#define __DECL_SIMD_erfcf32x
#define __DECL_SIMD_erfcf64x
#define __DECL_SIMD_erfcf128x

#define __DECL_SIMD_tan
#define __DECL_SIMD_tanf
#define __DECL_SIMD_tanl
#define __DECL_SIMD_tanf16
#define __DECL_SIMD_tanf32
#define __DECL_SIMD_tanf64
#define __DECL_SIMD_tanf128
#define __DECL_SIMD_tanf32x
#define __DECL_SIMD_tanf64x
#define __DECL_SIMD_tanf128x

#define __DECL_SIMD_sinpi
#define __DECL_SIMD_sinpif
#define __DECL_SIMD_sinpil
#define __DECL_SIMD_sinpif16
#define __DECL_SIMD_sinpif32
#define __DECL_SIMD_sinpif64
#define __DECL_SIMD_sinpif128
#define __DECL_SIMD_sinpif32x
#define __DECL_SIMD_sinpif64x
#define __DECL_SIMD_sinpif128x

#define __DECL_SIMD_cospi
#define __DECL_SIMD_cospif
#define __DECL_SIMD_cospil
#define __DECL_SIMD_cospif16
#define __DECL_SIMD_cospif32
#define __DECL_SIMD_cospif64
#define __DECL_SIMD_cospif128
#define __DECL_SIMD_cospif32x
#define __DECL_SIMD_cospif64x
#define __DECL_SIMD_cospif128x

#define __DECL_SIMD_tanpi
#define __DECL_SIMD_tanpif
#define __DECL_SIMD_tanpil
#define __DECL_SIMD_tanpif16
#define __DECL_SIMD_tanpif32
#define __DECL_SIMD_tanpif64
#define __DECL_SIMD_tanpif128
#define __DECL_SIMD_tanpif32x
#define __DECL_SIMD_tanpif64x
#define __DECL_SIMD_tanpif128x
#endif