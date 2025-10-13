/*	$NetBSD: eeprom.h,v 1.3 2008/04/28 20:23:58 martin Exp $	*/

/*-
 * Copyright (c) 1996 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Gordon W. Ross.
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

#ifndef _DEV_SUN_EEPROM_H_
#define	_DEV_SUN_EEPROM_H_

/*
 * Structure/definitions for the Sun3/Sun4 EEPROM.
 *
 * This information is published in the Sun document:
 * "PROM User's Manual", part number 800-1736010.
 */

/*
 * Note that most places where the PROM stores a "true/false" flag,
 * the true value is 0x12 and false is the usual zero.  Such flags
 * all take the values EE_TRUE or EE_FALSE so this file does not
 * need to define so many value macros.
 */
#define	EE_TRUE 0x12
#define	EE_FALSE   0

struct eeprom {

	/* 0x00 */
	uint8_t	eeTestArea[4];		/* Factory Defined */
	uint16_t eeWriteCount[4];	/*    ||      ||   */
	uint8_t	eeChecksum[4];  	/*    ||      ||   */
	uint32_t eeLastHwUpdate; 	/*    ||      ||   */

	/* 0x14 */
	uint8_t	eeInstalledMem; 	/* Megabytes */
	uint8_t	eeMemTestSize;		/*     ||    */

	/* 0x16 */
	uint8_t	eeScreenSize;
#define	EE_SCR_1152X900 	0x00
#define	EE_SCR_1024X1024	0x12
#define EE_SCR_1600X1280	0x13
#define EE_SCR_1440X1440	0x14

	uint8_t	eeWatchDogDoesReset;	/* Watchdog timeout action:
					 * true:  reset/reboot
					 * false: return to monitor
					 */
	/* 0x18 */
	uint8_t	eeBootDevStored;	/* Is the boot device stored:
					 * true:  use stored device spec.
					 * false: use default (try all)
					 */
	/* 0x19 */
	/* Stored boot device spec. i.e.: "sd(Ctlr,Unit,Part)" */
	uint8_t	eeBootDevName[2];	/* xy,xd,sd,ie,le,st,xt,mt,...	*/
	uint8_t	eeBootDevCtlr;
	uint8_t	eeBootDevUnit;
	uint8_t	eeBootDevPart;

	/* 0x1E */
	uint8_t	eeKeyboardType;		/* zero for sun keyboards */

	/* 0x1F */
	uint8_t	eeConsole;		/* What to use for the console	*/
#define	EE_CONS_BW		0x00	/* - On-board B&W / keyboard	*/
#define	EE_CONS_TTYA		0x10	/* - serial port A		*/
#define	EE_CONS_TTYB		0x11	/* - serial port B		*/
#define	EE_CONS_COLOR		0x12	/* - Color FB / keyboard	*/
#define	EE_CONS_P4OPT		0x20	/* - Option board on P4		*/

	/* 0x20 */
	uint8_t	eeCustomBanner;		/* Is there a custom banner:
					 * true:  use text at 0x68
					 * false: use Sun banner
					 */

	uint8_t	eeKeyClick;		/* true/false */

	/* 0x22 */
	/* Boot device with "Diag" switch in Diagnostic mode: */
	uint8_t	eeDiagDevName[2];
	uint8_t	eeDiagDevCtlr;
	uint8_t	eeDiagDevUnit;
	uint8_t	eeDiagDevPart;

	/* Video white-on-black (not implemented) */
	uint8_t	eeWhiteOnBlack;		/* true/false */

	/* 0x28 */
	char	eeDiagPath[40];		/* path name of diag program	*/

	/* 0x50 */
	uint8_t	eeTtyCols;		/* normally 80 (0x50) */
	uint8_t	eeTtyRows;		/* normally 34 (0x22) */
	uint8_t	ee_x52[6];		/* unused */

	/* 0x58 */
	/* Default parameters for tty A and tty B: */
	struct	eeTtyDef {
	    uint8_t	eetBaudSet;	/* Is the baud rate set?
					 * true:  use values here
					 * false: use default (9600)
					 */
	    uint8_t	eetBaudHi;	/* i.e. 96..  */
	    uint8_t	eetBaudLo;	/*      ..00  */
	    uint8_t	eetNoRtsDtr;	/* true: disable H/W flow
					 * false: enable H/W flow */
	    uint8_t	eet_pad[4];
	} eeTtyDefA, eeTtyDefB;

	/* 0x68 */
	char eeBannerString[80];	/* see eeCustomBanner above */

	/* 0xB8 */
	uint16_t eeTestPattern;		/* must be 0xAA55 */
	uint16_t ee_xBA;		/* unused */

	/* 0xBC */
	/* Configuration data.  Hopefully we don't need it. */
	struct eeConf {
	    uint8_t	eecData[16];
	} eeConf[12+1];

	/* 0x18c */
	uint8_t	eeAltKeyTable;		/* What Key table to use:
					 * 0x58: EEPROM tables
					 * else: PROM key tables
					 */
	uint8_t	eeKeyboardLocale;	/* extended keyboard type */
	uint8_t	eeKeyboardID;		/* for EEPROM key tables  */
	uint8_t	eeCustomLogo;		/* true: use eeLogoBitmap */

	/* 0x190 */
	uint8_t	eeKeymapLC[0x80];
	uint8_t	eeKeymapUC[0x80];

	/* 0x290 */
	uint8_t	eeLogoBitmap[64][8];	/* 64x64 bit custom logo */

	/* 0x490 */
	uint8_t	ee_x490[2];		/* unused */

	/* 0x492 */
	uint8_t	ee_passwd_mode;		/* Only (ROM rev > 2.7.0)
					 * 0x5E = fully secure mode
					 * 0x01 = command secure mode
					 * Rest = non-secure mode
					 */
	uint8_t	ee_password[8];
	uint8_t	ee_x49b[0x500-0x49b];	/* unused */

	/* 0x500 */
	uint8_t	eeReserved[0x100];

	/* 0x600 */
	uint8_t	eeROM_Area[0x100];

	/* 0x700 */
	/* "Unix area" (hah!) */
	uint8_t ee_x700[0xb];		/* unused */
	/* 0x70b */
	uint8_t ee_diag_mode;		/* 3/80 diag switch:
					 * 0x06 = normal boot
					 * 0x12 = diagnostic mode
					 * Rest = full diagnostic boot
					 */
	/* 0x70c */
	uint8_t	ee_x70c[0x7d8-0x70c];	/* unused */

	/* 0x7d8 */
	uint8_t ee_80_IDPROM[32];	/* 3/80 IDPROM */
	/* 0x7f8 */
	uint8_t ee_80_CLOCK[8];		/* 3/80 clock */
};

#endif /* _DEV_SUN_EEPROM_H_ */