/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 1998 The NetBSD Foundation, Inc. All rights reserved.
 * Copyright (c) 1998 Lennart Augustsson. All rights reserved.
 * Copyright (c) 2008-2010 Hans Petter Selasky. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * USB spec: http://www.usb.org/developers/docs/usbspec.zip
 */

#ifndef USB_HUB_PRIVATE_H_
#define    USB_HUB_PRIVATE_H_
#define	UHUB_INTR_INTERVAL 250		/* ms */

enum {
	UHUB_INTR_TRANSFER,
#if USB_HAVE_TT_SUPPORT
	UHUB_RESET_TT_TRANSFER,
#endif
	UHUB_N_TRANSFER,
};

struct uhub_current_state {
	uint16_t port_change;
	uint16_t port_status;
};

struct uhub_softc {
	struct uhub_current_state sc_st;	/* current state */
#if (USB_HAVE_FIXED_PORT != 0)
	struct usb_hub sc_hub;
#endif
	device_t sc_dev;		/* base device */
	struct mtx sc_mtx;		/* our mutex */
	struct usb_device *sc_udev;	/* USB device */
	struct usb_xfer *sc_xfer[UHUB_N_TRANSFER];	/* interrupt xfer */
#if USB_HAVE_DISABLE_ENUM
	int	sc_disable_enumeration;
	int	sc_disable_port_power;
#endif
	uint8_t	sc_usb_port_errors;	/* error counter */
#define	UHUB_USB_PORT_ERRORS_MAX 4
	uint8_t	sc_flags;
#define	UHUB_FLAG_DID_EXPLORE 0x01
};
struct hub_result {
	struct usb_device *udev;
	uint8_t	portno;
	uint8_t	iface_index;
};

void
uhub_find_iface_index(struct usb_hub *hub, device_t child,
    struct hub_result *res);

device_probe_t uhub_probe;
device_attach_t uhub_attach;
device_detach_t uhub_detach;
bus_child_location_t uhub_child_location;
bus_get_device_path_t uhub_get_device_path;

#endif