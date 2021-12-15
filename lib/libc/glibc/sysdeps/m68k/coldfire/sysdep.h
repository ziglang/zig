/* Assembler macros for Coldfire.
   Copyright (C) 1998-2021 Free Software Foundation, Inc.
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

#include <sysdeps/m68k/sysdep.h>

#ifdef __ASSEMBLER__

/* Perform operation OP with PC-relative SRC as the first operand and
   DST as the second.  TMP is available as a temporary if needed.  */
# define PCREL_OP(OP, SRC, DST, TMP) \
  move.l &SRC - ., TMP; OP (-8, %pc, TMP), DST

/* Load the address of the GOT into register R.  */
# define LOAD_GOT(R) \
  move.l &_GLOBAL_OFFSET_TABLE_@GOTPC, R; \
  lea (-6, %pc, R), R

#else

/* As above, but PC is the spelling of the PC register.  We need this
   so that the macro can be used in both normal and extended asms.  */
# define PCREL_OP(OP, SRC, DST, TMP, PC) \
  "move.l #" SRC " - ., " TMP "\n\t" OP " (-8, " PC ", " TMP "), " DST

#endif	/* __ASSEMBLER__ */
