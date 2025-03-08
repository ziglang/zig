/* Copyright (C) 1998-2025 Free Software Foundation, Inc.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _FENV_H
# error "Never use <bits/fenv.h> directly; include <fenv.h> instead."
#endif


#ifdef __mips_hard_float

/* Define bits representing the exception.  We use the bit positions
   of the appropriate bits in the FPU control word.  */
enum
  {
    FE_INEXACT =
# define FE_INEXACT	0x04
      FE_INEXACT,
    FE_UNDERFLOW =
# define FE_UNDERFLOW	0x08
      FE_UNDERFLOW,
    FE_OVERFLOW =
# define FE_OVERFLOW	0x10
      FE_OVERFLOW,
    FE_DIVBYZERO =
# define FE_DIVBYZERO	0x20
      FE_DIVBYZERO,
    FE_INVALID =
# define FE_INVALID	0x40
      FE_INVALID,
  };

# define FE_ALL_EXCEPT \
	(FE_INEXACT | FE_DIVBYZERO | FE_UNDERFLOW | FE_OVERFLOW | FE_INVALID)

/* The MIPS FPU supports all of the four defined rounding modes.  We
   use again the bit positions in the FPU control word as the values
   for the appropriate macros.  */
enum
  {
    FE_TONEAREST =
# define FE_TONEAREST	0x0
      FE_TONEAREST,
    FE_TOWARDZERO =
# define FE_TOWARDZERO	0x1
      FE_TOWARDZERO,
    FE_UPWARD =
# define FE_UPWARD	0x2
      FE_UPWARD,
    FE_DOWNWARD =
# define FE_DOWNWARD	0x3
      FE_DOWNWARD
  };

#else

/* In the soft-float case, only rounding to nearest is supported, with
   no exceptions.  */

enum
  {
    __FE_UNDEFINED = -1,

    FE_TONEAREST =
# define FE_TONEAREST	0x0
      FE_TONEAREST
  };

# define FE_ALL_EXCEPT 0

#endif


/* Type representing exception flags.  */
typedef unsigned short int fexcept_t;


/* Type representing floating-point environment.  This function corresponds
   to the layout of the block written by the `fstenv'.  */
typedef struct
  {
    unsigned int __fp_control_register;
  }
fenv_t;

/* If the default argument is used we use this value.  */
#define FE_DFL_ENV	((const fenv_t *) -1)

#if defined __USE_GNU && defined __mips_hard_float
/* Floating-point environment where none of the exception is masked.  */
# define FE_NOMASK_ENV  ((const fenv_t *) -2)
#endif

#if __GLIBC_USE (IEC_60559_BFP_EXT_C23)
/* Type representing floating-point control modes.  */
typedef unsigned int femode_t;

/* Default floating-point control modes.  */
# define FE_DFL_MODE	((const femode_t *) -1L)
#endif