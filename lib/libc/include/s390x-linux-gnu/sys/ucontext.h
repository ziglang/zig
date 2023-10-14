/* Copyright (C) 2000-2023 Free Software Foundation, Inc.
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

#ifndef _SYS_UCONTEXT_H
#define _SYS_UCONTEXT_H	1

#include <features.h>

#include <bits/types/sigset_t.h>
#include <bits/types/stack_t.h>


#ifdef __USE_MISC
# define __ctx(fld) fld
#else
# define __ctx(fld) __ ## fld
#endif

/* Type for a program status word.  */
typedef struct
{
  unsigned long __ctx(mask);
  unsigned long __ctx(addr);
} __attribute__ ((__aligned__(8))) __psw_t;

/* Type for a general-purpose register.  */
typedef unsigned long greg_t;

/* And the whole bunch of them.  We should have used `struct s390_regs',
   but to avoid name space pollution and since the tradition says that
   the register set is an array, we make gregset_t a simple array
   that has the same size as s390_regs.  This is needed for the
   elf_prstatus structure.  */
#if __WORDSIZE == 64
# define __NGREG 27
#else
# define __NGREG 36
#endif
#ifdef __USE_MISC
# define NGREG __NGREG
#endif
/* Must match kernels psw_t alignment.  */
typedef greg_t gregset_t[__NGREG] __attribute__ ((__aligned__(8)));

typedef union
  {
    double  __ctx(d);
    float   __ctx(f);
  } fpreg_t;

/* Register set for the floating-point registers.  */
typedef struct
  {
    unsigned int __ctx(fpc);
    fpreg_t __ctx(fprs)[16];
  } fpregset_t;

/* Context to describe whole processor state.  */
typedef struct
  {
    __psw_t __ctx(psw);
    unsigned long __ctx(gregs)[16];
    unsigned int __ctx(aregs)[16];
    fpregset_t __ctx(fpregs);
  } mcontext_t;

/* Userlevel context.  */
typedef struct ucontext_t
  {
    unsigned long int __ctx(uc_flags);
    struct ucontext_t *uc_link;
    stack_t uc_stack;
    mcontext_t uc_mcontext;
    sigset_t uc_sigmask;
  } ucontext_t;

#undef __ctx


#endif /* sys/ucontext.h */