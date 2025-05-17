/*	$NetBSD: apmio.h,v 1.7 2017/10/28 06:27:32 riastradh Exp $	*/
/*-
 * Copyright (c) 1995 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by John Kohl.
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
#ifndef _DEV_APM_APMIO_H_
#define _DEV_APM_APMIO_H_

#include <sys/types.h>
#include <sys/ioccom.h>

struct apm_event_info {
	u_int type;
	u_int index;
	u_int spare[8];
};

struct apm_power_info {
	u_char battery_state;
	u_char ac_state;
	u_char battery_life;
	u_char minutes_valid;
	u_int minutes_left;		/* estimate */
	u_int nbattery;
	u_int batteryid;
	u_int battery_flags;
	u_int spare2[3];
};

struct apm_ctl {
	u_int dev;
	u_int mode;
};

#define	APM_IOC_REJECT	_IOW('A', 0, struct apm_event_info) /* reject request # */
#define	APM_IOC_STANDBY	_IO('A', 1)	/* put system into standby */
#define	APM_IOC_SUSPEND	_IO('A', 2)	/* put system into suspend */
#define	OAPM_IOC_GETPOWER _IOR('A', 3, struct apm_power_info) /* fetch battery state */
#define	APM_IOC_GETPOWER _IOWR('A', 3, struct apm_power_info) /* fetch battery state */
#define	APM_IOC_NEXTEVENT _IOR('A', 4, struct apm_event_info) /* fetch event */
#define	APM_IOC_DEV_CTL	_IOW('A', 5, struct apm_ctl) /* put device into mode */

#endif /* _DEV_APM_APMIO_H_ */