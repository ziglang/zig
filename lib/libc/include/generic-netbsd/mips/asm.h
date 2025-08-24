/*	$NetBSD: asm.h,v 1.71.4.1 2023/07/31 13:36:30 martin Exp $	*/

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Ralph Campbell.
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
 *
 *	@(#)machAsmDefs.h	8.1 (Berkeley) 6/10/93
 */

/*
 * machAsmDefs.h --
 *
 *	Macros used when writing assembler programs.
 *
 *	Copyright (C) 1989 Digital Equipment Corporation.
 *	Permission to use, copy, modify, and distribute this software and
 *	its documentation for any purpose and without fee is hereby granted,
 *	provided that the above copyright notice appears in all copies.
 *	Digital Equipment Corporation makes no representations about the
 *	suitability of this software for any purpose.  It is provided "as is"
 *	without express or implied warranty.
 *
 * from: Header: /sprite/src/kernel/mach/ds3100.md/RCS/machAsmDefs.h,
 *	v 1.2 89/08/15 18:28:24 rab Exp  SPRITE (DECWRL)
 */

#ifndef _MIPS_ASM_H
#define	_MIPS_ASM_H

#include <sys/cdefs.h>		/* for API selection */
#include <mips/regdef.h>

#if defined(_KERNEL_OPT)
#include "opt_gprof.h"
#endif

#ifdef __ASSEMBLER__
#define	__BIT(n)	(1 << (n))
#define	__BITS(hi,lo)	((~((~0)<<((hi)+1)))&((~0)<<(lo)))

#define	__LOWEST_SET_BIT(__mask) ((((__mask) - 1) & (__mask)) ^ (__mask))
#define	__SHIFTOUT(__x, __mask) (((__x) & (__mask)) / __LOWEST_SET_BIT(__mask))
#define	__SHIFTIN(__x, __mask) ((__x) * __LOWEST_SET_BIT(__mask))
#endif	/* __ASSEMBLER__ */

/*
 * Define -pg profile entry code.
 * Must always be noreorder, must never use a macro instruction.
 */
#if defined(__mips_o32)		/* Old 32-bit ABI */
/*
 * The old ABI version must also decrement two less words off the
 * stack and the final addiu to t9 must always equal the size of this
 * _MIPS_ASM_MCOUNT.
 */
#define	_MIPS_ASM_MCOUNT					\
	.set	push;						\
	.set	noreorder;					\
	.set	noat;						\
	subu	sp,16;						\
	sw	t9,12(sp);					\
	move	AT,ra;						\
	lui	t9,%hi(_mcount); 				\
	addiu	t9,t9,%lo(_mcount);				\
	jalr	t9;						\
	 nop;							\
	lw	t9,4(sp);					\
	addiu	sp,8;						\
	addiu	t9,40;						\
	.set	pop;
#elif defined(__mips_o64)	/* Old 64-bit ABI */
# error yeahnah
#else				/* New (n32/n64) ABI */
/*
 * The new ABI version just needs to put the return address in AT and
 * call _mcount().  For the no abicalls case, skip the reloc dance.
 */
#ifdef __mips_abicalls
#define	_MIPS_ASM_MCOUNT					\
	.set	push;						\
	.set	noreorder;					\
	.set	noat;						\
	subu	sp,16;						\
	sw	t9,8(sp);					\
	move	AT,ra;						\
	lui	t9,%hi(_mcount); 				\
	addiu	t9,t9,%lo(_mcount);				\
	jalr	t9;						\
	 nop;							\
	lw	t9,8(sp);					\
	addiu	sp,16;						\
	.set	pop;
#else /* !__mips_abicalls */
#define	_MIPS_ASM_MCOUNT					\
	.set	push;						\
	.set	noreorder;					\
	.set	noat;						\
	move	AT,ra;						\
	jal	_mcount;					\
	 nop;							\
	.set	pop;
#endif /* !__mips_abicalls */
#endif /* n32/n64 */

#ifdef GPROF
#define	MCOUNT _MIPS_ASM_MCOUNT
#else
#define	MCOUNT
#endif

#ifdef USE_AENT
#define	AENT(x)				\
	.aent	x, 0
#else
#define	AENT(x)
#endif

/*
 * WEAK_ALIAS: create a weak alias.
 */
#define	WEAK_ALIAS(alias,sym)						\
	.weak alias;							\
	alias = sym
/*
 * STRONG_ALIAS: create a strong alias.
 */
#define	STRONG_ALIAS(alias,sym)						\
	.globl alias;							\
	alias = sym

/*
 * WARN_REFERENCES: create a warning if the specified symbol is referenced.
 */
#define	WARN_REFERENCES(sym,msg)					\
	.pushsection __CONCAT(.gnu.warning.,sym);			\
	.ascii msg;							\
	.popsection

/*
 * STATIC_LEAF_NOPROFILE
 *	No profilable local leaf routine.
 */
#define	STATIC_LEAF_NOPROFILE(x)	\
	.ent	_C_LABEL(x);		\
_C_LABEL(x): ;				\
	.frame sp, 0, ra

/*
 * LEAF_NOPROFILE
 *	No profilable leaf routine.
 */
#define	LEAF_NOPROFILE(x)		\
	.globl	_C_LABEL(x);		\
	STATIC_LEAF_NOPROFILE(x)

/*
 * STATIC_LEAF
 *	Declare a local leaf function.
 */
#define	STATIC_LEAF(x)			\
	STATIC_LEAF_NOPROFILE(x);	\
	MCOUNT

/*
 * LEAF
 *	A leaf routine does
 *	- call no other function,
 *	- never use any register that callee-saved (S0-S8), and
 *	- not use any local stack storage.
 */
#define	LEAF(x)				\
	LEAF_NOPROFILE(x);		\
	MCOUNT

/*
 * STATIC_XLEAF
 *	declare alternate entry to a static leaf routine
 */
#define	STATIC_XLEAF(x)			\
	AENT (_C_LABEL(x));		\
_C_LABEL(x):

/*
 * XLEAF
 *	declare alternate entry to leaf routine
 */
#define	XLEAF(x)			\
	.globl	_C_LABEL(x);		\
	STATIC_XLEAF(x)

/*
 * STATIC_NESTED_NOPROFILE
 *	No profilable local nested routine.
 */
#define	STATIC_NESTED_NOPROFILE(x, fsize, retpc)	\
	.ent	_C_LABEL(x);				\
	.type	_C_LABEL(x), @function;			\
_C_LABEL(x): ;						\
	.frame	sp, fsize, retpc

/*
 * NESTED_NOPROFILE
 *	No profilable nested routine.
 */
#define	NESTED_NOPROFILE(x, fsize, retpc)	\
	.globl	_C_LABEL(x);			\
	STATIC_NESTED_NOPROFILE(x, fsize, retpc)

/*
 * NESTED
 *	A function calls other functions and needs
 *	therefore stack space to save/restore registers.
 */
#define	NESTED(x, fsize, retpc)			\
	NESTED_NOPROFILE(x, fsize, retpc);	\
	MCOUNT

/*
 * STATIC_NESTED
 *	No profilable local nested routine.
 */
#define	STATIC_NESTED(x, fsize, retpc)			\
	STATIC_NESTED_NOPROFILE(x, fsize, retpc);	\
	MCOUNT

/*
 * XNESTED
 *	declare alternate entry point to nested routine.
 */
#define	XNESTED(x)			\
	.globl	_C_LABEL(x);		\
	AENT (_C_LABEL(x));		\
_C_LABEL(x):

/*
 * END
 *	Mark end of a procedure.
 */
#define	END(x)				\
	.end _C_LABEL(x);		\
	.size _C_LABEL(x), . - _C_LABEL(x)

/*
 * IMPORT -- import external symbol
 */
#define	IMPORT(sym, size)		\
	.extern _C_LABEL(sym),size

/*
 * EXPORT -- export definition of symbol
 */
#define	EXPORT(x)			\
	.globl	_C_LABEL(x);		\
_C_LABEL(x):

/*
 * EXPORT_OBJECT -- export definition of symbol of symbol
 * type Object, visible to ksyms(4) address search.
 */
#define	EXPORT_OBJECT(x)		\
	EXPORT(x);			\
	.type	_C_LABEL(x), @object;

/*
 * VECTOR
 *	exception vector entrypoint
 *	XXX: regmask should be used to generate .mask
 */
#define	VECTOR(x, regmask)		\
	.ent	_C_LABEL(x);		\
	EXPORT(x);			\

#define	VECTOR_END(x)			\
	EXPORT(__CONCAT(x,_end));	\
	END(x);				\
	.org _C_LABEL(x) + 0x80

/*
 * Macros to panic and printf from assembly language.
 */
#define	PANIC(msg)			\
	PTR_LA	a0, 9f;			\
	jal	_C_LABEL(panic);	\
	nop;				\
	MSG(msg)

#define	PRINTF(msg)			\
	PTR_LA	a0, 9f;			\
	jal	_C_LABEL(printf);	\
	nop;				\
	MSG(msg)

#define	MSG(msg)			\
	.rdata;				\
9:	.asciz	msg;			\
	.text

#define	ASMSTR(str)			\
	.asciz str;			\
	.align	3

#define	RCSID(x)	.pushsection ".ident","MS",@progbits,1;		\
			.asciz x;					\
			.popsection

/*
 * XXX retain dialects XXX
 */
#define	ALEAF(x)			XLEAF(x)
#define	NLEAF(x)			LEAF_NOPROFILE(x)
#define	NON_LEAF(x, fsize, retpc)	NESTED(x, fsize, retpc)
#define	NNON_LEAF(x, fsize, retpc)	NESTED_NOPROFILE(x, fsize, retpc)

#if defined(__mips_o32)
#define	SZREG	4
#else
#define	SZREG	8
#endif

#if defined(__mips_o32) || defined(__mips_o64)
#define	ALSK	7		/* stack alignment */
#define	ALMASK	-7		/* stack alignment */
#define	SZFPREG	4
#define	FP_L	lwc1
#define	FP_S	swc1
#else
#define	ALSK	15		/* stack alignment */
#define	ALMASK	-15		/* stack alignment */
#define	SZFPREG	8
#define	FP_L	ldc1
#define	FP_S	sdc1
#endif

/*
 *  standard callframe {
 *  	register_t cf_args[4];		arg0 - arg3 (only on o32 and o64)
 *	register_t cf_pad[N];		o32/64 (N=0), n32 (N=1) n64 (N=1)
 *  	register_t cf_gp;		global pointer (only on n32 and n64)
 *  	register_t cf_sp;		frame pointer
 *  	register_t cf_ra;		return address
 *  };
 */
#if defined(__mips_o32) || defined(__mips_o64)
#define	CALLFRAME_SIZ	(SZREG * (4 + 2))
#define	CALLFRAME_S0	0
#elif defined(__mips_n32) || defined(__mips_n64)
#define	CALLFRAME_SIZ	(SZREG * 4)
#define	CALLFRAME_S0	(CALLFRAME_SIZ - 4 * SZREG)
#endif
#ifndef _KERNEL
#define	CALLFRAME_GP	(CALLFRAME_SIZ - 3 * SZREG)
#endif
#define	CALLFRAME_SP	(CALLFRAME_SIZ - 2 * SZREG)
#define	CALLFRAME_RA	(CALLFRAME_SIZ - 1 * SZREG)

/*
 * While it would be nice to be compatible with the SGI
 * REG_L and REG_S macros, because they do not take parameters, it
 * is impossible to use them with the _MIPS_SIM_ABIX32 model.
 *
 * These macros hide the use of mips3 instructions from the
 * assembler to prevent the assembler from generating 64-bit style
 * ABI calls.
 */
#ifdef __mips_o32
#define	PTR_ADD		add
#define	PTR_ADDI	addi
#define	PTR_ADDU	addu
#define	PTR_ADDIU	addiu
#define	PTR_SUB		subu
#define	PTR_SUBI	subi
#define	PTR_SUBU	subu
#define	PTR_SUBIU	subu
#define	PTR_L		lw
#define	PTR_LA		la
#define	PTR_S		sw
#define	PTR_SLL		sll
#define	PTR_SLLV	sllv
#define	PTR_SRL		srl
#define	PTR_SRLV	srlv
#define	PTR_SRA		sra
#define	PTR_SRAV	srav
#define	PTR_LL		ll
#define	PTR_SC		sc
#define	PTR_WORD	.word
#define	PTR_SCALESHIFT	2
#else /* _MIPS_SZPTR == 64 */
#define	PTR_ADD		dadd
#define	PTR_ADDI	daddi
#define	PTR_ADDU	daddu
#define	PTR_ADDIU	daddiu
#define	PTR_SUB		dsubu
#define	PTR_SUBI	dsubi
#define	PTR_SUBU	dsubu
#define	PTR_SUBIU	dsubu
#ifdef __mips_n32
#define	PTR_L		lw
#define	PTR_LL		ll
#define	PTR_SC		sc
#define	PTR_S		sw
#define	PTR_SCALESHIFT	2
#define	PTR_WORD	.word
#else
#define	PTR_L		ld
#define	PTR_LL		lld
#define	PTR_SC		scd
#define	PTR_S		sd
#define	PTR_SCALESHIFT	3
#define	PTR_WORD	.dword
#endif
#define	PTR_LA		dla
#define	PTR_SLL		dsll
#define	PTR_SLLV	dsllv
#define	PTR_SRL		dsrl
#define	PTR_SRLV	dsrlv
#define	PTR_SRA		dsra
#define	PTR_SRAV	dsrav
#endif /* _MIPS_SZPTR == 64 */

#if _MIPS_SZINT == 32
#define	INT_ADD		add
#define	INT_ADDI	addi
#define	INT_ADDU	addu
#define	INT_ADDIU	addiu
#define	INT_SUB		subu
#define	INT_SUBI	subi
#define	INT_SUBU	subu
#define	INT_SUBIU	subu
#define	INT_L		lw
#define	INT_LA		la
#define	INT_S		sw
#define	INT_SLL		sll
#define	INT_SLLV	sllv
#define	INT_SRL		srl
#define	INT_SRLV	srlv
#define	INT_SRA		sra
#define	INT_SRAV	srav
#define	INT_LL		ll
#define	INT_SC		sc
#define	INT_WORD	.word
#define	INT_SCALESHIFT	2
#else
#define	INT_ADD		dadd
#define	INT_ADDI	daddi
#define	INT_ADDU	daddu
#define	INT_ADDIU	daddiu
#define	INT_SUB		dsubu
#define	INT_SUBI	dsubi
#define	INT_SUBU	dsubu
#define	INT_SUBIU	dsubu
#define	INT_L		ld
#define	INT_LA		dla
#define	INT_S		sd
#define	INT_SLL		dsll
#define	INT_SLLV	dsllv
#define	INT_SRL		dsrl
#define	INT_SRLV	dsrlv
#define	INT_SRA		dsra
#define	INT_SRAV	dsrav
#define	INT_LL		lld
#define	INT_SC		scd
#define	INT_WORD	.dword
#define	INT_SCALESHIFT	3
#endif

#if _MIPS_SZLONG == 32
#define	LONG_ADD	add
#define	LONG_ADDI	addi
#define	LONG_ADDU	addu
#define	LONG_ADDIU	addiu
#define	LONG_SUB	subu
#define	LONG_SUBI	subi
#define	LONG_SUBU	subu
#define	LONG_SUBIU	subu
#define	LONG_L		lw
#define	LONG_LA		la
#define	LONG_S		sw
#define	LONG_SLL	sll
#define	LONG_SLLV	sllv
#define	LONG_SRL	srl
#define	LONG_SRLV	srlv
#define	LONG_SRA	sra
#define	LONG_SRAV	srav
#define	LONG_LL		ll
#define	LONG_SC		sc
#define	LONG_WORD	.word
#define	LONG_SCALESHIFT	2
#else
#define	LONG_ADD	dadd
#define	LONG_ADDI	daddi
#define	LONG_ADDU	daddu
#define	LONG_ADDIU	daddiu
#define	LONG_SUB	dsubu
#define	LONG_SUBI	dsubi
#define	LONG_SUBU	dsubu
#define	LONG_SUBIU	dsubu
#define	LONG_L		ld
#define	LONG_LA		dla
#define	LONG_S		sd
#define	LONG_SLL	dsll
#define	LONG_SLLV	dsllv
#define	LONG_SRL	dsrl
#define	LONG_SRLV	dsrlv
#define	LONG_SRA	dsra
#define	LONG_SRAV	dsrav
#define	LONG_LL		lld
#define	LONG_SC		scd
#define	LONG_WORD	.dword
#define	LONG_SCALESHIFT	3
#endif

#if SZREG == 4
#define	REG_L		lw
#define	REG_S		sw
#define	REG_LI		li
#define	REG_ADDU	addu
#define	REG_SLL		sll
#define	REG_SLLV	sllv
#define	REG_SRL		srl
#define	REG_SRLV	srlv
#define	REG_SRA		sra
#define	REG_SRAV	srav
#define	REG_LL		ll
#define	REG_SC		sc
#define	REG_SCALESHIFT	2
#else
#define	REG_L		ld
#define	REG_S		sd
#define	REG_LI		dli
#define	REG_ADDU	daddu
#define	REG_SLL		dsll
#define	REG_SLLV	dsllv
#define	REG_SRL		dsrl
#define	REG_SRLV	dsrlv
#define	REG_SRA		dsra
#define	REG_SRAV	dsrav
#define	REG_LL		lld
#define	REG_SC		scd
#define	REG_SCALESHIFT	3
#endif

#if (MIPS1 + MIPS2) > 0
#define	NOP_L		nop
#else
#define	NOP_L		/* nothing */
#endif

/* compiler define */
#if defined(__OCTEON__)
/*
 * See common/lib/libc/arch/mips/atomic/membar_ops.S for notes on
 * Octeon memory ordering guarantees and barriers.
 *
 * cnMIPS also has a quirk where the store buffer can get clogged and
 * we need to apply a plunger to it _after_ releasing a lock or else
 * other CPUs may spin for hundreds of thousands of cycles before they
 * see the lock is released.  So we also have the quirky SYNC_PLUNGER
 * barrier as syncw.
 */
#define	LLSCSYNC	/* nothing */
#define	BDSYNC		sync
#define	BDSYNC_ACQ	nop
#define	SYNC_ACQ	/* nothing */
#define	SYNC_REL	sync 4
#define	BDSYNC_PLUNGER	sync 4
#define	SYNC_PLUNGER	sync 4
#elif __mips >= 3 || !defined(__mips_o32)
#define	LLSCSYNC	/* nothing */
#define	BDSYNC		sync
#define	BDSYNC_ACQ	sync
#define	SYNC_ACQ	sync
#define	SYNC_REL	sync
#define	BDSYNC_PLUNGER	nop
#define	SYNC_PLUNGER	/* nothing */
#else
#define	LLSCSYNC	/* nothing */
#define	BDSYNC		nop
#define	BDSYNC_ACQ	nop
#define	SYNC_ACQ	/* nothing */
#define	SYNC_REL	/* nothing */
#define	BDSYNC_PLUNGER	nop
#define	SYNC_PLUNGER	/* nothing */
#endif

/*
 * Store-before-load barrier.  Do not use this unless you know what
 * you're doing.
 */
#ifdef MULTIPROCESSOR
#define	SYNC_DEKKER	sync
#else
#define	SYNC_DEKKER	/* nothing */
#endif

/*
 * Store-before-store and load-before-load barriers.  These could be
 * made weaker than release (load/store-before-store) and acquire
 * (load-before-load/store) barriers, and newer MIPS does have
 * instruction encodings for finer-grained barriers like this, but I
 * dunno how to appropriately conditionalize their use or get the
 * assembler to be happy with them, so we'll use these definitions for
 * now.
 */
#define	SYNC_PRODUCER	SYNC_REL
#define	SYNC_CONSUMER	SYNC_ACQ

/* CPU dependent hook for cp0 load delays */
#if defined(MIPS1) || defined(MIPS2) || defined(MIPS3)
#define	MFC0_HAZARD	sll $0,$0,1	/* super scalar nop */
#else
#define	MFC0_HAZARD	/* nothing */
#endif

#if _MIPS_ISA == _MIPS_ISA_MIPS1 || _MIPS_ISA == _MIPS_ISA_MIPS2 || \
    _MIPS_ISA == _MIPS_ISA_MIPS32
#define	MFC0		mfc0
#define	MTC0		mtc0
#endif
#if _MIPS_ISA == _MIPS_ISA_MIPS3 || _MIPS_ISA == _MIPS_ISA_MIPS4 || \
    _MIPS_ISA == _MIPS_ISA_MIPS64
#define	MFC0		dmfc0
#define	MTC0		dmtc0
#endif

#if defined(__mips_o32) || defined(__mips_o64)

#ifdef __mips_abicalls
#define	CPRESTORE(r)	.cprestore r
#define	CPLOAD(r)	.cpload r
#else
#define	CPRESTORE(r)	/* not needed */
#define	CPLOAD(r)	/* not needed */
#endif

#define	SETUP_GP	\
			.set push;				\
			.set noreorder;				\
			.cpload	t9;				\
			.set pop
#define	SETUP_GPX(r)	\
			.set push;				\
			.set noreorder;				\
			move	r,ra;	/* save old ra */	\
			bal	7f;				\
			nop;					\
		7:	.cpload	ra;				\
			move	ra,r;				\
			.set pop
#define	SETUP_GPX_L(r,lbl)	\
			.set push;				\
			.set noreorder;				\
			move	r,ra;	/* save old ra */	\
			bal	lbl;				\
			nop;					\
		lbl:	.cpload	ra;				\
			move	ra,r;				\
			.set pop
#define	SAVE_GP(x)	.cprestore x

#define	SETUP_GP64(a,b)		/* n32/n64 specific */
#define	SETUP_GP64_R(a,b)	/* n32/n64 specific */
#define	SETUP_GPX64(a,b)	/* n32/n64 specific */
#define	SETUP_GPX64_L(a,b,c)	/* n32/n64 specific */
#define	RESTORE_GP64		/* n32/n64 specific */
#define	USE_ALT_CP(a)		/* n32/n64 specific */
#endif /* __mips_o32 || __mips_o64 */

#if defined(__mips_o32) || defined(__mips_o64)
#define	REG_PROLOGUE	.set push
#define	REG_EPILOGUE	.set pop
#endif
#if defined(__mips_n32) || defined(__mips_n64)
#define	REG_PROLOGUE	.set push ; .set mips3
#define	REG_EPILOGUE	.set pop
#endif

#if defined(__mips_n32) || defined(__mips_n64)
#define	SETUP_GP		/* o32 specific */
#define	SETUP_GPX(r)		/* o32 specific */
#define	SETUP_GPX_L(r,lbl)	/* o32 specific */
#define	SAVE_GP(x)		/* o32 specific */
#define	SETUP_GP64(a,b)		.cpsetup t9, a, b
#define	SETUP_GPX64(a,b)	\
				.set push;			\
				move	b,ra;			\
				.set noreorder;			\
				bal	7f;			\
				nop;				\
			7:	.set pop;			\
				.cpsetup ra, a, 7b;		\
				move	ra,b
#define	SETUP_GPX64_L(a,b,c)	\
				.set push;			\
				move	b,ra;			\
				.set noreorder;			\
				bal	c;			\
				nop;				\
			c:	.set pop;			\
				.cpsetup ra, a, c;		\
				move	ra,b
#define	RESTORE_GP64		.cpreturn
#define	USE_ALT_CP(a)		.cplocal a
#endif	/* __mips_n32 || __mips_n64 */

/*
 * The DYNAMIC_STATUS_MASK option adds an additional masking operation
 * when updating the hardware interrupt mask in the status register.
 *
 * This is useful for platforms that need to at run-time mask
 * interrupts based on motherboard configuration or to handle
 * slowly clearing interrupts.
 *
 * XXX this is only currently implemented for mips3.
 */
#ifdef MIPS_DYNAMIC_STATUS_MASK
#define	DYNAMIC_STATUS_MASK(sr,scratch)	\
	lw	scratch, mips_dynamic_status_mask; \
	and	sr, sr, scratch

#define	DYNAMIC_STATUS_MASK_TOUSER(sr,scratch1)		\
	ori	sr, (MIPS_INT_MASK | MIPS_SR_INT_IE);	\
	DYNAMIC_STATUS_MASK(sr,scratch1)
#else
#define	DYNAMIC_STATUS_MASK(sr,scratch)
#define	DYNAMIC_STATUS_MASK_TOUSER(sr,scratch1)
#endif

/* See lock_stubs.S. */
#define	LOG2_MIPS_LOCK_RAS_SIZE	8
#define	MIPS_LOCK_RAS_SIZE	256	/* 16 bytes left over */

#define	CPUVAR(off) _C_LABEL(cpu_info_store)+__CONCAT(CPU_INFO_,off)

#endif /* _MIPS_ASM_H */