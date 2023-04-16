/* Types for registers for sys/procfs.h.  SPARC version.
   Copyright (C) 1996-2023 Free Software Foundation, Inc.
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

#ifndef _SYS_PROCFS_H
# error "Never include <bits/procfs.h> directly; use <sys/procfs.h> instead."
#endif

#include <signal.h>
#include <sys/ucontext.h>
#include <bits/wordsize.h>

#if __WORDSIZE == 64

#define ELF_NGREG		36

typedef struct
  {
    unsigned long	pr_regs[32];
    unsigned long	pr_fsr;
    unsigned long	pr_gsr;
    unsigned long	pr_fprs;
  } elf_fpregset_t;

#else /* sparc32 */

#define ELF_NGREG		38

typedef struct
  {
    union
      {
	unsigned long	pr_regs[32];
	double		pr_dregs[16];
      }			pr_fr;
    unsigned long	__glibc_reserved;
    unsigned long	pr_fsr;
    unsigned char	pr_qcnt;
    unsigned char	pr_q_entrysize;
    unsigned char	pr_en;
    unsigned int	pr_q[64];
  } elf_fpregset_t;

#endif /* sparc32 */

typedef unsigned long elf_greg_t;
typedef elf_greg_t elf_gregset_t[ELF_NGREG];