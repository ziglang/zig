/*	$NetBSD: esp_var.h,v 1.6 2018/04/19 08:27:38 maxv Exp $	*/
/*	$FreeBSD: esp_var.h,v 1.1.4.1 2003/01/24 05:11:35 sam Exp $	*/
/*	$OpenBSD: ip_esp.h,v 1.37 2002/06/09 16:26:10 itojun Exp $	*/
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
 * Copyright (C) 1995, 1996, 1997, 1998, 1999 by John Ioannidis,
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

#ifndef _NETIPSEC_ESP_VAR_H_
#define _NETIPSEC_ESP_VAR_H_

#define	ESP_STAT_HDROPS		0	/* packet shorter than header shows */
#define	ESP_STAT_NOPF		1	/* protocol family not supported */
#define	ESP_STAT_NOTDB		2
#define	ESP_STAT_BADKCR		3
#define	ESP_STAT_QFULL		4
#define	ESP_STAT_NOXFORM	5
#define	ESP_STAT_BADILEN	6
#define	ESP_STAT_WRAP		7	/* replay counter wrapped around */
#define	ESP_STAT_BADENC		8	/* bad encryption detected */
#define	ESP_STAT_BADAUTH	9	/* (only valid for xforms with auth) */
#define	ESP_STAT_REPLAY		10	/* possible packet replay detected */
#define	ESP_STAT_INPUT		11	/* input ESP packets */
#define	ESP_STAT_OUTPUT		12	/* output ESP packets */
#define	ESP_STAT_INVALID	13	/* trying to use an invalid TDB */
#define	ESP_STAT_IBYTES		14	/* input bytes */
#define	ESP_STAT_OBYTES		15	/* output bytes */
#define	ESP_STAT_TOOBIG		16	/* packet got larger than IP_MAXPACKET */
#define	ESP_STAT_PDROPS		17	/* packet blocked due to policy */
#define	ESP_STAT_CRYPTO		18	/* crypto processing failure */
#define	ESP_STAT_TUNNEL		19	/* tunnel sanity check failure */
#define	ESP_STAT_HIST		20	/* per-algorithm op count */

/* space for SADB_EALG_STATS_NUM counters */
#define	ESP_ALG_MAX		SADB_EALG_STATS_NUM
#define	ESP_ALG_STR		SADB_EALG_STATS_STR
#define	ESP_NSTATS		(ESP_STAT_HIST + ESP_ALG_MAX)

#ifdef _KERNEL
extern  const uint8_t esp_stats[256];
extern	int esp_enable;
#endif /* _KERNEL */
#endif /* !_NETIPSEC_ESP_VAR_H_ */