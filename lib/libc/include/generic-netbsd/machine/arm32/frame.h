/*	$NetBSD: frame.h,v 1.48 2020/08/14 16:18:36 skrll Exp $	*/

/*
 * Copyright (c) 1994-1997 Mark Brinicombe.
 * Copyright (c) 1994 Brini.
 * All rights reserved.
 *
 * This code is derived from software written for Brini by Mark Brinicombe
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
 *	This product includes software developed by Brini.
 * 4. The name of the company nor the name of the author may be used to
 *    endorse or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRINI ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL BRINI OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * RiscBSD kernel project
 *
 * frame.h
 *
 * Stack frames structures
 *
 * Created      : 30/09/94
 */

#ifndef _ARM32_FRAME_H_
#define _ARM32_FRAME_H_

#include <arm/frame.h>		/* Common ARM stack frames */

#ifndef _LOCORE

/*
 * Switch frame.
 *
 * Should be a multiple of 8 bytes for dumpsys.
 */

struct switchframe {
	u_int	sf_r4;
	u_int	sf_r5;
	u_int	sf_r6;
	u_int	sf_r7;
	u_int	sf_sp;
	u_int	sf_pc;
};

/*
 * System stack frames.
 */

struct clockframe {
	struct trapframe cf_tf;
};

/*
 * Stack frame. Used during stack traces (db_trace.c)
 */
struct frame {
	u_int	fr_fp;
	u_int	fr_sp;
	u_int	fr_lr;
	u_int	fr_pc;
};

#ifdef _KERNEL
void validate_trapframe(trapframe_t *, int);
#endif /* _KERNEL */

#else /* _LOCORE */

#include "opt_compat_netbsd.h"
#include "opt_execfmt.h"
#include "opt_multiprocessor.h"
#include "opt_cpuoptions.h"
#include "opt_arm_debug.h"
#include "opt_cputypes.h"
#include "opt_dtrace.h"

#include <arm/locore.h>

/*
 * This macro is used by DO_AST_AND_RESTORE_ALIGNMENT_FAULTS to process
 * any pending softints.
 */
#ifdef _ARM_ARCH_4T
#define	B_CF_CONTROL(rX)						;\
	ldr	ip, [rX, #CF_CONTROL]	/* get function addr */		;\
	bx	ip			/* branch to cpu_control */
#else
#define	B_CF_CONTROL(rX)						;\
	ldr	pc, [rX, #CF_CONTROL]	/* branch to cpu_control */
#endif
#ifdef _ARM_ARCH_5T
#define	BL_CF_CONTROL(rX)						;\
	ldr	ip, [rX, #CF_CONTROL]	/* get function addr */		;\
	blx	ip			/* call cpu_control */
#else
#define	BL_CF_CONTROL(rX)						;\
	mov	lr, pc							;\
	ldr	pc, [rX, #CF_CONTROL]	/* call cpu_control */
#endif
#if defined(__HAVE_FAST_SOFTINTS) && !defined(__HAVE_PIC_FAST_SOFTINTS)
#define	DO_PENDING_SOFTINTS						\
	ldr	r0, [r4, #CI_INTR_DEPTH]/* Get current intr depth */	;\
	cmp	r0, #0			/* Test for 0. */		;\
	bne	10f			/*   skip softints if != 0 */	;\
	ldr	r0, [r4, #CI_CPL]	/* Get current priority level */;\
	ldr	r1, [r4, #CI_SOFTINTS]	/* Get pending softint mask */	;\
	lsrs	r0, r1, r0		/* shift mask by cpl */		;\
	blne	_C_LABEL(dosoftints)	/* dosoftints(void) */		;\
10:
#else
#define	DO_PENDING_SOFTINTS		/* nothing */
#endif

#ifdef _ARM_ARCH_6
#define	GET_CPSR(rb)			/* nothing */
#define	CPSID_I(ra,rb)			cpsid	i
#define	CPSIE_I(ra,rb)			cpsie	i
#else
#define	GET_CPSR(rb)							\
	mrs	rb, cpsr		/* fetch CPSR */

#define	CPSID_I(ra,rb)							\
	orr	ra, rb, #(IF32_bits)					;\
	msr	cpsr_c, ra		/* Disable interrupts */

#define	CPSIE_I(ra,rb)							\
	bic	ra, rb, #(IF32_bits)					;\
	msr	cpsr_c, ra		/* Restore interrupts */
#endif

#define DO_PENDING_AST(lbl)						;\
1:	ldr	r1, [r5, #L_MD_ASTPENDING] /* Pending AST? */		;\
	tst	r1, #1							;\
	beq	lbl			/* Nope. Just bail */		;\
	bic	r0, r1, #1		 /* clear AST */		;\
	str	r0, [r5, #L_MD_ASTPENDING]				;\
	CPSIE_I(r6, r6)			/* Restore interrupts */	;\
	mov	r0, sp							;\
	bl	_C_LABEL(ast)		/* ast(frame) */		;\
	CPSID_I(r0, r6)			/* Disable interrupts */	;\
	b	1b			/* test again */

/*
 * AST_ALIGNMENT_FAULT_LOCALS and ENABLE_ALIGNMENT_FAULTS
 * These are used in order to support dynamic enabling/disabling of
 * alignment faults when executing old a.out ARM binaries.
 *
 * Note that when ENABLE_ALIGNMENTS_FAULTS finishes r4 will contain
 * curcpu() and r5 containing curlwp.  DO_AST_AND_RESTORE_ALIGNMENT_FAULTS
 * relies on r4 and r5 being preserved.
 */
#ifdef EXEC_AOUT
#define	AST_ALIGNMENT_FAULT_LOCALS					\
.Laflt_cpufuncs:							;\
	.word	_C_LABEL(cpufuncs)

/*
 * This macro must be invoked following PUSHFRAMEINSVC or PUSHFRAME at
 * the top of interrupt/exception handlers.
 *
 * When invoked, r0 *must* contain the value of SPSR on the current
 * trap/interrupt frame. This is always the case if ENABLE_ALIGNMENT_FAULTS
 * is invoked immediately after PUSHFRAMEINSVC or PUSHFRAME.
 */
#define	ENABLE_ALIGNMENT_FAULTS						\
	and	r7, r0, #(PSR_MODE)	/* Test for USR32 mode */	;\
	cmp	r7, #(PSR_USR32_MODE)					;\
	GET_CURX(r4, r5)		/* r4 = curcpu, r5 = curlwp */	;\
	bne	1f			/* Not USR mode skip AFLT */	;\
	ldr	r1, [r5, #L_MD_FLAGS]	/* Fetch l_md.md_flags */	;\
	tst	r1, #MDLWP_NOALIGNFLT					;\
	beq	1f			/* AFLTs already enabled */	;\
	ldr	r2, .Laflt_cpufuncs					;\
	ldr	r1, [r4, #CI_CTRL]	/* Fetch control register */	;\
	mov	r0, #-1							;\
	BL_CF_CONTROL(r2)		/* Enable alignment faults */	;\
1:	/* done */

/*
 * This macro must be invoked just before PULLFRAMEFROMSVCANDEXIT or
 * PULLFRAME at the end of interrupt/exception handlers.  We know that
 * r4 points to curcpu() and r5 points to curlwp since that is what
 * ENABLE_ALIGNMENT_FAULTS did for us.
 */
#define	DO_AST_AND_RESTORE_ALIGNMENT_FAULTS				\
	DO_PENDING_SOFTINTS						;\
	GET_CPSR(r6)			/* save CPSR */			;\
	CPSID_I(r1, r6)			/* Disable interrupts */	;\
	cmp	r7, #(PSR_USR32_MODE)	/* Returning to USR mode? */	;\
	bne	3f			/* Nope, get out now */		;\
	DO_PENDING_AST(2f)		/* Pending AST? */		;\
2:	ldr	r1, [r4, #CI_CURLWP]	/* get curlwp from cpu_info */	;\
	ldr	r0, [r1, #L_MD_FLAGS]	/* get md_flags from lwp */	;\
	tst	r0, #MDLWP_NOALIGNFLT					;\
	beq	3f			/* Keep AFLTs enabled */	;\
	ldr	r1, [r4, #CI_CTRL]	/* Fetch control register */	;\
	ldr	r2, .Laflt_cpufuncs					;\
	mov	r0, #-1							;\
	bic	r1, r1, #CPU_CONTROL_AFLT_ENABLE  /* Disable AFLTs */	;\
	BL_CF_CONTROL(r2)		/* Set new CTRL reg value */	;\
3:	/* done */

#else	/* !EXEC_AOUT */

#define	AST_ALIGNMENT_FAULT_LOCALS

#define	ENABLE_ALIGNMENT_FAULTS						\
	and	r7, r0, #(PSR_MODE)	/* Test for USR32 mode */	;\
	GET_CURX(r4, r5)		/* r4 = curcpu, r5 = curlwp */


#define	DO_AST_AND_RESTORE_ALIGNMENT_FAULTS				\
	DO_PENDING_SOFTINTS						;\
	GET_CPSR(r6)			/* save CPSR */			;\
	CPSID_I(r1, r6)			/* Disable interrupts */	;\
	cmp	r7, #(PSR_USR32_MODE)					;\
	bne	2f			/* Nope, get out now */		;\
	DO_PENDING_AST(2f)		/* Pending AST? */		;\
2:	/* done */
#endif /* EXEC_AOUT */

#ifndef _ARM_ARCH_6
#ifdef ARM_LOCK_CAS_DEBUG
#define	LOCK_CAS_DEBUG_LOCALS						 \
.L_lock_cas_restart:							;\
	.word	_C_LABEL(_lock_cas_restart)

#if defined(__ARMEB__)
#define	LOCK_CAS_DEBUG_COUNT_RESTART					 \
	ble	99f							;\
	ldr	r0, .L_lock_cas_restart					;\
	ldmia	r0, {r1-r2}		/* load ev_count */		;\
	adds	r2, r2, #1		/* 64-bit incr (lo) */		;\
	adc	r1, r1, #0		/* 64-bit incr (hi) */		;\
	stmia	r0, {r1-r2}		/* store ev_count */
#else /* __ARMEB__ */
#define	LOCK_CAS_DEBUG_COUNT_RESTART					 \
	ble	99f							;\
	ldr	r0, .L_lock_cas_restart					;\
	ldmia	r0, {r1-r2}		/* load ev_count */		;\
	adds	r1, r1, #1		/* 64-bit incr (lo) */		;\
	adc	r2, r2, #0		/* 64-bit incr (hi) */		;\
	stmia	r0, {r1-r2}		/* store ev_count */
#endif /* __ARMEB__ */
#else /* ARM_LOCK_CAS_DEBUG */
#define	LOCK_CAS_DEBUG_LOCALS		/* nothing */
#define	LOCK_CAS_DEBUG_COUNT_RESTART	/* nothing */
#endif /* ARM_LOCK_CAS_DEBUG */

#define	LOCK_CAS_CHECK_LOCALS						 \
.L_lock_cas:								;\
	.word	_C_LABEL(_lock_cas)					;\
.L_lock_cas_end:							;\
	.word	_C_LABEL(_lock_cas_end)					;\
LOCK_CAS_DEBUG_LOCALS

#define	LOCK_CAS_CHECK							 \
	ldr	r0, [sp]		/* get saved PSR */		;\
	and	r0, r0, #(PSR_MODE)	/* check for SVC32 mode */	;\
	cmp	r0, #(PSR_SVC32_MODE)					;\
	bne	99f			/* nope, get out now */		;\
	ldr	r0, [sp, #(TF_PC)]					;\
	ldr	r1, .L_lock_cas_end					;\
	cmp	r0, r1							;\
	bge	99f							;\
	ldr	r1, .L_lock_cas						;\
	cmp	r0, r1							;\
	strgt	r1, [sp, #(TF_PC)]					;\
	LOCK_CAS_DEBUG_COUNT_RESTART					;\
99:

#else
#define	LOCK_CAS_CHECK			/* nothing */
#define	LOCK_CAS_CHECK_LOCALS		/* nothing */
#endif

/*
 * ASM macros for pushing and pulling trapframes from the stack
 *
 * These macros are used to handle the trapframe structure defined above.
 */

/*
 * PUSHFRAME - macro to push a trap frame on the stack in the current mode
 * Since the current mode is used, the SVC lr field is not defined.
 */

#ifdef CPU_SA110
/*
 * NOTE: r13 and r14 are stored separately as a work around for the
 * SA110 rev 2 STM^ bug
 */
#define	PUSHUSERREGS							   \
	stmia	sp, {r0-r12};		/* Push the user mode registers */ \
	add	r0, sp, #(TF_USR_SP-TF_R0); /* Adjust the stack pointer */ \
	stmia	r0, {r13-r14}^		/* Push the user mode registers */
#else
#define	PUSHUSERREGS							   \
	stmia	sp, {r0-r14}^		/* Push the user mode registers */
#endif

#define PUSHFRAME							   \
	str	lr, [sp, #-4]!;		/* Push the return address */	   \
	sub	sp, sp, #(TF_PC-TF_R0);	/* Adjust the stack pointer */	   \
	PUSHUSERREGS;			/* Push the user mode registers */ \
	mov     r0, r0;                 /* NOP for previous instruction */ \
	mrs	r0, spsr;		/* Get the SPSR */		   \
	str	r0, [sp, #-TF_R0]!	/* Push the SPSR on the stack */

/*
 * Push a minimal trapframe so we can dispatch an interrupt from the
 * idle loop.  The only reason the idle loop wakes up is to dispatch
 * interrupts so why take the avoid of a full exception when we can do
 * something minimal.
 */
#define PUSHIDLEFRAME							   \
	str	lr, [sp, #-4]!;		/* save SVC32 lr */		   \
	str	r6, [sp, #(TF_R6-TF_PC)]!; /* save callee-saved r6 */	   \
	str	r4, [sp, #(TF_R4-TF_R6)]!; /* save callee-saved r4 */	   \
	mrs	r0, cpsr;		/* Get the CPSR */		   \
	str	r0, [sp, #(-TF_R4)]!	/* Push the CPSR on the stack */

/*
 * Push a trapframe to be used by cpu_switchto
 */
#define PUSHSWITCHFRAME(rX)						\
	mov	ip, sp;							\
	sub	sp, sp, #(TRAPFRAMESIZE-TF_R12); /* Adjust the stack pointer */ \
	push	{r4-r11};		/* Push the callee saved registers */ \
	sub	sp, sp, #TF_R4;		/* reserve rest of trapframe */	\
	str	ip, [sp, #TF_SVC_SP];					\
	str	lr, [sp, #TF_SVC_LR];					\
	str	lr, [sp, #TF_PC];					\
	mrs	rX, cpsr;		/* Get the CPSR */		\
	str	rX, [sp, #TF_SPSR]	/* save in trapframe */

#define PUSHSWITCHFRAME1						   \
	mov	ip, sp;							   \
	sub	sp, sp, #(TRAPFRAMESIZE-TF_R8); /* Adjust the stack pointer */ \
	push	{r4-r7};		/* Push some of the callee saved registers */ \
	sub	sp, sp, #TF_R4;		/* reserve rest of trapframe */	\
	str	ip, [sp, #TF_SVC_SP];					\
	str	lr, [sp, #TF_SVC_LR];					\
	str	lr, [sp, #TF_PC]

#if defined(_ARM_ARCH_DWORD_OK) && __ARM_EABI__
#define	PUSHSWITCHFRAME2						\
	strd	r10, [sp, #TF_R10];	/* save r10 & r11 */		\
	strd	r8, [sp, #TF_R8];	/* save r8 & r9 */		\
	mrs	r0, cpsr;		/* Get the CPSR */		\
	str	r0, [sp, #TF_SPSR]	/* save in trapframe */
#else
#define	PUSHSWITCHFRAME2						\
	add	r0, sp, #TF_R8;		/* get ptr to r8 and above */	\
	stmia	r0, {r8-r11};		/* save rest of registers */	\
	mrs	r0, cpsr;		/* Get the CPSR */		\
	str	r0, [sp, #TF_SPSR]	/* save in trapframe */
#endif

/*
 * PULLFRAME - macro to pull a trap frame from the stack in the current mode
 * Since the current mode is used, the SVC lr field is ignored.
 */

#define PULLFRAME							   \
	ldr     r0, [sp], #TF_R0;	/* Pop the SPSR from stack */	   \
	msr     spsr_fsxc, r0;						   \
	ldmia   sp, {r0-r14}^;		/* Restore registers (usr mode) */ \
	mov     r0, r0;                 /* NOP for previous instruction */ \
	add	sp, sp, #(TF_PC-TF_R0);	/* Adjust the stack pointer */	   \
 	ldr	lr, [sp], #4		/* Pop the return address */

#define PULLIDLEFRAME							   \
	add	sp, sp, #TF_R4;		/* Adjust the stack pointer */	   \
	ldr	r4, [sp], #(TF_R6-TF_R4); /* restore callee-saved r4 */	   \
	ldr	r6, [sp], #(TF_PC-TF_R6); /* restore callee-saved r6 */	   \
 	ldr	lr, [sp], #4		/* Pop the return address */

/*
 * Pop a trapframe to be used by cpu_switchto (don't touch r0 & r1).
 */
#define PULLSWITCHFRAME							\
	add	sp, sp, #TF_R4;		/* Adjust the stack pointer */	\
	pop	{r4-r11};		/* pop the callee saved registers */ \
	add	sp, sp, #(TF_PC-TF_R12); /* Adjust the stack pointer */	\
	ldr	lr, [sp], #4;		/* pop the return address */

/*
 * PUSHFRAMEINSVC - macro to push a trap frame on the stack in SVC32 mode
 * This should only be used if the processor is not currently in SVC32
 * mode. The processor mode is switched to SVC mode and the trap frame is
 * stored. The SVC lr field is used to store the previous value of
 * lr in SVC mode.
 *
 * NOTE: r13 and r14 are stored separately as a work around for the
 * SA110 rev 2 STM^ bug
 */

#ifdef _ARM_ARCH_6
#define	SET_CPSR_MODE(tmp, mode)	\
	cps	#(mode)
#else
#define	SET_CPSR_MODE(tmp, mode)	\
	mrs     tmp, cpsr; 		/* Get the CPSR */		   \
	bic     tmp, tmp, #(PSR_MODE);	/* Fix for SVC mode */		   \
	orr     tmp, tmp, #(mode);					   \
	msr     cpsr_c, tmp		/* Punch into SVC mode */
#endif

#define PUSHXXXREGSANDSWITCH						   \
	stmdb	sp, {r0-r3};		/* Save 4 registers */		   \
	mov	r0, lr;			/* Save xxx32 r14 */		   \
	mov	r1, sp;			/* Save xxx32 sp */		   \
	mrs	r3, spsr;		/* Save xxx32 spsr */		   \
	SET_CPSR_MODE(r2, PSR_SVC32_MODE)

#ifdef KDTRACE_HOOKS
#define PUSHDTRACEGAP							   \
	and	r2, r3, #(PSR_MODE);					   \
	cmp	r2, #(PSR_SVC32_MODE);	/* were we in SVC mode? */	   \
	mov	r2, sp;							   \
	subeq	r2, r2, #(4 * 16);	/* if so, leave a gap for dtrace */
#else
#define PUSHDTRACEGAP							   \
	mov	r2, sp
#endif

#define PUSHTRAPFRAME(rX)						   \
	bic	r2, rX, #7;		/* Align new SVC sp */		   \
	str	r0, [r2, #-4]!;		/* Push return address */	   \
	stmdb	r2!, {sp, lr};		/* Push SVC sp, lr */		   \
	mov	sp, r2;			/* Keep stack aligned */	   \
	msr     spsr_fsxc, r3;		/* Restore correct spsr */	   \
	ldmdb	r1, {r0-r3};		/* Restore 4 regs from xxx mode */ \
	sub	sp, sp, #(TF_SVC_SP-TF_R0); /* Adjust the stack pointer */ \
	PUSHUSERREGS;			/* Push the user mode registers */ \
	mov     r0, r0;                 /* NOP for previous instruction */ \
	mrs	r0, spsr;		/* Get the SPSR */		   \
	str	r0, [sp, #-TF_R0]!	/* Push the SPSR onto the stack */

#define PUSHFRAMEINSVC							   \
	PUSHXXXREGSANDSWITCH;						   \
	PUSHTRAPFRAME(sp)

/*
 * PULLFRAMEFROMSVCANDEXIT - macro to pull a trap frame from the stack
 * in SVC32 mode and restore the saved processor mode and PC.
 * This should be used when the SVC lr register needs to be restored on
 * exit.
 */

#define PULLFRAMEFROMSVCANDEXIT						   \
	ldr     r0, [sp], #TF_R0;	/* Pop the SPSR from stack */	   \
	msr     spsr_fsxc, r0;		/* restore SPSR */		   \
	ldmia   sp, {r0-r14}^;		/* Restore registers (usr mode) */ \
	mov     r0, r0;	  		/* NOP for previous instruction */ \
	add	sp, sp, #(TF_SVC_SP-TF_R0); /* Adjust the stack pointer */ \
	ldmia	sp, {sp, lr, pc}^	/* Restore lr and exit */

#endif /* _LOCORE */

#endif /* _ARM32_FRAME_H_ */