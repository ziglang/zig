/*	$NetBSD: altq_jobs.h,v 1.5 2010/04/09 19:32:45 plunky Exp $	*/
/*	$KAME: altq_jobs.h,v 1.6 2003/07/10 12:07:48 kjc Exp $	*/
/*
 * Copyright (c) 2001, Rector and Visitors of the University of 
 * Virginia.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, 
 * with or without modification, are permitted provided 
 * that the following conditions are met:
 *
 * Redistributions of source code must retain the above 
 * copyright notice, this list of conditions and the following 
 * disclaimer. 
 *
 * Redistributions in binary form must reproduce the above 
 * copyright notice, this list of conditions and the following 
 * disclaimer in the documentation and/or other materials provided 
 * with the distribution. 
 *
 * Neither the name of the University of Virginia nor the names 
 * of its contributors may be used to endorse or promote products 
 * derived from this software without specific prior written 
 * permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND 
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
 * DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE 
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, 
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND 
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING 
 * IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF 
 * THE POSSIBILITY OF SUCH DAMAGE.
 */
/*                                                                     
 * JoBS - altq prototype implementation                                
 *                                                                     
 * Author: Nicolas Christin <nicolas@cs.virginia.edu>
 *
 * JoBS algorithms originally devised and proposed by		       
 * Nicolas Christin and Jorg Liebeherr.
 * Grateful Acknowledgments to Tarek Abdelzaher for his help and       
 * comments, and to Kenjiro Cho for some helpful advice.
 * Contributed by the Multimedia Networks Group at the University
 * of Virginia. 
 *
 * Papers and additional info can be found at 
 * http://qosbox.cs.virginia.edu
 *                                                                      
 */ 							               

#ifndef _ALTQ_ALTQ_JOBS_H_
#define	_ALTQ_ALTQ_JOBS_H_

#include <altq/altq.h>
#include <altq/altq_classq.h>

#ifdef __cplusplus
extern "C" {
#endif

#define	JOBS_MAXPRI	16	/* upper limit on the number of priorities */
#define SCALE_RATE	32
#define SCALE_LOSS	32
#define SCALE_SHARE	16
#define GRANULARITY	1000000 /* microseconds */
#define ALTQ_INFINITY	LLONG_MAX	/* not infinite, just large */

/* list of packet arrival times */
struct _tsentry;
typedef TAILQ_HEAD(_timestamps, _tsentry) TSLIST;  
typedef struct _tsentry {
	TAILQ_ENTRY(_tsentry) ts_list;
	uint64_t	timestamp;
} TSENTRY;

/*
 * timestamp list macros
 */

#define tslist_first(s)	TAILQ_FIRST(s)
#define tslist_last(s)	TAILQ_LAST(s, _timestamps)
#define tslist_empty(s) TAILQ_EMPTY(s)

/*
 * scaling/conversion macros
 * none of these macros present side-effects, hence the lowercase
 */

#define	secs_to_ticks(x)	((x) * machclk_freq)
#define ticks_to_secs(x)	((x) / machclk_freq)
#define invsecs_to_invticks(x)	ticks_to_secs(x)
#define invticks_to_invsecs(x)	secs_to_ticks(x)
#define bits_to_bytes(x)	((x) >> 3)
#define bytes_to_bits(x)	((x) << 3)
#define scale_rate(x)		((x) << SCALE_RATE)
#define unscale_rate(x)		((x) >> SCALE_RATE)
#define bps_to_internal(x)	(invsecs_to_invticks(bits_to_bytes(scale_rate(x))))
#define internal_to_bps(x)	(unscale_rate(invticks_to_invsecs(bytes_to_bits(x))))

/*
 * this macro takes care of possible wraparound
 * effects in the computation of a delay
 * no side-effects here either
 */

#define delay_diff(x, y) ((x >= y)?(x - y):((ULLONG_MAX-y)+x+1))

/*
 * additional macros (PKTCNTR_ADD can be found
 * in the original distribution)
 */

#define PKTCNTR_SUB(cntr, len) do {                                     \
        (cntr)->packets--;                                              \
        (cntr)->bytes -= len;                                           \
} while (/*CONSTCOND*/ 0)

#define PKTCNTR_RESET(cntr) do {                                        \
        (cntr)->packets = 0;                                            \
        (cntr)->bytes = 0;                                              \
} while (/*CONSTCOND*/ 0)

struct jobs_interface {
	char	jobs_ifname[IFNAMSIZ];	/* interface name (e.g., fxp0) */
	u_long	arg;			/* request-specific argument */
};
struct jobs_attach {
	struct	jobs_interface iface;
	u_int	bandwidth;		/* link bandwidth in bits/sec */
	u_int	qlimit;			/* buffer size in packets */
	u_int	separate;		/* separate buffers flag */
};

struct jobs_add_class {
	struct	jobs_interface	iface;
	int	pri;			/* priority (0 is the lowest) */
	int	flags;			/* misc flags (see below) */

	/*
	 * Delay Bound (-1 = NO ADC) is provided in us,
	 * and is converted to clock ticks
	 */
	int64_t	cl_adc;

	/*
	 * Loss Rate Bound (-1 = NO ALC) is provided in fraction of 1
	 * and is converted to a fraction of  2^(SCALE_LOSS)
	 */
	int64_t	cl_alc;

	/*
	 * lower bound on throughput (-1 = no ARC)
	 * is provided in (string) and
	 * is converted to internal format
	 */
	int64_t	cl_arc;

	/* RDC weight (-1 = NO RDC) - no unit */
	int64_t	cl_rdc;

	/* RLC weight (-1 = NO RLC) - no unit */
	int64_t	cl_rlc;

	u_long	class_handle;		/* return value */
};

/* jobs class flags */
#define	JOCF_CLEARDSCP		0x0010  /* clear diffserv codepoint */
#define	JOCF_DEFAULTCLASS	0x1000	/* default class */

/* special class handles */
#define	JOBS_NULLCLASS_HANDLE	0

struct jobs_delete_class {
	struct	jobs_interface	iface;
	u_long	class_handle;
};

struct jobs_modify_class {
	struct	jobs_interface	iface;
	u_long	class_handle;
	int	pri;

	/* 
	 * Delay Bound (-1 = NO ADC) is provided in us,
	 * and is converted to clock ticks
	 */
	int64_t	cl_adc;

	/*
	 * Loss Rate Bound (-1 = NO ALC) is provided in fraction of 1
	 * and is converted to a fraction of  2^(SCALE_LOSS)
	 */
	int64_t	cl_alc;

	/*
	 * lower bound on throughput (-1 = no ARC)
	 * is provided in (string) and
	 * is converted to internal format
	 */
	int64_t	cl_arc;

	/* RDC weight (-1 = NO RDC) - no unit */
	int64_t	cl_rdc;

	/* RLC weight (-1 = NO RLC) - no unit */
	int64_t	cl_rlc;

	int	flags;
};

struct jobs_add_filter {
	struct	jobs_interface iface;
	u_long	class_handle;
#ifdef ALTQ3_CLFIER_COMPAT
	struct	flow_filter filter;
#endif
	u_long	filter_handle;		/* return value */
};

struct jobs_delete_filter {
	struct	jobs_interface iface;
	u_long	filter_handle;
};

struct class_stats {
	u_int	adc_violations;
	u_int	totallength;
	u_int 	period;
	u_int	qlength;

	u_long	class_handle;

	int64_t	service_rate;		/* bps that should be out */

	u_int64_t	avg_cycles_dequeue;
	u_int64_t	avg_cycles_enqueue;
	u_int64_t	avg_cycles2_dequeue;
	u_int64_t	avg_cycles2_enqueue;
	u_int64_t	avgdel;		/* in us */
	u_int64_t	bc_cycles_dequeue;
	u_int64_t	bc_cycles_enqueue;
	u_int64_t	busylength;	/* in ms */
	u_int64_t	lastdel;	/* in us */
	u_int64_t	total_dequeued;
	u_int64_t	total_enqueued;
	u_int64_t	wc_cycles_dequeue;
	u_int64_t	wc_cycles_enqueue;

	struct	pktcntr	arrival;	/* rin+dropped */
	struct	pktcntr	arrivalbusy;
	struct	pktcntr	rin;		/* dropped packet counter */
	struct	pktcntr	rout;		/* transmitted packet counter */
	struct	pktcntr	dropcnt;	/* dropped packet counter */
};

struct jobs_class_stats {
	struct	class_stats *stats;	/* pointer to stats array */
	int	maxpri;			/* in/out */
	struct	jobs_interface iface;
};

#define	JOBS_IF_ATTACH		_IOW('Q', 1, struct jobs_attach)
#define	JOBS_IF_DETACH		_IOW('Q', 2, struct jobs_interface)
#define	JOBS_ENABLE		_IOW('Q', 3, struct jobs_interface)
#define	JOBS_DISABLE		_IOW('Q', 4, struct jobs_interface)
#define	JOBS_CLEAR		_IOW('Q', 6, struct jobs_interface)
#define	JOBS_ADD_CLASS		_IOWR('Q', 7, struct jobs_add_class)
#define	JOBS_DEL_CLASS		_IOW('Q', 8, struct jobs_delete_class)
#define	JOBS_MOD_CLASS		_IOW('Q', 9, struct jobs_modify_class)
#define	JOBS_ADD_FILTER		_IOWR('Q', 10, struct jobs_add_filter)
#define	JOBS_DEL_FILTER		_IOW('Q', 11, struct jobs_delete_filter)
#define	JOBS_GETSTATS		_IOWR('Q', 12, struct jobs_class_stats)

#ifdef _KERNEL

struct jobs_class {
        TSLIST	*arv_tm;		/* list of timestamps */
	struct	jobs_if	*cl_jif;	/* back pointer to jif */
	class_queue_t	*cl_q;		/* class queue structure */

	int	cl_pri;			/* priority */
	int	cl_flags;		/* class flags */

	u_long	cl_handle;		/* class handle */

	/* control variables */

        /*
	 * internal representation:
	 * bytes/unit_time << 32 = (bps /8 << 32)*1/machclk_freq
         */
	int64_t	service_rate;		/* bps that should be out */
        int64_t	min_rate_adc;		/* bps that should be out for ADC/ARC */

	u_int64_t	current_loss;	/* % of packets dropped */
	u_int64_t	cl_lastdel;     /* in clock ticks */
	u_int64_t	cl_avgdel;

	/* statistics */
	u_int	cl_period;		/* backlog period */
	struct	pktcntr cl_arrival;	/* arrived packet counter */
	struct	pktcntr cl_dropcnt;	/* dropped packet counter */
	struct	pktcntr cl_rin;		/* let in packet counter */
	struct	pktcntr cl_rout;	/* transmitted packet counter */


	/* modified deficit round-robin specific variables */

	/*
	 * rout_th is SCALED for precision, as opposed to rout.
	 */
	int64_t st_service_rate;
	u_int64_t	cl_last_rate_update;
	struct	pktcntr	cl_rout_th;	/* theoretical transmissions */
	struct	pktcntr st_arrival;	/* rin+dropped */
	struct	pktcntr	st_rin;		/* dropped packet counter */
	struct	pktcntr	st_rout;	/* transmitted packet counter */
	struct	pktcntr	st_dropcnt;	/* dropped packet counter */

	/* service guarantees */
	u_int	adc_violations;
	int	concerned_adc;
	int	concerned_alc;
	int	concerned_arc;
	int	concerned_rdc;
	int	concerned_rlc;
	/*
	 * Delay Bound (-1 = NO ADC) is provided in us,
	 * and is converted to clock ticks
	 */
	int64_t	cl_adc;

	/*
	 * Loss Rate Bound (-1 = NO ALC) is provided in fraction of 1
	 * and is converted to a fraction of  2^(SCALE_LOSS)
	 */
	int64_t	cl_alc;

	/*
	 * lower bound on throughput (-1 = no ARC)
	 * is provided in (string) and
	 * is converted to internal format
	 */
	int64_t	cl_arc;

	/* RDC weight (-1 = NO RDC) - no unit */
	int64_t	cl_rdc;

	/* RLC weight (-1 = NO RLC) - no unit */
	int64_t	cl_rlc;

	u_int64_t	delay_prod_others;
	u_int64_t	loss_prod_others;
	u_int64_t	idletime;
};

/*
 * jobs interface state
 */
struct jobs_if {
	struct	jobs_if	*jif_next;		/* interface state list */
	struct	ifaltq	*jif_ifq;		/* backpointer to ifaltq */
	struct	jobs_class *jif_default;	/* default class */
	struct	jobs_class *jif_classes[JOBS_MAXPRI]; /* classes */
#ifdef ALTQ3_CLFIER_COMPAT
	struct	acc_classifier jif_classifier;	/* classifier */
#endif
	int	jif_maxpri;			/* max priority in use */

	u_int	jif_bandwidth;			/* link bandwidth in bps */
	u_int	jif_qlimit;			/* buffer size in packets */
	u_int	jif_separate;			/* separate buffers or not */
	u_int64_t	avg_cycles_dequeue;
	u_int64_t	avg_cycles_enqueue;
	u_int64_t	avg_cycles2_dequeue;
	u_int64_t	avg_cycles2_enqueue;
	u_int64_t	bc_cycles_dequeue;
	u_int64_t	bc_cycles_enqueue;
	u_int64_t	wc_cycles_dequeue;
	u_int64_t	wc_cycles_enqueue;
	u_int64_t	total_dequeued;
	u_int64_t	total_enqueued;
};

#endif /* _KERNEL */

#ifdef __cplusplus
}
#endif

#endif /* _ALTQ_ALTQ_JOBS_H_ */