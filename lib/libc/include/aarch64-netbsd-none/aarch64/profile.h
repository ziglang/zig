/* $NetBSD: profile.h,v 1.4 2021/02/10 12:31:34 ryo Exp $ */

/*-
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef __aarch64__

#define	_MCOUNT_DECL void mcount

/*
 * Cannot implement mcount in C as GCC will trash the ip register when it
 * pushes a trapframe. Pity we cannot insert assembly before the function
 * prologue.
 */

#define MCOUNT_ASM_NAME "_mcount"		/* gcc */
#define MCOUNT_ASM_NAME_ALIAS "__mcount"	/* llvm */
#define	PLTSYM

#define	MCOUNT								\
	__asm(".text");							\
	__asm(".align	6");						\
	__asm(".type	" MCOUNT_ASM_NAME ",@function");		\
	__asm(".global	" MCOUNT_ASM_NAME);				\
	__asm(".global	" MCOUNT_ASM_NAME_ALIAS);			\
	__asm(MCOUNT_ASM_NAME ":");					\
	__asm(MCOUNT_ASM_NAME_ALIAS ":");				\
	/*								\
	 * Preserve registers that are trashed during mcount		\
	 */								\
	__asm("stp	x29, x30, [sp, #-80]!");			\
	__asm("stp	x0, x1, [sp, #16]");				\
	__asm("stp	x2, x3, [sp, #32]");				\
	__asm("stp	x4, x5, [sp, #48]");				\
	__asm("stp	x6, x7, [sp, #64]");				\
	/*								\
	 * find the return address for mcount,				\
	 * and the return address for mcount's caller.			\
	 *								\
	 * frompcindex = pc pushed by call into self.			\
	 */								\
	__asm("ldr	x0, [x29, #8]");				\
	/*								\
	 * selfpc = pc pushed by mcount call				\
	 */								\
	__asm("mov	x1, x30");					\
	/*								\
	 * Call the real mcount code					\
	 */								\
	__asm("bl	" ___STRING(_C_LABEL(mcount)));			\
	/*								\
	 * Restore registers that were trashed during mcount		\
	 */								\
	__asm("ldp	x0, x1, [sp, #16]");				\
	__asm("ldp	x2, x3, [sp, #32]");				\
	__asm("ldp	x4, x5, [sp, #48]");				\
	__asm("ldp	x6, x7, [sp, #64]");				\
	__asm("ldp	x29, x30, [sp], #80");				\
	__asm("ret");							\
	__asm(".size	" MCOUNT_ASM_NAME ", .-" MCOUNT_ASM_NAME);

#ifdef _KERNEL
#define MCOUNT_ENTER	\
	__asm __volatile ("mrs %x0, daif; msr daifset, #3": "=r"(s):: "memory")
#define MCOUNT_EXIT	\
	__asm __volatile ("msr daif, %x0":: "r"(s): "memory")
#endif /* _KERNEL */

#elif defined(__arm__)

#include <arm/profile.h>

#endif