/*-
 * Copyright 2009 Konstantin Belousov.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <machine/asm.h>
	.text
	.align	4
	.globl	_start
	.type	_start, @function
_start:
	.cfi_startproc
	.cfi_undefined %eip
	popl	%esi		# Pop argc
	.cfi_def_cfa_offset -4
	movl	%esp,%edi	# argv starts at stack top
	xorl	%ebp,%ebp
	pushl	%ebp
	.cfi_def_cfa_offset 0
	movl	%esp,%ebp
	.cfi_offset %ebp,-4
	.cfi_def_cfa_register %ebp
	andl	$0xfffffff0,%esp # align stack

#ifdef GCRT
	subl	$4,%esp		# Align stack for 7 arguments
	pushl	$etext
	pushl	$eprol
eprol:
#else
	subl	$12,%esp	# Align stack for 5 arguments
#endif /* GCRT */

#ifdef PIC
	calll	1f
1:	popl	%ebx
	addl	$_GLOBAL_OFFSET_TABLE_+[.-1b],%ebx
	leal	main@GOTOFF(%ebx),%eax
	pushl	%eax
#else
	pushl	$main
#endif /* PIC */

	pushl	%edx		# rtld cleanup
	/* env = argv + argc + 1 */
	movl	%edi,%eax	# env = argv
	movl	%esi,%ecx
	shll	$2,%ecx		# argc * 4
	addl	%ecx,%eax	# env += argc
	addl	$4,%eax		# env += 1
	pushl	%eax		# env
	pushl	%edi		# argv
	pushl	%esi		# argc

#ifdef GCRT
	/*
	 * __libc_start1_gcrt(argc, argv, env, cleanup, main, &eprol, &etext);
	 */
	calll	__libc_start1_gcrt
#else
	/*
	 * __libc_start1(argc, argv, env, cleanup, main);
	 */
#ifdef PIC
	calll	__libc_start1@PLT
#else
	calll	__libc_start1
#endif
#endif /* GCRT */
	int3
	.cfi_endproc
	.size	_start, . - _start

	.section .note.GNU-stack,"",%progbits
