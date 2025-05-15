/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2022 Alexander V. Chernikov <melifaro@FreeBSD.org>
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

#ifndef _NETLINK_LINUX_VAR_H_
#define _NETLINK_LINUX_VAR_H_

/*
 * The file contains headers for the bridge interface between
 * linux[_common] module and the netlink module
 */
struct nlpcb;
struct nl_pstate;

typedef struct mbuf *mbufs_to_linux_cb_t(int netlink_family, struct mbuf *m,
    struct nlpcb *nlp);
typedef struct mbuf *msgs_to_linux_cb_t(int netlink_family, char *buf, int data_length,
    struct nlpcb *nlp);
typedef struct nlmsghdr *msg_from_linux_cb_t(int netlink_family, struct nlmsghdr *hdr,
    struct nl_pstate *npt);

struct linux_netlink_provider {
	mbufs_to_linux_cb_t	*mbufs_to_linux;
	msgs_to_linux_cb_t	*msgs_to_linux;
	msg_from_linux_cb_t	*msg_from_linux;

};

extern struct linux_netlink_provider *linux_netlink_p;

#endif