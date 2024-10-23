/* Startup code compliant to the ELF Mips ABI.
   Copyright (C) 1995-2024 Free Software Foundation, Inc.
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

#define __ASSEMBLY__ 1
#include <entry.h>
#include <sgidefs.h>
#include <sys/asm.h>

#ifndef ENTRY_POINT
#error ENTRY_POINT needs to be defined for start.S on MIPS/ELF.
#endif

/* This is the canonical entry point, usually the first thing in the text
   segment.  The SVR4/Mips ABI (pages 3-31, 3-32) says that when the entry
   point runs, most registers' values are unspecified, except for:

   v0 ($2)	Contains a function pointer to be registered with `atexit'.
		This is how the dynamic linker arranges to have DT_FINI
		functions called for shared libraries that have been loaded
		before this code runs.

   sp ($29)	The stack contains the arguments and environment:
		0(%esp)			argc
		4(%esp)			argv[0]
		...
		(4*argc)(%esp)		NULL
		(4*(argc+1))(%esp)	envp[0]
		...
					NULL
   ra ($31)	The return address register is set to zero so that programs
		that search backward through stack frames recognize the last
		stack frame.
*/


/* We need to call:
   __libc_start_main (int (*main) (int, char **, char **), int argc,
		      char **argv, void (*init) (void), void (*fini) (void),
		      void (*rtld_fini) (void), void *stack_end)
*/

	.text
	.globl ENTRY_POINT
	.type ENTRY_POINT,@function
#ifndef __mips16
ENTRY_POINT:
# ifdef __PIC__
	SETUP_GPX($0)
	SETUP_GPX64($25,$0)
# else
	PTR_LA $28, _gp		/* Setup GP correctly if we're non-PIC.  */
	move $31, $0
# endif

	PTR_LA $4, main		/* main */
	PTR_L $5, 0($29)		/* argc */
	PTR_ADDIU $6, $29, PTRSIZE	/* argv  */

	/* Allocate space on the stack for seven arguments (o32 only)
	   and make sure the stack is aligned to double words (8 bytes)
	   on o32 and quad words (16 bytes) on n32 and n64.  */

	and $29, -2 * SZREG
# if _MIPS_SIM == _ABIO32
	PTR_SUBIU $29, 32
# endif
	move  $7, $0			/* Used to be init.  */
# if _MIPS_SIM == _ABIO32
	PTR_S $0, 16($29)		/* Used to be fini.  */
	PTR_S $2, 20($29)		/* rtld_fini */
	PTR_S $29, 24($29)		/* stack_end */
# else
	move $8, $0		/* Used to be fini.  */
	move $9, $2		/* rtld_fini */
	move $10, $29		/* stack_end */
# endif
	PTR_LA $25, __libc_start_main
	jalr   $25
hlt:	b hlt			/* Crash if somehow it does return.  */

#elif _MIPS_SIM == _ABIO32 /* __mips16 */
	/* MIPS16 entry point.  */
	.set	mips16
ENTRY_POINT:
# ifdef __PIC__
	li	$3, %hi(_gp_disp)
	addiu	$4, $pc, %lo(_gp_disp)
	sll	$3, 16
	addu	$3, $4
	move	$gp, $3
# else
	li	$3, %hi(_gp)
	sll	$3, 16
	addiu	$3, %lo(_gp)
	move	$gp, $3
# endif
	/* Tie end of stack frames.  */
	li	$4, 0
	move	$31, $4
	/* Create new SP value in $7, including alignment.  */
	li	$4, 2 * SZREG
	neg	$4, $4
	move	$7, $sp
	and	$7, $4
	addiu	$7, -32
	/* Load arguments with original SP.  */
	lw	$5, 0($sp)
	addiu	$6, $sp, PTRSIZE
	/* Update SP.  */
	move	$sp, $7
	/* Lay out last arguments, and call __libc_start_main().  */
# ifdef __PIC__
	sw	$7, 24($sp)			/* stack_end */
	move	$4, $0				/* Used to be ini.  */
	sw	$0, 16($sp)			/* Used to be fini.  */
	lw	$4, %got(main)($3)		/* main */
	lw	$3, %call16(__libc_start_main)($3)
	sw	$2, 20($sp)			/* rtld_fini */
	move	$25, $3
	jalr	$3
# else
	sw	$7, 24($sp)			/* stack_end */
	move	$7, $0				/* Used to be init.  */
	sw	$0, 16($sp)			/* Used to be fini.  */
	lw	$4, 3f				/* main */
	sw	$2, 20($sp)			/* rtld_fini */
	/* Load and call __libc_start_main().  */
	lw	$3, 4f
	jalr	$3
# endif
hlt:	b	hlt		/* Crash if somehow it does return.  */
# ifndef __PIC__
	.align	2
3:	.word	main
4:	.word	__libc_start_main
# endif

#else /* __mips16 && _MIPS_SIM != _ABIO32 */
# error "MIPS16 support for N32/N64 not implemented"

#endif /* __mips16 */

/* Define a symbol for the first piece of initialized data.  */
	.data
	.globl __data_start
__data_start:
	.long 0
	.weak data_start
	data_start = __data_start
