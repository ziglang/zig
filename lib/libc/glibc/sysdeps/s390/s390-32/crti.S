/* Special .init and .fini section support for S/390.
   Copyright (C) 2000-2021 Free Software Foundation, Inc.
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
	.globl	_init
	.hidden	_init
	.type	_init,@function
	.align	4
_init:
	stm	%r6,%r15,24(%r15)
	bras	%r13,1f
0:
#if PREINIT_FUNCTION_WEAK
	.long	PREINIT_FUNCTION@GOT
#else
	.long	PREINIT_FUNCTION-0b
#endif
	.long	_GLOBAL_OFFSET_TABLE_-0b
1:	lr	%r1,%r15
	ahi	%r15,-96
	st	%r1,0(%r15)
	l	%r12,4(%r13)
	ar	%r12,%r13
	l	%r1,0(%r13)
#if PREINIT_FUNCTION_WEAK
	l	%r1,0(%r1,%r12)
	ltr	%r1,%r1
	je	2f
#else
	la	%r1,0(%r1,%r13)
#endif
	basr	%r14,%r1
	.align	4,0x07
2:

	.section .fini,"ax",@progbits
	.globl	_fini
	.hidden	_fini
	.type	_fini,@function
	.align	4
_fini:
	stm	%r6,%r15,24(%r15)
	bras	%r13,1f
0:	.long	_GLOBAL_OFFSET_TABLE_-0b
1:	lr	%r1,%r15
	ahi	%r15,-96
	st	%r1,0(%r15)
	l	%r12,0(%r13)
	ar	%r12,%r13
	.align	4,0x07
