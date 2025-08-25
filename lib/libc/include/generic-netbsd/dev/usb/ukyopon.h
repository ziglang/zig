/*	$NetBSD: ukyopon.h,v 1.6 2016/04/23 10:15:32 skrll Exp $	*/

/*-
 * Copyright (c) 2005 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by ITOH Yasufumi.
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

#include <sys/ioccom.h>

#ifdef _KERNEL
#include <machine/limits.h>
#else
#include <limits.h>
#endif

struct ukyopon_identify {
	char	ui_name[16];		/* driver name */

	int	ui_busno;		/* usb bus number */
	uint8_t	ui_address;		/* device address */

	enum ukyopon_model {
		UKYOPON_MODEL_UNKNOWN,
		/* UKYOPON_MODEL_AHK3001V, ... */
		_UKYOPON_MODEL_KEEPSZ = INT_MAX	/* fix size of this field */
	} ui_model;			/* possibly future use */
	enum ukyopon_port {
		UKYOPON_PORT_UNKNOWN,
		UKYOPON_PORT_MODEM,	/* modem port */
		UKYOPON_PORT_DATA,	/* data transfer port */
		_UKYOPON_PORT_KEEPSZ = INT_MAX	/* fix size of this field */
	} ui_porttype;			/* port type */
	int	ui_rsvd1, ui_rsvd2;
};

#define UKYOPON_NAME		"ukyopon"
#define UKYOPON_IDENTIFY	_IOR ('U', 210, struct ukyopon_identify)