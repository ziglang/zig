/* Machine-specific audit interfaces for dynamic linker.  SPARC version.
   Copyright (C) 2005-2024 Free Software Foundation, Inc.
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

#ifndef	_LINK_H
# error "Never include <bits/link.h> directly; use <link.h> instead."
#endif

#if __WORDSIZE == 32

typedef struct La_sparc32_regs
{
  uint32_t lr_lreg[8];  /* %l0 through %l7 */
  uint32_t lr_reg[6];   /* %o0 through %o5 */
  uint32_t lr_sp;       /* %o6 */
  uint32_t lr_ra;       /* %o7 */
  uint32_t lr_struct;   /* Pass-by-reference struct pointer */
} La_sparc32_regs;

typedef struct La_sparc32_retval
{
  uint32_t lrv_reg[2]; /* %o0 and %o1 */
  double lrv_fpreg[2]; /* %f0 and %f2 */
} La_sparc32_retval;

#else

typedef struct La_sparc64_regs
{
  uint64_t lr_lreg[8];  /* %l0 through %l7 */
  uint64_t lr_reg[6];	/* %o0 through %o5 */
  uint64_t lr_sp;	/* %o6 */
  uint64_t lr_ra;	/* %o7 */
  double lr_fpreg[16];	/* %f0 through %f30 */
} La_sparc64_regs;

typedef struct La_sparc64_retval
{
  uint64_t lrv_reg[4]; /* %o0 through %o3 */
  double lrv_fprev[4]; /* %f0 through %f8 */
} La_sparc64_retval;

#endif

__BEGIN_DECLS

#if __WORDSIZE == 32

extern Elf32_Addr la_sparc32_gnu_pltenter (Elf32_Sym *__sym,
					   unsigned int __ndx,
					   uintptr_t *__refcook,
					   uintptr_t *__defcook,
					   La_sparc32_regs *__regs,
					   unsigned int *__flags,
					   const char *__symname,
					   long int *__framesizep);
extern unsigned int la_sparc32_gnu_pltexit (Elf32_Sym *__sym,
					    unsigned int __ndx,
					    uintptr_t *__refcook,
					    uintptr_t *__defcook,
					     const La_sparc32_regs *__inregs,
					    La_sparc32_retval *__outregs,
					    const char *__symname);

#else

extern Elf64_Addr la_sparc64_gnu_pltenter (Elf64_Sym *__sym,
					   unsigned int __ndx,
					   uintptr_t *__refcook,
					   uintptr_t *__defcook,
					   La_sparc64_regs *__regs,
					   unsigned int *__flags,
					   const char *__symname,
					   long int *__framesizep);
extern unsigned int la_sparc64_gnu_pltexit (Elf64_Sym *__sym,
					    unsigned int __ndx,
					    uintptr_t *__refcook,
					    uintptr_t *__defcook,
					    const La_sparc64_regs *__inregs,
					    La_sparc64_retval *__outregs,
					    const char *__symname);

#endif

__END_DECLS