/* Copyright (C) 2000-2024 Free Software Foundation, Inc.
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

/* Define bits representing the exception.  We use the bit positions
   of the appropriate bits in the FPU control word.  */
enum
  {
    FE_INVALID =
#define FE_INVALID	0x80
      FE_INVALID,
    FE_DIVBYZERO =
#define FE_DIVBYZERO	0x40
      FE_DIVBYZERO,
    FE_OVERFLOW =
#define FE_OVERFLOW	0x20
      FE_OVERFLOW,
    FE_UNDERFLOW =
#define FE_UNDERFLOW	0x10
      FE_UNDERFLOW,
    FE_INEXACT =
#define FE_INEXACT	0x08
      FE_INEXACT
  };
/* We dont use the y bit of the DXC in the floating point control register
   as glibc has no FE encoding for fe inexact incremented
   or fe inexact truncated.
   We currently  use the flag bits in the fpc
   as these are sticky for feholdenv & feupdatenv as it is defined
   in the HP Manpages.  */


#define FE_ALL_EXCEPT \
	(FE_INEXACT | FE_DIVBYZERO | FE_UNDERFLOW | FE_OVERFLOW | FE_INVALID)

enum
  {
    FE_TONEAREST =
#define FE_TONEAREST	0
      FE_TONEAREST,
    FE_DOWNWARD =
#define FE_DOWNWARD	0x3
      FE_DOWNWARD,
    FE_UPWARD =
#define FE_UPWARD	0x2
      FE_UPWARD,
    FE_TOWARDZERO =
#define FE_TOWARDZERO	0x1
      FE_TOWARDZERO
  };


/* Type representing exception flags.  */
typedef unsigned int fexcept_t; /* size of fpc */


/* Type representing floating-point environment.  This function corresponds
   to the layout of the block used by fegetenv and fesetenv.  */
typedef struct
{
  fexcept_t __fpc;
  void *__unused;
  /* The field __unused (formerly __ieee_instruction_pointer) is a relict from
     commit "Remove PTRACE_PEEKUSER" (87b9b50f0d4b92248905e95a06a13c513dc45e59)
     and isn't used anymore.  */
} fenv_t;

/* If the default argument is used we use this value.  */
#define FE_DFL_ENV	((const fenv_t *) -1)

#ifdef __USE_GNU
/* Floating-point environment where none of the exceptions are masked.  */
# define FE_NOMASK_ENV	((const fenv_t *) -2)
#endif

#if __GLIBC_USE (IEC_60559_BFP_EXT_C2X)
/* Type representing floating-point control modes.  */
typedef unsigned int femode_t;

/* Default floating-point control modes.  */
# define FE_DFL_MODE	((const femode_t *) -1L)
#endif