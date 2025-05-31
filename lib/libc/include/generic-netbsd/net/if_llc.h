/*	$NetBSD: if_llc.h,v 1.23 2021/02/03 18:13:13 roy Exp $	*/

/*
 * Copyright (c) 1988, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
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
 *
 *	@(#)if_llc.h	8.1 (Berkeley) 6/10/93
 */

#ifndef _NET_IF_LLC_H_
#define _NET_IF_LLC_H_

/*
 * IEEE 802.2 Link Level Control headers, for use in conjunction with
 * 802.{3,4,5} media access control methods.
 *
 * Headers here do not use bit fields due to shortcommings in many
 * compilers.
 */

struct llc {
	uint8_t llc_dsap;
	uint8_t llc_ssap;
	union {
	    struct {
		uint8_t control;
		uint8_t format_id;
		uint8_t class_u;
		uint8_t window_x2;
	    } type_u /* XXX __packed ??? */;
	    struct {
		uint8_t num_snd_x2;
		uint8_t num_rcv_x2;
	    } type_i /* XXX __packed ??? */;
	    struct {
		uint8_t control;
		uint8_t num_rcv_x2;
	    } type_s /* XXX __packed ??? */;
	    struct {
	        uint8_t control;
		/*
		 * We cannot put the following fields in a structure because
		 * the structure rounding might cause padding.
		 */
		uint8_t frmr_rej_pdu0;
		uint8_t frmr_rej_pdu1;
		uint8_t frmr_control;
		uint8_t frmr_control_ext;
		uint8_t frmr_cause;
	    } type_frmr /* XXX __packed ??? */;
	    struct {
		uint8_t  control;
		uint8_t  org_code[3];
		uint16_t ether_type;
	    } type_snap __packed;
	    struct {
		uint8_t control;
		uint8_t control_ext;
	    } type_raw /* XXX __packed ??? */;
	} llc_un /* XXX __packed ??? */;
};

struct frmrinfo {
	uint8_t frmr_rej_pdu0;
	uint8_t frmr_rej_pdu1;
	uint8_t frmr_control;
	uint8_t frmr_control_ext;
	uint8_t frmr_cause;
};

#ifdef __CTASSERT
__CTASSERT(sizeof(struct llc) == 8);
__CTASSERT(sizeof(struct frmrinfo) == 5);
#endif

#define	llc_control		llc_un.type_u.control
#define	llc_control_ext		llc_un.type_raw.control_ext
#define	llc_fid			llc_un.type_u.format_id
#define	llc_class		llc_un.type_u.class_u
#define	llc_window		llc_un.type_u.window_x2
#define	llc_frmrinfo 		llc_un.type_frmr.frmr_rej_pdu0
#define	llc_frmr_pdu0		llc_un.type_frmr.frmr_rej_pdu0
#define	llc_frmr_pdu1		llc_un.type_frmr.frmr_rej_pdu1
#define	llc_frmr_control	llc_un.type_frmr.frmr_control
#define	llc_frmr_control_ext	llc_un.type_frmr.frmr_control_ext
#define	llc_frmr_cause		llc_un.type_frmr.frmr_cause
#define	llc_snap		llc_un.type_snap

/*
 * Don't use sizeof(struct llc_un) for LLC header sizes
 */
#define LLC_ISFRAMELEN 4
#define LLC_UFRAMELEN  3
#define LLC_FRMRLEN    7
#define LLC_SNAPFRAMELEN 8

/*
 * Unnumbered LLC format commands
 */
#define LLC_UI		0x3
#define LLC_UI_P	0x13
#define LLC_DISC	0x43
#define	LLC_DISC_P	0x53
#define LLC_UA		0x63
#define LLC_UA_P	0x73
#define LLC_TEST	0xe3
#define LLC_TEST_P	0xf3
#define LLC_FRMR	0x87
#define	LLC_FRMR_P	0x97
#define LLC_DM		0x0f
#define	LLC_DM_P	0x1f
#define LLC_XID		0xaf
#define LLC_XID_P	0xbf
#define LLC_SABME	0x6f
#define LLC_SABME_P	0x7f

/*
 * Supervisory LLC commands
 */
#define	LLC_RR		0x01
#define	LLC_RNR		0x05
#define	LLC_REJ		0x09

/*
 * Info format - dummy only
 */
#define	LLC_INFO	0x00

/*
 * ISO PDTR 10178 contains among others
 */
#define	LLC_8021D_LSAP	0x42
#define LLC_X25_LSAP	0x7e
#define LLC_SNAP_LSAP	0xaa
#define LLC_ISO_LSAP	0xfe

/*
 * LLC XID definitions from 802.2, as needed
 */

#define LLC_XID_FORMAT_BASIC	0x81
#define LLC_XID_BASIC_MINLEN	(LLC_UFRAMELEN + 3)

#define LLC_XID_CLASS_I 	0x1
#define LLC_XID_CLASS_II	0x3
#define LLC_XID_CLASS_III	0x5
#define LLC_XID_CLASS_IV	0x7


#endif /* !_NET_IF_LLC_H_ */