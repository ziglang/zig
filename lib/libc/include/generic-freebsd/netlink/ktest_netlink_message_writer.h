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

#ifndef _NETLINK_KTEST_NETLINK_MESSAGE_WRITER_H_
#define _NETLINK_KTEST_NETLINK_MESSAGE_WRITER_H_

#if defined(_KERNEL) && defined(INVARIANTS)

bool nlmsg_get_buf_type_wrapper(struct nl_writer *nw, int size, int type, bool waitok);
void nlmsg_set_callback_wrapper(struct nl_writer *nw);
struct mbuf *nl_get_mbuf_chain_wrapper(int len, int malloc_flags);

#ifndef KTEST_CALLER

bool
nlmsg_get_buf_type_wrapper(struct nl_writer *nw, int size, int type, bool waitok)
{
	return (nlmsg_get_buf_type(nw, size, type, waitok));
}

void
nlmsg_set_callback_wrapper(struct nl_writer *nw)
{
	nlmsg_set_callback(nw);
}

struct mbuf *
nl_get_mbuf_chain_wrapper(int len, int malloc_flags)
{
	return (nl_get_mbuf_chain(len, malloc_flags));
}
#endif

#endif

#endif