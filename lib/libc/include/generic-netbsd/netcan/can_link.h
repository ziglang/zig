/*	$NetBSD: can_link.h,v 1.2 2017/05/27 21:02:56 bouyer Exp $	*/

/*-
 * Copyright (c) 2017 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Manuel Bouyer
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

#ifndef _NETCAN_CAN_LINK_H
#define _NETCAN_CAN_LINK_H

/*
 * CAN bus link-layer related commands, from the SIOCSDRVSPEC
 */

/* get timing capabilities from HW */
struct can_link_timecaps {
	uint32_t cltc_prop_min; /* prop seg, in tq */
	uint32_t cltc_prop_max;
	uint32_t cltc_ps1_min; /* phase1 seg, in tq */
	uint32_t cltc_ps1_max;
	uint32_t cltc_ps2_min; /* phase 2 seg, in tq */
	uint32_t cltc_ps2_max;
	uint32_t cltc_sjw_max;	/* Synchronisation Jump Width */
	uint32_t cltc_brp_min;	/* bit-rate prescaler */
	uint32_t cltc_brp_max;
	uint32_t cltc_brp_inc;
	uint32_t cltc_clock_freq; /* prescaler input clock, in hz */
	uint32_t cltc_linkmode_caps; /* link mode, see below */
};
#define CANGLINKTIMECAP	0 /* get struct can_link_timecaps */

/* get/set timing parameters */
struct can_link_timings {
	uint32_t clt_brp;	/* prescaler value */
	uint32_t clt_prop;	/* Propagation segment in tq */
	uint32_t clt_ps1;	/* Phase segment 1 in tq */
	uint32_t clt_ps2;	/* Phase segment 2 in tq */
	uint32_t clt_sjw;	/* Synchronisation jump width in tq */
};
#define CANGLINKTIMINGS	1 /* get struct can_link_timings */
#define CANSLINKTIMINGS	2 /* set struct can_link_timings */

/* link-level modes */
#define CAN_LINKMODE_LOOPBACK		0x01    /* Loopback mode */
#define CAN_LINKMODE_LISTENONLY		0x02    /* Listen-only mode */
#define CAN_LINKMODE_3SAMPLES		0x04    /* Triple sampling mode */
#define CAN_LINKMODE_PRESUME_ACK	0x08    /* Ignore missing CAN ACKs */
#define CAN_IFFBITS \
    "\020\1LOOPBACK\2LISTENONLY\3TRIPLESAMPLE\4PRESUMEACK"

#define CANGLINKMODE	3 /* (uint32_t) get bits */
#define CANSLINKMODE	4 /* (uint32_t) set bits */
#define CANCLINKMODE	5 /* (uint32_t) clear bits */

#endif /* _NETCAN_CAN_LINK_H */