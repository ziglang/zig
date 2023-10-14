/* Special .init and .fini section support for PowerPC.
   Copyright (C) 2012-2023 Free Software Foundation, Inc.
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
	.align	2
	.globl	_init
	.hidden	_init
	.type	_init, @function
_init:
	stwu r1, -16(r1)
	mflr r0
	stw r0, 20(r1)
	stw r30, 8(r1)
	SETUP_GOT_ACCESS (r30, .Lgot_label_i)
	addis r30, r30, _GLOBAL_OFFSET_TABLE_-.Lgot_label_i@ha
	addi r30, r30, _GLOBAL_OFFSET_TABLE_-.Lgot_label_i@l
#if PREINIT_FUNCTION_WEAK
	lwz r0, PREINIT_FUNCTION@got(r30)
	cmpwi cr7, r0, 0
	beq+ cr7, 1f
	bl PREINIT_FUNCTION@plt
1:
#else
	bl PREINIT_FUNCTION@local
#endif

	.section .fini,"ax",@progbits
	.align	2
	.globl	_fini
	.hidden	_fini
	.type	_fini, @function
_fini:
	stwu r1, -16(r1)
	mflr r0
	stw r0, 20(r1)
	stw r30, 8(r1)
	SETUP_GOT_ACCESS (r30, .Lgot_label_f)
