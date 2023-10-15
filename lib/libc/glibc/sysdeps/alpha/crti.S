/* Special .init and .fini section support for Alpha.
   Copyright (C) 2001-2023 Free Software Foundation, Inc.
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

/* crti.S puts a function prologue at the beginning of the .init and
   .fini sections and defines global symbols for those addresses, so
   they can be called as functions.  The symbols _init and _fini are
   magic and cause the linker to emit DT_INIT and DT_FINI.

   This differs from what would be generated for ordinary code in that
   we save and restore the GP within the function.  In order for linker
   relaxation to work, the value in the GP register on exit from a function
   must be valid for the function entry point.  Normally, a function is
   contained within one object file and this is not an issue, provided
   that the function reloads the gp after making any function calls.
   However, _init and _fini are constructed from pieces of many object
   files, all of which may have different GP values.  So we must reload
   the GP value from crti.o in crtn.o.  */

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

	.section .init, "ax", @progbits
	.globl	_init
	.hidden	_init
	.type	_init, @function
	.usepv	_init, std
_init:
	ldgp	$29, 0($27)
	subq	$30, 16, $30
#if PREINIT_FUNCTION_WEAK
	lda	$27, PREINIT_FUNCTION
#endif
	stq	$26, 0($30)
	stq	$29, 8($30)
#if PREINIT_FUNCTION_WEAK
	beq	$27, 1f
	jsr	$26, ($27), PREINIT_FUNCTION
	ldq	$29, 8($30)
1:
#else
	bsr	$26, PREINIT_FUNCTION !samegp
#endif
	.p2align 3

	.section .fini, "ax", @progbits
	.globl	_fini
	.hidden	_fini
	.type	_fini,@function
	.usepv	_fini,std
_fini:
	ldgp	$29, 0($27)
	subq	$30, 16, $30
	stq	$26, 0($30)
	stq	$29, 8($30)
	.p2align 3
