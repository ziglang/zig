/*	$NetBSD: bthidev.h,v 1.5 2010/04/28 06:13:51 plunky Exp $	*/

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

#ifndef _DEV_BLUETOOTH_BTHIDEV_H_
#define _DEV_BLUETOOTH_BTHIDEV_H_

/* bthidev(4) properties */
#define BTHIDEVcontrolpsm	"control-psm"
#define BTHIDEVinterruptpsm	"interrupt-psm"
#define BTHIDEVdescriptor	"descriptor"
#define BTHIDEVreconnect	"reconnect"

#ifdef _KERNEL
/* HID device header */
struct bthidev {
	device_t	 sc_dev;
	device_t	 sc_parent;

	int		 sc_id;		/* report id */
	int		 sc_len;	/* report len */

	void		(*sc_input)	/* input method */
			(struct bthidev *, uint8_t *, int);

	void		(*sc_feature)	/* feature method */
			(struct bthidev *, uint8_t *, int);

	LIST_ENTRY(bthidev)	 sc_next;
};

/* HID device attach arguments */
struct bthidev_attach_args {
	int		 ba_vendor;	/* USB Forum Vendor ID */
	int		 ba_product;	/* USB Forum Product ID */
	const void	*ba_desc;	/* descriptor */
	int		 ba_dlen;	/* descriptor length */
	int		 ba_id;		/* report id */

	void		(*ba_input)	/* input method */
			(struct bthidev *, uint8_t *, int);
	void		(*ba_feature)	/* feature method */
			(struct bthidev *, uint8_t *, int);
	int		(*ba_output)	/* output method */
			(struct bthidev *, uint8_t *, int);
};
#endif /* _KERNEL */

#endif /* _DEV_BLUETOOTH_BTHIDEV_H_ */