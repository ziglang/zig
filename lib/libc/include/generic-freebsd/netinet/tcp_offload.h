/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2012 Chelsio Communications, Inc.
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
 */

#ifndef _NETINET_TCP_OFFLOAD_H_
#define	_NETINET_TCP_OFFLOAD_H_

#ifndef _KERNEL
#error "no user-serviceable parts inside"
#endif

#include <netinet/tcp.h>

extern int registered_toedevs;

int  tcp_offload_connect(struct socket *, struct sockaddr *);
void tcp_offload_listen_start(struct tcpcb *);
void tcp_offload_listen_stop(struct tcpcb *);
void tcp_offload_input(struct tcpcb *, struct mbuf *);
int  tcp_offload_output(struct tcpcb *);
void tcp_offload_rcvd(struct tcpcb *);
void tcp_offload_ctloutput(struct tcpcb *, int, int);
void tcp_offload_tcp_info(const struct tcpcb *, struct tcp_info *);
int  tcp_offload_alloc_tls_session(struct tcpcb *, struct ktls_session *, int);
void tcp_offload_detach(struct tcpcb *);
void tcp_offload_pmtu_update(struct tcpcb *, tcp_seq, int);

#endif