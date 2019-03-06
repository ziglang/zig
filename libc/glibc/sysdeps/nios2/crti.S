/* Special .init and .fini section support for Nios II.
   Copyright (C) 2012-2019 Free Software Foundation, Inc.
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
   <http://www.gnu.org/licenses/>.  */

/* crti.S puts a function prologue at the beginning of the .init and
   .fini sections and defines global symbols for those addresses, so
   they can be called as functions.  The symbols _init and _fini are
   magic and cause the linker to emit DT_INIT and DT_FINI.  */

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

	.section .init,"ax",@progbits
	.align	2
	.global	_init
	.hidden	_init
	.type	_init, @function
_init:
	addi	sp, sp, -8
	stw	r22, 0(sp)
	nextpc	r22
	1:
	movhi	r8, %hiadj(_gp_got - 1b)
	addi	r8, r8, %lo(_gp_got - 1b)
	add	r22, r22, r8
	stw	ra, 4(sp)
#if PREINIT_FUNCTION_WEAK
	movhi	r2, %got_hiadj(PREINIT_FUNCTION)
	addi	r2, r2, %got_lo(PREINIT_FUNCTION)
	add	r2, r2, r22
	ldw	r2, 0(r2)
	beq	r2, zero, .L5
#endif
	movhi	r2, %call_hiadj(PREINIT_FUNCTION)
	addi	r2, r2, %call_lo(PREINIT_FUNCTION)
	add	r2, r2, r22
	ldw	r2, 0(r2)
	callr	r2
.L5:

	.section .fini,"ax",@progbits
	.align	2
	.global	_fini
	.hidden	_fini
	.type	_fini, @function
_fini:
	addi	sp, sp, -8
	stw	r22, 0(sp)
	nextpc	r22
	1:
	movhi	r8, %hiadj(_gp_got - 1b)
	addi	r8, r8, %lo(_gp_got - 1b)
	stw	ra, 4(sp)
	add	r22, r22, r8
