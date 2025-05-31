/*	$NetBSD: tctrl.h,v 1.5 2015/09/07 03:49:46 dholland Exp $	*/

/*-
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Tim Rightnour.
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
#ifndef _MACHINE_TCTRL_H
#define	_MACHINE_TCTRL_H

#include <sys/ioccom.h>

struct tctrl_req {
	uint8_t        cmdbuf[16];
	uint8_t        cmdlen;
	uint8_t        cmdoff;
	struct proc     *p;
	uint8_t        rspbuf[16];
	uint8_t        rspoff;
	uint8_t        rsplen;
};
typedef struct tctrl_req tctrl_req_t;

struct tctrl_pwr {
	int	rw;
	int	state;
};
typedef struct tctrl_pwr tctrl_pwr_t;

/* Port power state */
#define PORT_PWR_ON		0x00	/* Always on */
#define PORT_PWR_STANDBY	0x01	/* On when open */
#define PORT_PWR_OFF		0x02	/* Always off */

#define TCTRL_CMD_REQ     _IOWR('C', 0, struct tctrl_req)
#define TCTRL_SERIAL_PWR  _IOWR('C', 1, struct tctrl_pwr)
#define TCTRL_MODEM_PWR   _IOWR('C', 2, struct tctrl_pwr)

#endif /* _MACHINE_TCTRL_H */