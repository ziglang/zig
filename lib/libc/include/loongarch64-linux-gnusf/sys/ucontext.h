/* struct ucontext definition.
   Copyright (C) 2022-2024 Free Software Foundation, Inc.

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

/* Don't rely on this, the interface is currently messed up and may need to
   be broken to be fixed.  */
#ifndef _SYS_UCONTEXT_H
#define _SYS_UCONTEXT_H 1

#include <features.h>

#include <bits/types/sigset_t.h>
#include <bits/types/stack_t.h>

#ifdef __USE_MISC
#define LARCH_NGREG 32

#define LARCH_REG_RA 1
#define LARCH_REG_SP 3
#define LARCH_REG_S0 23
#define LARCH_REG_S1 24
#define LARCH_REG_A0 4
#define LARCH_REG_S2 25
#define LARCH_REG_NARGS 8

typedef unsigned long int greg_t;
/* Container for all general registers.  */
typedef greg_t gregset_t[32];
#endif

typedef struct mcontext_t
{
  unsigned long long __pc;
  unsigned long long __gregs[32];
  unsigned int __flags;
  unsigned long long __extcontext[0] __attribute__((__aligned__(16)));
} mcontext_t;

/* Userlevel context.  */
typedef struct ucontext_t
{
  unsigned long int __uc_flags;
  struct ucontext_t *uc_link;
  stack_t uc_stack;
  sigset_t uc_sigmask;
  mcontext_t uc_mcontext;
} ucontext_t;

#endif /* sys/ucontext.h */