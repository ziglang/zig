/*	$NetBSD: in6_gif.h,v 1.18 2019/10/30 03:45:59 knakahara Exp $	*/
/*	$KAME: in6_gif.h,v 1.7 2001/07/26 06:53:16 jinmei Exp $	*/

/*
 * Copyright (C) 1995, 1996, 1997, and 1998 WIDE Project.
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
 * 3. Neither the name of the project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NETINET6_IN6_GIF_H_
#define _NETINET6_IN6_GIF_H_

#define GIF_HLIM	30
extern int	ip6_gif_hlim;		/* Hop limit for gif encap packet */
extern int	ip6_gif_pmtu;		/* Default Path MTU setting for gif tunnels */

#define GIF_PMTU_SYSDEFAULT	-1	/* Use system default value (ip6_gif_pmtu) */
#define GIF_PMTU_MINMTU		0	/* Fragmented by IPV6_MINMTU */
#define GIF_PMTU_OUTERMTU	1	/* Fragmented by Path MTU of outer path */

struct gif_variant;
struct sockaddr;
int in6_gif_input(struct mbuf **, int *, int, void *);
#ifdef GIF_ENCAPCHECK
int gif_encapcheck6(struct mbuf *, int, int, struct gif_variant *);
#endif
int in6_gif_attach(struct gif_variant *);
int in6_gif_detach(struct gif_variant *);
void *in6_gif_ctlinput(int, const struct sockaddr *, void *, void *);

#endif /* !_NETINET6_IN6_GIF_H_ */