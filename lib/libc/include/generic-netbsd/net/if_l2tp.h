/*	$NetBSD: if_l2tp.h,v 1.10 2021/03/16 07:00:38 knakahara Exp $	*/

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
 * L2TPv3 kernel interface
 */

#ifndef _NET_IF_L2TP_H_
#define _NET_IF_L2TP_H_

#include <sys/queue.h>
#include <sys/ioccom.h>
#ifdef _KERNEL
#include <sys/pserialize.h>
#include <sys/psref.h>
#include <sys/pslist.h>
#endif

#include <net/if_ether.h>
#include <netinet/in.h>

#define	SIOCSL2TPSESSION	_IOW('i', 151, struct ifreq)
#define	SIOCDL2TPSESSION	_IOW('i', 152, struct ifreq)
#define	SIOCSL2TPCOOKIE		_IOW('i', 153, struct ifreq)
#define	SIOCDL2TPCOOKIE		_IOW('i', 154, struct ifreq)
#define	SIOCSL2TPSTATE		_IOW('i', 155, struct ifreq)
#define	SIOCGL2TP		SIOCGIFGENERIC

struct l2tp_req {
	int state;
	u_int my_cookie_len;
	u_int peer_cookie_len;
	uint32_t my_sess_id;
	uint32_t peer_sess_id;
	uint64_t my_cookie;
	uint64_t peer_cookie;
};

#define	L2TP_STATE_UP	1
#define	L2TP_STATE_DOWN	0

#define	L2TP_COOKIE_ON	1
#define	L2TP_COOKIE_OFF	0

#ifdef _KERNEL
extern struct psref_class *lv_psref_class;

struct l2tp_variant {
	struct l2tp_softc *lv_softc;

	struct sockaddr	*lv_psrc; /* Physical src addr */
	struct sockaddr	*lv_pdst; /* Physical dst addr */
	const struct encaptab *lv_encap_cookie;

	/* L2TP session info */
	int lv_state;
	uint32_t lv_my_sess_id;		/* my session ID */
	uint32_t lv_peer_sess_id;	/* peer session ID */

	int lv_use_cookie;
	u_int lv_my_cookie_len;
	u_int lv_peer_cookie_len;
	uint64_t lv_my_cookie;		/* my cookie */
	uint64_t lv_peer_cookie;	/* peer cookie */

	struct psref_target lv_psref;
};

struct l2tp_softc {
	struct ethercom	l2tp_ec;	/* common area - must be at the top */
					/* to use ether_input(), we must have this */
	percpu_t *l2tp_ro_percpu;	/* struct tunnel_ro */
	struct l2tp_variant *l2tp_var;	/*
					* reader must use l2tp_getref_variant()
					* instead of direct dereference.
					*/
	kmutex_t l2tp_lock;		/* writer lock for l2tp_var */
	pserialize_t l2tp_psz;

	void *l2tp_si;
	percpu_t *l2tp_ifq_percpu;

	LIST_ENTRY(l2tp_softc) l2tp_list; /* list of all l2tps */
	struct pslist_entry l2tp_hash;	/* hashed list to lookup by session id */
};

#define	L2TP_ROUTE_TTL	10

#define	L2TP_MTU	(1280)	/* Default MTU */
#define	L2TP_MTU_MIN	(1280)	/* Minimum MTU */
#define	L2TP_MTU_MAX	(8192)	/* Maximum MTU */

/*
 * Get l2tp_variant from l2tp_softc.
 *
 * l2tp_variant itself is protected not to be freed by lv_psref.
 * In contrast, sc->sc_var can be changed to NULL even if reader critical
 * section. see l2tp_variant_update().
 * So, once a reader dereference sc->sc_var by this API, the reader must not
 * re-dereference form sc->sc_var.
 */
static __inline struct l2tp_variant *
l2tp_getref_variant(struct l2tp_softc *sc, struct psref *psref)
{
	struct l2tp_variant *var;
	int s;

	s = pserialize_read_enter();
	var = atomic_load_consume(&sc->l2tp_var);
	if (var == NULL) {
		pserialize_read_exit(s);
		return NULL;
	}
	psref_acquire(psref, &var->lv_psref, lv_psref_class);
	pserialize_read_exit(s);

	return var;
}

static __inline void
l2tp_putref_variant(struct l2tp_variant *var, struct psref *psref)
{

	if (var == NULL)
		return;
	psref_release(psref, &var->lv_psref, lv_psref_class);
}

static __inline bool
l2tp_heldref_variant(struct l2tp_variant *var)
{

	return psref_held(&var->lv_psref, lv_psref_class);
}


/* Prototypes */
void l2tpattach(int);
int l2tpattach0(struct l2tp_softc *);
void l2tp_input(struct mbuf *, struct ifnet *);
int l2tp_ioctl(struct ifnet *, u_long, void *);

struct l2tp_variant *l2tp_lookup_session_ref(uint32_t, struct psref *);
int l2tp_check_nesting(struct ifnet *, struct mbuf *);

/* TODO IP_TCPMSS support */
#ifdef IP_TCPMSS
struct mbuf *l2tp_tcpmss_clamp(struct ifnet *, struct mbuf *);
#endif /* IP_TCPMSS */
#endif /* _KERNEL */

/*
 * Locking notes:
 * + l2tp_softc_list is protected by l2tp_list_lock (an adaptive mutex)
 *       l2tp_softc_list is list of all l2tp_softcs, and it is used to avoid
 *       unload while busy.
 * + l2tp_hashed_list is protected by
 *   - l2tp_hash_lock (an adaptive mutex) for writer
 *   - pserialize for reader
 *       l2tp_hashed_list is hashed list of all l2tp_softcs, and it is used by
 *       input processing to find appropriate softc.
 * + l2tp_softc->l2tp_var is protected by
 *   - l2tp_softc->l2tp_lock (an adaptive mutex) for writer
 *   - l2tp_var->lv_psref for reader
 *       l2tp_softc->l2tp_var is used for variant values while the l2tp tunnel
 *       exists.
 * + struct l2tp_ro->lr_ro is protected by struct tunnel_ro->tr_lock.
 *       This lock is required to exclude softnet/0 lwp(such as output
 *       processing softint) and  processing lwp(such as DAD timer processing).
 *
 * Locking order:
 *     - encap_lock => struct l2tp_softc->l2tp_lock
 * Other mutexes must not hold simultaneously.
 *
 *   NOTICE
 *   - l2tp_softc must not have a variant value while the l2tp tunnel exists.
 *     Such variant values must be in l2tp_softc->l2tp_var.
 *   - l2tp_softc->l2tp_var is modified like read-copy-update.
 *     So, once we dereference l2tp_softc->l2tp_var, we must
 *     keep the pointer during the same context. If we re-derefence
 *     l2tp_softc->l2tp_var, the l2tp_var may be other one because of
 *     concurrent writer processing.
 */
#endif /* _NET_IF_L2TP_H_ */