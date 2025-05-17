/*	$NetBSD: wdog.h,v 1.6 2016/01/26 06:27:38 dholland Exp $	*/

/*-
 * Copyright (c) 2000 Zembu Labs, Inc.
 * All rights reserved.
 *
 * Author: Jason R. Thorpe <thorpej@zembu.com>
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
 *	This product includes software developed by Zembu Labs, Inc.
 * 4. Neither the name of Zembu Labs nor the names of its employees may
 *    be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY ZEMBU LABS, INC. ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WAR-
 * RANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DIS-
 * CLAIMED.  IN NO EVENT SHALL ZEMBU LABS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_WDOG_H_
#define	_SYS_WDOG_H_

#include <sys/ioccom.h>

/*
 * Definitions for manipulating watchdog timers.
 */

/* This must match struct device's "dv_xname" size. */
#define	WDOG_NAMESIZE	16

struct wdog_mode {
	char wm_name[WDOG_NAMESIZE];
	int wm_mode;		/* timer mode */
	unsigned int wm_period;	/* timer period (seconds) */
};

/*
 * GMODE -- get mode of watchdog specified by wm_name.
 *
 * SMODE -- set mode of watchdog specified by wm_name.  If
 *          wm_mode is not DISARMED, the watchdog is armed,
 *          if another watchdog is not already running.
 */
#define	WDOGIOC_GMODE		_IOWR('w', 0, struct wdog_mode)
#define	WDOGIOC_SMODE		 _IOW('w', 1, struct wdog_mode)

/*
 * WHICH -- returns the mode information of the currently armed
 *          watchdog timer.
 */
#define	WDOGIOC_WHICH		 _IOR('w', 2, struct wdog_mode)

/*
 * TICKLE -- tickle the currently armed watchdog timer if the
 *           mode of that timer is UTICKLE.
 */
#define	WDOGIOC_TICKLE		  _IO('w', 3)

/*
 * GTICKLER -- get the PID of the last process to tickle the timer.
 */
#define	WDOGIOC_GTICKLER	 _IOR('w', 4, pid_t)

/*
 * GWDOGS -- fill in the character array with the names of all of
 *           the watchdog timers present on the system.  The names
 *           will be padded out to WDOG_NAMESIZE.  Thus, the argument
 *           should be (count * WDOG_NAMESIZE) bytes long.
 */
struct wdog_conf {
	char *wc_names;
	int wc_count;
};
#define	WDOGIOC_GWDOGS		_IOWR('w', 5, struct wdog_conf)

#define	WDOG_MODE_DISARMED	0	/* watchdog is disarmed */
#define	WDOG_MODE_KTICKLE	1	/* kernel tickles watchdog */
#define	WDOG_MODE_UTICKLE	2	/* user tickles watchdog */
#define	WDOG_MODE_ETICKLE	3	/* external program tickles watchdog */

#define	WDOG_MODE_MASK		0x03

#define	WDOG_FEATURE_ALARM	0x10	/* enable audible alarm on expire */

#define	WDOG_FEATURE_MASK	0x10

#define	WDOG_PERIOD_DEFAULT	((u_int)-1)

/* Period is expressed in seconds. */
#define	WDOG_PERIOD_TO_TICKS(period)	((period) * hz)

#endif /* _SYS_WDOG_H_ */