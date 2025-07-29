/*	$NetBSD: ddp_var.h,v 1.4 2008/04/23 15:17:42 thorpej Exp $	 */

/*
 * Copyright (c) 1990,1994 Regents of The University of Michigan.
 * All Rights Reserved.
 *
 * Permission to use, copy, modify, and distribute this software and
 * its documentation for any purpose and without fee is hereby granted,
 * provided that the above copyright notice appears in all copies and
 * that both that copyright notice and this permission notice appear
 * in supporting documentation, and that the name of The University
 * of Michigan not be used in advertising or publicity pertaining to
 * distribution of the software without specific, written prior
 * permission. This software is supplied as is without expressed or
 * implied warranties of any kind.
 *
 * This product includes software developed by the University of
 * California, Berkeley and its contributors.
 *
 *	Research Systems Unix Group
 *	The University of Michigan
 *	c/o Wesley Craig
 *	535 W. William Street
 *	Ann Arbor, Michigan
 *	+1-313-764-2278
 *	netatalk@umich.edu
 */

#ifndef _NETATALK_DDP_VAR_H_
#define _NETATALK_DDP_VAR_H_

struct ddpcb {
	struct sockaddr_at ddp_fsat, ddp_lsat;
	struct route    ddp_route;
	struct socket  *ddp_socket;
	struct ddpcb   *ddp_prev, *ddp_next;
	struct ddpcb   *ddp_pprev, *ddp_pnext;
};

#define sotoddpcb(so)	((struct ddpcb *)(so)->so_pcb)

#define	DDP_STAT_SHORT		0	/* short header packets received */
#define	DDP_STAT_LONG		1	/* long header packets received */
#define	DDP_STAT_NOSUM		2	/* no checksum */
#define	DDP_STAT_BADSUM		3	/* bad checksum */
#define	DDP_STAT_TOOSHORT	4	/* packet too short */
#define	DDP_STAT_TOOSMALL	5	/* not enough data */
#define	DDP_STAT_FORWARD	6	/* packets forwarded */
#define	DDP_STAT_ENCAP		7	/* packets encapsulated */
#define	DDP_STAT_CANTFORWARD	8	/* packets rcvd for unreachable net */
#define	DDP_STAT_NOSOCKSPACE	9	/* no space in sockbuf for packet */

#define	DDP_NSTATS		10

#ifdef _KERNEL
extern struct ddpcb *ddp_ports[];
extern struct ddpcb *ddpcb;
#endif

#endif /* !_NETATALK_DDP_VAR_H_ */