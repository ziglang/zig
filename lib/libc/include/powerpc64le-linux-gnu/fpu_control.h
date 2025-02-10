/* FPU control word definitions.  PowerPC version.
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
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _FPU_CONTROL_H
#define _FPU_CONTROL_H

#if defined __SPE__ || (defined __NO_FPRS__ && !defined _SOFT_FLOAT)
# error "SPE/e500 is no longer supported"
#endif

#ifdef _SOFT_FLOAT

# define _FPU_RESERVED 0xffffffff
# define _FPU_DEFAULT  0x00000000 /* Default value.  */
typedef unsigned int fpu_control_t;
# define _FPU_GETCW(cw) (cw) = 0
# define _FPU_SETCW(cw) (void) (cw)
extern fpu_control_t __fpu_control;

#else /* PowerPC 6xx floating-point.  */

/* rounding control */
# define _FPU_RC_NEAREST 0x00   /* RECOMMENDED */
# define _FPU_RC_DOWN    0x03
# define _FPU_RC_UP      0x02
# define _FPU_RC_ZERO    0x01

# define _FPU_MASK_RC (_FPU_RC_NEAREST|_FPU_RC_DOWN|_FPU_RC_UP|_FPU_RC_ZERO)

# define _FPU_MASK_NI  0x04 /* non-ieee mode */

/* masking of interrupts */
# define _FPU_MASK_ZM  0x10 /* zero divide */
# define _FPU_MASK_OM  0x40 /* overflow */
# define _FPU_MASK_UM  0x20 /* underflow */
# define _FPU_MASK_XM  0x08 /* inexact */
# define _FPU_MASK_IM  0x80 /* invalid operation */

# define _FPU_RESERVED 0xffffff00 /* These bits are reserved are not changed. */

/* The fdlibm code requires no interrupts for exceptions.  */
# define _FPU_DEFAULT  0x00000000 /* Default value.  */

/* IEEE:  same as above, but (some) exceptions;
   we leave the 'inexact' exception off.
 */
# define _FPU_IEEE     0x000000f0

/* Type of the control word.  */
typedef unsigned int fpu_control_t;

/* Macros for accessing the hardware control word.  */
# define _FPU_GETCW(cw)						\
  ({union { double __d; unsigned long long __ll; } __u;		\
    __asm__ __volatile__("mffs %0" : "=f" (__u.__d));		\
    (cw) = (fpu_control_t) __u.__ll;				\
    (fpu_control_t) __u.__ll;					\
  })

# define _FPU_GET_RC_ISA300()						\
  ({union { double __d; unsigned long long __ll; } __u;			\
    __asm__ __volatile__(						\
      ".machine push; .machine \"power9\"; mffsl %0; .machine pop" 	\
      : "=f" (__u.__d));						\
    (fpu_control_t) (__u.__ll & _FPU_MASK_RC);				\
  })

# ifdef _ARCH_PWR9
#  define _FPU_GET_RC() _FPU_GET_RC_ISA300()
# elif defined __BUILTIN_CPU_SUPPORTS__
#  define _FPU_GET_RC()							\
  ({fpu_control_t __rc;							\
    __rc = __glibc_likely (__builtin_cpu_supports ("arch_3_00"))	\
      ? _FPU_GET_RC_ISA300 ()						\
      : _FPU_GETCW (__rc) & _FPU_MASK_RC;				\
    __rc;								\
  })
# else
#  define _FPU_GET_RC()						\
  ({fpu_control_t __rc = _FPU_GETCW (__rc) & _FPU_MASK_RC;	\
    __rc;							\
  })
# endif

# define _FPU_SETCW(cw)						\
  { union { double __d; unsigned long long __ll; } __u;		\
    register double __fr;					\
    __u.__ll = 0xfff80000LL << 32; /* This is a QNaN.  */	\
    __u.__ll |= (cw) & 0xffffffffLL;				\
    __fr = __u.__d;						\
    __asm__ __volatile__("mtfsf 255,%0" : : "f" (__fr));	\
  }

/* Default control word set at startup.  */
extern fpu_control_t __fpu_control;

#endif /* PowerPC 6xx floating-point.  */

#endif /* _FPU_CONTROL_H */