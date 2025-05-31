/*	$NetBSD: trap.h,v 1.20 2021/01/24 07:36:54 mrg Exp $ */

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratory.
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
 *	@(#)trap.h	8.1 (Berkeley) 6/11/93
 */
/*
 * Sun4m support by Aaron Brown, Harvard University.
 * Changes Copyright (c) 1995 The President and Fellows of Harvard College.
 * All rights reserved.
 */

#ifndef	_MACHINE_TRAP_H
#define	_MACHINE_TRAP_H

/*	trap		vec	  (pri) description	*/
#define	T_RESET		0x00	/* (1) not actually vectored; jumps to 0 */
#define	T_TEXTFAULT	0x01	/* (2) address fault during instr fetch */
#define	T_ILLINST	0x02	/* (3) illegal instruction */
#define	T_PRIVINST	0x03	/* (4) privileged instruction */
#define	T_FPDISABLED	0x04	/* (5) fp instr while fp disabled */
#define	T_WINOF		0x05	/* (6) register window overflow */
#define	T_WINUF		0x06	/* (7) register window underflow */
#define	T_ALIGN		0x07	/* (8) address not properly aligned */
#define	T_FPE		0x08	/* (9) floating point exception */
#define	T_DATAFAULT	0x09	/* (10) address fault during data fetch */
#define	T_TAGOF		0x0a	/* (11) tag overflow */
/*			0x0b	   unused */
/*			0x0c	   unused */
/*			0x0d	   unused */
/*			0x0e	   unused */
/*			0x0f	   unused */
/*			0x10	   unused */
#define	T_L1INT		0x11	/* (27) level 1 interrupt */
#define	T_L2INT		0x12	/* (26) level 2 interrupt */
#define	T_L3INT		0x13	/* (25) level 3 interrupt */
#define	T_L4INT		0x14	/* (24) level 4 interrupt */
#define	T_L5INT		0x15	/* (23) level 5 interrupt */
#define	T_L6INT		0x16	/* (22) level 6 interrupt */
#define	T_L7INT		0x17	/* (21) level 7 interrupt */
#define	T_L8INT		0x18	/* (20) level 8 interrupt */
#define	T_L9INT		0x19	/* (19) level 9 interrupt */
#define	T_L10INT	0x1a	/* (18) level 10 interrupt */
#define	T_L11INT	0x1b	/* (17) level 11 interrupt */
#define	T_L12INT	0x1c	/* (16) level 12 interrupt */
#define	T_L13INT	0x1d	/* (15) level 13 interrupt */
#define	T_L14INT	0x1e	/* (14) level 14 interrupt */
#define	T_L15INT	0x1f	/* (13) level 15 interrupt */
/*			0x20	   unused */
#define	T_TEXTERROR	0x21	/* (3) address fault during instr fetch */
/*			0x22	   unused */
/*			0x23	   unused */
#define	T_CPDISABLED	0x24	/* (5) coprocessor instr while disabled */
#define	T_UNIMPLFLUSH	0x25	/* Unimplemented FLUSH */
/*	through		0x27	   unused */
#define	T_CPEXCEPTION	0x28	/* (11) coprocessor exception */
#define	T_DATAERROR	0x29	/* (12) address error during data fetch */
#define T_IDIV0		0x2a	/* divide by zero (from hw [su]div instr) */
#define T_STOREBUFFAULT	0x2b	/* SuperSPARC: Store buffer copy-back fault */
/*			0x2c	   unused */
/*	through		0x7f	   unused */

/* beginning of `user' vectors (from trap instructions) - all priority 12 */
#define	T_SUN_SYSCALL	0x80	/* system call */
#define	T_BREAKPOINT	0x81	/* breakpoint `instruction' */
#define	T_DIV0		0x82	/* explicitly signal division by zero */
#define	T_FLUSHWIN	0x83	/* flush windows */
#define	T_CLEANWIN	0x84	/* request new windows to be cleaned */
#define	T_RANGECHECK	0x85	/* explicitly signal a range checking error */
#define	T_FIXALIGN	0x86	/* fix up unaligned accesses */
#define	T_INTOF		0x87	/* explicitly signal integer overflow */

/* 0x89..0x8f - reserved for the OS */
#define	T_BSD_SYSCALL	0x89	/* BSD system call */
#define	T_KGDB_EXEC	0x8a	/* for kernel gdb */
#define	T_DBPAUSE	0x8b	/* for smp kernel debugging */

/* 0x90..0x9f - reserved, will never be specified */

/* 0xa0..0xff are currently unallocated */

#ifdef _KERNEL			/* pseudo traps for locore.s */
#define	T_RWRET		-1	/* need first user window for trap return */
#define	T_AST		-2	/* no-op, just needed reschedule or profile */
#endif

/* flags to system call (flags in %g1 along with syscall number) */
#define	SYSCALL_G2RFLAG	0x400	/* on success, return to %g2 rather than npc */
#define	SYSCALL_G7RFLAG	0x800	/* use %g7 as above (deprecated) */
#define	SYSCALL_G5RFLAG	0xc00	/* use %g5 as above (only ABI compatible way) */

/*
 * `software trap' macros to keep people happy (sparc v8 manual says not
 * to set the upper bits).
 */
#define	ST_SYSCALL	(T_SUN_SYSCALL & 0x7f)
#define	ST_BREAKPOINT	(T_BREAKPOINT & 0x7f)
#define	ST_DIV0		(T_DIV0 & 0x7f)
#define	ST_FLUSHWIN	(T_FLUSHWIN & 0x7f)

#if defined(_KERNEL) && !defined(_LOCORE)
extern const char *trap_type[];
extern struct fpstate initfpstate;
#endif

#endif /* _MACHINE_TRAP_H_ */