/* Assembly macros for 64-bit PowerPC.
   Copyright (C) 2002-2023 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#include <sysdeps/powerpc/sysdep.h>
#include <tls.h>

#ifdef __ASSEMBLER__

/* Stack frame offsets.  */
#define FRAME_BACKCHAIN		0
#define FRAME_CR_SAVE		8
#define FRAME_LR_SAVE		16
#if _CALL_ELF != 2
#define FRAME_MIN_SIZE		112
#define FRAME_MIN_SIZE_PARM	112
#define FRAME_TOC_SAVE		40
#define FRAME_PARM_SAVE		48
#else
#define FRAME_MIN_SIZE		32
#define FRAME_MIN_SIZE_PARM	96
#define FRAME_TOC_SAVE		24
#define FRAME_PARM_SAVE		32
#endif

/* Support macros for CALL_MCOUNT.  */
	.macro SAVE_ARG NARG
	.if \NARG
	SAVE_ARG \NARG-1
	std	2+\NARG,-FRAME_MIN_SIZE_PARM+FRAME_PARM_SAVE-8+8*(\NARG)(1)
	.endif
	.endm

	.macro REST_ARG NARG
	.if \NARG
	REST_ARG \NARG-1
	ld	2+\NARG,FRAME_PARM_SAVE-8+8*(\NARG)(1)
	.endif
	.endm

	.macro CFI_SAVE_ARG NARG
	.if \NARG
	CFI_SAVE_ARG \NARG-1
	cfi_offset(2+\NARG,-FRAME_MIN_SIZE_PARM+FRAME_PARM_SAVE-8+8*(\NARG))
	.endif
	.endm

	.macro CFI_REST_ARG NARG
	.if \NARG
	CFI_REST_ARG \NARG-1
	cfi_restore(2+\NARG)
	.endif
	.endm

/* If compiled for profiling, call `_mcount' at the start of each function.
   see ppc-mcount.S for more details.  */
	.macro CALL_MCOUNT NARG
#ifdef	PROF
	mflr	r0
	SAVE_ARG \NARG
	std	r0,FRAME_LR_SAVE(r1)
	stdu	r1,-FRAME_MIN_SIZE_PARM(r1)
	cfi_adjust_cfa_offset(FRAME_MIN_SIZE_PARM)
	cfi_offset(lr,FRAME_LR_SAVE)
	CFI_SAVE_ARG \NARG
	bl	JUMPTARGET (_mcount)
#ifndef SHARED
	nop
#endif
	ld	r0,FRAME_MIN_SIZE_PARM+FRAME_LR_SAVE(r1)
	REST_ARG \NARG
	mtlr	r0
	addi	r1,r1,FRAME_MIN_SIZE_PARM
	cfi_adjust_cfa_offset(-FRAME_MIN_SIZE_PARM)
	cfi_restore(lr)
	CFI_REST_ARG \NARG
#endif
	.endm

#if _CALL_ELF != 2

/* Macro to prepare for calling via a function pointer.  */
	.macro PPC64_LOAD_FUNCPTR PTR
	ld      r12,0(\PTR)
	ld      r2,8(\PTR)
	mtctr   r12
	ld      r11,16(\PTR)
	.endm

#ifdef USE_PPC64_OVERLAPPING_OPD
# define OPD_ENT(name)	.quad BODY_LABEL (name), .TOC.@tocbase
#else
# define OPD_ENT(name)	.quad BODY_LABEL (name), .TOC.@tocbase, 0
#endif

#define ENTRY_1(name)				\
	.type BODY_LABEL(name),@function;	\
	.globl name;				\
	.section ".opd","aw";			\
	.p2align 3;FUNC_LABEL(name):		\
	OPD_ENT (name);				\
	.previous

#define FUNC_LABEL(X) X
#define BODY_LABEL(X) .LY##X
#define ENTRY_2(name)				\
	.type name,@function;			\
	ENTRY_1(name)
#define END_2(name)				\
	.size name,.-BODY_LABEL(name);		\
	.size BODY_LABEL(name),.-BODY_LABEL(name)
#define LOCALENTRY(name)

#else /* _CALL_ELF == 2 */

/* Macro to prepare for calling via a function pointer.  */
	.macro PPC64_LOAD_FUNCPTR PTR
	mr	r12,\PTR
	mtctr   r12
	.endm

#define FUNC_LABEL(X) X
#define BODY_LABEL(X) X
#define ENTRY_2(name)				\
	.globl name;				\
	.type name,@function
#define END_2(name)				\
	.size name,.-name
#define LOCALENTRY(name)			\
1:      addis	r2,r12,.TOC.-1b@ha;		\
        addi	r2,r2,.TOC.-1b@l;		\
	.localentry name,.-name

#endif /* _CALL_ELF */

	.macro NOPS NARG
	.if \NARG
	NOPS \NARG-1
	nop
	.endif
	.endm

	.macro ENTRY_3 name, alignp2=2, nopwords=0
	.text
	ENTRY_2(\name)
	.p2align \alignp2
	NOPS \nopwords
BODY_LABEL(\name):
	.endm

/* Use ENTRY_TOCLESS for functions that make no use of r2 and
   guarantee r2 is unchanged on exit.  Any function that has @toc or
   @got relocs uses r2.  Functions that call other functions via the
   PLT use r2.  Use ENTRY for functions that may use or change r2.
   The first argument is the function name.
   The optional second argument specifies alignment of the function's
   code, as the logarithm base two of the byte alignment.  For
   example, a value of four aligns to a sixteen byte boundary.
   The optional third argument specifies the number of NOPs to emit
   before the start of the function's code.   */
#ifndef PROF
#define ENTRY_TOCLESS(name, ...)		\
	ENTRY_3 name, ## __VA_ARGS__;		\
	cfi_startproc

#define ENTRY(name, ...)			\
	ENTRY_TOCLESS(name, ## __VA_ARGS__);	\
	LOCALENTRY(name)
#else
/* The call to _mcount is potentially via the plt, so profiling code
   is never free of an r2 use.  */
#define ENTRY_TOCLESS(name, ...)		\
	ENTRY_3 name, ## __VA_ARGS__;		\
	cfi_startproc;				\
	LOCALENTRY(name)

#define ENTRY(name, ...)			\
	ENTRY_TOCLESS(name, ## __VA_ARGS__)
#endif

/* Local labels stripped out by the linker.  */
#undef L
#define L(x) .L##x

#define tostring(s) #s
#define stringify(s) tostring(s)
#define XGLUE(a,b) a##b
#define GLUE(a,b) XGLUE(a,b)
#define LT_LABEL(name) GLUE(.LT,name)
#define LT_LABELSUFFIX(name,suffix) GLUE(GLUE(.LT,name),suffix)

/* Support Traceback tables */
#define TB_ASM			0x000c000000000000
#define TB_GLOBALLINK		0x0000800000000000
#define TB_IS_EPROL		0x0000400000000000
#define TB_HAS_TBOFF		0x0000200000000000
#define TB_INT_PROC		0x0000100000000000
#define TB_HAS_CTL		0x0000080000000000
#define TB_TOCLESS		0x0000040000000000
#define TB_FP_PRESENT		0x0000020000000000
#define TB_LOG_ABORT		0x0000010000000000
#define TB_INT_HANDL		0x0000008000000000
#define TB_NAME_PRESENT		0x0000004000000000
#define TB_USES_ALLOCA		0x0000002000000000
#define TB_SAVES_CR		0x0000000200000000
#define TB_SAVES_LR		0x0000000100000000
#define TB_STORES_BC		0x0000000080000000
#define TB_FIXUP		0x0000000040000000
#define TB_FP_SAVED(fprs)	(((fprs) & 0x3f) << 24)
#define TB_GPR_SAVED(gprs)	(((fprs) & 0x3f) << 16)
#define TB_FIXEDPARMS(parms)	(((parms) & 0xff) << 8)
#define TB_FLOATPARMS(parms)	(((parms) & 0x7f) << 1)
#define TB_PARMSONSTK		0x0000000000000001

#define PPC_HIGHER(v) 		(((v) >> 32) & 0xffff)
#define TB_DEFAULT		TB_ASM | TB_HAS_TBOFF | TB_NAME_PRESENT

#define TRACEBACK(name) \
LT_LABEL(name): ; \
	.long	0 ; \
	.quad	TB_DEFAULT ; \
	.long	LT_LABEL(name)-BODY_LABEL(name) ; \
	.short	LT_LABELSUFFIX(name,_name_end)-LT_LABELSUFFIX(name,_name_start) ; \
LT_LABELSUFFIX(name,_name_start): ;\
	.ascii	stringify(name) ; \
LT_LABELSUFFIX(name,_name_end): ; \
	.p2align 2

#define TRACEBACK_MASK(name,mask) \
LT_LABEL(name): ; \
	.long	0 ; \
	.quad	TB_DEFAULT | mask ; \
	.long	LT_LABEL(name)-BODY_LABEL(name) ; \
	.short	LT_LABELSUFFIX(name,_name_end)-LT_LABELSUFFIX(name,_name_start) ; \
LT_LABELSUFFIX(name,_name_start): ;\
	.ascii	stringify(name) ; \
LT_LABELSUFFIX(name,_name_end): ; \
	.p2align 2

/* END generates Traceback tables */
#undef	END
#define END(name) \
  cfi_endproc;			\
  TRACEBACK(name);		\
  END_2(name)

/* This form supports more informative traceback tables */
#define END_GEN_TB(name,mask)	\
  cfi_endproc;			\
  TRACEBACK_MASK(name,mask);	\
  END_2(name)

/* We will allocate a new frame to save LR and the non-volatile register used to
   read the TCB when checking for scv support on syscall code.  We actually just
   need the minimum frame size plus room for 1 reg (8 bytes).  But the ABI
   mandates stack frames should be aligned at 16 Bytes, so we end up allocating
   a bit more space then what will actually be used.  */
#define SCV_FRAME_SIZE (FRAME_MIN_SIZE+16)
#define SCV_FRAME_NVOLREG_SAVE FRAME_MIN_SIZE

/* Allocate frame and save register */
#define NVOLREG_SAVE \
    stdu r1,-SCV_FRAME_SIZE(r1); \
    cfi_adjust_cfa_offset(SCV_FRAME_SIZE); \
    std r31,SCV_FRAME_NVOLREG_SAVE(r1); \
    cfi_rel_offset(r31,SCV_FRAME_NVOLREG_SAVE);

/* Restore register and destroy frame */
#define NVOLREG_RESTORE	\
    ld r31,SCV_FRAME_NVOLREG_SAVE(r1); \
    cfi_restore(r31); \
    addi r1,r1,SCV_FRAME_SIZE; \
    cfi_adjust_cfa_offset(-SCV_FRAME_SIZE);

/* Check PPC_FEATURE2_SCV bit from hwcap2 in the TCB.  If it is not set, scv is
   not available, then go to JUMPFALSE (label given by the macro's caller).  We
   save the value we read from the TCB in a non-volatile register so we can
   reuse it later when exiting from the syscall in PSEUDO_RET.  Note that for
   the static case we need an extra check to guarantee the thread pointer has
   already been initialized, otherwise we may try to access an invalid address
   if a syscall is called before the TLS has been setup.  */
    .macro CHECK_SCV_SUPPORT REG JUMPFALSE

#ifndef SHARED
    /* Check if thread pointer has already been setup.  */
    cmpdi r13,0
    beq \JUMPFALSE
#endif

    /* Read PPC_FEATURE2_SCV from TCB and store it in REG */
    ld \REG,TCB_HWCAP(PT_THREAD_POINTER)
    andis. \REG,\REG,PPC_FEATURE2_SCV>>16

    beq \JUMPFALSE
    .endm

#if !defined(USE_PPC_SCV) || IS_IN(rtld)
# define DO_CALL(syscall) \
    li r0,syscall; \
    DO_CALL_SC
#else
/* Before doing the syscall, check if we can use scv.  scv is supported by P9
   and later with Linux v5.9 and later.  If so, use it.  Otherwise, fallback to
   sc.  We use a non-volatile register to save hwcap2 from the TCB, so we need
   to save its content beforehand.  */
# define DO_CALL(syscall) \
    li r0,syscall; \
    NVOLREG_SAVE; \
    CHECK_SCV_SUPPORT r31 0f; \
    DO_CALL_SCV; \
    b 1f; \
0:  DO_CALL_SC; \
1:
#endif /* !defined(USE_PPC_SCV) || IS_IN(rtld) */

/* DO_CALL_SC and DO_CALL_SCV expect the syscall number to be in r0.  */
#define DO_CALL_SC \
    sc

#define DO_CALL_SCV \
    mflr r9; \
    std r9,SCV_FRAME_SIZE+FRAME_LR_SAVE(r1);   \
    cfi_rel_offset(lr,SCV_FRAME_SIZE+FRAME_LR_SAVE); \
    .machine "push"; \
    .machine "power9"; \
    scv 0; \
    .machine "pop"; \
    ld r9,SCV_FRAME_SIZE+FRAME_LR_SAVE(r1);      \
    mtlr r9; \
    cfi_restore(lr);

/* ppc64 is always PIC */
#undef JUMPTARGET
#define JUMPTARGET(name) FUNC_LABEL(name)

#define PSEUDO(name, syscall_name, args) \
  .section ".text";				\
  ENTRY (name);					\
  DO_CALL (SYS_ify (syscall_name))

#ifdef SHARED
#define TAIL_CALL_SYSCALL_ERROR \
    b JUMPTARGET (NOTOC (__syscall_error))
#else
/* Static version might be linked into a large app with a toc exceeding
   64k.  We can't put a toc adjusting stub on a plain branch, so can't
   tail call __syscall_error.  */
#define TAIL_CALL_SYSCALL_ERROR \
    .ifdef .Local_syscall_error; \
    b .Local_syscall_error; \
    .else; \
.Local_syscall_error: \
    mflr 0; \
    std 0,FRAME_LR_SAVE(1); \
    stdu 1,-FRAME_MIN_SIZE(1); \
    cfi_adjust_cfa_offset(FRAME_MIN_SIZE); \
    cfi_offset(lr,FRAME_LR_SAVE); \
    bl JUMPTARGET(__syscall_error); \
    nop; \
    ld 0,FRAME_MIN_SIZE+FRAME_LR_SAVE(1); \
    addi 1,1,FRAME_MIN_SIZE; \
    cfi_adjust_cfa_offset(-FRAME_MIN_SIZE); \
    mtlr 0; \
    cfi_restore(lr); \
    blr; \
    .endif
#endif

#if !defined(USE_PPC_SCV) || IS_IN(rtld)
# define PSEUDO_RET \
    RET_SC; \
    TAIL_CALL_SYSCALL_ERROR
#else
/* This should only be called after a DO_CALL.  In such cases, r31 contains the
   value of PPC_FEATURE2_SCV read from hwcap2 by CHECK_SCV_SUPPORT.  If it is
   set, we know we have entered the kernel using scv, so handle the return code
   accordingly.  */
# define PSEUDO_RET \
    cmpdi cr5,r31,0; \
    NVOLREG_RESTORE; \
    beq cr5,0f; \
    RET_SCV; \
    b 1f; \
0:  RET_SC; \
1:  TAIL_CALL_SYSCALL_ERROR
#endif /* !defined(USE_PPC_SCV) || IS_IN(rtld) */

#define RET_SCV \
    li r9,-4095; \
    cmpld r3,r9; \
    bltlr+; \
    neg r3,r3;

#define RET_SC \
    bnslr+;

#define ret PSEUDO_RET

#undef	PSEUDO_END
#define	PSEUDO_END(name) \
  END (name)

#define PSEUDO_NOERRNO(name, syscall_name, args) \
  .section ".text";					\
  ENTRY (name);						\
  DO_CALL (SYS_ify (syscall_name))

#if !defined(USE_PPC_SCV) || IS_IN(rtld)
# define PSEUDO_RET_NOERRNO \
    blr
#else
/* This should only be called after a DO_CALL.  */
# define PSEUDO_RET_NOERRNO \
    NVOLREG_RESTORE; \
    blr
#endif /* !defined(USE_PPC_SCV) || IS_IN(rtld) */

#define ret_NOERRNO PSEUDO_RET_NOERRNO

#undef	PSEUDO_END_NOERRNO
#define	PSEUDO_END_NOERRNO(name) \
  END (name)

#define PSEUDO_ERRVAL(name, syscall_name, args) \
  .section ".text";					\
  ENTRY (name);						\
  DO_CALL (SYS_ify (syscall_name))

#if !defined(USE_PPC_SCV) || IS_IN(rtld)
# define PSEUDO_RET_ERRVAL \
    blr
#else
/* This should only be called after a DO_CALL.  */
# define PSEUDO_RET_ERRVAL \
    NVOLREG_RESTORE; \
    blr
#endif /* !defined(USE_PPC_SCV) || IS_IN(rtld) */

#define ret_ERRVAL PSEUDO_RET_ERRVAL

#undef	PSEUDO_END_ERRVAL
#define	PSEUDO_END_ERRVAL(name) \
  END (name)

#ifdef SHARED
# if IS_IN (rtld)
	 /* Inside ld.so we use the local alias to avoid runtime GOT
	    relocations.  */
#  define __GLRO_DEF(var)				\
.LC__ ## var:						\
	.tc _rtld_local_ro[TC],_rtld_local_ro
# else
#  define __GLRO_DEF(var)				\
.LC__ ## var:						\
	.tc _rtld_global_ro[TC],_rtld_global_ro
# endif
# define __GLRO(rOUT, var, offset)		\
	addis	rOUT,r2,.LC__ ## var@toc@ha;	\
	ld	rOUT,.LC__ ## var@toc@l(rOUT);	\
	lwz	rOUT,offset(rOUT)
#else
# define __GLRO_DEF(var)			\
.LC__ ## var:					\
	.tc _ ## var[TC],_ ## var
# define __GLRO(rOUT, var, offset)		\
	addis	rOUT,r2,.LC__ ## var@toc@ha;	\
	ld	rOUT,.LC__ ## var@toc@l(rOUT);	\
	lwz	rOUT,0(rOUT)
#endif

#ifdef USE_PPC64_NOTOC
# define NOTOC(l) l@notoc
#else
# define NOTOC(l) l
#endif

#else /* !__ASSEMBLER__ */

#if _CALL_ELF != 2

#define PPC64_LOAD_FUNCPTR(ptr) \
	"ld 	12,0(" #ptr ")\n"					\
	"ld	2,8(" #ptr ")\n"					\
	"mtctr	12\n"							\
	"ld	11,16(" #ptr ")"

#ifdef USE_PPC64_OVERLAPPING_OPD
# define OPD_ENT(name)	".quad " BODY_PREFIX #name ", .TOC.@tocbase"
#else
# define OPD_ENT(name)	".quad " BODY_PREFIX #name ", .TOC.@tocbase, 0"
#endif

#define ENTRY_1(name)	\
	".type   " BODY_PREFIX #name ",@function\n"			\
	".globl " #name "\n"						\
	".pushsection \".opd\",\"aw\"\n"				\
	".p2align 3\n"							\
#name ":\n"								\
	OPD_ENT (name) "\n"						\
	".popsection"

#define DOT_PREFIX ""
#define BODY_PREFIX ".LY"
#define ENTRY_2(name)	\
	".type " #name ",@function\n"					\
	ENTRY_1(name)
#define END_2(name)	\
	".size " #name ",.-" BODY_PREFIX #name "\n"			\
	".size " BODY_PREFIX #name ",.-" BODY_PREFIX #name
#define LOCALENTRY(name)

#else /* _CALL_ELF */

#define PPC64_LOAD_FUNCPTR(ptr) \
	"mr	12," #ptr "\n"						\
	"mtctr 	12"

#define DOT_PREFIX ""
#define BODY_PREFIX ""
#define ENTRY_2(name)	\
	".type " #name ",@function\n"					\
	".globl " #name
#define END_2(name)	\
	".size " #name ",.-" #name
#define LOCALENTRY(name)	\
	"1: addis 2,12,.TOC.-1b@ha\n"					\
	"addi	2,2,.TOC.-1b@l\n"					\
	".localentry " #name ",.-" #name

#endif /* _CALL_ELF */

#endif	/* __ASSEMBLER__ */
