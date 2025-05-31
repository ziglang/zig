/*	$NetBSD: trap.h,v 1.12 2018/12/19 13:57:50 maxv Exp $ */

/*
 * Copyright (c) 1996-1999 Eduardo Horvath
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR  ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR  BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */


#ifndef	_MACHINE_TRAP_H
#define	_MACHINE_TRAP_H

/*	trap		vec	  (pri) description	*/
/*			0x000	   unused */
#define	T_POR		0x001	/* (0) power on reset */
#define T_WDR		0x002	/* (1) watchdog reset */
#define T_XIR		0x003	/* (1) externally initiated reset */
#define T_SIR		0x004	/* (1) software initiated reset */
#define T_RED_EXCEPTION	0x005	/* (1) RED state exception */
/*			0x006	   unused */
/*			0x007	   unused */
#define T_INST_EXCEPT	0x008	/* (5) instruction access exception */
#define T_TEXTFAULT	0x009	/* (2) ? Text fault */
#define T_INST_ERROR	0x00a	/* (3) instruction access error */
/*			0x00b	   unused */
/*	through		0x00f	   unused */
#define T_ILLINST	0x010	/* (7) illegal instruction */
#define T_PRIVINST	0x011	/* (6) privileged opcode */
/*			0x012	   unused */
/*	through		0x01f	   unused */
#define T_FPDISABLED	0x020	/* (8) fpu disabled */
#define T_FP_IEEE_754	0x021	/* (11) ieee 754 exception */
#define T_FP_OTHER	0x022	/* (11) other fp exception */
#define T_TAGOF		0x023	/* (14) tag overflow */
#define T_CLEAN_WINDOW	0x024	/* (10) clean window exception */
/*	through		0x027	   unused */
#define T_IDIV0		0x028	/* (15) division by 0 */
/*			0x029	   unused */
/*	through		0x02f	   unused */
#define	T_DATAFAULT	0x030	/* (12) address fault during data fetch */
#define	T_DATA_MMU_MISS	0x031	/* (N/A) address fault during data fetch [USIII] */
#define	T_DATA_ERROR	0x032	/* (12) data access error */
#define	T_DATA_PROT	0x033	/* (12) Data protection ??? */
#define	T_ALIGN		0x034	/* (10) address not properly aligned */
#define	T_LDDF_ALIGN	0x035	/* (10) LDDF address not properly aligned */
#define	T_STDF_ALIGN	0x036	/* (10) STDF address not properly aligned */
#define T_PRIVACT	0x037	/* (11) privileged action */
/*			0x038	   unused */
/*	through		0x03f	   unused */
#define T_ASYNC_ERROR	0x040	/* ???? */
#define	T_L1INT		0x041	/* (31) level 1 interrupt */
#define	T_L2INT		0x042	/* (30) level 2 interrupt */
#define	T_L3INT		0x043	/* (29) level 3 interrupt */
#define	T_L4INT		0x044	/* (28) level 4 interrupt */
#define	T_L5INT		0x045	/* (27) level 5 interrupt */
#define	T_L6INT		0x046	/* (26) level 6 interrupt */
#define	T_L7INT		0x047	/* (25) level 7 interrupt */
#define	T_L8INT		0x048	/* (24) level 8 interrupt */
#define	T_L9INT		0x049	/* (23) level 9 interrupt */
#define	T_L10INT	0x04a	/* (22) level 10 interrupt */
#define	T_L11INT	0x04b	/* (21) level 11 interrupt */
#define	T_L12INT	0x04c	/* (20) level 12 interrupt */
#define	T_L13INT	0x04d	/* (19) level 13 interrupt */
#define	T_L14INT	0x04e	/* (18) level 14 interrupt */
#define	T_L15INT	0x04f	/* (17) level 15 interrupt */
/*			0x050	   unused */
/*	through		0x05f	   unused */
#define T_INTVEC	0x060	/* (16) interrupt vector [Interrupt Global Regs]*/
#define T_PA_WATCHPT	0x061	/* (12) Physical addr data watchpoint */
#define T_VA_WATCHPT	0x062	/* (11) Virtual addr data watchpoint */
#define T_ECCERR	0x063	/* (33) ECC correction error */
#define T_FIMMU_MISS	0x064	/* (2) fast instruction access MMU miss */
/*	through		0x067	   unused */
#define T_FDMMU_MISS	0x068	/* (2) fast data access MMU miss */
/*	through		0x06b	   unused */
#define T_FDMMU_PROT	0x06c	/* (2) fast data access protection */
/*	through		0x06f	   unused */
/*  0x070...0x07f implementation dependent exceptions */
#define T_FAST_ECC_ERROR 0x070	/* (2) fast ECC error [USIII] */
#define T_DC_PAR_ERR	0x071	/* (2) dcache parity error [USIII] */
#define T_IC_PAR_ERR	0x072	/* (2) icache parity error [USIII] */
#define T_CPU_MONDO	0x07c	/* cpu mondo [SUN4V] */
#define T_SPILL_N_NORM	0x080	/* (9) spill (n=0..7) normal */
/*	through		0x09f	   unused */
#define T_SPILL_N_OTHER	0x0a0	/* (9) spill (n=0..7) other */
/*	through		0x0bF	   unused */
#define T_FILL_N_NORM	0x0c0	/* (9) fill (n=0..7) normal */
/*	through		0x0dF	   unused */
#define T_FILL_N_OTHER	0x0e0	/* (9) fill (n=0..7) other */
/*	through		0x0fF	   unused */

/* beginning of `user' vectors (from trap instructions) - all priority 16 */
#define	T_SUN_SYSCALL	0x100	/* system call */
#define	T_BREAKPOINT	0x101	/* breakpoint `instruction' */
#define	T_DIV0		0x102	/* division routine was handed 0 */
#define	T_FLUSHWIN	0x103	/* flush windows */
#define	T_CLEANWIN	0x104	/* provide clean windows */
#define	T_RANGECHECK	0x105	/* ? */
#define	T_FIXALIGN	0x106	/* fix up unaligned accesses */
#define	T_INTOF		0x107	/* integer overflow ? */
#define	T_BSD_SYSCALL	0x109	/* BSD system call */
#define	T_KGDB_EXEC	0x10a	/* for kernel gdb */

/* 0x10c..0x1ff are currently unallocated, except the following */
#define T_GETCC			0x132
#define T_SETCC			0x133
#define T_SVID_SYSCALL		0x164
#define	T_SPARC_INTL_SYSCALL	0x165
#define	T_OS_VENDOR_SYSCALL	0x166
#define	T_HW_OEM_SYSCALL	0x167
#define T_RTF_DEF_TRAP		0x168

#ifdef _KERNEL			/* pseudo traps for locore.s */
#define	T_RWRET		-1	/* need first user window for trap return */
#define	T_AST		-2	/* no-op, just needed reschedule or profile */
#endif

/* flags to system call (flags in %g1 along with syscall number) */
#define	SYSCALL_G2RFLAG	0x400	/* on success, return to %g2 rather than npc */
#define	SYSCALL_G7RFLAG	0x800	/* use %g7 as above (deprecated) */
#define	SYSCALL_G5RFLAG	0xc00	/* use %g5 as above (only ABI compatible way) */

/* Software traps */
#ifdef SUN4V
#define ST_FAST_TRAP            0x80
#define ST_MMU_MAP_ADDR         0x83
#define ST_MMU_UNMAP_ADDR	0x84
#define ST_CORE_TRAP	        0xff
#endif

/*
 * `software trap' macros to keep people happy (sparc v8 manual says not
 * to set the upper bits). Correct mask is 0xff for v9, but all values
 * here are small enough - so keep it the same as the sparc port.
 */
#define	ST_BREAKPOINT	(T_BREAKPOINT & 0x7f)
#define	ST_DIV0		(T_DIV0 & 0x7f)
#define	ST_FLUSHWIN	(T_FLUSHWIN & 0x7f)
#define	ST_SYSCALL	(T_SUN_SYSCALL & 0x7f)

#endif /* _MACHINE_TRAP_H_ */