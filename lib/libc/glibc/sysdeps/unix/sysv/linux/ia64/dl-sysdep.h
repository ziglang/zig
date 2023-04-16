/* System-specific settings for dynamic linker code.  IA-64 version.
   Copyright (C) 2003-2023 Free Software Foundation, Inc.
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

#ifndef _LINUX_IA64_DL_SYSDEP_H
#define _LINUX_IA64_DL_SYSDEP_H	1

#include_next <dl-sysdep.h>

/* Traditionally system calls have been made using break 0x100000.  A
   second method was introduced which, if possible, will use the EPC
   instruction.  To signal the presence and where to find the code the
   kernel passes an AT_SYSINFO_EHDR pointer in the auxiliary vector to
   the application.  */
#define NEED_DL_SYSINFO	1
#define USE_DL_SYSINFO	1

#ifndef __ASSEMBLER__
/* Don't declare this as a function---we want it's entry-point, not
   it's function descriptor... */
extern int _dl_sysinfo_break attribute_hidden;
# define DL_SYSINFO_DEFAULT ((uintptr_t) &_dl_sysinfo_break)
# define DL_SYSINFO_IMPLEMENTATION		\
  asm (".text\n\t"				\
       ".hidden _dl_sysinfo_break\n\t"		\
       ".proc _dl_sysinfo_break\n\t"		\
       "_dl_sysinfo_break:\n\t"			\
       ".prologue\n\t"				\
       ".altrp b6\n\t"				\
       ".body\n\t"				\
       "break 0x100000;\n\t"			\
       "br.ret.sptk.many b6;\n\t"		\
       ".endp _dl_sysinfo_break\n\t"		\
       ".previous");
#endif

#endif	/* dl-sysdep.h */
