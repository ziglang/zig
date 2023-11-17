/* Copyright (C) 1992-2023 Free Software Foundation, Inc.
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

#include <sysdeps/unix/mips/sysdep.h>

#ifdef __ASSEMBLER__
#include <sys/asm.h>

/* Note that while it's better structurally, going back to call __syscall_error
   can make things confusing if you're debugging---it looks like it's jumping
   backwards into the previous fn.  */
#ifdef __PIC__
#define PSEUDO(name, syscall_name, args) \
  .align 2;								      \
  .set nomips16;							      \
  cfi_startproc;							      \
  99:;									      \
  .set noat;								      \
  .cpsetup t9, $1, name;						      \
  cfi_register (gp, $1);						      \
  .set at;								      \
  PTR_LA t9,__syscall_error;						      \
  .cpreturn;								      \
  cfi_restore (gp);							      \
  jr t9;								      \
  cfi_endproc;								      \
  ENTRY(name)								      \
  li v0, SYS_ify(syscall_name);						      \
  syscall;								      \
  bne a3, zero, 99b;							      \
L(syse1):
#else
#define PSEUDO(name, syscall_name, args) \
  .set noreorder;							      \
  .align 2;								      \
  .set nomips16;							      \
  cfi_startproc;							      \
  99: j __syscall_error;						      \
  nop;                                                                        \
  cfi_endproc;								      \
  ENTRY(name)								      \
  .set noreorder;							      \
  li v0, SYS_ify(syscall_name);						      \
  syscall;								      \
  .set reorder;								      \
  bne a3, zero, 99b;							      \
L(syse1):
#endif

#endif
