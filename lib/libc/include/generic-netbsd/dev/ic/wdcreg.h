/*	$NetBSD: wdcreg.h,v 1.35 2012/01/15 20:08:54 jakllsch Exp $	*/

/*-
 * Copyright (c) 1991 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
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
 *	@(#)wdreg.h	7.1 (Berkeley) 5/9/91
 */

#ifndef _DEV_IC_WDCREG_H_
#define	_DEV_IC_WDCREG_H_

/*
 * WD1003 / ATA Disk Controller register definitions.
 */

/* offsets of registers in the 'regular' register region */
#define	wd_data			0	/* data register (R/W - 16 bits) */
#define	wd_error		1	/* error register (R) */
#define	wd_precomp		1	/* write precompensation (W) */
#define	wd_seccnt		2	/* sector count (R/W) */
#define	wd_ireason		2	/* interrupt reason (R/W) (for atapi) */
#define	wd_sector		3	/* first sector number (R/W) */
#define	wd_cyl_lo		4	/* cylinder address, low byte (R/W) */
#define	wd_cyl_hi		5	/* cylinder address, high byte (R/W) */
#define	wd_sdh			6	/* sector size/drive/head (R/W) */
#define	wd_command		7	/* command register (W)	*/
#define	wd_lba_lo		3	/* lba address, low byte (RW) */
#define	wd_lba_mi		4	/* lba address, middle byte (RW) */
#define	wd_lba_hi		5	/* lba address, high byte (RW) */

/* "shadow" registers; these may or may not overlap regular registers */
#define	wd_status		8	/* immediate status (R) */
#define	wd_features		9	/* features (W) */

/* offsets of registers in the auxiliary register region */
#define	wd_aux_altsts		0	/* alternate fixed disk status (R) */
#define	wd_aux_ctlr		0	/* fixed disk controller control (W) */
#define  WDCTL_HOB		 0x80	/* read high order byte */
#define  WDCTL_4BIT		 0x08	/* use four head bits (wd1003) */
#define  WDCTL_RST		 0x04	/* reset the controller */
#define  WDCTL_IDS		 0x02	/* disable controller interrupts */
#if 0 /* NOT MAPPED; fd uses this register on PCs */
#define	wd_digin		1	/* disk controller input (R) */
#endif

#endif /* _DEV_IC_WDCREG_H_ */