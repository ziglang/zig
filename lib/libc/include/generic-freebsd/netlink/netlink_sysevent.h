/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2023 Baptiste Daroussin <bapt@FreeBSD.org>
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

#ifndef _NETLINK_SYSEVENT_H_
#define _NETLINK_SYSEVENT_H_

enum {
	NLSE_ATTR_UNSPEC = 0,
	NLSE_ATTR_SYSTEM = 1,     /* string reporting the system name */
	NLSE_ATTR_SUBSYSTEM = 2,  /* string reporting the subsystem name */
	NLSE_ATTR_TYPE = 3,       /* string reporting the type if the event */
	NLSE_ATTR_DATA = 4,       /* string reporting the extra data (can be null) */
	__NLSE_ATTR_MAX,
};
#define NLSE_ATTR_MAX (__NLSE_ATTR_MAX -1)

/* commands */
enum {
	NLSE_CMD_UNSPEC = 0,
	NLSE_CMD_NEWEVENT = 1,
	__NLSE_CMD_MAX,
};
#define	NLSE_CMD_MAX (__NLSE_CMD_MAX - 1)

#endif