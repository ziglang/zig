/* Special .init and .fini section support for SH.
   Copyright (C) 2000-2024 Free Software Foundation, Inc.
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

	.section	.init,"ax",@progbits
	.align 5
	.global	_init
	.hidden	_init
	.type	_init, @function
_init:
	mov.l	r12,@-r15
	mova	.L12,r0
	mov.l	.L12,r12
	mov.l	r14,@-r15
	add	r0,r12
	sts.l	pr,@-r15
#if PREINIT_FUNCTION_WEAK
	mov.l	.L13,r0
	mov.l	@(r0,r12),r1
	tst	r1,r1
	bt/s	.L8
	mov	r15,r14
	mov.l	.L14,r1
	bsrf	r1
.LPCS0:
	nop
.L8:
#else
	mova    .L13,r0
	mov.l	.L13,r1
	add	r0,r1
	jsr	@r1
	mov    r15,r14
#endif
	bra	1f
	nop
	.align 2
.L12:
	.long	_GLOBAL_OFFSET_TABLE_
#if PREINIT_FUNCTION_WEAK
.L13:
	.long	PREINIT_FUNCTION@GOT
.L14:
	.long	PREINIT_FUNCTION@PLT-(.LPCS0+2-(.))
#else
.L13:
	.long	PREINIT_FUNCTION@PLT
#endif
1:

	.section	.fini,"ax",@progbits
	.align 5
	.global	_fini
	.hidden	_fini
	.type	_fini, @function
_fini:
	mov.l	r12,@-r15
	mova	.L19,r0
	mov.l	r14,@-r15
	sts.l	pr,@-r15
	mov.l	.L19,r12
	mov	r15,r14
	add	r0,r12
	bra	0f
	nop
	.align 2
.L19:
	.long	_GLOBAL_OFFSET_TABLE_
0:
