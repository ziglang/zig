/* struct ucontext definition, C-SKY version.
   Copyright (C) 2018-2023 Free Software Foundation, Inc.
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

#ifndef _SYS_UCONTEXT_H
#define _SYS_UCONTEXT_H	1

#include <features.h>

#include <bits/types/sigset_t.h>
#include <bits/types/stack_t.h>

typedef struct
  {
    unsigned long __tls;
    unsigned long __lr;
    unsigned long __pc;
    unsigned long __sr;
    unsigned long __usp;

    /*
     * a0, a1, a2, a3:
     * abiv1: r2, r3, r4, r5
     * abiv2: r0, r1, r2, r3
     */

    unsigned long __orig_a0;
    unsigned long __a0;
    unsigned long __a1;
    unsigned long __a2;
    unsigned long __a3;

    /*
     * ABIV2: r4 ~ r13
     */
    unsigned long __regs[10];

    /* r16 ~ r30 */
    unsigned long __exregs[15];

    unsigned long __rhi;
    unsigned long __rlo;
    unsigned long __glibc_reserved;
  } gregset_t;

typedef struct
  {
    unsigned long __vr[64];
    unsigned long __fcr;
    unsigned long __fesr;
    unsigned long __fid;
    unsigned long __glibc_reserved;
  } fpregset_t;

/* Context to describe whole processor state.  */
typedef struct
  {
    gregset_t __gregs;
    fpregset_t __fpregs;
  } mcontext_t;

/* Userlevel context.  */
typedef struct ucontext_t
  {
    unsigned long int __uc_flags;
    struct ucontext_t *uc_link;
    stack_t uc_stack;
    mcontext_t uc_mcontext;
    sigset_t uc_sigmask;
  } ucontext_t;

#undef __ctx


#endif /* sys/ucontext.h */