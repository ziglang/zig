/* Types for registers for sys/procfs.h.
   Copyright (C) 2022-2025 Free Software Foundation, Inc.

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

/* Type for a general-purpose register.  */
typedef __uint64_t elf_greg_t;

/* And the whole bunch of them.  We could have used `struct
   pt_regs' directly in the typedef, but tradition says that
   the register set is an array, which does have some peculiar
   semantics, so leave it that way.  */
#define ELF_NGREG (sizeof (struct user_regs_struct) / sizeof (elf_greg_t))
typedef elf_greg_t elf_gregset_t[ELF_NGREG];

#define ELF_NFPREG 34 /* 32 FPRs + 8-byte byte-vec for fcc + 4-byte FCR */
typedef union
{
  double d;
  float f;
} elf_fpreg_t;
typedef elf_fpreg_t elf_fpregset_t[ELF_NFPREG];

typedef union
{
  double d[2];
  float f[4];
} __attribute__ ((__aligned__ (16))) elf_lsxregset_t[32];

typedef union
{
  double d[4];
  float f[8];
} __attribute__ ((__aligned__ (32))) elf_lasxregset_t[32];