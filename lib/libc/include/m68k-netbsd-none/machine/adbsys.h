/*	$NetBSD: adbsys.h,v 1.13 2000/02/14 07:01:48 scottr Exp $	*/

/*-
 * Copyright (C) 1993, 1994	Allen K. Briggs, Chris P. Caputo,
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
 */

#ifndef _ADBSYS_MACHINE_
#define _ADBSYS_MACHINE_

#include <sys/time.h>	/* timeval stuff */
#include <sys/ioctl.h>	/* ioctls */


/* Handy visual constants */
#define ADB_MAX_HANDLERS	256
#define ADB_MAX_DEVS	16


/* Different ADB system types */
enum adb_system_e {
	MacIIADB,
	MacIIsiADB,
	MacPBADB};
extern enum adb_system_e adb_system_type;


/* an ADB event */
typedef struct adb_event_s {
	int addr;			/* device address */
	int hand_id;			/* handler id */
	int def_addr;			/* default address */
	int byte_count;			/* number of bytes */
	unsigned char bytes[8];		/* bytes from register 0 */
	struct timeval timestamp;	/* time event was acquired */
	union {
		struct adb_keydata_s{
			int key;	/* ADB key code */
		} k;
		struct adb_mousedata_s{
			int dx;		/* mouse delta x */
			int dy;		/* mouse delta y */
			int buttons;	/* buttons (down << (buttonnum)) */
		} m;
	} u;				/* courtesy interpretation */
} adb_event_t;


/* a device on the ADB */
typedef struct adb_dev_s{
	int		addr;		/* current address */
	int		default_addr;	/* startup address */
	int		handler_id;	/* handler ID */
} adb_dev_t;


	/* Interesting default addresses */
#define	ADBADDR_SECURE	1		/* Security dongles */
#define ADBADDR_MAP	2		/* Mapped devices (keyboards/pads) */
#define ADBADDR_REL	3		/* Relative positioning devices
					   (mice, trackballs/pads) */
#define ADBADDR_ABS	4		/* Absolute positioning devices
					   (graphics tablets) */
#define ADBADDR_DATATX	5
#define ADBADDR_RSRVD	6		/* Reserved by Apple */
#define ADBADDR_MISC	7		/* Miscellaneous appliances */
#define ADBADDR_DONGLE	ADBADDR_SECURE
#define ADBADDR_KBD	ADBADDR_MAP
#define ADBADDR_MS	ADBADDR_REL
#define ADBADDR_TABLET	ADBADDR_ABS
#define ADBADDR_MODEM	ADBADDR_DATATX


	/* Interesting keyboard handler IDs */
#define ADB_STDKBD	1
#define ADB_EXTKBD	2
#define ADB_ISOKBD	4
#define ADB_EXTISOKBD	5
#define ADB_KBDII	8
#define ADB_ISOKBDII	9
#define ADB_PBKBD	12
#define ADB_PBISOKBD	13
#define ADB_ADJKPD	14
#define ADB_ADJKBD	16
#define ADB_ADJISOKBD	17
#define ADB_ADJJAPKBD	18
#define ADB_PBEXTISOKBD	20
#define ADB_PBEXTJAPKBD	21
#define ADB_JPKBDII	22
#define ADB_PBEXTKBD	24
#define ADB_DESIGNKBD	27	/* XXX Needs to be verified XXX */
#define ADB_PBJPKBD	30

	/* Interesting mouse handler IDs */
#define ADBMS_100DPI	1
#define ADBMS_200DPI	2
#define ADBMS_MSA3	3	/* Mouse Systems A3 Mouse */
#define ADBMS_EXTENDED	4	/* Extended mouse protocol */
#define ADBMS_USPEED    0x2f	/* MicroSpeed mouse */
#define ADBMS_UCONTOUR  0x66	/* Contour mouse */

	/* Interesting tablet handler ID */
#define ADB_ARTPAD	58	/* WACOM ArtPad II tablet */

	/* Interesting miscellaneous handler ID */
#define ADB_POWERKEY	34	/* Sophisticated Circuits PowerKey */
				/* (intelligent power tap) */

	/* Get device info from ADB system */
typedef struct adb_devinfo_s{
	adb_dev_t	dev[ADB_MAX_DEVS];
		/* [addr].addr == -1 if none */ 
} adb_devinfo_t;
#define ADBIOC_DEVSINFO	_IOR('A', 128, adb_devinfo_t)


	/* Event auto-repeat */
typedef struct adb_rptinfo_s{
	int delay_ticks;	/* ticks before repeat */
	int interval_ticks;	/* ticks between repeats */
} adb_rptinfo_t;
#define ADBIOC_GETREPEAT	_IOR('A', 130, adb_rptinfo_t)
#define ADBIOC_SETREPEAT	_IOW('A', 131, adb_rptinfo_t)


	/* Reset and reinitialize */
#define ADBIOC_RESET		_IO('A', 132)


typedef struct adb_listencmd_s{
	int address;		/* device address */
	int reg;		/* register to which to send bytes */
	int bytecnt;		/* number of bytes */
	u_char bytes[8];	/* bytes */
} adb_listencmd_t;
#define ADBIOC_LISTENCMD	_IOW('A', 133, adb_listencmd_t)

#endif /* _ADBSYS_MACHINE_ */