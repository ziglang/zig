/*	$NetBSD: ras.h,v 1.15 2021/01/11 21:51:20 skrll Exp $	*/

/*-
 * Copyright (c) 2002, 2004, 2007 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Gregory McGarry.
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

#ifndef _SYS_RAS_H_
#define _SYS_RAS_H_

#ifndef __ASSEMBLER__
#include <sys/types.h>
#include <sys/queue.h>

struct ras {
	struct ras	*ras_next;
	void		*ras_startaddr;
	void		*ras_endaddr;
};

#define RAS_INSTALL		0
#define RAS_PURGE		1
#define RAS_PURGE_ALL		2
#else
#include <sys/cdefs.h>
#endif /* __ASSEMBLER__ */

#ifdef _KERNEL

#ifndef __ASSEMBLER__
struct proc;

void	*ras_lookup(struct proc *, void *);
int	ras_fork(struct proc *, struct proc *);
int	ras_purgeall(void);
#endif /* __ASSEMBLER__ */

#else /* !_KERNEL */

#ifndef	RAS_DECL

#define	RAS_DECL(name)							\
extern void __CONCAT(name,_ras_start(void)), __CONCAT(name,_ras_end(void))

#endif	/* RAS_DECL */

/*
 * RAS_START and RAS_END contain implicit instruction reordering
 * barriers.  See __insn_barrier() in <sys/cdefs.h>.
 *
 * Note: You are strongly advised to avoid coding RASs in C. There is a
 * good chance the compiler will generate code which cannot be restarted.
 */
#define	RAS_START(name)							\
	__asm volatile(".globl " ___STRING(name) "_ras_start\n"	\
			 ___STRING(name) "_ras_start:" 			\
	    ::: "memory")

#define	RAS_END(name)							\
	__asm volatile(".globl " ___STRING(name) "_ras_end\n"		\
			 ___STRING(name) "_ras_end:"			\
	    ::: "memory")

#define	RAS_ADDR(name)	((void *)(uintptr_t) __CONCAT(name,_ras_start))
#define	RAS_SIZE(name)	((size_t)((uintptr_t) __CONCAT(name,_ras_end) -	\
				  (uintptr_t) __CONCAT(name,_ras_start)))

#ifndef __ASSEMBLER__
__BEGIN_DECLS
int rasctl(void *, size_t, int);
__END_DECLS

#else /* __ASSEMBLER__ */

#ifndef	_ASM_LS_CHAR
#define	_ASM_LS_CHAR	;
#endif

/*
 * RAS_START_ASM and RAS_END_ASM are for use within assembly code.
 * This is the preferred method of coding a RAS.
 */
#define	RAS_START_ASM(name)						\
	.globl _C_LABEL(__CONCAT(name,_ras_start))	 _ASM_LS_CHAR	\
	_C_LABEL(__CONCAT(name,_ras_start)):

#define	RAS_END_ASM(name)						\
	.globl _C_LABEL(__CONCAT(name,_ras_end)) 	_ASM_LS_CHAR	\
	_C_LABEL(__CONCAT(name,_ras_end)):

/*
 * RAS_START_ASM_HIDDEN and RAS_END_ASM_HIDDEN are similar to the above,
 * except that they limit the scope of the symbol such that it will not
 * be placed into the dynamic symbol table. Thus no other module (executable
 * or shared library) can reference it directly.
 */
#define	RAS_START_ASM_HIDDEN(name)					\
	.globl _C_LABEL(__CONCAT(name,_ras_start)) 	_ASM_LS_CHAR	\
	.hidden _C_LABEL(__CONCAT(name,_ras_start)) 	_ASM_LS_CHAR	\
	_C_LABEL(__CONCAT(name,_ras_start)):

#define	RAS_END_ASM_HIDDEN(name)					\
	.globl _C_LABEL(__CONCAT(name,_ras_end)) 	_ASM_LS_CHAR	\
	.hidden _C_LABEL(__CONCAT(name,_ras_end)) 	_ASM_LS_CHAR	\
	_C_LABEL(__CONCAT(name,_ras_end)):
#endif /* __ASSEMBLER__ */

#endif /* _KERNEL */

#endif /* !_SYS_RAS_H_ */