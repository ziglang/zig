/* Special .init and .fini section support for 64 bit S/390.
   Copyright (C) 2001-2024 Free Software Foundation, Inc.
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
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

/* crti.S puts a function prologue at the beginning of the .init and
   .fini sections and defines global symbols for those addresses, so
   they can be called as functions.  The symbols _init and _fini are
   magic and cause the linker to emit DT_INIT and DT_FINI.  */

#include <libc-symbols.h>
#include <sysdep.h>

#ifndef PREINIT_FUNCTION
# define PREINIT_FUNCTION __gmon_start__
#endif

#ifndef PREINIT_FUNCTION_WEAK
# define PREINIT_FUNCTION_WEAK 1
#endif

#if PREINIT_FUNCTION_WEAK
	weak_extern (PREINIT_FUNCTION)
#else
	.hidden PREINIT_FUNCTION
#endif

	.section .init,"ax",@progbits
	.align 4
	.globl	_init
	.hidden	_init
	.type	_init,@function
_init:
	stmg	%r6,%r15,48(%r15)
	lgr	%r1,%r15
	aghi	%r15,-160
	stg	%r1,0(%r15)
	larl	%r12,_GLOBAL_OFFSET_TABLE_
#if PREINIT_FUNCTION_WEAK
	/* zig patch: GOTENT -> GOT. revert with llvm 20. */
	larl	%r1,PREINIT_FUNCTION@GOT
	lg	%r1,0(%r1)
	ltgr	%r1,%r1
	je	1f
	basr	%r14,%r1
#else
	brasl	%r14,PREINIT_FUNCTION
#endif
	.align	4,0x07
1:

	.section .fini,"ax",@progbits
	.align 4
	.globl	_fini
	.hidden	_fini
	.type	_fini,@function
_fini:
	stmg	%r6,%r15,48(%r15)
	lg	%r1,120(%r15)
	aghi	%r15,-160
	stg	%r1,0(%r15)
	larl	%r12,_GLOBAL_OFFSET_TABLE_
	.align	4,0x07
