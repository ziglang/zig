/* ELF startup code for HPPA.
   Copyright (C) 2002-2023 Free Software Foundation, Inc.
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

	.import main, code
	.import $global$, data
	.import __libc_start_main, code

	/* Have the linker create plabel words so we get PLABEL32
	   relocs and not 21/14.  The use of 21/14 relocs is only
	   supported in the latest dynamic linker.  */
#ifdef PIC
	.section	.data.rel.ro,"aw",@progbits
#else
	.section	.rodata,"a",@progbits
#endif
	.align 4
.Lpmain:
	.word P%main
.Lp__libc_start_main:
	.word P%__libc_start_main

	.text
	.align 4
	.globl _start
	.export _start, ENTRY
	.type _start,@function
_start:
	/* At entry to the function we have:

		r26 - Unused
		r25 - argc
		r24 - argv
		r23 - False _dl_fini plabel address

	   This function is called from the lower half of RTLD_START.

	   The call to __libc_start_main expects:

		1. r26 - Application main
		2. r25 - argc
		3. r24 - argv
		4. r23 - init (unused)
		5. sp-52 - fini (unused)
		6. sp-56 - rtld_fini
		7. sp-60 - stackend  */

	.proc
	.callinfo
	/* Clear previous-sp.  */
	stw	%r0, -4(%sp)
	/* Setup the stack and frame.  */
	stw	%rp, -20(%sp)
	ldo	64(%sp), %sp
	stw	%sp, -4(%sp)
	stw	%r19, -32(%sp)

	/* argc and argv should be in 25 and 24 (2nd and 3rd argument) */
	/* void (*rtld_fini) (void) (6th argument) */
	stw	%r23, -56(%sp)

	/* Need to setup 1, 4, 5, and 7th arguments */

#ifdef PIC
	/* Load $global$ address into %dp */
	bl	.+8, %dp
	addil	L'$global$-$PIC_pcrel$0+1, %dp
	ldo	R'$global$-$PIC_pcrel$0+5(%r1), %dp

	/* load main (1st argument) */
	addil	LT'.Lpmain, %r19
	ldw	RT'.Lpmain(%r1), %r26
	ldw	0(%r26),%r26
#else
	/* Load $global$ address into %dp */
	ldil	L%$global$, %dp
	ldo	R%$global$(%dp), %dp

	/* load main (1st argument) */
	ldil	LR'.Lpmain, %r26
	ldw	RR'.Lpmain(%r26), %r26
#endif
	ldi	0,%r23		/* Used to be init.  */
	ldi	0,%r22		/* Used to be fini.  */
	/* Store 5th argument */
	stw	%r22, -52(%sp)
	/* void *stack_end (7th argument) */
	stw	%sp, -60(%sp)
	bl	__libc_start_main,%r2
	nop
	/* die horribly if it returned (it shouldn't) */
	iitlbp %r0,(%sr0,%r0)
	nop

	.procend

/* Define a symbol for the first piece of initialized data.  */
	.data
	.globl __data_start
__data_start:
	.long 0
	.weak data_start
	data_start = __data_start
