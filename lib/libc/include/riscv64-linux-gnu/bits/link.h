/* Machine-specific declarations for dynamic linker interface.  RISC-V version.
   Copyright (C) 2005-2021 Free Software Foundation, Inc.
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

#ifndef	_LINK_H
# error "Never include <bits/link.h> directly; use <link.h> instead."
#endif

typedef struct La_riscv_regs
{
  unsigned long int lr_reg[8]; /* a0 - a7 */
  double lr_fpreg[8]; /* fa0 - fa7 */
  unsigned long int lr_ra;
  unsigned long int lr_sp;
} La_riscv_regs;

/* Return values for calls from PLT on RISC-V.  */
typedef struct La_riscv_retval
{
  unsigned long int lrv_a0;
  unsigned long int lrv_a1;
  double lrv_fa0;
  double lrv_fa1;
} La_riscv_retval;

__BEGIN_DECLS

extern ElfW(Addr) la_riscv_gnu_pltenter (ElfW(Sym) *__sym, unsigned int __ndx,
					 uintptr_t *__refcook,
					 uintptr_t *__defcook,
					 La_riscv_regs *__regs,
					 unsigned int *__flags,
					 const char *__symname,
					 long int *__framesizep);
extern unsigned int la_riscv_gnu_pltexit (ElfW(Sym) *__sym, unsigned int __ndx,
					  uintptr_t *__refcook,
					  uintptr_t *__defcook,
					  const La_riscv_regs *__inregs,
					  La_riscv_retval *__outregs,
					  const char *__symname);

__END_DECLS