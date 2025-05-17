/*	$NetBSD: if_gre.h,v 1.50 2021/12/03 13:27:39 andvar Exp $ */

/*
 * Copyright (c) 1998, 2008 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Heiko W.Rupp <hwr@pilhuhn.de>
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by David Young <dyoung@NetBSD.org>
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
 *
 * This material is based upon work partially supported by NSF
 * under Contract No. NSF CNS-0626584.
 */

#ifndef _NET_IF_GRE_H_
#define _NET_IF_GRE_H_

#include <sys/ioccom.h>
#include <sys/evcnt.h>
#include <sys/queue.h>
#include <sys/mutex.h>
#include <sys/condvar.h>
#include <sys/malloc.h>
#include <sys/mallocvar.h>

#ifdef _KERNEL

#include <sys/pcq.h>

struct gre_soparm {
	struct socket		*sp_so;
	struct sockaddr_storage sp_src;	/* source of gre packets */
	struct sockaddr_storage sp_dst;	/* destination of gre packets */
	int		sp_type;	/* encapsulating socket type */
	int		sp_proto;	/* encapsulating protocol */
	bool		sp_bysock;	/* encapsulation configured by passing
					 * socket, not by SIOCSLIFPHYADDR
					 */
};

enum gre_state {
	  GRE_S_IDLE = 0
	, GRE_S_IOCTL
	, GRE_S_DIE
};

struct gre_bufq {
	pcq_t		*bq_q;
	volatile int	bq_drops;
};

enum gre_msg {
	  GRE_M_NONE = 0
	, GRE_M_SETFP
	, GRE_M_DELFP
	, GRE_M_STOP
	, GRE_M_OK
	, GRE_M_ERR
};

struct gre_softc {
	struct ifnet		sc_if;
	kmutex_t		sc_mtx;
	kcondvar_t		sc_condvar;
	kcondvar_t		sc_fp_condvar;
	struct gre_bufq		sc_snd;
	struct gre_soparm	sc_soparm;
	volatile enum gre_state	sc_state;
	volatile int		sc_waiters;
	volatile int		sc_fp_waiters;
	void			*sc_si;

	struct evcnt		sc_recv_ev;
	struct evcnt		sc_send_ev;

	struct evcnt		sc_block_ev;
	struct evcnt		sc_error_ev;
	struct evcnt		sc_pullup_ev;
	struct evcnt		sc_unsupp_ev;
	struct evcnt		sc_oflow_ev;
	file_t	* volatile	sc_fp;
	volatile enum gre_msg	sc_msg;
	int			sc_fd;
};

struct gre_h {
	uint16_t flags;		/* GRE flags */
	uint16_t ptype;		/* protocol type of payload typically
				 * ethernet protocol type
				 */
/*
 *  from here on: fields are optional, presence indicated by flags
 *
	u_int_16 checksum	checksum (one-complements of GRE header
				and payload
				Present if (ck_pres | rt_pres == 1).
				Valid if (ck_pres == 1).
	u_int_16 offset		offset from start of routing field to
				first octet of active SRE (see below).
				Present if (ck_pres | rt_pres == 1).
				Valid if (rt_pres == 1).
	u_int_32 key		inserted by encapsulator e.g. for
				authentication
				Present if (key_pres ==1 ).
	u_int_32 seq_num	Sequence number to allow for packet order
				Present if (seq_pres ==1 ).
	struct gre_sre[] routing Routing fields (see below)
				Present if (rt_pres == 1)
 */
};
#define GRE_CP		0x8000  /* Checksum Present */
#define GRE_RP		0x4000  /* Routing Present */
#define GRE_KP		0x2000  /* Key Present */
#define GRE_SP		0x1000  /* Sequence Present */
#define GRE_SS		0x0800	/* Strict Source Route */

/*
 * gre_sre defines a Source route Entry. These are needed if packets
 * should be routed over more than one tunnel hop by hop
 */
struct gre_sre {
	uint16_t sre_family;	/* address family */
	u_char	sre_offset;	/* offset to first octet of active entry */
	u_char	sre_length;	/* number of octets in the SRE.
				   sre_lengthl==0 -> last entry. */
	u_char	*sre_rtinfo;	/* the routing information */
};

#define	GRE_TTL	30
extern int ip_gre_ttl;
#endif /* _KERNEL */

/*
 * ioctls needed to manipulate the interface
 */

#define GRESADDRS	 _IOW('i', 101, struct ifreq)
#define GRESADDRD	 _IOW('i', 102, struct ifreq)
#define GREGADDRS	_IOWR('i', 103, struct ifreq)
#define GREGADDRD	_IOWR('i', 104, struct ifreq)
#define GRESPROTO	 _IOW('i', 105, struct ifreq)
#define GREGPROTO	_IOWR('i', 106, struct ifreq)
#define GRESSOCK	 _IOW('i', 107, struct ifreq)
#define GREDSOCK	 _IOW('i', 108, struct ifreq)

#endif /* !_NET_IF_GRE_H_ */