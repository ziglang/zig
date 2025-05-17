/*	$NetBSD: ah_var.h,v 1.7 2018/04/19 08:27:38 maxv Exp $	*/
/*	$FreeBSD: ah_var.h,v 1.1.4.1 2003/01/24 05:11:35 sam Exp $	*/
/*	$OpenBSD: ip_ah.h,v 1.29 2002/06/09 16:26:10 itojun Exp $	*/
/*
 * The authors of this code are John Ioannidis (ji@tla.org),
 * Angelos D. Keromytis (kermit@csd.uch.gr) and
 * Niels Provos (provos@physnet.uni-hamburg.de).
 *
 * The original version of this code was written by John Ioannidis
 * for BSD/OS in Athens, Greece, in November 1995.
 *
 * Ported to OpenBSD and NetBSD, with additional transforms, in December 1996,
 * by Angelos D. Keromytis.
 *
 * Additional transforms and features in 1997 and 1998 by Angelos D. Keromytis
 * and Niels Provos.
 *
 * Additional features in 1999 by Angelos D. Keromytis.
 *
 * Copyright (C) 1995, 1996, 1997, 1998, 1999 John Ioannidis,
 * Angelos D. Keromytis and Niels Provos.
 * Copyright (c) 2001 Angelos D. Keromytis.
 *
 * Permission to use, copy, and modify this software with or without fee
 * is hereby granted, provided that this entire notice is included in
 * all copies of any software which is or includes a copy or
 * modification of this software.
 * You may use this code under the GNU public license if you so wish. Please
 * contribute changes back to the authors under this freer than GPL license
 * so that we may further the use of strong encryption without limitations to
 * all.
 *
 * THIS SOFTWARE IS BEING PROVIDED "AS IS", WITHOUT ANY EXPRESS OR
 * IMPLIED WARRANTY. IN PARTICULAR, NONE OF THE AUTHORS MAKES ANY
 * REPRESENTATION OR WARRANTY OF ANY KIND CONCERNING THE
 * MERCHANTABILITY OF THIS SOFTWARE OR ITS FITNESS FOR ANY PARTICULAR
 * PURPOSE.
 */

#ifndef _NETIPSEC_AH_VAR_H_
#define _NETIPSEC_AH_VAR_H_

#define	AH_STAT_HDROPS		0	/* packet shorter than header shows */
#define	AH_STAT_NOPF		1	/* protocol family not supported */
#define	AH_STAT_NOTDB		2
#define	AH_STAT_BADKCR		3
#define	AH_STAT_BADAUTH		4
#define	AH_STAT_NOXFORM		5
#define	AH_STAT_QFULL		6
#define	AH_STAT_WRAP		7
#define	AH_STAT_REPLAY		8
#define	AH_STAT_BADAUTHL	9	/* bad authenticator length */
#define	AH_STAT_INPUT		10	/* input AH packets */
#define	AH_STAT_OUTPUT		11	/* output AH packets */
#define	AH_STAT_INVALID		12	/* trying to use an invalid TDB */
#define	AH_STAT_IBYTES		13	/* input bytes */
#define	AH_STAT_OBYTES		14	/* output bytes */
#define	AH_STAT_TOOBIG		15	/* packet got > than IP_MAXPACKET */
#define	AH_STAT_PDROPS		16	/* packet blocked due to policy */
#define	AH_STAT_CRYPTO		17	/* crypto processing failure */
#define	AH_STAT_TUNNEL		18	/* tunnel sanity check failure */
#define	AH_STAT_HIST		19	/* per-algorithm op count */

/* space for SADB_AALG_STATS_NUM counters */
#define	AH_ALG_MAX		SADB_AALG_STATS_NUM
#define	AH_ALG_STR		SADB_AALG_STATS_STR
#define	AH_NSTATS		(AH_STAT_HIST + AH_ALG_MAX)

#ifdef _KERNEL
extern const uint8_t ah_stats[256];
extern int ah_enable;
#endif /* _KERNEL */
#endif /* !_NETIPSEC_AH_VAR_H_ */