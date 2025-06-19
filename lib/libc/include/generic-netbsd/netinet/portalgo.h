/*	$NetBSD: portalgo.h,v 1.3 2022/10/28 05:18:39 ozaki-r Exp $	*/

/*
 * Copyright 2011 Vlad Balan
 *
 * Written by Vlad Balan for the NetBSD Foundation.
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
 */
#ifndef _NETINET_PORTALGO_H_
#define _NETINET_PORTALGO_H_

#ifdef _KERNEL
#include <sys/sysctl.h>

struct inpcb;
int portalgo_randport(uint16_t *, struct inpcb *, kauth_cred_t);
int sysctl_portalgo_selected4(SYSCTLFN_ARGS);
int sysctl_portalgo_selected6(SYSCTLFN_ARGS);
int sysctl_portalgo_reserve4(SYSCTLFN_ARGS);
int sysctl_portalgo_reserve6(SYSCTLFN_ARGS);
int sysctl_portalgo_available(SYSCTLFN_ARGS);
int portalgo_algo_index_select(struct inpcb *, int);

#define	PORTALGO_MAXLEN       16
#endif /* _KERNEL */

/*
 * User-settable options (used with setsockopt).
 */
#define	PORTALGO_DEFAULT		0xffff
#define	PORTALGO_BSD			0
#define	PORTALGO_RANDOM_START		1
#define	PORTALGO_RANDOM_PICK		2
#define	PORTALGO_HASH			3
#define	PORTALGO_DOUBLEHASH		4
#define	PORTALGO_RANDINC		5

#endif /* !_NETINET_PORTALGO_H_ */