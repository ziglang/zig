/* Determine the wordsize from the preprocessor defines.  RISC-V version.
   Copyright (C) 2002-2020 Free Software Foundation, Inc.
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

#if __riscv_xlen == (__SIZEOF_POINTER__ * 8)
# define __WORDSIZE __riscv_xlen
#else
# error unsupported ABI
#endif

#if __riscv_xlen == 64
# define __WORDSIZE_TIME64_COMPAT32 1
#else
# error "rv32i-based targets are not supported"
#endif