/* Machine-specific declarations for dynamic linker interface, ARC version.
   Copyright (C) 2020-2025 Free Software Foundation, Inc.
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

/* Registers for entry into PLT on ARC.  */
typedef struct La_arc_regs
{
  uint32_t lr_reg[8]; /* r0 through r7 (upto 8 args).  */
} La_arc_regs;

/* Return values for calls from PLT on ARC.  */
typedef struct La_arc_retval
{
  /* For ARCv2, a 64-bit integer return value can use 2 regs.  */
  uint32_t lrv_reg[2];
} La_arc_retval;

__BEGIN_DECLS

extern ElfW(Addr) la_arc_gnu_pltenter (ElfW(Sym) *__sym, unsigned int __ndx,
					 uintptr_t *__refcook,
					 uintptr_t *__defcook,
					 La_arc_regs *__regs,
					 unsigned int *__flags,
					 const char *__symname,
					 long int *__framesizep);
extern unsigned int la_arc_gnu_pltexit (ElfW(Sym) *__sym, unsigned int __ndx,
					  uintptr_t *__refcook,
					  uintptr_t *__defcook,
					  const La_arc_regs *__inregs,
					  La_arc_retval *__outregs,
					  const char *symname);

__END_DECLS