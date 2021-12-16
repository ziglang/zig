/* Special .init and .fini section support for AArch64.
   Copyright (C) 1995-2021 Free Software Foundation, Inc.

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

#include <sysdep.h>
#include <libc-symbols.h>

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

#if PREINIT_FUNCTION_WEAK
	.align	2
	.type	call_weak_fn, %function
call_weak_fn:
	adrp	x0, :got:PREINIT_FUNCTION
	ldr	PTR_REG (0), [x0, #:got_lo12:PREINIT_FUNCTION]
	cbz	x0, 1f
	b	PREINIT_FUNCTION
1:
	RET
	.size	call_weak_fn, .-call_weak_fn
#endif

	.section .init,"ax",%progbits
	.align	2
	.global	_init
	.hidden	_init
	.type	_init, %function
_init:
#if HAVE_AARCH64_PAC_RET
	PACIASP
#else
	BTI_C
#endif
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
#if PREINIT_FUNCTION_WEAK
	bl	call_weak_fn
#else
	bl	PREINIT_FUNCTION
#endif

	.section	.fini,"ax",%progbits
	.align	2
	.global	_fini
	.hidden	_fini
	.type	_fini, %function
_fini:
#if HAVE_AARCH64_PAC_RET
	PACIASP
#else
	BTI_C
#endif
	stp	x29, x30, [sp, -16]!
	mov	x29, sp
