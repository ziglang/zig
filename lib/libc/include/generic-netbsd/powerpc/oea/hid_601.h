/*	$NetBSD: hid_601.h,v 1.2 2008/04/28 20:23:32 martin Exp $	*/

/*-
 * Copyright (c) 1999 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Jason R. Thorpe.
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

#ifndef _POWERPC_OEA_HID_601_H_
#define _POWERPC_OEA_HID_601_H_
/*
 * Hardware Implementation Dependent registers for the PowerPC 601.
 */

/*
 * HID0 (SPR 1008) -- Checkstop Enable/Disable and Status register
 */
/*	v- feature bits -v						*/
#define	HID0_601_EHP	0x00000001	/* enable HP_SNP_REQ# */
#define	HID0_601_EMC	0x00000002	/* main cache error */
#define	HID0_601_PAR	0x00000004	/* precharge of ARTRY#/SHD# disabled */
#define	HID0_601_LM	0x00000008	/* little endian mode */
#define	HID0_601_DRL	0x00000010	/* alt sec rld of load/store miss */
#define	HID0_601_DRF	0x00000020	/* alt sec rld of insn fetch miss */
/*	v- checkstop enable/disable bits -v				*/
#define	HID0_601_EPP	0x00000040	/* i/o protocol checkstop */
#define	HID0_601_EIU	0x00000080	/* invalid uCode checkstop */
#define	HID0_601_ECP	0x00000100	/* cache parity checkstop */
#define	HID0_601_EBD	0x00000200	/* data bus parity checkstop */
#define	HID0_601_EBA	0x00000400	/* address bus parity checkstop */
#define	HID0_601_EDT	0x00000800	/* dispatch timeout checkstop */
#define	HID0_601_ESH	0x00001000	/* sequencer timeout checkstop */
#define	HID0_601_ECD	0x00002000	/* cache checkstop */
#define	HID0_601_ETD	0x00004000	/* TLB checkstop */
#define	HID0_601_EM	0x00008000	/* machine checkstop */
#define	HID0_601_ES	0x00010000	/* uCode checkstop */
		/*	0x00020000	   reserved */
		/*	0x00040000	   reserved */
		/*	0x00080000	   reserved */
/*	v- status bits -- correspond to enable bits above -v		*/
#define	HID0_601_PP	0x00100000
#define	HID0_601_IU	0x00200000
#define	HID0_601_CP	0x00400000
#define	HID0_601_BD	0x00800000
#define	HID0_601_BA	0x01000000
#define	HID0_601_DT	0x02000000
#define	HID0_601_SH	0x04000000
#define	HID0_601_CD	0x08000000
#define	HID0_601_TD	0x10000000
#define	HID0_601_M	0x20000000
#define	HID0_601_S	0x40000000

#define	HID0_601_CE	0x80000000	/* master checkstop enable */

#define HID0_601_BITMASK "\020" \
    "\040CE\037S\036M\035TD\034CD\033SH\032DT\031BA" \
    "\030BD\027CP\026IU\025PP\021ES" \
    "\020EM\017ETC\016ECD\015ESH\014EDT\013EBA\012EBD\011ECP" \
    "\010EIU\007EPP\006DRF\005DRL\004LM\003PAR\002EMC\001EHP"


/*
 * HID1 (SPR 1009) -- Debug Modes register
 */
	/* XXX */


/*
 * HID2 (SPR 1010) -- Instruction Address Breakpoint Register
 */


/*
 * HID5 (SPR 1013) -- Data Address Breakpoint Register
 */


/*
 * HID15 (SPR 1023) -- Processor ID Register
 */
#define	HID15_601_PID	0x0000000f	/* processor ID mask */

#endif /* _POWERPC_OEA_HID_601_H_ */