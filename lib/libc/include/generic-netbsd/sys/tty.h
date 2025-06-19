/*	$NetBSD: tty.h,v 1.103 2022/10/26 23:41:49 riastradh Exp $	*/

/*-
 * Copyright (c) 2008 The NetBSD Foundation, Inc.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*-
 * Copyright (c) 1982, 1986, 1993
 *	The Regents of the University of California.  All rights reserved.
 * (c) UNIX System Laboratories, Inc.
 * All or some portions of this file are derived from material licensed
 * to the University of California by American Telephone and Telegraph
 * Co. or Unix System Laboratories, Inc. and are reproduced herein with
 * the permission of UNIX System Laboratories, Inc.
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
 *	@(#)tty.h	8.7 (Berkeley) 1/9/95
 */

#ifndef _SYS_TTY_H_
#define _SYS_TTY_H_

#include <sys/termios.h>
#include <sys/select.h>
#include <sys/selinfo.h>	/* For struct selinfo. */
#include <sys/mutex.h>
#include <sys/condvar.h>
#include <sys/queue.h>
#include <sys/callout.h>

/*
 * Clists are actually ring buffers. The c_cc, c_cf, c_cl fields have
 * exactly the same behaviour as in true clists.
 * if c_cq is NULL, the ring buffer has no TTY_QUOTE functionality
 * (but, saves memory and CPU time)
 *
 * *DON'T* play with c_cs, c_ce, c_cq, or c_cl outside tty_subr.c!!!
 */
struct clist {
	u_char	*c_cf;		/* points to first character */
	u_char	*c_cl;		/* points to next open character */
	u_char	*c_cs;		/* start of ring buffer */
	u_char	*c_ce;		/* c_ce + c_len */
	u_char	*c_cq;		/* N bits/bytes long, see tty_subr.c */
	int	c_cc;		/* count of characters in queue */
	int	c_cn;		/* total ring buffer length */
};

/* tty signal types */
enum ttysigtype {
	TTYSIG_PG1,
	TTYSIG_PG2,
	TTYSIG_LEADER,
	TTYSIG_COUNT
};

/*
 * Per-tty structure.
 *
 * Should be split in two, into device and tty drivers.
 * Glue could be masks of what to echo and circular buffer
 * (low, high, timeout).
 */
struct tty {
	TAILQ_ENTRY(tty) tty_link;	/* Link in global tty list. */
	struct	clist t_rawq;		/* Device raw input queue. */
	long	t_rawcc;		/* Raw input queue statistics. */
	kcondvar_t t_rawcv;		/* notifier */
	kcondvar_t t_rawcvf;		/* notifier */
	struct	clist t_canq;		/* Device canonical queue. */
	long	t_cancc;		/* Canonical queue statistics. */
	kcondvar_t t_cancv;		/* notifier */
	kcondvar_t t_cancvf;		/* notifier */
	struct	clist t_outq;		/* Device output queue. */
	long	t_outcc;		/* Output queue statistics. */
	kcondvar_t t_outcv;		/* notifier */
	kcondvar_t t_outcvf;		/* notifier */
	callout_t t_rstrt_ch;		/* for delayed output start */
	struct	linesw *t_linesw;	/* Interface to device drivers. */
	dev_t	t_dev;			/* Device. */
	int	t_state;		/* Device and driver (TS*) state. */
	int	t_wopen;		/* Processes waiting for open. */
	int	t_flags;		/* Tty flags. */
	int	t_qsize;		/* Tty character queue size */
	struct	pgrp *t_pgrp;		/* Foreground process group. */
	struct	session *t_session;	/* Enclosing session. */
	struct	selinfo t_rsel;		/* Tty read/oob select. */
	struct	selinfo t_wsel;		/* Tty write select. */
	struct	termios t_termios;	/* Termios state. */
	struct	winsize t_winsize;	/* Window size. */
					/* Start output. */
	void	(*t_oproc)(struct tty *);
					/* Set hardware state. */
	int	(*t_param)(struct tty *, struct termios *);
					/* Set hardware flow control. */
	int	(*t_hwiflow)(struct tty *, int);
	void	*t_sc;			/* XXX: net/if_sl.c:sl_softc. */
	short	t_column;		/* Tty output column. */
	short	t_rocount, t_rocol;	/* Tty. */
	int	t_hiwat;		/* High water mark. */
	int	t_lowat;		/* Low water mark. */
	short	t_gen;			/* Generation number. */
	sigset_t t_sigs[TTYSIG_COUNT];	/* Pending signals */
	int	t_sigcount;		/* # pending signals */
	TAILQ_ENTRY(tty) t_sigqueue;	/* entry on pending signal list */
	void	*t_softc;		/* pointer to driver's softc. */
	volatile unsigned t_refcnt;	/* reference count for constty */
};

#ifdef TTY_ALLOW_PRIVATE
#define	t_cc		t_termios.c_cc
#endif
#define	t_cflag		t_termios.c_cflag
#define	t_iflag		t_termios.c_iflag
#define	t_ispeed	t_termios.c_ispeed
#define	t_lflag		t_termios.c_lflag
#define	t_oflag		t_termios.c_oflag
#define	t_ospeed	t_termios.c_ospeed

#define	TTIPRI	25			/* Sleep priority for tty reads. */
#define	TTOPRI	26			/* Sleep priority for tty writes. */

#define	TTMASK	15
#define	OBUFSIZ	100
#define	TTYHOG	tp->t_qsize

#ifdef _KERNEL
#define	TTMAXHIWAT	roundup(tp->t_qsize << 1, 64)
#define	TTMINHIWAT	roundup(tp->t_qsize >> 3, 64)
#define	TTMAXLOWAT	(tp->t_qsize >> 2)
#define	TTMINLOWAT	(tp->t_qsize >> 5)
#define	TTROUND		64
#define	TTDIALOUT_MASK	0x80000		/* dialout=524288 in MAKEDEV.tmpl */
#define	TTCALLUNIT_MASK	0x40000		/* XXX: compat */
#define	TTUNIT_MASK	0x3ffff
#define	TTDIALOUT(d)	(minor(d) & TTDIALOUT_MASK)
#define	TTCALLUNIT(d)	(minor(d) & TTCALLUNIT_MASK)
#define	TTUNIT(d)	(minor(d) & TTUNIT_MASK)
#endif /* _KERNEL */

/* These flags are kept in t_state. */
#define	TS_SIGINFO	0x00001		/* Ignore mask on dispatch SIGINFO */
#define	TS_ASYNC	0x00002		/* Tty in async I/O mode. */
#define	TS_BUSY		0x00004		/* Draining output. */
#define	TS_CARR_ON	0x00008		/* Carrier is present. */
#define	TS_DIALOUT	0x00010		/* Tty used for dialout. */
#define	TS_FLUSH	0x00020		/* Outq has been flushed during DMA. */
#define	TS_ISOPEN	0x00040		/* Open has completed. */
#define	TS_TBLOCK	0x00080		/* Further input blocked. */
#define	TS_TIMEOUT	0x00100		/* Wait for output char processing. */
#define	TS_TTSTOP	0x00200		/* Output paused. */
#define	TS_XCLUDE	0x00400		/* Tty requires exclusivity. */

/* State for intra-line fancy editing work. */
#define	TS_BKSL		0x00800		/* State for lowercase \ work. */
#define	TS_CNTTB	0x01000		/* Counting tab width, ignore FLUSHO. */
#define	TS_ERASE	0x02000		/* Within a \.../ for PRTRUB. */
#define	TS_LNCH		0x04000		/* Next character is literal. */
#define	TS_TYPEN	0x08000		/* Retyping suspended input (PENDIN). */
#define	TS_LOCAL	(TS_BKSL | TS_CNTTB | TS_ERASE | TS_LNCH | TS_TYPEN)

/* for special line disciplines, like dev/sun/sunkbd.c */
#define	TS_KERN_ONLY	0x10000		/* Device is accessible by kernel
					 * only, deny all userland access */

#define	TS_CANCEL	0x20000		/* I/O cancelled pending close. */

/* Character type information. */
#define	ORDINARY	0
#define	CONTROL		1
#define	BACKSPACE	2
#define	NEWLINE		3
#define	TAB		4
#define	VTAB		5
#define	RETURN		6

struct speedtab {
	int sp_speed;			/* Speed. */
	int sp_code;			/* Code. */
};

/* Modem control commands (driver). */
#define	DMSET		0
#define	DMBIS		1
#define	DMBIC		2
#define	DMGET		3

/* Flags on a character passed to ttyinput. */
#define	TTY_CHARMASK	0x000000ff	/* Character mask */
#define	TTY_QUOTE	0x00000100	/* Character quoted */
#define	TTY_ERRORMASK	0xff000000	/* Error mask */
#define	TTY_FE		0x01000000	/* Framing error or BREAK condition */
#define	TTY_PE		0x02000000	/* Parity error */

/* Is tp controlling terminal for p? */
#define	isctty(p, tp)							\
	((p)->p_session == (tp)->t_session && (p)->p_lflag & PL_CONTROLT)

/* Is p in background of tp? */
#define	isbackground(p, tp)						\
	(isctty((p), (tp)) && (p)->p_pgrp != (tp)->t_pgrp)

/*
 * ttylist_head is defined here so that user-land has access to it.
 */
TAILQ_HEAD(ttylist_head, tty);		/* the ttylist is a TAILQ */

#ifdef _KERNEL

extern kmutex_t	tty_lock;
extern kmutex_t	constty_lock;
extern struct tty *volatile constty;

extern	int tty_count;			/* number of ttys in global ttylist */
extern	struct ttychars ttydefaults;

/* Symbolic sleep message strings. */
extern	 const char ttclos[];

int	 b_to_q(const u_char *, int, struct clist *);
void	 catq(struct clist *, struct clist *);
void	 clist_init(void);
int	 getc(struct clist *);
void	 ndflush(struct clist *, int);
int	 ndqb(struct clist *, int);
u_char	*nextc(struct clist *, u_char *, int *);
int	 putc(int, struct clist *);
int	 q_to_b(struct clist *, u_char *, int);
int	 unputc(struct clist *);

int	 nullmodem(struct tty *, int);
int	 tputchar(int, int, struct tty *);
int	 ttioctl(struct tty *, u_long, void *, int, struct lwp *);
int	 ttread(struct tty *, struct uio *, int);
void	 ttrstrt(void *);
int	 ttpoll(struct tty *, int, struct lwp *);
void	 ttsetwater(struct tty *);
int	 ttspeedtab(int, const struct speedtab *);
int	 ttstart(struct tty *);
void	 ttwakeup(struct tty *);
int	 ttwrite(struct tty *, struct uio *, int);
void	 ttychars(struct tty *);
int	 ttycheckoutq(struct tty *, int);
void	 ttycancel(struct tty *);
int	 ttyclose(struct tty *);
void	 ttyflush(struct tty *, int);
void	 ttygetinfo(struct tty *, int, char *, size_t);
void	 ttyputinfo(struct tty *, char *);
int	 ttyinput(int, struct tty *);
int	 ttyinput_wlock(int, struct tty *); /* XXX see wsdisplay.c */
int	 ttylclose(struct tty *, int);
int	 ttylopen(dev_t, struct tty *);
int	 ttykqfilter(dev_t, struct knote *);
int	 ttymodem(struct tty *, int);
int	 ttyopen(struct tty *, int, int);
int	 ttyoutput(int, struct tty *);
void	 ttypend(struct tty *);
void	 ttyretype(struct tty *);
void	 ttyrub(int, struct tty *);
int	 ttysleep(struct tty *, kcondvar_t *, bool, int);
int	 ttypause(struct tty *, int);
int	 ttywait(struct tty *);
int	 ttywflush(struct tty *);
void	 ttysig(struct tty *, enum ttysigtype, int);
void	 tty_attach(struct tty *);
void	 tty_detach(struct tty *);
void	 tty_init(void);
struct tty
	*tty_alloc(void);
void	 tty_free(struct tty *);
u_char	*firstc(struct clist *, int *);
bool	 ttypull(struct tty *);
int	 tty_unit(dev_t);
void	 tty_acquire(struct tty *);
void	 tty_release(struct tty *);

void	 ttylock(struct tty *);
void	 ttyunlock(struct tty *);
bool	 ttylocked(struct tty *);

int	clalloc(struct clist *, int, int);
void	clfree(struct clist *);

/* overwritten to be non-null if ptm(4) is present */

struct ptm_pty;
extern struct ptm_pty *ptm;

unsigned char tty_getctrlchar(struct tty *, unsigned /*which*/);
void tty_setctrlchar(struct tty *, unsigned /*which*/, unsigned char /*val*/);
int tty_try_xonxoff(struct tty *, unsigned char /*c*/);

#endif /* _KERNEL */

#endif /* !_SYS_TTY_H_ */