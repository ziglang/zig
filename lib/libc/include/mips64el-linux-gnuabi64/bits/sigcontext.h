/* Copyright (C) 1996-2024 Free Software Foundation, Inc.  This file is part of the GNU C Library.

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

#ifndef _BITS_SIGCONTEXT_H
#define _BITS_SIGCONTEXT_H 1

#if !defined _SIGNAL_H && !defined _SYS_UCONTEXT_H
# error "Never use <bits/sigcontext.h> directly; include <signal.h> instead."
#endif

#include <sgidefs.h>

#if _MIPS_SIM == _ABIO32

/* Certain unused fields were replaced with new ones in 2.6.12-rc4.
   The changes were as follows:

   sc_cause -> sc_hi1
   sc_badvaddr -> sc_lo1
   sc_sigset[0] -> sc_hi2
   sc_sigset[1] -> sc_lo2
   sc_sigset[2] -> sc_hi3
   sc_sigset[3] -> sc_lo3

   sc_regmask, sc_ownedfp and sc_fpc_eir are not used.  */
struct sigcontext {
  unsigned int sc_regmask;
  unsigned int sc_status;
  __extension__ unsigned long long sc_pc;
  __extension__ unsigned long long sc_regs[32];
  __extension__ unsigned long long sc_fpregs[32];
  unsigned int sc_ownedfp;
  unsigned int sc_fpc_csr;
  unsigned int sc_fpc_eir;
  unsigned int sc_used_math;
  unsigned int sc_dsp;
  __extension__ unsigned long long sc_mdhi;
  __extension__ unsigned long long sc_mdlo;
  unsigned long sc_hi1;
  unsigned long sc_lo1;
  unsigned long sc_hi2;
  unsigned long sc_lo2;
  unsigned long sc_hi3;
  unsigned long sc_lo3;
};

#else

/* This structure changed in 2.6.12-rc4 when DSP support was added.  */
struct sigcontext {
  __extension__ unsigned long long sc_regs[32];
  __extension__ unsigned long long sc_fpregs[32];
  __extension__ unsigned long long sc_mdhi;
  __extension__ unsigned long long sc_hi1;
  __extension__ unsigned long long sc_hi2;
  __extension__ unsigned long long sc_hi3;
  __extension__ unsigned long long sc_mdlo;
  __extension__ unsigned long long sc_lo1;
  __extension__ unsigned long long sc_lo2;
  __extension__ unsigned long long sc_lo3;
  __extension__ unsigned long long sc_pc;
  unsigned int sc_fpc_csr;
  unsigned int sc_used_math;
  unsigned int sc_dsp;
  unsigned int sc_reserved;
};

#endif /* _MIPS_SIM != _ABIO32 */
#endif