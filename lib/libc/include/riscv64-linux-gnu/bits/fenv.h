/* Floating point environment, RISC-V version.
   Copyright (C) 1998-2023 Free Software Foundation, Inc.
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

enum
  {
    FE_INEXACT   =
#define FE_INEXACT	(0x01)
      FE_INEXACT,
    FE_UNDERFLOW =
#define FE_UNDERFLOW	(0x02)
      FE_UNDERFLOW,
    FE_OVERFLOW  =
#define FE_OVERFLOW	(0x04)
      FE_OVERFLOW,
    FE_DIVBYZERO =
#define FE_DIVBYZERO	(0x08)
      FE_DIVBYZERO,
    FE_INVALID   =
#define FE_INVALID	(0x10)
      FE_INVALID
  };

#define FE_ALL_EXCEPT \
	(FE_INEXACT | FE_DIVBYZERO | FE_UNDERFLOW | FE_OVERFLOW | FE_INVALID)

enum
  {
    FE_TONEAREST  =
#define FE_TONEAREST	(0x0)
      FE_TONEAREST,
    FE_TOWARDZERO =
#define FE_TOWARDZERO	(0x1)
      FE_TOWARDZERO,
    FE_DOWNWARD   =
#define FE_DOWNWARD	(0x2)
      FE_DOWNWARD,
    FE_UPWARD     =
#define FE_UPWARD	(0x3)
      FE_UPWARD
  };


typedef unsigned int fexcept_t;
typedef unsigned int fenv_t;

/* If the default argument is used we use this value.  */
#define FE_DFL_ENV	((__const fenv_t *) -1)

#if __GLIBC_USE (IEC_60559_BFP_EXT_C2X)
/* Type representing floating-point control modes.  */
typedef unsigned int femode_t;

/* Default floating-point control modes.  */
# define FE_DFL_MODE	((const femode_t *) -1L)
#endif