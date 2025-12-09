/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2001 Daniel Hartmeier
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *    - Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *    - Redistributions in binary form must reproduce the above
 *      copyright notice, this list of conditions and the following
 *      disclaimer in the documentation and/or other materials provided
 *      with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 *	$OpenBSD: pfvar.h,v 1.282 2009/01/29 15:12:28 pyr Exp $
 */

#ifndef _NET_PFVAR_H_
#define _NET_PFVAR_H_

#include <sys/param.h>
#include <sys/queue.h>
#include <sys/counter.h>
#include <sys/cpuset.h>
#include <sys/epoch.h>
#include <sys/malloc.h>
#include <sys/nv.h>
#include <sys/refcount.h>
#include <sys/sdt.h>
#include <sys/sysctl.h>
#include <sys/smp.h>
#include <sys/lock.h>
#include <sys/rmlock.h>
#include <sys/tree.h>
#include <sys/seqc.h>
#include <vm/uma.h>

#include <net/if.h>
#include <net/ethernet.h>
#include <net/radix.h>
#include <netinet/in.h>
#ifdef _KERNEL
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <netinet/sctp.h>
#include <netinet/ip_icmp.h>
#include <netinet/icmp6.h>
#endif

#include <netpfil/pf/pf.h>
#include <netpfil/pf/pf_altq.h>
#include <netpfil/pf/pf_mtag.h>

#ifdef _KERNEL

#define        PF_PFIL_NOREFRAGMENT    0x80000000

#if defined(__arm__)
#define PF_WANT_32_TO_64_COUNTER
#endif

/*
 * A hybrid of 32-bit and 64-bit counters which can be used on platforms where
 * counter(9) is very expensive.
 *
 * As 32-bit counters are expected to overflow, a periodic job sums them up to
 * a saved 64-bit state. Fetching the value still walks all CPUs to get the most
 * current snapshot.
 */
#ifdef PF_WANT_32_TO_64_COUNTER
struct pf_counter_u64_pcpu {
	u_int32_t current;
	u_int32_t snapshot;
};

struct pf_counter_u64 {
	struct pf_counter_u64_pcpu *pfcu64_pcpu;
	u_int64_t pfcu64_value;
	seqc_t	pfcu64_seqc;
};

static inline int
pf_counter_u64_init(struct pf_counter_u64 *pfcu64, int flags)
{

	pfcu64->pfcu64_value = 0;
	pfcu64->pfcu64_seqc = 0;
	pfcu64->pfcu64_pcpu = uma_zalloc_pcpu(pcpu_zone_8, flags | M_ZERO);
	if (__predict_false(pfcu64->pfcu64_pcpu == NULL))
		return (ENOMEM);
	return (0);
}

static inline void
pf_counter_u64_deinit(struct pf_counter_u64 *pfcu64)
{

	uma_zfree_pcpu(pcpu_zone_8, pfcu64->pfcu64_pcpu);
}

static inline void
pf_counter_u64_critical_enter(void)
{

	critical_enter();
}

static inline void
pf_counter_u64_critical_exit(void)
{

	critical_exit();
}

static inline void
pf_counter_u64_rollup_protected(struct pf_counter_u64 *pfcu64, uint64_t n)
{

	MPASS(curthread->td_critnest > 0);
	pfcu64->pfcu64_value += n;
}

static inline void
pf_counter_u64_add_protected(struct pf_counter_u64 *pfcu64, uint32_t n)
{
	struct pf_counter_u64_pcpu *pcpu;
	u_int32_t val;

	MPASS(curthread->td_critnest > 0);
	pcpu = zpcpu_get(pfcu64->pfcu64_pcpu);
	val = atomic_load_int(&pcpu->current);
	atomic_store_int(&pcpu->current, val + n);
}

static inline void
pf_counter_u64_add(struct pf_counter_u64 *pfcu64, uint32_t n)
{

	critical_enter();
	pf_counter_u64_add_protected(pfcu64, n);
	critical_exit();
}

static inline u_int64_t
pf_counter_u64_periodic(struct pf_counter_u64 *pfcu64)
{
	struct pf_counter_u64_pcpu *pcpu;
	u_int64_t sum;
	u_int32_t val;
	int cpu;

	MPASS(curthread->td_critnest > 0);
	seqc_write_begin(&pfcu64->pfcu64_seqc);
	sum = pfcu64->pfcu64_value;
	CPU_FOREACH(cpu) {
		pcpu = zpcpu_get_cpu(pfcu64->pfcu64_pcpu, cpu);
		val = atomic_load_int(&pcpu->current);
		sum += (uint32_t)(val - pcpu->snapshot);
		pcpu->snapshot = val;
	}
	pfcu64->pfcu64_value = sum;
	seqc_write_end(&pfcu64->pfcu64_seqc);
	return (sum);
}

static inline u_int64_t
pf_counter_u64_fetch(const struct pf_counter_u64 *pfcu64)
{
	struct pf_counter_u64_pcpu *pcpu;
	u_int64_t sum;
	seqc_t seqc;
	int cpu;

	for (;;) {
		seqc = seqc_read(&pfcu64->pfcu64_seqc);
		sum = 0;
		CPU_FOREACH(cpu) {
			pcpu = zpcpu_get_cpu(pfcu64->pfcu64_pcpu, cpu);
			sum += (uint32_t)(atomic_load_int(&pcpu->current) -pcpu->snapshot);
		}
		sum += pfcu64->pfcu64_value;
		if (seqc_consistent(&pfcu64->pfcu64_seqc, seqc))
			break;
	}
	return (sum);
}

static inline void
pf_counter_u64_zero_protected(struct pf_counter_u64 *pfcu64)
{
	struct pf_counter_u64_pcpu *pcpu;
	int cpu;

	MPASS(curthread->td_critnest > 0);
	seqc_write_begin(&pfcu64->pfcu64_seqc);
	CPU_FOREACH(cpu) {
		pcpu = zpcpu_get_cpu(pfcu64->pfcu64_pcpu, cpu);
		pcpu->snapshot = atomic_load_int(&pcpu->current);
	}
	pfcu64->pfcu64_value = 0;
	seqc_write_end(&pfcu64->pfcu64_seqc);
}

static inline void
pf_counter_u64_zero(struct pf_counter_u64 *pfcu64)
{

	critical_enter();
	pf_counter_u64_zero_protected(pfcu64);
	critical_exit();
}
#else
struct pf_counter_u64 {
	counter_u64_t counter;
};

static inline int
pf_counter_u64_init(struct pf_counter_u64 *pfcu64, int flags)
{

	pfcu64->counter = counter_u64_alloc(flags);
	if (__predict_false(pfcu64->counter == NULL))
		return (ENOMEM);
	return (0);
}

static inline void
pf_counter_u64_deinit(struct pf_counter_u64 *pfcu64)
{

	counter_u64_free(pfcu64->counter);
}

static inline void
pf_counter_u64_critical_enter(void)
{

}

static inline void
pf_counter_u64_critical_exit(void)
{

}

static inline void
pf_counter_u64_rollup_protected(struct pf_counter_u64 *pfcu64, uint64_t n)
{

	counter_u64_add(pfcu64->counter, n);
}

static inline void
pf_counter_u64_add_protected(struct pf_counter_u64 *pfcu64, uint32_t n)
{

	counter_u64_add(pfcu64->counter, n);
}

static inline void
pf_counter_u64_add(struct pf_counter_u64 *pfcu64, uint32_t n)
{

	pf_counter_u64_add_protected(pfcu64, n);
}

static inline u_int64_t
pf_counter_u64_fetch(const struct pf_counter_u64 *pfcu64)
{

	return (counter_u64_fetch(pfcu64->counter));
}

static inline void
pf_counter_u64_zero_protected(struct pf_counter_u64 *pfcu64)
{

	counter_u64_zero(pfcu64->counter);
}

static inline void
pf_counter_u64_zero(struct pf_counter_u64 *pfcu64)
{

	pf_counter_u64_zero_protected(pfcu64);
}
#endif

#define pf_get_timestamp(prule)({					\
	uint32_t _ts = 0;						\
	uint32_t __ts;							\
	int cpu;							\
	CPU_FOREACH(cpu) {						\
		__ts = *zpcpu_get_cpu(prule->timestamp, cpu);		\
		if (__ts > _ts)						\
			_ts = __ts;					\
	}								\
	_ts;								\
})

#define pf_update_timestamp(prule)					\
	do {								\
		critical_enter();					\
		*zpcpu_get((prule)->timestamp) = time_second;		\
		critical_exit();					\
	} while (0)

#define pf_timestamp_pcpu_zone	(sizeof(time_t) == 4 ? pcpu_zone_4 : pcpu_zone_8)
_Static_assert(sizeof(time_t) == 4 || sizeof(time_t) == 8, "unexpected time_t size");

SYSCTL_DECL(_net_pf);
MALLOC_DECLARE(M_PF);
MALLOC_DECLARE(M_PFHASH);
MALLOC_DECLARE(M_PF_RULE_ITEM);

SDT_PROVIDER_DECLARE(pf);
SDT_PROBE_DECLARE(pf, , test, reason_set);
SDT_PROBE_DECLARE(pf, , log, log);

#define DPFPRINTF(n, fmt, x...)				\
	do {						\
		SDT_PROBE2(pf, , log, log, (n), fmt);	\
		if (V_pf_status.debug >= (n))	 	\
			printf(fmt "\n", ##x); 		\
	} while (0)

struct pfi_dynaddr {
	TAILQ_ENTRY(pfi_dynaddr)	 entry;
	struct pf_addr			 pfid_addr4;
	struct pf_addr			 pfid_mask4;
	struct pf_addr			 pfid_addr6;
	struct pf_addr			 pfid_mask6;
	struct pfr_ktable		*pfid_kt;
	struct pfi_kkif			*pfid_kif;
	int				 pfid_net;	/* mask or 128 */
	int				 pfid_acnt4;	/* address count IPv4 */
	int				 pfid_acnt6;	/* address count IPv6 */
	sa_family_t			 pfid_af;	/* rule af */
	u_int8_t			 pfid_iflags;	/* PFI_AFLAG_* */
};

#define	PF_NAME		"pf"

#define	PF_HASHROW_ASSERT(h)	mtx_assert(&(h)->lock, MA_OWNED)
#define	PF_HASHROW_LOCK(h)	mtx_lock(&(h)->lock)
#define	PF_HASHROW_UNLOCK(h)	mtx_unlock(&(h)->lock)

#ifdef INVARIANTS
#define	PF_STATE_LOCK(s)						\
	do {								\
		struct pf_kstate *_s = (s);				\
		struct pf_idhash *_ih = &V_pf_idhash[PF_IDHASH(_s)];	\
		MPASS(_s->lock == &_ih->lock);				\
		mtx_lock(_s->lock);					\
	} while (0)
#define	PF_STATE_UNLOCK(s)						\
	do {								\
		struct pf_kstate *_s = (s);				\
		struct pf_idhash *_ih = &V_pf_idhash[PF_IDHASH(_s)];	\
		MPASS(_s->lock == &_ih->lock);				\
		mtx_unlock(_s->lock);					\
	} while (0)
#else
#define	PF_STATE_LOCK(s)	mtx_lock((s)->lock)
#define	PF_STATE_UNLOCK(s)	mtx_unlock((s)->lock)
#endif

#ifdef INVARIANTS
#define	PF_STATE_LOCK_ASSERT(s)						\
	do {								\
		struct pf_kstate *_s = (s);				\
		struct pf_idhash *_ih = &V_pf_idhash[PF_IDHASH(_s)];	\
		MPASS(_s->lock == &_ih->lock);				\
		PF_HASHROW_ASSERT(_ih);					\
	} while (0)
#else /* !INVARIANTS */
#define	PF_STATE_LOCK_ASSERT(s)		do {} while (0)
#endif /* INVARIANTS */

#ifdef INVARIANTS
#define	PF_SRC_NODE_LOCK(sn)						\
	do {								\
		struct pf_ksrc_node *_sn = (sn);			\
		struct pf_srchash *_sh = &V_pf_srchash[			\
		    pf_hashsrc(&_sn->addr, _sn->af)];			\
		MPASS(_sn->lock == &_sh->lock);				\
		mtx_lock(_sn->lock);					\
	} while (0)
#define	PF_SRC_NODE_UNLOCK(sn)						\
	do {								\
		struct pf_ksrc_node *_sn = (sn);			\
		struct pf_srchash *_sh = &V_pf_srchash[			\
		    pf_hashsrc(&_sn->addr, _sn->af)];			\
		MPASS(_sn->lock == &_sh->lock);				\
		mtx_unlock(_sn->lock);					\
	} while (0)
#else
#define	PF_SRC_NODE_LOCK(sn)	mtx_lock((sn)->lock)
#define	PF_SRC_NODE_UNLOCK(sn)	mtx_unlock((sn)->lock)
#endif

#ifdef INVARIANTS
#define	PF_SRC_NODE_LOCK_ASSERT(sn)					\
	do {								\
		struct pf_ksrc_node *_sn = (sn);			\
		struct pf_srchash *_sh = &V_pf_srchash[			\
		    pf_hashsrc(&_sn->addr, _sn->af)];			\
		MPASS(_sn->lock == &_sh->lock);				\
		PF_HASHROW_ASSERT(_sh);					\
	} while (0)
#else /* !INVARIANTS */
#define	PF_SRC_NODE_LOCK_ASSERT(sn)		do {} while (0)
#endif /* INVARIANTS */

extern struct mtx_padalign pf_unlnkdrules_mtx;
#define	PF_UNLNKDRULES_LOCK()	mtx_lock(&pf_unlnkdrules_mtx)
#define	PF_UNLNKDRULES_UNLOCK()	mtx_unlock(&pf_unlnkdrules_mtx)
#define	PF_UNLNKDRULES_ASSERT()	mtx_assert(&pf_unlnkdrules_mtx, MA_OWNED)

extern struct sx pf_config_lock;
#define	PF_CONFIG_LOCK()	sx_xlock(&pf_config_lock)
#define	PF_CONFIG_UNLOCK()	sx_xunlock(&pf_config_lock)
#define	PF_CONFIG_ASSERT()	sx_assert(&pf_config_lock, SA_XLOCKED)

VNET_DECLARE(struct rmlock, pf_rules_lock);
#define	V_pf_rules_lock		VNET(pf_rules_lock)

#define	PF_RULES_RLOCK_TRACKER	struct rm_priotracker _pf_rules_tracker
#define	PF_RULES_RLOCK()	rm_rlock(&V_pf_rules_lock, &_pf_rules_tracker)
#define	PF_RULES_RUNLOCK()	rm_runlock(&V_pf_rules_lock, &_pf_rules_tracker)
#define	PF_RULES_WLOCK()	rm_wlock(&V_pf_rules_lock)
#define	PF_RULES_WUNLOCK()	rm_wunlock(&V_pf_rules_lock)
#define	PF_RULES_WOWNED()	rm_wowned(&V_pf_rules_lock)
#define	PF_RULES_ASSERT()	rm_assert(&V_pf_rules_lock, RA_LOCKED)
#define	PF_RULES_RASSERT()	rm_assert(&V_pf_rules_lock, RA_RLOCKED)
#define	PF_RULES_WASSERT()	rm_assert(&V_pf_rules_lock, RA_WLOCKED)

VNET_DECLARE(struct rmlock, pf_tags_lock);
#define	V_pf_tags_lock		VNET(pf_tags_lock)

#define	PF_TAGS_RLOCK_TRACKER	struct rm_priotracker _pf_tags_tracker
#define	PF_TAGS_RLOCK()		rm_rlock(&V_pf_tags_lock, &_pf_tags_tracker)
#define	PF_TAGS_RUNLOCK()	rm_runlock(&V_pf_tags_lock, &_pf_tags_tracker)
#define	PF_TAGS_WLOCK()		rm_wlock(&V_pf_tags_lock)
#define	PF_TAGS_WUNLOCK()	rm_wunlock(&V_pf_tags_lock)
#define	PF_TAGS_WASSERT()	rm_assert(&V_pf_tags_lock, RA_WLOCKED)

extern struct mtx_padalign pf_table_stats_lock;
#define	PF_TABLE_STATS_LOCK()	mtx_lock(&pf_table_stats_lock)
#define	PF_TABLE_STATS_UNLOCK()	mtx_unlock(&pf_table_stats_lock)
#define	PF_TABLE_STATS_OWNED()	mtx_owned(&pf_table_stats_lock)
#define	PF_TABLE_STATS_ASSERT()	mtx_assert(&pf_table_stats_lock, MA_OWNED)

extern struct sx pf_end_lock;

#define	PF_MODVER	1
#define	PFLOG_MODVER	1
#define	PFSYNC_MODVER	1

#define	PFLOG_MINVER	1
#define	PFLOG_PREFVER	PFLOG_MODVER
#define	PFLOG_MAXVER	1
#define	PFSYNC_MINVER	1
#define	PFSYNC_PREFVER	PFSYNC_MODVER
#define	PFSYNC_MAXVER	1

#ifdef INET
#ifndef INET6
#define	PF_INET_ONLY
#endif /* ! INET6 */
#endif /* INET */

#ifdef INET6
#ifndef INET
#define	PF_INET6_ONLY
#endif /* ! INET */
#endif /* INET6 */

#ifdef INET
#ifdef INET6
#define	PF_INET_INET6
#endif /* INET6 */
#endif /* INET */

#else

#define	PF_INET_INET6

#endif /* _KERNEL */

/* Both IPv4 and IPv6 */
#ifdef PF_INET_INET6

#define PF_AEQ(a, b, c) \
	((c == AF_INET && (a)->addr32[0] == (b)->addr32[0]) || \
	(c == AF_INET6 && (a)->addr32[3] == (b)->addr32[3] && \
	(a)->addr32[2] == (b)->addr32[2] && \
	(a)->addr32[1] == (b)->addr32[1] && \
	(a)->addr32[0] == (b)->addr32[0])) \

#define PF_ANEQ(a, b, c) \
	((c == AF_INET && (a)->addr32[0] != (b)->addr32[0]) || \
	(c == AF_INET6 && ((a)->addr32[0] != (b)->addr32[0] || \
	(a)->addr32[1] != (b)->addr32[1] || \
	(a)->addr32[2] != (b)->addr32[2] || \
	(a)->addr32[3] != (b)->addr32[3]))) \

#define PF_AZERO(a, c) \
	((c == AF_INET && !(a)->addr32[0]) || \
	(c == AF_INET6 && !(a)->addr32[0] && !(a)->addr32[1] && \
	!(a)->addr32[2] && !(a)->addr32[3] )) \

#else

/* Just IPv6 */

#ifdef PF_INET6_ONLY

#define PF_AEQ(a, b, c) \
	((a)->addr32[3] == (b)->addr32[3] && \
	(a)->addr32[2] == (b)->addr32[2] && \
	(a)->addr32[1] == (b)->addr32[1] && \
	(a)->addr32[0] == (b)->addr32[0]) \

#define PF_ANEQ(a, b, c) \
	((a)->addr32[3] != (b)->addr32[3] || \
	(a)->addr32[2] != (b)->addr32[2] || \
	(a)->addr32[1] != (b)->addr32[1] || \
	(a)->addr32[0] != (b)->addr32[0]) \

#define PF_AZERO(a, c) \
	(!(a)->addr32[0] && \
	!(a)->addr32[1] && \
	!(a)->addr32[2] && \
	!(a)->addr32[3] ) \

#else

/* Just IPv4 */
#ifdef PF_INET_ONLY

#define PF_AEQ(a, b, c) \
	((a)->addr32[0] == (b)->addr32[0])

#define PF_ANEQ(a, b, c) \
	((a)->addr32[0] != (b)->addr32[0])

#define PF_AZERO(a, c) \
	(!(a)->addr32[0])

#endif /* PF_INET_ONLY */
#endif /* PF_INET6_ONLY */
#endif /* PF_INET_INET6 */

#ifdef _KERNEL

void				 unhandled_af(int) __dead2;

static void inline
pf_addrcpy(struct pf_addr *dst, const struct pf_addr *src, sa_family_t af)
{
	switch (af) {
#ifdef INET
	case AF_INET:
		memcpy(&dst->v4, &src->v4, sizeof(dst->v4));
		break;
#endif /* INET */
#ifdef INET6
	case AF_INET6:
		memcpy(&dst->v6, &src->v6, sizeof(dst->v6));
		break;
#endif /* INET6 */
	default:
		unhandled_af(af);
	}
}
#endif

/*
 * XXX callers not FIB-aware in our version of pf yet.
 * OpenBSD fixed it later it seems, 2010/05/07 13:33:16 claudio.
 */
#define	PF_MISMATCHAW(aw, x, af, neg, ifp, rtid)			\
	(								\
		(((aw)->type == PF_ADDR_NOROUTE &&			\
		    pf_routable((x), (af), NULL, (rtid))) ||		\
		(((aw)->type == PF_ADDR_URPFFAILED && (ifp) != NULL &&	\
		    pf_routable((x), (af), (ifp), (rtid))) ||		\
		((aw)->type == PF_ADDR_TABLE &&				\
		    !pfr_match_addr((aw)->p.tbl, (x), (af))) ||		\
		((aw)->type == PF_ADDR_DYNIFTL &&			\
		    !pfi_match_addr((aw)->p.dyn, (x), (af))) ||		\
		((aw)->type == PF_ADDR_RANGE &&				\
		    !pf_match_addr_range(&(aw)->v.a.addr,		\
		    &(aw)->v.a.mask, (x), (af))) ||			\
		((aw)->type == PF_ADDR_ADDRMASK &&			\
		    !PF_AZERO(&(aw)->v.a.mask, (af)) &&			\
		    !pf_match_addr(0, &(aw)->v.a.addr,			\
		    &(aw)->v.a.mask, (x), (af))))) !=			\
		(neg)							\
	)

#define PF_ALGNMNT(off) (((off) % 2) == 0)

/*
 * At the moment there are no rules which have both NAT and RDR actions,
 * apart from af-to rules, but those don't to source tracking for address
 * translation. And the r->rdr pool is used for both NAT and RDR.
 * So there is no PF_SN_RDR.
 */
enum pf_sn_types { PF_SN_LIMIT, PF_SN_NAT, PF_SN_ROUTE, PF_SN_MAX };
typedef enum pf_sn_types pf_sn_types_t;
#define PF_SN_TYPE_NAMES { \
	"limit source-track", \
	"NAT/RDR sticky-address", \
	"route sticky-address", \
	NULL \
}

#ifdef _KERNEL

struct pf_kpooladdr {
	struct pf_addr_wrap		 addr;
	TAILQ_ENTRY(pf_kpooladdr)	 entries;
	char				 ifname[IFNAMSIZ];
	sa_family_t		 	 af;
	struct pfi_kkif			*kif;
};

TAILQ_HEAD(pf_kpalist, pf_kpooladdr);

struct pf_kpool {
	struct mtx		 mtx;
	struct pf_kpalist	 list;
	struct pf_kpooladdr	*cur;
	struct pf_poolhashkey	 key;
	struct pf_addr		 counter;
	struct pf_mape_portset	 mape;
	int			 tblidx;
	u_int16_t		 proxy_port[2];
	u_int8_t		 opts;
	sa_family_t		 ipv6_nexthop_af;
};

struct pf_rule_actions {
	struct pf_addr	 rt_addr;
	struct pfi_kkif	*rt_kif;
	int32_t		 rtableid;
	uint32_t	 flags;
	uint16_t	 qid;
	uint16_t	 pqid;
	uint16_t	 max_mss;
	uint16_t	 dnpipe;
	uint16_t	 dnrpipe;	/* Reverse direction pipe */
	sa_family_t	 rt_af;
	uint8_t		 log;
	uint8_t		 set_tos;
	uint8_t		 min_ttl;
	uint8_t		 set_prio[2];
	uint8_t		 rt;
	uint8_t		 allow_opts;
	uint16_t	 max_pkt_size;
};

union pf_keth_rule_ptr {
	struct pf_keth_rule	*ptr;
	uint32_t		nr;
};

struct pf_keth_rule_addr {
	uint8_t	addr[ETHER_ADDR_LEN];
	uint8_t	mask[ETHER_ADDR_LEN];
	bool neg;
	uint8_t	isset;
};

struct pf_keth_anchor;

TAILQ_HEAD(pf_keth_ruleq, pf_keth_rule);

struct pf_keth_ruleset {
	struct pf_keth_ruleq		 rules[2];
	struct pf_keth_rules {
		struct pf_keth_ruleq	*rules;
		int			 open;
		uint32_t		 ticket;
	} active, inactive;
	struct vnet		*vnet;
	struct pf_keth_anchor	*anchor;
};

RB_HEAD(pf_keth_anchor_global, pf_keth_anchor);
RB_HEAD(pf_keth_anchor_node, pf_keth_anchor);
struct pf_keth_anchor {
	RB_ENTRY(pf_keth_anchor)	 entry_node;
	RB_ENTRY(pf_keth_anchor)	 entry_global;
	struct pf_keth_anchor		*parent;
	struct pf_keth_anchor_node	 children;
	char				 name[PF_ANCHOR_NAME_SIZE];
	char				 path[MAXPATHLEN];
	struct pf_keth_ruleset		 ruleset;
	int				 refcnt;	/* anchor rules */
	uint8_t				 anchor_relative;
	uint8_t				 anchor_wildcard;
};
RB_PROTOTYPE(pf_keth_anchor_node, pf_keth_anchor, entry_node,
    pf_keth_anchor_compare);
RB_PROTOTYPE(pf_keth_anchor_global, pf_keth_anchor, entry_global,
    pf_keth_anchor_compare);

struct pf_keth_rule {
#define PFE_SKIP_IFP		0
#define PFE_SKIP_DIR		1
#define PFE_SKIP_PROTO		2
#define PFE_SKIP_SRC_ADDR	3
#define PFE_SKIP_DST_ADDR	4
#define PFE_SKIP_SRC_IP_ADDR	5
#define PFE_SKIP_DST_IP_ADDR	6
#define PFE_SKIP_COUNT		7
	union pf_keth_rule_ptr	 skip[PFE_SKIP_COUNT];

	TAILQ_ENTRY(pf_keth_rule)	entries;

	struct pf_keth_anchor	*anchor;
	u_int8_t		 anchor_relative;
	u_int8_t		 anchor_wildcard;

	uint32_t		 nr;

	bool			 quick;

	/* Filter */
	char			 ifname[IFNAMSIZ];
	struct pfi_kkif		*kif;
	bool			 ifnot;
	uint8_t			 direction;
	uint16_t		 proto;
	struct pf_keth_rule_addr src, dst;
	struct pf_rule_addr	 ipsrc, ipdst;
	char			 match_tagname[PF_TAG_NAME_SIZE];
	uint16_t		 match_tag;
	bool			 match_tag_not;


	/* Stats */
	counter_u64_t		 evaluations;
	counter_u64_t		 packets[2];
	counter_u64_t		 bytes[2];
	time_t			*timestamp;

	/* Action */
	char			 qname[PF_QNAME_SIZE];
	int			 qid;
	char			 tagname[PF_TAG_NAME_SIZE];
	uint16_t		 tag;
	char			 bridge_to_name[IFNAMSIZ];
	struct pfi_kkif		*bridge_to;
	uint8_t			 action;
	uint16_t		 dnpipe;
	uint32_t		 dnflags;

	char			label[PF_RULE_MAX_LABEL_COUNT][PF_RULE_LABEL_SIZE];
	uint32_t		ridentifier;
};

struct pf_kthreshold {
	uint32_t		 limit;
	uint32_t		 seconds;
	struct counter_rate	*cr;
};

RB_HEAD(pf_krule_global, pf_krule);
RB_PROTOTYPE(pf_krule_global, pf_krule, entry_global, pf_krule_compare);

struct pf_krule {
	struct pf_rule_addr	 src;
	struct pf_rule_addr	 dst;
	struct pf_krule		*skip[PF_SKIP_COUNT];
	char			 label[PF_RULE_MAX_LABEL_COUNT][PF_RULE_LABEL_SIZE];
	uint32_t		 ridentifier;
	char			 ifname[IFNAMSIZ];
	char			 rcv_ifname[IFNAMSIZ];
	char			 qname[PF_QNAME_SIZE];
	char			 pqname[PF_QNAME_SIZE];
	char			 tagname[PF_TAG_NAME_SIZE];
	char			 match_tagname[PF_TAG_NAME_SIZE];

	char			 overload_tblname[PF_TABLE_NAME_SIZE];

	TAILQ_ENTRY(pf_krule)	 entries;
	struct pf_kpool		 nat;
	struct pf_kpool		 rdr;
	struct pf_kpool		 route;
	struct pf_kthreshold	 pktrate;

	struct pf_counter_u64	 evaluations;
	struct pf_counter_u64	 packets[2];
	struct pf_counter_u64	 bytes[2];
	time_t			*timestamp;

	struct pfi_kkif		*kif;
	struct pfi_kkif		*rcv_kif;
	struct pf_kanchor	*anchor;
	struct pfr_ktable	*overload_tbl;

	pf_osfp_t		 os_fingerprint;

	int32_t			 rtableid;
	u_int32_t		 timeout[PFTM_MAX];
	u_int32_t		 max_states;
	u_int32_t		 max_src_nodes;
	u_int32_t		 max_src_states;
	u_int32_t		 max_src_conn;
	struct {
		u_int32_t		limit;
		u_int32_t		seconds;
	}			 max_src_conn_rate;
	uint16_t		 max_pkt_size;
	u_int16_t		 qid;
	u_int16_t		 pqid;
	u_int16_t		 dnpipe;
	u_int16_t		 dnrpipe;
	u_int32_t		 free_flags;
	u_int32_t		 nr;
	u_int32_t		 prob;
	uid_t			 cuid;
	pid_t			 cpid;

	counter_u64_t		 states_cur;
	counter_u64_t		 states_tot;
	counter_u64_t		 src_nodes[PF_SN_MAX];

	u_int16_t		 return_icmp;
	u_int16_t		 return_icmp6;
	u_int16_t		 max_mss;
	u_int16_t		 tag;
	u_int16_t		 match_tag;
	u_int16_t		 scrub_flags;

	struct pf_rule_uid	 uid;
	struct pf_rule_gid	 gid;

	u_int32_t		 rule_flag;
	uint32_t		 rule_ref;
	u_int8_t		 action;
	u_int8_t		 direction;
	u_int8_t		 log;
	u_int8_t		 logif;
	u_int8_t		 quick;
	u_int8_t		 ifnot;
	u_int8_t		 match_tag_not;
	u_int8_t		 natpass;

	u_int8_t		 keep_state;
	sa_family_t		 af;
	u_int8_t		 proto;
	uint16_t		 type;
	uint16_t		 code;
	u_int8_t		 flags;
	u_int8_t		 flagset;
	u_int8_t		 min_ttl;
	u_int8_t		 allow_opts;
	u_int8_t		 rt;
	u_int8_t		 return_ttl;
	u_int8_t		 tos;
	u_int8_t		 set_tos;
	u_int8_t		 anchor_relative;
	u_int8_t		 anchor_wildcard;

	u_int8_t		 flush;
	u_int8_t		 prio;
	u_int8_t		 set_prio[2];
	sa_family_t		 naf;
	u_int8_t		 rcvifnot;

	struct {
		struct pf_addr		addr;
		u_int16_t		port;
	}			divert;
	u_int8_t		 md5sum[PF_MD5_DIGEST_LENGTH];
	RB_ENTRY(pf_krule)	 entry_global;

#ifdef PF_WANT_32_TO_64_COUNTER
	LIST_ENTRY(pf_krule)	 allrulelist;
	bool			 allrulelinked;
#endif
};

struct pf_krule_item {
	SLIST_ENTRY(pf_krule_item)	 entry;
	struct pf_krule			*r;
};

SLIST_HEAD(pf_krule_slist, pf_krule_item);

struct pf_ksrc_node {
	LIST_ENTRY(pf_ksrc_node) entry;
	struct pf_addr		 addr;
	struct pf_addr		 raddr;
	struct pf_krule_slist	 match_rules;
	struct pf_krule		*rule;
	struct pfi_kkif		*rkif;
	counter_u64_t		 bytes[2];
	counter_u64_t		 packets[2];
	u_int32_t		 states;
	u_int32_t		 conn;
	struct pf_kthreshold	 conn_rate;
	u_int32_t		 creation;
	u_int32_t		 expire;
	sa_family_t		 af;
	sa_family_t		 raf;
	u_int8_t		 ruletype;
	pf_sn_types_t		 type;
	struct mtx		*lock;
};
#endif

struct pf_state_scrub {
	struct timeval	pfss_last;	/* time received last packet	*/
	u_int32_t	pfss_tsecr;	/* last echoed timestamp	*/
	u_int32_t	pfss_tsval;	/* largest timestamp		*/
	u_int32_t	pfss_tsval0;	/* original timestamp		*/
	u_int16_t	pfss_flags;
#define PFSS_TIMESTAMP	0x0001		/* modulate timestamp		*/
#define PFSS_PAWS	0x0010		/* stricter PAWS checks		*/
#define PFSS_PAWS_IDLED	0x0020		/* was idle too long.  no PAWS	*/
#define PFSS_DATA_TS	0x0040		/* timestamp on data packets	*/
#define PFSS_DATA_NOTS	0x0080		/* no timestamp on data packets	*/
	u_int8_t	pfss_ttl;	/* stashed TTL			*/
	u_int8_t	pad;
	union {
		u_int32_t	pfss_ts_mod;	/* timestamp modulation		*/
		u_int32_t	pfss_v_tag;	/* SCTP verification tag	*/
	};
};

struct pf_state_host {
	struct pf_addr	addr;
	u_int16_t	port;
	u_int16_t	pad;
};

struct pf_state_peer {
	struct pf_state_scrub	*scrub;	/* state is scrubbed		*/
	u_int32_t	seqlo;		/* Max sequence number sent	*/
	u_int32_t	seqhi;		/* Max the other end ACKd + win	*/
	u_int32_t	seqdiff;	/* Sequence number modulator	*/
	u_int16_t	max_win;	/* largest window (pre scaling)	*/
	u_int16_t	mss;		/* Maximum segment size option	*/
	u_int8_t	state;		/* active state level		*/
	u_int8_t	wscale;		/* window scaling factor	*/
	u_int8_t	tcp_est;	/* Did we reach TCPS_ESTABLISHED */
	u_int8_t	pad[1];
};

/* Keep synced with struct pf_udp_endpoint. */
struct pf_udp_endpoint_cmp {
	struct pf_addr	addr;
	uint16_t	port;
	sa_family_t	af;
	uint8_t		pad[1];
};

struct pf_udp_endpoint {
	struct pf_addr	addr;
	uint16_t	port;
	sa_family_t	af;
	uint8_t		pad[1];

	struct pf_udp_mapping *mapping;
	LIST_ENTRY(pf_udp_endpoint) entry;
};

struct pf_udp_mapping {
	struct pf_udp_endpoint endpoints[2];
	u_int refs;
};

/* Keep synced with struct pf_state_key. */
struct pf_state_key_cmp {
	struct pf_addr	 addr[2];
	u_int16_t	 port[2];
	sa_family_t	 af;
	u_int8_t	 proto;
	u_int8_t	 pad[2];
};

struct pf_state_key {
	struct pf_addr	 addr[2];
	u_int16_t	 port[2];
	sa_family_t	 af;
	u_int8_t	 proto;
	u_int8_t	 pad[2];

	LIST_ENTRY(pf_state_key) entry;
	TAILQ_HEAD(, pf_kstate)	 states[2];
};

#define PF_REVERSED_KEY(state, family)					\
	(((state)->key[PF_SK_WIRE]->af != (state)->key[PF_SK_STACK]->af) &&	\
	    ((state)->key[PF_SK_WIRE]->af != (family)) &&			\
	    ((state)->direction == PF_IN))

/* Keep synced with struct pf_kstate. */
struct pf_state_cmp {
	u_int64_t		 id;
	u_int32_t		 creatorid;
	u_int8_t		 direction;
	u_int8_t		 pad[3];
};

struct pf_state_scrub_export {
	uint16_t	pfss_flags;
	uint8_t		pfss_ttl;	/* stashed TTL		*/
#define PF_SCRUB_FLAG_VALID		0x01
	uint8_t		scrub_flag;
	uint32_t	pfss_ts_mod;	/* timestamp modulation	*/
} __packed;

struct pf_state_key_export {
	struct pf_addr	 addr[2];
	uint16_t	 port[2];
};

struct pf_state_peer_export {
	struct pf_state_scrub_export	scrub;	/* state is scrubbed	*/
	uint32_t	seqlo;		/* Max sequence number sent	*/
	uint32_t	seqhi;		/* Max the other end ACKd + win	*/
	uint32_t	seqdiff;	/* Sequence number modulator	*/
	uint16_t	max_win;	/* largest window (pre scaling)	*/
	uint16_t	mss;		/* Maximum segment size option	*/
	uint8_t		state;		/* active state level		*/
	uint8_t		wscale;		/* window scaling factor	*/
	uint8_t		dummy[6];
} __packed;
_Static_assert(sizeof(struct pf_state_peer_export) == 32, "size incorrect");

struct pf_state_export {
	uint64_t	 version;
#define	PF_STATE_VERSION	20230404
	uint64_t	 id;
	char		 ifname[IFNAMSIZ];
	char		 orig_ifname[IFNAMSIZ];
	struct pf_state_key_export	 key[2];
	struct pf_state_peer_export	 src;
	struct pf_state_peer_export	 dst;
	struct pf_addr	 rt_addr;
	uint32_t	 rule;
	uint32_t	 anchor;
	uint32_t	 nat_rule;
	uint32_t	 creation;
	uint32_t	 expire;
	uint32_t	 spare0;
	uint64_t	 packets[2];
	uint64_t	 bytes[2];
	uint32_t	 creatorid;
	uint32_t	 spare1;
	sa_family_t	 af;
	uint8_t		 proto;
	uint8_t		 direction;
	uint8_t		 log;
	uint8_t		 state_flags_compat;
	uint8_t		 timeout;
	uint8_t		 sync_flags;
	uint8_t		 updates;
	uint16_t	 state_flags;
	uint16_t	 qid;
	uint16_t	 pqid;
	uint16_t	 dnpipe;
	uint16_t	 dnrpipe;
	int32_t		 rtableid;
	uint8_t		 min_ttl;
	uint8_t		 set_tos;
	uint16_t	 max_mss;
	uint8_t		 set_prio[2];
	uint8_t		 rt;
	char		 rt_ifname[IFNAMSIZ];

	uint8_t		 spare[72];
};
_Static_assert(sizeof(struct pf_state_export) == 384, "size incorrect");

#ifdef _KERNEL
struct pf_kstate {
	/*
	 * Area shared with pf_state_cmp
	 */
	u_int64_t		 id;
	u_int32_t		 creatorid;
	u_int8_t		 direction;
	u_int8_t		 pad[3];
	/*
	 * end of the area
	 */

	u_int16_t		 state_flags;
	u_int8_t		 timeout;
	u_int8_t		 sync_state; /* PFSYNC_S_x */
	u_int8_t		 sync_updates;
	u_int			 refs;
	struct mtx		*lock;
	TAILQ_ENTRY(pf_kstate)	 sync_list;
	TAILQ_ENTRY(pf_kstate)	 key_list[2];
	LIST_ENTRY(pf_kstate)	 entry;
	struct pf_state_peer	 src;
	struct pf_state_peer	 dst;
	struct pf_krule_slist	 match_rules;
	struct pf_krule		*rule;
	struct pf_krule		*anchor;
	struct pf_krule		*nat_rule;
	struct pf_state_key	*key[2];	/* addresses stack and wire  */
	struct pf_udp_mapping	*udp_mapping;
	struct pfi_kkif		*kif;
	struct pfi_kkif		*orig_kif;	/* The real kif, even if we're a floating state (i.e. if == V_pfi_all). */
	struct pf_ksrc_node	*sns[PF_SN_MAX];/* source nodes */
	u_int64_t		 packets[2];
	u_int64_t		 bytes[2];
	u_int64_t		 creation;
	u_int64_t	 	 expire;
	u_int32_t		 pfsync_time;
	struct pf_rule_actions	 act;
	u_int16_t		 tag;
	u_int16_t		 if_index_in;
	u_int16_t		 if_index_out;
};

/*
 * 6 cache lines per struct, 10 structs per page.
 * Try to not grow the struct beyond that.
 */
_Static_assert(sizeof(struct pf_kstate) <= 384, "pf_kstate size crosses 384 bytes");

enum pf_test_status {
	PF_TEST_FAIL = -1,
	PF_TEST_OK,
	PF_TEST_QUICK
};

struct pf_test_ctx {
	enum pf_test_status	 test_status;
	struct pf_pdesc		*pd;
	struct pf_rule_actions	 act;
	uint8_t			 icmpcode;
	uint8_t			 icmptype;
	int			 icmp_dir;
	int			 state_icmp;
	int			 tag;
	int			 rewrite;
	u_short			 reason;
	struct pf_src_node	*sns[PF_SN_MAX];
	struct pf_krule		*nr;
	struct pf_krule		*tr;
	struct pf_krule		**rm;
	struct pf_krule		*a;
	struct pf_krule		**am;
	struct pf_kruleset	**rsm;
	struct pf_kruleset	*arsm;
	struct pf_kruleset	*aruleset;
	struct pf_state_key	*sk;
	struct pf_state_key	*nk;
	struct tcphdr		*th;
	struct pf_udp_mapping	*udp_mapping;
	struct pf_kpool		*nat_pool;
	uint16_t		 virtual_type;
	uint16_t		 virtual_id;
	int			 depth;
};

#define	PF_ANCHOR_STACK_MAX	32
#endif

/*
 * Unified state structures for pulling states out of the kernel
 * used by pfsync(4) and the pf(4) ioctl.
 */
struct pfsync_state_key {
	struct pf_addr	 addr[2];
	u_int16_t	 port[2];
};

struct pfsync_state_1301 {
	u_int64_t	 id;
	char		 ifname[IFNAMSIZ];
	struct pfsync_state_key	key[2];
	struct pf_state_peer_export src;
	struct pf_state_peer_export dst;
	struct pf_addr	 rt_addr;
	u_int32_t	 rule;
	u_int32_t	 anchor;
	u_int32_t	 nat_rule;
	u_int32_t	 creation;
	u_int32_t	 expire;
	u_int32_t	 packets[2][2];
	u_int32_t	 bytes[2][2];
	u_int32_t	 creatorid;
	sa_family_t	 af;
	u_int8_t	 proto;
	u_int8_t	 direction;
	u_int8_t	 __spare[2];
	u_int8_t	 log;
	u_int8_t	 state_flags;
	u_int8_t	 timeout;
	u_int8_t	 sync_flags;
	u_int8_t	 updates;	/* unused */
} __packed;

struct pfsync_state_1400 {
	/* The beginning of the struct is compatible with pfsync_state_1301 */
	u_int64_t	 id;
	char		 ifname[IFNAMSIZ];
	struct pfsync_state_key	key[2];
	struct pf_state_peer_export src;
	struct pf_state_peer_export dst;
	struct pf_addr	 rt_addr;
	u_int32_t	 rule;
	u_int32_t	 anchor;
	u_int32_t	 nat_rule;
	u_int32_t	 creation;
	u_int32_t	 expire;
	u_int32_t	 packets[2][2];
	u_int32_t	 bytes[2][2];
	u_int32_t	 creatorid;
	sa_family_t	 af;
	u_int8_t	 proto;
	u_int8_t	 direction;
	u_int16_t	 state_flags;
	u_int8_t	 log;
	u_int8_t	 __spare;
	u_int8_t	 timeout;
	u_int8_t	 sync_flags;
	u_int8_t	 updates;	/* unused */
	/* The rest is not */
	u_int16_t	 qid;
	u_int16_t	 pqid;
	u_int16_t	 dnpipe;
	u_int16_t	 dnrpipe;
	int32_t		 rtableid;
	u_int8_t	 min_ttl;
	u_int8_t	 set_tos;
	u_int16_t	 max_mss;
	u_int8_t	 set_prio[2];
	u_int8_t	 rt;
	char		 rt_ifname[IFNAMSIZ];
} __packed;

struct pfsync_state_1500 {
	/* The beginning of the struct is compatible with pfsync_state_1301 */
	u_int64_t	 id;
	char		 ifname[IFNAMSIZ];
	struct pfsync_state_key	key[2];
	struct pf_state_peer_export src;
	struct pf_state_peer_export dst;
	struct pf_addr	 rt_addr;
	u_int32_t	 rule;
	u_int32_t	 anchor;
	u_int32_t	 nat_rule;
	u_int32_t	 creation;
	u_int32_t	 expire;
	u_int32_t	 packets[2][2];
	u_int32_t	 bytes[2][2];
	u_int32_t	 creatorid;
	/* The rest is not, use the opportunity to fix alignment */
	char		 tagname[PF_TAG_NAME_SIZE];
	char		 rt_ifname[IFNAMSIZ];
	char		 orig_ifname[IFNAMSIZ];
	int32_t		 rtableid;
	u_int16_t	 state_flags;
	u_int16_t	 qid;
	u_int16_t	 pqid;
	u_int16_t	 dnpipe;
	u_int16_t	 dnrpipe;
	u_int16_t	 max_mss;
	sa_family_t	 wire_af;
	sa_family_t	 stack_af;
	sa_family_t	 rt_af;
	u_int8_t	 wire_proto;
	u_int8_t	 stack_proto;
	u_int8_t	 log;
	u_int8_t	 timeout;
	u_int8_t	 direction;
	u_int8_t	 rt;
	u_int8_t	 min_ttl;
	u_int8_t	 set_tos;
	u_int8_t	 set_prio[2];
	u_int8_t	 spare[3];	/* Improve struct alignment */
} __packed;

union pfsync_state_union {
	struct pfsync_state_1301 pfs_1301;
	struct pfsync_state_1400 pfs_1400;
	struct pfsync_state_1500 pfs_1500;
} __packed;

#ifdef _KERNEL
/* pfsync */
typedef int		pfsync_state_import_t(union pfsync_state_union *, int, int);
typedef	void		pfsync_insert_state_t(struct pf_kstate *);
typedef	void		pfsync_update_state_t(struct pf_kstate *);
typedef	void		pfsync_delete_state_t(struct pf_kstate *);
typedef void		pfsync_clear_states_t(u_int32_t, const char *);
typedef int		pfsync_defer_t(struct pf_kstate *, struct mbuf *);
typedef void		pfsync_detach_ifnet_t(struct ifnet *);
typedef void		pflow_export_state_t(const struct pf_kstate *);
typedef bool		pf_addr_filter_func_t(const sa_family_t, const struct pf_addr *);

VNET_DECLARE(pfsync_state_import_t *, pfsync_state_import_ptr);
#define V_pfsync_state_import_ptr	VNET(pfsync_state_import_ptr)
VNET_DECLARE(pfsync_insert_state_t *, pfsync_insert_state_ptr);
#define V_pfsync_insert_state_ptr	VNET(pfsync_insert_state_ptr)
VNET_DECLARE(pfsync_update_state_t *, pfsync_update_state_ptr);
#define V_pfsync_update_state_ptr	VNET(pfsync_update_state_ptr)
VNET_DECLARE(pfsync_delete_state_t *, pfsync_delete_state_ptr);
#define V_pfsync_delete_state_ptr	VNET(pfsync_delete_state_ptr)
VNET_DECLARE(pfsync_clear_states_t *, pfsync_clear_states_ptr);
#define V_pfsync_clear_states_ptr	VNET(pfsync_clear_states_ptr)
VNET_DECLARE(pfsync_defer_t *, pfsync_defer_ptr);
#define V_pfsync_defer_ptr		VNET(pfsync_defer_ptr)
VNET_DECLARE(pflow_export_state_t *,	pflow_export_state_ptr);
#define V_pflow_export_state_ptr	VNET(pflow_export_state_ptr)
extern pfsync_detach_ifnet_t	*pfsync_detach_ifnet_ptr;

void			pfsync_state_export(union pfsync_state_union *,
			    struct pf_kstate *, int);
void			pf_state_export(struct pf_state_export *,
			    struct pf_kstate *);

/* pflog */
struct pf_kruleset;
struct pf_pdesc;
typedef int pflog_packet_t(uint8_t, u_int8_t,
    struct pf_krule *, struct pf_krule *, struct pf_kruleset *,
    struct pf_pdesc *, int, struct pf_krule *);
extern pflog_packet_t		*pflog_packet_ptr;

#endif /* _KERNEL */

#define	PFSYNC_FLAG_SRCNODE	0x04
#define	PFSYNC_FLAG_NATSRCNODE	0x08

/* for copies to/from network byte order */
/* ioctl interface also uses network byte order */
void	 pf_state_peer_hton(const struct pf_state_peer *,
	    struct pf_state_peer_export *);
void	 pf_state_peer_ntoh(const struct pf_state_peer_export *,
	    struct pf_state_peer *);

#define pf_state_counter_hton(s,d) do {				\
	d[0] = htonl((s>>32)&0xffffffff);			\
	d[1] = htonl(s&0xffffffff);				\
} while (0)

#define pf_state_counter_from_pfsync(s)				\
	(((u_int64_t)(s[0])<<32) | (u_int64_t)(s[1]))

#define pf_state_counter_ntoh(s,d) do {				\
	d = ntohl(s[0]);					\
	d = d<<32;						\
	d += ntohl(s[1]);					\
} while (0)

TAILQ_HEAD(pf_krulequeue, pf_krule);

struct pf_kanchor;

struct pf_kruleset {
	struct {
		struct pf_krulequeue	 queues[2];
		struct {
			struct pf_krulequeue	*ptr;
			u_int32_t		 rcount;
			u_int32_t		 ticket;
			int			 open;
			struct pf_krule_global 	 *tree;
		}			 active, inactive;
	}			 rules[PF_RULESET_MAX];
	struct pf_kanchor	*anchor;
	u_int32_t		 tticket;
	int			 tables;
	int			 topen;
};

RB_HEAD(pf_kanchor_global, pf_kanchor);
RB_HEAD(pf_kanchor_node, pf_kanchor);
struct pf_kanchor {
	RB_ENTRY(pf_kanchor)	 entry_global;
	RB_ENTRY(pf_kanchor)	 entry_node;
	struct pf_kanchor	*parent;
	struct pf_kanchor_node	 children;
	char			 name[PF_ANCHOR_NAME_SIZE];
	char			 path[MAXPATHLEN];
	struct pf_kruleset	 ruleset;
	int			 refcnt;	/* anchor rules */
};
RB_PROTOTYPE(pf_kanchor_global, pf_kanchor, entry_global, pf_anchor_compare);
RB_PROTOTYPE(pf_kanchor_node, pf_kanchor, entry_node, pf_kanchor_compare);

#define PF_RESERVED_ANCHOR	"_pf"

#define PFR_TFLAG_PERSIST	0x00000001
#define PFR_TFLAG_CONST		0x00000002
#define PFR_TFLAG_ACTIVE	0x00000004
#define PFR_TFLAG_INACTIVE	0x00000008
#define PFR_TFLAG_REFERENCED	0x00000010
#define PFR_TFLAG_REFDANCHOR	0x00000020
#define PFR_TFLAG_COUNTERS	0x00000040
/* Adjust masks below when adding flags. */
#define PFR_TFLAG_USRMASK	(PFR_TFLAG_PERSIST	| \
				 PFR_TFLAG_CONST	| \
				 PFR_TFLAG_COUNTERS)
#define PFR_TFLAG_SETMASK	(PFR_TFLAG_ACTIVE	| \
				 PFR_TFLAG_INACTIVE	| \
				 PFR_TFLAG_REFERENCED	| \
				 PFR_TFLAG_REFDANCHOR)
#define PFR_TFLAG_ALLMASK	(PFR_TFLAG_PERSIST	| \
				 PFR_TFLAG_CONST	| \
				 PFR_TFLAG_ACTIVE	| \
				 PFR_TFLAG_INACTIVE	| \
				 PFR_TFLAG_REFERENCED	| \
				 PFR_TFLAG_REFDANCHOR	| \
				 PFR_TFLAG_COUNTERS)

struct pf_keth_anchor_stackframe;

struct pfr_table {
	char			 pfrt_anchor[MAXPATHLEN];
	char			 pfrt_name[PF_TABLE_NAME_SIZE];
	u_int32_t		 pfrt_flags;
	u_int8_t		 pfrt_fback;
};

enum { PFR_FB_NONE, PFR_FB_MATCH, PFR_FB_ADDED, PFR_FB_DELETED,
	PFR_FB_CHANGED, PFR_FB_CLEARED, PFR_FB_DUPLICATE,
	PFR_FB_NOTMATCH, PFR_FB_CONFLICT, PFR_FB_NOCOUNT, PFR_FB_MAX };

struct pfr_addr {
	union {
		struct in_addr	 _pfra_ip4addr;
		struct in6_addr	 _pfra_ip6addr;
	}		 pfra_u;
	u_int8_t	 pfra_af;
	u_int8_t	 pfra_net;
	u_int8_t	 pfra_not;
	u_int8_t	 pfra_fback;
};
#define	pfra_ip4addr	pfra_u._pfra_ip4addr
#define	pfra_ip6addr	pfra_u._pfra_ip6addr

enum { PFR_DIR_IN, PFR_DIR_OUT, PFR_DIR_MAX };
enum { PFR_OP_BLOCK, PFR_OP_PASS, PFR_OP_ADDR_MAX, PFR_OP_TABLE_MAX };
enum { PFR_TYPE_PACKETS, PFR_TYPE_BYTES, PFR_TYPE_MAX };
#define	PFR_NUM_COUNTERS	(PFR_DIR_MAX * PFR_OP_ADDR_MAX * PFR_TYPE_MAX)
#define PFR_OP_XPASS	PFR_OP_ADDR_MAX

struct pfr_astats {
	struct pfr_addr	 pfras_a;
	u_int64_t	 pfras_packets[PFR_DIR_MAX][PFR_OP_ADDR_MAX];
	u_int64_t	 pfras_bytes[PFR_DIR_MAX][PFR_OP_ADDR_MAX];
	time_t		 pfras_tzero;
};

enum { PFR_REFCNT_RULE, PFR_REFCNT_ANCHOR, PFR_REFCNT_MAX };

struct pfr_tstats {
	struct pfr_table pfrts_t;
	u_int64_t	 pfrts_packets[PFR_DIR_MAX][PFR_OP_TABLE_MAX];
	u_int64_t	 pfrts_bytes[PFR_DIR_MAX][PFR_OP_TABLE_MAX];
	u_int64_t	 pfrts_match;
	u_int64_t	 pfrts_nomatch;
	time_t		 pfrts_tzero;
	int		 pfrts_cnt;
	int		 pfrts_refcnt[PFR_REFCNT_MAX];
};

#ifdef _KERNEL

struct pfr_kstate_counter {
	counter_u64_t	pkc_pcpu;
	u_int64_t	pkc_zero;
};

static inline int
pfr_kstate_counter_init(struct pfr_kstate_counter *pfrc, int flags)
{

	pfrc->pkc_zero = 0;
	pfrc->pkc_pcpu = counter_u64_alloc(flags);
	if (pfrc->pkc_pcpu == NULL)
		return (ENOMEM);
	return (0);
}

static inline void
pfr_kstate_counter_deinit(struct pfr_kstate_counter *pfrc)
{

	counter_u64_free(pfrc->pkc_pcpu);
}

static inline u_int64_t
pfr_kstate_counter_fetch(struct pfr_kstate_counter *pfrc)
{
	u_int64_t c;

	c = counter_u64_fetch(pfrc->pkc_pcpu);
	c -= pfrc->pkc_zero;
	return (c);
}

static inline void
pfr_kstate_counter_zero(struct pfr_kstate_counter *pfrc)
{
	u_int64_t c;

	c = counter_u64_fetch(pfrc->pkc_pcpu);
	pfrc->pkc_zero = c;
}

static inline void
pfr_kstate_counter_add(struct pfr_kstate_counter *pfrc, int64_t n)
{

	counter_u64_add(pfrc->pkc_pcpu, n);
}

struct pfr_ktstats {
	struct pfr_table pfrts_t;
	struct pfr_kstate_counter	 pfrkts_packets[PFR_DIR_MAX][PFR_OP_TABLE_MAX];
	struct pfr_kstate_counter	 pfrkts_bytes[PFR_DIR_MAX][PFR_OP_TABLE_MAX];
	struct pfr_kstate_counter	 pfrkts_match;
	struct pfr_kstate_counter	 pfrkts_nomatch;
	time_t		 pfrkts_tzero;
	int		 pfrkts_cnt;
	int		 pfrkts_refcnt[PFR_REFCNT_MAX];
};

#endif /* _KERNEL */

#define	pfrts_name	pfrts_t.pfrt_name
#define pfrts_flags	pfrts_t.pfrt_flags

#ifndef _SOCKADDR_UNION_DEFINED
#define	_SOCKADDR_UNION_DEFINED
union sockaddr_union {
	struct sockaddr		sa;
	struct sockaddr_in	sin;
	struct sockaddr_in6	sin6;
};
#endif /* _SOCKADDR_UNION_DEFINED */

struct pfr_kcounters {
	counter_u64_t		 pfrkc_counters;
	time_t			 pfrkc_tzero;
};
#define	pfr_kentry_counter(kc, dir, op, t)		\
	((kc)->pfrkc_counters +				\
	    (dir) * PFR_OP_ADDR_MAX * PFR_TYPE_MAX + (op) * PFR_TYPE_MAX + (t))

#ifdef _KERNEL
SLIST_HEAD(pfr_kentryworkq, pfr_kentry);
struct pfr_kentry {
	struct radix_node	 pfrke_node[2];
	union sockaddr_union	 pfrke_sa;
	SLIST_ENTRY(pfr_kentry)	 pfrke_workq;
	struct pfr_kcounters	 pfrke_counters;
	u_int8_t		 pfrke_af;
	u_int8_t		 pfrke_net;
	u_int8_t		 pfrke_not;
	u_int8_t		 pfrke_mark;
};

SLIST_HEAD(pfr_ktableworkq, pfr_ktable);
RB_HEAD(pfr_ktablehead, pfr_ktable);
struct pfr_ktable {
	struct pfr_ktstats	 pfrkt_kts;
	RB_ENTRY(pfr_ktable)	 pfrkt_tree;
	SLIST_ENTRY(pfr_ktable)	 pfrkt_workq;
	struct radix_node_head	*pfrkt_ip4;
	struct radix_node_head	*pfrkt_ip6;
	struct pfr_ktable	*pfrkt_shadow;
	struct pfr_ktable	*pfrkt_root;
	struct pf_kruleset	*pfrkt_rs;
	long			 pfrkt_larg;
	int			 pfrkt_nflags;
};
#define pfrkt_t		pfrkt_kts.pfrts_t
#define pfrkt_name	pfrkt_t.pfrt_name
#define pfrkt_anchor	pfrkt_t.pfrt_anchor
#define pfrkt_ruleset	pfrkt_t.pfrt_ruleset
#define pfrkt_flags	pfrkt_t.pfrt_flags
#define pfrkt_cnt	pfrkt_kts.pfrkts_cnt
#define pfrkt_refcnt	pfrkt_kts.pfrkts_refcnt
#define pfrkt_packets	pfrkt_kts.pfrkts_packets
#define pfrkt_bytes	pfrkt_kts.pfrkts_bytes
#define pfrkt_match	pfrkt_kts.pfrkts_match
#define pfrkt_nomatch	pfrkt_kts.pfrkts_nomatch
#define pfrkt_tzero	pfrkt_kts.pfrkts_tzero
#endif

#ifdef _KERNEL
struct pfi_kkif {
	char				 pfik_name[IFNAMSIZ];
	union {
		RB_ENTRY(pfi_kkif)	 _pfik_tree;
		LIST_ENTRY(pfi_kkif)	 _pfik_list;
	} _pfik_glue;
#define	pfik_tree	_pfik_glue._pfik_tree
#define	pfik_list	_pfik_glue._pfik_list
	struct pf_counter_u64		 pfik_packets[2][2][2];
	struct pf_counter_u64		 pfik_bytes[2][2][2];
	time_t				 pfik_tzero;
	u_int				 pfik_flags;
	struct ifnet			*pfik_ifp;
	struct ifg_group		*pfik_group;
	u_int				 pfik_rulerefs;
	TAILQ_HEAD(, pfi_dynaddr)	 pfik_dynaddrs;
#ifdef PF_WANT_32_TO_64_COUNTER
	LIST_ENTRY(pfi_kkif)		 pfik_allkiflist;
#endif
};
#endif

#define	PFI_IFLAG_REFS		0x0001	/* has state references */
#define PFI_IFLAG_SKIP		0x0100	/* skip filtering on interface */
#define	PFI_IFLAG_ANY 		0x0200	/* match any non-loopback interface */

#ifdef _KERNEL
struct pf_sctp_multihome_job;
TAILQ_HEAD(pf_sctp_multihome_jobs, pf_sctp_multihome_job);

struct pf_pdesc {
	struct {
		int	 done;
		uid_t	 uid;
		gid_t	 gid;
	}		 lookup;
	u_int64_t	 tot_len;	/* Make Mickey money */
	union pf_headers {
		struct tcphdr		tcp;
		struct udphdr		udp;
		struct sctphdr		sctp;
		struct icmp		icmp;
#ifdef INET6
		struct icmp6_hdr	icmp6;
#endif /* INET6 */
		char any[0];
	} hdr;

	struct pf_addr	 nsaddr;	/* src address after NAT */
	struct pf_addr	 ndaddr;	/* dst address after NAT */

	struct pfi_kkif	*kif;		/* incomming interface */
	struct mbuf	*m;

	struct pf_addr	*src;		/* src address */
	struct pf_addr	*dst;		/* dst address */
	struct pf_addr	 osrc;
	struct pf_addr	 odst;
	u_int16_t	*pcksum;	/* proto cksum */
	u_int16_t	*sport;
	u_int16_t	*dport;
	u_int16_t	 osport;
	u_int16_t	 odport;
	u_int16_t	 nsport;	/* src port after NAT */
	u_int16_t	 ndport;	/* dst port after NAT */
	struct pf_mtag	*pf_mtag;
	struct pf_rule_actions	act;

	u_int32_t	 off;		/* protocol header offset */
	bool		 df;		/* IPv4 Don't fragment flag. */
	u_int32_t	 hdrlen;	/* protocol header length */
	u_int32_t	 p_len;		/* total length of protocol payload */
	u_int32_t	 extoff;	/* extentsion header offset */
	u_int32_t	 fragoff;	/* fragment header offset */
	u_int32_t	 jumbolen;	/* length from v6 jumbo header */
	u_int32_t	 badopts;	/* v4 options or v6 routing headers */
#define	PF_OPT_OTHER		0x0001
#define	PF_OPT_JUMBO		0x0002
#define	PF_OPT_ROUTER_ALERT	0x0004

	u_int16_t	*ip_sum;
	u_int16_t	 flags;		/* Let SCRUB trigger behavior in
					 * state code. Easier than tags */
#define PFDESC_TCP_NORM	0x0001		/* TCP shall be statefully scrubbed */
	u_int16_t	 virtual_proto;
#define PF_VPROTO_FRAGMENT	256
	sa_family_t	 af;
	sa_family_t	 naf;
	u_int8_t	 proto;
	u_int8_t	 tos;
	u_int8_t	 ttl;
	u_int8_t	 dir;		/* direction */
	u_int8_t	 sidx;		/* key index for source */
	u_int8_t	 didx;		/* key index for destination */
#define PFDESC_SCTP_INIT	0x0001
#define PFDESC_SCTP_INIT_ACK	0x0002
#define PFDESC_SCTP_COOKIE	0x0004
#define PFDESC_SCTP_COOKIE_ACK	0x0008
#define PFDESC_SCTP_ABORT	0x0010
#define PFDESC_SCTP_SHUTDOWN	0x0020
#define PFDESC_SCTP_SHUTDOWN_COMPLETE	0x0040
#define PFDESC_SCTP_DATA	0x0080
#define PFDESC_SCTP_ASCONF	0x0100
#define PFDESC_SCTP_HEARTBEAT	0x0200
#define PFDESC_SCTP_HEARTBEAT_ACK	0x0400
#define PFDESC_SCTP_OTHER	0x0800
#define PFDESC_SCTP_ADD_IP	0x1000
	u_int16_t	 sctp_flags;
	u_int32_t	 sctp_initiate_tag;
	u_int16_t	 sctp_dummy_sum;
	struct pf_krule	*related_rule;

	struct pf_sctp_multihome_jobs	sctp_multihome_jobs;
};

struct pf_sctp_multihome_job {
	TAILQ_ENTRY(pf_sctp_multihome_job)	next;
	struct pf_pdesc				 pd;
	struct pf_addr				 src;
	struct pf_addr				 dst;
	int					 op;
};

#endif

/* flags for RDR options */
#define PF_DPORT_RANGE	0x01		/* Dest port uses range */
#define PF_RPORT_RANGE	0x02		/* RDR'ed port uses range */

/* UDP state enumeration */
#define PFUDPS_NO_TRAFFIC	0
#define PFUDPS_SINGLE		1
#define PFUDPS_MULTIPLE		2

#define PFUDPS_NSTATES		3	/* number of state levels */

#define PFUDPS_NAMES { \
	"NO_TRAFFIC", \
	"SINGLE", \
	"MULTIPLE", \
	NULL \
}

/* Other protocol state enumeration */
#define PFOTHERS_NO_TRAFFIC	0
#define PFOTHERS_SINGLE		1
#define PFOTHERS_MULTIPLE	2

#define PFOTHERS_NSTATES	3	/* number of state levels */

#define PFOTHERS_NAMES { \
	"NO_TRAFFIC", \
	"SINGLE", \
	"MULTIPLE", \
	NULL \
}

#define ACTION_SET(a, x) \
	do { \
		if ((a) != NULL) \
			*(a) = (x); \
	} while (0)

#define REASON_SET(a, x) \
	do { \
		SDT_PROBE2(pf, , test, reason_set, x, __LINE__); \
		if ((a) != NULL) \
			*(a) = (x); \
		if (x < PFRES_MAX) \
			counter_u64_add(V_pf_status.counters[x], 1); \
	} while (0)

enum pf_syncookies_mode {
	PF_SYNCOOKIES_NEVER = 0,
	PF_SYNCOOKIES_ALWAYS = 1,
	PF_SYNCOOKIES_ADAPTIVE = 2,
	PF_SYNCOOKIES_MODE_MAX = PF_SYNCOOKIES_ADAPTIVE
};

#define	PF_SYNCOOKIES_HIWATPCT	25
#define	PF_SYNCOOKIES_LOWATPCT	(PF_SYNCOOKIES_HIWATPCT / 2)

#ifdef _KERNEL
struct pf_kstatus {
	counter_u64_t	counters[PFRES_MAX]; /* reason for passing/dropping */
	counter_u64_t	lcounters[KLCNT_MAX]; /* limit counters */
	struct pf_counter_u64	fcounters[FCNT_MAX]; /* state operation counters */
	counter_u64_t	scounters[SCNT_MAX]; /* src_node operation counters */
	uint32_t	states;
	uint32_t	src_nodes;
	uint32_t	running;
	uint32_t	since;
	uint32_t	debug;
	uint32_t	hostid;
	char		ifname[IFNAMSIZ];
	uint8_t		pf_chksum[PF_MD5_DIGEST_LENGTH];
	bool		keep_counters;
	enum pf_syncookies_mode	syncookies_mode;
	bool		syncookies_active;
	uint64_t	syncookies_inflight[2];
	uint32_t	states_halfopen;
	uint32_t	reass;
};
#endif

struct pf_divert {
	union {
		struct in_addr	ipv4;
		struct in6_addr	ipv6;
	}		addr;
	u_int16_t	port;
};

#define PFFRAG_FRENT_HIWAT	5000	/* Number of fragment entries */
#define PFR_KENTRY_HIWAT	200000	/* Number of table entries */

struct pf_fragment_tag {
	uint16_t	ft_hdrlen;	/* header length of reassembled pkt */
	uint16_t	ft_extoff;	/* last extension header offset or 0 */
	uint16_t	ft_maxlen;	/* maximum fragment payload length */
	uint32_t	ft_id;		/* fragment id */
};

/*
 * Limit the length of the fragment queue traversal.  Remember
 * search entry points based on the fragment offset.
 */
#define PF_FRAG_ENTRY_POINTS		16

/*
 * The number of entries in the fragment queue must be limited
 * to avoid DoS by linear searching.  Instead of a global limit,
 * use a limit per entry point.  For large packets these sum up.
 */
#define PF_FRAG_ENTRY_LIMIT		64

/*
 * ioctl parameter structures
 */

struct pfioc_pooladdr {
	u_int32_t		 action;
	u_int32_t		 ticket;
	u_int32_t		 nr;
	u_int32_t		 r_num;
	u_int8_t		 r_action;
	u_int8_t		 r_last;
	u_int8_t		 af;
	char			 anchor[MAXPATHLEN];
	struct pf_pooladdr	 addr;
};

struct pfioc_rule {
	u_int32_t	 action;
	u_int32_t	 ticket;
	u_int32_t	 pool_ticket;
	u_int32_t	 nr;
	char		 anchor[MAXPATHLEN];
	char		 anchor_call[MAXPATHLEN];
	struct pf_rule	 rule;
};

struct pfioc_natlook {
	struct pf_addr	 saddr;
	struct pf_addr	 daddr;
	struct pf_addr	 rsaddr;
	struct pf_addr	 rdaddr;
	u_int16_t	 sport;
	u_int16_t	 dport;
	u_int16_t	 rsport;
	u_int16_t	 rdport;
	sa_family_t	 af;
	u_int8_t	 proto;
	u_int8_t	 direction;
};

struct pfioc_state {
	struct pfsync_state_1301	state;
};

struct pfioc_src_node_kill {
	sa_family_t psnk_af;
	struct pf_rule_addr psnk_src;
	struct pf_rule_addr psnk_dst;
	u_int		    psnk_killed;
};

#ifdef _KERNEL
struct pf_kstate_kill {
	struct pf_state_cmp	psk_pfcmp;
	sa_family_t		psk_af;
	int			psk_proto;
	struct pf_rule_addr	psk_src;
	struct pf_rule_addr	psk_dst;
	struct pf_rule_addr	psk_rt_addr;
	char			psk_ifname[IFNAMSIZ];
	char			psk_label[PF_RULE_LABEL_SIZE];
	u_int			psk_killed;
	bool			psk_kill_match;
	bool			psk_nat;
};
#endif

struct pfioc_state_kill {
	struct pf_state_cmp	psk_pfcmp;
	sa_family_t		psk_af;
	int			psk_proto;
	struct pf_rule_addr	psk_src;
	struct pf_rule_addr	psk_dst;
	char			psk_ifname[IFNAMSIZ];
	char			psk_label[PF_RULE_LABEL_SIZE];
	u_int			psk_killed;
};

struct pfioc_states {
	int	ps_len;
	union {
		void				*ps_buf;
		struct pfsync_state_1301	*ps_states;
	};
};

struct pfioc_states_v2 {
	int		ps_len;
	uint64_t	ps_req_version;
	union {
		void			*ps_buf;
		struct pf_state_export	*ps_states;
	};
};

struct pfioc_src_nodes {
	int	psn_len;
	union {
		void		*psn_buf;
		struct pf_src_node	*psn_src_nodes;
	};
};

struct pfioc_if {
	char		 ifname[IFNAMSIZ];
};

struct pfioc_tm {
	int		 timeout;
	int		 seconds;
};

struct pfioc_limit {
	int		 index;
	unsigned	 limit;
};

struct pfioc_altq_v0 {
	u_int32_t	 action;
	u_int32_t	 ticket;
	u_int32_t	 nr;
	struct pf_altq_v0 altq;
};

struct pfioc_altq_v1 {
	u_int32_t	 action;
	u_int32_t	 ticket;
	u_int32_t	 nr;
	/*
	 * Placed here so code that only uses the above parameters can be
	 * written entirely in terms of the v0 or v1 type.
	 */
	u_int32_t	 version;
	struct pf_altq_v1 altq;
};

/*
 * Latest version of struct pfioc_altq_vX.  This must move in lock-step with
 * the latest version of struct pf_altq_vX as it has that struct as a
 * member.
 */
#define PFIOC_ALTQ_VERSION	PF_ALTQ_VERSION

struct pfioc_qstats_v0 {
	u_int32_t	 ticket;
	u_int32_t	 nr;
	void		*buf;
	int		 nbytes;
	u_int8_t	 scheduler;
};

struct pfioc_qstats_v1 {
	u_int32_t	 ticket;
	u_int32_t	 nr;
	void		*buf;
	int		 nbytes;
	u_int8_t	 scheduler;
	/*
	 * Placed here so code that only uses the above parameters can be
	 * written entirely in terms of the v0 or v1 type.
	 */
	u_int32_t	 version;  /* Requested version of stats struct */
};

/* Latest version of struct pfioc_qstats_vX */
#define PFIOC_QSTATS_VERSION	1

struct pfioc_ruleset {
	u_int32_t	 nr;
	char		 path[MAXPATHLEN];
	char		 name[PF_ANCHOR_NAME_SIZE];
};

#define PF_RULESET_ALTQ		(PF_RULESET_MAX)
#define PF_RULESET_TABLE	(PF_RULESET_MAX+1)
#define PF_RULESET_ETH		(PF_RULESET_MAX+2)
struct pfioc_trans {
	int		 size;	/* number of elements */
	int		 esize; /* size of each element in bytes */
	struct pfioc_trans_e {
		int		rs_num;
		char		anchor[MAXPATHLEN];
		u_int32_t	ticket;
	}		*array;
};

#define PFR_FLAG_ATOMIC		0x00000001	/* unused */
#define PFR_FLAG_DUMMY		0x00000002
#define PFR_FLAG_FEEDBACK	0x00000004
#define PFR_FLAG_CLSTATS	0x00000008
#define PFR_FLAG_ADDRSTOO	0x00000010
#define PFR_FLAG_REPLACE	0x00000020
#define PFR_FLAG_ALLRSETS	0x00000040
#define PFR_FLAG_ALLMASK	0x0000007F
#ifdef _KERNEL
#define PFR_FLAG_USERIOCTL	0x10000000
#endif

struct pfioc_table {
	struct pfr_table	 pfrio_table;
	void			*pfrio_buffer;
	int			 pfrio_esize;
	int			 pfrio_size;
	int			 pfrio_size2;
	int			 pfrio_nadd;
	int			 pfrio_ndel;
	int			 pfrio_nchange;
	int			 pfrio_flags;
	u_int32_t		 pfrio_ticket;
};
#define	pfrio_exists	pfrio_nadd
#define	pfrio_nzero	pfrio_nadd
#define	pfrio_nmatch	pfrio_nadd
#define pfrio_naddr	pfrio_size2
#define pfrio_setflag	pfrio_size2
#define pfrio_clrflag	pfrio_nadd

struct pfioc_iface {
	char	 pfiio_name[IFNAMSIZ];
	void	*pfiio_buffer;
	int	 pfiio_esize;
	int	 pfiio_size;
	int	 pfiio_nzero;
	int	 pfiio_flags;
};

/*
 * ioctl operations
 */

#define DIOCSTART	_IO  ('D',  1)
#define DIOCSTOP	_IO  ('D',  2)
#define DIOCADDRULE	_IOWR('D',  4, struct pfioc_rule)
#define DIOCADDRULENV	_IOWR('D',  4, struct pfioc_nv)
#define DIOCGETRULES	_IOWR('D',  6, struct pfioc_rule)
#define DIOCGETRULENV	_IOWR('D',  7, struct pfioc_nv)
#define DIOCCLRSTATESNV	_IOWR('D', 18, struct pfioc_nv)
#define DIOCGETSTATE	_IOWR('D', 19, struct pfioc_state)
#define DIOCGETSTATENV	_IOWR('D', 19, struct pfioc_nv)
#define DIOCSETSTATUSIF _IOWR('D', 20, struct pfioc_if)
#define DIOCGETSTATUSNV	_IOWR('D', 21, struct pfioc_nv)
#define DIOCCLRSTATUS	_IO  ('D', 22)
#define DIOCNATLOOK	_IOWR('D', 23, struct pfioc_natlook)
#define DIOCSETDEBUG	_IOWR('D', 24, u_int32_t)
#ifdef COMPAT_FREEBSD14
#define DIOCGETSTATES	_IOWR('D', 25, struct pfioc_states)
#endif
#define DIOCCHANGERULE	_IOWR('D', 26, struct pfioc_rule)
#define DIOCSETTIMEOUT	_IOWR('D', 29, struct pfioc_tm)
#define DIOCGETTIMEOUT	_IOWR('D', 30, struct pfioc_tm)
#define DIOCADDSTATE	_IOWR('D', 37, struct pfioc_state)
#define DIOCCLRRULECTRS	_IO  ('D', 38)
#define DIOCGETLIMIT	_IOWR('D', 39, struct pfioc_limit)
#define DIOCSETLIMIT	_IOWR('D', 40, struct pfioc_limit)
#define DIOCKILLSTATESNV	_IOWR('D', 41, struct pfioc_nv)
#define DIOCSTARTALTQ	_IO  ('D', 42)
#define DIOCSTOPALTQ	_IO  ('D', 43)
#define DIOCADDALTQV0	_IOWR('D', 45, struct pfioc_altq_v0)
#define DIOCADDALTQV1	_IOWR('D', 45, struct pfioc_altq_v1)
#define DIOCGETALTQSV0	_IOWR('D', 47, struct pfioc_altq_v0)
#define DIOCGETALTQSV1	_IOWR('D', 47, struct pfioc_altq_v1)
#define DIOCGETALTQV0	_IOWR('D', 48, struct pfioc_altq_v0)
#define DIOCGETALTQV1	_IOWR('D', 48, struct pfioc_altq_v1)
#define DIOCCHANGEALTQV0 _IOWR('D', 49, struct pfioc_altq_v0)
#define DIOCCHANGEALTQV1 _IOWR('D', 49, struct pfioc_altq_v1)
#define DIOCGETQSTATSV0	_IOWR('D', 50, struct pfioc_qstats_v0)
#define DIOCGETQSTATSV1	_IOWR('D', 50, struct pfioc_qstats_v1)
#define DIOCBEGINADDRS	_IOWR('D', 51, struct pfioc_pooladdr)
#define DIOCADDADDR	_IOWR('D', 52, struct pfioc_pooladdr)
#define DIOCGETADDRS	_IOWR('D', 53, struct pfioc_pooladdr)
#define DIOCGETADDR	_IOWR('D', 54, struct pfioc_pooladdr)
#define DIOCCHANGEADDR	_IOWR('D', 55, struct pfioc_pooladdr)
#define	DIOCGETRULESETS	_IOWR('D', 58, struct pfioc_ruleset)
#define	DIOCGETRULESET	_IOWR('D', 59, struct pfioc_ruleset)
#define	DIOCRCLRTABLES	_IOWR('D', 60, struct pfioc_table)
#define	DIOCRADDTABLES	_IOWR('D', 61, struct pfioc_table)
#define	DIOCRDELTABLES	_IOWR('D', 62, struct pfioc_table)
#define	DIOCRGETTABLES	_IOWR('D', 63, struct pfioc_table)
#define	DIOCRGETTSTATS	_IOWR('D', 64, struct pfioc_table)
#define DIOCRCLRTSTATS	_IOWR('D', 65, struct pfioc_table)
#define	DIOCRCLRADDRS	_IOWR('D', 66, struct pfioc_table)
#define	DIOCRADDADDRS	_IOWR('D', 67, struct pfioc_table)
#define	DIOCRDELADDRS	_IOWR('D', 68, struct pfioc_table)
#define	DIOCRSETADDRS	_IOWR('D', 69, struct pfioc_table)
#define	DIOCRGETADDRS	_IOWR('D', 70, struct pfioc_table)
#define	DIOCRGETASTATS	_IOWR('D', 71, struct pfioc_table)
#define	DIOCRCLRASTATS	_IOWR('D', 72, struct pfioc_table)
#define	DIOCRTSTADDRS	_IOWR('D', 73, struct pfioc_table)
#define	DIOCRSETTFLAGS	_IOWR('D', 74, struct pfioc_table)
#define	DIOCRINADEFINE	_IOWR('D', 77, struct pfioc_table)
#define	DIOCOSFPFLUSH	_IO('D', 78)
#define	DIOCOSFPADD	_IOWR('D', 79, struct pf_osfp_ioctl)
#define	DIOCOSFPGET	_IOWR('D', 80, struct pf_osfp_ioctl)
#define	DIOCXBEGIN	_IOWR('D', 81, struct pfioc_trans)
#define	DIOCXCOMMIT	_IOWR('D', 82, struct pfioc_trans)
#define	DIOCXROLLBACK	_IOWR('D', 83, struct pfioc_trans)
#define	DIOCGETSRCNODES	_IOWR('D', 84, struct pfioc_src_nodes)
#define	DIOCCLRSRCNODES	_IO('D', 85)
#define	DIOCSETHOSTID	_IOWR('D', 86, u_int32_t)
#define	DIOCIGETIFACES	_IOWR('D', 87, struct pfioc_iface)
#define	DIOCSETIFFLAG	_IOWR('D', 89, struct pfioc_iface)
#define	DIOCCLRIFFLAG	_IOWR('D', 90, struct pfioc_iface)
#define	DIOCKILLSRCNODES	_IOWR('D', 91, struct pfioc_src_node_kill)
#define	DIOCGIFSPEEDV0	_IOWR('D', 92, struct pf_ifspeed_v0)
#define	DIOCGIFSPEEDV1	_IOWR('D', 92, struct pf_ifspeed_v1)
#ifdef COMPAT_FREEBSD14
#define DIOCGETSTATESV2	_IOWR('D', 93, struct pfioc_states_v2)
#endif
#define	DIOCGETSYNCOOKIES	_IOWR('D', 94, struct pfioc_nv)
#define	DIOCSETSYNCOOKIES	_IOWR('D', 95, struct pfioc_nv)
#define	DIOCKEEPCOUNTERS	_IOWR('D', 96, struct pfioc_nv)
#define	DIOCKEEPCOUNTERS_FREEBSD13	_IOWR('D', 92, struct pfioc_nv)
#define	DIOCADDETHRULE		_IOWR('D', 97, struct pfioc_nv)
#define	DIOCGETETHRULE		_IOWR('D', 98, struct pfioc_nv)
#define	DIOCGETETHRULES		_IOWR('D', 99, struct pfioc_nv)
#define	DIOCGETETHRULESETS	_IOWR('D', 100, struct pfioc_nv)
#define	DIOCGETETHRULESET	_IOWR('D', 101, struct pfioc_nv)
#define DIOCSETREASS		_IOWR('D', 102, u_int32_t)

struct pf_ifspeed_v0 {
	char			ifname[IFNAMSIZ];
	u_int32_t		baudrate;
};

struct pf_ifspeed_v1 {
	char			ifname[IFNAMSIZ];
	u_int32_t		baudrate32;
	/* layout identical to struct pf_ifspeed_v0 up to this point */
	u_int64_t		baudrate;
};

/* Latest version of struct pf_ifspeed_vX */
#define PF_IFSPEED_VERSION	1

/*
 * Compatibility and convenience macros
 */
#ifndef _KERNEL
#ifdef PFIOC_USE_LATEST
/*
 * Maintaining in-tree consumers of the ioctl interface is easier when that
 * code can be written in terms old names that refer to the latest interface
 * version as that reduces the required changes in the consumers to those
 * that are functionally necessary to accommodate a new interface version.
 */
#define	pfioc_altq	__CONCAT(pfioc_altq_v, PFIOC_ALTQ_VERSION)
#define	pfioc_qstats	__CONCAT(pfioc_qstats_v, PFIOC_QSTATS_VERSION)
#define	pf_ifspeed	__CONCAT(pf_ifspeed_v, PF_IFSPEED_VERSION)

#define	DIOCADDALTQ	__CONCAT(DIOCADDALTQV, PFIOC_ALTQ_VERSION)
#define	DIOCGETALTQS	__CONCAT(DIOCGETALTQSV, PFIOC_ALTQ_VERSION)
#define	DIOCGETALTQ	__CONCAT(DIOCGETALTQV, PFIOC_ALTQ_VERSION)
#define	DIOCCHANGEALTQ	__CONCAT(DIOCCHANGEALTQV, PFIOC_ALTQ_VERSION)
#define	DIOCGETQSTATS	__CONCAT(DIOCGETQSTATSV, PFIOC_QSTATS_VERSION)
#define	DIOCGIFSPEED	__CONCAT(DIOCGIFSPEEDV, PF_IFSPEED_VERSION)
#else
/*
 * When building out-of-tree code that is written for the old interface,
 * such as may exist in ports for example, resolve the old struct tags and
 * ioctl command names to the v0 versions.
 */
#define	pfioc_altq	__CONCAT(pfioc_altq_v, 0)
#define	pfioc_qstats	__CONCAT(pfioc_qstats_v, 0)
#define	pf_ifspeed	__CONCAT(pf_ifspeed_v, 0)

#define	DIOCADDALTQ	__CONCAT(DIOCADDALTQV, 0)
#define	DIOCGETALTQS	__CONCAT(DIOCGETALTQSV, 0)
#define	DIOCGETALTQ	__CONCAT(DIOCGETALTQV, 0)
#define	DIOCCHANGEALTQ	__CONCAT(DIOCCHANGEALTQV, 0)
#define	DIOCGETQSTATS	__CONCAT(DIOCGETQSTATSV, 0)
#define	DIOCGIFSPEED	__CONCAT(DIOCGIFSPEEDV, 0)
#endif /* PFIOC_USE_LATEST */
#endif /* _KERNEL */

#ifdef _KERNEL
LIST_HEAD(pf_ksrc_node_list, pf_ksrc_node);
struct pf_srchash {
	struct pf_ksrc_node_list		nodes;
	struct mtx			lock;
};

struct pf_keyhash {
	LIST_HEAD(, pf_state_key)	keys;
	struct mtx			lock;
};

struct pf_idhash {
	LIST_HEAD(, pf_kstate)		states;
	struct mtx			lock;
};

struct pf_udpendpointhash {
	LIST_HEAD(, pf_udp_endpoint)	endpoints;
	/* refcont is synchronized on the source endpoint's row lock */
	struct mtx			lock;
};

extern u_long		pf_ioctl_maxcount;
VNET_DECLARE(u_long, pf_hashmask);
#define V_pf_hashmask	VNET(pf_hashmask)
VNET_DECLARE(u_long, pf_srchashmask);
#define V_pf_srchashmask	VNET(pf_srchashmask)
VNET_DECLARE(u_long, pf_udpendpointhashmask);
#define V_pf_udpendpointhashmask	VNET(pf_udpendpointhashmask)
#define	PF_HASHSIZ	(131072)
#define	PF_SRCHASHSIZ	(PF_HASHSIZ/4)
#define	PF_UDPENDHASHSIZ	(PF_HASHSIZ/4)
VNET_DECLARE(struct pf_keyhash *, pf_keyhash);
VNET_DECLARE(struct pf_idhash *, pf_idhash);
VNET_DECLARE(struct pf_udpendpointhash *, pf_udpendpointhash);
#define V_pf_keyhash	VNET(pf_keyhash)
#define	V_pf_idhash	VNET(pf_idhash)
#define	V_pf_udpendpointhash	VNET(pf_udpendpointhash)
VNET_DECLARE(struct pf_srchash *, pf_srchash);
#define	V_pf_srchash	VNET(pf_srchash)

#define	PF_IDHASHID(id)	(be64toh(id) % (V_pf_hashmask + 1))
#define	PF_IDHASH(s)	PF_IDHASHID((s)->id)

VNET_DECLARE(void *, pf_swi_cookie);
#define V_pf_swi_cookie	VNET(pf_swi_cookie)
VNET_DECLARE(struct intr_event *, pf_swi_ie);
#define	V_pf_swi_ie	VNET(pf_swi_ie)

VNET_DECLARE(struct unrhdr64, pf_stateid);
#define	V_pf_stateid	VNET(pf_stateid)

TAILQ_HEAD(pf_altqqueue, pf_altq);
VNET_DECLARE(struct pf_altqqueue,	 pf_altqs[4]);
#define	V_pf_altqs			 VNET(pf_altqs)
VNET_DECLARE(struct pf_kpalist,		 pf_pabuf[3]);
#define	V_pf_pabuf			 VNET(pf_pabuf)

VNET_DECLARE(u_int32_t,			 ticket_altqs_active);
#define	V_ticket_altqs_active		 VNET(ticket_altqs_active)
VNET_DECLARE(u_int32_t,			 ticket_altqs_inactive);
#define	V_ticket_altqs_inactive		 VNET(ticket_altqs_inactive)
VNET_DECLARE(int,			 altqs_inactive_open);
#define	V_altqs_inactive_open		 VNET(altqs_inactive_open)
VNET_DECLARE(u_int32_t,			 ticket_pabuf);
#define	V_ticket_pabuf			 VNET(ticket_pabuf)
VNET_DECLARE(struct pf_altqqueue *,	 pf_altqs_active);
#define	V_pf_altqs_active		 VNET(pf_altqs_active)
VNET_DECLARE(struct pf_altqqueue *,	 pf_altq_ifs_active);
#define	V_pf_altq_ifs_active		 VNET(pf_altq_ifs_active)
VNET_DECLARE(struct pf_altqqueue *,	 pf_altqs_inactive);
#define	V_pf_altqs_inactive		 VNET(pf_altqs_inactive)
VNET_DECLARE(struct pf_altqqueue *,	 pf_altq_ifs_inactive);
#define	V_pf_altq_ifs_inactive		 VNET(pf_altq_ifs_inactive)

VNET_DECLARE(struct pf_krulequeue, pf_unlinked_rules);
#define	V_pf_unlinked_rules	VNET(pf_unlinked_rules)

#ifdef PF_WANT_32_TO_64_COUNTER
LIST_HEAD(allkiflist_head, pfi_kkif);
VNET_DECLARE(struct allkiflist_head, pf_allkiflist);
#define V_pf_allkiflist     VNET(pf_allkiflist)
VNET_DECLARE(size_t, pf_allkifcount);
#define V_pf_allkifcount     VNET(pf_allkifcount)
VNET_DECLARE(struct pfi_kkif *, pf_kifmarker);
#define V_pf_kifmarker     VNET(pf_kifmarker)

LIST_HEAD(allrulelist_head, pf_krule);
VNET_DECLARE(struct allrulelist_head, pf_allrulelist);
#define V_pf_allrulelist     VNET(pf_allrulelist)
VNET_DECLARE(size_t, pf_allrulecount);
#define V_pf_allrulecount     VNET(pf_allrulecount)
VNET_DECLARE(struct pf_krule *, pf_rulemarker);
#define V_pf_rulemarker     VNET(pf_rulemarker)
#endif

int				 pf_start(void);
int				 pf_stop(void);
void				 pf_initialize(void);
void				 pf_mtag_initialize(void);
void				 pf_mtag_cleanup(void);
void				 pf_cleanup(void);

struct pf_mtag			*pf_get_mtag(struct mbuf *);

extern void			 pf_calc_skip_steps(struct pf_krulequeue *);
#ifdef ALTQ
extern	void			 pf_altq_ifnet_event(struct ifnet *, int);
#endif
VNET_DECLARE(uma_zone_t,	 pf_state_z);
#define	V_pf_state_z		 VNET(pf_state_z)
VNET_DECLARE(uma_zone_t,	 pf_state_key_z);
#define	V_pf_state_key_z	 VNET(pf_state_key_z)
VNET_DECLARE(uma_zone_t,	 pf_udp_mapping_z);
#define	V_pf_udp_mapping_z	 VNET(pf_udp_mapping_z)
VNET_DECLARE(uma_zone_t,	 pf_state_scrub_z);
#define	V_pf_state_scrub_z	 VNET(pf_state_scrub_z)
VNET_DECLARE(uma_zone_t,	 pf_anchor_z);
#define	V_pf_anchor_z		 VNET(pf_anchor_z)
VNET_DECLARE(uma_zone_t,	 pf_eth_anchor_z);
#define	V_pf_eth_anchor_z	 VNET(pf_eth_anchor_z)

extern void			 pf_purge_thread(void *);
extern void			 pf_unload_vnet_purge(void);
extern void			 pf_intr(void *);
extern void			 pf_purge_expired_src_nodes(void);

extern int			 pf_remove_state(struct pf_kstate *);
extern int			 pf_state_insert(struct pfi_kkif *,
				    struct pfi_kkif *,
				    struct pf_state_key *,
				    struct pf_state_key *,
				    struct pf_kstate *);
extern struct pf_kstate		*pf_alloc_state(int);
extern void			 pf_free_state(struct pf_kstate *);
extern void			 pf_killstates(struct pf_kstate_kill *,
				    unsigned int *);
extern unsigned int		 pf_clear_states(const struct pf_kstate_kill *);

static __inline void
pf_ref_state(struct pf_kstate *s)
{

	refcount_acquire(&s->refs);
}

static __inline int
pf_release_state(struct pf_kstate *s)
{

	if (refcount_release(&s->refs)) {
		pf_free_state(s);
		return (1);
	} else
		return (0);
}

static __inline int
pf_release_staten(struct pf_kstate *s, u_int n)
{

	if (refcount_releasen(&s->refs, n)) {
		pf_free_state(s);
		return (1);
	} else
		return (0);
}

static __inline uint64_t
pf_get_uptime(void)
{
	struct timeval t;
	microuptime(&t);
	return ((t.tv_sec * 1000) + (t.tv_usec / 1000));
}

static __inline uint64_t
pf_get_time(void)
{
	struct timeval t;
	microtime(&t);
	return ((t.tv_sec * 1000) + (t.tv_usec / 1000));
}

extern struct pf_kstate		*pf_find_state_byid(uint64_t, uint32_t);
extern struct pf_kstate		*pf_find_state_all(
				    const struct pf_state_key_cmp *,
				    u_int, int *);
extern bool			pf_find_state_all_exists(
				    const struct pf_state_key_cmp *,
				    u_int);
extern struct pf_udp_mapping	*pf_udp_mapping_find(struct pf_udp_endpoint_cmp
				    *endpoint);
extern struct pf_udp_mapping	*pf_udp_mapping_create(sa_family_t af,
				    struct pf_addr *src_addr, uint16_t src_port,
				    struct pf_addr *nat_addr, uint16_t nat_port);
extern int			 pf_udp_mapping_insert(struct pf_udp_mapping
				    *mapping);
extern void			 pf_udp_mapping_release(struct pf_udp_mapping
				    *mapping);
uint32_t			 pf_hashsrc(struct pf_addr *, sa_family_t);
extern bool			 pf_src_node_exists(struct pf_ksrc_node **,
				    struct pf_srchash *);
extern struct pf_ksrc_node	*pf_find_src_node(struct pf_addr *,
				    struct pf_krule *, sa_family_t,
				    struct pf_srchash **, pf_sn_types_t, bool);
extern void			 pf_unlink_src_node(struct pf_ksrc_node *);
extern u_int			 pf_free_src_nodes(struct pf_ksrc_node_list *);
extern void			 pf_print_state(struct pf_kstate *);
extern void			 pf_print_flags(uint16_t);
extern int			 pf_addr_wrap_neq(struct pf_addr_wrap *,
				    struct pf_addr_wrap *);
extern u_int16_t		 pf_cksum_fixup(u_int16_t, u_int16_t, u_int16_t,
				    u_int8_t);
extern u_int16_t		 pf_proto_cksum_fixup(struct mbuf *, u_int16_t,
				    u_int16_t, u_int16_t, u_int8_t);

VNET_DECLARE(struct ifnet *,		 sync_ifp);
#define	V_sync_ifp		 	 VNET(sync_ifp);
VNET_DECLARE(struct pf_krule,		 pf_default_rule);
#define	V_pf_default_rule		  VNET(pf_default_rule)
extern void			 pf_addrcpy(struct pf_addr *, const struct pf_addr *,
				    sa_family_t);
void				pf_free_rule(struct pf_krule *);

int	pf_test_eth(int, int, struct ifnet *, struct mbuf **, struct inpcb *);
int	pf_scan_sctp(struct pf_pdesc *);
#if defined(INET) || defined(INET6)
int	pf_test(sa_family_t, int, int, struct ifnet *, struct mbuf **, struct inpcb *,
	    struct pf_rule_actions *);
#endif
#ifdef INET
int	pf_normalize_ip(u_short *, struct pf_pdesc *);
#endif /* INET */

void	pf_poolmask(struct pf_addr *, struct pf_addr*,
	    struct pf_addr *, struct pf_addr *, sa_family_t);
void	pf_addr_inc(struct pf_addr *, sa_family_t);
#ifdef INET6
int	pf_normalize_ip6(int, u_short *, struct pf_pdesc *);
int	pf_max_frag_size(struct mbuf *);
int	pf_refragment6(struct ifnet *, struct mbuf **, struct m_tag *,
	    struct ifnet *, bool);
#endif /* INET6 */

int	pf_multihome_scan_init(int, int, struct pf_pdesc *);
int	pf_multihome_scan_asconf(int, int, struct pf_pdesc *);

u_int32_t	pf_new_isn(struct pf_kstate *);
void   *pf_pull_hdr(const struct mbuf *, int, void *, int, u_short *, u_short *,
	    sa_family_t);
void	pf_change_a(void *, u_int16_t *, u_int32_t, u_int8_t);
void	pf_change_proto_a(struct mbuf *, void *, u_int16_t *, u_int32_t,
	    u_int8_t);
void	pf_change_tcp_a(struct mbuf *, void *, u_int16_t *, u_int32_t);
int	pf_patch_16(struct pf_pdesc *, void *, u_int16_t, bool);
int	pf_patch_32(struct pf_pdesc *, void *, u_int32_t, bool);
void	pf_send_deferred_syn(struct pf_kstate *);
int	pf_match_addr(u_int8_t, const struct pf_addr *,
	    const struct pf_addr *, const struct pf_addr *, sa_family_t);
int	pf_match_addr_range(const struct pf_addr *, const struct pf_addr *,
	    const struct pf_addr *, sa_family_t);
int	pf_match_port(u_int8_t, u_int16_t, u_int16_t, u_int16_t);

void	pf_normalize_init(void);
void	pf_normalize_cleanup(void);
int	pf_normalize_tcp(struct pf_pdesc *);
void	pf_normalize_tcp_cleanup(struct pf_kstate *);
int	pf_normalize_tcp_init(struct pf_pdesc *,
	    struct tcphdr *, struct pf_state_peer *);
int	pf_normalize_tcp_stateful(struct pf_pdesc *,
	    u_short *, struct tcphdr *, struct pf_kstate *,
	    struct pf_state_peer *, struct pf_state_peer *, int *);
int	pf_normalize_sctp_init(struct pf_pdesc *,
	    struct pf_state_peer *, struct pf_state_peer *);
int	pf_normalize_sctp(struct pf_pdesc *);
u_int32_t
	pf_state_expires(const struct pf_kstate *);
void	pf_purge_expired_fragments(void);
void	pf_purge_fragments(uint32_t);
int	pf_routable(struct pf_addr *addr, sa_family_t af, struct pfi_kkif *,
	    int);
int	pf_socket_lookup(struct pf_pdesc *);
struct pf_state_key *pf_alloc_state_key(int);
int	pf_translate(struct pf_pdesc *, struct pf_addr *, u_int16_t,
	    struct pf_addr *, u_int16_t, u_int16_t, int);
int	pf_translate_af(struct pf_pdesc *);
bool	pf_init_threshold(struct pf_kthreshold *, uint32_t, uint32_t);
uint16_t	pf_tagname2tag(const char *);
#ifdef ALTQ
uint16_t	pf_qname2qid(const char *, bool);
#endif /* ALTQ */

void	pfr_initialize(void);
void	pfr_cleanup(void);
int	pfr_match_addr(struct pfr_ktable *, struct pf_addr *, sa_family_t);
void	pfr_update_stats(struct pfr_ktable *, struct pf_addr *, sa_family_t,
	    u_int64_t, int, int, int);
int	pfr_pool_get(struct pfr_ktable *, int *, struct pf_addr *, sa_family_t,
	    pf_addr_filter_func_t, bool);
void	pfr_dynaddr_update(struct pfr_ktable *, struct pfi_dynaddr *);
struct pfr_ktable *
	pfr_attach_table(struct pf_kruleset *, char *);
struct pfr_ktable *
	pfr_eth_attach_table(struct pf_keth_ruleset *, char *);
void	pfr_detach_table(struct pfr_ktable *);
int	pfr_clr_tables(struct pfr_table *, int *, int);
int	pfr_add_tables(struct pfr_table *, int, int *, int);
int	pfr_del_tables(struct pfr_table *, int, int *, int);
int	pfr_table_count(struct pfr_table *, int);
int	pfr_get_tables(struct pfr_table *, struct pfr_table *, int *, int);
int	pfr_get_tstats(struct pfr_table *, struct pfr_tstats *, int *, int);
int	pfr_clr_tstats(struct pfr_table *, int, int *, int);
int	pfr_set_tflags(struct pfr_table *, int, int, int, int *, int *, int);
int	pfr_clr_addrs(struct pfr_table *, int *, int);
int	pfr_insert_kentry(struct pfr_ktable *, struct pfr_addr *, time_t);
int	pfr_add_addrs(struct pfr_table *, struct pfr_addr *, int, int *,
	    int);
int	pfr_del_addrs(struct pfr_table *, struct pfr_addr *, int, int *,
	    int);
int	pfr_set_addrs(struct pfr_table *, struct pfr_addr *, int, int *,
	    int *, int *, int *, int, u_int32_t);
int	pfr_get_addrs(struct pfr_table *, struct pfr_addr *, int *, int);
int	pfr_get_astats(struct pfr_table *, struct pfr_astats *, int *, int);
int	pfr_clr_astats(struct pfr_table *, struct pfr_addr *, int, int *,
	    int);
int	pfr_tst_addrs(struct pfr_table *, struct pfr_addr *, int, int *,
	    int);
int	pfr_ina_begin(struct pfr_table *, u_int32_t *, int *, int);
int	pfr_ina_rollback(struct pfr_table *, u_int32_t, int *, int);
int	pfr_ina_commit(struct pfr_table *, u_int32_t, int *, int *, int);
int	pfr_ina_define(struct pfr_table *, struct pfr_addr *, int, int *,
	    int *, u_int32_t, int);
struct pfr_ktable
	*pfr_ktable_select_active(struct pfr_ktable *);

MALLOC_DECLARE(PFI_MTYPE);
VNET_DECLARE(struct pfi_kkif *,		 pfi_all);
#define	V_pfi_all	 		 VNET(pfi_all)

void		 pfi_initialize(void);
void		 pfi_initialize_vnet(void);
void		 pfi_cleanup(void);
void		 pfi_cleanup_vnet(void);
void		 pfi_kkif_ref(struct pfi_kkif *);
void		 pfi_kkif_unref(struct pfi_kkif *);
struct pfi_kkif	*pfi_kkif_find(const char *);
struct pfi_kkif	*pfi_kkif_attach(struct pfi_kkif *, const char *);
int		 pfi_kkif_match(struct pfi_kkif *, struct pfi_kkif *);
void		 pfi_kkif_purge(void);
int		 pfi_match_addr(struct pfi_dynaddr *, struct pf_addr *,
		    sa_family_t);
int		 pfi_dynaddr_setup(struct pf_addr_wrap *, sa_family_t);
void		 pfi_dynaddr_remove(struct pfi_dynaddr *);
void		 pfi_dynaddr_copyout(struct pf_addr_wrap *);
void		 pfi_update_status(const char *, struct pf_status *);
void		 pfi_get_ifaces(const char *, struct pfi_kif *, int *);
int		 pfi_set_flags(const char *, int);
int		 pfi_clear_flags(const char *, int);

int		 pf_match_tag(struct mbuf *, struct pf_krule *, int *, int);
int		 pf_tag_packet(struct pf_pdesc *, int);
int		 pf_addr_cmp(struct pf_addr *, struct pf_addr *,
		    sa_family_t);

uint8_t*	 pf_find_tcpopt(u_int8_t *, u_int8_t *, size_t,
		    u_int8_t, u_int8_t);
u_int16_t	 pf_get_mss(struct pf_pdesc *);
u_int8_t	 pf_get_wscale(struct pf_pdesc *);
struct mbuf 	*pf_build_tcp(const struct pf_krule *, sa_family_t,
		    const struct pf_addr *, const struct pf_addr *,
		    u_int16_t, u_int16_t, u_int32_t, u_int32_t,
		    u_int8_t, u_int16_t, u_int16_t, u_int8_t, int,
		    u_int16_t, u_int16_t, u_int, int);
void		 pf_send_tcp(const struct pf_krule *, sa_family_t,
			    const struct pf_addr *, const struct pf_addr *,
			    u_int16_t, u_int16_t, u_int32_t, u_int32_t,
			    u_int8_t, u_int16_t, u_int16_t, u_int8_t, int,
			    u_int16_t, u_int16_t, int);

void			 pf_syncookies_init(void);
void			 pf_syncookies_cleanup(void);
int			 pf_get_syncookies(struct pfioc_nv *);
int			 pf_set_syncookies(struct pfioc_nv *);
int			 pf_synflood_check(struct pf_pdesc *);
void			 pf_syncookie_send(struct pf_pdesc *);
bool			 pf_syncookie_check(struct pf_pdesc *);
u_int8_t		 pf_syncookie_validate(struct pf_pdesc *);
struct mbuf *		 pf_syncookie_recreate_syn(struct pf_pdesc *);

VNET_DECLARE(struct pf_kstatus, pf_status);
#define	V_pf_status	VNET(pf_status)

struct pf_limit {
	uma_zone_t	zone;
	u_int		limit;
};
VNET_DECLARE(struct pf_limit, pf_limits[PF_LIMIT_MAX]);
#define	V_pf_limits VNET(pf_limits)

#endif /* _KERNEL */

#ifdef _KERNEL
struct pf_nl_pooladdr {
	u_int32_t		 action;
	u_int32_t		 ticket;
	u_int32_t		 nr;
	u_int32_t		 r_num;
	u_int8_t		 r_action;
	u_int8_t		 r_last;
	u_int8_t		 af;
	char			 anchor[MAXPATHLEN];
	struct pf_pooladdr	 addr;
	/* Above this is identical to pfioc_pooladdr */
	int			 which;
};

VNET_DECLARE(struct pf_kanchor_global,		 pf_anchors);
#define	V_pf_anchors				 VNET(pf_anchors)
VNET_DECLARE(struct pf_kanchor,			 pf_main_anchor);
#define	V_pf_main_anchor			 VNET(pf_main_anchor)
VNET_DECLARE(struct pf_keth_anchor_global,	 pf_keth_anchors);
#define	V_pf_keth_anchors			 VNET(pf_keth_anchors)
#define pf_main_ruleset	V_pf_main_anchor.ruleset

VNET_DECLARE(struct pf_keth_anchor,		 pf_main_keth_anchor);
#define V_pf_main_keth_anchor			 VNET(pf_main_keth_anchor)
VNET_DECLARE(struct pf_keth_ruleset*,		 pf_keth);
#define	V_pf_keth				 VNET(pf_keth)

void			 pf_init_kruleset(struct pf_kruleset *);
void			 pf_init_keth(struct pf_keth_ruleset *);
int			 pf_kanchor_setup(struct pf_krule *,
			    const struct pf_kruleset *, const char *);
int			 pf_kanchor_copyout(const struct pf_kruleset *,
			    const struct pf_krule *, char *, size_t);
int			 pf_kanchor_nvcopyout(const struct pf_kruleset *,
			    const struct pf_krule *, nvlist_t *);
void			 pf_remove_kanchor(struct pf_krule *);
void			 pf_remove_if_empty_kruleset(struct pf_kruleset *);
struct pf_kruleset	*pf_find_kruleset(const char *);
struct pf_kruleset	*pf_get_leaf_kruleset(char *, char **);
struct pf_kruleset	*pf_find_or_create_kruleset(const char *);
void			 pf_rs_initialize(void);
void			 pf_rule_tree_free(struct pf_krule_global *);


struct pf_krule		*pf_krule_alloc(void);

void			 pf_remove_if_empty_keth_ruleset(
			    struct pf_keth_ruleset *);
struct pf_keth_ruleset	*pf_find_keth_ruleset(const char *);
struct pf_keth_anchor	*pf_find_keth_anchor(const char *);
int			 pf_keth_anchor_setup(struct pf_keth_rule *,
			    const struct pf_keth_ruleset *, const char *);
int			 pf_keth_anchor_nvcopyout(
			    const struct pf_keth_ruleset *,
			    const struct pf_keth_rule *, nvlist_t *);
struct pf_keth_ruleset	*pf_find_or_create_keth_ruleset(const char *);
void			 pf_keth_anchor_remove(struct pf_keth_rule *);

int			 pf_ioctl_getrules(struct pfioc_rule *);
int			 pf_ioctl_addrule(struct pf_krule *, uint32_t,
			    uint32_t, const char *, const char *, uid_t uid,
			    pid_t);
void			 pf_ioctl_clear_status(void);
int			 pf_ioctl_get_timeout(int, int *);
int			 pf_ioctl_set_timeout(int, int, int *);
int			 pf_ioctl_get_limit(int, unsigned int *);
int			 pf_ioctl_set_limit(int, unsigned int, unsigned int *);
int			 pf_ioctl_begin_addrs(uint32_t *);
int			 pf_ioctl_add_addr(struct pf_nl_pooladdr *);
int			 pf_ioctl_get_addrs(struct pf_nl_pooladdr *);
int			 pf_ioctl_get_addr(struct pf_nl_pooladdr *);
int			 pf_ioctl_get_rulesets(struct pfioc_ruleset *);
int			 pf_ioctl_get_ruleset(struct pfioc_ruleset *);
int			 pf_ioctl_natlook(struct pfioc_natlook *);

void			 pf_krule_free(struct pf_krule *);
void			 pf_krule_clear_counters(struct pf_krule *);
void			 pf_addr_copyout(struct pf_addr_wrap *);
#endif

/* The fingerprint functions can be linked into userland programs (tcpdump) */
int	pf_osfp_add(struct pf_osfp_ioctl *);
#ifdef _KERNEL
struct pf_osfp_enlist *
	pf_osfp_fingerprint(struct pf_pdesc *, const struct tcphdr *);
#endif /* _KERNEL */
void	pf_osfp_flush(void);
int	pf_osfp_get(struct pf_osfp_ioctl *);
int	pf_osfp_match(struct pf_osfp_enlist *, pf_osfp_t);

#ifdef _KERNEL
void			 pf_print_host(struct pf_addr *, u_int16_t, sa_family_t);

enum pf_test_status	 pf_step_into_anchor(struct pf_test_ctx *, struct pf_krule *,
			    struct pf_krule_slist *match_rules);
enum pf_test_status	 pf_match_rule(struct pf_test_ctx *, struct pf_kruleset *,
			    struct pf_krule_slist *);
void			 pf_step_into_keth_anchor(struct pf_keth_anchor_stackframe *,
			    int *, struct pf_keth_ruleset **,
			    struct pf_keth_rule **, struct pf_keth_rule **,
			    int *);
int			 pf_step_out_of_keth_anchor(struct pf_keth_anchor_stackframe *,
			    int *, struct pf_keth_ruleset **,
			    struct pf_keth_rule **, struct pf_keth_rule **,
			    int *);

u_short			 pf_map_addr(sa_family_t, struct pf_krule *,
			    struct pf_addr *, struct pf_addr *,
			    struct pfi_kkif **nkif, sa_family_t *,
			    struct pf_addr *, struct pf_kpool *);
u_short			 pf_map_addr_sn(u_int8_t, struct pf_krule *,
			    struct pf_addr *, struct pf_addr *,
			    sa_family_t *, struct pfi_kkif **,
			    struct pf_addr *, struct pf_kpool *,
			    pf_sn_types_t);
int			 pf_get_transaddr_af(struct pf_krule *,
			    struct pf_pdesc *);
u_short			 pf_get_translation(struct pf_test_ctx *);
u_short			 pf_get_transaddr(struct pf_test_ctx *,
			    struct pf_krule *,
			    u_int8_t, struct pf_kpool *);
int			 pf_translate_compat(struct pf_test_ctx *);

int			 pf_state_key_setup(struct pf_pdesc *,
			    u_int16_t, u_int16_t,
			    struct pf_state_key **sk, struct pf_state_key **nk);
struct pf_state_key	*pf_state_key_clone(const struct pf_state_key *);
void			 pf_rule_to_actions(struct pf_krule *,
			    struct pf_rule_actions *);
int			 pf_normalize_mss(struct pf_pdesc *pd);
#if defined(INET) || defined(INET6)
void	pf_scrub(struct pf_pdesc *);
#endif

struct pfi_kkif		*pf_kkif_create(int);
void			 pf_kkif_free(struct pfi_kkif *);
void			 pf_kkif_zero(struct pfi_kkif *);


/* NAT64 functions. */
int	  inet_nat64(int, const void *, void *, const void *, u_int8_t);
int	  inet_nat64_inet(const void *, void *, const void *, u_int8_t);
int	  inet_nat64_inet6(const void *, void *, const void *, u_int8_t);

int	  inet_nat46(int, const void *, void *, const void *, u_int8_t);
int	  inet_nat46_inet(const void *, void *, const void *, u_int8_t);
int	  inet_nat46_inet6(const void *, void *, const void *, u_int8_t);

#endif /* _KERNEL */

#endif /* _NET_PFVAR_H_ */