/* Startup code for programs linked with GNU libc.
   Copyright (C) 1998-2020 Free Software Foundation, Inc.
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

/* We do not want .eh_frame info for crt1.o since crt1.o is linked
   before crtbegin.o, the file defining __EH_FRAME_BEGIN__.  */
#undef cfi_startproc
#define cfi_startproc
#undef cfi_endproc
#define cfi_endproc

 /* These are the various addresses we require.  */
#ifdef PIC
	.section ".data"
#else
	.section ".rodata"
#endif
	.align	2
L(start_addresses):
	.long	_SDA_BASE_
	.long	main
	.long 	__libc_csu_init
	.long 	__libc_csu_fini
	ASM_SIZE_DIRECTIVE(L(start_addresses))

	.section ".text"
ENTRY(_start)
 /* Save the stack pointer, in case we're statically linked under Linux.  */
	mr	r9,r1
 /* Set up an initial stack frame, and clear the LR.  */
	clrrwi	r1,r1,4
#ifdef PIC
	SETUP_GOT_ACCESS(r13,got_label)
	li	r0,0
#else
	li	r0,0
#endif
	stwu	r1,-16(r1)
	mtlr	r0
	stw	r0,0(r1)
 /* Set r13 to point at the 'small data area', and put the address of
    start_addresses in r8.  Also load the GOT pointer so that new PLT
    calls work, like the one to __libc_start_main.  */
#ifdef PIC
	addis	r30,r13,_GLOBAL_OFFSET_TABLE_-got_label@ha
	addis	r8,r13,L(start_addresses)-got_label@ha
	addi	r30,r30,_GLOBAL_OFFSET_TABLE_-got_label@l
	lwzu	r13, L(start_addresses)-got_label@l(r8)
#else
	lis	r8,L(start_addresses)@ha
	lwzu	r13,L(start_addresses)@l(r8)
#endif
 /* and continue in libc-start, in glibc.  */
	b	JUMPTARGET(__libc_start_main)
END(_start)

/* Define a symbol for the first piece of initialized data.  */
	.section ".data"
	.globl	__data_start
__data_start:
	.long	0
weak_alias (__data_start, data_start)
