/* Platform-specific SIMD declarations of math functions.
   Copyright (C) 2014-2024 Free Software Foundation, Inc.
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
# error "Never include <bits/math-vector.h> directly;\
 include <math.h> instead."
#endif

/* Get default empty definitions for simd declarations.  */
#include <bits/libm-simd-decl-stubs.h>

#if defined __x86_64__ && defined __FAST_MATH__
# if defined _OPENMP && _OPENMP >= 201307
/* OpenMP case.  */
#  define __DECL_SIMD_x86_64 _Pragma ("omp declare simd notinbranch")
# elif __GNUC_PREREQ (6,0)
/* W/o OpenMP use GCC 6.* __attribute__ ((__simd__)).  */
#  define __DECL_SIMD_x86_64 __attribute__ ((__simd__ ("notinbranch")))
# endif

# ifdef __DECL_SIMD_x86_64
#  undef __DECL_SIMD_cos
#  define __DECL_SIMD_cos __DECL_SIMD_x86_64
#  undef __DECL_SIMD_cosf
#  define __DECL_SIMD_cosf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_sin
#  define __DECL_SIMD_sin __DECL_SIMD_x86_64
#  undef __DECL_SIMD_sinf
#  define __DECL_SIMD_sinf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_sincos
#  define __DECL_SIMD_sincos __DECL_SIMD_x86_64
#  undef __DECL_SIMD_sincosf
#  define __DECL_SIMD_sincosf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_log
#  define __DECL_SIMD_log __DECL_SIMD_x86_64
#  undef __DECL_SIMD_logf
#  define __DECL_SIMD_logf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_exp
#  define __DECL_SIMD_exp __DECL_SIMD_x86_64
#  undef __DECL_SIMD_expf
#  define __DECL_SIMD_expf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_pow
#  define __DECL_SIMD_pow __DECL_SIMD_x86_64
#  undef __DECL_SIMD_powf
#  define __DECL_SIMD_powf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_acos
#  define __DECL_SIMD_acos __DECL_SIMD_x86_64
#  undef __DECL_SIMD_acosf
#  define __DECL_SIMD_acosf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_atan
#  define __DECL_SIMD_atan __DECL_SIMD_x86_64
#  undef __DECL_SIMD_atanf
#  define __DECL_SIMD_atanf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_asin
#  define __DECL_SIMD_asin __DECL_SIMD_x86_64
#  undef __DECL_SIMD_asinf
#  define __DECL_SIMD_asinf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_hypot
#  define __DECL_SIMD_hypot __DECL_SIMD_x86_64
#  undef __DECL_SIMD_hypotf
#  define __DECL_SIMD_hypotf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_exp2
#  define __DECL_SIMD_exp2 __DECL_SIMD_x86_64
#  undef __DECL_SIMD_exp2f
#  define __DECL_SIMD_exp2f __DECL_SIMD_x86_64
#  undef __DECL_SIMD_exp10
#  define __DECL_SIMD_exp10 __DECL_SIMD_x86_64
#  undef __DECL_SIMD_exp10f
#  define __DECL_SIMD_exp10f __DECL_SIMD_x86_64
#  undef __DECL_SIMD_cosh
#  define __DECL_SIMD_cosh __DECL_SIMD_x86_64
#  undef __DECL_SIMD_coshf
#  define __DECL_SIMD_coshf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_expm1
#  define __DECL_SIMD_expm1 __DECL_SIMD_x86_64
#  undef __DECL_SIMD_expm1f
#  define __DECL_SIMD_expm1f __DECL_SIMD_x86_64
#  undef __DECL_SIMD_sinh
#  define __DECL_SIMD_sinh __DECL_SIMD_x86_64
#  undef __DECL_SIMD_sinhf
#  define __DECL_SIMD_sinhf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_cbrt
#  define __DECL_SIMD_cbrt __DECL_SIMD_x86_64
#  undef __DECL_SIMD_cbrtf
#  define __DECL_SIMD_cbrtf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_atan2
#  define __DECL_SIMD_atan2 __DECL_SIMD_x86_64
#  undef __DECL_SIMD_atan2f
#  define __DECL_SIMD_atan2f __DECL_SIMD_x86_64
#  undef __DECL_SIMD_log10
#  define __DECL_SIMD_log10 __DECL_SIMD_x86_64
#  undef __DECL_SIMD_log10f
#  define __DECL_SIMD_log10f __DECL_SIMD_x86_64
#  undef __DECL_SIMD_log2
#  define __DECL_SIMD_log2 __DECL_SIMD_x86_64
#  undef __DECL_SIMD_log2f
#  define __DECL_SIMD_log2f __DECL_SIMD_x86_64
#  undef __DECL_SIMD_log1p
#  define __DECL_SIMD_log1p __DECL_SIMD_x86_64
#  undef __DECL_SIMD_log1pf
#  define __DECL_SIMD_log1pf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_atanh
#  define __DECL_SIMD_atanh __DECL_SIMD_x86_64
#  undef __DECL_SIMD_atanhf
#  define __DECL_SIMD_atanhf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_acosh
#  define __DECL_SIMD_acosh __DECL_SIMD_x86_64
#  undef __DECL_SIMD_acoshf
#  define __DECL_SIMD_acoshf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_erf
#  define __DECL_SIMD_erf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_erff
#  define __DECL_SIMD_erff __DECL_SIMD_x86_64
#  undef __DECL_SIMD_tanh
#  define __DECL_SIMD_tanh __DECL_SIMD_x86_64
#  undef __DECL_SIMD_tanhf
#  define __DECL_SIMD_tanhf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_asinh
#  define __DECL_SIMD_asinh __DECL_SIMD_x86_64
#  undef __DECL_SIMD_asinhf
#  define __DECL_SIMD_asinhf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_erfc
#  define __DECL_SIMD_erfc __DECL_SIMD_x86_64
#  undef __DECL_SIMD_erfcf
#  define __DECL_SIMD_erfcf __DECL_SIMD_x86_64
#  undef __DECL_SIMD_tan
#  define __DECL_SIMD_tan __DECL_SIMD_x86_64
#  undef __DECL_SIMD_tanf
#  define __DECL_SIMD_tanf __DECL_SIMD_x86_64

# endif
#endif