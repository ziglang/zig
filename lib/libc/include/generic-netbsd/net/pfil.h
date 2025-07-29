/*	$NetBSD: pfil.h,v 1.33 2017/01/16 09:28:40 ryo Exp $	*/

/*
 * Copyright (c) 1996 Matthew R. Green
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _NET_PFIL_H_
#define _NET_PFIL_H_

#include <sys/queue.h>

struct mbuf;
struct ifnet;
struct ifaddr;

/*
 * The packet filter hooks are designed for anything to call them to
 * possibly intercept the packet.
 */
typedef int (*pfil_func_t)(void *, struct mbuf **, struct ifnet *, int);
typedef void (*pfil_ifunc_t)(void *, unsigned long, void *);

#define PFIL_IN		0x00000001
#define PFIL_OUT	0x00000002
#define PFIL_ALL	(PFIL_IN|PFIL_OUT)
#define PFIL_IFADDR	0x00000008
#define PFIL_IFNET	0x00000010

/* events notified by PFIL_IFNET */
#define	PFIL_IFNET_ATTACH	0
#define	PFIL_IFNET_DETACH	1

#define	PFIL_TYPE_AF		1	/* key is AF_* type */
#define	PFIL_TYPE_IFNET		2	/* key is ifnet or ifaddr pointer */

typedef struct pfil_head	pfil_head_t;

#ifdef _KERNEL

void	pfil_init(void);
int	pfil_run_hooks(pfil_head_t *, struct mbuf **, struct ifnet *, int);
void	pfil_run_addrhooks(pfil_head_t *, unsigned long, struct ifaddr *);
void	pfil_run_ifhooks(pfil_head_t *, unsigned long, struct ifnet *);

int	pfil_add_hook(pfil_func_t, void *, int, pfil_head_t *);
int	pfil_remove_hook(pfil_func_t, void *, int, pfil_head_t *);

int	pfil_add_ihook(pfil_ifunc_t, void *, int, pfil_head_t *);
int	pfil_remove_ihook(pfil_ifunc_t, void *, int, pfil_head_t *);

pfil_head_t *	pfil_head_create(int, void *);
void		pfil_head_destroy(pfil_head_t *);
pfil_head_t *	pfil_head_get(int, void *);

/* Packet filtering hook for interfaces (in sys/net/if.c module). */
extern pfil_head_t *if_pfil;

#endif /* _KERNEL */

#endif /* !_NET_PFIL_H_ */