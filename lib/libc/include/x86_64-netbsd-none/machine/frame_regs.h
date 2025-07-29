/*	$NetBSD: frame_regs.h,v 1.8 2021/04/17 20:12:55 rillig Exp $	*/

#ifndef _AMD64_FRAME_REGS_H_
#define _AMD64_FRAME_REGS_H_

/*
 * amd64 registers (and friends) ordered as in a trap/interrupt/syscall frame.
 * Also the indexes into the 'general register state' (__greg_t) passed to
 * userland.
 * Historically they were in the same order, but the order in the frames
 * has been changed to improve syscall efficiency.
 *
 * Notes:
 * 1) gdb (amd64nbsd-tdep.c) has a lookup table that assumes the __greg_t
 *    ordering.
 * 2) src/lib/libc/arch/x86_64/gen/makecontext.c assumes that the first
 *    6 entries in the __greg_t array match the registers used to pass
 *    function arguments.
 * 3) The 'struct reg' from machine/reg.h has to match __greg_t.
 *    Since they are both arrays and indexed with the same tokens this
 *    shouldn't be a problem, but is rather confusing.
 *    This assumption is made in a lot of places!
 * 4) There might be other code out there that relies on the ordering.
 *
 * The first entries below match the registers used for syscall arguments
 * (%rcx is destroyed by the syscall instruction, the libc system call
 * stubs copy %rcx to %r10).
 * arg6-arg9 are copied from the user stack for system calls with more
 * than 6 args (SYS_MAXSYSARGS is 8, + 2 entries for SYS___SYSCALL).
 */
#define _FRAME_REG(greg, freg) 	\
	greg(rdi, RDI, 0)	/* tf_rdi */ \
	greg(rsi, RSI, 1)	/* tf_rsi */ \
	greg(rdx, RDX, 2)	/* tf_rdx */ \
	greg(r10, R10, 6)	/* tf_r10 */ \
	greg(r8,  R8,  4)	/* tf_r8 */ \
	greg(r9,  R9,  5)	/* tf_r9 */ \
	freg(arg6, @,  @)	/* tf_arg6: syscall arg from stack */ \
	freg(arg7, @,  @)	/* tf_arg7: syscall arg from stack */ \
	freg(arg8, @,  @)	/* tf_arg8: syscall arg from stack */ \
	freg(arg9, @,  @)	/* tf_arg9: syscall arg from stack */ \
	greg(rcx, RCX, 3)	/* tf_rcx */ \
	greg(r11, R11, 7)	/* tf_r11 */ \
	greg(r12, R12, 8)	/* tf_r12 */ \
	greg(r13, R13, 9)	/* tf_r13 */ \
	greg(r14, R14, 10)	/* tf_r14 */ \
	greg(r15, R15, 11)	/* tf_r15 */ \
	greg(rbp, RBP, 12)	/* tf_rbp */ \
	greg(rbx, RBX, 13)	/* tf_rbx */ \
	greg(rax, RAX, 14)	/* tf_rax */ \
	greg(gs,  GS,  15)	/* tf_gs */ \
	greg(fs,  FS,  16)	/* tf_fs */ \
	greg(es,  ES,  17)	/* tf_es */ \
	greg(ds,  DS,  18)	/* tf_ds */ \
	greg(trapno, TRAPNO,	/* tf_trapno */ \
	    19) \
	/* Below portion defined in hardware */ \
	greg(err, ERR, 20)	/* tf_err: Dummy inserted if not defined */ \
	greg(rip, RIP, 21)	/* tf_rip */ \
	greg(cs,  CS,  22)	/* tf_cs */ \
	greg(rflags, RFLAGS,	/* tf_rflags */ \
	    23) \
	/* These are pushed unconditionally on the x86-64 */ \
	greg(rsp, RSP, 24)	/* tf_rsp */ \
	greg(ss,  SS,  25)	/* tf_ss */

#define _FRAME_NOREG(reg, REG, idx)

#define _FRAME_GREG(greg) _FRAME_REG(greg, _FRAME_NOREG)

#endif