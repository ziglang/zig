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

#ifndef _BITS_SIGCONTEXT_H
#define _BITS_SIGCONTEXT_H 1

#if !defined _SIGNAL_H && !defined _SYS_UCONTEXT_H
# error "Never use <bits/sigcontext.h> directly; include <signal.h> instead."
#endif

#include <bits/wordsize.h>

#if __WORDSIZE == 32

/* It is quite hard to choose what to put here, because
   Linux/sparc32 had at least 3 totally incompatible
   signal stack layouts.
   This one is for the "new" style signals, which are
   now delivered unless SA_SIGINFO is requested.  */

struct sigcontext
  {
    struct
      {
	unsigned int	psr;
	unsigned int	pc;
	unsigned int	npc;
	unsigned int	y;
	unsigned int	u_regs[16]; /* globals and ins */
      }			si_regs;
    int			si_mask;
  };

#else /* sparc64 */

typedef struct
  {
    unsigned int	si_float_regs [64];
    unsigned long	si_fsr;
    unsigned long	si_gsr;
    unsigned long	si_fprs;
  } __siginfo_fpu_t;

struct sigcontext
  {
    char		sigc_info[128];
    struct
      {
	unsigned long	u_regs[16]; /* globals and ins */
	unsigned long	tstate;
	unsigned long	tpc;
	unsigned long	tnpc;
	unsigned int	y;
	unsigned int	fprs;
      }			sigc_regs;
    __siginfo_fpu_t *	sigc_fpu_save;
    struct
      {
	void *		ss_sp;
	int		ss_flags;
	unsigned long	ss_size;
      }			sigc_stack;
    unsigned long	sigc_mask;
};

#endif /* sparc64 */

#endif /* bits/sigcontext.h */