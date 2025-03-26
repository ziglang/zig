/* Startup code compliant to the ELF C-SKY ABIV2.
   Copyright (C) 2018-2025 Free Software Foundation, Inc.
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

/* We need to call:
   __libc_start_main (int (*main) (int, char **, char **), int argc,
		      char **argv, void (*init) (void), void (*fini) (void),
		      void (*rtld_fini) (void), void *stack_end)
 */

#include <sysdep.h>

	.text
	.globl _start;
	.type _start,@function;
	.align 4;
_start:
	cfi_startproc
	.cfi_label .Ldummy
	cfi_undefined (lr)
	subi	sp, 8
	/* Clear the link register since this is the outermost frame.  */
	movi	lr, 0
	/* Pop argc off the stack and save a pointer to argv.  */
	ldw	a1, (sp, 8)	/* Init argc for __libc_start_main.  */
	addi	a2, sp, 12	/* Init argv for __libc_start_main.  */

	/* Push stack limit.  */
	stw	a2, (sp, 8)
	/* Push rtld_fini.  */
	stw	a0, (sp, 4)

#ifdef SHARED
	grs	t0, .Lgetpc
.Lgetpc:
	lrw	gb, .Lgetpc@GOTPC
	addu	gb, t0

	movi	a3, 0		/* Used to be init.  */
	stw 	a3, (sp, 0) 	/* Used to be fini.  */

	lrw	t0, main@GOT
	addu	t0, gb
	ldw	a0, (t0, 0)
	lrw	t1, __libc_start_main@PLT
	ldr.w	t1, (gb, t1 << 0)
	jsr	t1

	lrw	t1, abort@PLT
	ldr.w	t1, (gb, t1 << 0)
	jsr	t1
#else
	movi	a3, 0		/* Used to be init.  */
	stw 	a3, (sp, 0) 	/* Used to be fini.  */
	lrw	a0, main
	/* Let the libc call main and exit with its return code.  */
	jsri	__libc_start_main

	/* Should never get here.  */
	jsri	abort
#endif	/* !SHARED */
	cfi_endproc
	.size _start,.-_start


	/* Define a symbol for the first piece of initialized data.  */
	.data
	.globl __data_start
__data_start:
	.long 0
	.weak data_start
	data_start = __data_start
