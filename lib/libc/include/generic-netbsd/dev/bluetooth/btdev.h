/*	$NetBSD: btdev.h,v 1.10 2015/09/06 06:01:00 dholland Exp $	*/

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

#ifndef _DEV_BLUETOOTH_BTDEV_H_
#define _DEV_BLUETOOTH_BTDEV_H_

#include <sys/ioccom.h>

/* btdev attach/detach ioctl's */
#define BTDEV_ATTACH		_IOW('b', 14, struct plistref)
#define BTDEV_DETACH		_IOW('b', 15, struct plistref)

/* btdev properties */
#define BTDEVvendor		"vendor-id"
#define BTDEVproduct		"product-id"
#define BTDEVtype		"device-type"
#define BTDEVladdr		"local-bdaddr"
#define BTDEVraddr		"remote-bdaddr"
#define BTDEVservice		"service-name"
#define BTDEVmode		"link-mode"
#define BTDEVauth		"auth"
#define BTDEVencrypt		"encrypt"
#define BTDEVsecure		"secure"

#endif /* _DEV_BLUETOOTH_BTDEV_H_ */