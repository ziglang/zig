/*-
 * Copyright (c) 2014 Andrew Turner
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

#ifdef __arm__
#include <arm/asm.h>
#else /* !__arm__ */

#ifndef _MACHINE_ASM_H_
#define	_MACHINE_ASM_H_

#undef __FBSDID
#if !defined(lint) && !defined(STRIP_FBSDID)
#define	__FBSDID(s)     .ident s
#else
#define	__FBSDID(s)     /* nothing */
#endif

#define	_C_LABEL(x)	x

#ifdef KDTRACE_HOOKS
#define	DTRACE_NOP	nop
#else
#define	DTRACE_NOP
#endif

#define	LENTRY(sym)						\
	.text; .align 2; .type sym,#function; sym:		\
	.cfi_startproc; BTI_C; DTRACE_NOP
#define	ENTRY(sym)						\
	.globl sym; LENTRY(sym)
#define	EENTRY(sym)						\
	.globl	sym; .text; .align 2; .type sym,#function; sym:
#define	LEND(sym) .ltorg; .cfi_endproc; .size sym, . - sym
#define	END(sym) LEND(sym)
#define	EEND(sym)

#define	WEAK_REFERENCE(sym, alias)				\
	.weak alias;						\
	.set alias,sym

#define	UINT64_C(x)	(x)

#if defined(PIC)
#define	PIC_SYM(x,y)	x ## @ ## y
#else
#define	PIC_SYM(x,y)	x
#endif

/* Alias for link register x30 */
#define	lr		x30

/*
 * Sets the trap fault handler. The exception handler will return to the
 * address in the handler register on a data abort or the xzr register to
 * clear the handler. The tmp parameter should be a register able to hold
 * the temporary data.
 */
#define	SET_FAULT_HANDLER(handler, tmp)					\
	ldr	tmp, [x18, #PC_CURTHREAD];	/* Load curthread */	\
	ldr	tmp, [tmp, #TD_PCB];		/* Load the pcb */	\
	str	handler, [tmp, #PCB_ONFAULT]	/* Set the handler */

#define	ENTER_USER_ACCESS(reg, tmp)					\
	ldr	tmp, =has_pan;			/* Get the addr of has_pan */ \
	ldr	reg, [tmp];			/* Read it */		\
	cbz	reg, 997f;			/* If no PAN skip */	\
	.inst	0xd500409f | (0 << 8);		/* Clear PAN */		\
	997:

#define	EXIT_USER_ACCESS(reg)						\
	cbz	reg, 998f;			/* If no PAN skip */	\
	.inst	0xd500409f | (1 << 8);		/* Set PAN */		\
	998:

#define	EXIT_USER_ACCESS_CHECK(reg, tmp)				\
	ldr	tmp, =has_pan;			/* Get the addr of has_pan */ \
	ldr	reg, [tmp];			/* Read it */		\
	cbz	reg, 999f;			/* If no PAN skip */	\
	.inst	0xd500409f | (1 << 8);		/* Set PAN */		\
	999:

/*
 * Some AArch64 CPUs speculate past an eret instruction. As the user may
 * control the registers at this point add a speculation barrier usable on
 * all AArch64 CPUs after the eret instruction.
 * TODO: ARMv8.5 adds a specific instruction for this, we could use that
 * if we know we are running on something that supports it.
 */
#define	ERET								\
	eret;								\
	dsb	sy;							\
	isb

/*
 * When a CPU that implements FEAT_BTI uses a BR/BLR instruction (or the
 * pointer authentication variants, e.g. BLRAA) and the target location
 * has the GP attribute in its page table, then the target of the BR/BLR
 * needs to be a valid BTI landing pad.
 *
 * BTI_C should be used at the start of a function and is used in the
 * ENTRY macro. It can be replaced by PACIASP or PACIBSP, however these
 * also need an appropriate authenticate instruction before returning.
 *
 * BTI_J should be used as the target instruction when branching with a
 * BR instruction within a function.
 *
 * When using a BR to branch to a new function, e.g. a tail call, then
 * the target register should be x16 or x17 so it is compatible with
 * the BRI_C instruction.
 *
 * As these instructions are in the hint space they are a NOP when
 * the CPU doesn't implement FEAT_BTI so are safe to use.
 */
#ifdef __ARM_FEATURE_BTI_DEFAULT
#define	BTI_C	hint	#34
#define	BTI_J	hint	#36
#else
#define	BTI_C
#define	BTI_J
#endif

/*
 * To help protect against ROP attacks we can use Pointer Authentication
 * to sign the return address before pushing it to the stack.
 *
 * PAC_LR_SIGN can be used at the start of a function to sign the link
 * register with the stack pointer as the modifier. As this is in the hint
 * space it is safe to use on CPUs that don't implement pointer
 * authentication. It can be used in place of the BTI_C instruction above as
 * a valid BTI landing pad instruction.
 *
 * PAC_LR_AUTH is used to authenticate the link register using the stack
 * pointer as the modifier. It should be used in any function that uses
 * PAC_LR_SIGN. The stack pointer must be identical in each case.
 */
#ifdef __ARM_FEATURE_PAC_DEFAULT
#define	PAC_LR_SIGN	hint	#25	/* paciasp */
#define	PAC_LR_AUTH	hint	#29	/* autiasp */
#else
#define	PAC_LR_SIGN
#define	PAC_LR_AUTH
#endif

/*
 * GNU_PROPERTY_AARCH64_FEATURE_1_NOTE can be used to insert a note that
 * the current assembly file is built with Pointer Authentication (PAC) or
 * Branch Target Identification support (BTI). As the linker requires all
 * object files in an executable or library to have the GNU property
 * note to emit it in the created elf file we need to add a note to all
 * assembly files that support BTI so the kernel and dynamic linker can
 * mark memory used by the file as guarded.
 *
 * The GNU_PROPERTY_AARCH64_FEATURE_1_VAL macro encodes the combination
 * of PAC and BTI that have been enabled. It can be used as follows:
 * GNU_PROPERTY_AARCH64_FEATURE_1_NOTE(GNU_PROPERTY_AARCH64_FEATURE_1_VAL);
 *
 * To use this you need to include <sys/elf_common.h> for
 * GNU_PROPERTY_AARCH64_FEATURE_1_*
 */
#if defined(__ARM_FEATURE_BTI_DEFAULT)
#if defined(__ARM_FEATURE_PAC_DEFAULT)
/* BTI, PAC */
#define	GNU_PROPERTY_AARCH64_FEATURE_1_VAL				\
    (GNU_PROPERTY_AARCH64_FEATURE_1_BTI | GNU_PROPERTY_AARCH64_FEATURE_1_PAC)
#else
/* BTI, no PAC */
#define	GNU_PROPERTY_AARCH64_FEATURE_1_VAL				\
    (GNU_PROPERTY_AARCH64_FEATURE_1_BTI)
#endif
#elif defined(__ARM_FEATURE_PAC_DEFAULT)
/* No BTI, PAC */
#define	GNU_PROPERTY_AARCH64_FEATURE_1_VAL				\
    (GNU_PROPERTY_AARCH64_FEATURE_1_PAC)
#else
/* No BTI, no PAC */
#define	GNU_PROPERTY_AARCH64_FEATURE_1_VAL	0
#endif

#if defined(__ARM_FEATURE_BTI_DEFAULT) || defined(__ARM_FEATURE_PAC_DEFAULT)
#define	GNU_PROPERTY_AARCH64_FEATURE_1_NOTE(x)				\
    .section .note.gnu.property, "a";					\
    .balign 8;								\
    .4byte 0x4;				/* sizeof(vendor) */		\
    .4byte 0x10;			/* sizeof(note data) */		\
    .4byte (NT_GNU_PROPERTY_TYPE_0);					\
    .asciz "GNU";			/* vendor */			\
    /* note data: */							\
    .4byte (GNU_PROPERTY_AARCH64_FEATURE_1_AND);			\
    .4byte 0x4;				/* sizeof(property) */		\
    .4byte (x);				/* property */			\
    .4byte 0
#else
#define	GNU_PROPERTY_AARCH64_FEATURE_1_NOTE(x)
#endif

#endif /* _MACHINE_ASM_H_ */

#endif /* !__arm__ */