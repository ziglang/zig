/* Types for registers for sys/procfs.h.  RISC-V version.
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
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _SYS_PROCFS_H
# error "Never include <bits/procfs.h> directly; use <sys/procfs.h> instead."
#endif

#include <sys/ucontext.h>

/* ELF register definitions */
#define ELF_NGREG	NGREG
#define ELF_NFPREG	NFPREG

typedef unsigned long int elf_greg_t;
typedef unsigned long int elf_gregset_t[32];
typedef union __riscv_mc_fp_state elf_fpregset_t;