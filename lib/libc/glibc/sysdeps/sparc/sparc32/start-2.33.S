/* Startup code for elf32-sparc
   Copyright (C) 1997-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Richard Henderson <richard@gnu.ai.mit.edu>, 1997.

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

#include <sysdep.h>


	.section ".text"
	.align 4
	.global _start
	.type _start,#function
_start:
#ifdef PIC
	SETUP_PIC_REG(l7)
#endif

  /* Terminate the stack frame, and reserve space for functions to
     drop their arguments.  */
	mov	%g0, %fp
	sub	%sp, 6*4, %sp

  /* Extract the arguments and environment as encoded on the stack.  The
     argument info starts after one register window (16 words) past the SP.  */
	ld	[%sp+22*4], %o1
	add	%sp, 23*4, %o2

  /* Load the addresses of the user entry points.  */
#ifndef PIC
	sethi	%hi(main), %o0
	sethi	%hi(__libc_csu_init), %o3
	sethi	%hi(__libc_csu_fini), %o4
	or	%o0, %lo(main), %o0
	or	%o3, %lo(__libc_csu_init), %o3
	or	%o4, %lo(__libc_csu_fini), %o4
#else
	sethi	%gdop_hix22(main), %o0
	sethi	%gdop_hix22(__libc_csu_init), %o3
	sethi	%gdop_hix22(__libc_csu_fini), %o4
	xor	%o0, %gdop_lox10(main), %o0
	xor	%o3, %gdop_lox10(__libc_csu_init), %o3
	xor	%o4, %gdop_lox10(__libc_csu_fini), %o4
	ld	[%l7 + %o0], %o0, %gdop(main)
	ld	[%l7 + %o3], %o3, %gdop(__libc_csu_init)
	ld	[%l7 + %o4], %o4, %gdop(__libc_csu_fini)
#endif

  /* When starting a binary via the dynamic linker, %g1 contains the
     address of the shared library termination function, which will be
     registered with atexit().  If we are statically linked, this will
     be NULL.  */
	mov	%g1, %o5

  /* Let libc do the rest of the initialization, and call main.  */
	call	__libc_start_main
	 nop

  /* Die very horribly if exit returns.  */
	unimp

	.size _start, .-_start

/* Define a symbol for the first piece of initialized data.  */
	.data
	.globl	__data_start
__data_start:
	.long	0
weak_alias (__data_start, data_start)
