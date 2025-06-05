/*	$NetBSD: if_media.h,v 1.71 2020/03/15 23:04:51 thorpej Exp $	*/

/*-
 * Copyright (c) 1998, 2000, 2001, 2020 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe of the Numerical Aerospace Simulation Facility,
 * NASA Ames Research Center.
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

/*
 * Copyright (c) 1997
 *	Jonathan Stone and Jason R. Thorpe.  All rights reserved.
 *
 * This software is derived from information provided by Matt Thomas.
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
 *	This product includes software developed by Jonathan Stone
 *	and Jason R. Thorpe for the NetBSD Project.
 * 4. The names of the authors may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NET_IF_MEDIA_H_
#define _NET_IF_MEDIA_H_

/*
 * Prototypes and definitions for BSD/OS-compatible network interface
 * media selection.
 *
 * Where it is safe to do so, this code strays slightly from the BSD/OS
 * design.  Software which uses the API (device drivers, basically)
 * shouldn't notice any difference.
 *
 * Many thanks to Matt Thomas for providing the information necessary
 * to implement this interface.
 */

/*
 * Status bits. THIS IS NOT A MEDIA WORD.
 */
#define	IFM_AVALID	0x00000001	/* Active bit valid */
#define	IFM_ACTIVE	0x00000002	/* Interface attached to working net */

/*
 * if_media Options word:
 *	Bits	Use
 *	----	-------
 *	0-4	Media subtype	MAX SUBTYPE == 255 for ETH and 31 for others
 *				See below (IFM_ETHER part) for the detail.
 *	5-7	Media type
 *	8-15	Type specific options
 *	16-18	Mode (for multi-mode devices)
 *	19	(Reserved for Future Use)
 *	20-27	Shared (global) options
 *	28-31	Instance
 *
 *   3                     2                   1
 *   1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
 *  +-------+---------------+-+-----+---------------+-----+---------+
 *  |       |               |R|     |               |     |         |
 *  | IMASK |     GMASK     |F|MMASK+-----+ OMASK   |NMASK|  TMASK  |
 *  |       |               |U|     |XTMSK|         |     |         |
 *  +-------+---------------+-+-----+-----+---------+-----+---------+
 *   <----->                   <--->                 <--->
 *  IFM_INST()               IFM_MODE()            IFM_TYPE()
 *
 *                              IFM_SUBTYPE(other than ETH)<------->
 *
 *                                   <---> IFM_SUBTYPE(ETH)<------->
 *                                         
 *
 *           <------------->         <------------->
 *                        IFM_OPTIONS()
 */

/*
 * Masks
 */
#define	IFM_NMASK	0x000000e0	/* Network type */
#define	IFM_TMASK	0x0000001f	/* Media sub-type */
#define	IFM_IMASK	0xf0000000	/* Instance */
#define	IFM_ISHIFT	28		/* Instance shift */
#define	IFM_OMASK	0x0000ff00	/* Type specific options */
#define	IFM_MMASK	0x00070000	/* Mode */
#define	IFM_MSHIFT	16		/* Mode shift */
#define	IFM_GMASK	0x0ff00000	/* Global options */

/*
 * Macros to extract various bits of information from the media word.
 */
#define	IFM_TYPE(x)	((x) & IFM_NMASK)
#define	IFM_SUBTYPE(x)	(IFM_TYPE(x) == IFM_ETHER ?			      \
	    IFM_ETHER_SUBTYPE_GET(x) : ((x) & IFM_TMASK))
#define	IFM_TYPE_MATCH(dt, t)						      \
	(IFM_TYPE(dt) == 0 || IFM_TYPE(dt) == IFM_TYPE(t))
#define	IFM_TYPE_SUBTYPE_MATCH(dt, t)					      \
	(IFM_TYPE(dt) == IFM_TYPE(t) && IFM_SUBTYPE(dt) == IFM_SUBTYPE(t))
#define	IFM_INST(x)	(((x) & IFM_IMASK) >> IFM_ISHIFT)
#define	IFM_OPTIONS(x)	((x) & (IFM_OMASK | IFM_GMASK))
#define	IFM_MODE(x)	((x) & IFM_MMASK)

#define	IFM_INST_MAX	IFM_INST(IFM_IMASK)
#define	IFM_INST_ANY	((u_int) -1)

/* Mask of "status valid" bits, for ifconfig(8). */
#define	IFM_STATUS_VALID IFM_AVALID

/* List of "status valid" bits, for ifconfig(8). */
#define	IFM_STATUS_VALID_LIST {						\
	IFM_AVALID,							\
	0,								\
}

/*
 * Macro to create a media word.
 */
#define	IFM_MAKEWORD(type, subtype, options, instance)			\
	((type) | (subtype) | (options) | ((instance) << IFM_ISHIFT))
#define	IFM_MAKEMODE(mode) \
	(((mode) << IFM_MSHIFT) & IFM_MMASK)

/*
 * Media type (IFM_NMASK).
 */
#define	IFM_GENERIC	0x00000000    /* Only used for link status reporting */
#define	IFM_ETHER	0x00000020
#define	IFM_TOKEN	0x00000040
#define	IFM_FDDI	0x00000060
#define	IFM_IEEE80211	0x00000080
#define	IFM_CARP	0x000000c0     /* Common Address Redundancy Protocol */

#define	IFM_NMIN	IFM_ETHER	/* lowest Network type */
#define	IFM_NMAX	IFM_NMASK	/* highest Network type */

/*
 * Shared media sub-types (IFM_TMASK)
 */
#define	IFM_AUTO	0		/* Autoselect best media */
#define	IFM_MANUAL	1		/* Jumper/dipswitch selects media */
#define	IFM_NONE	2		/* Deselect all media */

/*
 * Shared (global) options (IFM_GMASK)
 */
#define	IFM_FDX		0x00100000	/* Force full duplex */
#define	IFM_HDX		0x00200000	/* Force half duplex */
#define	IFM_FLOW	0x00400000	/* enable hardware flow control */
#define	IFM_FLAG0	0x01000000	/* Driver defined flag */
#define	IFM_FLAG1	0x02000000	/* Driver defined flag */
#define	IFM_FLAG2	0x04000000	/* Driver defined flag */
#define	IFM_LOOP	0x08000000	/* Put hardware in loopback */

/*
 * 0: Generic (IFM_GENERIC). Only used for link status reporting.
 * No any media specific flag.
 */

/*
 * 1: Ethernet (IFM_ETHER)
 *
 * In order to use more than 31 subtypes, Ethernet uses some of the option
 * bits as part of the subtype field. See the options section below for
 * relevant definitions.
 */
#define	IFM_ETHER_SUBTYPE(x) (((x) & IFM_TMASK) |			      \
	    (((x) & (_IFM_ETH_XTMASK >> IFM_ETH_XSHIFT)) << IFM_ETH_XSHIFT))
#define IFM_ETHER_SUBTYPE_GET(x) ((x) & (IFM_TMASK | _IFM_ETH_XTMASK))
#define _IFM_EX(x)	IFM_ETHER_SUBTYPE(x) /* internal shorthand */

#define	IFM_10_T	3		/* 10BaseT - RJ45 */
#define	IFM_10_2	4		/* 10Base2 - Thinnet */
#define	IFM_10_5	5		/* 10Base5 - AUI */
#define	IFM_100_TX	6		/* 100BaseTX - RJ45 */
#define	IFM_100_FX	7		/* 100BaseFX - Fiber */
#define	IFM_100_T4	8		/* 100BaseT4 - 4 pair cat 3 */
#define	IFM_100_VG	9		/* 100VG-AnyLAN */
#define	IFM_100_T2	10		/* 100BaseT2 */
#define	IFM_1000_SX	11		/* 1000BaseSX - multi-mode fiber */
#define	IFM_10_STP	12		/* 10BaseT over shielded TP */
#define	IFM_10_FL	13		/* 10BaseFL - Fiber */
#define	IFM_1000_LX	14		/* 1000baseLX - single-mode fiber */
#define	IFM_1000_CX	15		/* 1000baseCX - 150ohm STP */
#define	IFM_1000_T	16		/* 1000baseT - 4 pair cat 5 */
#define	IFM_HPNA_1	17		/* HomePNA 1.0 (1Mb/s) */
#define	IFM_10G_LR	18		/* 10GbaseLR - single-mode fiber */
#define	IFM_10G_SR	19		/* 10GBase-SR 850nm Multi-mode */
#define	IFM_10G_CX4	20		/* 10GBase CX4 copper */
#define	IFM_2500_SX	21		/* 2500baseSX - multi-mode fiber */
#define	IFM_1000_BX10	22		/* 1000base-BX10 */
#define	IFM_10G_TWINAX	23		/* 10GBase Twinax copper */
#define	IFM_10G_TWINAX_LONG	24	/* 10GBase Twinax Long copper */
#define	IFM_10G_LRM	25		/* 10GBase-LRM 850nm Multi-mode */
#define	IFM_10G_T	26		/* 10GBase-T - RJ45 */
#define	IFM_1000_KX	27		/* 1000base-KX backplane */
#define	IFM_2500_KX	28		/* 2500base-KX backplane */
#define	IFM_2500_T	29		/* 2500base-T - RJ45 */
#define	IFM_5000_T	30		/* 5Gbase-T - RJ45 */
#define	IFM_OTHER	31		/*
					 * This number indicates "Not listed".
					 * and also used for backward
					 * compatibility.
					 */
#define	IFM_1000_SGMII	_IFM_EX(32)	/* 1G SGMII */
#define	IFM_5000_KR	_IFM_EX(33)	/* 5GBASE-KR backplane */
#define	IFM_10G_AOC	_IFM_EX(34)	/* 10G active optical cable */
#define	IFM_10G_CR1	_IFM_EX(35)	/* 10GBASE-CR1 Twinax splitter */
#define	IFM_10G_ER	_IFM_EX(36)	/* 10GBASE-ER */
#define	IFM_10G_KR	_IFM_EX(37)	/* 10GBASE-KR backplane */
#define	IFM_10G_KX4	_IFM_EX(38)	/* 10GBASE-KX4 backplane */
#define	IFM_10G_LX4	_IFM_EX(39)	/* 10GBASE-LX4 */
#define	IFM_10G_SFI	_IFM_EX(40)	/* 10G SFI */
#define	IFM_10G_ZR	_IFM_EX(41)	/* 10GBASE-ZR */
#define	IFM_20G_KR2	_IFM_EX(42)	/* 20GBASE-KR2 backplane */
#define	IFM_25G_AOC	_IFM_EX(43)	/* 25G active optical cable */
#define	IFM_25G_AUI	_IFM_EX(44)	/* 25G-AUI-C2C (chip to chip) */
#define	IFM_25G_CR	_IFM_EX(45)	/* 25GBASE-CR (twinax) */
#define	IFM_25G_ACC	_IFM_EX(46)	/* 25GBASE-ACC */
#define	IFM_25G_CR_S	_IFM_EX(47)	/* 25GBASE-CR-S (CR short) */
#define	IFM_25G_ER	_IFM_EX(48)	/* 25GBASE-ER */
#define	IFM_25G_KR	_IFM_EX(49)	/* 25GBASE-KR */
#define	IFM_25G_KR_S	_IFM_EX(50)	/* 25GBASE-KR-S (KR short) */
#define	IFM_25G_LR	_IFM_EX(51)	/* 25GBASE-LR */
#define	IFM_25G_SR	_IFM_EX(52)	/* 25GBASE-SR */
#define	IFM_25G_T	_IFM_EX(53)	/* 25GBASE-T - RJ45 */
#define	IFM_40G_AOC	_IFM_EX(54)	/* 40G Active Optical Cable */
#define	IFM_40G_CR4	_IFM_EX(55)	/* 40GBASE-CR4 */
#define	IFM_40G_ER4	_IFM_EX(56)	/* 40GBASE-ER4 */
#define	IFM_40G_FR	_IFM_EX(57)	/* 40GBASE-FR */
#define	IFM_40G_KR4	_IFM_EX(58)	/* 40GBASE-KR4 */
#define	IFM_40G_LR4	_IFM_EX(59)	/* 40GBASE-LR4 */
#define	IFM_40G_SR4	_IFM_EX(60)	/* 40GBASE-SR4 */
#define	IFM_40G_T	_IFM_EX(61)	/* 40GBASE-T */
#define	IFM_40G_XLPPI	_IFM_EX(62)	/* 40G XLPPI */
#define	IFM_50G_AUI1	_IFM_EX(63)	/* 50GAUI-1 */
#define	IFM_50G_AUI2	_IFM_EX(64)	/* 50GAUI-2 */
#define	IFM_50G_CR	_IFM_EX(65)	/* 50GBASE-CR */
#define	IFM_50G_CR2	_IFM_EX(66)	/* 50GBASE-CR2 */
#define	IFM_50G_FR	_IFM_EX(67)	/* 50GBASE-FR */
#define	IFM_50G_KR	_IFM_EX(68)	/* 50GBASE-KR */
#define	IFM_50G_KR2	_IFM_EX(69)	/* 50GBASE-KR2 */
#define	IFM_50G_LAUI2	_IFM_EX(70)	/* 50GLAUI-2 */
#define	IFM_50G_LR	_IFM_EX(71)	/* 50GBASE-LR */
		     /* _IFM_EX(72) Not defined yet */
#define	IFM_50G_SR	_IFM_EX(73)	/* 50GBASE-SR */
#define	IFM_50G_SR2	_IFM_EX(74)	/* 50GBASE-SR2 */
#define	IFM_56G_R4	_IFM_EX(75)	/* 56GBASE-R4 */
#define	IFM_100G_CR2	_IFM_EX(76)	/* 100GBASE-CR2 (CP2?) */
#define	IFM_100G_CR4	_IFM_EX(77)	/* 100GBASE-CR4 */
#define	IFM_100G_CR10	_IFM_EX(78)	/* 100GBASE-CR10 */
#define	IFM_100G_DR	_IFM_EX(79)	/* 100GBASE-DR */
#define	IFM_100G_ER4	_IFM_EX(80)	/* 100GBASE-ER4 */
#define	IFM_100G_KP4	_IFM_EX(81)	/* 100GBASE-KP4 */
#define	IFM_100G_KR2	_IFM_EX(82)	/* 100GBASE-KR2 */
#define	IFM_100G_KR4	_IFM_EX(83)	/* 100GBASE-KR4 */
#define	IFM_100G_LR4	_IFM_EX(84)	/* 100GBASE-LR4 */
#define	IFM_100G_SR2	_IFM_EX(85)	/* 100GBASE-SR2 */
#define	IFM_100G_SR4	_IFM_EX(86)	/* 100GBASE-SR4 */
#define	IFM_100G_SR10	_IFM_EX(87)	/* 100GBASE-SR10 */
#define	IFM_200G_CR2	_IFM_EX(88)	/* 200GBASE-CR2 */
#define	IFM_200G_CR4	_IFM_EX(89)	/* 200GBASE-CR4 */
#define	IFM_200G_DR4	_IFM_EX(90)	/* 200GBASE-DR4 */
#define	IFM_200G_FR4	_IFM_EX(91)	/* 200GBASE-FR4 */
#define	IFM_200G_KR2	_IFM_EX(92)	/* 200GBASE-KR2 */
#define	IFM_200G_KR4	_IFM_EX(93)	/* 200GBASE-KR4 */
#define	IFM_200G_LR4	_IFM_EX(94)	/* 200GBASE-LR4 */
#define	IFM_200G_SR4	_IFM_EX(95)	/* 200GBASE-SR4 */
#define	IFM_400G_CR4	_IFM_EX(96)	/* 400GBASE-CR4 */
#define	IFM_400G_DR4	_IFM_EX(97)	/* 400GBASE-DR4 */
#define	IFM_400G_FR8	_IFM_EX(98)	/* 400GBASE-FR8 */
#define	IFM_400G_KR4	_IFM_EX(99)	/* 400GBASE-KR4 */
#define	IFM_400G_LR8	_IFM_EX(100)	/* 400GBASE-LR8 */
#define	IFM_400G_SR16	_IFM_EX(101)	/* 400GBASE-SR16 */
#define	IFM_100G_ACC	_IFM_EX(102)	/* 100GBASE-ACC */
#define	IFM_100G_AOC	_IFM_EX(103)	/* 100GBASE-AOC */
#define	IFM_100G_FR	_IFM_EX(104)	/* 100GBASE-FR */
#define	IFM_100G_LR	_IFM_EX(105)	/* 100GBASE-LR */
#define	IFM_200G_ER4	_IFM_EX(106)	/* 200GBASE-ER4 */
#define	IFM_400G_ER8	_IFM_EX(107)	/* 400GBASE-ER8 */
#define	IFM_400G_FR4	_IFM_EX(108)	/* 400GBASE-FR4 */
#define	IFM_400G_LR4	_IFM_EX(109)	/* 400GBASE-LR4 */
#define	IFM_400G_SR4_2	_IFM_EX(110)	/* 400GBASE-SR4.2 */
#define	IFM_400G_SR8	_IFM_EX(111)	/* 400GBASE-SR8 */

/* IFM_OMASK bits */
#define	IFM_ETH_MASTER	0x00000100	/* master mode (1000baseT) */
#define	IFM_ETH_RXPAUSE	0x00000200	/* receive PAUSE frames */
#define	IFM_ETH_TXPAUSE	0x00000400	/* transmit PAUSE frames */
#define	_IFM_ETH_XTMASK	0x0000e000	/* Media sub-type (MSB) */
#define	IFM_ETH_XSHIFT	(13 - 5)	/* shift XTYPE next to TMASK */

/* Ethernet flow control mask */
#define	IFM_ETH_FMASK	(IFM_FLOW | IFM_ETH_RXPAUSE | IFM_ETH_TXPAUSE)

/*
 * 2: Token ring (IFM_TOKEN)
 */
#define	IFM_TOK_STP4	3		/* Shielded twisted pair 4m - DB9 */
#define	IFM_TOK_STP16	4		/* Shielded twisted pair 16m - DB9 */
#define	IFM_TOK_UTP4	5		/* Unshielded twisted pair 4m - RJ45 */
#define	IFM_TOK_UTP16	6		/* Unshielded twisted pair 16m - RJ45 */
/* IFM_OMASK bits */
#define	IFM_TOK_ETR	0x00000200	/* Early token release */
#define	IFM_TOK_SRCRT	0x00000400	/* Enable source routing features */
#define	IFM_TOK_ALLR	0x00000800	/* All routes / Single route bcast */

/*
 * 3: FDDI (IFM_FDDI)
 */
#define	IFM_FDDI_SMF	3		/* Single-mode fiber */
#define	IFM_FDDI_MMF	4		/* Multi-mode fiber */
#define	IFM_FDDI_UTP	5		/* CDDI / UTP */
#define	IFM_FDDI_DA	0x00000100	/* Dual attach / single attach */

/*
 * 4: IEEE 802.11 Wireless (IFM_IEEE80211)
 */
#define	IFM_IEEE80211_FH1	3	/* Frequency Hopping 1Mbps */
#define	IFM_IEEE80211_FH2	4	/* Frequency Hopping 2Mbps */
#define	IFM_IEEE80211_DS2	5	/* Direct Sequence 2Mbps */
#define	IFM_IEEE80211_DS5	6	/* Direct Sequence 5Mbps*/
#define	IFM_IEEE80211_DS11	7	/* Direct Sequence 11Mbps*/
#define	IFM_IEEE80211_DS1	8	/* Direct Sequence 1Mbps */
#define	IFM_IEEE80211_DS22	9	/* Direct Sequence 22Mbps */
#define	IFM_IEEE80211_OFDM6	10	/* OFDM 6Mbps */
#define	IFM_IEEE80211_OFDM9	11	/* OFDM 9Mbps */
#define	IFM_IEEE80211_OFDM12	12	/* OFDM 12Mbps */
#define	IFM_IEEE80211_OFDM18	13	/* OFDM 18Mbps */
#define	IFM_IEEE80211_OFDM24	14	/* OFDM 24Mbps */
#define	IFM_IEEE80211_OFDM36	15	/* OFDM 36Mbps */
#define	IFM_IEEE80211_OFDM48	16	/* OFDM 48Mbps */
#define	IFM_IEEE80211_OFDM54	17	/* OFDM 54Mbps */
#define	IFM_IEEE80211_OFDM72	18	/* OFDM 72Mbps */
#define	IFM_IEEE80211_DS354k	19	/* Direct Sequence 354Kbps */
#define	IFM_IEEE80211_DS512k	20	/* Direct Sequence 512Kbps */
#define	IFM_IEEE80211_OFDM3	21	/* OFDM 3Mbps */
#define	IFM_IEEE80211_OFDM4	22	/* OFDM 4.5Mbps */
#define	IFM_IEEE80211_OFDM27	23	/* OFDM 27Mbps */
/* NB: not enough bits to express MCS fully */
#define	IFM_IEEE80211_MCS	24	/* HT MCS rate */
#define	IFM_IEEE80211_VHT	25	/* VHT MCS rate */

/* IFM_OMASK bits */
#define	IFM_IEEE80211_ADHOC	0x00000100	/* Operate in Adhoc mode */
#define	IFM_IEEE80211_HOSTAP	0x00000200	/* Operate in Host AP mode */
#define	IFM_IEEE80211_MONITOR	0x00000400	/* Operate in Monitor mode */
#define	IFM_IEEE80211_TURBO	0x00000800	/* Operate in Turbo mode */
#define	IFM_IEEE80211_IBSS	0x00001000	/* Operate in IBSS mode */
#define	IFM_IEEE80211_WDS 	0x00002000	/* Operate as an WDS master */
#define	IFM_IEEE80211_MBSS	0x00004000	/* Operate in MBSS mode */

/* Operating mode (IFM_MMASK) for multi-mode devices */
#define	IFM_IEEE80211_11A	0x00010000	/* 5 GHz, OFDM mode */
#define	IFM_IEEE80211_11B	0x00020000	/* Direct Sequence mode */
#define	IFM_IEEE80211_11G	0x00030000	/* 2 GHz, CCK mode */
#define	IFM_IEEE80211_FH	0x00040000	/* 2 GHz, GFSK mode */
#define	IFM_IEEE80211_11NA	0x00050000	/* 5Ghz, HT mode */
#define	IFM_IEEE80211_11NG	0x00060000	/* 2Ghz, HT mode */
#define	IFM_IEEE80211_11AC	0x00070000	/* 2Ghz/5Ghz, VHT mode */


/*
 * 6: Common Address Redundancy Protocol (IFM_CARP)
 * No any media specific flag.
 */

/*
 * NetBSD extension not defined in the BSDI API.  This is used in various
 * places to get the canonical description for a given type/subtype.
 *
 * In the subtype and mediaopt descriptions, the valid TYPE bits are OR'd
 * in to indicate which TYPE the subtype/option corresponds to.  If no
 * TYPE is present, it is a shared media/mediaopt.
 *
 * Note that these are parsed case-insensitive.
 *
 * Order is important.  The first matching entry is the canonical name
 * for a media type; subsequent matches are aliases.
 */
struct ifmedia_description {
	int	ifmt_word;		/* word value; may be masked */
	const char *ifmt_string;	/* description */
};

#define	IFM_TYPE_DESCRIPTIONS {						\
	{ IFM_ETHER,			"Ethernet" },			\
	{ IFM_ETHER,			"ether" },			\
	{ IFM_TOKEN,			"TokenRing" },			\
	{ IFM_TOKEN,			"token" },			\
	{ IFM_FDDI,			"FDDI" },			\
	{ IFM_IEEE80211,		"IEEE802.11" },			\
	{ IFM_CARP,			"CARP" },			\
	{ 0, NULL },							\
}

#define	IFM_SUBTYPE_DESCRIPTIONS {					\
	{ IFM_AUTO,			"autoselect" },			\
	{ IFM_AUTO,			"auto" },			\
	{ IFM_MANUAL,			"manual" },			\
	{ IFM_NONE,			"none" },			\
									\
	{ IFM_ETHER | IFM_10_T,		"10baseT" },			\
	{ IFM_ETHER | IFM_10_T,		"10baseT/UTP" },		\
	{ IFM_ETHER | IFM_10_T,		"UTP" },			\
	{ IFM_ETHER | IFM_10_T,		"10UTP" },			\
	{ IFM_ETHER | IFM_10_T,		"10BASE-T" },			\
	{ IFM_ETHER | IFM_10_2,		"10base2" },			\
	{ IFM_ETHER | IFM_10_2,		"10base2/BNC" },		\
	{ IFM_ETHER | IFM_10_2,		"BNC" },			\
	{ IFM_ETHER | IFM_10_2,		"10BNC" },			\
	{ IFM_ETHER | IFM_10_2,		"10BASE2" },			\
	{ IFM_ETHER | IFM_10_5,		"10base5" },			\
	{ IFM_ETHER | IFM_10_5,		"10base5/AUI" },		\
	{ IFM_ETHER | IFM_10_5,		"AUI" },			\
	{ IFM_ETHER | IFM_10_5,		"10AUI" },			\
	{ IFM_ETHER | IFM_10_5,		"10BASE5" },			\
	{ IFM_ETHER | IFM_100_TX,	"100baseTX" },			\
	{ IFM_ETHER | IFM_100_TX,	"100TX" },			\
	{ IFM_ETHER | IFM_100_TX,	"100BASE-TX" },			\
	{ IFM_ETHER | IFM_100_FX,	"100baseFX" },			\
	{ IFM_ETHER | IFM_100_FX,	"100FX" },			\
	{ IFM_ETHER | IFM_100_FX,	"100BASE-FX" },			\
	{ IFM_ETHER | IFM_100_T4,	"100baseT4" },			\
	{ IFM_ETHER | IFM_100_T4,	"100T4" },			\
	{ IFM_ETHER | IFM_100_T4,	"100BASE-T4" },			\
	{ IFM_ETHER | IFM_100_VG,	"100baseVG" },			\
	{ IFM_ETHER | IFM_100_VG,	"100VG" },			\
	{ IFM_ETHER | IFM_100_VG,	"100VG-AnyLAN" },		\
	{ IFM_ETHER | IFM_100_T2,	"100baseT2" },			\
	{ IFM_ETHER | IFM_100_T2,	"100T2" },			\
	{ IFM_ETHER | IFM_100_T2,	"100BASE-T2" },			\
	{ IFM_ETHER | IFM_1000_SX,	"1000baseSX" },			\
	{ IFM_ETHER | IFM_1000_SX,	"1000SX" },			\
	{ IFM_ETHER | IFM_1000_SX,	"1000BASE-SX" },		\
	{ IFM_ETHER | IFM_10_STP,	"10baseSTP" },			\
	{ IFM_ETHER | IFM_10_STP,	"STP" },			\
	{ IFM_ETHER | IFM_10_STP,	"10STP" },			\
	{ IFM_ETHER | IFM_10_STP,	"10BASE-STP" },			\
	{ IFM_ETHER | IFM_10_FL,	"10baseFL" },			\
	{ IFM_ETHER | IFM_10_FL,	"FL" },				\
	{ IFM_ETHER | IFM_10_FL,	"10FL" },			\
	{ IFM_ETHER | IFM_10_FL,	"10BASE-FL" },			\
	{ IFM_ETHER | IFM_1000_LX,	"1000baseLX" },			\
	{ IFM_ETHER | IFM_1000_LX,	"1000LX" },			\
	{ IFM_ETHER | IFM_1000_LX,	"1000BASE-LX" },		\
	{ IFM_ETHER | IFM_1000_CX,	"1000baseCX" },			\
	{ IFM_ETHER | IFM_1000_CX,	"1000CX" },			\
	{ IFM_ETHER | IFM_1000_CX,	"1000BASE-CX" },		\
	{ IFM_ETHER | IFM_1000_BX10,	"1000BASE-BX10" },		\
	{ IFM_ETHER | IFM_1000_KX,	"1000BASE-KX" },		\
	{ IFM_ETHER | IFM_1000_KX,	"1000baseKX" },			\
	{ IFM_ETHER | IFM_1000_T,	"1000baseT" },			\
	{ IFM_ETHER | IFM_1000_T,	"1000T" },			\
	{ IFM_ETHER | IFM_1000_T,	"1000BASE-T" },			\
	{ IFM_ETHER | IFM_HPNA_1,	"HomePNA1" },			\
	{ IFM_ETHER | IFM_HPNA_1,	"HPNA1" },			\
	{ IFM_ETHER | IFM_2500_KX | IFM_FDX,	"2500BASE-KX" },	\
	{ IFM_ETHER | IFM_2500_KX | IFM_FDX,	"2500baseKX" },		\
	{ IFM_ETHER | IFM_2500_T | IFM_FDX,	"2.5GBASE-T" },		\
	{ IFM_ETHER | IFM_2500_T | IFM_FDX,	"2500baseT" },		\
	{ IFM_ETHER | IFM_5000_T | IFM_FDX,	"5GBASE-T" },		\
	{ IFM_ETHER | IFM_5000_T | IFM_FDX,	"5GbaseT" },		\
	{ IFM_ETHER | IFM_OTHER,		"Other" },		\
	{ IFM_ETHER | IFM_10G_LR | IFM_FDX,	"10GbaseLR" },		\
	{ IFM_ETHER | IFM_10G_LR | IFM_FDX,	"10GLR" },		\
	{ IFM_ETHER | IFM_10G_LR | IFM_FDX,	"10GBASE-LR" },		\
	{ IFM_ETHER | IFM_10G_SR | IFM_FDX,	"10GbaseSR" },		\
	{ IFM_ETHER | IFM_10G_SR | IFM_FDX,	"10GSR" },		\
	{ IFM_ETHER | IFM_10G_SR | IFM_FDX,	"10GBASE-SR" },		\
	{ IFM_ETHER | IFM_10G_LRM | IFM_FDX,	"10Gbase-LRM" },	\
	{ IFM_ETHER | IFM_10G_TWINAX | IFM_FDX,	"10Gbase-Twinax" },	\
	{ IFM_ETHER | IFM_10G_TWINAX_LONG | IFM_FDX, "10Gbase-Twinax-Long" },\
	{ IFM_ETHER | IFM_10G_T | IFM_FDX,	"10Gbase-T" },		\
	{ IFM_ETHER | IFM_10G_CX4 | IFM_FDX,	"10GbaseCX4" },		\
	{ IFM_ETHER | IFM_10G_CX4 | IFM_FDX,	"10GCX4" },		\
	{ IFM_ETHER | IFM_10G_CX4 | IFM_FDX,	"10GBASE-CX4" },	\
	{ IFM_ETHER | IFM_2500_SX | IFM_FDX,	"2500baseSX" },		\
	{ IFM_ETHER | IFM_2500_SX | IFM_FDX,	"2500SX" },		\
	{ IFM_ETHER | IFM_1000_SGMII | IFM_FDX,	"1000BASE-SGMII" },	\
	{ IFM_ETHER | IFM_5000_KR | IFM_FDX,	"5GBASE-KR" },		\
	{ IFM_ETHER | IFM_10G_AOC | IFM_FDX,	"10GBASE-AOC" },	\
	{ IFM_ETHER | IFM_10G_CR1 | IFM_FDX,	"10GBASE-CR1" },	\
	{ IFM_ETHER | IFM_10G_ER | IFM_FDX,	"10GBASE-ER" },		\
	{ IFM_ETHER | IFM_10G_KR | IFM_FDX,	"10GBASE-KR" },		\
	{ IFM_ETHER | IFM_10G_KX4 | IFM_FDX,	"10GBASE-KX4" },	\
	{ IFM_ETHER | IFM_10G_LX4 | IFM_FDX,	"10GBASE-LX4" },	\
	{ IFM_ETHER | IFM_10G_SFI | IFM_FDX,	"10GBASE-SFI" },	\
	{ IFM_ETHER | IFM_10G_ZR | IFM_FDX,	"10GBASE-ZR" },		\
	{ IFM_ETHER | IFM_20G_KR2 | IFM_FDX,	"20GBASE-KR2" },	\
	{ IFM_ETHER | IFM_25G_ACC | IFM_FDX,	"25GBASE-ACC" },	\
	{ IFM_ETHER | IFM_25G_AOC | IFM_FDX,	"25GBASE-AOC" },	\
	{ IFM_ETHER | IFM_25G_AUI | IFM_FDX,	"25G-AUI" },	\
	{ IFM_ETHER | IFM_25G_CR | IFM_FDX,	"25GBASE-CR" },		\
	{ IFM_ETHER | IFM_25G_CR_S | IFM_FDX,	"25GBASE-CR-S" },	\
	{ IFM_ETHER | IFM_25G_ER | IFM_FDX,	"25GBASE-ER" },		\
	{ IFM_ETHER | IFM_25G_KR | IFM_FDX,	"25GBASE-KR" },		\
	{ IFM_ETHER | IFM_25G_KR_S | IFM_FDX,	"25GBASE-KR-S" },	\
	{ IFM_ETHER | IFM_25G_LR | IFM_FDX,	"25GBASE-LR" },		\
	{ IFM_ETHER | IFM_25G_SR | IFM_FDX,	"25GBASE-SR" },		\
	{ IFM_ETHER | IFM_25G_T | IFM_FDX,	"25GBASE-T" },		\
	{ IFM_ETHER | IFM_40G_AOC | IFM_FDX,	"40GBASE-AOC" },	\
	{ IFM_ETHER | IFM_40G_CR4 | IFM_FDX,	"40GBASE-CR4" },	\
	{ IFM_ETHER | IFM_40G_ER4 | IFM_FDX,	"40GBASE-ER4" },	\
	{ IFM_ETHER | IFM_40G_FR | IFM_FDX,	"40GBASE-FR" },		\
	{ IFM_ETHER | IFM_40G_KR4 | IFM_FDX,	"40GBASE-KR4" },	\
	{ IFM_ETHER | IFM_40G_LR4 | IFM_FDX,	"40GBASE-LR4" },	\
	{ IFM_ETHER | IFM_40G_SR4 | IFM_FDX,	"40GBASE-SR4" },	\
	{ IFM_ETHER | IFM_40G_T | IFM_FDX,	"40GBASE-T" },		\
	{ IFM_ETHER | IFM_40G_XLPPI | IFM_FDX,	"40G-XLPPI" },		\
	{ IFM_ETHER | IFM_50G_AUI1 | IFM_FDX,	"50GAUI-1" },		\
	{ IFM_ETHER | IFM_50G_AUI2 | IFM_FDX,	"50GAUI-2" },		\
	{ IFM_ETHER | IFM_50G_CR | IFM_FDX,	"50GBASE-CR" },		\
	{ IFM_ETHER | IFM_50G_CR2 | IFM_FDX,	"50GBASE-CR2" },	\
	{ IFM_ETHER | IFM_50G_FR | IFM_FDX,	"50GBASE-FR" },		\
	{ IFM_ETHER | IFM_50G_KR | IFM_FDX,	"50GBASE-KR" },		\
	{ IFM_ETHER | IFM_50G_KR2 | IFM_FDX,	"50GBASE-KR2" },	\
	{ IFM_ETHER | IFM_50G_LAUI2 | IFM_FDX,	"50GLAUI-2" },		\
	{ IFM_ETHER | IFM_50G_LR | IFM_FDX,	"50GBASE-LR" },		\
	{ IFM_ETHER | IFM_50G_SR | IFM_FDX,	"50GBASE-SR" },		\
	{ IFM_ETHER | IFM_50G_SR2 | IFM_FDX,	"50GBASE-SR2" },	\
	{ IFM_ETHER | IFM_56G_R4 | IFM_FDX,	"56GBASE-R4" },		\
	{ IFM_ETHER | IFM_100G_ACC | IFM_FDX,	"100GBASE-ACC" },	\
	{ IFM_ETHER | IFM_100G_AOC | IFM_FDX,	"100GBASE-AOC" },	\
	{ IFM_ETHER | IFM_100G_CR2 | IFM_FDX,	"100GBASE-CR2" },	\
	{ IFM_ETHER | IFM_100G_CR4 | IFM_FDX,	"100GBASE-CR4" },	\
	{ IFM_ETHER | IFM_100G_CR10 | IFM_FDX,	"100GBASE-CR10" },	\
	{ IFM_ETHER | IFM_100G_DR | IFM_FDX,	"100GBASE-DR" },	\
	{ IFM_ETHER | IFM_100G_ER4 | IFM_FDX,	"100GBASE-ER4" },	\
	{ IFM_ETHER | IFM_100G_FR | IFM_FDX,	"100GBASE-FR" },	\
	{ IFM_ETHER | IFM_100G_KP4 | IFM_FDX,	"100GBASE-KP4" },	\
	{ IFM_ETHER | IFM_100G_KR2 | IFM_FDX,	"100GBASE-KR2" },	\
	{ IFM_ETHER | IFM_100G_KR4 | IFM_FDX,	"100GBASE-KR4" },	\
	{ IFM_ETHER | IFM_100G_LR | IFM_FDX,	"100GBASE-LR" },	\
	{ IFM_ETHER | IFM_100G_LR4 | IFM_FDX,	"100GBASE-LR4" },	\
	{ IFM_ETHER | IFM_100G_SR2 | IFM_FDX,	"100GBASE-SR2" },	\
	{ IFM_ETHER | IFM_100G_SR4 | IFM_FDX,	"100GBASE-SR4" },	\
	{ IFM_ETHER | IFM_100G_SR10 | IFM_FDX,	"100GBASE-SR10" },	\
	{ IFM_ETHER | IFM_200G_CR2 | IFM_FDX,	"200GBASE-CR2" },	\
	{ IFM_ETHER | IFM_200G_CR4 | IFM_FDX,	"200GBASE-CR4" },	\
	{ IFM_ETHER | IFM_200G_DR4 | IFM_FDX,	"200GBASE-DR4" },	\
	{ IFM_ETHER | IFM_200G_ER4 | IFM_FDX,	"200GBASE-ER4" },	\
	{ IFM_ETHER | IFM_200G_FR4 | IFM_FDX,	"200GBASE-FR4" },	\
	{ IFM_ETHER | IFM_200G_KR2 | IFM_FDX,	"200GBASE-KR2" },	\
	{ IFM_ETHER | IFM_200G_KR4 | IFM_FDX,	"200GBASE-KR4" },	\
	{ IFM_ETHER | IFM_200G_LR4 | IFM_FDX,	"200GBASE-LR4" },	\
	{ IFM_ETHER | IFM_200G_SR4 | IFM_FDX,	"200GBASE-SR4" },	\
	{ IFM_ETHER | IFM_400G_CR4 | IFM_FDX,	"400GBASE-CR4" },	\
	{ IFM_ETHER | IFM_400G_DR4 | IFM_FDX,	"400GBASE-DR4" },	\
	{ IFM_ETHER | IFM_400G_ER8 | IFM_FDX,	"400GBASE-ER8" },	\
	{ IFM_ETHER | IFM_400G_FR4 | IFM_FDX,	"400GBASE-FR4" },	\
	{ IFM_ETHER | IFM_400G_FR8 | IFM_FDX,	"400GBASE-FR8" },	\
	{ IFM_ETHER | IFM_400G_KR4 | IFM_FDX,	"400GBASE-KR4" },	\
	{ IFM_ETHER | IFM_400G_LR4 | IFM_FDX,	"400GBASE-LR4" },	\
	{ IFM_ETHER | IFM_400G_LR8 | IFM_FDX,	"400GBASE-LR8" },	\
	{ IFM_ETHER | IFM_400G_SR4_2 | IFM_FDX,	"400GBASE-SR4.2" },	\
	{ IFM_ETHER | IFM_400G_SR8 | IFM_FDX,	"400GBASE-SR8" },	\
	{ IFM_ETHER | IFM_400G_SR16 | IFM_FDX,	"400GBASE-SR16" },	\
									\
	{ IFM_TOKEN | IFM_TOK_STP4,	"DB9/4Mbit" },			\
	{ IFM_TOKEN | IFM_TOK_STP4,	"4STP" },			\
	{ IFM_TOKEN | IFM_TOK_STP16,	"DB9/16Mbit" },			\
	{ IFM_TOKEN | IFM_TOK_STP16,	"16STP" },			\
	{ IFM_TOKEN | IFM_TOK_UTP4,	"UTP/4Mbit" },			\
	{ IFM_TOKEN | IFM_TOK_UTP4,	"4UTP" },			\
	{ IFM_TOKEN | IFM_TOK_UTP16,	"UTP/16Mbit" },			\
	{ IFM_TOKEN | IFM_TOK_UTP16,	"16UTP" },			\
									\
	{ IFM_FDDI | IFM_FDDI_SMF,	"Single-mode" },		\
	{ IFM_FDDI | IFM_FDDI_SMF,	"SMF" },			\
	{ IFM_FDDI | IFM_FDDI_MMF,	"Multi-mode" },			\
	{ IFM_FDDI | IFM_FDDI_MMF,	"MMF" },			\
	{ IFM_FDDI | IFM_FDDI_UTP,	"UTP" },			\
	{ IFM_FDDI | IFM_FDDI_UTP,	"CDDI" },			\
									\
	/*								\
	 * Short-hand for common media+option combos.			\
	 */								\
	{ IFM_ETHER | IFM_10_T | IFM_FDX,	"10baseT-FDX" },	\
	{ IFM_ETHER | IFM_10_T | IFM_FDX,	"10BASE-T-FDX" },	\
	{ IFM_ETHER | IFM_100_TX | IFM_FDX,	"100baseTX-FDX" },	\
	{ IFM_ETHER | IFM_100_TX | IFM_FDX,	"100BASE-TX-FDX" },	\
	{ IFM_ETHER | IFM_1000_T | IFM_FDX,	"1000baseT-FDX" },	\
									\
	/*								\
	 * IEEE 802.11							\
	 */								\
	{ IFM_IEEE80211 | IFM_IEEE80211_FH1,	"FH1" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_FH2,	"FH2" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS1,	"DS1" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS2,	"DS2" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS5,	"DS5" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS11,	"DS11" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS22,	"DS22" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM6,	"OFDM6" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM9,	"OFDM9" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM12,	"OFDM12" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM18,	"OFDM18" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM24,	"OFDM24" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM36,	"OFDM36" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM48,	"OFDM48" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM54,	"OFDM54" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM72,	"OFDM72" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS354k, "DS/354Kbps" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS512k, "DS/512Kbps" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM3,	"OFDM/3Mbps" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM4,	"OFDM/4.5Mbps" },	\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM27, "OFDM/27Mbps" },	\
	{ IFM_IEEE80211 | IFM_IEEE80211_MCS, "HT" },			\
	{ IFM_IEEE80211 | IFM_IEEE80211_VHT, "VHT" },			\
									\
	{ 0, NULL },							\
}

#define IFM_MODE_DESCRIPTIONS {						\
	{ IFM_AUTO,				"autoselect" },		\
	{ IFM_AUTO,				"auto" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_11A,	"11a" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_11B,	"11b" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_11G,	"11g" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_FH,	"fh" },			\
	{ IFM_IEEE80211 | IFM_IEEE80211_11NA,	"11na" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_11NG,	"11ng" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_11AC,	"11ac" },		\
	{ 0, NULL },							\
}

#define	IFM_OPTION_DESCRIPTIONS {					\
	{ IFM_FDX,			"full-duplex" },		\
	{ IFM_FDX,			"fdx" },			\
	{ IFM_HDX,			"half-duplex" },		\
	{ IFM_HDX,			"hdx" },			\
	{ IFM_FLOW,			"flowcontrol" },		\
	{ IFM_FLOW,			"flow" },			\
	{ IFM_FLAG0,			"flag0" },			\
	{ IFM_FLAG1,			"flag1" },			\
	{ IFM_FLAG2,			"flag2" },			\
	{ IFM_LOOP,			"loopback" },			\
	{ IFM_LOOP,			"hw-loopback"},			\
	{ IFM_LOOP,			"loop" },			\
									\
	{ IFM_ETHER | IFM_ETH_MASTER,	"master" },			\
	{ IFM_ETHER | IFM_ETH_RXPAUSE,	"rxpause" },			\
	{ IFM_ETHER | IFM_ETH_TXPAUSE,	"txpause" },			\
									\
	{ IFM_TOKEN | IFM_TOK_ETR,	"EarlyTokenRelease" },		\
	{ IFM_TOKEN | IFM_TOK_ETR,	"ETR" },			\
	{ IFM_TOKEN | IFM_TOK_SRCRT,	"SourceRouting" },		\
	{ IFM_TOKEN | IFM_TOK_SRCRT,	"SRCRT" },			\
	{ IFM_TOKEN | IFM_TOK_ALLR,	"AllRoutes" },			\
	{ IFM_TOKEN | IFM_TOK_ALLR,	"ALLR" },			\
									\
	{ IFM_FDDI | IFM_FDDI_DA,	"dual-attach" },		\
	{ IFM_FDDI | IFM_FDDI_DA,	"das" },			\
									\
	{ IFM_IEEE80211 | IFM_IEEE80211_ADHOC,	"adhoc" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_HOSTAP,	"hostap" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_MONITOR,"monitor" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_TURBO,	"turbo" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_IBSS,	"ibss" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_WDS,	"wds" },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_MBSS,	"mesh" },		\
									\
	{ 0, NULL },							\
}

/*
 * Baudrate descriptions for the various media types.
 */
struct ifmedia_baudrate {
	int	ifmb_word;		/* media word */
	uint64_t	ifmb_baudrate;		/* corresponding baudrate */
};

#define	IFM_BAUDRATE_DESCRIPTIONS {					\
	{ IFM_ETHER | IFM_10_T,		IF_Mbps(10) },			\
	{ IFM_ETHER | IFM_10_2,		IF_Mbps(10) },			\
	{ IFM_ETHER | IFM_10_5,		IF_Mbps(10) },			\
	{ IFM_ETHER | IFM_100_TX,	IF_Mbps(100) },			\
	{ IFM_ETHER | IFM_100_FX,	IF_Mbps(100) },			\
	{ IFM_ETHER | IFM_100_T4,	IF_Mbps(100) },			\
	{ IFM_ETHER | IFM_100_VG,	IF_Mbps(100) },			\
	{ IFM_ETHER | IFM_100_T2,	IF_Mbps(100) },			\
	{ IFM_ETHER | IFM_1000_SX,	IF_Mbps(1000) },		\
	{ IFM_ETHER | IFM_10_STP,	IF_Mbps(10) },			\
	{ IFM_ETHER | IFM_10_FL,	IF_Mbps(10) },			\
	{ IFM_ETHER | IFM_1000_LX,	IF_Mbps(1000) },		\
	{ IFM_ETHER | IFM_1000_CX,	IF_Mbps(1000) },		\
	{ IFM_ETHER | IFM_1000_T,	IF_Mbps(1000) },		\
	{ IFM_ETHER | IFM_HPNA_1,	IF_Mbps(1) },			\
	{ IFM_ETHER | IFM_10G_LR,	IF_Gbps(10ULL) },		\
	{ IFM_ETHER | IFM_10G_SR,	IF_Gbps(10ULL) },		\
	{ IFM_ETHER | IFM_10G_CX4,	IF_Gbps(10ULL) },		\
	{ IFM_ETHER | IFM_2500_SX,	IF_Mbps(2500ULL) },		\
	{ IFM_ETHER | IFM_1000_BX10,	IF_Mbps(1000ULL) },		\
	{ IFM_ETHER | IFM_10G_TWINAX,	IF_Gbps(10) },			\
	{ IFM_ETHER | IFM_10G_TWINAX_LONG, IF_Gbps(10) },		\
	{ IFM_ETHER | IFM_10G_LRM,	IF_Gbps(10) },			\
	{ IFM_ETHER | IFM_10G_T,	IF_Gbps(10) },			\
	{ IFM_ETHER | IFM_1000_KX,	IF_Mbps(1000ULL) },		\
	{ IFM_ETHER | IFM_2500_KX,	IF_Mbps(2500ULL) },		\
	{ IFM_ETHER | IFM_2500_T,	IF_Mbps(2500ULL) },		\
	{ IFM_ETHER | IFM_5000_T,	IF_Gbps(5) },			\
	{ IFM_ETHER | IFM_1000_SGMII,	IF_Gbps(1) },			\
	{ IFM_ETHER | IFM_5000_KR,	IF_Gbps(5) },			\
	{ IFM_ETHER | IFM_10G_AOC,	IF_Gbps(10) },			\
	{ IFM_ETHER | IFM_10G_CR1,	IF_Gbps(10) },			\
	{ IFM_ETHER | IFM_10G_ER,	IF_Gbps(10) },			\
	{ IFM_ETHER | IFM_10G_KR,	IF_Gbps(10) },			\
	{ IFM_ETHER | IFM_10G_KX4,	IF_Gbps(10) },			\
	{ IFM_ETHER | IFM_10G_LX4,	IF_Gbps(10) },			\
	{ IFM_ETHER | IFM_10G_SFI,	IF_Gbps(10) },			\
	{ IFM_ETHER | IFM_10G_ZR,	IF_Gbps(10) },			\
	{ IFM_ETHER | IFM_20G_KR2,	IF_Gbps(20) },			\
	{ IFM_ETHER | IFM_25G_ACC,	IF_Gbps(25) },			\
	{ IFM_ETHER | IFM_25G_AOC,	IF_Gbps(25) },			\
	{ IFM_ETHER | IFM_25G_AUI,	IF_Gbps(25) },			\
	{ IFM_ETHER | IFM_25G_CR,	IF_Gbps(25) },			\
	{ IFM_ETHER | IFM_25G_CR_S,	IF_Gbps(25) },			\
	{ IFM_ETHER | IFM_25G_ER,	IF_Gbps(25) },			\
	{ IFM_ETHER | IFM_25G_KR,	IF_Gbps(25) },			\
	{ IFM_ETHER | IFM_25G_KR_S,	IF_Gbps(25) },			\
	{ IFM_ETHER | IFM_25G_LR,	IF_Gbps(25) },			\
	{ IFM_ETHER | IFM_25G_SR,	IF_Gbps(25) },			\
	{ IFM_ETHER | IFM_25G_T,	IF_Gbps(25) },			\
	{ IFM_ETHER | IFM_40G_AOC,	IF_Gbps(40) },			\
	{ IFM_ETHER | IFM_40G_CR4,	IF_Gbps(40) },			\
	{ IFM_ETHER | IFM_40G_ER4,	IF_Gbps(40) },			\
	{ IFM_ETHER | IFM_40G_FR,	IF_Gbps(40) },			\
	{ IFM_ETHER | IFM_40G_KR4,	IF_Gbps(40) },			\
	{ IFM_ETHER | IFM_40G_LR4,	IF_Gbps(40) },			\
	{ IFM_ETHER | IFM_40G_SR4,	IF_Gbps(40) },			\
	{ IFM_ETHER | IFM_40G_T,	IF_Gbps(40) },			\
	{ IFM_ETHER | IFM_40G_XLPPI,	IF_Gbps(40) },			\
	{ IFM_ETHER | IFM_50G_AUI1,	IF_Gbps(50) },			\
	{ IFM_ETHER | IFM_50G_AUI2,	IF_Gbps(50) },			\
	{ IFM_ETHER | IFM_50G_CR,	IF_Gbps(50) },			\
	{ IFM_ETHER | IFM_50G_CR2,	IF_Gbps(50) },			\
	{ IFM_ETHER | IFM_50G_FR,	IF_Gbps(50) },			\
	{ IFM_ETHER | IFM_50G_KR,	IF_Gbps(50) },			\
	{ IFM_ETHER | IFM_50G_KR2,	IF_Gbps(50) },			\
	{ IFM_ETHER | IFM_50G_LAUI2,	IF_Gbps(50) },			\
	{ IFM_ETHER | IFM_50G_LR,	IF_Gbps(50) },			\
	{ IFM_ETHER | IFM_50G_SR,	IF_Gbps(50) },			\
	{ IFM_ETHER | IFM_50G_SR2,	IF_Gbps(50) },			\
	{ IFM_ETHER | IFM_56G_R4,	IF_Gbps(56) },			\
	{ IFM_ETHER | IFM_100G_ACC,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_AOC,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_CR2,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_CR4,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_CR10,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_DR,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_ER4,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_FR,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_KP4,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_KR2,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_KR4,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_LR,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_LR4,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_SR2,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_SR4,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_100G_SR10,	IF_Gbps(100) },			\
	{ IFM_ETHER | IFM_200G_CR2,	IF_Gbps(200) },			\
	{ IFM_ETHER | IFM_200G_CR4,	IF_Gbps(200) },			\
	{ IFM_ETHER | IFM_200G_DR4,	IF_Gbps(200) },			\
	{ IFM_ETHER | IFM_200G_ER4,	IF_Gbps(200) },			\
	{ IFM_ETHER | IFM_200G_FR4,	IF_Gbps(200) },			\
	{ IFM_ETHER | IFM_200G_KR2,	IF_Gbps(200) },			\
	{ IFM_ETHER | IFM_200G_KR4,	IF_Gbps(200) },			\
	{ IFM_ETHER | IFM_200G_LR4,	IF_Gbps(200) },			\
	{ IFM_ETHER | IFM_200G_SR4,	IF_Gbps(200) },			\
	{ IFM_ETHER | IFM_400G_CR4,	IF_Gbps(400) },			\
	{ IFM_ETHER | IFM_400G_DR4,	IF_Gbps(400) },			\
	{ IFM_ETHER | IFM_400G_ER8,	IF_Gbps(400) },			\
	{ IFM_ETHER | IFM_400G_FR4,	IF_Gbps(400) },			\
	{ IFM_ETHER | IFM_400G_FR8,	IF_Gbps(400) },			\
	{ IFM_ETHER | IFM_400G_KR4,	IF_Gbps(400) },			\
	{ IFM_ETHER | IFM_400G_LR4,	IF_Gbps(400) },			\
	{ IFM_ETHER | IFM_400G_LR8,	IF_Gbps(400) },			\
	{ IFM_ETHER | IFM_400G_SR4_2,	IF_Gbps(400) },			\
	{ IFM_ETHER | IFM_400G_SR8,	IF_Gbps(400) },			\
	{ IFM_ETHER | IFM_400G_SR16,	IF_Gbps(400) },			\
									\
	{ IFM_TOKEN | IFM_TOK_STP4,	IF_Mbps(4) },			\
	{ IFM_TOKEN | IFM_TOK_STP16,	IF_Mbps(16) },			\
	{ IFM_TOKEN | IFM_TOK_UTP4,	IF_Mbps(4) },			\
	{ IFM_TOKEN | IFM_TOK_UTP16,	IF_Mbps(16) },			\
									\
	{ IFM_FDDI | IFM_FDDI_SMF,	IF_Mbps(100) },			\
	{ IFM_FDDI | IFM_FDDI_MMF,	IF_Mbps(100) },			\
	{ IFM_FDDI | IFM_FDDI_UTP,	IF_Mbps(100) },			\
									\
	{ IFM_IEEE80211 | IFM_IEEE80211_FH1,	IF_Mbps(1) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_FH2,	IF_Mbps(2) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS2,	IF_Mbps(2) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS5,	IF_Kbps(5500) },	\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS11,	IF_Mbps(11) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS1,	IF_Mbps(1) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_DS22,	IF_Mbps(22) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM6,	IF_Mbps(6) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM9,	IF_Mbps(9) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM12,	IF_Mbps(12) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM18,	IF_Mbps(18) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM24,	IF_Mbps(24) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM36,	IF_Mbps(36) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM48,	IF_Mbps(48) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM54,	IF_Mbps(54) },		\
	{ IFM_IEEE80211 | IFM_IEEE80211_OFDM72,	IF_Mbps(72) },		\
									\
	{ 0, 0 },							\
}

/*
 * Status bit descriptions for the various media types.
 */
struct ifmedia_status_description {
	int	ifms_type;
	int	ifms_valid;
	int	ifms_bit;
	const char *ifms_string[2];
};

#define	IFM_STATUS_DESC(ifms, bit)					\
	(ifms)->ifms_string[((ifms)->ifms_bit & (bit)) ? 1 : 0]

#define	IFM_STATUS_DESCRIPTIONS {					\
	{ IFM_GENERIC,		IFM_AVALID,	IFM_ACTIVE,		\
	  { "no network", "active" } },					\
									\
	{ IFM_ETHER,		IFM_AVALID,	IFM_ACTIVE,		\
	  { "no carrier", "active" } },					\
									\
	{ IFM_FDDI,		IFM_AVALID,	IFM_ACTIVE,		\
	  { "no ring", "inserted" } },					\
									\
	{ IFM_TOKEN,		IFM_AVALID,	IFM_ACTIVE,		\
	  { "no ring", "inserted" } },					\
									\
	{ IFM_IEEE80211,	IFM_AVALID,	IFM_ACTIVE,		\
	  { "no network", "active" } },					\
									\
	{ IFM_CARP,		IFM_AVALID,	IFM_ACTIVE,		\
	    { "backup", "master" } },					\
									\
	{ 0,			0,		0,			\
	  { NULL, NULL } },						\
}

#ifdef _KERNEL
#include <sys/mutex.h>
#include <sys/queue.h>

/*
 * Driver callbacks for media status and change requests.
 */
typedef	int (*ifm_change_cb_t)(struct ifnet *);
typedef	void (*ifm_stat_cb_t)(struct ifnet *, struct ifmediareq *);

/*
 * In-kernel representation of a single supported media type.
 */
struct ifmedia_entry {
	TAILQ_ENTRY(ifmedia_entry) ifm_list;
	u_int	ifm_media;	/* IFMWD: description of this media */
	u_int	ifm_data;	/* for driver-specific use */
	void	*ifm_aux;	/* for driver-specific use */
};

/*
 * One of these goes into a network interface's softc structure.
 * It is used to keep general media state.
 *
 * LOCKING
 * =======
 * The ifmedia is protected by a lock provided by the interface
 * driver.  All ifmedia API entry points (with the exception of one)
 * are expect to be called with this mutex NOT HELD.
 *
 * ifmedia_ioctl() is called with the interface's if_ioctl_lock held,
 * and thus the locking order is:
 *
 *	IFNET_LOCK -> ifm_lock
 *
 * Driver callbacks (ifm_change / ifm_status) are called with ifm_lock HELD.
 *
 * Field markings and the corresponding locks:
 *
 * m:	ifm_lock
 * ::	unlocked, stable
 */
struct ifmedia {
	kmutex_t *ifm_lock;	/* :: mutex (provided by interface driver) */
	u_int	ifm_mask;	/* :: IFMWD: mask of changes we don't care */
	u_int	ifm_media;	/*
				 * m: IFMWD: current user-set media word.
				 *
				 * XXX some drivers misuse this entry as
				 * current active media word. Don't use this
				 * entry as this purpose but use driver
				 * specific entry if you don't use mii(4).
				 */
	struct ifmedia_entry *ifm_cur;	/*
					 * m: entry corresponding to
					 * ifm_media
					 */
	TAILQ_HEAD(, ifmedia_entry) ifm_list; /*
					       * m: list of all supported
					       * media
					       */
	ifm_change_cb_t	ifm_change;	/* :: media change driver callback */
	ifm_stat_cb_t	ifm_status;	/* :: media status driver callback */
	uintptr_t	ifm_legacy;	/* m: legacy driver handling */
};

#define	ifmedia_lock(ifm)	mutex_enter((ifm)->ifm_lock)
#define	ifmedia_unlock(ifm)	mutex_exit((ifm)->ifm_lock)
#define	ifmedia_locked(ifm)	mutex_owned((ifm)->ifm_lock)

#ifdef __IFMEDIA_PRIVATE
#define	ifmedia_islegacy(ifm)	((ifm)->ifm_legacy)
void	ifmedia_lock_for_legacy(struct ifmedia *);
void	ifmedia_unlock_for_legacy(struct ifmedia *);

#define	IFMEDIA_LOCK_FOR_LEGACY(ifm)					\
do {									\
	if (ifmedia_islegacy(ifm))					\
		ifmedia_lock_for_legacy(ifm);				\
} while (/*CONSTCOND*/0)

#define	IFMEDIA_UNLOCK_FOR_LEGACY(ifm)					\
do {									\
	if (ifmedia_islegacy(ifm))					\
		ifmedia_unlock_for_legacy(ifm);				\
} while (/*CONSTCOND*/0)
#endif /* __IFMEDIA_PRIVATE */

/* Initialize an interface's struct if_media field. */
void	ifmedia_init(struct ifmedia *, int, ifm_change_cb_t, ifm_stat_cb_t);
void	ifmedia_init_with_lock(struct ifmedia *, int, ifm_change_cb_t,
	    ifm_stat_cb_t, kmutex_t *);

/* Release resourecs associated with an ifmedia. */
void	ifmedia_fini(struct ifmedia *);


/* Add one supported medium to a struct ifmedia. */
void	ifmedia_add(struct ifmedia *, int, int, void *);

/* Add an array (of ifmedia_entry) media to a struct ifmedia. */
void	ifmedia_list_add(struct ifmedia *, struct ifmedia_entry *, int);

/* Set default media type on initialization. */
void	ifmedia_set(struct ifmedia *ifm, int mword);

/* Common ioctl function for getting/setting media, called by driver. */
int	ifmedia_ioctl(struct ifnet *, struct ifreq *, struct ifmedia *, u_long);

/* Look up a media entry. */
struct ifmedia_entry *ifmedia_match(struct ifmedia *, u_int, u_int);

/* Delete all media for a given media instance */
void	ifmedia_delete_instance(struct ifmedia *, u_int);

/* Remove all media */
void	ifmedia_removeall(struct ifmedia *);

/* Compute baudrate for a given media. */
uint64_t ifmedia_baudrate(int);

/*
 * This is a thin wrapper around the ifmedia "change" callback that
 * is available to drivers to use within their own initialization
 * routines.
 *
 * IFMEDIA must be LOCKED.
 */
int	ifmedia_change(struct ifmedia *, struct ifnet *);

#else
/* Functions for converting media to/from strings, in libutil/if_media.c */
const char *get_media_type_string(int);
const char *get_media_subtype_string(int);
const char *get_media_mode_string(int);
const char *get_media_option_string(int *);
int	get_media_mode(int, const char *);
int	get_media_subtype(int, const char *);
int	get_media_options(int, const char *, char **);
int	lookup_media_word(struct ifmedia_description *, int, const char *);
#endif /* _KERNEL */

#endif /* !_NET_IF_MEDIA_H_ */