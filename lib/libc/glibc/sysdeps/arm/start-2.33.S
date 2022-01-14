/* Startup code for ARM & ELF
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

/* This is the canonical entry point, usually the first thing in the text
   segment.

	Note that the code in the .init section has already been run.
	This includes _init and _libc_init


	At this entry point, most registers' values are unspecified, except:

   a1		Contains a function pointer to be registered with `atexit'.
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

/* Tag_ABI_align8_preserved: This code preserves 8-byte
   alignment in any callee.  */
	.eabi_attribute 25, 1
/* Tag_ABI_align8_needed: This code may require 8-byte alignment from
   the caller.  */
	.eabi_attribute 24, 1

#if defined(__thumb2__)
	.thumb
	.syntax unified
#endif

	.text
	.globl _start
	.type _start,#function
_start:
       /* Protect against unhandled exceptions.  */
       .fnstart
	/* Clear the frame pointer and link register since this is the outermost frame. */
	mov fp, #0
	mov lr, #0

	/* Pop argc off the stack and save a pointer to argv */
	pop { a2 }
	mov a3, sp

	/* Push stack limit */
	push { a3 }

	/* Push rtld_fini */
	push { a1 }

#ifdef PIC
	ldr sl, .L_GOT
	adr a4, .L_GOT
	add sl, sl, a4

	ldr ip, .L_GOT+4	/* __libc_csu_fini */
	ldr ip, [sl, ip]

	push { ip }		/* Push __libc_csu_fini */

	ldr a4, .L_GOT+8	/* __libc_csu_init */
	ldr a4, [sl, a4]

	ldr a1, .L_GOT+12	/* main */
	ldr a1, [sl, a1]

	/* __libc_start_main (main, argc, argv, init, fini, rtld_fini, stack_end) */
	/* Let the libc call main and exit with its return code.  */
	bl __libc_start_main(PLT)
#else
	/* Fetch address of __libc_csu_fini */
	ldr ip, =__libc_csu_fini

	/* Push __libc_csu_fini */
	push { ip }

	/* Set up the other arguments in registers */
	ldr a1, =main
	ldr a4, =__libc_csu_init

	/* __libc_start_main (main, argc, argv, init, fini, rtld_fini, stack_end) */
	/* Let the libc call main and exit with its return code.  */
	bl __libc_start_main
#endif

	/* should never get here....*/
	bl abort

#ifdef PIC
	.align 2
.L_GOT:
	.word _GLOBAL_OFFSET_TABLE_ - .L_GOT
	.word __libc_csu_fini(GOT)
	.word __libc_csu_init(GOT)
	.word main(GOT)
#endif

       .cantunwind
       .fnend

/* Define a symbol for the first piece of initialized data.  */
	.data
	.globl __data_start
__data_start:
	.long 0
	.weak data_start
	data_start = __data_start
