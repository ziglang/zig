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
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef	_LINK_H
# error "Never include <bits/link.h> directly; use <link.h> instead."
#endif

#if defined HAVE_S390_VX_ASM_SUPPORT
typedef char La_s390_vr[16];
#endif

#if __ELF_NATIVE_CLASS == 32

/* Registers for entry into PLT on s390-32.  */
typedef struct La_s390_32_regs
{
  uint32_t lr_r2;
  uint32_t lr_r3;
  uint32_t lr_r4;
  uint32_t lr_r5;
  uint32_t lr_r6;
  double lr_fp0;
  double lr_fp2;
# if defined HAVE_S390_VX_ASM_SUPPORT
  La_s390_vr lr_v24;
  La_s390_vr lr_v25;
  La_s390_vr lr_v26;
  La_s390_vr lr_v27;
  La_s390_vr lr_v28;
  La_s390_vr lr_v29;
  La_s390_vr lr_v30;
  La_s390_vr lr_v31;
# endif
} La_s390_32_regs;

/* Return values for calls from PLT on s390-32.  */
typedef struct La_s390_32_retval
{
  uint32_t lrv_r2;
  uint32_t lrv_r3;
  double lrv_fp0;
# if defined HAVE_S390_VX_ASM_SUPPORT
  La_s390_vr lrv_v24;
# endif
} La_s390_32_retval;


__BEGIN_DECLS

extern Elf32_Addr la_s390_32_gnu_pltenter (Elf32_Sym *__sym,
					   unsigned int __ndx,
					   uintptr_t *__refcook,
					   uintptr_t *__defcook,
					   La_s390_32_regs *__regs,
					   unsigned int *__flags,
					   const char *__symname,
					   long int *__framesizep);
extern unsigned int la_s390_32_gnu_pltexit (Elf32_Sym *__sym,
					    unsigned int __ndx,
					    uintptr_t *__refcook,
					    uintptr_t *__defcook,
					    const La_s390_32_regs *__inregs,
					    La_s390_32_retval *__outregs,
					    const char *symname);

__END_DECLS

#else

/* Registers for entry into PLT on s390-64.  */
typedef struct La_s390_64_regs
{
  uint64_t lr_r2;
  uint64_t lr_r3;
  uint64_t lr_r4;
  uint64_t lr_r5;
  uint64_t lr_r6;
  double lr_fp0;
  double lr_fp2;
  double lr_fp4;
  double lr_fp6;
# if defined HAVE_S390_VX_ASM_SUPPORT
  La_s390_vr lr_v24;
  La_s390_vr lr_v25;
  La_s390_vr lr_v26;
  La_s390_vr lr_v27;
  La_s390_vr lr_v28;
  La_s390_vr lr_v29;
  La_s390_vr lr_v30;
  La_s390_vr lr_v31;
# endif
} La_s390_64_regs;

/* Return values for calls from PLT on s390-64.  */
typedef struct La_s390_64_retval
{
  uint64_t lrv_r2;
  double lrv_fp0;
# if defined HAVE_S390_VX_ASM_SUPPORT
  La_s390_vr lrv_v24;
# endif
} La_s390_64_retval;


__BEGIN_DECLS

extern Elf64_Addr la_s390_64_gnu_pltenter (Elf64_Sym *__sym,
					   unsigned int __ndx,
					   uintptr_t *__refcook,
					   uintptr_t *__defcook,
					   La_s390_64_regs *__regs,
					   unsigned int *__flags,
					   const char *__symname,
					   long int *__framesizep);
extern unsigned int la_s390_64_gnu_pltexit (Elf64_Sym *__sym,
					    unsigned int __ndx,
					    uintptr_t *__refcook,
					    uintptr_t *__defcook,
					    const La_s390_64_regs *__inregs,
					    La_s390_64_retval *__outregs,
					    const char *__symname);

__END_DECLS

#endif