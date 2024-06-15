/* Machine-specific declarations for dynamic linker interface.
   Copyright (C) 2022-2024 Free Software Foundation, Inc.
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
#error "Never include <bits/link.h> directly; use <link.h> instead."
#endif

#ifndef __loongarch_soft_float
typedef float La_loongarch_vr
    __attribute__ ((__vector_size__ (16), __aligned__ (16)));
typedef float La_loongarch_xr
    __attribute__ ((__vector_size__ (32), __aligned__ (16)));

typedef union
{
  double fpreg[4];
  La_loongarch_vr vr[2];
  La_loongarch_xr xr[1];
} La_loongarch_vector __attribute__ ((__aligned__ (16)));
#endif

typedef struct La_loongarch_regs
{
  unsigned long int lr_reg[8]; /* a0 - a7 */
#ifndef __loongarch_soft_float
  La_loongarch_vector lr_vec[8]; /* fa0 - fa7 or vr0 - vr7 or xr0 - xr7*/
#endif
  unsigned long int lr_ra;
  unsigned long int lr_sp;
} La_loongarch_regs;

/* Return values for calls from PLT on LoongArch.  */
typedef struct La_loongarch_retval
{
  unsigned long int lrv_a0;
  unsigned long int lrv_a1;
#ifndef __loongarch_soft_float
  La_loongarch_vector lrv_vec0;
  La_loongarch_vector lrv_vec1;
#endif
} La_loongarch_retval;

__BEGIN_DECLS

extern ElfW (Addr) la_loongarch_gnu_pltenter (ElfW (Sym) *__sym,
					      unsigned int __ndx,
					      uintptr_t *__refcook,
					      uintptr_t *__defcook,
					      La_loongarch_regs *__regs,
					      unsigned int *__flags,
					      const char *__symname,
					      long int *__framesizep);
extern unsigned int la_loongarch_gnu_pltexit (ElfW (Sym) *__sym,
					      unsigned int __ndx,
					      uintptr_t *__refcook,
					      uintptr_t *__defcook,
					      const La_loongarch_regs *__inregs,
					      La_loongarch_retval *__outregs,
					      const char *__symname);

__END_DECLS