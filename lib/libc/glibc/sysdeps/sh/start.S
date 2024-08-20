/* Startup code for SH & ELF.
   Copyright (C) 1999-2024 Free Software Foundation, Inc.
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

/* This is the canonical entry point, usually the first thing in the text
   segment.

	Note that the code in the .init section has already been run.
	This includes _init and _libc_init


	At this entry point, most registers' values are unspecified, except:

   r4		Contains a function pointer to be registered with `atexit'.
		This is how the dynamic linker arranges to have DT_FINI
		functions called for shared libraries that have been loaded
		before this code runs.

   sp		The stack contains the arguments and environment:
		0(sp)			argc
		4(sp)			argv[0]
		...
		(4*argc)(sp)		NULL
		(4*(argc+1))(sp)	envp[0]
		...
					NULL
*/

	.text
	.globl _start
	.type _start,@function
_start:
	/* Clear the frame pointer since this is the outermost frame.  */
	mov #0, r14

	/* Pop argc off the stack and save a pointer to argv */
	mov.l @r15+,r5
	mov r15, r6

	/* Push the last arguments to main() onto the stack */
	mov.l r4,@-r15
	mov.l r14,@-r15		/* Used to be fini.  */

	/* Set up the other arguments for main() that go in registers */
	mov.l L_main,r4
	mov #0,r7		/* Used to be init.  */

	/* __libc_start_main (main, argc, argv, init, fini, rtld_fini) */

	/* Let the libc call main and exit with its return code.  */
	mov.l L_libc_start_main,r1
	jsr @r1
	nop
	/* should never get here....*/
	mov.l L_abort,r1
	jsr @r1
	nop
	.align	2
L_main:
	.long	main
L_libc_start_main:
	.long	__libc_start_main
L_abort:
	.long	abort
/* Define a symbol for the first piece of initialized data.  */
	.data
	.globl __data_start
__data_start:
	.long 0
	.weak data_start
	data_start = __data_start
	.global __fpscr_values
__fpscr_values:
	.long   0
	.long   0x80000
