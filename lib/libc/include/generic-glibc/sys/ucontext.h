/* Copyright (C) 1997-2024 Free Software Foundation, Inc.  This file is part of the GNU C Library.

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

#include <sgidefs.h>


/* Type for general register.  Even in o32 we assume 64-bit registers,
   like the kernel.  */
__extension__ typedef unsigned long long int greg_t;

/* Number of general registers.  */
#define __NGREG	32
#define __NFPREG	32
#ifdef __USE_MISC
# define NGREG	__NGREG
# define NFPREG	__NFPREG
#endif

/* Container for all general registers.  */
typedef greg_t gregset_t[__NGREG];

#ifdef __USE_MISC
# define __ctx(fld) fld
#else
# define __ctx(fld) __ ## fld
#endif

/* Container for all FPU registers.  */
typedef struct {
	union {
		double	__ctx(fp_dregs)[__NFPREG];
		struct {
			float		_fp_fregs;
			unsigned int	_fp_pad;
		} __ctx(fp_fregs)[__NFPREG];
	} __ctx(fp_r);
} fpregset_t;


/* Context to describe whole processor state.  */
#if _MIPS_SIM == _ABIO32
/* Earlier versions of glibc for mips had an entirely different
   definition of mcontext_t, that didn't even resemble the
   corresponding kernel data structure.  Fortunately, makecontext,
   [gs]etcontext et all were not implemented back then, so this can
   still be rectified.  */
typedef struct
  {
    unsigned int __ctx(regmask);
    unsigned int __ctx(status);
    greg_t __ctx(pc);
    gregset_t __ctx(gregs);
    fpregset_t __ctx(fpregs);
    unsigned int __ctx(fp_owned);
    unsigned int __ctx(fpc_csr);
    unsigned int __ctx(fpc_eir);
    unsigned int __ctx(used_math);
    unsigned int __ctx(dsp);
    greg_t __ctx(mdhi);
    greg_t __ctx(mdlo);
    unsigned long __ctx(hi1);
    unsigned long __ctx(lo1);
    unsigned long __ctx(hi2);
    unsigned long __ctx(lo2);
    unsigned long __ctx(hi3);
    unsigned long __ctx(lo3);
  } mcontext_t;
#else
typedef struct
  {
    gregset_t __ctx(gregs);
    fpregset_t __ctx(fpregs);
    greg_t __ctx(mdhi);
    greg_t __ctx(hi1);
    greg_t __ctx(hi2);
    greg_t __ctx(hi3);
    greg_t __ctx(mdlo);
    greg_t __ctx(lo1);
    greg_t __ctx(lo2);
    greg_t __ctx(lo3);
    greg_t __ctx(pc);
    unsigned int __ctx(fpc_csr);
    unsigned int __ctx(used_math);
    unsigned int __ctx(dsp);
    unsigned int __glibc_reserved1;
  } mcontext_t;
#endif

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