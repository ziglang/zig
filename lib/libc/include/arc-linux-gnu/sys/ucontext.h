/* struct ucontext definition, ARC version.
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
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

/* System V/ARC ABI compliant context switching support.  */

#ifndef _SYS_UCONTEXT_H
#define _SYS_UCONTEXT_H	1

#include <features.h>

#include <bits/types/sigset_t.h>
#include <bits/types/stack_t.h>

typedef struct
{
  unsigned long int __pad;
  unsigned long int __bta;
  unsigned long int __lp_start, __lp_end, __lp_count;
  unsigned long int __status32, __ret, __blink;
  unsigned long int __fp, __gp;
  unsigned long int __r12, __r11, __r10, __r9, __r8, __r7;
  unsigned long int __r6, __r5, __r4, __r3, __r2, __r1, __r0;
  unsigned long int __sp;
  unsigned long int __r26;
  unsigned long int __r25, __r24, __r23, __r22, __r21, __r20;
  unsigned long int __r19, __r18, __r17, __r16, __r15, __r14, __r13;
  unsigned long int __efa;
  unsigned long int __stop_pc;
  unsigned long int __r30, __r58, __r59;
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

#endif