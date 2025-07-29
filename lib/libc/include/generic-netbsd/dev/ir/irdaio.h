/*	$NetBSD: irdaio.h,v 1.8 2015/09/06 06:01:00 dholland Exp $	*/

/*
 * Copyright (c) 2001 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Lennart Augustsson (lennart@augustsson.net).
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

#ifndef _SYS_DEV_IRDAIO_H_
#define _SYS_DEV_IRDAIO_H_

#include <sys/ioccom.h>

struct irda_params {
	unsigned int speed;
	unsigned int ebofs;
	unsigned int maxsize;
};

/* SIR speeds */
#define IRDA_SPEED_2400		0x0001
#define IRDA_SPEED_9600		0x0002
#define IRDA_SPEED_19200	0x0004
#define IRDA_SPEED_38400	0x0008
#define IRDA_SPEED_57600	0x0010
#define IRDA_SPEED_115200	0x0020
/* MIR speeds */
#define IRDA_SPEED_576000	0x0040
#define IRDA_SPEED_1152000	0x0080
/* FIR speeds */
#define IRDA_SPEED_4000000	0x0100
/* VFIR speeds */
#define IRDA_SPEED_16000000	0x0200

#define IRDA_SPEEDS_SIR		0x003f
#define IRDA_SPEEDS_MIR		0x00c0
#define IRDA_SPEEDS_FIR		0x0100
#define IRDA_SPEEDS_VFIR	0x0200

#define IRDA_TURNT_10000	0x01
#define IRDA_TURNT_5000		0x02
#define IRDA_TURNT_1000		0x04
#define IRDA_TURNT_500		0x08
#define IRDA_TURNT_100		0x10
#define IRDA_TURNT_50		0x20
#define IRDA_TURNT_10		0x40
#define IRDA_TURNT_0		0x80

/* Coordinate numbering with cirio.h. */
#define IRDA_RESET_PARAMS	_IO ('I', 1)
#define IRDA_SET_PARAMS		_IOW('I', 2, struct irda_params)
#define IRDA_GET_SPEEDMASK	_IOR('I', 3, unsigned int)
#define IRDA_GET_TURNAROUNDMASK	_IOR('I', 4, unsigned int)


/* irframetty device ioctls */
#define IRFRAMETTY_GET_DEVICE	_IOR('I', 100, unsigned int)
#define IRFRAMETTY_GET_DONGLE	_IOR('I', 101, unsigned int)
#define IRFRAMETTY_SET_DONGLE	_IOW('I', 102, unsigned int)
#define   DONGLE_NONE		0
#define   DONGLE_TEKRAM		1
#define   DONGLE_JETEYE		2
#define   DONGLE_ACTISYS	3
#define   DONGLE_ACTISYS_PLUS	4
#define   DONGLE_LITELINK	5
#define   DONGLE_GIRBIL		6
#define   DONGLE_MAX		7

#endif /* _SYS_DEV_IRDAIO_H_ */