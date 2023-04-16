/* Copyright (C) 1997-2023 Free Software Foundation, Inc.
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

#ifndef _FENV_H
# error "Never use <bits/fenv.h> directly; include <fenv.h> instead."
#endif


/* Define bits representing the exception.  We use the bit positions of
   the appropriate bits in the FPSCR...  */
enum
  {
    FE_INEXACT =
#define FE_INEXACT	(1 << (31 - 6))
      FE_INEXACT,
    FE_DIVBYZERO =
#define FE_DIVBYZERO	(1 << (31 - 5))
      FE_DIVBYZERO,
    FE_UNDERFLOW =
#define FE_UNDERFLOW	(1 << (31 - 4))
      FE_UNDERFLOW,
    FE_OVERFLOW =
#define FE_OVERFLOW	(1 << (31 - 3))
      FE_OVERFLOW,

    /* ... except for FE_INVALID, for which we use bit 31. FE_INVALID
       actually corresponds to bits 7 through 12 and 21 through 23
       in the FPSCR, but we can't use that because the current draft
       says that it must be a power of 2.  Instead we use bit 2 which
       is the summary bit for all the FE_INVALID exceptions, which
       kind of makes sense.  */
    FE_INVALID =
#define FE_INVALID	(1 << (31 - 2))
      FE_INVALID,

#ifdef __USE_GNU
    /* Breakdown of the FE_INVALID bits. Setting FE_INVALID on an
       input to a routine is equivalent to setting all of these bits;
       FE_INVALID will be set on output from a routine iff one of
       these bits is set.  Note, though, that you can't disable or
       enable these exceptions individually.  */

    /* Operation with a sNaN.  */
    FE_INVALID_SNAN =
# define FE_INVALID_SNAN	(1 << (31 - 7))
      FE_INVALID_SNAN,

    /* Inf - Inf */
    FE_INVALID_ISI =
# define FE_INVALID_ISI	(1 << (31 - 8))
      FE_INVALID_ISI,

    /* Inf / Inf */
    FE_INVALID_IDI =
# define FE_INVALID_IDI	(1 << (31 - 9))
      FE_INVALID_IDI,

    /* 0 / 0 */
    FE_INVALID_ZDZ =
# define FE_INVALID_ZDZ	(1 << (31 - 10))
      FE_INVALID_ZDZ,

    /* Inf * 0 */
    FE_INVALID_IMZ =
# define FE_INVALID_IMZ	(1 << (31 - 11))
      FE_INVALID_IMZ,

    /* Comparison with a NaN.  */
    FE_INVALID_COMPARE =
# define FE_INVALID_COMPARE	(1 << (31 - 12))
      FE_INVALID_COMPARE,

    /* Invalid operation flag for software (not set by hardware).  */
    /* Note that some chips don't have this implemented, presumably
       because no-one expected anyone to write software for them %-).  */
    FE_INVALID_SOFTWARE =
# define FE_INVALID_SOFTWARE	(1 << (31 - 21))
      FE_INVALID_SOFTWARE,

    /* Square root of negative number (including -Inf).  */
    /* Note that some chips don't have this implemented.  */
    FE_INVALID_SQRT =
# define FE_INVALID_SQRT	(1 << (31 - 22))
      FE_INVALID_SQRT,

    /* Conversion-to-integer of a NaN or a number too large or too small.  */
    FE_INVALID_INTEGER_CONVERSION =
# define FE_INVALID_INTEGER_CONVERSION	(1 << (31 - 23))
      FE_INVALID_INTEGER_CONVERSION

# define FE_ALL_INVALID \
        (FE_INVALID_SNAN | FE_INVALID_ISI | FE_INVALID_IDI | FE_INVALID_ZDZ \
	 | FE_INVALID_IMZ | FE_INVALID_COMPARE | FE_INVALID_SOFTWARE \
	 | FE_INVALID_SQRT | FE_INVALID_INTEGER_CONVERSION)
#endif
  };

#define FE_ALL_EXCEPT \
	(FE_INEXACT | FE_DIVBYZERO | FE_UNDERFLOW | FE_OVERFLOW | FE_INVALID)

/* PowerPC chips support all of the four defined rounding modes.  We
   use the bit pattern in the FPSCR as the values for the
   appropriate macros.  */
enum
  {
    FE_TONEAREST =
#define FE_TONEAREST	0
      FE_TONEAREST,
    FE_TOWARDZERO =
#define FE_TOWARDZERO	1
      FE_TOWARDZERO,
    FE_UPWARD =
#define FE_UPWARD	2
      FE_UPWARD,
    FE_DOWNWARD =
#define FE_DOWNWARD	3
      FE_DOWNWARD
  };

/* Type representing exception flags.  */
typedef unsigned int fexcept_t;

/* Type representing floating-point environment.  We leave it as 'double'
   for efficiency reasons (rather than writing it to a 32-bit integer). */
typedef double fenv_t;

/* If the default argument is used we use this value.  */
extern const fenv_t __fe_dfl_env;
#define FE_DFL_ENV	(&__fe_dfl_env)

#ifdef __USE_GNU
/* Floating-point environment where all exceptions are enabled.  Note that
   this is not sufficient to give you SIGFPE.  */
extern const fenv_t __fe_enabled_env;
# define FE_ENABLED_ENV	(&__fe_enabled_env)

/* Floating-point environment with (processor-dependent) non-IEEE floating
   point.  */
extern const fenv_t __fe_nonieee_env;
# define FE_NONIEEE_ENV	(&__fe_nonieee_env)

/* Floating-point environment with all exceptions enabled.  Note that
   just evaluating this value does not change the processor exception mode.
   Passing this mask to fesetenv will result in a prctl syscall to change
   the MSR FE0/FE1 bits to "Precise Mode".  On some processors this will
   result in slower floating point execution.  This will last until an
   fenv or exception mask is installed that disables all FP exceptions.  */
# define FE_NOMASK_ENV	FE_ENABLED_ENV

/* Floating-point environment with all exceptions disabled.  Note that
   just evaluating this value does not change the processor exception mode.
   Passing this mask to fesetenv will result in a prctl syscall to change
   the MSR FE0/FE1 bits to "Ignore Exceptions Mode".  On most processors
   this allows the fastest possible floating point execution.*/
# define FE_MASK_ENV	FE_DFL_ENV

#endif

#if __GLIBC_USE (IEC_60559_BFP_EXT_C2X)
/* Type representing floating-point control modes.  */
typedef double femode_t;

/* Default floating-point control modes.  */
extern const femode_t __fe_dfl_mode;
# define FE_DFL_MODE	(&__fe_dfl_mode)
#endif