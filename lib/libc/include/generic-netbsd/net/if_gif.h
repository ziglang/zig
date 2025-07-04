/*	$NetBSD: if_gif.h,v 1.35 2020/02/01 02:57:45 riastradh Exp $	*/
/*	$KAME: if_gif.h,v 1.23 2001/07/27 09:21:42 itojun Exp $	*/

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

/*
 * if_gif.h
 */

#ifndef _NET_IF_GIF_H_
#define _NET_IF_GIF_H_

#include <sys/queue.h>
#include <sys/percpu.h>
#ifdef _KERNEL
#include <sys/pserialize.h>
#include <sys/psref.h>
#endif

#ifdef _KERNEL_OPT
#include "opt_inet.h"
#endif

#include <netinet/in.h>
/* xxx sigh, why route have struct route instead of pointer? */

extern struct psref_class *gv_psref_class;

struct encaptab;

struct gif_variant {
	struct gif_softc *gv_softc;
	struct sockaddr	*gv_psrc; /* Physical src addr */
	struct sockaddr	*gv_pdst; /* Physical dst addr */
	const struct encaptab *gv_encap_cookie4;
	const struct encaptab *gv_encap_cookie6;
	int (*gv_output)(struct gif_variant *, int, struct mbuf *);

	struct psref_target gv_psref;
};

struct gif_softc {
	struct ifnet	gif_if;		/* common area - must be at the top */
	percpu_t *gif_ro_percpu;	/* struct tunnel_ro */
	struct gif_variant *gif_var;	/*
					 * reader must use gif_getref_variant()
					 * instead of direct dereference.
					 */
	kmutex_t gif_lock;		/* writer lock for gif_var */
	pserialize_t gif_psz;

	int gif_pmtu;

	LIST_ENTRY(gif_softc) gif_list;	/* list of all gifs */
};
#define GIF_ROUTE_TTL	10

#define GIF_MTU		(1280)	/* Default MTU */
#define	GIF_MTU_MIN	(1280)	/* Minimum MTU */
#define	GIF_MTU_MAX	(8192)	/* Maximum MTU */

/*
 * Get gif_variant from gif_softc.
 *
 * Never return NULL by contract.
 * gif_variant itself is protected not to be freed by gv_psref.
 * Once a reader dereference sc->sc_var by this API, the reader must not
 * re-dereference form sc->sc_var.
 */
static __inline struct gif_variant *
gif_getref_variant(struct gif_softc *sc, struct psref *psref)
{
	struct gif_variant *var;
	int s;

	s = pserialize_read_enter();
	var = atomic_load_consume(&sc->gif_var);
	KASSERT(var != NULL);
	psref_acquire(psref, &var->gv_psref, gv_psref_class);
	pserialize_read_exit(s);

	return var;
}

static __inline void
gif_putref_variant(struct gif_variant *var, struct psref *psref)
{

	KASSERT(var != NULL);
	psref_release(psref, &var->gv_psref, gv_psref_class);
}

static __inline bool
gif_heldref_variant(struct gif_variant *var)
{

	return psref_held(&var->gv_psref, gv_psref_class);
}

/* Prototypes */
void	gif_input(struct mbuf *, int, struct ifnet *);

#ifdef GIF_ENCAPCHECK
int	gif_encapcheck(struct mbuf *, int, int, void *);
#endif

/*
 * Locking notes:
 * + gif_softc_list is protected by gif_softcs.lock (an adaptive mutex)
 *       gif_softc_list is list of all gif_softcs. It is used by ioctl
 *       context only.
 * + gif_softc->gif_var is protected by
 *   - gif_softc->gif_lock (an adaptive mutex) for writer
 *   - gif_var->gv_psref for reader
 *       gif_softc->gif_var is used for variant values while the gif tunnel
 *       exists.
 * + Each CPU's tunnel_ro.tr_ro of gif_ro_percpu are protected by
 *   percpu'ed tunnel_ro.tr_lock.
 *
 * Locking order:
 *     - encap_lock => gif_softc->gif_lock => gif_softcs.lock
 */
#endif /* !_NET_IF_GIF_H_ */