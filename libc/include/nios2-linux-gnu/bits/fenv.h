/* Copyright (C) 2012-2019 Free Software Foundation, Inc.
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
   <http://www.gnu.org/licenses/>.  */

#ifndef _FENV_H
# error "Never use <bits/fenv.h> directly; include <fenv.h> instead."
#endif

/* The Altera specified Nios II hardware FPU does not support exceptions,
   nor does the software floating-point support.  */
#define FE_ALL_EXCEPT	0

/* Nios II supports only round-to-nearest.  The software
   floating-point support also acts this way.  */
enum
  {
    __FE_UNDEFINED = 0,

    FE_TONEAREST =
#define FE_TONEAREST	1
      FE_TONEAREST,
  };

/* Type representing exception flags. */
typedef unsigned int fexcept_t;

/* Type representing floating-point environment.  */
typedef unsigned int fenv_t;

/* If the default argument is used we use this value.  */
#define FE_DFL_ENV	((const fenv_t *) -1)

#if __GLIBC_USE (IEC_60559_BFP_EXT)
/* Type representing floating-point control modes.  */
typedef unsigned int femode_t;

/* Default floating-point control modes.  */
# define FE_DFL_MODE	((const femode_t *) -1L)
#endif