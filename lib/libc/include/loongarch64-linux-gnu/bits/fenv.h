/* Floating point environment.
   Copyright (C) 2022-2024 Free Software Foundation, Inc.
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
#error "Never use <bits/fenv.h> directly; include <fenv.h> instead."
#endif

/* Define bits representing the exception.  We use the bit positions
   of the appropriate bits in the FPU control word.  */
enum
{
  FE_INEXACT =
#define FE_INEXACT 0x010000
    FE_INEXACT,
  FE_UNDERFLOW =
#define FE_UNDERFLOW 0x020000
    FE_UNDERFLOW,
  FE_OVERFLOW =
#define FE_OVERFLOW 0x040000
    FE_OVERFLOW,
  FE_DIVBYZERO =
#define FE_DIVBYZERO 0x080000
    FE_DIVBYZERO,
  FE_INVALID =
#define FE_INVALID 0x100000
    FE_INVALID,
};

#define FE_ALL_EXCEPT \
  (FE_INEXACT | FE_DIVBYZERO | FE_UNDERFLOW | FE_OVERFLOW | FE_INVALID)

/* The LoongArch FPU supports all of the four defined rounding modes.  We
   use again the bit positions in the FPU control word as the values
   for the appropriate macros.  */
enum
{
  FE_TONEAREST =
#define FE_TONEAREST 0x000
    FE_TONEAREST,
  FE_TOWARDZERO =
#define FE_TOWARDZERO 0x100
    FE_TOWARDZERO,
  FE_UPWARD =
#define FE_UPWARD 0x200
    FE_UPWARD,
  FE_DOWNWARD =
#define FE_DOWNWARD 0x300
    FE_DOWNWARD
};

/* Type representing exception flags.  */
typedef unsigned int fexcept_t;

/* Type representing floating-point environment.  This function corresponds
   to the layout of the block written by the `fstenv'.  */
typedef struct
{
  unsigned int __fp_control_register;
} fenv_t;

/* If the default argument is used we use this value.  */
#define FE_DFL_ENV ((const fenv_t *) -1)

#ifdef __USE_GNU
/* Floating-point environment where none of the exception is masked.  */
#define FE_NOMASK_ENV ((const fenv_t *) -257)
#endif

#if __GLIBC_USE (IEC_60559_BFP_EXT_C2X)
/* Type representing floating-point control modes.  */
typedef unsigned int femode_t;

/* Default floating-point control modes.  */
#define FE_DFL_MODE ((const femode_t *) -1L)
#endif