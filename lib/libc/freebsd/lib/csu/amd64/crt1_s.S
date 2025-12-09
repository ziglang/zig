/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (C) 2023 Dmitry Chagin <dchagin@FreeBSD.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <machine/asm.h>


	.text
	.align 8

	/*
	 * The program entry point
	 *		  %rdi		%rsi
	 * void _start(char **ap, void (*cleanup)(void)) __dead2
	 */
	.globl	_start
	.type	_start, @function
_start:
	.cfi_startproc
	.cfi_undefined %rip		/* Terminate call chain. */
	pushq	%rbp			/* Align stack, terminate call chain. */
	.cfi_def_cfa_offset 8
	movq	%rsp, %rbp
	.cfi_offset %rbp, -16
	.cfi_def_cfa_register %rbp
#ifdef GCRT
	subq	$16, %rsp
#endif
	movq	%rsi, %rcx		/* cleanup */
	movslq	(%rdi), %rax		/* long *ap; tmpargc = *ap */
	leaq	0x8(%rdi), %rsi		/* argv = ap + 1 */
	leaq	0x10(%rdi, %rax, 8), %rdx /* env = ap + 2 + tmpargc */
	movl	%eax, %edi		/* argc = tmpargc */

#ifdef PIC
	/*
	 * XXX. %rip relative addressing is not intended for use in the
	 * large memory model due to the offset from %rip being limited
	 * to 32 bits.
	 */
	leaq	main@plt(%rip), %r8
#else
	movabsq	$main, %r8
#endif
#ifdef GCRT
	movabsq	$eprol, %r9
	movabsq	$etext, %rax
	movq    %rax, (%rsp)
	/*
	 *		      %edi  %rsi  %rdx  %rcx    %r8    %r9    (%rsp)
	 * __libc_start1_gcrt(argc, argv, env, cleanup, main, &eprol, &etext)
	 */
	callq	__libc_start1_gcrt
eprol:
#else
	/* __libc_start1(argc, argv, env, cleanup, main) */
	callq	__libc_start1
#endif
	int3
	.cfi_endproc
	.size   _start, . - _start

	.section .note.GNU-stack,"",%progbits
