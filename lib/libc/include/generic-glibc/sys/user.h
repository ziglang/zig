/* Copyright (C) 2002-2021 Free Software Foundation, Inc.
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

#ifndef _SYS_USER_H
#define _SYS_USER_H	1

#include <sgidefs.h>
#include <stddef.h>

/* The whole purpose of this file is for GDB and GDB only.  Don't read
   too much into it.  Don't use it for anything other than GDB unless
   you know what you are doing.  */

/* #include <asm/reg.h> */
/* Instead of including the kernel header, that will vary depending on
   whether the 32- or the 64-bit kernel is installed, we paste its
   contents here.  Note that the fact that the file is inline here,
   instead of included separately, doesn't change in any way the
   licensing status of a program that includes user.h.  Since this is
   for gdb alone, and gdb is GPLed, no surprises here.  */
#if _MIPS_SIM == _ABIO32
/*
 * Various register offset definitions for debuggers, core file
 * examiners and whatnot.
 *
 * This file is subject to the terms and conditions of the GNU General Public
 * License.  See the file "COPYING" in the main directory of this archive
 * for more details.
 *
 * Copyright (C) 1995, 1999 by Ralf Baechle
 */
#ifndef __ASM_MIPS_REG_H
#define __ASM_MIPS_REG_H

/*
 * This defines/structures correspond to the register layout on stack -
 * if the order here is changed, it needs to be updated in
 * include/asm-mips/stackframe.h
 */
#define EF_REG0			6
#define EF_REG1			7
#define EF_REG2			8
#define EF_REG3			9
#define EF_REG4			10
#define EF_REG5			11
#define EF_REG6			12
#define EF_REG7			13
#define EF_REG8			14
#define EF_REG9			15
#define EF_REG10		16
#define EF_REG11		17
#define EF_REG12		18
#define EF_REG13		19
#define EF_REG14		20
#define EF_REG15		21
#define EF_REG16		22
#define EF_REG17		23
#define EF_REG18		24
#define EF_REG19		25
#define EF_REG20		26
#define EF_REG21		27
#define EF_REG22		28
#define EF_REG23		29
#define EF_REG24		30
#define EF_REG25		31
/*
 * k0/k1 unsaved
 */
#define EF_REG28		34
#define EF_REG29		35
#define EF_REG30		36
#define EF_REG31		37

/*
 * Saved special registers
 */
#define EF_LO			38
#define EF_HI			39

#define EF_CP0_EPC		40
#define EF_CP0_BADVADDR		41
#define EF_CP0_STATUS		42
#define EF_CP0_CAUSE		43

#define EF_SIZE			180	/* size in bytes */

#endif /* __ASM_MIPS_REG_H */

#else /* _MIPS_SIM != _ABIO32 */

/*
 * Various register offset definitions for debuggers, core file
 * examiners and whatnot.
 *
 * This file is subject to the terms and conditions of the GNU General Public
 * License.  See the file "COPYING" in the main directory of this archive
 * for more details.
 *
 * Copyright (C) 1995, 1999 Ralf Baechle
 * Copyright (C) 1995, 1999 Silicon Graphics
 */
#ifndef _ASM_REG_H
#define _ASM_REG_H

/*
 * This defines/structures correspond to the register layout on stack -
 * if the order here is changed, it needs to be updated in
 * include/asm-mips/stackframe.h
 */
#define EF_REG0			 0
#define EF_REG1			 1
#define EF_REG2			 2
#define EF_REG3			 3
#define EF_REG4			 4
#define EF_REG5			 5
#define EF_REG6			 6
#define EF_REG7			 7
#define EF_REG8			 8
#define EF_REG9			 9
#define EF_REG10		10
#define EF_REG11		11
#define EF_REG12		12
#define EF_REG13		13
#define EF_REG14		14
#define EF_REG15		15
#define EF_REG16		16
#define EF_REG17		17
#define EF_REG18		18
#define EF_REG19		19
#define EF_REG20		20
#define EF_REG21		21
#define EF_REG22		22
#define EF_REG23		23
#define EF_REG24		24
#define EF_REG25		25
/*
 * k0/k1 unsaved
 */
#define EF_REG28		28
#define EF_REG29		29
#define EF_REG30		30
#define EF_REG31		31

/*
 * Saved special registers
 */
#define EF_LO			32
#define EF_HI			33

#define EF_CP0_EPC		34
#define EF_CP0_BADVADDR		35
#define EF_CP0_STATUS		36
#define EF_CP0_CAUSE		37

#define EF_SIZE			304	/* size in bytes */

#endif /* _ASM_REG_H */

#endif /* _MIPS_SIM != _ABIO32 */

#if _MIPS_SIM == _ABIO32

struct user
{
  unsigned long	regs[EF_SIZE/4+64];	/* integer and fp regs */
  size_t	u_tsize;		/* text size (pages) */
  size_t	u_dsize;		/* data size (pages) */
  size_t	u_ssize;		/* stack size (pages) */
  unsigned long	start_code;		/* text starting address */
  unsigned long	start_data;		/* data starting address */
  unsigned long	start_stack;		/* stack starting address */
  long int	signal;			/* signal causing core dump */
  void*		u_ar0;			/* help gdb find registers */
  unsigned long	magic;			/* identifies a core file */
  char		u_comm[32];		/* user command name */
};

#else

struct user {
  __extension__ unsigned long	regs[EF_SIZE/8+64]; /* integer and fp regs */
  __extension__ unsigned long	u_tsize;	/* text size (pages) */
  __extension__ unsigned long	u_dsize;	/* data size (pages) */
  __extension__ unsigned long	u_ssize;	/* stack size (pages) */
  __extension__ unsigned long long start_code;	/* text starting address */
  __extension__ unsigned long long start_data;	/* data starting address */
  __extension__ unsigned long long start_stack;	/* stack starting address */
  __extension__ long long	signal;		/* signal causing core dump */
  __extension__ unsigned long long u_ar0;	/* help gdb find registers */
  __extension__ unsigned long long magic;	/* identifies a core file */
  char		u_comm[32];		/* user command name */
};

#endif

#endif	/* _SYS_USER_H */