/* Copyright (C) 2005-2025 Free Software Foundation, Inc.
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


/* Registers for entry into PLT on ARM.  */
typedef struct La_arm_regs
{
  uint32_t lr_reg[4];
  uint32_t lr_sp;
  uint32_t lr_lr;
  /* Coprocessor registers used for argument passing.  The data
     stored here depends on the coprocessors available in the
     system which are used for function calls in the current ABI.
     VFP uses eight 64-bit registers, and iWMMXt uses ten.  */
  uint32_t lr_coproc[42];
} La_arm_regs;

/* Return values for calls from PLT on ARM.  */
typedef struct La_arm_retval
{
  /* Up to four integer registers can be used for a return value in
     some ABIs (APCS complex long double).  */
  uint32_t lrv_reg[4];

  /* Any coprocessor registers which might be used to return values
     in the current ABI.  */
  uint32_t lrv_coproc[12];
} La_arm_retval;


__BEGIN_DECLS

extern Elf32_Addr la_arm_gnu_pltenter (Elf32_Sym *__sym, unsigned int __ndx,
				       uintptr_t *__refcook,
				       uintptr_t *__defcook,
				       La_arm_regs *__regs,
				       unsigned int *__flags,
				       const char *__symname,
				       long int *__framesizep);
extern unsigned int la_arm_gnu_pltexit (Elf32_Sym *__sym, unsigned int __ndx,
					uintptr_t *__refcook,
					uintptr_t *__defcook,
					const La_arm_regs *__inregs,
					La_arm_retval *__outregs,
					const char *__symname);

__END_DECLS