/*	$NetBSD: altq_rmclass.h,v 1.13 2022/05/24 20:50:18 andvar Exp $	*/
/*	$KAME: altq_rmclass.h,v 1.10 2003/08/20 23:30:23 itojun Exp $	*/

/*
 * Copyright (c) 1991-1997 Regents of the University of California.
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
 *	This product includes software developed by the Network Research
 *	Group at Lawrence Berkeley Laboratory.
 * 4. Neither the name of the University nor of the Laboratory may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
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
 */

#ifndef _ALTQ_ALTQ_RMCLASS_H_
#define	_ALTQ_ALTQ_RMCLASS_H_

#include <altq/altq_classq.h>

/* #pragma ident "@(#)rm_class.h  1.20     97/10/23 SMI" */

#ifdef __cplusplus
extern "C" {
#endif

#define	RM_MAXPRIO	8	/* Max priority */

#ifdef _KERNEL

typedef struct mbuf		mbuf_t;
typedef struct rm_ifdat		rm_ifdat_t;
typedef struct rm_class		rm_class_t;

struct red;

#define	RM_GETTIME(now) nanotime(&now)

#define	TS_LT(a, b) (((a)->tv_sec < (b)->tv_sec) ||  \
	(((a)->tv_nsec < (b)->tv_nsec) && ((a)->tv_sec <= (b)->tv_sec)))

#define	TS_DELTA(a, b, delta) do { \
	register int64_t	xxs;	\
							\
	delta = (int64_t)((a)->tv_nsec - (b)->tv_nsec); \
	if ((xxs = (a)->tv_sec - (b)->tv_sec)) { \
		switch (xxs) { \
		default: \
			/* if (xxs < 0) \
				printf("rm_class: bogus time values\n"); */ \
			delta = 0; \
			/* fall through */ \
		case 2: \
			delta += 1000000000; \
			/* fall through */ \
		case 1: \
			delta += 1000000000; \
			break; \
		} \
	} \
} while (0)

#define	TS_ADD_DELTA(a, delta, res) do { \
	register long xxns = (a)->tv_nsec + (long)(delta); \
	\
	(res)->tv_sec = (a)->tv_sec; \
	while (xxns >= 1000000000) { \
		++((res)->tv_sec); \
		xxns -= 1000000000; \
	} \
	(res)->tv_nsec = xxns; \
} while (0)

#define	RM_TIMEOUT	2	/* 1 Clock tick. */

#if 1
#define	RM_MAXQUEUED	1	/* this isn't used in ALTQ/CBQ */
#else
#define	RM_MAXQUEUED	16	/* Max number of packets downstream of CBQ */
#endif
#define	RM_MAXQUEUE	64	/* Max queue length */
#define	RM_FILTER_GAIN	5	/* log2 of gain, e.g., 5 => 31/32 */
#define	RM_POWER	(1 << RM_FILTER_GAIN)
#define	RM_MAXDEPTH	32
#define	RM_NS_PER_SEC	(1000000000)
#define	RM_PS_PER_SEC	(1000000000000)

typedef struct _rm_class_stats_ {
	u_int		handle;
	u_int		depth;

	struct pktcntr	xmit_cnt;	/* packets sent in this class */
	struct pktcntr	drop_cnt;	/* dropped packets */
	u_int		over;		/* # times went over limit */
	u_int		borrows;	/* # times tried to borrow */
	u_int		overactions;	/* # times invoked overlimit action */
	u_int		delays;		/* # times invoked delay actions */
} rm_class_stats_t;

/*
 * CBQ Class state structure
 */
struct rm_class {
	class_queue_t	*q_;		/* Queue of packets */
	rm_ifdat_t	*ifdat_;
	int		pri_;		/* Class priority. */
	int		depth_;		/* Class depth */
	uint64_t	ps_per_byte_;	/* PicoSeconds per byte. */
	u_int		maxrate_;	/* Bytes per second for this class. */
	u_int		allotment_;	/* Fraction of link bandwidth. */
	u_int		w_allotment_;	/* Weighted allotment for WRR */
	int		bytes_alloc_;	/* Allocation for round of WRR */

	int64_t		avgidle_;
	int64_t		maxidle_;
	int64_t		minidle_;
	int64_t		offtime_;
	int		sleeping_;	/* != 0 if delaying */
	int		qthresh_;	/* Queue threshold for formal link sharing */
	int		leaf_;		/* Note whether leaf class or not.*/

	rm_class_t	*children_;	/* Children of this class */
	rm_class_t	*next_;		/* Next pointer, used if child */

	rm_class_t	*peer_;		/* Peer class */
	rm_class_t	*borrow_;	/* Borrow class */
	rm_class_t	*parent_;	/* Parent class */

	void	(*overlimit)(struct rm_class *, struct rm_class *);
	void	(*drop)(struct rm_class *);       /* Class drop action. */

	struct red	*red_;		/* RED state pointer */
	struct altq_pktattr *pktattr_;	/* saved hdr used by RED/ECN */
	int		flags_;

	int64_t		last_pkttime_;	/* saved pkt_time */
	struct timespec	undertime_;	/* time can next send */
	struct timespec	last_;		/* time last packet sent */
	struct timespec	overtime_;
	struct callout	callout_; 	/* for timeout() calls */

	rm_class_stats_t stats_;	/* Class Statistics */
};

/*
 * CBQ Interface state
 */
struct rm_ifdat {
	int		queued_;	/* # pkts queued downstream */
	int		efficient_;	/* Link Efficiency bit */
	int		wrr_;		/* Enable Weighted Round-Robin */
	uint64_t	ps_per_byte_;	/* Link byte speed. */
	int		maxqueued_;	/* Max packets to queue */
	int		maxpkt_;	/* Max packet size. */
	int		qi_;		/* In/out pointers for downstream */
	int		qo_;		/* packets */

	/*
	 * Active class state and WRR state.
	 */
	rm_class_t	*active_[RM_MAXPRIO];	/* Active cl's in each pri */
	int		na_[RM_MAXPRIO];	/* # of active cl's in a pri */
	int		num_[RM_MAXPRIO];	/* # of cl's per pri */
	int		alloc_[RM_MAXPRIO];	/* Byte Allocation */
	u_long		M_[RM_MAXPRIO];		/* WRR weights. */

	/*
	 * Network Interface/Solaris Queue state pointer.
	 */
	struct ifaltq	*ifq_;
	rm_class_t	*default_;	/* Default Pkt class, BE */
	rm_class_t	*root_;		/* Root Link class. */
	rm_class_t	*ctl_;		/* Control Traffic class. */
	void		(*restart)(struct ifaltq *);	/* Restart routine. */

	/*
	 * Current packet downstream packet state and dynamic state.
	 */
	rm_class_t	*borrowed_[RM_MAXQUEUED]; /* Class borrowed last */
	rm_class_t	*class_[RM_MAXQUEUED];	/* class sending */
	int		curlen_[RM_MAXQUEUED];	/* Current pktlen */
	struct timespec	now_[RM_MAXQUEUED];	/* Current packet time. */
	int		is_overlimit_[RM_MAXQUEUED];/* Current packet time. */

	int		cutoff_;	/* Cut-off depth for borrowing */

	struct timespec	ifnow_;		/* expected xmit completion time */
#if 1 /* ALTQ4PPP */
	int		maxiftime_;	/* max delay inside interface */
#endif
        rm_class_t	*pollcache_;	/* cached rm_class by poll operation */
};

/* flags for rmc_init and rmc_newclass */
/* class flags */
#define	RMCF_RED		0x0001
#define	RMCF_ECN		0x0002
#define	RMCF_RIO		0x0004
#define	RMCF_FLOWVALVE		0x0008	/* use flowvalve (aka penalty-box) */
#define	RMCF_CLEARDSCP		0x0010  /* clear diffserv codepoint */

/* flags for rmc_init */
#define	RMCF_WRR		0x0100
#define	RMCF_EFFICIENT		0x0200

#define	is_a_parent_class(cl)	((cl)->children_ != NULL)

extern rm_class_t *rmc_newclass(int, struct rm_ifdat *, uint64_t,
				void (*)(struct rm_class *, struct rm_class *),
				int, struct rm_class *, struct rm_class *,
				u_int, int, u_int, int, int);
extern void	rmc_delete_class(struct rm_ifdat *, struct rm_class *);
extern int 	rmc_modclass(struct rm_class *, uint64_t, int,
			     u_int, int, u_int, int);
extern int	rmc_init(struct ifaltq *, struct rm_ifdat *, uint64_t,
			 void (*)(struct ifaltq *),
			 int, int, u_int, int, u_int, int);
extern int	rmc_queue_packet(struct rm_class *, mbuf_t *);
extern mbuf_t	*rmc_dequeue_next(struct rm_ifdat *, int);
extern void	rmc_update_class_util(struct rm_ifdat *);
extern void	rmc_delay_action(struct rm_class *, struct rm_class *);
extern void	rmc_dropall(struct rm_class *);
extern int	rmc_get_weight(struct rm_ifdat *, int);

#endif /* _KERNEL */

#ifdef __cplusplus
}
#endif

#endif /* _ALTQ_ALTQ_RMCLASS_H_ */