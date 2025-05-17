/*	$NetBSD: apmbios.h,v 1.7 2012/09/30 21:36:20 dsl Exp $	*/
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
#ifndef _DEV_APM_APMBIOS_H_
#define _DEV_APM_APMBIOS_H_

/*
 * These definitions were those for the i386 'APM' (which predates ACPI),
 * but have been hijacked for all sorts of uses.
 * The APM specific values were removed when APM was removed.
 */

#define	APM_ERR_PM_DISABLED	0x01
#define	APM_ERR_REALALREADY	0x02
#define	APM_ERR_NOTCONN		0x03
#define	APM_ERR_16ALREADY	0x05
#define	APM_ERR_16NOTSUPP	0x06
#define	APM_ERR_32ALREADY	0x07
#define	APM_ERR_32NOTSUPP	0x08
#define	APM_ERR_UNRECOG_DEV	0x09
#define	APM_ERR_ERANGE		0x0A
#define	APM_ERR_NOTENGAGED	0x0B
#define	APM_ERR_EOPNOTSUPP	0x0C
#define	APM_ERR_RTIMER_DISABLED	0x0D
#define APM_ERR_UNABLE		0x60
#define APM_ERR_NOEVENTS	0x80
#define	APM_ERR_NOT_PRESENT	0x86

#define APM_DEV_ALLDEVS		0x0001

#define		APM_SYS_READY	0x0000
#define		APM_SYS_STANDBY	0x0001
#define		APM_SYS_SUSPEND	0x0002
#define		APM_SYS_OFF	0x0003
#define		APM_LASTREQ_INPROG	0x0004
#define		APM_LASTREQ_REJECTED	0x0005

#define		APM_AC_OFF		0x00
#define		APM_AC_ON		0x01
#define		APM_AC_BACKUP		0x02
#define		APM_AC_UNKNOWN		0xff

/* the first set of battery constants is 1.0 style values;
 * the second set is 1.1 style bit definitions */
#define		APM_BATT_HIGH		0x00
#define		APM_BATT_LOW		0x01
#define		APM_BATT_CRITICAL	0x02
#define		APM_BATT_CHARGING	0x03
#define		APM_BATT_ABSENT		0x04 /* Software only--not in spec! */
#define		APM_BATT_UNKNOWN	0xff

#define		APM_BATT_FLAG_HIGH	0x01
#define		APM_BATT_FLAG_LOW	0x02
#define		APM_BATT_FLAG_CRITICAL	0x04
#define		APM_BATT_FLAG_CHARGING	0x08
#define		APM_BATT_FLAG_NOBATTERY	0x10
#define		APM_BATT_FLAG_NO_SYSTEM_BATTERY	0x80
#define		APM_BATT_FLAG_UNKNOWN	0xff

#define		APM_BATT_LIFE_UNKNOWN	0xff

#define		APM_STANDBY_REQ		0x0001 /* %bx on return */
#define		APM_SUSPEND_REQ		0x0002
#define		APM_NORMAL_RESUME	0x0003
#define		APM_CRIT_RESUME		0x0004 /* suspend/resume happened
						  without us */
#define		APM_BATTERY_LOW		0x0005
#define		APM_POWER_CHANGE	0x0006
#define		APM_UPDATE_TIME		0x0007
#define		APM_CRIT_SUSPEND_REQ	0x0008
#define		APM_USER_STANDBY_REQ	0x0009
#define		APM_USER_SUSPEND_REQ	0x000A
#define		APM_SYS_STANDBY_RESUME	0x000B
#define		APM_CAP_CHANGE		0x000C	/* V1.2 */

#define		APM_GLOBAL_STANDBY	0x0001
#define		APM_GLOBAL_SUSPEND	0x0002

/*
 * APM info word from the real-mode handler is adjusted to put
 * major/minor version in low half and support bits in upper half.
 */
#define	APM_MAJOR_VERS(info) (((info)&0xff00)>>8)
#define	APM_MINOR_VERS(info) ((info)&0xff)

#define	APMDEBUG_INFO		0x01
#define	APMDEBUG_EVENTS		0x04
#define	APMDEBUG_DEVICE		0x20
#define	APMDEBUG_ANOM		0x40

#endif /* _DEV_APM_APMBIOS_H_ */