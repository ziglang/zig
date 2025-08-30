/* System-specific settings for dynamic linker code.  i386 version.
   Copyright (C) 2002-2025 Free Software Foundation, Inc.
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

#ifndef _LINUX_I386_DL_SYSDEP_H

#include_next <dl-sysdep.h>

/* Traditionally system calls have been made using int $0x80.  A
   second method was introduced which, if possible, will use the
   sysenter/syscall instructions.  To signal the presence and where to
   find the code the kernel passes an AT_SYSINFO value in the
   auxiliary vector to the application.  */
#define NEED_DL_SYSINFO	1

#ifndef __ASSEMBLER__
extern void _dl_sysinfo_int80 (void) attribute_hidden;
# define DL_SYSINFO_DEFAULT (uintptr_t) _dl_sysinfo_int80
# define DL_SYSINFO_IMPLEMENTATION \
  asm (".text\n\t"							      \
       ".type _dl_sysinfo_int80,@function\n\t"				      \
       ".hidden _dl_sysinfo_int80\n"					      \
       CFI_STARTPROC "\n"						      \
       "_dl_sysinfo_int80:\n\t"						      \
       "int $0x80;\n\t"							      \
       "ret;\n\t"							      \
       CFI_ENDPROC "\n"							      \
       ".size _dl_sysinfo_int80,.-_dl_sysinfo_int80\n\t"		      \
       ".previous");
#endif

#endif	/* dl-sysdep.h */
