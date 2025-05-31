/*	$NetBSD: frame.h,v 1.31 2019/02/18 01:12:23 thorpej Exp $	*/

/*
 * Copyright (c) 1988 University of Utah.
 * Copyright (c) 1982, 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department.
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
 * from: Utah $Hdr: frame.h 1.8 92/12/20$
 *
 *	@(#)frame.h	8.1 (Berkeley) 6/10/93
 */

#ifndef	_M68K_FRAME_H_
#define	_M68K_FRAME_H_

#include <m68k/cpuframe.h>

/* common frame size */
#define	CFSIZE		(sizeof(struct frame) - sizeof(union F_u))
#define	NFMTSIZE	9

#define	FMT0		0x0
#define	FMT1		0x1
#define	FMT2		0x2
#define	FMT3		0x3
#define	FMT4		0x4
#define	FMT7		0x7
#define	FMT8		0x8
#define	FMT9		0x9
#define	FMTA		0xA
#define	FMTB		0xB

/* frame specific info sizes */
#define	FMT0SIZE	0
#define	FMT1SIZE	0
#define	FMT2SIZE	sizeof(struct fmt2)
#define	FMT3SIZE	sizeof(struct fmt3)
#define	FMT4SIZE	sizeof(struct fmt4)
#define	FMT7SIZE	sizeof(struct fmt7)
#define	FMT8SIZE	sizeof(struct fmt8)
#define	FMT9SIZE	sizeof(struct fmt9)
#define	FMTASIZE	sizeof(struct fmtA)
#define	FMTBSIZE	sizeof(struct fmtB)

#define	V_BUSERR	0x008
#define	V_ADDRERR	0x00C
#define	V_TRAP1		0x084

/* 68010 SSW bits */
#define SSW1_RR		0x8000
#define SSW1_IF		0x2000
#define SSW1_DF		0x1000
#define SSW1_RM		0x0800
#define SSW1_HI		0x0400
#define SSW1_BX		0x0200
#define SSW1_RW		0x0100
#define SSW1_FCMASK	0x000F

/* 68020/68030 SSW bits */
#define	SSW_RC		0x2000
#define	SSW_RB		0x1000
#define	SSW_DF		0x0100
#define	SSW_RM		0x0080
#define	SSW_RW		0x0040
#define	SSW_FCMASK	0x0007

/* 68040 SSW bits */
#define	SSW4_CP		0x8000
#define	SSW4_CU		0x4000
#define	SSW4_CT		0x2000
#define	SSW4_CM		0x1000
#define	SSW4_MA		0x0800
#define	SSW4_ATC	0x0400
#define	SSW4_LK		0x0200
#define	SSW4_RW		0x0100
#define SSW4_WBSV	0x0080	/* really in WB status, not SSW */
#define	SSW4_SZMASK	0x0060
#define	SSW4_SZLW	0x0000
#define	SSW4_SZB	0x0020
#define	SSW4_SZW	0x0040
#define	SSW4_SZLN	0x0060
#define	SSW4_TTMASK	0x0018
#define	SSW4_TTNOR	0x0000
#define	SSW4_TTM16	0x0008
#define	SSW4_TMMASK	0x0007
#define	SSW4_TMDCP	0x0000
#define	SSW4_TMUD	0x0001
#define	SSW4_TMUC	0x0002
#define	SSW4_TMKD	0x0005
#define	SSW4_TMKC	0x0006

/* 060 Fault Status Long Word (FPSP) */

#define FSLW_MA		0x08000000
#define FSLW_LK		0x02000000
#define FSLW_RW		0x01800000

#define FSLW_RW_R	0x01000000
#define FSLW_RW_W	0x00800000

#define FSLW_SIZE	0x00600000
/*
 * We better define the FSLW_SIZE values here, as the table given in the 
 * MC68060UM/AD rev. 0/1 p. 8-23 is wrong, and was corrected in the errata 
 * document.
 */
#define FSLW_SIZE_LONG	0x00000000
#define FSLW_SIZE_BYTE	0x00200000
#define FSLW_SIZE_WORD	0x00400000
#define FSLW_SIZE_MV16	0x00600000

#define FLSW_TT		0x00180000
#define FSLW_TM		0x00070000
#define FSLW_TM_SV	0x00040000



#define FSLW_IO		0x00008000
#define FSLW_PBE	0x00004000
#define FSLW_SBE	0x00002000
#define FSLW_PTA	0x00001000
#define FSLW_PTB 	0x00000800
#define FSLW_IL 	0x00000400
#define FSLW_PF 	0x00000200
#define FSLW_SP 	0x00000100
#define FSLW_WP 	0x00000080
#define FSLW_TWE 	0x00000040
#define FSLW_RE 	0x00000020
#define FSLW_WE 	0x00000010
#define FSLW_TTR 	0x00000008
#define FSLW_BPE 	0x00000004
#define FSLW_SEE 	0x00000001

/* struct fpframe060 */
#define FPF6_FMT_NULL	0x00
#define FPF6_FMT_IDLE	0x60
#define FPF6_FMT_EXCP	0xe0

#define	FPF6_V_BSUN	0
#define	FPF6_V_INEX12	1
#define	FPF6_V_DZ	2
#define	FPF6_V_UNFL	3
#define	FPF6_V_OPERR	4
#define	FPF6_V_OVFL	5
#define	FPF6_V_SNAN	6
#define	FPF6_V_UNSUP	7

#if defined(_KERNEL)

#include <m68k/signal.h>

#if defined(COMPAT_16)
/*
 * Stack frame layout when delivering a signal.
 */
struct sigframe_sigcontext {
	int	sf_ra;			/* handler return address */
	int	sf_signum;		/* signal number for handler */
	int	sf_code;		/* additional info for handler */
	struct sigcontext *sf_scp;	/* context pointer for handler */
	struct sigcontext sf_sc;	/* actual context */
	struct sigstate sf_state;	/* state of the hardware */
};
#endif

struct sigframe_siginfo {
	int		sf_ra;		/* return address for handler */
	int		sf_signum;	/* "signum" argument for handler */
	siginfo_t	*sf_sip;	/* "sip" argument for handler */
	ucontext_t	*sf_ucp;	/* "ucp" argument for handler */
	siginfo_t	sf_si;		/* actual saved siginfo */
	ucontext_t	sf_uc;		/* actual saved ucontext */
};

/*
 * Utility function to relocate the initial frame, make room to restore an
 * exception frame and reenter the syscall.
 */
void	reenter_syscall(struct frame *, int) __attribute__((__noreturn__));

/*
 * Create an FPU "idle" frame for use by cpu_setmcontext()
 */
extern void m68k_make_fpu_idle_frame(void);
extern struct fpframe m68k_cached_fpu_idle_frame;

void	*getframe(struct lwp *, int, int *);
void	buildcontext(struct lwp *, void *, void *);
#ifdef COMPAT_16
void	sendsig_sigcontext(const ksiginfo_t *, const sigset_t *);
#endif

#ifdef M68040
int	m68040_writeback(struct frame *, int);
#endif

#if defined(__mc68010__)
/*
 * Restartable atomic sequence-cased compare-and-swap for atomic_cas ops
 * and locking primitives.  We defined this here because it manipulates a
 * "clockframe" as prepared by interrupt handlers.
 */
extern char	_atomic_cas_ras_start;
extern char	_atomic_cas_ras_end;

#define ATOMIC_CAS_CHECK(cfp)						\
do {									\
	if (! CLKF_USERMODE(cfp) &&					\
	    (CLKF_PC(cfp) < (u_long)&_atomic_cas_ras_end &&		\
	     CLKF_PC(cfp) > (u_long)&_atomic_cas_ras_start)) {		\
	    	(cfp)->cf_pc = (u_long)&_atomic_cas_ras_start;		\
	}								\
} while (/*CONSTCOND*/0)
#else
#define	ATOMIC_CAS_CHECK(cfp)	/* nothing */
#endif /* __mc68010__ */

#endif	/* _KERNEL */

#endif	/* _M68K_FRAME_H_ */