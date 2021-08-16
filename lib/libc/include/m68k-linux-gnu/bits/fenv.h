/* Copyright (C) 1997-2021 Free Software Foundation, Inc.
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


#if defined __HAVE_68881__ || defined __HAVE_FPU__ || defined __mcffpu__

/* Define bits representing the exception.  We use the bit positions of
   the appropriate bits in the FPSR Accrued Exception Byte.  */
enum
  {
    FE_INEXACT =
# define FE_INEXACT	(1 << 3)
      FE_INEXACT,
    FE_DIVBYZERO =
# define FE_DIVBYZERO	(1 << 4)
      FE_DIVBYZERO,
    FE_UNDERFLOW =
# define FE_UNDERFLOW	(1 << 5)
      FE_UNDERFLOW,
    FE_OVERFLOW =
# define FE_OVERFLOW	(1 << 6)
      FE_OVERFLOW,
    FE_INVALID =
# define FE_INVALID	(1 << 7)
      FE_INVALID
  };

# define FE_ALL_EXCEPT \
	(FE_INEXACT | FE_DIVBYZERO | FE_UNDERFLOW | FE_OVERFLOW | FE_INVALID)

/* The m68k FPU supports all of the four defined rounding modes.  We use
   the bit positions in the FPCR Mode Control Byte as the values for the
   appropriate macros.  */
enum
  {
    FE_TONEAREST =
# define FE_TONEAREST	0
      FE_TONEAREST,
    FE_TOWARDZERO =
# define FE_TOWARDZERO	(1 << 4)
      FE_TOWARDZERO,
    FE_DOWNWARD =
# define FE_DOWNWARD	(2 << 4)
      FE_DOWNWARD,
    FE_UPWARD =
# define FE_UPWARD	(3 << 4)
      FE_UPWARD
  };

#else

/* In the soft-float case, only rounding to nearest is supported, with
   no exceptions.  */

# define FE_ALL_EXCEPT 0

enum
  {
    __FE_UNDEFINED = -1,

    FE_TONEAREST =
# define FE_TONEAREST	0
      FE_TONEAREST
  };

#endif


/* Type representing exception flags.  */
typedef unsigned int fexcept_t;


#if defined __HAVE_68881__ || defined __HAVE_FPU__ || defined __mcffpu__

/* Type representing floating-point environment.  This structure
   corresponds to the layout of the block written by `fmovem'.  */
typedef struct
  {
    unsigned int __control_register;
    unsigned int __status_register;
    unsigned int __instruction_address;
  }
fenv_t;

#else

/* Keep ABI compatibility with the type used in the generic
   bits/fenv.h, formerly used for no-FPU ColdFire.  */
typedef struct
  {
    fexcept_t __excepts;
  }
fenv_t;

#endif

/* If the default argument is used we use this value.  */
#define FE_DFL_ENV	((const fenv_t *) -1)

#if defined __USE_GNU && (defined __HAVE_68881__	\
			  || defined __HAVE_FPU__	\
			  || defined __mcffpu__)
/* Floating-point environment where none of the exceptions are masked.  */
# define FE_NOMASK_ENV	((const fenv_t *) -2)
#endif

#if __GLIBC_USE (IEC_60559_BFP_EXT_C2X)
/* Type representing floating-point control modes.  */
typedef unsigned int femode_t;

/* Default floating-point control modes.  */
# define FE_DFL_MODE	((const femode_t *) -1L)
#endif