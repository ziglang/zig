/*	$NetBSD: if_vlanvar.h,v 1.17 2022/06/20 08:02:25 yamaguchi Exp $	*/

/*
 * Copyright (c) 2000 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Andrew Doran.
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

/*
 * Copyright 1998 Massachusetts Institute of Technology
 *
 * Permission to use, copy, modify, and distribute this software and
 * its documentation for any purpose and without fee is hereby
 * granted, provided that both the above copyright notice and this
 * permission notice appear in all copies, that both the above
 * copyright notice and this permission notice appear in all
 * supporting documentation, and that the name of M.I.T. not be used
 * in advertising or publicity pertaining to distribution of the
 * software without specific, written prior permission.  M.I.T. makes
 * no representations about the suitability of this software for any
 * purpose.  It is provided "as is" without express or implied
 * warranty.
 *
 * THIS SOFTWARE IS PROVIDED BY M.I.T. ``AS IS''.  M.I.T. DISCLAIMS
 * ALL EXPRESS OR IMPLIED WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT
 * SHALL M.I.T. BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
 * USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 * OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * from FreeBSD: if_vlan_var.h,v 1.3 1999/08/28 00:48:24 peter Exp
 */

#ifndef _NET_IF_VLANVAR_H_
#define	_NET_IF_VLANVAR_H_

struct ether_vlan_header {
	uint8_t		evl_dhost[ETHER_ADDR_LEN];
	uint8_t		evl_shost[ETHER_ADDR_LEN];
	uint16_t	evl_encap_proto;
	uint16_t	evl_tag;
	uint16_t	evl_proto;
} __packed;

/* Configuration structure for SIOCSETVLAN and SIOCGETVLAN ioctls. */
struct vlanreq {
	char		vlr_parent[IFNAMSIZ];
	uint16_t	vlr_tag;
};

#define	SIOCSETVLAN	SIOCSIFGENERIC
#define	SIOCGETVLAN	SIOCGIFGENERIC

#ifdef _KERNEL
struct mbuf *	vlan_input(struct ifnet *, struct mbuf *);

/*
 * Locking notes:
 * + ifv_list.list is protected by ifv_list.lock (an adaptive mutex)
 *     ifv_list.list is list of all ifvlans, and it is used to avoid
 *     unload while busy.
 * + ifv_hash.lists is protected by
 *   - ifv_hash.lock (an adaptive mutex) for writer
 *   - pserialize for reader
 *     ifv_hash.lists is hashed list of all configured
 *     vlan interface, and it is used to avoid unload while busy.
 * + ifvlan->ifv_linkmib is protected by
 *   - ifvlan->ifv_lock (an adaptive mutex) for writer
 *   - ifv_linkmib->ifvm_psref for reader
 *     ifvlan->ifv_linkmib is used for variant values while tagging
 *     and untagging
 *
 * Locking order:
 *     - ifv_list.lock => struct ifvlan->ifv_lock
 *     - struct ifvlan->ifv_lock => ifv_hash.lock
 * Other mutexes must not hold simultaneously
 *
 *   NOTICE
 *     - ifvlan must not have a variant value while tagging and
 *       untagging. Such variant values must be in ifvlan->ifv_mib
 *     - ifvlan->ifv_mib is modified like read-copy-update.
 *       So, once we dereference ifvlan->ifv_mib,
 *       we must keep the pointer during the same context. If we
 *       re-dereference ifvlan->ifv_mib, the ifv_mib may be other
 *       one because of concurrent writer processing.
 */
#endif	/* _KERNEL */

#endif	/* !_NET_IF_VLANVAR_H_ */