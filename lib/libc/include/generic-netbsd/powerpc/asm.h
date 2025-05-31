/*	$NetBSD: asm.h,v 1.53 2022/01/07 22:59:32 andvar Exp $	*/

/*
 * Copyright (C) 1995, 1996 Wolfgang Solfrank.
 * Copyright (C) 1995, 1996 TooLs GmbH.
 * All rights reserved.
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
 *	This product includes software developed by TooLs GmbH.
 * 4. The name of TooLs GmbH may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY TOOLS GMBH ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL TOOLS GMBH BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _PPC_ASM_H_
#define _PPC_ASM_H_

#ifdef _LP64

/* ppc64 is always PIC, r2 is always the TOC */

# define PIC_PLT(x)	.x

#else

# ifdef __PIC__
#  define PIC_PROLOGUE	XXX
#  define PIC_EPILOGUE	XXX
#  define PIC_PLT(x)	x+32768@plt
#  ifdef __STDC__
#   define PIC_TOCNAME(name) 	.LCTOC_##name
#  else
#   define PIC_TOCNAME(name) 	.LCTOC_/**/name
#  endif /* __STDC __*/
#  define PIC_TOCSETUP(name, reg)						\
		.pushsection ".got2","aw"				;\
	PIC_TOCNAME(name) = . + 32768					;\
		.popsection						;\
		bcl	20,31,1001f					;\
	1001:	mflr	reg						;\
		addis	reg,reg,PIC_TOCNAME(name)-1001b@ha		;\
		addi	reg,reg,PIC_TOCNAME(name)-1001b@l
#  define PIC_GOTSETUP(reg)						\
		bcl	20,31,2002f					;\
	2002:	mflr	reg						;\
		addis	reg,reg,_GLOBAL_OFFSET_TABLE_-2002b@ha		;\
		addi	reg,reg,_GLOBAL_OFFSET_TABLE_-2002b@l
#  ifdef __STDC__
#   define PIC_GOT(x)	XXX
#   define PIC_GOTOFF(x)	XXX
#  else	/* not __STDC__ */
#   define PIC_GOT(x)	XXX
#   define PIC_GOTOFF(x)	XXX
#  endif /* __STDC__ */
# else /* !__PIC__ */
#  define PIC_PROLOGUE
#  define PIC_EPILOGUE
#  define PIC_PLT(x)	x
#  define PIC_GOT(x)	x
#  define PIC_GOTOFF(x)	x
#  define PIC_GOTSETUP(r)
#  define PIC_TOCSETUP(n, r)
# endif /* __PIC__ */

#endif /* _LP64 */

#define	_C_LABEL(x)	x
#define	_ASM_LABEL(x)	x

#define	_GLOBAL(x) \
	.data; .align 2; .globl x; x:

#ifdef GPROF
# define _PROF_PROLOGUE	mflr 0; stw 0,4(1); bl _mcount
#else
# define _PROF_PROLOGUE
#endif

#ifdef _LP64

# define SF_HEADER_SZ	48
# define SF_PARAM_SZ	64
# define SF_SZ		(SF_HEADER_SZ + SF_PARAM_SZ)

# define SF_SP		 0
# define SF_CR		 8
# define SF_LR		16
# define SF_COMP	24
# define SF_LD		32
# define SF_TOC		40
# define SF_PARAM	SF_HEADER_SZ
# define SF_ALIGN(x)	(((x) + 0xf) & ~0xf)

# define _XENTRY(y)			\
	.globl	y;			\
	.pushsection ".opd","aw";	\
	.align	3;			\
y:	.quad	.##y,.TOC.@tocbase,0;	\
	.popsection;			\
	.size	y,24;			\
	.type	.##y,@function;		\
	.globl	.##y;			\
	.align	3;			\
.##y:

#define _ENTRY(x)	.text; _XENTRY(x)

# define ENTRY(y) _ENTRY(y)

# define END(y)	.size .##y,. - .##y

# define CALL(y)			\
	bl	.y;			\
	nop

# define ENTRY_NOPROFILE(y)	ENTRY(y)
# define ASENTRY(y)		ENTRY(y)
#else /* !_LP64 */

# define _XENTRY(x)	.align 2; .globl x; .type x,@function; x:
# define _ENTRY(x)	.text; _XENTRY(x)

# define ENTRY(y)	_ENTRY(_C_LABEL(y)); _PROF_PROLOGUE

# define END(y)		.size _C_LABEL(y),.-_C_LABEL(y)

# define CALL(y)			\
	bl	y

# define ENTRY_NOPROFILE(y) _ENTRY(_C_LABEL(y))
# define ASENTRY(y)	_ENTRY(_ASM_LABEL(y)); _PROF_PROLOGUE
#endif /* _LP64 */

#define	GLOBAL(y)	_GLOBAL(_C_LABEL(y))

#define	ASMSTR		.asciz

#undef __RCSID
#define RCSID(x)	__RCSID(x)
#define __RCSID(x)	.pushsection ".ident","MS",@progbits,1;		\
			.asciz x;					\
			.popsection

#ifdef __ELF__
# define WEAK_ALIAS(alias,sym)						\
	.weak alias;							\
	alias = sym
#endif /* __ELF__ */
/*
 * STRONG_ALIAS: create a strong alias.
 */
#define STRONG_ALIAS(alias,sym)						\
	.globl alias;							\
	alias = sym

#ifdef __STDC__
# define WARN_REFERENCES(sym,msg)					\
	.pushsection .gnu.warning. ## sym;				\
	.ascii msg;							\
	.popsection
#else
# define WARN_REFERENCES(sym,msg)					\
	.pushsection .gnu.warning./**/sym;				\
	.ascii msg;							\
	.popsection
#endif /* __STDC__ */

#ifdef _KERNEL
/*
 * Get cpu_info pointer for current processor.  Always in SPRG0. *ALWAYS*
 */
# define GET_CPUINFO(r)		mfsprg r,0
/*
 * IN:
 *	R4[er] = first free byte beyond end/esym.
 *
 * OUT:
 *	R1[sp] = new kernel stack
 *	R4[er] = kernelend
 */

# ifdef CI_INTSTK
#  define INIT_CPUINFO_INTSTK(er,tmp1)					\
	addis	er,er,INTSTK@ha;					\
	addi	er,er,INTSTK@l;						\
	stptr	er,CI_INTSTK(tmp1)
# else
#  define INIT_CPUINFO_INTSTK(er,tmp1)	/* nothing */
# endif /* CI_INTSTK */

/*
 * We use lis/ori instead of lis/addi in case tmp2 is r0.
 */
# define INIT_CPUINFO(er,sp,tmp1,tmp2) 					\
	li	tmp1,PAGE_MASK;						\
	add	er,er,tmp1;						\
	andc	er,er,tmp1;		/* page align */		\
	lis	tmp1,_C_LABEL(cpu_info)@ha;				\
	addi	tmp1,tmp1,_C_LABEL(cpu_info)@l;				\
	mtsprg0	tmp1;			/* save for later use */	\
	INIT_CPUINFO_INTSTK(er,tmp1);					\
	lis	tmp2,_C_LABEL(emptyidlespin)@h;				\
	ori	tmp2,tmp2,_C_LABEL(emptyidlespin)@l;			\
	stptr	tmp2,CI_IDLESPIN(tmp1);					\
	li	tmp2,-1;						\
	stint	tmp2,CI_IDEPTH(tmp1);					\
	li	tmp2,0;							\
	lis	%r13,_C_LABEL(lwp0)@h;					\
	ori	%r13,%r13,_C_LABEL(lwp0)@l;				\
	stptr	er,L_PCB(%r13);		/* XXXuvm_lwp_getuarea */	\
	stptr	tmp1,L_CPU(%r13);	 				\
	addis	er,er,USPACE@ha;	/* stackpointer for lwp0 */	\
	addi	er,er,USPACE@l;		/* stackpointer for lwp0 */	\
	addi	sp,er,-FRAMELEN-CALLFRAMELEN;	/* stackpointer for lwp0 */ \
	stptr	sp,L_MD_UTF(%r13);	/* save in lwp0.l_md.md_utf */	\
		/* er = end of mem reserved for kernel */		\
	li	tmp2,0;							\
	stptr	tmp2,-CALLFRAMELEN(er);	/* end of stack chain */	\
	stptru	tmp2,-CALLFRAMELEN(sp)	/* end of stack chain */

#endif /* _KERNEL */


#if defined(_REGNAMES) && (defined(_KERNEL) || defined(_STANDALONE))
  /* Condition Register Bit Fields */
# define cr0	 0
# define cr1	 1
# define cr2	 2
# define cr3	 3
# define cr4	 4
# define cr5	 5
# define cr6	 6
# define cr7	 7
  /* General Purpose Registers (GPRs) */
# define r0	 0
# define r1	 1
# define r2	 2
# define r3	 3
# define r4	 4
# define r5	 5
# define r6	 6
# define r7	 7
# define r8	 8
# define r9	 9
# define r10	10
# define r11	11
# define r12	12
# define r13	13
# define r14	14
# define r15	15
# define r16	16
# define r17	17
# define r18	18
# define r19	19
# define r20	20
# define r21	21
# define r22	22
# define r23	23
# define r24	24
# define r25	25
# define r26	26
# define r27	27
# define r28	28
# define r29	29
# define r30	30
# define r31	31
  /* Floating Point Registers (FPRs) */
# define fr0	 0
# define fr1	 1
# define fr2	 2
# define fr3	 3
# define fr4	 4
# define fr5	 5
# define fr6	 6
# define fr7	 7
# define fr8	 8
# define fr9	 9
# define fr10	10
# define fr11	11
# define fr12	12
# define fr13	13
# define fr14	14
# define fr15	15
# define fr16	16
# define fr17	17
# define fr18	18
# define fr19	19
# define fr20	20
# define fr21	21
# define fr22	22
# define fr23	23
# define fr24	24
# define fr25	25
# define fr26	26
# define fr27	27
# define fr28	28
# define fr29	29
# define fr30	30
# define fr31	31
#endif /* _REGNAMES && (_KERNEL || _STANDALONE) */

/*
 * Add some psuedo instructions to made sharing of assembly versions of
 * ILP32 and LP64 code possible.
 */
#define ldint		lwz	/* not needed but for completeness */
#define ldintu		lwzu	/* not needed but for completeness */
#define stint		stw	/* not needed but for completeness */
#define stintu		stwu	/* not needed but for completeness */

#ifndef _LP64

# define ldlong		lwz	/* load "C" long */
# define ldlongu	lwzu	/* load "C" long with update */
# define stlong		stw	/* load "C" long */
# define stlongu	stwu	/* load "C" long with update */
# define ldptr		lwz	/* load "C" pointer */
# define ldptru		lwzu	/* load "C" pointer with update */
# define stptr		stw	/* load "C" pointer */
# define stptru		stwu	/* load "C" pointer with update */
# define ldreg		lwz	/* load PPC general register */
# define ldregu		lwzu	/* load PPC general register with update */
# define streg		stw	/* load PPC general register */
# define stregu		stwu	/* load PPC general register with update */
# define SZREG		4	/* 4 byte registers */
# define P2SZREG	2

# define lptrarx	lwarx	/* load "C" pointer with reservation */
# define llongarx	lwarx	/* load "C" long with reservation */
# define lregarx	lwarx	/* load PPC general register with reservation */

# define stptrcx	stwcx	/* store "C" pointer conditional */
# define stlongcx	stwcx	/* store "C" long conditional */
# define stregcx	stwcx	/* store PPC general register conditional */

# define clrrptri	clrrwi	/* clear right "C" pointer immediate */
# define clrrlongi	clrrwi	/* clear right "C" long immediate */
# define clrrregi	clrrwi	/* clear right PPC general register immediate */

# define cmpptr		cmpw
# define cmplong	cmpw
# define cmpreg		cmpw
# define cmpptri	cmpwi
# define cmplongi	cmpwi
# define cmpregi	cmpwi
# define cmpptrl	cmplw
# define cmplongl	cmplw
# define cmpregl	cmplw
# define cmpptrli	cmplwi
# define cmplongli	cmplwi
# define cmpregli	cmplwi

#else /* _LP64 */

# define ldlong		ld	/* load "C" long */
# define ldlongu	ldu	/* load "C" long with update */
# define stlong		std	/* store "C" long */
# define stlongu	stdu	/* store "C" long with update */
# define ldptr		ld	/* load "C" pointer */
# define ldptru		ldu	/* load "C" pointer with update */
# define stptr		std	/* store "C" pointer */
# define stptru		stdu	/* store "C" pointer with update */
# define ldreg		ld	/* load PPC general register */
# define ldregu		ldu	/* load PPC general register with update */
# define streg		std	/* store PPC general register */
# define stregu		stdu	/* store PPC general register with update */
/* redefined this to force an error on PPC64 to catch their use.  */
# define lmw		lmd	/* load multiple PPC general registers */
# define stmw		stmd	/* store multiple PPC general registers */
# define SZREG		8	/* 8 byte registers */
# define P2SZREG	3

# define lptrarx	ldarx	/* load "C" pointer with reservation */
# define llongarx	ldarx	/* load "C" long with reservation */
# define lregarx	ldarx	/* load PPC general register with reservation */

# define stptrcx	stdcx	/* store "C" pointer conditional */
# define stlongcx	stdcx	/* store "C" long conditional */
# define stregax	stdcx	/* store PPC general register conditional */

# define clrrptri	clrrdi	/* clear right "C" pointer immediate */
# define clrrlongi	clrrdi	/* clear right "C" long immediate */
# define clrrregi	clrrdi	/* clear right PPC general register immediate */

# define cmpptr		cmpd
# define cmplong	cmpd
# define cmpreg		cmpd
# define cmpptri	cmpdi
# define cmplongi	cmpdi
# define cmpregi	cmpdi
# define cmpptrl	cmpld
# define cmplongl	cmpld
# define cmpregl	cmpld
# define cmpptrli	cmpldi
# define cmplongli	cmpldi
# define cmpregli	cmpldi

#endif /* _LP64 */

#ifdef _LOCORE
.macro	stmd	r,dst
	i = 0
    .rept	32-\r
	std	i+\r, i*8+\dst
	i = i + 1
    .endr
.endm

.macro	lmd	r,dst
	i = 0
    .rept	32-\r
	ld	i+\r, i*8+\dst
	i = i + 1
    .endr
.endm
#endif /* _LOCORE */

#if defined(IBM405_ERRATA77) || \
    ((defined(_MODULE) || !defined(_KERNEL)) && !defined(_LP64))
/*
 * Workaround for IBM405 Errata 77 (CPU_210): interrupted stwcx. may
 * errantly write data to memory
 *
 * (1) Insert dcbt before every stwcx. instruction
 * (2) Insert sync before every rfi/rfci instruction
 */
#define	IBM405_ERRATA77_DCBT(ra, rb)	dcbt ra,rb
#define	IBM405_ERRATA77_SYNC		sync
#else
#define	IBM405_ERRATA77_DCBT(ra, rb)	/* nothing */
#define	IBM405_ERRATA77_SYNC		/* nothing */
#endif

#endif /* !_PPC_ASM_H_ */