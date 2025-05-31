/*	$NetBSD: aarp.h,v 1.3 2011/05/08 13:51:31 bouyer Exp $	*/

/*
 * Copyright (c) 1990,1991 Regents of The University of Michigan.
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
#ifndef _NETATALK_AARP_H_
#define _NETATALK_AARP_H_
/*
 * This structure is used for both phase 1 and 2. Under phase 1
 * the net is not filled in. It is in phase 2. In both cases, the
 * hardware address length is (for some unknown reason) 4. If
 * anyone at Apple could program their way out of paper bag, it
 * would be 1 and 3 respectively for phase 1 and 2.
 */
union aapa {
	u_int8_t ap_pa[4];
	struct ap_node {
		u_int8_t an_zero;
		u_int8_t an_net[2];
		u_int8_t an_node;
	} ap_node;
};

struct ether_aarp {
	struct arphdr   eaa_hdr;
	u_int8_t        aarp_sha[6];
	union aapa      aarp_spu;
	u_int8_t        aarp_tha[6];
	union aapa      aarp_tpu;
};
#define aarp_hrd	eaa_hdr.ar_hrd
#define aarp_pro	eaa_hdr.ar_pro
#define aarp_hln	eaa_hdr.ar_hln
#define aarp_pln	eaa_hdr.ar_pln
#define aarp_op		eaa_hdr.ar_op
#define aarp_spa	aarp_spu.ap_node.an_node
#define aarp_tpa	aarp_tpu.ap_node.an_node
#define aarp_spnet	aarp_spu.ap_node.an_net
#define aarp_tpnet	aarp_tpu.ap_node.an_net
#define aarp_spnode	aarp_spu.ap_node.an_node
#define aarp_tpnode	aarp_tpu.ap_node.an_node

struct aarptab {
	struct at_addr  aat_ataddr;
	u_int8_t        aat_enaddr[6];
	u_int8_t        aat_timer;
	u_int8_t        aat_flags;
	struct mbuf    *aat_hold;
};

#define AARPHRD_ETHER	0x0001

#define AARPOP_REQUEST	0x01
#define AARPOP_RESPONSE	0x02
#define AARPOP_PROBE	0x03

extern struct mowner aarp_mowner;

#endif /* !_NETATALK_AARP_H_ */