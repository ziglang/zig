/*	$NetBSD: altq_fifoq.h,v 1.7 2006/10/12 19:59:08 peter Exp $	*/
/*	$KAME: altq_fifoq.h,v 1.8 2002/11/29 04:36:23 kjc Exp $	*/

/*
 * Copyright (C) 1997-2002
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

#ifndef _ALTQ_ALTQ_FIFOQ_H_
#define	_ALTQ_ALTQ_FIFOQ_H_

#ifdef _KERNEL
typedef struct fifoq_state {
	struct fifoq_state *q_next;	/* next fifoq_state in the list */
	struct ifaltq *q_ifq;		/* backpointer to ifaltq */

	struct mbuf *q_head;		/* head of queue */
	struct mbuf *q_tail;		/* tail of queue */
	int	q_len;			/* queue length */
	int	q_limit;		/* max queue length */

	/* statistics */
	struct {
		struct pktcntr	xmit_cnt;
		struct pktcntr	drop_cnt;
		u_int		period;
	} q_stats;
} fifoq_state_t;
#endif

struct fifoq_interface {
	char	fifoq_ifname[IFNAMSIZ];
};

struct fifoq_getstats {
	struct fifoq_interface iface;
	int		q_len;
	int		q_limit;
	struct pktcntr	xmit_cnt;
	struct pktcntr	drop_cnt;
	u_int		period;
};

struct fifoq_conf {
	struct fifoq_interface iface;
	int fifoq_limit;
};

#define	FIFOQ_LIMIT	50	/* default max queue length */

/*
 * IOCTLs for FIFOQ
 */
#define	FIFOQ_IF_ATTACH		_IOW('Q', 1, struct fifoq_interface)
#define	FIFOQ_IF_DETACH		_IOW('Q', 2, struct fifoq_interface)
#define	FIFOQ_ENABLE		_IOW('Q', 3, struct fifoq_interface)
#define	FIFOQ_DISABLE		_IOW('Q', 4, struct fifoq_interface)
#define	FIFOQ_CONFIG		_IOWR('Q', 6, struct fifoq_conf)
#define	FIFOQ_GETSTATS		_IOWR('Q', 12, struct fifoq_getstats)

#endif /* _ALTQ_ALTQ_FIFOQ_H_ */