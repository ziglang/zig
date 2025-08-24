/* FPU control word definitions.  ARM VFP version.
   Copyright (C) 2004-2025 Free Software Foundation, Inc.
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

#if !(defined(_LIBC) && !defined(_LIBC_TEST)) && defined(__SOFTFP__)

#define _FPU_RESERVED 0xffffffff
#define _FPU_DEFAULT  0x00000000
typedef unsigned int fpu_control_t;
#define _FPU_GETCW(cw) (cw) = 0
#define _FPU_SETCW(cw) (void) (cw)
extern fpu_control_t __fpu_control;

#else

/* masking of interrupts */
#define _FPU_MASK_IM	0x00000100	/* invalid operation */
#define _FPU_MASK_ZM	0x00000200	/* divide by zero */
#define _FPU_MASK_OM	0x00000400	/* overflow */
#define _FPU_MASK_UM	0x00000800	/* underflow */
#define _FPU_MASK_PM	0x00001000	/* inexact */

#define _FPU_MASK_NZCV	0xf0000000	/* NZCV flags */
#define _FPU_MASK_RM	0x00c00000	/* rounding mode */
#define _FPU_MASK_EXCEPT 0x00001f1f	/* all exception flags */

/* Some bits in the FPSCR are not yet defined.  They must be preserved when
   modifying the contents.  */
#define _FPU_RESERVED	0x00086060
#define _FPU_DEFAULT    0x00000000

/* Default + exceptions enabled.  */
#define _FPU_IEEE	(_FPU_DEFAULT | 0x00001f00)

/* Type of the control word.  */
typedef unsigned int fpu_control_t;

/* Macros for accessing the hardware control word.  */
#ifdef __SOFTFP__
/* This is fmrx %0, fpscr.  */
# define _FPU_GETCW(cw) \
  __asm__ __volatile__ ("mrc p10, 7, %0, cr1, cr0, 0" : "=r" (cw))
/* This is fmxr fpscr, %0.  */
# define _FPU_SETCW(cw) \
  __asm__ __volatile__ ("mcr p10, 7, %0, cr1, cr0, 0" : : "r" (cw))
#else
# define _FPU_GETCW(cw) \
  __asm__ __volatile__ ("vmrs %0, fpscr" : "=r" (cw))
# define _FPU_SETCW(cw) \
  __asm__ __volatile__ ("vmsr fpscr, %0" : : "r" (cw))
#endif

/* Default control word set at startup.  */
extern fpu_control_t __fpu_control;

#endif /* __SOFTFP__ */

#endif /* _FPU_CONTROL_H */