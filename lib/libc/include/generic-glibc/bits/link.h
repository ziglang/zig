/* Copyright (C) 2005-2024 Free Software Foundation, Inc.
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

#include <sgidefs.h>

#if _MIPS_SIM == _ABIO32

/* Registers for entry into PLT on MIPS.  */
typedef struct La_mips_32_regs
{
  uint32_t lr_reg[4]; /* $a0 through $a3 */
  double lr_fpreg[2]; /* $f12 and $f14 */
  uint32_t lr_ra;
  uint32_t lr_sp;
} La_mips_32_regs;

/* Return values for calls from PLT on MIPS.  */
typedef struct La_mips_32_retval
{
  uint32_t lrv_v0;
  uint32_t lrv_v1;
  double lrv_f0;
  double lrv_f2;
} La_mips_32_retval;

#else

typedef struct La_mips_64_regs
{
  uint64_t lr_reg[8]; /* $a0 through $a7 */
  double lr_fpreg[8]; /* $f12 through $f19 */
  uint64_t lr_ra;
  uint64_t lr_sp;
} La_mips_64_regs;

/* Return values for calls from PLT on MIPS.  */
typedef struct La_mips_64_retval
{
  uint64_t lrv_v0;
  uint64_t lrv_v1;
  double lrv_f0;
  double lrv_f2;
} La_mips_64_retval;

#endif

__BEGIN_DECLS

#if _MIPS_SIM == _ABIO32

extern Elf32_Addr la_mips_o32_gnu_pltenter (Elf32_Sym *__sym, unsigned int __ndx,
					    uintptr_t *__refcook,
					    uintptr_t *__defcook,
					    La_mips_32_regs *__regs,
					    unsigned int *__flags,
					    const char *__symname,
					    long int *__framesizep);
extern unsigned int la_mips_o32_gnu_pltexit (Elf32_Sym *__sym, unsigned int __ndx,
					     uintptr_t *__refcook,
					     uintptr_t *__defcook,
					     const La_mips_32_regs *__inregs,
					     La_mips_32_retval *__outregs,
					     const char *__symname);

#elif _MIPS_SIM == _ABIN32

extern Elf32_Addr la_mips_n32_gnu_pltenter (Elf32_Sym *__sym, unsigned int __ndx,
					    uintptr_t *__refcook,
					    uintptr_t *__defcook,
					    La_mips_64_regs *__regs,
					    unsigned int *__flags,
					    const char *__symname,
					    long int *__framesizep);
extern unsigned int la_mips_n32_gnu_pltexit (Elf32_Sym *__sym, unsigned int __ndx,
					     uintptr_t *__refcook,
					     uintptr_t *__defcook,
					     const La_mips_64_regs *__inregs,
					     La_mips_64_retval *__outregs,
					     const char *__symname);

#else

extern Elf64_Addr la_mips_n64_gnu_pltenter (Elf64_Sym *__sym, unsigned int __ndx,
					    uintptr_t *__refcook,
					    uintptr_t *__defcook,
					    La_mips_64_regs *__regs,
					    unsigned int *__flags,
					    const char *__symname,
					    long int *__framesizep);
extern unsigned int la_mips_n64_gnu_pltexit (Elf64_Sym *__sym, unsigned int __ndx,
					     uintptr_t *__refcook,
					     uintptr_t *__defcook,
					     const La_mips_64_regs *__inregs,
					     La_mips_64_retval *__outregs,
					     const char *__symname);

#endif

__END_DECLS