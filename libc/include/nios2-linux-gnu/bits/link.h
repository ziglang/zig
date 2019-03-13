/* Machine-specific declarations for dynamic linker interface, Nios II version.
   Copyright (C) 2009-2019 Free Software Foundation, Inc.
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
   <http://www.gnu.org/licenses/>.  */

#ifndef	_LINK_H
# error "Never include <bits/link.h> directly; use <link.h> instead."
#endif

/* Registers for entry into PLT on Nios II.  */
typedef struct La_nios2_regs
{
  uint32_t lr_reg[4]; /* r4 through r7 */
  uint32_t lr_ra;
  uint32_t lr_sp;
} La_nios2_regs;

/* Return values for calls from PLT on Nios II.  */
typedef struct La_nios2_retval
{
  uint32_t lrv_r2;
  uint32_t lrv_r3;
} La_nios2_retval;

__BEGIN_DECLS

extern Elf32_Addr la_nios2_gnu_pltenter (Elf32_Sym *__sym, unsigned int __ndx,
					 uintptr_t *__refcook,
					 uintptr_t *__defcook,
					 La_nios2_regs *__regs,
					 unsigned int *__flags,
					 const char *__symname,
					 long int *__framesizep);
extern unsigned int la_nios2_gnu_pltexit (Elf32_Sym *__sym, unsigned int __ndx,
					  uintptr_t *__refcook,
					  uintptr_t *__defcook,
					  const La_nios2_regs *__inregs,
					  La_nios2_retval *__outregs,
					  const char *symname);

__END_DECLS