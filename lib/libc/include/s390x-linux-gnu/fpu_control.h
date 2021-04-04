/* FPU control word definitions.  Stub version.
   Copyright (C) 2000-2021 Free Software Foundation, Inc.
   Contributed by Denis Joseph Barrow (djbarrow@de.ibm.com) and
   Martin Schwidefsky (schwidefsky@de.ibm.com).
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

#ifndef _FPU_CONTROL_H
#define _FPU_CONTROL_H

#include <features.h>

/* These bits are reserved are not changed.  */
#define _FPU_RESERVED 0x0707FFFC

/* The fdlibm code requires no interrupts for exceptions.  Don't
   change the rounding mode, it would break long double I/O!  */
#define _FPU_DEFAULT  0x00000000 /* Default value.  */

/* Type of the control word.  */
typedef unsigned int fpu_control_t;

/* Macros for accessing the hardware control word.  */
#define _FPU_GETCW(cw)  __asm__ __volatile__ ("efpc %0,0" : "=d" (cw))
#define _FPU_SETCW(cw)  __asm__ __volatile__ ("sfpc  %0,0" : : "d" (cw))

/* Default control word set at startup.  */
extern fpu_control_t __fpu_control;

#endif /* _FPU_CONTROL_H */