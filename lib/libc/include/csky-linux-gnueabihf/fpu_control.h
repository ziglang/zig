/* FPU control word bits.  C-SKY version.
   Copyright (C) 2018-2024 Free Software Foundation, Inc.
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

/* C-SKY FPU floating point control register bits.

   31-28  -> Reserved (read as 0, write with 0).
   27     -> 0: Flush denormalized results to zero.
             1: Flush denormalized results to signed minimal normal number.
   26     -> Reserved (read as 0, write with 0).
   25-24  -> Rounding control.
   23-6   -> Reserved (read as 0, write with 0).
    5     -> Enable exception for input denormalized exception.
    4     -> Enable exception for inexact exception.
    3     -> Enable exception for underflow exception.
    2     -> Enable exception for overflow exception.
    1     -> Enable exception for division by zero exception.
    0     -> Enable exception for invalid operation exception.

   Rounding Control:
   00 - Rounding to nearest (RN).
   01 - Rounding toward zero (RZ).
   10 - Rounding (up) toward plus infinity (RP).
   11 - Rounding (down)toward minus infinity (RM).

   C-SKY FPU floating point exception status register bits.

   15     -> Accumulate bit for any exception.
   14     -> Reserved (read as 0, write with 0).
   13     -> Cause bit for input denormalized exception.
   12     -> Cause bit for inexact exception.
   11     -> Cause bit for underflow exception.
   10     -> Cause bit for overflow exception.
    9     -> Cause bit for division by zero exception.
    8     -> Cause bit for invalid operation exception.
    7     -> Flag bit for any exception.
    6     -> Reserved (read as 0, write with 0).
    5     -> Flag exception for input denormalized exception.
    4     -> Flag exception for inexact exception.
    3     -> Flag exception for underflow exception.
    2     -> Flag exception for overflow exception.
    1     -> Flag exception for division by zero exception.
    0     -> Flag exception for invalid operation exception.  */

#include <features.h>

#ifdef __csky_soft_float__

# define _FPU_RESERVED 0xffffffff
# define _FPU_DEFAULT  0x00000000
typedef unsigned int fpu_control_t;
# define _FPU_GETCW(cw) (cw) = 0
# define _FPU_SETCW(cw) (void) (cw)
# define _FPU_GETFPSR(cw) (cw) = 0
# define _FPU_SETFPSR(cw) (void) (cw)
extern fpu_control_t __fpu_control;

#else /* __csky_soft_float__ */

/* Masking of interrupts.  */
# define _FPU_MASK_IDE     (1 << 5)  /* Input denormalized exception.  */
# define _FPU_MASK_IXE     (1 << 4)  /* Inexact exception.  */
# define _FPU_MASK_UFE     (1 << 3)  /* Underflow exception.  */
# define _FPU_MASK_OFE     (1 << 2)  /* Overflow exception.  */
# define _FPU_MASK_DZE     (1 << 1)  /* Division by zero exception.  */
# define _FPU_MASK_IOE     (1 << 0)  /* Invalid operation exception.  */

# define _FPU_MASK_FEA     (1 << 15) /* Case for any exception.  */
# define _FPU_MASK_FEC     (1 << 7)  /* Flag for any exception.  */

/* Flush denormalized numbers to zero.  */
# define _FPU_FLUSH_TZ   0x8000000

/* Rounding control.  */
# define _FPU_RC_NEAREST (0x0 << 24)     /* RECOMMENDED.  */
# define _FPU_RC_ZERO    (0x1 << 24)
# define _FPU_RC_UP      (0x2 << 24)
# define _FPU_RC_DOWN    (0x3 << 24)

# define _FPU_RESERVED      0xf460ffc0  /* Reserved bits in cw.  */
# define _FPU_FPSR_RESERVED 0xffff4040

/* The fdlibm code requires strict IEEE double precision arithmetic,
   and no interrupts for exceptions, rounding to nearest.  */

# define _FPU_DEFAULT        0x00000000
# define _FPU_FPSR_DEFAULT   0x00000000

/* IEEE: same as above, but exceptions.  */
# define _FPU_FPCR_IEEE     0x0000001F
# define _FPU_FPSR_IEEE     0x00000000

/* Type of the control word.  */
typedef unsigned int fpu_control_t;

/* Macros for accessing the hardware control word.  */
# if (__CSKY__ == 2)
#  define _FPU_GETCW(cw) __asm__ volatile ("mfcr %0, cr<1, 2>" : "=a" (cw))
#  define _FPU_SETCW(cw) __asm__ volatile ("mtcr %0, cr<1, 2>" : : "a" (cw))
#  define _FPU_GETFPSR(cw) __asm__ volatile ("mfcr %0, cr<2, 2>" : "=a" (cw))
#  define _FPU_SETFPSR(cw) __asm__ volatile ("mtcr %0, cr<2, 2>" : : "a" (cw))
# else
#  define _FPU_GETCW(cw) __asm__ volatile ("1: cprcr  %0, cpcr2 \n"          \
                                         "   btsti  %0, 31    \n"           \
                                         "   bt     1b        \n"           \
                                         "   cprcr  %0, cpcr1\n" : "=b" (cw))

#  define _FPU_SETCW(cw) __asm__ volatile ("1: cprcr  r7, cpcr2 \n"          \
                                         "   btsti  r7, 31    \n"           \
                                         "   bt     1b        \n"           \
                                         "   cpwcr  %0, cpcr1 \n"           \
                                         : : "b" (cw) : "r7")

#  define _FPU_GETFPSR(cw) __asm__ volatile ("1: cprcr  %0, cpcr2 \n"        \
                                           "   btsti  %0, 31    \n"         \
                                           "   bt     1b        \n"         \
                                           "   cprcr  %0, cpcr4\n" : "=b" (cw))

#  define _FPU_SETFPSR(cw) __asm__ volatile ("1: cprcr  r7, cpcr2 \n"        \
                                           "   btsti  r7, 31    \n"         \
                                           "   bt     1b        \n"         \
                                           "   cpwcr %0, cpcr4  \n"         \
                                           : : "b" (cw) : "r7")
# endif /* __CSKY__ != 2 */

/* Default control word set at startup.  */
extern fpu_control_t __fpu_control;

#endif /* !__csky_soft_float__ */

#endif /* fpu_control.h */