/* Types for registers for sys/procfs.h.  C-SKY version.
   Copyright (C) 2018-2021 Free Software Foundation, Inc.
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

#ifndef _SYS_PROCFS_H
# error "Never include <bits/procfs.h> directly; use <sys/procfs.h> instead."
#endif

#include <asm/ptrace.h>

/* Type for a general-purpose register.  */
typedef unsigned long elf_greg_t;
/* Type for a floating-point registers.  */
typedef unsigned long elf_fpreg_t;

/* In gdb/bfd elf32-csky.c, csky_elf_grok_prstatus() use fixed size of
   elf_prstatus.  It's 148 for abiv1 and 220 for abiv2, the size is enough
   for coredump and no need full sizeof (struct pt_regs).  */
#define ELF_NGREG ((sizeof (struct pt_regs) / sizeof (elf_greg_t)) - 2)
typedef elf_greg_t elf_gregset_t[ELF_NGREG];

#define ELF_NFPREG (sizeof (struct user_fp) / sizeof (elf_fpreg_t))
typedef elf_fpreg_t elf_fpregset_t[ELF_NFPREG];