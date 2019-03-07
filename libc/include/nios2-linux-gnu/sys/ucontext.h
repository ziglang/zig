/* ucontext_t definition, Nios II version.
   Copyright (C) 2015-2019 Free Software Foundation, Inc.
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
   <http://www.gnu.org/licenses/>.  */

/* System V/Nios II ABI compliant context switching support.  */

#ifndef _SYS_UCONTEXT_H
#define _SYS_UCONTEXT_H	1

#include <features.h>

#include <bits/types/sigset_t.h>
#include <bits/types/stack_t.h>


/* These definitions must be in sync with the kernel.  */

#ifdef __USE_MISC
# define MCONTEXT_VERSION 2
#endif

#ifdef __USE_MISC
# define __ctx(fld) fld
#else
# define __ctx(fld) __ ## fld
#endif

/* Context to describe whole processor state.  */
typedef struct
  {
    int __ctx(version);
    unsigned long __ctx(regs)[32];
  } mcontext_t;

/* Userlevel context.  */
typedef struct ucontext_t
  {
    unsigned long __ctx(uc_flags);
    struct ucontext_t *uc_link;
    stack_t uc_stack;
    mcontext_t uc_mcontext;
    sigset_t uc_sigmask;
  } ucontext_t;

#undef __ctx

#endif /* sys/ucontext.h */