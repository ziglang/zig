/*	$NetBSD: altq_afmap.h,v 1.3 2006/10/12 19:59:08 peter Exp $	*/
/*	$KAME: altq_afmap.h,v 1.6 2002/04/03 05:38:50 kjc Exp $	*/

/*
 * Copyright (C) 1997-2002
 *	Sony Computer Science Laboratories Inc.  All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY SONY CSL AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL SONY CSL OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _ALTQ_ALTQ_AFMAP_H_
#define	_ALTQ_ALTQ_AFMAP_H_

#include <sys/queue.h>
#include <altq/altq.h>

struct atm_flowmap {
	char		af_ifname[IFNAMSIZ];	/* if name, e.g. "en0" */
	u_int8_t	af_vpi;
	u_int16_t	af_vci;
	u_int32_t	af_pcr;			/* peek cell rate */
	union {
		struct flowinfo	      afu_fi;
		struct flowinfo_in    afu_fi4;
#ifdef SIN6_LEN
		struct flowinfo_in6   afu_fi6;
#endif
	} af_fiu;
#define	af_flowinfo	af_fiu.afu_fi
#define	af_flowinfo4	af_fiu.afu_fi4
#define	af_flowinfo6	af_fiu.afu_fi6

	/* statistics */
	u_int32_t	afs_packets;		/* total packet count */
	u_int32_t	afs_bytes;		/* total byte count */
};

/* set or get flowmap */
#define	AFM_ADDFMAP	_IOWR('F', 30, struct atm_flowmap)
#define	AFM_DELFMAP	_IOWR('F', 31, struct atm_flowmap)
#define	AFM_CLEANFMAP	_IOWR('F', 32, struct atm_flowmap)
#define	AFM_GETFMAP	_IOWR('F', 33, struct atm_flowmap)

#ifdef _KERNEL

/* per flow information */
struct afm {
	LIST_ENTRY(afm) 	afm_list;
	u_int16_t		afm_vci;
	u_int8_t		afm_vpi;
	union {
		struct flowinfo      afmu_fi;
		struct flowinfo_in   afmu_fi4;
#ifdef SIN6_LEN
		struct flowinfo_in6  afmu_fi6;
#endif
	} afm_fiu;
#define	afm_flowinfo	afm_fiu.afmu_fi
#define	afm_flowinfo4	afm_fiu.afmu_fi4
#define	afm_flowinfo6	afm_fiu.afmu_fi6

	/* statistics */
	u_int32_t		afms_packets;	/* total packet count */
	u_int32_t		afms_bytes;	/* total byte count */
};

/* per interface */
struct afm_head {
	LIST_ENTRY(afm_head) 	afh_chain;
	LIST_HEAD(, afm)	afh_head;
	struct ifnet		*afh_ifp;
};

struct afm	*afm_top(struct ifnet *);
int		afm_alloc(struct ifnet *);
int		afm_dealloc(struct ifnet *);
int		afm_add(struct ifnet *, struct atm_flowmap *);
int		afm_remove(struct afm *);
int		afm_removeall(struct ifnet *);
struct		afm *afm_lookup(struct ifnet *, int, int);
struct afm 	*afm_match(struct ifnet *, struct flowinfo *);

#endif /* _KERNEL */

#endif /* _ALTQ_ALTQ_AFMAP_H_ */