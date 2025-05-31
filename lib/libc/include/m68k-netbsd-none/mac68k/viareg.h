/*	$NetBSD: viareg.h,v 1.14 2005/12/11 12:18:03 christos Exp $	*/

/*-
 * Copyright (C) 1993	Allen K. Briggs, Chris P. Caputo,
 *			Michael L. Finch, Bradley A. Grantham, and
 *			Lawrence A. Kesteloot
 * All rights reserved.
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
 *	This product includes software developed by the Alice Group.
 * 4. The names of the Alice Group or any of its members may not be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE ALICE GROUP ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE ALICE GROUP BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
/*

	Prototype VIA control definitions

	06/04/92,22:33:57 BG Let's see what I can do.

*/


	/* VIA1 data register A */
#define DA1I_vSCCWrReq	0x80
#define DA1O_vPage2	0x40
#define DA1I_CPU_ID1	0x40
#define DA1O_vHeadSel	0x20
#define DA1O_vOverlay	0x10
#define DA1O_vSync	0x08
#define DA1O_RESERVED2	0x04
#define DA1O_RESERVED1	0x02
#define DA1O_RESERVED0	0x01

	/* VIA1 data register B */
#define DB1I_Par_Err	0x80
#define DB1O_vSndEnb	0x80
#define DB1O_Par_Enb	0x40
#define DB1O_AuxIntEnb	0x40	/* 0 = enabled, 1 = disabled */
#define DB1O_vFDesk2	0x20
#define DB1O_vFDesk1	0x10
#define DB1I_vFDBInt	0x08
#define DB1O_rTCEnb	0x04
#define DB1O_rTCCLK	0x02
#define DB1O_rTCData	0x01
#define DB1I_rTCData	0x01

	/* VIA2 data register A */
#define DA2O_v2Ram1	0x80
#define DA2O_v2Ram0	0x40
#define DA2I_v2IRQ0	0x40
#define DA2I_v2IRQE	0x20
#define DA2I_v2IRQD	0x10
#define DA2I_v2IRQC	0x08
#define DA2I_v2IRQB	0x04
#define DA2I_v2IRQA	0x02
#define DA2I_v2IRQ9	0x01

	/* VIA2 data register B */
#define DB2O_v2VBL	0x80
#define DB2O_Par_Test	0x80
#define DB2I_v2SNDEXT	0x40
#define DB2I_v2TM0A	0x20
#define DB2I_v2TM1A	0x10
#define DB2I_vFC3	0x08
#define DB2O_vFC3	0x08
#define DB2O_v2PowerOff	0x04
#define DB2O_v2BusLk	0x02
#define DB2O_vCDis	0x01
#define DB2O_CEnable	0x01

/*
 * VIA1 interrupts
 */
#define	VIA1_T1		6
#define	VIA1_T2		5
#define	VIA1_ADBCLK	4
#define	VIA1_ADBDATA	3
#define	VIA1_ADBRDY	2
#define	VIA1_VBLNK	1
#define	VIA1_ONESEC	0

/* VIA1 interrupt bits */
#define V1IF_IRQ	0x80
#define V1IF_T1		(1 << VIA1_T1)
#define V1IF_T2		(1 << VIA1_T2)
#define V1IF_ADBCLK	(1 << VIA1_ADBCLK)
#define V1IF_ADBDATA	(1 << VIA1_ADBDATA)
#define V1IF_ADBRDY	(1 << VIA1_ADBRDY)
#define V1IF_VBLNK	(1 << VIA1_VBLNK)
#define V1IF_ONESEC	(1 << VIA1_ONESEC)

/*
 * VIA2 interrupts
 */
#define VIA2_T1		6
#define VIA2_T2		5
#define VIA2_ASC	4
#define VIA2_SCSIIRQ	3
#define VIA2_EXPIRQ	2
#define VIA2_SLOTINT	1
#define VIA2_SCSIDRQ	0

/* VIA2 interrupt bits */
#define	V2IF_IRQ	0x80
#define	V2IF_T1		(1 << VIA2_T1)
#define	V2IF_T2		(1 << VIA2_T2)
#define	V2IF_ASC	(1 << VIA2_ASC)
#define	V2IF_SCSIIRQ	(1 << VIA2_SCSIIRQ)
#define	V2IF_EXPIRQ	(1 << VIA2_EXPIRQ)
#define	V2IF_SLOTINT	(1 << VIA2_SLOTINT)
#define	V2IF_SCSIDRQ	(1 << VIA2_SCSIDRQ)

#define VIA1_INTS	(V1IF_T1 | V1IF_ADBRDY)
#define VIA2_INTS	(V2IF_T1 | V2IF_ASC | V2IF_SCSIIRQ | V2IF_SLOTINT | \
			 V2IF_SCSIDRQ)

#define RBV_INTS	(V2IF_T1 | V2IF_ASC | V2IF_SCSIIRQ | V2IF_SLOTINT | \
			 V2IF_SCSIDRQ | V1IF_ADBRDY)

#define ACR_T1LATCH	0x40

extern volatile unsigned char *Via1Base;
extern volatile unsigned char *Via2Base;	/* init in VIA_Initialize */
#define VIA1_addr	Via1Base	/* at PA 0x50f00000 */

#define VIA2OFF		1		/* VIA2 addr = VIA1_addr + 0x2000 */
#define RBVOFF		0x13		/* RBV addr = VIA1_addr + 0x26000 */
#define OSSOFF		0xd		/* OSS addr = VIA1_addr + 0x1A000 */

#define VIA1		0
extern int VIA2;

	/* VIA interface registers */
#define vBufA		0x1e00	/* register A */
#define vBufB		0	/* register B */
#define vDirA		0x0600	/* data direction register */
#define vDirB		0x0400	/* data direction register */
#define vT1C		0x0800
#define vT1CH		0x0a00
#define vT1L		0x0c00
#define vT1LH		0x0e00
#define vT2C		0x1000
#define vT2CH		0x1200
#define vSR		0x1400	/* shift register */
#define vACR		0x1600	/* aux control register */
#define vPCR		0x1800	/* peripheral control register */
#define vIFR		0x1a00	/* interrupt flag register */
#define vIER		0x1c00	/* interrupt enable register */

	/* RBV interface registers */
#define rBufB		0	/* register B */
#define rBufA		2	/* register A */
#define rIFR		0x3	/* interrupt flag register (writes?) */
#define rIER		0x13	/* interrupt enable register */
#define rMonitor	0x10	/* Monitor type */
#define rSlotInt	0x12	/* Slot interrupt */

	/* RBV monitor type flags and masks */
#define RBVDepthMask	0x07	/* Depth in bits */
#define RBVMonitorMask	0x38	/* Type numbers */
#define RBVOff		0x40	/* Monitor turned off */
#define RBVMonIDBWP	0x08	/* 15 inch BW portrait */
#define RBVMonIDRGB12	0x10	/* 12 inch color */
#define RBVMonIDRGB15	0x28	/* 15 inch RGB */
#define RBVMonIDStd	0x30	/* 12 inch BW or 13 inch color */
#define RBVMonIDNone	0x38	/* No monitor connected */

	/* OSS registers */
#define OSS_IFR		0x202
#define OSS_PENDING_IRQ	(*(volatile u_short *)(Via2Base + (OSS_IFR)))

#define OSS_oRCR	0x204
#define OSS_POWEROFF	 0x80

#define via_reg(v, r) (*(Via1Base+(v)*0x2000+(r)))
#define via2_reg(r) (*(Via2Base+(r)))

#define vDirA_ADBState	0x30

void	via_init(void);
void	via_powerdown(void);
void	via_set_modem(int);
int	add_nubus_intr(int, void (*)(void *), void *);
void	enable_nubus_intr(void);
void	via1_register_irq(int, void (*)(void *), void *);
void	via2_register_irq(int, void (*)(void *), void *);

extern void	(*via1itab[7])(void *);
extern void	(*via2itab[7])(void *);