/* FPU control word bits.  RISC-V version.
   Copyright (C) 1996-2024 Free Software Foundation, Inc.
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

#include <features.h>

#ifndef __riscv_flen

# define _FPU_RESERVED 0xffffffff
# define _FPU_DEFAULT  0x00000000
typedef unsigned int fpu_control_t;
# define _FPU_GETCW(cw) (cw) = 0
# define _FPU_SETCW(cw) do { } while (0)
extern fpu_control_t __fpu_control;

#else /* __riscv_flen */

# define _FPU_RESERVED 0
# define _FPU_DEFAULT  0
# define _FPU_IEEE     _FPU_DEFAULT

/* Type of the control word.  */
typedef unsigned int fpu_control_t __attribute__ ((__mode__ (__SI__)));

/* Macros for accessing the hardware control word.  */
# define _FPU_GETCW(cw) __asm__ volatile ("frsr %0" : "=r" (cw))
# define _FPU_SETCW(cw) __asm__ volatile ("fssr %z0" : : "rJ" (cw))

/* Default control word set at startup.  */
extern fpu_control_t __fpu_control;

# define _FCLASS(x) (__extension__ ({ int __res; \
  if (sizeof (x) * 8 > __riscv_flen) __builtin_trap (); \
  if (sizeof (x) == 4) asm ("fclass.s %0, %1" : "=r" (__res) : "f" (x)); \
  else if (sizeof (x) == 8) asm ("fclass.d %0, %1" : "=r" (__res) : "f" (x)); \
  else __builtin_trap (); \
  __res; }))

# define _FCLASS_MINF     (1 << 0)
# define _FCLASS_MNORM    (1 << 1)
# define _FCLASS_MSUBNORM (1 << 2)
# define _FCLASS_MZERO    (1 << 3)
# define _FCLASS_PZERO    (1 << 4)
# define _FCLASS_PSUBNORM (1 << 5)
# define _FCLASS_PNORM    (1 << 6)
# define _FCLASS_PINF     (1 << 7)
# define _FCLASS_SNAN     (1 << 8)
# define _FCLASS_QNAN     (1 << 9)
# define _FCLASS_ZERO     (_FCLASS_MZERO | _FCLASS_PZERO)
# define _FCLASS_SUBNORM  (_FCLASS_MSUBNORM | _FCLASS_PSUBNORM)
# define _FCLASS_NORM     (_FCLASS_MNORM | _FCLASS_PNORM)
# define _FCLASS_INF      (_FCLASS_MINF | _FCLASS_PINF)
# define _FCLASS_NAN      (_FCLASS_SNAN | _FCLASS_QNAN)

#endif /* __riscv_flen */

#endif	/* fpu_control.h */