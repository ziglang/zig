/* Machine-specific declarations for dynamic linker interface.  PowerPC version
   Copyright (C) 2004-2024 Free Software Foundation, Inc.
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


#if __ELF_NATIVE_CLASS == 32

/* Registers for entry into PLT on PPC32.  */
typedef struct La_ppc32_regs
{
  uint32_t lr_reg[8];
  double lr_fp[8];
  uint32_t lr_vreg[12][4];
  uint32_t lr_r1;
  uint32_t lr_lr;
} La_ppc32_regs;

/* Return values for calls from PLT on PPC32.  */
typedef struct La_ppc32_retval
{
  uint32_t lrv_r3;
  uint32_t lrv_r4;
  double lrv_fp[8];
  uint32_t lrv_v2[4];
} La_ppc32_retval;


__BEGIN_DECLS

extern Elf32_Addr la_ppc32_gnu_pltenter (Elf32_Sym *__sym,
					 unsigned int __ndx,
					 uintptr_t *__refcook,
					 uintptr_t *__defcook,
					 La_ppc32_regs *__regs,
					 unsigned int *__flags,
					 const char *__symname,
					 long int *__framesizep);
extern unsigned int la_ppc32_gnu_pltexit (Elf32_Sym *__sym,
					  unsigned int __ndx,
					  uintptr_t *__refcook,
					  uintptr_t *__defcook,
					  const La_ppc32_regs *__inregs,
					  La_ppc32_retval *__outregs,
					  const char *__symname);

__END_DECLS

#elif __ELF_NATIVE_CLASS == 64
# if _CALL_ELF != 2

/* Registers for entry into PLT on PPC64.  */
typedef struct La_ppc64_regs
{
  uint64_t lr_reg[8];
  double lr_fp[13];
  uint32_t __padding;
  uint32_t lr_vrsave;
  uint32_t lr_vreg[12][4];
  uint64_t lr_r1;
  uint64_t lr_lr;
} La_ppc64_regs;

/* Return values for calls from PLT on PPC64.  */
typedef struct La_ppc64_retval
{
  uint64_t lrv_r3;
  uint64_t lrv_r4;
  double lrv_fp[4];	/* f1-f4, float - complex long double.  */
  uint32_t lrv_v2[4];	/* v2.  */
} La_ppc64_retval;


__BEGIN_DECLS

extern Elf64_Addr la_ppc64_gnu_pltenter (Elf64_Sym *__sym,
					 unsigned int __ndx,
					 uintptr_t *__refcook,
					 uintptr_t *__defcook,
					 La_ppc64_regs *__regs,
					 unsigned int *__flags,
					 const char *__symname,
					 long int *__framesizep);
extern unsigned int la_ppc64_gnu_pltexit (Elf64_Sym *__sym,
					  unsigned int __ndx,
					  uintptr_t *__refcook,
					  uintptr_t *__defcook,
					  const La_ppc64_regs *__inregs,
					  La_ppc64_retval *__outregs,
					  const char *__symname);

__END_DECLS

# else

/* Registers for entry into PLT on PPC64 in the ELFv2 ABI.  */
typedef struct La_ppc64v2_regs
{
  uint64_t lr_reg[8];
  double lr_fp[13];
  uint32_t __padding;
  uint32_t lr_vrsave;
  uint32_t lr_vreg[12][4] __attribute__ ((aligned (16)));
  uint64_t lr_r1;
  uint64_t lr_lr;
} La_ppc64v2_regs;

/* Return values for calls from PLT on PPC64 in the ELFv2 ABI.  */
typedef struct La_ppc64v2_retval
{
  uint64_t lrv_r3;
  uint64_t lrv_r4;
  double lrv_fp[10];
  uint32_t lrv_vreg[8][4] __attribute__ ((aligned (16)));
} La_ppc64v2_retval;


__BEGIN_DECLS

extern Elf64_Addr la_ppc64v2_gnu_pltenter (Elf64_Sym *__sym,
					   unsigned int __ndx,
					   uintptr_t *__refcook,
					   uintptr_t *__defcook,
					   La_ppc64v2_regs *__regs,
					   unsigned int *__flags,
					   const char *__symname,
					   long int *__framesizep);
extern unsigned int la_ppc64v2_gnu_pltexit (Elf64_Sym *__sym,
					    unsigned int __ndx,
					    uintptr_t *__refcook,
					    uintptr_t *__defcook,
					    const La_ppc64v2_regs *__inregs,
					    La_ppc64v2_retval *__outregs,
					    const char *__symname);

__END_DECLS

# endif
#endif