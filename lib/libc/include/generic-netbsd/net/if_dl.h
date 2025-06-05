/*	$NetBSD: if_dl.h,v 1.31 2022/11/07 08:32:35 msaitoh Exp $	*/

/*
 * Copyright (c) 1990, 1993
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
 *	@(#)if_dl.h	8.1 (Berkeley) 6/10/93
 */

/*
 * A Link-Level Sockaddr may specify the interface in one of two
 * ways: either by means of a system-provided index number (computed
 * anew and possibly differently on every reboot), or by a human-readable
 * string such as "il0" (for managerial convenience).
 *
 * Census taking actions, such as something akin to SIOCGCONF would return
 * both the index and the human name.
 *
 * High volume transactions (such as giving a link-level ``from'' address
 * in a recvfrom or recvmsg call) may be likely only to provide the indexed
 * form, (which requires fewer copy operations and less space).
 *
 * The form and interpretation  of the link-level address is purely a matter
 * of convention between the device driver and its consumers; however, it is
 * expected that all drivers for an interface of a given if_type will agree.
 */

#ifndef _NET_IF_DL_H_
#define _NET_IF_DL_H_

#include <sys/ansi.h>

#ifndef sa_family_t
typedef __sa_family_t	sa_family_t;
#define sa_family_t	__sa_family_t
#endif
#ifndef socklen_t
typedef __socklen_t   socklen_t;
#define socklen_t     __socklen_t
#endif

struct dl_addr {
	uint8_t	    dl_type;	/* interface type */
	uint8_t	    dl_nlen;	/* interface name length, no trailing 0 reqd. */
	uint8_t	    dl_alen;	/* link level address length */
	uint8_t	    dl_slen;	/* link layer selector length */
	char	    dl_data[24]; /*
				  * minimum work area, can be larger; contains
				  * both if name and ll address; big enough for
				  * IFNAMSIZ plus 8byte ll addr.
				  */
};

/*
 * Structure of a Link-Level sockaddr:
 */
struct sockaddr_dl {
	uint8_t	    sdl_len;	/* Total length of sockaddr */
	sa_family_t sdl_family;	/* AF_LINK */
	uint16_t    sdl_index;	/* if != 0, system given index for interface */
	struct dl_addr sdl_addr;
#define sdl_type	sdl_addr.dl_type
#define sdl_nlen	sdl_addr.dl_nlen
#define sdl_alen	sdl_addr.dl_alen
#define sdl_slen	sdl_addr.dl_slen
#define sdl_data	sdl_addr.dl_data
};

#define	satosdl(__sa)	((struct sockaddr_dl *)(__sa))
#define	satocsdl(__sa)	((const struct sockaddr_dl *)(__sa))

/* We do arithmetic directly with these, so keep them char instead of void */
#define LLADDR(s) ((char *)((s)->sdl_data + (s)->sdl_nlen))
#define CLLADDR(s) ((const char *)((s)->sdl_data + (s)->sdl_nlen))

#ifdef _KERNEL
uint8_t sockaddr_dl_measure(uint8_t, uint8_t);
struct sockaddr *sockaddr_dl_alloc(uint16_t, uint8_t,
    const void *, uint8_t, const void *, uint8_t, int);
struct sockaddr_dl *sockaddr_dl_init(struct sockaddr_dl *, socklen_t, uint16_t,
    uint8_t, const void *, uint8_t, const void *, uint8_t);
struct sockaddr_dl *sockaddr_dl_setaddr(struct sockaddr_dl *, socklen_t,
    const void *, uint8_t);
#else

#include <sys/cdefs.h>

__BEGIN_DECLS
void	link_addr(const char *, struct sockaddr_dl *);
char	*link_ntoa(const struct sockaddr_dl *);
__END_DECLS

#endif /* !_KERNEL */

#if defined(_KERNEL) || defined(_TEST)
// 255 xx: + 255 'a' + / + # + 3 digits + NUL
#define LINK_ADDRSTRLEN	((255 * 4) + 5)
#define LLA_ADDRSTRLEN	(16 * 3)

char	*lla_snprintf(char *, size_t, const void *, size_t);
int	dl_print(char *, size_t, const struct dl_addr *);
#define DL_PRINT(b, a) (dl_print((b), sizeof(b), (a)), (b))
int	sdl_print(char *, size_t, const void *);
#endif

#endif /* !_NET_IF_DL_H_ */