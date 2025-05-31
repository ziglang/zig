/*	$NetBSD: altq_rio.h,v 1.5 2006/10/12 19:59:08 peter Exp $	*/
/*	$KAME: altq_rio.h,v 1.9 2003/07/10 12:07:49 kjc Exp $	*/

/*
 * Copyright (C) 1998-2003
 *	Sony Computer Science Laboratories Inc.  All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY SONY CSL AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL SONY CSL OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _ALTQ_ALTQ_RIO_H_
#define	_ALTQ_ALTQ_RIO_H_

#include <altq/altq_classq.h>

/*
 * RIO: RED with IN/OUT bit
 * (extended to support more than 2 drop precedence values)
 */
#define	RIO_NDROPPREC	3	/* number of drop precedence values */

#ifdef ALTQ3_COMPAT
struct rio_interface {
	char	rio_ifname[IFNAMSIZ];
};

struct rio_stats {
	struct rio_interface iface;
	int q_len[RIO_NDROPPREC];
	struct redstats q_stats[RIO_NDROPPREC];

	/* static red parameters */
	int q_limit;
	int weight;
	int flags;
	struct redparams q_params[RIO_NDROPPREC];
};

struct rio_conf {
	struct rio_interface iface;
	struct redparams q_params[RIO_NDROPPREC];
	int rio_weight;		/* weight for EWMA */
	int rio_limit;		/* max queue length */
	int rio_pkttime;	/* average packet time in usec */
	int rio_flags;		/* see below */
};
#endif /* ALTQ3_COMPAT */

/* rio flags */
#define	RIOF_ECN4	0x01	/* use packet marking for IPv4 packets */
#define	RIOF_ECN6	0x02	/* use packet marking for IPv6 packets */
#define	RIOF_ECN	(RIOF_ECN4 | RIOF_ECN6)
#define	RIOF_CLEARDSCP	0x200	/* clear diffserv codepoint */

#ifdef ALTQ3_COMPAT
/*
 * IOCTLs for RIO
 */
#define	RIO_IF_ATTACH		_IOW('Q', 1, struct rio_interface)
#define	RIO_IF_DETACH		_IOW('Q', 2, struct rio_interface)
#define	RIO_ENABLE		_IOW('Q', 3, struct rio_interface)
#define	RIO_DISABLE		_IOW('Q', 4, struct rio_interface)
#define	RIO_CONFIG		_IOWR('Q', 6, struct rio_conf)
#define	RIO_GETSTATS		_IOWR('Q', 12, struct rio_stats)
#define	RIO_SETDEFAULTS		_IOW('Q', 30, struct redparams[RIO_NDROPPREC])
#endif /* ALTQ3_COMPAT */

#ifdef _KERNEL

typedef struct rio {
	/* per drop precedence structure */
	struct dropprec_state {
		/* red parameters */
		int	inv_pmax;	/* inverse of max drop probability */
		int	th_min;		/* red min threshold */
		int	th_max;		/* red max threshold */

		/* variables for internal use */
		int	th_min_s;	/* th_min scaled by avgshift */
		int	th_max_s;	/* th_max scaled by avgshift */
		int	probd;		/* drop probability denominator */

		int	qlen;		/* queue length */
		int	avg;		/* (scaled) queue length average */
		int	count;		/* packet count since the last dropped/
					   marked packet */
		int	idle;		/* queue was empty */
		int	old;		/* avg is above th_min */
		struct timeval	last;	/* timestamp when queue becomes idle */
	} rio_precstate[RIO_NDROPPREC];

	int		 rio_wshift;	/* log(red_weight) */
	int		 rio_weight;	/* weight for EWMA */
	struct wtab	*rio_wtab;	/* weight table */

	int		 rio_pkttime;	/* average packet time in micro sec
					   used for idle calibration */
	int		 rio_flags;	/* rio flags */

	u_int8_t	 rio_codepoint;	/* codepoint value to tag packets */
	u_int8_t	 rio_codepointmask;	/* codepoint mask bits */

	struct redstats q_stats[RIO_NDROPPREC];	/* statistics */
} rio_t;

#ifdef ALTQ3_COMPAT
typedef struct rio_queue {
	struct rio_queue	*rq_next;	/* next red_state in the list */
	struct ifaltq		*rq_ifq;	/* backpointer to ifaltq */

	class_queue_t		*rq_q;

	rio_t			*rq_rio;
} rio_queue_t;
#endif /* ALTQ3_COMPAT */

extern rio_t		*rio_alloc(int, struct redparams *, int, int);
extern void		 rio_destroy(rio_t *);
extern void		 rio_getstats(rio_t *, struct redstats *);
extern int		 rio_addq(rio_t *, class_queue_t *, struct mbuf *,
			     struct altq_pktattr *);
extern struct mbuf	*rio_getq(rio_t *, class_queue_t *);

#endif /* _KERNEL */

#endif /* _ALTQ_ALTQ_RIO_H_ */