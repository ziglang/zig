/*	$NetBSD: vuid_event.h,v 1.8 2015/09/06 06:01:01 dholland Exp $ */

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratory.
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
 *	@(#)vuid_event.h	8.1 (Berkeley) 6/11/93
 */

#ifndef _SUN_VUID_EVENT_H_
#define _SUN_VUID_EVENT_H_

#include <sys/ioccom.h>

struct firm_timeval {
	long tv_sec;
	long tv_usec;
};

/*
 * The following is a minimal emulation of Sun's `Firm_event' structures
 * and related operations necessary to make X11 happy (i.e., make it
 * compile, and make old X11 binaries run).
 */
typedef struct firm_event {
	u_short	id;		/* key or MS_* or LOC_[XY]_DELTA */
	u_short	pad;		/* unused, at least by X11 */
	int	value;		/* VKEY_{UP,DOWN} or locator delta */
	struct	firm_timeval time;
} Firm_event;

#ifdef _KERNEL
__BEGIN_DECLS
static __inline void firm_gettime(Firm_event *fev)
{
	struct timeval tv;
	getmicrotime(&tv);
	fev->time.tv_sec = (long)tv.tv_sec;
	fev->time.tv_usec = (long)tv.tv_usec;
}
__END_DECLS
#endif /* _KERNEL */

/*
 * Special `id' fields.  These weird numbers simply match the old binaries.
 * Others are in 0..0x7f and are keyboard key numbers (keyboard dependent!).
 */
#define	MS_LEFT		0x7f20	/* left mouse button */
#define	MS_MIDDLE	0x7f21	/* middle mouse button */
#define	MS_RIGHT	0x7f22	/* right mouse button */
#define	LOC_X_DELTA	0x7f80	/* mouse delta-X */
#define	LOC_Y_DELTA	0x7f81	/* mouse delta-Y */
#define	LOC_X_ABSOLUTE	0x7f82	/* X compat, unsupported */
#define	LOC_Y_ABSOLUTE	0x7f83	/* X compat, unsupported */

/*
 * Special `value' fields.  These apply to keys and mouse buttons.  The
 * value of a mouse delta is the delta.  Note that positive deltas are
 * left and up (not left and down as you might expect).
 */
#define	VKEY_UP		0	/* key or button went up */
#define	VKEY_DOWN	1	/* key or button went down */

/*
 * The following ioctls are clearly intended to take things in and out
 * of `firm event' mode.  Since we always run in this mode (as far as
 * /dev/kbd and /dev/mouse are concerned, anyway), we always claim to
 * be in this mode and reject anything else.
 */
#define	VUIDSFORMAT	_IOW('v', 1, int)
#define	VUIDGFORMAT	_IOR('v', 2, int)
#define	VUID_FIRM_EVENT	1	/* the only format we support */

#endif /* _SUN_VUID_EVENT_H_ */