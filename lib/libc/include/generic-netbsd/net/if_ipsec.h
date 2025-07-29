/*	$NetBSD: if_ipsec.h,v 1.8 2022/01/17 20:56:03 andvar Exp $  */

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

/*
 * if_ipsec.h
 */

#ifndef _NET_IF_IPSEC_H_
#define _NET_IF_IPSEC_H_

#include <sys/queue.h>
#ifdef _KERNEL
#include <sys/pserialize.h>
#include <sys/psref.h>
#endif

#ifdef _KERNEL_OPT
#include "opt_inet.h"
#endif

#include <netinet/in.h>
#include <netipsec/ipsec.h>

#ifdef _KERNEL
/*
 * This macro controls the upper limitation on nesting of ipsec tunnels.
 * Since, setting a large value to this macro with a careless configuration
 * may introduce system crash, we don't allow any nestings by default.
 * If you need to configure nested ipsec tunnels, you can define this macro
 * in your kernel configuration file.  However, if you do so, please be
 * careful to configure the tunnels so that it won't make a loop.
 */
#ifndef MAX_IPSEC_NEST
#define MAX_IPSEC_NEST 1
#endif

#define IFF_NAT_T	IFF_LINK0	/* enable NAT-T */
#define IFF_ECN		IFF_LINK1	/* enable ECN */
#define IFF_FWD_IPV6	IFF_LINK2	/* forward IPv6 packet */

extern struct psref_class *iv_psref_class;

struct ipsec_variant {
	struct ipsec_softc *iv_softc;

	struct sockaddr	*iv_psrc;	/* Physical src addr */
	struct sockaddr	*iv_pdst;	/* Physical dst addr */
	const struct encaptab *iv_encap_cookie4;
	const struct encaptab *iv_encap_cookie6;
	int (*iv_output)(struct ipsec_variant *, int, struct mbuf *);
	in_port_t iv_sport;
	in_port_t iv_dport;

	/*
	 * IPsec SPs
	 * Don't change directly, use if_ipsec_replace_sp().
	 */
	struct secpolicy *iv_sp[IPSEC_DIR_MAX];
	struct secpolicy *iv_sp6[IPSEC_DIR_MAX];

	struct psref_target iv_psref;
};

struct ipsec_softc {
	struct ifnet	ipsec_if;	/* common area - must be at the top */
	percpu_t *ipsec_ro_percpu;	/* struct tunnel_ro */
	struct ipsec_variant *ipsec_var; /*
					  * reader must use ipsec_getref_variant()
					  * instead of direct dereference.
					  */
	kmutex_t ipsec_lock;		/* writer lock for ipsec_var */
	pserialize_t ipsec_psz;
	int ipsec_pmtu;

	LIST_ENTRY(ipsec_softc) ipsec_list; /* list of all gifs */
};

#define IPSEC_MTU		(1280)	/* Default MTU */
#define	IPSEC_MTU_MIN		(1280)	/* Minimum MTU */
#define	IPSEC_MTU_MAX		(8192)	/* Maximum MTU */

#define IV_SP_IN(x) ((x)->iv_sp[IPSEC_DIR_INBOUND])
#define IV_SP_IN6(x) ((x)->iv_sp6[IPSEC_DIR_INBOUND])
#define IV_SP_OUT(x) ((x)->iv_sp[IPSEC_DIR_OUTBOUND])
#define IV_SP_OUT6(x) ((x)->iv_sp6[IPSEC_DIR_OUTBOUND])

static __inline bool
if_ipsec_variant_is_configured(struct ipsec_variant *var)
{

	return (var->iv_psrc != NULL && var->iv_pdst != NULL);
}

static __inline bool
if_ipsec_variant_is_unconfigured(struct ipsec_variant *var)
{

	return (var->iv_psrc == NULL || var->iv_pdst == NULL);
}

static __inline void
if_ipsec_copy_variant(struct ipsec_variant *dst, struct ipsec_variant *src)
{

	dst->iv_softc = src->iv_softc;
	dst->iv_psrc = src->iv_psrc;
	dst->iv_pdst = src->iv_pdst;
	dst->iv_encap_cookie4 = src->iv_encap_cookie4;
	dst->iv_encap_cookie6 = src->iv_encap_cookie6;
	dst->iv_output = src->iv_output;
	dst->iv_sport = src->iv_sport;
	dst->iv_dport = src->iv_dport;
}

static __inline void
if_ipsec_clear_config(struct ipsec_variant *var)
{

	var->iv_psrc = NULL;
	var->iv_pdst = NULL;
	var->iv_encap_cookie4 = NULL;
	var->iv_encap_cookie6 = NULL;
	var->iv_output = NULL;
	var->iv_sport = 0;
	var->iv_dport = 0;
}

/*
 * Get ipsec_variant from ipsec_softc.
 *
 * Never return NULL by contract.
 * ipsec_variant itself is protected not to be freed by lv_psref.
 * Once a reader dereference sc->sc_var by this API, the reader must not
 * re-dereference from sc->sc_var.
 */
static __inline struct ipsec_variant *
if_ipsec_getref_variant(struct ipsec_softc *sc, struct psref *psref)
{
	struct ipsec_variant *var;
	int s;

	s = pserialize_read_enter();
	var = atomic_load_consume(&sc->ipsec_var);
	KASSERT(var != NULL);
	psref_acquire(psref, &var->iv_psref, iv_psref_class);
	pserialize_read_exit(s);

	return var;
}

static __inline void
if_ipsec_putref_variant(struct ipsec_variant *var, struct psref *psref)
{

	KASSERT(var != NULL);
	psref_release(psref, &var->iv_psref, iv_psref_class);
}

static __inline bool
if_ipsec_heldref_variant(struct ipsec_variant *var)
{

	return psref_held(&var->iv_psref, iv_psref_class);
}

void ipsecifattach(int);
int if_ipsec_encap_func(struct mbuf *, int, int, void *);
void if_ipsec_input(struct mbuf *, int, struct ifnet *);
int if_ipsec_output(struct ifnet *, struct mbuf *,
		    const struct sockaddr *, const struct rtentry *);
int if_ipsec_ioctl(struct ifnet *, u_long, void *);
#endif /* _KERNEL */

/*
 * sharing SP note:
 * When ipsec(4) I/Fs use NAT-T, they can use the same src and dst address pair
 * as long as they use different port. Howerver, SPD cannot have the SPs which
 * use the same src and dst address pair and the same policy. So, such ipsec(4)
 * I/Fs share the same SPs.
 * To avoid race between ipsec0 set_tunnel/delete_tunnel and ipsec1
 * t_tunnel/delete_tunnel, any global lock is needed. See also the following
 * locking notes.
 *
 * Locking notes:
 * + ipsec_softcs.list is protected by ipsec_softcs.lock (an adaptive mutex)
 *       ipsec_softc_list is list of all ipsec_softcs. It is used by ioctl
 *       context only.
 * + ipsec_softc->ipsec_var is protected by
 *   - ipsec_softc->ipsec_lock (an adaptive mutex) for writer
 *   - ipsec_var->iv_psref for reader
 *       ipsec_softc->ipsec_var is used for variant values while the ipsec tunnel
 *       exists.
 * + struct tunnel_ro->tr_ro is protected by struct tunnel_ro->tr_lock.
 *       This lock is required to exclude softnet/0 lwp(such as output
 *       processing softint) and  processing lwp(such as DAD timer processing).
 * + if_ipsec_share_sp() and if_ipsec_unshare_sp() operations are serialized by
 *   encap_lock
 *       This only need to be global lock, need not to be encap_lock.
 *
 * Locking order:
 *     - encap_lock => ipsec_softc->ipsec_lock => ipsec_softcs.lock
 */
#endif /* _NET_IF_IPSEC_H_ */