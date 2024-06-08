/* struct ucontext definition, RISC-V version.
   Copyright (C) 1997-2024 Free Software Foundation, Inc.
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
#define _SYS_UCONTEXT_H	1

#include <features.h>

#include <bits/types/sigset_t.h>
#include <bits/types/stack_t.h>

typedef unsigned long int __riscv_mc_gp_state[32];

#ifdef __USE_MISC
# define NGREG	32

# define REG_PC 0
# define REG_RA 1
# define REG_SP 2
# define REG_TP 4
# define REG_S0 8
# define REG_S1 9
# define REG_A0 10
# define REG_S2 18
# define REG_NARGS 8

typedef unsigned long int greg_t;

/* Container for all general registers.  */
typedef __riscv_mc_gp_state gregset_t;

/* Container for floating-point state.  */
typedef union __riscv_mc_fp_state fpregset_t;
#endif

struct __riscv_mc_f_ext_state
  {
    unsigned int __f[32];
    unsigned int __fcsr;
  };

struct __riscv_mc_d_ext_state
  {
    unsigned long long int __f[32];
    unsigned int __fcsr;
  };

struct __riscv_mc_q_ext_state
  {
    unsigned long long int __f[64] __attribute__ ((__aligned__ (16)));
    unsigned int __fcsr;
    /* Reserved for expansion of sigcontext structure.  Currently zeroed
       upon signal, and must be zero upon sigreturn.  */
    unsigned int __glibc_reserved[3];
  };

union __riscv_mc_fp_state
  {
    struct __riscv_mc_f_ext_state __f;
    struct __riscv_mc_d_ext_state __d;
    struct __riscv_mc_q_ext_state __q;
  };

typedef struct mcontext_t
  {
    __riscv_mc_gp_state __gregs;
    union  __riscv_mc_fp_state __fpregs;
  } mcontext_t;

/* Userlevel context.  */
typedef struct ucontext_t
  {
    unsigned long int  __uc_flags;
    struct ucontext_t *uc_link;
    stack_t            uc_stack;
    sigset_t           uc_sigmask;
    /* There's some padding here to allow sigset_t to be expanded in the
       future.  Though this is unlikely, other architectures put uc_sigmask
       at the end of this structure and explicitly state it can be
       expanded, so we didn't want to box ourselves in here.  */
    char               __glibc_reserved[1024 / 8 - sizeof (sigset_t)];
    /* We can't put uc_sigmask at the end of this structure because we need
       to be able to expand sigcontext in the future.  For example, the
       vector ISA extension will almost certainly add ISA state.  We want
       to ensure all user-visible ISA state can be saved and restored via a
       ucontext, so we're putting this at the end in order to allow for
       infinite extensibility.  Since we know this will be extended and we
       assume sigset_t won't be extended an extreme amount, we're
       prioritizing this.  */
    mcontext_t uc_mcontext;
  } ucontext_t;

#endif /* sys/ucontext.h */