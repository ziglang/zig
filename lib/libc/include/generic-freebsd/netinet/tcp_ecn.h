/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1982, 1986, 1993, 1994, 1995
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)tcp_ecn.h	8.4 (Berkeley) 5/24/95
 */

#ifndef _NETINET_TCP_ECN_H_
#define _NETINET_TCP_ECN_H_

#ifdef _KERNEL

#include <netinet/tcp.h>
#include <netinet/tcp_var.h>
#include <netinet/tcp_syncache.h>

void	 tcp_ecn_input_syn_sent(struct tcpcb *, uint16_t, int);
void	 tcp_ecn_input_parallel_syn(struct tcpcb *, uint16_t, int);
int	 tcp_ecn_input_segment(struct tcpcb *, uint16_t, int, int, int);
uint16_t tcp_ecn_output_syn_sent(struct tcpcb *);
int	 tcp_ecn_output_established(struct tcpcb *, uint16_t *, int, bool);
void	 tcp_ecn_syncache_socket(struct tcpcb *, struct syncache *);
int	 tcp_ecn_syncache_add(uint16_t, int);
uint16_t tcp_ecn_syncache_respond(uint16_t, struct syncache *);
int	 tcp_ecn_get_ace(uint16_t);

#endif /* _KERNEL */

#endif /* _NETINET_TCP_ECN_H_ */