/* FPU control word bits.  ARC version.
   Copyright (C) 2020-2025 Free Software Foundation, Inc.
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

#ifndef _FPU_CONTROL_H
#define _FPU_CONTROL_H

/* ARC FPU control register bits.

  [  0] -> IVE: Enable invalid operation exception.
           if 0, soft exception: status register IV flag set.
           if 1, hardware exception trap (not supported in Linux yet).
  [  1] -> DZE: Enable division by zero exception.
           if 0, soft exception: status register IV flag set.
           if 1, hardware exception: (not supported in Linux yet).
  [9:8] -> RM: Rounding Mode:
           00 - Rounding toward zero.
           01 - Rounding to nearest (default).
           10 - Rounding (up) toward plus infinity.
           11 - Rounding (down)toward minus infinity.

   ARC FPU status register bits.

   [ 0] -> IV: flag invalid operation.
   [ 1] -> DZ: flag division by zero.
   [ 2] -> OV: flag Overflow operation.
   [ 3] -> UV: flag Underflow operation.
   [ 4] -> IX: flag Inexact operation.
   [31] -> FWE: Flag Write Enable.
           If 1, above flags writable explicitly (clearing),
           else IoW and only writable indirectly via bits [12:7].  */

#include <features.h>

#if !defined(__ARC_FPU_SP__) &&  !defined(__ARC_FPU_DP__)

# define _FPU_RESERVED 0xffffffff
# define _FPU_DEFAULT  0x00000000
typedef unsigned int fpu_control_t;
# define _FPU_GETCW(cw) (cw) = 0
# define _FPU_SETCW(cw) (void) (cw)
# define _FPU_GETS(cw) (cw) = 0
# define _FPU_SETS(cw) (void) (cw)
extern fpu_control_t __fpu_control;

#else

#define _FPU_RESERVED		0

/* The fdlibm code requires strict IEEE double precision arithmetic,
   and no interrupts for exceptions, rounding to nearest.
   So only RM set to b'01.  */
# define _FPU_DEFAULT		0x00000100

/* Actually default needs to have FWE bit as 1 but that is already
   ingrained into _FPU_SETS macro below.  */
#define  _FPU_FPSR_DEFAULT	0x00000000

#define __FPU_RND_SHIFT		8
#define __FPU_RND_MASK		0x3

/* Type of the control word.  */
typedef unsigned int fpu_control_t;

/* Macros for accessing the hardware control word.  */
#  define _FPU_GETCW(cw) __asm__ volatile ("lr %0, [0x300]" : "=r" (cw))
#  define _FPU_SETCW(cw) __asm__ volatile ("sr %0, [0x300]" : : "r" (cw))

/*  Macros for accessing the hardware status word.
    Writing to FPU_STATUS requires a "control" bit FWE to be able to set the
    exception flags directly (as opposed to side-effects of FP instructions).
    That is done in the macro here to keeps callers agnostic of this detail.
    And given FWE is write-only and RAZ, no need to "clear" it in _FPU_GETS
    macro.  */
#  define _FPU_GETS(cw)				\
    __asm__ volatile ("lr   %0, [0x301]	\r\n" 	\
                      : "=r" (cw))

#  define _FPU_SETS(cw)				\
    do {					\
      unsigned int __fwe = 0x80000000 | (cw);	\
      __asm__ volatile ("sr  %0, [0x301] \r\n" 	\
                        : : "r" (__fwe));	\
    } while (0)

/* Default control word set at startup.  */
extern fpu_control_t __fpu_control;

#endif

#endif /* fpu_control.h */