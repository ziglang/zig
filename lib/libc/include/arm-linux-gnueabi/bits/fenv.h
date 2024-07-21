/* Copyright (C) 2004-2024 Free Software Foundation, Inc.
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

/* Define bits representing exceptions in the FPU status word.  */
enum
  {
    FE_INVALID =
#define FE_INVALID	1
      FE_INVALID,
    FE_DIVBYZERO =
#define FE_DIVBYZERO	2
      FE_DIVBYZERO,
    FE_OVERFLOW =
#define FE_OVERFLOW	4
      FE_OVERFLOW,
    FE_UNDERFLOW =
#define FE_UNDERFLOW	8
      FE_UNDERFLOW,
    FE_INEXACT =
#define FE_INEXACT	16
      FE_INEXACT,
  };

/* Amount to shift by to convert an exception to a mask bit.  */
#define FE_EXCEPT_SHIFT	8

/* All supported exceptions.  */
#define FE_ALL_EXCEPT	\
	(FE_INVALID | FE_DIVBYZERO | FE_OVERFLOW | FE_UNDERFLOW | FE_INEXACT)

/* VFP supports all of the four defined rounding modes.  */
enum
  {
    FE_TONEAREST =
#define FE_TONEAREST	0
      FE_TONEAREST,
    FE_UPWARD =
#define FE_UPWARD	0x400000
      FE_UPWARD,
    FE_DOWNWARD =
#define FE_DOWNWARD	0x800000
      FE_DOWNWARD,
    FE_TOWARDZERO =
#define FE_TOWARDZERO	0xc00000
      FE_TOWARDZERO
  };

/* Type representing exception flags. */
typedef unsigned int fexcept_t;

/* Type representing floating-point environment.  */
typedef struct
  {
    unsigned int __cw;
  }
fenv_t;

/* If the default argument is used we use this value.  */
#define FE_DFL_ENV	((const fenv_t *) -1l)

#ifdef __USE_GNU
/* Floating-point environment where none of the exceptions are masked.  */
# define FE_NOMASK_ENV  ((const fenv_t *) -2)
#endif

#if __GLIBC_USE (IEC_60559_BFP_EXT_C2X)
/* Type representing floating-point control modes.  */
typedef unsigned int femode_t;

/* Default floating-point control modes.  */
# define FE_DFL_MODE	((const femode_t *) -1L)
#endif