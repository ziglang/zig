/* -*- mode: asm -*- */
/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1993 The Regents of the University of California.
 * All rights reserved.
 *
 * Copyright (c) 2018 The FreeBSD Foundation
 * All rights reserved.
 *
 * Portions of this software were developed by
 * Konstantin Belousov <kib@FreeBSD.org> under sponsorship from
 * the FreeBSD Foundation.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#if defined(__i386__)
#include <i386/asmacros.h>
#else /* !__i386__ */

#ifndef _MACHINE_ASMACROS_H_
#define _MACHINE_ASMACROS_H_

#include <sys/cdefs.h>

/* XXX too much duplication in various asm*.h's. */

/*
 * CNAME is used to manage the relationship between symbol names in C
 * and the equivalent assembly language names.  CNAME is given a name as
 * it would be used in a C program.  It expands to the equivalent assembly
 * language name.
 */
#define CNAME(csym)		csym

#define ALIGN_DATA	.p2align 3	/* 8 byte alignment, zero filled */
#define ALIGN_TEXT	.p2align 4,0x90	/* 16-byte alignment, nop filled */
#define SUPERALIGN_TEXT	.p2align 4,0x90	/* 16-byte alignment, nop filled */

#define GEN_ENTRY(name)		ALIGN_TEXT; .globl CNAME(name); \
				.type CNAME(name),@function; CNAME(name):
#define ENTRY(name)		GEN_ENTRY(name)
#define ALTENTRY(name)		GEN_ENTRY(name)
#define	END(name)		.size name, . - name

/*
 * Convenience for adding frame pointers to hand-coded ASM.  Useful for
 * DTrace, HWPMC, and KDB.
 */
#define PUSH_FRAME_POINTER	\
	pushq	%rbp ;		\
	movq	%rsp, %rbp ;
#define POP_FRAME_POINTER	\
	popq	%rbp

#ifdef LOCORE
/*
 * Access per-CPU data.
 */
#define	PCPU(member)	%gs:PC_ ## member
#define	PCPU_ADDR(member, reg)					\
	movq %gs:PC_PRVSPACE, reg ;				\
	addq $PC_ ## member, reg

/*
 * Convenience macro for declaring interrupt entry points.
 */
#define	IDTVEC(name)	ALIGN_TEXT; .globl __CONCAT(X,name); \
			.type __CONCAT(X,name),@function; __CONCAT(X,name):

	.macro	SAVE_SEGS
	movw	%fs,TF_FS(%rsp)
	movw	%gs,TF_GS(%rsp)
	movw	%es,TF_ES(%rsp)
	movw	%ds,TF_DS(%rsp)
	.endm

	.macro	MOVE_STACKS qw
	.L.offset=0
	.rept	\qw
	movq	.L.offset(%rsp),%rdx
	movq	%rdx,.L.offset(%rax)
	.L.offset=.L.offset+8
	.endr
	.endm

	.macro	PTI_UUENTRY has_err
	movq	PCPU(KCR3),%rax
	movq	%rax,%cr3
	movq	PCPU(RSP0),%rax
	subq	$PTI_SIZE - 8 * (1 - \has_err),%rax
	MOVE_STACKS	((PTI_SIZE / 8) - 1 + \has_err)
	movq	%rax,%rsp
	popq	%rdx
	popq	%rax
	.endm

	.macro	PTI_UENTRY has_err
	swapgs
	lfence
	cmpq	$~0,PCPU(UCR3)
	je	1f
	pushq	%rax
	pushq	%rdx
	PTI_UUENTRY \has_err
1:
	.endm

	.macro	PTI_ENTRY name, contk, contu, has_err=0
	ALIGN_TEXT
	.globl	X\name\()_pti
	.type	X\name\()_pti,@function
X\name\()_pti:
	/* %rax, %rdx, and possibly err are not yet pushed */
	testb	$SEL_RPL_MASK,PTI_CS-PTI_ERR-((1-\has_err)*8)(%rsp)
	jz	\contk
	PTI_UENTRY \has_err
	jmp	\contu
	.endm

	.macro	PTI_INTRENTRY vec_name
	SUPERALIGN_TEXT
	.globl	X\vec_name\()_pti
	.type	X\vec_name\()_pti,@function
X\vec_name\()_pti:
	testb	$SEL_RPL_MASK,PTI_CS-3*8(%rsp) /* err, %rax, %rdx not pushed */
	jz	.L\vec_name\()_u
	PTI_UENTRY has_err=0
	jmp	.L\vec_name\()_u
	.endm

	.macro	INTR_PUSH_FRAME vec_name
	SUPERALIGN_TEXT
	.globl	X\vec_name
	.type	X\vec_name,@function
X\vec_name:
	testb	$SEL_RPL_MASK,PTI_CS-3*8(%rsp) /* come from kernel? */
	jz	.L\vec_name\()_u		/* Yes, dont swapgs again */
	swapgs
.L\vec_name\()_u:
	lfence
	subq	$TF_RIP,%rsp	/* skip dummy tf_err and tf_trapno */
	movq	%rdi,TF_RDI(%rsp)
	movq	%rsi,TF_RSI(%rsp)
	movq	%rdx,TF_RDX(%rsp)
	movq	%rcx,TF_RCX(%rsp)
	movq	%r8,TF_R8(%rsp)
	movq	%r9,TF_R9(%rsp)
	movq	%rax,TF_RAX(%rsp)
	movq	%rbx,TF_RBX(%rsp)
	movq	%rbp,TF_RBP(%rsp)
	movq	%r10,TF_R10(%rsp)
	movq	%r11,TF_R11(%rsp)
	movq	%r12,TF_R12(%rsp)
	movq	%r13,TF_R13(%rsp)
	movq	%r14,TF_R14(%rsp)
	movq	%r15,TF_R15(%rsp)
	SAVE_SEGS
	movl	$TF_HASSEGS,TF_FLAGS(%rsp)
	pushfq
	andq	$~(PSL_D|PSL_AC),(%rsp)
	popfq
	testb	$SEL_RPL_MASK,TF_CS(%rsp)  /* come from kernel ? */
	jz	1f		/* yes, leave PCB_FULL_IRET alone */
	movq	PCPU(CURPCB),%r8
	andl	$~PCB_FULL_IRET,PCB_FLAGS(%r8)
	call	handle_ibrs_entry
1:
	.endm

	.macro	INTR_HANDLER vec_name
	.text
	PTI_INTRENTRY	\vec_name
	INTR_PUSH_FRAME	\vec_name
	.endm

	.macro	RESTORE_REGS
	movq	TF_RDI(%rsp),%rdi
	movq	TF_RSI(%rsp),%rsi
	movq	TF_RDX(%rsp),%rdx
	movq	TF_RCX(%rsp),%rcx
	movq	TF_R8(%rsp),%r8
	movq	TF_R9(%rsp),%r9
	movq	TF_RAX(%rsp),%rax
	movq	TF_RBX(%rsp),%rbx
	movq	TF_RBP(%rsp),%rbp
	movq	TF_R10(%rsp),%r10
	movq	TF_R11(%rsp),%r11
	movq	TF_R12(%rsp),%r12
	movq	TF_R13(%rsp),%r13
	movq	TF_R14(%rsp),%r14
	movq	TF_R15(%rsp),%r15
	.endm

#ifdef KMSAN
/*
 * The KMSAN runtime relies on a TLS block to track initialization and origin
 * state for function parameters and return values.  To keep this state
 * consistent in the face of asynchronous kernel-mode traps, the runtime
 * maintains a stack of blocks: when handling an exception or interrupt,
 * kmsan_intr_enter() pushes the new block to be used until the handler is
 * complete, at which point kmsan_intr_leave() restores the previous block.
 *
 * Thus, KMSAN_ENTER/LEAVE hooks are required only in handlers for events that
 * may have happened while in kernel-mode.  In particular, they are not required
 * around amd64_syscall() or ast() calls.  Otherwise, kmsan_intr_enter() can be
 * called unconditionally, without distinguishing between entry from user-mode
 * or kernel-mode.
 */
#define	KMSAN_ENTER	callq kmsan_intr_enter
#define	KMSAN_LEAVE	callq kmsan_intr_leave
#else
#define	KMSAN_ENTER
#define	KMSAN_LEAVE
#endif

#endif /* LOCORE */

#ifdef __STDC__
#define ELFNOTE(name, type, desctype, descdata...) \
.pushsection .note.name, "a", @note     ;       \
  .align 4                              ;       \
  .long 2f - 1f         /* namesz */    ;       \
  .long 4f - 3f         /* descsz */    ;       \
  .long type                            ;       \
1:.asciz #name                          ;       \
2:.align 4                              ;       \
3:desctype descdata                     ;       \
4:.align 4                              ;       \
.popsection
#else /* !__STDC__, i.e. -traditional */
#define ELFNOTE(name, type, desctype, descdata) \
.pushsection .note.name, "a", @note     ;       \
  .align 4                              ;       \
  .long 2f - 1f         /* namesz */    ;       \
  .long 4f - 3f         /* descsz */    ;       \
  .long type                            ;       \
1:.asciz "name"                         ;       \
2:.align 4                              ;       \
3:desctype descdata                     ;       \
4:.align 4                              ;       \
.popsection
#endif /* __STDC__ */

#endif /* !_MACHINE_ASMACROS_H_ */

#endif /* __i386__ */