/* Machine-specific declarations for dynamic linker interface.  C-SKY version.
   Copyright (C) 2018-2023 Free Software Foundation, Inc.
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

#ifndef _LINK_H
# error "Never include <bits/link.h> directly; use <link.h> instead."
#endif

/* Registers for entry into PLT on C-SKY.  */
typedef struct La_csky_regs
{
  uint32_t lr_reg[4];
  uint32_t lr_sp;
  uint32_t lr_lr;
} La_csky_regs;

/* Return values for calls from PLT on C-SKY.  */
typedef struct La_csky_retval
{
  /* Up to four integer registers can be used for a return value.  */
  uint32_t lrv_reg[4];
  uint32_t lrv_v0;
} La_csky_retval;

__BEGIN_DECLS

extern Elf32_Addr la_csky_gnu_pltenter (Elf32_Sym *__sym, unsigned int __ndx,
					uintptr_t *__refcook,
					uintptr_t *__defcook,
					La_csky_regs *__regs,
					unsigned int *__flags,
					const char *__symname,
					long int *__framesizep);
extern unsigned int la_csky_gnu_pltexit (Elf32_Sym *__sym, unsigned int __ndx,
					 uintptr_t *__refcook,
					 uintptr_t *__defcook,
					 const La_csky_regs *__inregs,
					 La_csky_retval *__outregs,
					 const char *__symname);

__END_DECLS