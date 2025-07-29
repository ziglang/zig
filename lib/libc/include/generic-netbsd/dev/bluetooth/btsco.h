/*	$NetBSD: btsco.h,v 1.3 2015/09/06 06:01:00 dholland Exp $	*/

/*-
 * Copyright (c) 2006 Itronix Inc.
 * All rights reserved.
 *
 * Written by Iain Hibbert for Itronix Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of Itronix Inc. may not be used to endorse
 *    or promote products derived from this software without specific
 *    prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY ITRONIX INC. ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL ITRONIX INC. BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _DEV_BLUETOOTH_BTSCO_H_
#define _DEV_BLUETOOTH_BTSCO_H_

#include <sys/ioccom.h>
#include <netbt/bluetooth.h>

/* btsco(4) properties */
#define BTSCOlisten		"listen"
#define BTSCOchannel		"rfcomm-channel"

/*
 * We need to provide a way to get the SCO Audio contact information
 * from the audio device so that the control channel can be set up
 */

struct btsco_info {
	bdaddr_t	laddr;		/* controller addr */
	bdaddr_t	raddr;		/* remote addr */
	uint8_t		channel;	/* RFCOMM channel */
	int		vgs;		/* mixer index speaker */
	int		vgm;		/* mixer index mic */
};

#define	BTSCO_GETINFO		_IOR('b', 16, struct btsco_info)

#define BTSCO_DELTA		16	/* volume delta */

#endif /* _DEV_BLUETOOTH_BTSCO_H_ */