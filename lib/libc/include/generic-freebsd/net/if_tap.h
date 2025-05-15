/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (C) 1999-2000 by Maksim Yevmenkin <m_evmenkin@yahoo.com>
 * All rights reserved.
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
 *
 * BASED ON:
 * -------------------------------------------------------------------------
 *
 * Copyright (c) 1988, Julian Onions <jpo@cs.nott.ac.uk>
 * Nottingham University 1987.
 */

/*
 * $Id: if_tap.h,v 0.7 2000/07/12 04:12:51 max Exp $
 */

#ifndef _NET_IF_TAP_H_
#define _NET_IF_TAP_H_

#include <net/if_tun.h>

/* maximum receive packet size (hard limit) */
#define	TAPMRU		65535

#define	tapinfo		tuninfo

/*
 * ioctl's for get/set debug; these are aliases of TUN* ioctls, see net/if_tun.h
 * for details.
 */
#define	TAPSDEBUG		TUNSDEBUG
#define	TAPGDEBUG		TUNGDEBUG
#define	TAPSIFINFO		TUNSIFINFO
#define	TAPGIFINFO		TUNGIFINFO
#define	TAPGIFNAME		TUNGIFNAME
#define	TAPSVNETHDR		_IOW('t', 91, int)
#define	TAPGVNETHDR		_IOR('t', 94, int)

/* VMware ioctl's */
#define VMIO_SIOCSIFFLAGS	_IOWINT('V', 0)
#define VMIO_SIOCSKEEP		_IO('V', 1)
#define VMIO_SIOCSIFBR		_IO('V', 2)
#define VMIO_SIOCSLADRF		_IO('V', 3)

/* XXX -- unimplemented */
#define VMIO_SIOCSETMACADDR	_IO('V', 4)

/* XXX -- not used? */
#define VMIO_SIOCPORT		_IO('V', 5)
#define VMIO_SIOCBRIDGE		_IO('V', 6)
#define VMIO_SIOCNETIF		_IO('V', 7)

#endif /* !_NET_IF_TAP_H_ */