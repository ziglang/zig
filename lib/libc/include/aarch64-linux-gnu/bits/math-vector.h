/* Platform-specific SIMD declarations of math functions.

   Copyright (C) 2023-2024 Free Software Foundation, Inc.
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
#  error "Never include <bits/math-vector.h> directly;\
 include <math.h> instead."
#endif

/* Get default empty definitions for simd declarations.  */
#include <bits/libm-simd-decl-stubs.h>

#if defined __aarch64__ && defined __FAST_MATH__ && __GNUC_PREREQ (6, 0)
/* Requires GCC >= 6 for __attribute__ ((__simd__)).  */
# define __DECL_SIMD_aarch64 __attribute__ ((__simd__ ("notinbranch"), const))

# undef __DECL_SIMD_acos
# define __DECL_SIMD_acos __DECL_SIMD_aarch64
# undef __DECL_SIMD_acosf
# define __DECL_SIMD_acosf __DECL_SIMD_aarch64
# undef __DECL_SIMD_acosh
# define __DECL_SIMD_acosh __DECL_SIMD_aarch64
# undef __DECL_SIMD_acoshf
# define __DECL_SIMD_acoshf __DECL_SIMD_aarch64
# undef __DECL_SIMD_asin
# define __DECL_SIMD_asin __DECL_SIMD_aarch64
# undef __DECL_SIMD_asinf
# define __DECL_SIMD_asinf __DECL_SIMD_aarch64
# undef __DECL_SIMD_asinh
# define __DECL_SIMD_asinh __DECL_SIMD_aarch64
# undef __DECL_SIMD_asinhf
# define __DECL_SIMD_asinhf __DECL_SIMD_aarch64
# undef __DECL_SIMD_atan
# define __DECL_SIMD_atan __DECL_SIMD_aarch64
# undef __DECL_SIMD_atanf
# define __DECL_SIMD_atanf __DECL_SIMD_aarch64
# undef __DECL_SIMD_atanh
# define __DECL_SIMD_atanh __DECL_SIMD_aarch64
# undef __DECL_SIMD_atanhf
# define __DECL_SIMD_atanhf __DECL_SIMD_aarch64
# undef __DECL_SIMD_atan2
# define __DECL_SIMD_atan2 __DECL_SIMD_aarch64
# undef __DECL_SIMD_atan2f
# define __DECL_SIMD_atan2f __DECL_SIMD_aarch64
# undef __DECL_SIMD_cbrt
# define __DECL_SIMD_cbrt __DECL_SIMD_aarch64
# undef __DECL_SIMD_cbrtf
# define __DECL_SIMD_cbrtf __DECL_SIMD_aarch64
# undef __DECL_SIMD_cos
# define __DECL_SIMD_cos __DECL_SIMD_aarch64
# undef __DECL_SIMD_cosf
# define __DECL_SIMD_cosf __DECL_SIMD_aarch64
# undef __DECL_SIMD_cosh
# define __DECL_SIMD_cosh __DECL_SIMD_aarch64
# undef __DECL_SIMD_coshf
# define __DECL_SIMD_coshf __DECL_SIMD_aarch64
# undef __DECL_SIMD_erf
# define __DECL_SIMD_erf __DECL_SIMD_aarch64
# undef __DECL_SIMD_erff
# define __DECL_SIMD_erff __DECL_SIMD_aarch64
# undef __DECL_SIMD_erfc
# define __DECL_SIMD_erfc __DECL_SIMD_aarch64
# undef __DECL_SIMD_erfcf
# define __DECL_SIMD_erfcf __DECL_SIMD_aarch64
# undef __DECL_SIMD_exp
# define __DECL_SIMD_exp __DECL_SIMD_aarch64
# undef __DECL_SIMD_expf
# define __DECL_SIMD_expf __DECL_SIMD_aarch64
# undef __DECL_SIMD_exp10
# define __DECL_SIMD_exp10 __DECL_SIMD_aarch64
# undef __DECL_SIMD_exp10f
# define __DECL_SIMD_exp10f __DECL_SIMD_aarch64
# undef __DECL_SIMD_exp2
# define __DECL_SIMD_exp2 __DECL_SIMD_aarch64
# undef __DECL_SIMD_exp2f
# define __DECL_SIMD_exp2f __DECL_SIMD_aarch64
# undef __DECL_SIMD_expm1
# define __DECL_SIMD_expm1 __DECL_SIMD_aarch64
# undef __DECL_SIMD_expm1f
# define __DECL_SIMD_expm1f __DECL_SIMD_aarch64
# undef __DECL_SIMD_hypot
# define __DECL_SIMD_hypot __DECL_SIMD_aarch64
# undef __DECL_SIMD_hypotf
# define __DECL_SIMD_hypotf __DECL_SIMD_aarch64
# undef __DECL_SIMD_log
# define __DECL_SIMD_log __DECL_SIMD_aarch64
# undef __DECL_SIMD_logf
# define __DECL_SIMD_logf __DECL_SIMD_aarch64
# undef __DECL_SIMD_log10
# define __DECL_SIMD_log10 __DECL_SIMD_aarch64
# undef __DECL_SIMD_log10f
# define __DECL_SIMD_log10f __DECL_SIMD_aarch64
# undef __DECL_SIMD_log1p
# define __DECL_SIMD_log1p __DECL_SIMD_aarch64
# undef __DECL_SIMD_log1pf
# define __DECL_SIMD_log1pf __DECL_SIMD_aarch64
# undef __DECL_SIMD_log2
# define __DECL_SIMD_log2 __DECL_SIMD_aarch64
# undef __DECL_SIMD_log2f
# define __DECL_SIMD_log2f __DECL_SIMD_aarch64
# undef __DECL_SIMD_pow
# define __DECL_SIMD_pow __DECL_SIMD_aarch64
# undef __DECL_SIMD_powf
# define __DECL_SIMD_powf __DECL_SIMD_aarch64
# undef __DECL_SIMD_sin
# define __DECL_SIMD_sin __DECL_SIMD_aarch64
# undef __DECL_SIMD_sinf
# define __DECL_SIMD_sinf __DECL_SIMD_aarch64
# undef __DECL_SIMD_sinh
# define __DECL_SIMD_sinh __DECL_SIMD_aarch64
# undef __DECL_SIMD_sinhf
# define __DECL_SIMD_sinhf __DECL_SIMD_aarch64
# undef __DECL_SIMD_tan
# define __DECL_SIMD_tan __DECL_SIMD_aarch64
# undef __DECL_SIMD_tanf
# define __DECL_SIMD_tanf __DECL_SIMD_aarch64
# undef __DECL_SIMD_tanh
# define __DECL_SIMD_tanh __DECL_SIMD_aarch64
# undef __DECL_SIMD_tanhf
# define __DECL_SIMD_tanhf __DECL_SIMD_aarch64
#endif

#if __GNUC_PREREQ(9, 0)
#  define __ADVSIMD_VEC_MATH_SUPPORTED
typedef __Float32x4_t __f32x4_t;
typedef __Float64x2_t __f64x2_t;
#elif __glibc_clang_prereq(8, 0)
#  define __ADVSIMD_VEC_MATH_SUPPORTED
typedef __attribute__ ((__neon_vector_type__ (4))) float __f32x4_t;
typedef __attribute__ ((__neon_vector_type__ (2))) double __f64x2_t;
#endif

#if __GNUC_PREREQ(10, 0) || __glibc_clang_prereq(11, 0)
#  define __SVE_VEC_MATH_SUPPORTED
typedef __SVFloat32_t __sv_f32_t;
typedef __SVFloat64_t __sv_f64_t;
typedef __SVBool_t __sv_bool_t;
#endif

/* If vector types and vector PCS are unsupported in the working
   compiler, no choice but to omit vector math declarations.  */

#ifdef __ADVSIMD_VEC_MATH_SUPPORTED

#  define __vpcs __attribute__ ((__aarch64_vector_pcs__))

__vpcs __f32x4_t _ZGVnN4vv_atan2f (__f32x4_t, __f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_acosf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_acoshf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_asinf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_asinhf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_atanf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_atanhf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_cbrtf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_cosf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_coshf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_erff (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_erfcf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_expf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_exp10f (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_exp2f (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_expm1f (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4vv_hypotf (__f32x4_t, __f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_logf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_log10f (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_log1pf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_log2f (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4vv_powf (__f32x4_t, __f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_sinf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_sinhf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_tanf (__f32x4_t);
__vpcs __f32x4_t _ZGVnN4v_tanhf (__f32x4_t);

__vpcs __f64x2_t _ZGVnN2vv_atan2 (__f64x2_t, __f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_acos (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_acosh (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_asin (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_asinh (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_atan (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_atanh (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_cbrt (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_cos (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_cosh (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_erf (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_erfc (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_exp (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_exp10 (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_exp2 (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_expm1 (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2vv_hypot (__f64x2_t, __f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_log (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_log10 (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_log1p (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_log2 (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2vv_pow (__f64x2_t, __f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_sin (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_sinh (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_tan (__f64x2_t);
__vpcs __f64x2_t _ZGVnN2v_tanh (__f64x2_t);

#  undef __ADVSIMD_VEC_MATH_SUPPORTED
#endif /* __ADVSIMD_VEC_MATH_SUPPORTED */

#ifdef __SVE_VEC_MATH_SUPPORTED

__sv_f32_t _ZGVsMxvv_atan2f (__sv_f32_t, __sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_acosf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_acoshf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_asinf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_asinhf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_atanf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_atanhf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_cbrtf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_cosf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_coshf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_erff (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_erfcf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_expf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_exp10f (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_exp2f (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_expm1f (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxvv_hypotf (__sv_f32_t, __sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_logf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_log10f (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_log1pf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_log2f (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxvv_powf (__sv_f32_t, __sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_sinf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_sinhf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_tanf (__sv_f32_t, __sv_bool_t);
__sv_f32_t _ZGVsMxv_tanhf (__sv_f32_t, __sv_bool_t);

__sv_f64_t _ZGVsMxvv_atan2 (__sv_f64_t, __sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_acos (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_acosh (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_asin (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_asinh (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_atan (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_atanh (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_cbrt (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_cos (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_cosh (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_erf (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_erfc (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_exp (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_exp10 (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_exp2 (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_expm1 (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxvv_hypot (__sv_f64_t, __sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_log (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_log10 (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_log1p (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_log2 (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxvv_pow (__sv_f64_t, __sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_sin (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_sinh (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_tan (__sv_f64_t, __sv_bool_t);
__sv_f64_t _ZGVsMxv_tanh (__sv_f64_t, __sv_bool_t);

#  undef __SVE_VEC_MATH_SUPPORTED
#endif /* __SVE_VEC_MATH_SUPPORTED */