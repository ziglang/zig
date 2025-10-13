/* $NetBSD: sfbreg.h,v 1.3 2000/12/19 01:25:46 perseant Exp $ */

/*
 * Copyright (c) 1996 Carnegie-Mellon University.
 * All rights reserved.
 *
 * Author: Chris G. Demetriou
 *
 * Permission to use, copy, modify and distribute this software and
 * its documentation is hereby granted, provided that both the copyright
 * notice and this permission notice appear in all copies of the
 * software, derivative works or modified versions, and any portions
 * thereof, and that both notices appear in supporting documentation.
 *
 * CARNEGIE MELLON ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
 * CONDITION.  CARNEGIE MELLON DISCLAIMS ANY LIABILITY OF ANY KIND
 * FOR ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
 *
 * Carnegie Mellon requests users of this software to return to
 *
 *  Software Distribution Coordinator  or  Software.Distribution@CS.CMU.EDU
 *  School of Computer Science
 *  Carnegie Mellon University
 *  Pittsburgh PA 15213-3890
 *
 * any improvements or extensions that they make and grant Carnegie the
 * rights to redistribute these changes.
 */

/*
 * Smart ("CXTurbo") Frame Buffer definitions, from:
 * ``DEC 3000 300/400/500/600/700/800/900 AXP Models System Prgrammer's Manual''
 * (DEC order number EK-D3SYS-PM), section 6.
 *
 * All definitions are in "dense" TURBOchannel space.
 */

#ifndef _DEV_TC_SFBREG_H_
#define _DEV_TC_SFBREG_H_

/*
 * Size of the SFB address space.
 */
#define	SFB_SIZE		0x1000000

/*
 * Offsets into slot space of each functional unit.
 */
#define	SFB_ASIC_OFFSET		0x0100000	/* SFB ASIC Control Registers */
#define	SFB_ASIC_SIZE		0x0020000
#define	SFB_RAMDAC_OFFSET	0x01c0000	/* BrookTree RAMDAC */
#define	SFB_RAMDAC_SIZE		0x0040000
#define	SFB_FB_OFFSET		0x0200000	/* Frame buffer */
#define	SFB_FB_SIZE		0x0200000
#define	SFB_OSBM_OFFSET		0x0600000	/* Off-screen buffer memory */
#define	SFB_OSBM_SIZE		0x0200000

/*
 * SFB ASIC registers (offsets from SFB_ASIC_OFFSET).
 */
#define	SFB_ASIC_COPYBUF_0	0x0000	/* Copy buffer register 0 (R/W) */
#define	SFB_ASIC_COPYBUF_1	0x0004	/* Copy buffer register 1 (R/W) */
#define	SFB_ASIC_COPYBUF_2	0x0008	/* Copy buffer register 2 (R/W) */
#define	SFB_ASIC_COPYBUF_3	0x000c	/* Copy buffer register 3 (R/W) */
#define	SFB_ASIC_COPYBUF_4	0x0010	/* Copy buffer register 4 (R/W) */
#define	SFB_ASIC_COPYBUF_5	0x0014	/* Copy buffer register 5 (R/W) */
#define	SFB_ASIC_COPYBUF_6	0x0018	/* Copy buffer register 6 (R/W) */
#define	SFB_ASIC_COPYBUF_7	0x001c	/* Copy buffer register 7 (R/W) */
#define	SFB_ASIC_FG		0x0020	/* Foreground (R/W) */
#define	SFB_ASIC_BG		0x0024	/* Background (R/W) */
#define	SFB_ASIC_PLANEMASK	0x0028	/* PlaneMask (R/W) */
#define	SFB_ASIC_PIXELMASK	0x002c	/* PixelMask (R/W) */
#define	SFB_ASIC_MODE		0x0030	/* Mode (R/W) */
#define	SFB_ASIC_ROP		0x0034	/* RasterOp (R/W) */
#define	SFB_ASIC_PIXELSHIFT	0x0038	/* PixelShift (R/W) */
#define	SFB_ASIC_ADDRESS	0x003c	/* Address (R/W) */
#define	SFB_ASIC_BRES1		0x0040	/* Bresenham register 1 (R/W) */
#define	SFB_ASIC_BRES2		0x0044	/* Bresenham register 2 (R/W) */
#define	SFB_ASIC_BRES3		0x0048	/* Bresenham register 3 (R/W) */
#define	SFB_ASIC_BCONT		0x004c	/* Bcont (W) */
#define	SFB_ASIC_DEEP		0x0050	/* Deep (R/W) */
#define	SFB_ASIC_START		0x0054	/* Start (W) */
#define	SFB_ASIC_CLEAR_INTR	0x0058	/* Clear Interrupt (W) */
#define	SFB_ASIC_VIDEO_REFRESH	0x0060	/* Video refresh counter (R/W) */
#define	SFB_ASIC_VIDEO_HSETUP	0x0064	/* Video horizontal setup (R/W) */
#define	SFB_ASIC_VIDEO_VSETUP	0x0068	/* Video vertical setup (R/W) */
#define	SFB_ASIC_VIDEO_BASE	0x006c	/* Video base address (R/W) */
#define	SFB_ASIC_VIDEO_VALID	0x0070	/* Video valid (W) */
#define	SFB_ASIC_ENABLE_INTR	0x0074	/* Enable/Disable Interrupts (W) */
#define	SFB_ASIC_TCCLK		0x0078	/* TCCLK count (R/W) */
#define	SFB_ASIC_VIDCLK		0x007c	/* VIDCLK count (R/W) */

/*
 * Same as above but in 32-bit units, and named like the corrseponding
 * TGA registers, for easy comparison.
 */
typedef u_int32_t sfb_reg_t;

#define	SFB_REG_GCBR0	0x000		/* Copy buffer 0 */
#define	SFB_REG_GCBR1	0x001		/* Copy buffer 1 */
#define	SFB_REG_GCBR2	0x002		/* Copy buffer 2 */
#define	SFB_REG_GCBR3	0x003		/* Copy buffer 3 */
#define	SFB_REG_GCBR4	0x004		/* Copy buffer 4 */
#define	SFB_REG_GCBR5	0x005		/* Copy buffer 5 */
#define	SFB_REG_GCBR6	0x006		/* Copy buffer 6 */
#define	SFB_REG_GCBR7	0x007		/* Copy buffer 7 */

#define	SFB_REG_GFGR	0x008		/* Foreground */
#define	SFB_REG_GBGR	0x009		/* Background */
#define	SFB_REG_GPMR	0x00a		/* Plane Mask */
#define	SFB_REG_GPXR_S	0x00b		/* Pixel Mask (one-shot) */
#define	SFB_REG_GMOR	0x00c		/* Mode */
#define	SFB_REG_GOPR	0x00d		/* Raster Operation */
#define	SFB_REG_GPSR	0x00e		/* Pixel Shift */
#define	SFB_REG_GADR	0x00f		/* Address */

#define	SFB_REG_GB1R	0x010		/* Bresenham 1 */
#define	SFB_REG_GB2R	0x011		/* Bresenham 2 */
#define	SFB_REG_GB3R	0x012		/* Bresenham 3 */

#define	SFB_REG_GCTR	0x013		/* Continue */
#define	SFB_REG_GDER	0x014		/* Deep */
#define SFB_REG_GREV	0x015		/* Start/Version on SFB,

 					 * Revision on SFB2 */
#define SFB_REG_CINT	0x016		/* Clear Interrupt */
/* 0x017 - unused */
#define SFB_REG_VRFR	0x018		/* Video Refresh */
#define	SFB_REG_VHCR	0x019		/* Horizontal Control */
#define	SFB_REG_VVCR	0x01a		/* Vertical Control */
#define	SFB_REG_VVBR	0x01b		/* Video Base Address */
#define	SFB_REG_VVVR	0x01c		/* Video Valid */
#define	SFB_REG_SISR	0x01d		/* Enable/Disable Interrupts */
#define	SFB_REG_TCCLK	0x01e		/* TCCLK count (R/W) */
#define	SFB_REG_VIDCLK	0x01f		/* VIDCLK count (R/W) */

#endif /* _DEV_TC_SFBREG_H_ */