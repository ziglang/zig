/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2008 Hans Petter Selasky. All rights reserved.
 * Copyright (c) 1998 The NetBSD Foundation, Inc. All rights reserved.
 * Copyright (c) 1998 Lennart Augustsson. All rights reserved.
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

#ifndef _USB_HID_H_
#define	_USB_HID_H_

#include <dev/hid/hid.h>

#ifndef USB_GLOBAL_INCLUDE_FILE
#include <dev/usb/usb_endian.h>
#endif

#define	UR_GET_HID_DESCRIPTOR	0x06
#define	UDESC_HID		0x21
#define	UDESC_REPORT		0x22
#define	UDESC_PHYSICAL		0x23
#define	UR_SET_HID_DESCRIPTOR	0x07
#define	UR_GET_REPORT		0x01
#define	UR_SET_REPORT		0x09
#define	UR_GET_IDLE		0x02
#define	UR_SET_IDLE		0x0a
#define	UR_GET_PROTOCOL		0x03
#define	UR_SET_PROTOCOL		0x0b

struct usb_hid_descriptor {
	uByte	bLength;
	uByte	bDescriptorType;
	uWord	bcdHID;
	uByte	bCountryCode;
	uByte	bNumDescriptors;
	struct {
		uByte	bDescriptorType;
		uWord	wDescriptorLength;
	}	descrs[1];
} __packed;

#define	USB_HID_DESCRIPTOR_SIZE(n) (9+((n)*3))

#define	UHID_INPUT_REPORT	HID_INPUT_REPORT
#define	UHID_OUTPUT_REPORT	HID_OUTPUT_REPORT
#define	UHID_FEATURE_REPORT	HID_FEATURE_REPORT

#if defined(_KERNEL) || defined(_STANDALONE)
struct usb_config_descriptor;

#ifdef COMPAT_USBHID12
/* FreeBSD <= 12 compat shims */
#define	hid_report_size(buf, len, kind, id)	\
	hid_report_size_max(buf, len, kind, id)
static __inline uint32_t
hid_get_data_unsigned(const uint8_t *buf, hid_size_t len,
    struct hid_location *loc)
{
	return (hid_get_udata(buf, len, loc));
}
static __inline void
hid_put_data_unsigned(uint8_t *buf, hid_size_t len, struct hid_location *loc,
    unsigned value)
{
	return (hid_put_udata(buf, len, loc, value));
}
#endif

struct usb_hid_descriptor *hid_get_descriptor_from_usb(
	    struct usb_config_descriptor *cd,
	    struct usb_interface_descriptor *id);
usb_error_t usbd_req_get_hid_desc(struct usb_device *udev, struct mtx *mtx,
	    void **descp, uint16_t *sizep, struct malloc_type *mem,
	    uint8_t iface_index);
#endif	/* _KERNEL || _STANDALONE */
#endif	/* _USB_HID_H_ */