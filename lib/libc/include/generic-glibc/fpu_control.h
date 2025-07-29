/* FPU control word bits.  Mips version.
   Copyright (C) 1996-2025 Free Software Foundation, Inc.
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

/* MIPS FPU floating point control register bits.
 *
 * 31-25  -> floating point conditions code bits 7-1.  These bits are only
 *           available in MIPS IV.
 * 24     -> flush denormalized results to zero instead of
 *           causing unimplemented operation exception.  This bit is only
 *           available for MIPS III and newer.
 * 23     -> Condition bit
 * 22-21  -> reserved for architecture implementers
 * 20     -> reserved (read as 0, write with 0)
 * 19     -> IEEE 754-2008 non-arithmetic ABS.fmt and NEG.fmt enable
 * 18     -> IEEE 754-2008 recommended NaN encoding enable
 * 17     -> cause bit for unimplemented operation
 * 16     -> cause bit for invalid exception
 * 15     -> cause bit for division by zero exception
 * 14     -> cause bit for overflow exception
 * 13     -> cause bit for underflow exception
 * 12     -> cause bit for inexact exception
 * 11     -> enable exception for invalid exception
 * 10     -> enable exception for division by zero exception
 *  9     -> enable exception for overflow exception
 *  8     -> enable exception for underflow exception
 *  7     -> enable exception for inexact exception
 *  6     -> flag invalid exception
 *  5     -> flag division by zero exception
 *  4     -> flag overflow exception
 *  3     -> flag underflow exception
 *  2     -> flag inexact exception
 *  1-0   -> rounding control
 *
 *
 * Rounding Control:
 * 00 - rounding to nearest (RN)
 * 01 - rounding toward zero (RZ)
 * 10 - rounding (up) toward plus infinity (RP)
 * 11 - rounding (down)toward minus infinity (RM)
 */

#include <features.h>

#ifdef __mips_soft_float

#define _FPU_RESERVED 0xffffffff
#define _FPU_DEFAULT  0x00000000
typedef unsigned int fpu_control_t;
#define _FPU_GETCW(cw) (cw) = 0
#define _FPU_SETCW(cw) (void) (cw)
extern fpu_control_t __fpu_control;

#else /* __mips_soft_float */

/* Masks for interrupts.  */
#define _FPU_MASK_V     0x0800  /* Invalid operation */
#define _FPU_MASK_Z     0x0400  /* Division by zero  */
#define _FPU_MASK_O     0x0200  /* Overflow          */
#define _FPU_MASK_U     0x0100  /* Underflow         */
#define _FPU_MASK_I     0x0080  /* Inexact operation */

/* Flush denormalized numbers to zero.  */
#define _FPU_FLUSH_TZ   0x1000000

/* IEEE 754-2008 compliance control.  */
#define _FPU_ABS2008    0x80000
#define _FPU_NAN2008    0x40000

/* Rounding control.  */
#define _FPU_RC_NEAREST 0x0     /* RECOMMENDED */
#define _FPU_RC_ZERO    0x1
#define _FPU_RC_UP      0x2
#define _FPU_RC_DOWN    0x3
/* Mask for rounding control.  */
#define _FPU_RC_MASK	0x3

#define _FPU_RESERVED 0xfe8c0000  /* Reserved bits in cw, incl ABS/NAN2008.  */


/* The fdlibm code requires strict IEEE double precision arithmetic,
   and no interrupts for exceptions, rounding to nearest.  */
#ifdef __mips_nan2008
# define _FPU_DEFAULT 0x000C0000
#else
# define _FPU_DEFAULT 0x00000000
#endif

/* IEEE: same as above, but exceptions.  */
#ifdef __mips_nan2008
# define _FPU_IEEE    0x000C0F80
#else
# define _FPU_IEEE    0x00000F80
#endif

/* Type of the control word.  */
typedef unsigned int fpu_control_t __attribute__ ((__mode__ (__SI__)));

/* Macros for accessing the hardware control word.  */
extern fpu_control_t __mips_fpu_getcw (void) __THROW;
extern void __mips_fpu_setcw (fpu_control_t) __THROW;
#ifdef __mips16
# define _FPU_GETCW(cw) do { (cw) = __mips_fpu_getcw (); } while (0)
# define _FPU_SETCW(cw) __mips_fpu_setcw (cw)
#else
# define _FPU_GETCW(cw) __asm__ volatile ("cfc1 %0,$31" : "=r" (cw))
# define _FPU_SETCW(cw) __asm__ volatile ("ctc1 %0,$31" : : "r" (cw))
#endif

/* Default control word set at startup.  */
extern fpu_control_t __fpu_control;

#endif /* __mips_soft_float */

#endif	/* fpu_control.h */