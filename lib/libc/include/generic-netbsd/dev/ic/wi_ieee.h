/*	$NetBSD: wi_ieee.h,v 1.24 2005/12/11 12:21:29 christos Exp $	*/

/*
 * Copyright (c) 1997, 1998, 1999
 *	Bill Paul <wpaul@ctr.columbia.edu>.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by Bill Paul.
 * 4. Neither the name of the author nor the names of any co-contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY Bill Paul AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL Bill Paul OR THE VOICES IN HIS HEAD
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 *
 * $FreeBSD: src/sys/i386/include/if_wavelan_ieee.h,v 1.4 1999/12/29 04:33:01 peter Exp $
 */

#ifndef _IF_WAVELAN_IEEE_H
#define _IF_WAVELAN_IEEE_H

/*
 * FreeBSD driver ported to NetBSD by Bill Sommerfeld in the back of the
 * Oslo IETF plenary meeting.
 * The stuff in here should probably go into a generic extension to the
 * ifmedia goop.
 *
 * Michael Graff brought over the encryption bits.
 */

/*
 * This header defines a simple command interface to the FreeBSD
 * WaveLAN/IEEE driver (wi) driver, which is used to set certain
 * device-specific parameters which can't be easily managed through
 * ifconfig(8). No, sysctl(2) is not the answer. I said a _simple_
 * interface, didn't I.
 */

#ifndef SIOCSWAVELAN
#define SIOCSWAVELAN	SIOCSIFGENERIC
#endif

#ifndef SIOCGWAVELAN
#define SIOCGWAVELAN	SIOCGIFGENERIC
#endif

/*
 * Technically I don't think there's a limit to a record
 * length. The largest record is the one that contains the CIS
 * data, which is 240 words long, so 256 should be a safe
 * value.
 */
#define WI_MAX_DATALEN	512

struct wi_req {
	u_int16_t	wi_len;
	u_int16_t	wi_type;
	u_int16_t	wi_val[WI_MAX_DATALEN];
};

/*
 * Private LTV records (interpreted only by the driver). This is
 * a minor kludge to allow reading the interface statistics from
 * the driver.
 */
#define WI_RID_IFACE_STATS	0x0100
#define WI_RID_MGMT_XMIT	0x0200
#ifdef WICACHE
#define WI_RID_ZERO_CACHE	0x0300
#define WI_RID_READ_CACHE	0x0400
#endif
#define	WI_RID_MONITOR_MODE	0x0500
#define	WI_RID_SCAN_APS		0x0600
#define	WI_RID_READ_APS		0x0700

struct wi_80211_hdr {
	u_int16_t		frame_ctl;
	u_int16_t		dur_id;
	u_int8_t		addr1[6];
	u_int8_t		addr2[6];
	u_int8_t		addr3[6];
	u_int16_t		seq_ctl;
	u_int8_t		addr4[6];
};

#define WI_FCTL_VERS		0x0002
#define WI_FCTL_FTYPE		0x000C
#define WI_FCTL_STYPE		0x00F0
#define WI_FCTL_TODS		0x0100
#define WI_FCTL_FROMDS		0x0200
#define WI_FCTL_MOREFRAGS	0x0400
#define WI_FCTL_RETRY		0x0800
#define WI_FCTL_PM		0x1000
#define WI_FCTL_MOREDATA	0x2000
#define WI_FCTL_WEP		0x4000
#define WI_FCTL_ORDER		0x8000

#define WI_FTYPE_MGMT		0x0000
#define WI_FTYPE_CTL		0x0004
#define WI_FTYPE_DATA		0x0008

#define WI_STYPE_MGMT_ASREQ	0x0000	/* association request */
#define WI_STYPE_MGMT_ASRESP	0x0010	/* association response */
#define WI_STYPE_MGMT_REASREQ	0x0020	/* reassociation request */
#define WI_STYPE_MGMT_REASRESP	0x0030	/* reassociation response */
#define WI_STYPE_MGMT_PROBEREQ	0x0040	/* probe request */
#define WI_STYPE_MGMT_PROBERESP	0x0050	/* probe response */
#define WI_STYPE_MGMT_BEACON	0x0080	/* beacon */
#define WI_STYPE_MGMT_ATIM	0x0090	/* announcement traffic ind msg */
#define WI_STYPE_MGMT_DISAS	0x00A0	/* disassociation */
#define WI_STYPE_MGMT_AUTH	0x00B0	/* authentication */
#define WI_STYPE_MGMT_DEAUTH	0x00C0	/* deauthentication */

#define	WI_STYPE_CTL_PSPOLL	0x00A0
#define	WI_STYPE_CTL_RTS	0x00B0
#define	WI_STYPE_CTL_CTS	0x00C0
#define	WI_STYPE_CTL_ACK	0x00D0
#define	WI_STYPE_CTL_CFEND	0x00E0
#define	WI_STYPE_CTL_CFENDACK	0x00F0

struct wi_mgmt_hdr {
	u_int16_t		frame_ctl;
	u_int16_t		duration;
	u_int8_t		dst_addr[6];
	u_int8_t		src_addr[6];
	u_int8_t		bssid[6];
	u_int16_t		seq_ctl;
};

/*
 * Lucent/wavelan IEEE signal strength cache
 *
 * driver keeps cache of last
 * MAXWICACHE packets to arrive including signal strength info.
 * daemons may read this via ioctl
 *
 * Each entry in the wi_sigcache has a unique macsrc.
 */
#ifdef WICACHE
#define	MAXWICACHE	10

struct wi_sigcache {
	char	macsrc[6];	/* unique MAC address for entry */
	int	ipsrc;		/* ip address associated with packet */
	int	signal;		/* signal strength of the packet */
	int	noise;		/* noise value */
	int	quality;	/* quality of the packet */
};
#endif

struct wi_counters {
	u_int32_t		wi_tx_unicast_frames;
	u_int32_t		wi_tx_multicast_frames;
	u_int32_t		wi_tx_fragments;
	u_int32_t		wi_tx_unicast_octets;
	u_int32_t		wi_tx_multicast_octets;
	u_int32_t		wi_tx_deferred_xmits;
	u_int32_t		wi_tx_single_retries;
	u_int32_t		wi_tx_multi_retries;
	u_int32_t		wi_tx_retry_limit;
	u_int32_t		wi_tx_discards;
	u_int32_t		wi_rx_unicast_frames;
	u_int32_t		wi_rx_multicast_frames;
	u_int32_t		wi_rx_fragments;
	u_int32_t		wi_rx_unicast_octets;
	u_int32_t		wi_rx_multicast_octets;
	u_int32_t		wi_rx_fcs_errors;
	u_int32_t		wi_rx_discards_nobuf;
	u_int32_t		wi_tx_discards_wrong_sa;
	u_int32_t		wi_rx_WEP_cant_decrypt;
	u_int32_t		wi_rx_msg_in_msg_frags;
	u_int32_t		wi_rx_msg_in_bad_msg_frags;
};

/*
 * Network parameters, static configuration entities.
 */
#define WI_RID_PORTTYPE		0xFC00 /* Connection control characteristics */
#define WI_RID_MAC_NODE		0xFC01 /* MAC address of this station */
#define WI_RID_DESIRED_SSID	0xFC02 /* Service Set ID for connection */
#define WI_RID_OWN_CHNL		0xFC03 /* Comm channel for BSS creation */
#define WI_RID_OWN_SSID		0xFC04 /* IBSS creation ID */
#define WI_RID_OWN_ATIM_WIN	0xFC05 /* ATIM window time for IBSS creation */
#define WI_RID_SYSTEM_SCALE	0xFC06 /* scale that specifies AP density */
#define WI_RID_MAX_DATALEN	0xFC07 /* Max len of MAC frame body data */
#define WI_RID_MAC_WDS		0xFC08 /* MAC addr of corresponding WDS node */
#define WI_RID_PM_ENABLED	0xFC09 /* ESS power management enable */
#define WI_RID_PM_EPS		0xFC0A /* PM EPS/PS mode */
#define WI_RID_MCAST_RX		0xFC0B /* ESS PM mcast reception */
#define WI_RID_MAX_SLEEP	0xFC0C /* max sleep time for ESS PM */
#define WI_RID_HOLDOVER		0xFC0D /* holdover time for ESS PM */
#define WI_RID_NODENAME		0xFC0E /* ID name of this node for diag */
#define WI_RID_DTIM_PERIOD	0xFC10 /* beacon interval between DTIMs */
#define WI_RID_WDS_ADDR1	0xFC11 /* port 1 MAC of WDS link node */
#define WI_RID_WDS_ADDR2	0xFC12 /* port 1 MAC of WDS link node */
#define WI_RID_WDS_ADDR3	0xFC13 /* port 1 MAC of WDS link node */
#define WI_RID_WDS_ADDR4	0xFC14 /* port 1 MAC of WDS link node */
#define WI_RID_WDS_ADDR5	0xFC15 /* port 1 MAC of WDS link node */
#define WI_RID_WDS_ADDR6	0xFC16 /* port 1 MAC of WDS link node */
#define WI_RID_MCAST_PM_BUF	0xFC17 /* PM buffering of mcast */
#define WI_RID_ENCRYPTION	0xFC20 /* enable/disable WEP */
#define WI_RID_AUTHTYPE		0xFC21 /* specify authentication type */
#define WI_RID_P2_TX_CRYPT_KEY	0xFC23
#define WI_RID_P2_CRYPT_KEY0	0xFC24
#define WI_RID_P2_CRYPT_KEY1	0xFC25
#define WI_RID_MICROWAVE_OVEN	0xFC25
#define WI_RID_P2_CRYPT_KEY2	0xFC26
#define WI_RID_P2_CRYPT_KEY3	0xFC27
#define WI_RID_P2_ENCRYPTION	0xFC28
#define	 PRIVACY_INVOKED	0x01
#define	 EXCLUDE_UNENCRYPTED	0x02
#define	 HOST_ENCRYPT		0x10
#define	 IV_EVERY_FRAME		0x00	/* IV = Initialization Vector */
#define	 IV_EVERY10_FRAME	0x20	/* every 10 frame IV reuse */
#define	 IV_EVERY50_FRAME	0x40	/* every 50 frame IV reuse */
#define	 IV_EVERY100_FRAME	0x60	/* every 100 frame IV reuse */
#define	 HOST_DECRYPT		0x80
#define WI_RID_WEP_MAPTABLE	0xFC29
#define WI_RID_CNFAUTHMODE	0xFC2A
#define WI_RID_ROAMING_MODE	0xFC2D
#define	WI_RID_ALT_RETRY_COUNT	0xFC32 /* retry count if WI_TXCNTL_ALTRTRY */
#define WI_RID_OWN_BEACON_INT	0xFC33 /* beacon xmit time for BSS creation */
#define WI_RID_SET_TIM		0xFC40
#define WI_RID_DBM_ADJUST	0xFC46 /* RSSI - WI_RID_DBM_ADJUST ~ dBm */
#define WI_RID_BASIC_RATE	0xFCB3
#define WI_RID_SUPPORT_RATE	0xFCB4

/*
 * Network parameters, dynamic configuration entities
 */
#define WI_RID_MCAST_LIST	0xFC80 /* multicast addrs to put in filter */
#define WI_RID_CREATE_IBSS	0xFC81 /* create IBSS */
#define WI_RID_FRAG_THRESH	0xFC82 /* frag len, unicast msg xmit */
#define WI_RID_RTS_THRESH	0xFC83 /* frame len for RTS/CTS handshake */
#define WI_RID_TX_RATE		0xFC84 /* data rate for message xmit
 					* 0 == Fixed 1mbps
 					* 1 == Fixed 2mbps
 					* 2 == auto fallback
					*/
#define WI_RID_PROMISC		0xFC85 /* enable promisc mode */
#define WI_RID_FRAG_THRESH0	0xFC90
#define WI_RID_FRAG_THRESH1	0xFC91
#define WI_RID_FRAG_THRESH2	0xFC92
#define WI_RID_FRAG_THRESH3	0xFC93
#define WI_RID_FRAG_THRESH4	0xFC94
#define WI_RID_FRAG_THRESH5	0xFC95
#define WI_RID_FRAG_THRESH6	0xFC96
#define WI_RID_RTS_THRESH0	0xFC97
#define WI_RID_RTS_THRESH1	0xFC98
#define WI_RID_RTS_THRESH2	0xFC99
#define WI_RID_RTS_THRESH3	0xFC9A
#define WI_RID_RTS_THRESH4	0xFC9B
#define WI_RID_RTS_THRESH5	0xFC9C
#define WI_RID_RTS_THRESH6	0xFC9D
#define WI_RID_TX_RATE0		0xFC9E
#define WI_RID_TX_RATE1		0xFC9F
#define WI_RID_TX_RATE2		0xFCA0
#define WI_RID_TX_RATE3		0xFCA1
#define WI_RID_TX_RATE4		0xFCA2
#define WI_RID_TX_RATE5		0xFCA3
#define WI_RID_TX_RATE6		0xFCA4
#define WI_RID_DEFLT_CRYPT_KEYS	0xFCB0
#define WI_RID_TX_CRYPT_KEY	0xFCB1
#define WI_RID_TICK_TIME	0xFCE0 	/* Auxiliary Timer tick interval */

struct wi_key {
	u_int16_t		wi_keylen;
	u_int8_t		wi_keydat[14];
};

struct wi_ltv_keys {
	u_int16_t		wi_len;
	u_int16_t		wi_type;
	struct wi_key		wi_keys[4];
};

/*
 * NIC information
 */
#define WI_RID_DNLD_BUF		0xFD01
#define WI_RID_MEMSZ		0xFD02 /* memory size info (XXX Lucent) */
#define	WI_RID_PRI_IDENTITY	0xFD02 /* primary funcs firmware ident (PRISM2) */
#define WI_RID_PRI_SUP_RANGE	0xFD03 /* primary supplier compatibility */
#define WI_RID_CIF_ACT_RANGE	0xFD04 /* controller sup. compatibility */
#define WI_RID_SERIALNO		0xFD0A /* card serial number */
#define WI_RID_CARD_ID		0xFD0B /* card identification */
#define WI_RID_MFI_SUP_RANGE	0xFD0C /* modem supplier compatibility */
#define WI_RID_CFI_SUP_RANGE	0xFD0D /* controller sup. compatibility */
#define WI_RID_CHANNEL_LIST	0xFD10 /* allowed comm. frequencies. */
#define WI_RID_REG_DOMAINS	0xFD11 /* list of intendted regulatory doms */
#define WI_RID_TEMP_TYPE	0xFD12 /* hw temp range code */
#define WI_RID_CIS		0xFD13 /* PC card info struct */
#define WI_RID_STA_IDENTITY	0xFD20 /* station funcs firmware ident */
#define WI_RID_STA_SUP_RANGE	0xFD21 /* station supplier compat */
#define WI_RID_MFI_ACT_RANGE	0xFD22
#define WI_RID_SYMBOL_IDENTITY	0xFD24
#define WI_RID_CFI_ACT_RANGE	0xFD33
#define WI_RID_COMMQUAL		0xFD43
#define WI_RID_SCALETHRESH	0xFD46
#define WI_RID_PCF		0xFD87

/*
 * MAC information
 */
#define WI_RID_PORT_STAT	0xFD40 /* actual MAC port con control stat */
#define WI_RID_CURRENT_SSID	0xFD41 /* ID of actually connected SS */
#define WI_RID_CURRENT_BSSID	0xFD42 /* ID of actually connected BSS */
#define WI_RID_COMMS_QUALITY	0xFD43 /* quality of BSS connection */
#define WI_RID_CUR_TX_RATE	0xFD44 /* current TX rate */
#define WI_RID_CUR_BEACON_INT	0xFD45 /* current beacon interval */
#define WI_RID_CUR_SCALE_THRESH	0xFD46 /* actual system scane thresh setting */
#define WI_RID_PROT_RESP_TIME	0xFD47 /* time to wait for resp to req msg */
#define WI_RID_SHORT_RTR_LIM	0xFD48 /* max tx attempts for short frames */
#define WI_RID_LONG_RTS_LIM	0xFD49 /* max tx attempts for long frames */
#define WI_RID_MAX_TX_LIFE	0xFD4A /* max tx frame handling duration */
#define WI_RID_MAX_RX_LIFE	0xFD4B /* max rx frame handling duration */
#define WI_RID_CF_POLL		0xFD4C /* contention free pollable ind */
#define WI_RID_AUTH_ALGS	0xFD4D /* auth algorithms available */
#define WI_RID_AUTH_TYPE	0xFD4E /* available auth types */
#define WI_RID_WEP_AVAIL	0xFD4F /* WEP privacy option available */
#define WI_RID_CUR_TX_RATE1	0xFD80
#define WI_RID_CUR_TX_RATE2	0xFD81
#define WI_RID_CUR_TX_RATE3	0xFD82
#define WI_RID_CUR_TX_RATE4	0xFD83
#define WI_RID_CUR_TX_RATE5	0xFD84
#define WI_RID_CUR_TX_RATE6	0xFD85
#define WI_RID_OWN_MAC		0xFD86 /* unique local MAC addr */
#define WI_RID_PCI_INFO		0xFD87 /* point coordination func cap */

/*
 * Scan Information
 */
#define	WI_RID_BCAST_SCAN_REQ	0xFCAB /* Broadcast Scan request (Symbol) */
#define	 BSCAN_5SEC		0x01
#define	 BSCAN_ONETIME		0x02
#define	 BSCAN_PASSIVE		0x40
#define	 BSCAN_BCAST		0x80
#define WI_RID_SCAN_REQ		0xFCE1 /* Scan request (STA only) */
#define WI_RID_JOIN_REQ		0xFCE2 /* Join request (STA only) */
#define	WI_RID_AUTH_STATION	0xFCE3 /* Authenticates Station (AP) */
#define	WI_RID_CHANNEL_REQ	0xFCE4 /* Channel Information Request (AP) */
#define WI_RID_SCAN_RESULTS	0xFD88 /* Scan Results Table */

struct wi_apinfo {
	int			scanreason;	/* ScanReason */
	char			bssid[6];	/* BSSID (mac address) */
	int			channel;	/* Channel */
	int			signal;		/* Signal level */
	int			noise;		/* Average Noise Level*/
	int			quality;	/* Quality */
	int			namelen;	/* Length of SSID string */
	char			name[32];	/* SSID string */
	int			capinfo;	/* Capability info. */
	int			interval;	/* BSS Beacon Interval */
	int			rate;		/* Data Rate */
};

/*
 * Modem information
 */
#define WI_RID_PHY_TYPE		0xFDC0 /* phys layer type indication */
#define WI_RID_CURRENT_CHAN	0xFDC1 /* current frequency */
#define WI_RID_PWR_STATE	0xFDC2 /* pwr consumption status */
#define WI_RID_CCA_MODE		0xFDC3 /* clear chan assess mode indication */
#define WI_RID_CCA_TIME		0xFDC4 /* clear chan assess time */
#define WI_RID_MAC_PROC_DELAY	0xFDC5 /* MAC processing delay time */
#define WI_RID_DATA_RATES	0xFDC6 /* supported data rates */

#endif