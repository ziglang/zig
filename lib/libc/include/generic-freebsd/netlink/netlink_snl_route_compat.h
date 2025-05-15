/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2023 Alexander V. Chernikov <melifaro@FreeBSD.org>
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
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#ifndef	_NETLINK_NETLINK_SNL_ROUTE_COMPAT_H_
#define	_NETLINK_NETLINK_SNL_ROUTE_COMPAT_H_

#include <sys/socket.h>
#include <sys/types.h>

/*
 * This file contains netlink-compatible definitions from the
 * net/route.h header.
 */
#define	NETLINK_COMPAT

#include <net/route.h>

#define	RTSOCK_RTM_ADD		0x1
#define	RTSOCK_RTM_DELETE	0x2
#define	RTSOCK_RTM_CHANGE	0x3
#define	RTSOCK_RTM_GET		0x4
#define	RTSOCK_RTM_NEWADDR	0xc
#define	RTSOCK_RTM_DELADDR	0xd
#define	RTSOCK_RTM_IFINFO	0xe
#define	RTSOCK_RTM_NEWMADDR	0xf
#define	RTSOCK_RTM_DELMADDR	0x10
#define	RTSOCK_RTM_IFANNOUNCE	0x11
#define	RTSOCK_RTM_IEEE80211	0x12

#endif