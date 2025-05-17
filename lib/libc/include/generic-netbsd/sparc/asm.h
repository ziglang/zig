/*	$NetBSD: asm.h,v 1.23 2020/04/17 14:19:44 joerg Exp $ */

/*
 * Copyright (c) 1994 Allen Briggs
 * All rights reserved.
 *
 * Gleaned from locore.s and sun3 asm.h which had the following copyrights:
 * locore.s:
 * Copyright (c) 1988 University of Utah.
 * Copyright (c) 1982, 1990 The Regents of the University of California.
 * sun3/include/asm.h:
 * Copyright (c) 1993 Adam Glass
 * Copyright (c) 1990 The Regents of the University of California.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
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

#ifndef _ASM_H_
#define _ASM_H_

/* Pull in CCFSZ, CC64FSZ, and BIAS from frame.h */
#ifndef _LOCORE
#define _LOCORE
#endif
#include <machine/frame.h>

#ifdef __ELF__
#define	_C_LABEL(name)		name
#else
#ifdef __STDC__
#define _C_LABEL(name)		_ ## name
#else
#define _C_LABEL(name)		_/**/name
#endif
#endif
#define	_ASM_LABEL(name)	name

#ifdef __PIC__
/*
 * PIC_PROLOGUE() is akin to the compiler generated function prologue for
 * PIC code. It leaves the address of the Global Offset Table in DEST,
 * clobbering register TMP in the process.
 *
 * We can use two code sequences.  We can read the %pc or use the call
 * instruction that saves the pc in %o7.  Call requires the branch unit and
 * IEU1, and clobbers %o7 which needs to be restored.  This instruction
 * sequence takes about 4 cycles due to instruction interdependence.  Reading
 * the pc takes 4 cycles to dispatch and is always dispatched alone.  That
 * sequence takes 7 cycles.
 */
#ifdef __arch64__
#define PIC_PROLOGUE(dest,tmp) \
	mov %o7, tmp; \
	sethi %hi(_GLOBAL_OFFSET_TABLE_-4),dest; \
	call 0f; \
	 or dest,%lo(_GLOBAL_OFFSET_TABLE_+4),dest; \
0: \
	add dest,%o7,dest; \
	mov tmp, %o7
#else
#define PIC_PROLOGUE(dest,tmp) \
	mov %o7,tmp; 3: call 4f; nop; 4: \
	sethi %hi(_C_LABEL(_GLOBAL_OFFSET_TABLE_)-(3b-.)),dest; \
	or dest,%lo(_C_LABEL(_GLOBAL_OFFSET_TABLE_)-(3b-.)),dest; \
	add dest,%o7,dest; mov tmp,%o7
#endif

/*
 * PICCY_SET() does the equivalent of a `set var, %dest' instruction in
 * a PIC-like way, but without involving the Global Offset Table. This
 * only works for VARs defined in the same file *and* in the text segment.
 */
#ifdef __arch64__
#define PICCY_SET(var,dest,tmp) \
	3: rd %pc, tmp; add tmp,(var-3b),dest
#else
#define PICCY_SET(var,dest,tmp) \
	mov %o7,tmp; 3: call 4f; nop; 4: \
	add %o7,(var-3b),dest; mov tmp,%o7
#endif
#else
#define PIC_PROLOGUE(dest,tmp)
#define PICCY_OFFSET(var,dest,tmp)
#endif

#define FTYPE(x)		.type x,@function
#define OTYPE(x)		.type x,@object

#define	_ENTRY(name) \
	.align 4; .globl name; FTYPE(name); name:

#ifdef GPROF
/* see _MCOUNT_ENTRY in profile.h */
#ifdef __ELF__
#ifdef __arch64__
#define _PROF_PROLOGUE \
	.data; .align 8; 1: .word 0; .word 0; \
	.text; save %sp,-CC64FSZ,%sp; sethi %hi(1b),%o0; call _mcount; \
	or %o0,%lo(1b),%o0; restore
#else
#define _PROF_PROLOGUE \
	.data; .align 4; 1: .long 0; \
	.text; save %sp,-96,%sp; sethi %hi(1b),%o0; call _mcount; \
	or %o0,%lo(1b),%o0; restore
#endif
#else
#ifdef __arch64__
#define _PROF_PROLOGUE \
	.data; .align 8; 1: .word 0; .word 0; \
	.text; save %sp,-CC64FSZ,%sp; sethi %hi(1b),%o0; call mcount; \
	or %o0,%lo(1b),%o0; restore
#else
#define	_PROF_PROLOGUE \
	.data; .align 4; 1: .long 0; \
	.text; save %sp,-96,%sp; sethi %hi(1b),%o0; call mcount; \
	or %o0,%lo(1b),%o0; restore
#endif
#endif
#else
#define _PROF_PROLOGUE
#endif

#define ENTRY(name)		_ENTRY(_C_LABEL(name)); _PROF_PROLOGUE
#define ENTRY_NOPROFILE(name)	_ENTRY(_C_LABEL(name))
#define	ASENTRY(name)		_ENTRY(_ASM_LABEL(name)); _PROF_PROLOGUE
#define	FUNC(name)		ASENTRY(name)
#define RODATA(name)		.align 4; .text; .globl _C_LABEL(name); \
				OTYPE(_C_LABEL(name)); _C_LABEL(name):
#define	END(y)		.size y, . - y

#define ASMSTR			.asciz

#ifdef __ELF__
#define RCSID(x)	.pushsection ".ident","MS",@progbits,1;		\
			.asciz x;					\
			.popsection
#else
#define RCSID(name)		.asciz name
#endif

#ifdef NO_KERNEL_RCSIDS
#define	__KERNEL_RCSID(_n, _s)	/* nothing */
#else
#define	__KERNEL_RCSID(_n, _s)	RCSID(_s)
#endif

#ifdef __ELF__
#define	WEAK_ALIAS(alias,sym)						\
	.weak alias;							\
	alias = sym
#endif
/*
 * STRONG_ALIAS: create a strong alias.
 */
#define STRONG_ALIAS(alias,sym)						\
	.globl alias;							\
	alias = sym

/*
 * WARN_REFERENCES: create a warning if the specified symbol is referenced.
 */
#ifdef __ELF__
#ifdef __STDC__
#define	WARN_REFERENCES(sym,msg)					\
	.pushsection .gnu.warning. ## sym;				\
	.ascii msg;							\
	.popsection
#else
#define	WARN_REFERENCES(sym,msg)					\
	.pushsection .gnu.warning./**/sym;				\
	.ascii msg;							\
	.popsection
#endif /* __STDC__ */
#else
#ifdef __STDC__
#define	__STRING(x)			#x
#define	WARN_REFERENCES(sym,msg)					\
	.stabs msg ## ,30,0,0,0 ;					\
	.stabs __STRING(_ ## sym) ## ,1,0,0,0
#else
#define	__STRING(x)			"x"
#define	WARN_REFERENCES(sym,msg)					\
	.stabs msg,30,0,0,0 ;						\
	.stabs __STRING(_/**/sym),1,0,0,0
#endif /* __STDC__ */
#endif /* __ELF__ */

#ifdef __arch64__
#define INCR64X(what,r0,r1)						\
	sethi	%hi(what), r0;						\
	ldx	[r0 + %lo(what)], r1;					\
	inc	r1;							\
	stx	r1, [r0 + %lo(what)]
#define INCR64(what)		INCR64X(what,%o0,%o1)
#else
#define INCR64X(what,r0,r1,r2)						\
	sethi	%hi(what), r2;						\
	ldd	[r2 + %lo(what)], r0;					\
	inccc	r1;							\
	addx	r0, 0, r0;						\
	std	r0, [r2 + %lo(what)]
#define INCR64(what)		INCR64X(what,%o0,%o1,%l7)
#endif

#endif /* _ASM_H_ */