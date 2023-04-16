/* Startup code compliant to the ELF x86-64 ABI.
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
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

/* This is the canonical entry point, usually the first thing in the text
   segment.  The SVR4/i386 ABI (pages 3-31, 3-32) says that when the entry
   point runs, most registers' values are unspecified, except for:

   %rdx		Contains a function pointer to be registered with `atexit'.
		This is how the dynamic linker arranges to have DT_FINI
		functions called for shared libraries that have been loaded
		before this code runs.

   %rsp		The stack contains the arguments and environment:
		0(%rsp)				argc
		LP_SIZE(%rsp)			argv[0]
		...
		(LP_SIZE*argc)(%rsp)		NULL
		(LP_SIZE*(argc+1))(%rsp)	envp[0]
		...
						NULL
*/

#include <sysdep.h>

ENTRY (_start)
	/* Clearing frame pointer is insufficient, use CFI.  */
	cfi_undefined (rip)
	/* Clear the frame pointer.  The ABI suggests this be done, to mark
	   the outermost frame obviously.  */
	xorl %ebp, %ebp

	/* Extract the arguments as encoded on the stack and set up
	   the arguments for __libc_start_main (int (*main) (int, char **, char **),
		   int argc, char *argv,
		   void (*init) (void), void (*fini) (void),
		   void (*rtld_fini) (void), void *stack_end).
	   The arguments are passed via registers and on the stack:
	main:		%rdi
	argc:		%rsi
	argv:		%rdx
	init:		%rcx
	fini:		%r8
	rtld_fini:	%r9
	stack_end:	stack.	*/

	mov %RDX_LP, %R9_LP	/* Address of the shared library termination
				   function.  */
#ifdef __ILP32__
	mov (%rsp), %esi	/* Simulate popping 4-byte argument count.  */
	add $4, %esp
#else
	popq %rsi		/* Pop the argument count.  */
#endif
	/* argv starts just at the current stack top.  */
	mov %RSP_LP, %RDX_LP
	/* Align the stack to a 16 byte boundary to follow the ABI.  */
	and  $~15, %RSP_LP

	/* Push garbage because we push 8 more bytes.  */
	pushq %rax

	/* Provide the highest stack address to the user code (for stacks
	   which grow downwards).  */
	pushq %rsp

	/* These used to be the addresses of .fini and .init.  */
	xorl %r8d, %r8d
	xorl %ecx, %ecx

#ifdef PIC
	mov main@GOTPCREL(%rip), %RDI_LP
#else
	mov $main, %RDI_LP
#endif

	/* Call the user's main function, and exit with its value.
	   But let the libc call main.  Since __libc_start_main in
	   libc.so is called very early, lazy binding isn't relevant
	   here.  Use indirect branch via GOT to avoid extra branch
	   to PLT slot.  In case of static executable, ld in binutils
	   2.26 or above can convert indirect branch into direct
	   branch.  */
	call *__libc_start_main@GOTPCREL(%rip)

	hlt			/* Crash if somehow `exit' does return.	 */
END (_start)

/* Define a symbol for the first piece of initialized data.  */
	.data
	.globl __data_start
__data_start:
	.long 0
	.weak data_start
	data_start = __data_start
