/* Startup code compliant to the ELF s390 ABI.
   Copyright (C) 2000-2020 Free Software Foundation, Inc.
   Contributed by Martin Schwidefsky (schwidefsky@de.ibm.com).
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

#include <sysdep.h>

/*
   This is the canonical entry point, usually the first thing in the text
   segment. Most registers' values are unspecified, except for:

   %r14         Contains a function pointer to be registered with `atexit'.
		This is how the dynamic linker arranges to have DT_FINI
		functions called for shared libraries that have been loaded
		before this code runs.

   %r15		The stack contains the arguments and environment:
		0(%r15)			argc
		4(%r15)			argv[0]
		...
		(4*argc)(%r15)		NULL
		(4*(argc+1))(%r15)	envp[0]
		...
					NULL
*/

	.text
	.globl _start
	.type _start,@function
_start:
	cfi_startproc
	/* Mark r14 as undefined in order to stop unwinding here!  */
	/* zig patch: r14 -> %r14. revert with llvm 20. */
	cfi_undefined (%r14)

	/* Check if the kernel provides highgprs facility if needed by
	   the binary.  */

	lr	%r6,%r15
	la	%r6,4(%r6)     /* Skip the argument counter.  */

.L11:	l	%r5,0(%r6)     /* Skip the argument vector.  */
	la	%r6,4(%r6)
	ltr	%r5,%r5
	jne	.L11

.L12:	l	%r5,0(%r6)     /* Skip the environment vector.  */
	la	%r6,4(%r6)
	ltr	%r5,%r5
	jne	.L12

	/* Usually the auxiliary vector can be expected directly after
	   the environment variables.  But we have to skip extra zeros
	   because the loader might have removed unsecure variables for
	   setuid programs.  */

.L26:	l	%r5,0(%r6)
	la	%r6,4(%r6)
	ltr	%r5,%r5
	jz	.L26

	ahi	%r6,-4

	/* Obtain the needed values from the auxiliary vector.  */

	lhi	%r7,16	       /* AT_HWCAP */
	lhi	%r8,3	       /* AT_PHDR */
	lhi	%r9,5          /* AT_PHNUM */
	lhi	%r2,4          /* AT_PHENT */
.L13:	l	%r5,0(%r6)
	clr	%r5,%r7
	jne	.L15
	l	%r10,4(%r6)    /* r10 = AT_HWCAP value.  */
.L15:	clr	%r5,%r8
	jne	.L16
	l	%r11,4(%r6)    /* r11 = AT_PHDR value.  */
.L16:	clr	%r5,%r9
	jne	.L17
	l	%r12,4(%r6)    /* r12 = AT_PHNUM value.  */
.L17:	clr	%r5,%r2
	jne	.L18
	l	%r0,4(%r6)     /* r0 = AT_PHENT value.  */
.L18:	ltr	%r5,%r5
	la	%r6,8(%r6)
	jnz	.L13

	/* Locate the ELF header by looking for the first PT_LOAD
	   segment with a p_offset of zero.  */

	lr	%r4,%r11       /* Backup AT_PHDR.  */
	lhi	%r7,1          /* PT_LOAD id */
	lhi	%r8,0
.L19:	cl	%r7,0(%r4)     /* p_type == PT_LOAD? */
	jne	.L20
	cl	%r8,4(%r4)     /* p_offset == 0? */
	jne	.L20
	l	%r9,8(%r4)     /* r9 = PT_LOAD.p_vaddr <- ELF header address  */
	j	.L24
.L20:	alr	%r4,%r0        /* r4 += AT_PHENT value */
	brct	%r12,.L19

	j	.+2            /* Trap, there must be such a phdr.  */

.L24:	lr	%r4,%r11       /* Backup AT_PHDR.  */
	lhi	%r2,6          /* PT_PHDR id */
.L23:	cl	%r2,0(%r4)
	jne	.L22
	l	%r3,8(%r4)     /* r3 = PT_PHDR p_vaddr */
	j	.L25
.L22:	alr	%r4,%r0        /* r4 += AT_PHENT value */
	brct	%r12,.L23

	j	.L14	       /* No PT_PHDR found - skip checking.  */

.L25:	slr	%r11,%r3       /* AT_PHDR - PT_PHDR.p_vaddr (relocation offset)*/
	alr	%r9,%r11       /* PT_LOAD.p_vaddr += relocation offset */

	l	%r5,36(%r9)    /* Load the e_flags field.  */
	tml	%r5,1
	jz	.L14	       /* Binary does not require highgprs facility.  */

	tml	%r10,512       /* Check the AT_HWCAP value.  */
	jz	2              /* Trap if no highgprs facility available.  */
.L14:

	/* Setup pointer to literal pool of _start */
	basr    %r13,0
.L0:    ahi     %r13,.Llit-.L0

	/* load argc and argv from stack */
	la      %r4,4(%r15)             # get argv
	l       %r3,0(%r15)             # get argc

	/* align the stack to a double word boundary */
	lhi     %r0,-8
	nr      %r15,%r0

	/* Setup a stack frame and a parameter area */
	ahi     %r15,-104               # make room on stack
	xc      0(4,%r15),0(%r15)       # clear back-chain

	/* set up arguments for __libc_start_main:
	   main, argc, argv, envp, _init, _fini, rtld_fini, stack_end
	   Note that envp will be determined later in __libc_start_main
	 */
	stm     %r14,%r15,96(%r15)      # store rtld_fini/stack_end to parameter area
	la      %r7,96(%r15)
	l       %r6,.L2-.Llit(%r13)     # load pointer to __libc_csu_fini
	l       %r5,.L1-.Llit(%r13)     # load pointer to __libc_csu_init
	l       %r2,.L3-.Llit(%r13)     # load pointer to main
	l       %r1,.L4-.Llit(%r13)	# load pointer to __libc_start_main
#ifdef PIC
	l       %r12,.L5-.Llit(%r13)    # load .got pointer
	la	%r6,0(%r13,%r6)
	la	%r5,0(%r13,%r5)
	la	%r12,0(%r13,%r12)
	l	%r2,0(%r12,%r2)
	la	%r1,0(%r13,%r1)
#endif

	/* ok, now branch to the libc main routine */
	basr    %r14,%r1

	/* crash if __libc_start_main returns */
	.word   0

	cfi_endproc
.Llit:
#ifndef PIC
.L1:    .long  __libc_csu_init
.L2:    .long  __libc_csu_fini
.L3:    .long  main
.L4:    .long  __libc_start_main
#else
.L1:    .long  __libc_csu_init-.Llit
.L2:    .long  __libc_csu_fini-.Llit
.L3:    .long  main@GOT
.L4:    .long  __libc_start_main@plt-.Llit
.L5:    .long  _GLOBAL_OFFSET_TABLE_-.Llit
#endif

/* Define a symbol for the first piece of initialized data.  */
	.data
	.globl __data_start
__data_start:
	.long 0
	.weak data_start
	data_start = __data_start
