/* Special .init and .fini section support for ARM.
   Copyright (C) 2000-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   In addition to the permissions in the GNU Lesser General Public
   License, the Free Software Foundation gives you unlimited
   permission to link the compiled version of this file with other
   programs, and to distribute those programs without any restriction
   coming from the use of this file. (The GNU Lesser General Public
   License restrictions do apply in other respects; for example, they
   cover modification of the file, and distribution when not linked
   into another program.)

   Note that people who make modified versions of this file are not
   obligated to grant this special exception for their modified
   versions; it is their choice whether to do so. The GNU Lesser
   General Public License gives permission to release a modified
   version without this exception; this exception also makes it
   possible to release a modified version which carries forward this
   exception.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library.  If not, see
   <https://www.gnu.org/licenses/>.  */

#include <sysdep.h>
#undef ret

/* crtn.S puts function epilogues in the .init and .fini sections
   corresponding to the prologues in crti.S. */

	.section .init,"ax",@progbits
	.proc _init#
_init:
	.prologue
	.save ar.pfs, r34
	.vframe r32
	.save rp, r33
	.body
	.regstk 0,2,0,0
	mov r12 = r32
	mov ar.pfs = r34
	mov b0 = r33
	br.ret.sptk.many b0
	.endp _init#

	.section .fini,"ax",@progbits
	.proc _fini#
_fini:
	.prologue
	.save ar.pfs, r34
	.vframe r32
	.save rp, r33
	.body
	mov r12 = r32
	mov ar.pfs = r34
	mov b0 = r33
	br.ret.sptk.many b0
	.endp _fini#
