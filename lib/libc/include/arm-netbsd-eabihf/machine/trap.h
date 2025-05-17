/*	$NetBSD: trap.h,v 1.10 2020/12/01 02:48:29 rin Exp $	*/

/*
 * Copyright (c) 1995 Mark Brinicombe.
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
 *	This product includes software developed by Mark Brinicombe.
 * 4. The name of the company nor the name of the author may be used to
 *    endorse or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
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
 * trap.h
 *
 * Various trap definitions
 */

#include <arm/cdefs.h>

/*
 * Instructions used for breakpoints.
 *
 * These are undefined instructions.
 * Technically the userspace breakpoint could be a SWI but we want to
 * keep this the same as IPKDB which needs an undefined instruction as
 * a break point.
 *
 * Ideally ARM would define several standard instruction sequences for
 * use as breakpoints.
 *
 * The BKPT instruction isn't much use to us, since its behaviour is
 * unpredictable on ARMv3 and lower.
 *
 * The ARM ARM says that for maximum compatibility, we should use undefined
 * instructions that look like 0x.7f...f. .
 */

#define GDB_BREAKPOINT		0xe6000011	/* Used by GDB 4.x */
#define IPKDB_BREAKPOINT_DEAD	0xe6000010	/* was used by IPKDB */
#define GDB5_BREAKPOINT		0xe7ffdefe	/* Used by GDB 5.0 */
#define GDB_THUMB_BREAKPOINT	0xdefe		/* Thumb in GDB */
#define KERNEL_BREAKPOINT	0xe7ffffff	/* Used by DDB */

/*
 * DTrace uses 0xe7fffef0 to 0xe7fffeff as breakpoints.
 * The first byte is used to encode a cond value.
 */
#define DTRACE_BREAKPOINT	0xe7fffef0
#define DTRACE_BREAKPOINT_MASK	0xfffffff0
#define DTRACE_IS_BREAKPOINT(insn)	((insn & DTRACE_BREAKPOINT_MASK) == DTRACE_BREAKPOINT)

#ifdef _ARM_ARCH_BE8
#define KBPT_ASM		".word 0xfedeffe7"
#else
#define KBPT_ASM		".word 0xe7ffdefe"
#endif

#define USER_BREAKPOINT		GDB_BREAKPOINT

/* End of trap.h */