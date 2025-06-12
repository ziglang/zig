/*	$NetBSD: ipsecif.h,v 1.3 2019/11/01 04:28:14 knakahara Exp $  */

/*
 * Copyright (c) 2017 Internet Initiative Japan Inc.
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
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _NETIPSEC_IPSECIF_H_
#define _NETIPSEC_IPSECIF_H_

#include <net/if_ipsec.h>

#define IPSEC_TTL	64
#define IPSEC_HLIM	64

#ifdef _KERNEL
#ifdef INET6
extern int ip6_ipsec_hlim;
extern int ip6_ipsec_pmtu;

#define IPSEC_PMTU_SYSDEFAULT	-1	/* Use system default value (ip6_gif_pmtu) */
#define IPSEC_PMTU_MINMTU	0	/* Fragmented by IPV6_MINMTU */
#define IPSEC_PMTU_OUTERMTU	1	/* Fragmented by Path MTU of outer path */
#endif

int ipsecif4_encap_func(struct mbuf *, struct ip *, struct ipsec_variant *);
int ipsecif4_attach(struct ipsec_variant *);
int ipsecif4_detach(struct ipsec_variant *);

int ipsecif6_encap_func(struct mbuf *, struct ip6_hdr *, struct ipsec_variant *);
int ipsecif6_attach(struct ipsec_variant *);
int ipsecif6_detach(struct ipsec_variant *);
void *ipsecif6_ctlinput(int, const struct sockaddr *, void *, void *);
#endif

#endif /*_NETIPSEC_IPSECIF_H_*/