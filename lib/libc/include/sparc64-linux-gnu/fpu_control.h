/* FPU control word bits.  SPARC version.
   Copyright (C) 1997-2023 Free Software Foundation, Inc.
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
#define _FPU_CONTROL_H	1


#include <features.h>
#include <bits/wordsize.h>

/* masking of interrupts */
#define _FPU_MASK_IM  0x08000000
#define _FPU_MASK_OM  0x04000000
#define _FPU_MASK_UM  0x02000000
#define _FPU_MASK_ZM  0x01000000
#define _FPU_MASK_PM  0x00800000

/* precision control */
#define _FPU_EXTENDED 0x00000000     /* RECOMMENDED */
#define _FPU_DOUBLE   0x20000000
#define _FPU_80BIT    0x30000000
#define _FPU_SINGLE   0x10000000     /* DO NOT USE */

/* rounding control / Sparc */
#define _FPU_RC_DOWN    0xc0000000
#define _FPU_RC_UP      0x80000000
#define _FPU_RC_ZERO    0x40000000
#define _FPU_RC_NEAREST 0x0        /* RECOMMENDED */

#define _FPU_RESERVED   0x30300000  /* Reserved bits in cw */


/* Now two recommended cw */

/* Linux and IEEE default:
     - extended precision
     - rounding to nearest
     - no exceptions  */
#define _FPU_DEFAULT  0x0
#define _FPU_IEEE     0x0

/* Type of the control word.  */
typedef unsigned long int fpu_control_t;

#if __WORDSIZE == 64
# define _FPU_GETCW(cw) __asm__ __volatile__ ("stx %%fsr,%0" : "=m" (*&cw))
# define _FPU_SETCW(cw) __asm__ __volatile__ ("ldx %0,%%fsr" : : "m" (*&cw))
#else
# define _FPU_GETCW(cw) __asm__ __volatile__ ("st %%fsr,%0" : "=m" (*&cw))
# define _FPU_SETCW(cw) __asm__ __volatile__ ("ld %0,%%fsr" : : "m" (*&cw))
#endif

/* Default control word set at startup.  */
extern fpu_control_t __fpu_control;

#endif	/* fpu_control.h */