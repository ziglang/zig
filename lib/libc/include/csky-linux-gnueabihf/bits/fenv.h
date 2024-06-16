/* Floating point environment.  C-SKY version.
   Copyright (C) 2018-2024 Free Software Foundation, Inc.
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

#ifdef __csky_hard_float__
/* Define bits representing the exception.  We use the bit positions
   of the appropriate bits in the FPU control word.  */
enum
  {
    FE_INVALID =
#define FE_INVALID	0x01
      FE_INVALID,
    FE_DIVBYZERO =
#define FE_DIVBYZERO	0x02
      FE_DIVBYZERO,
    FE_OVERFLOW =
#define FE_OVERFLOW	0x04
      FE_OVERFLOW,
    FE_UNDERFLOW =
#define FE_UNDERFLOW	0x08
      FE_UNDERFLOW,
    FE_INEXACT =
#define FE_INEXACT	0x10
      FE_INEXACT,
    __FE_DENORMAL = 0x20
  };

#define FE_ALL_EXCEPT \
	(FE_INEXACT | FE_DIVBYZERO | FE_UNDERFLOW | FE_OVERFLOW | FE_INVALID)

/* The C-SKY FPU supports all of the four defined rounding modes.  We
   use again the bit positions in the FPU control word as the values
   for the appropriate macros.  */
enum
  {
    FE_TONEAREST =
#define FE_TONEAREST	(0x0 << 24)
      FE_TONEAREST,
    FE_TOWARDZERO =
#define FE_TOWARDZERO	(0x1 << 24)
      FE_TOWARDZERO,
    FE_UPWARD =
#define FE_UPWARD	(0x2 << 24)
      FE_UPWARD,
    FE_DOWNWARD =
#define FE_DOWNWARD	(0x3 << 24)
      FE_DOWNWARD,
    __FE_ROUND_MASK = (0x3 << 24)
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
typedef unsigned int fexcept_t;

/* Type representing floating-point environment.  */
typedef struct
{
  unsigned int __fpcr;
  unsigned int __fpsr;
} fenv_t;

/* If the default argument is used we use this value.  */
#define FE_DFL_ENV	((const fenv_t *) -1)

#if defined __USE_GNU && defined __csky_hard_float__
/* Floating-point environment where none of the exceptions are masked.  */
# define FE_NOMASK_ENV	((const fenv_t *) -2)
#endif

#if __GLIBC_USE (IEC_60559_BFP_EXT_C2X)
/* Type representing floating-point control modes.  */
typedef unsigned int femode_t;

/* Default floating-point control modes.  */
# define FE_DFL_MODE	((const femode_t *) -1L)
#endif