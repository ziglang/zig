/* Special .init and .fini section support for ARM.
   Copyright (C) 1995-2020 Free Software Foundation, Inc.
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
   magic and cause the linker to emit DT_INIT and DT_FINI.  */

/* Always build .init and .fini sections in ARM mode.  */
#define NO_THUMB
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

#if PREINIT_FUNCTION_WEAK
	.p2align 2
	.type call_weak_fn, %function
call_weak_fn:
	ldr r3, .LGOT
	ldr r2, .LGOT+4
.LPIC:
	add r3, pc, r3
	ldr r2, [r3, r2]
	cmp r2, #0
	bxeq lr
	b PREINIT_FUNCTION
	.p2align 2
.LGOT:
	.word _GLOBAL_OFFSET_TABLE_-(.LPIC+8)
	.word PREINIT_FUNCTION(GOT)
#endif

	.section .init,"ax",%progbits
	.p2align 2
	.globl _init
	.hidden	_init
	.type _init, %function
_init:
	push	{r3, lr}
#if PREINIT_FUNCTION_WEAK
	bl call_weak_fn
#else
	bl PREINIT_FUNCTION
#endif

	.section .fini,"ax",%progbits
	.p2align 2
	.globl _fini
	.hidden	_fini
	.type _fini, %function
_fini:
	push	{r3, lr}
