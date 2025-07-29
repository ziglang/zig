/*	$NetBSD: ipsec.h,v 1.93 2022/10/28 05:23:09 ozaki-r Exp $	*/
/*	$FreeBSD: ipsec.h,v 1.2.4.2 2004/02/14 22:23:23 bms Exp $	*/
/*	$KAME: ipsec.h,v 1.53 2001/11/20 08:32:38 itojun Exp $	*/

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

#ifndef _NETIPSEC_IPSEC_H_
#define _NETIPSEC_IPSEC_H_

#if defined(_KERNEL_OPT)
#include "opt_inet.h"
#include "opt_ipsec.h"
#endif

#include <net/pfkeyv2.h>

#ifdef _KERNEL
#include <sys/socketvar.h>
#include <sys/localcount.h>

#include <netinet/in_pcb.h>
#include <netipsec/keydb.h>

/*
 * Security Policy Index
 * Ensure that both address families in the "src" and "dst" are same.
 * When the value of the ul_proto is ICMPv6, the port field in "src"
 * specifies ICMPv6 type, and the port field in "dst" specifies ICMPv6 code.
 */
struct secpolicyindex {
	u_int8_t dir;			/* direction of packet flow, see blow */
	union sockaddr_union src;	/* IP src address for SP */
	union sockaddr_union dst;	/* IP dst address for SP */
	u_int8_t prefs;			/* prefix length in bits for src */
	u_int8_t prefd;			/* prefix length in bits for dst */
	u_int16_t ul_proto;		/* upper layer Protocol */
};

/* Security Policy Data Base */
struct secpolicy {
	struct pslist_entry pslist_entry;

	struct localcount localcount;	/* reference count */
	struct secpolicyindex spidx;	/* selector */
	u_int32_t id;			/* It's unique number on the system. */
	u_int state;			/* 0: dead, others: alive */
#define IPSEC_SPSTATE_DEAD	0
#define IPSEC_SPSTATE_ALIVE	1

	u_int origin;			/* who generate this SP. */
#define IPSEC_SPORIGIN_USER	0
#define IPSEC_SPORIGIN_KERNEL	1

	u_int policy;		/* DISCARD, NONE or IPSEC, see keyv2.h */
	struct ipsecrequest *req;
				/* pointer to the ipsec request tree, */
				/* if policy == IPSEC else this value == NULL.*/

	/*
	 * lifetime handler.
	 * the policy can be used without limitiation if both lifetime and
	 * validtime are zero.
	 * "lifetime" is passed by sadb_lifetime.sadb_lifetime_addtime.
	 * "validtime" is passed by sadb_lifetime.sadb_lifetime_usetime.
	 */
	time_t created;		/* time created the policy */
	time_t lastused;	/* updated every when kernel sends a packet */
	time_t lifetime;	/* duration of the lifetime of this policy */
	time_t validtime;	/* duration this policy is valid without use */
};

/* Request for IPsec */
struct ipsecrequest {
	struct ipsecrequest *next;
				/* pointer to next structure */
				/* If NULL, it means the end of chain. */
	struct secasindex saidx;/* hint for search proper SA */
				/* if __ss_len == 0 then no address specified.*/
	u_int level;		/* IPsec level defined below. */

	struct secpolicy *sp;	/* back pointer to SP */
};

/* security policy in PCB */
struct inpcbpolicy {
	struct secpolicy *sp_in;
	struct secpolicy *sp_out;
	int priv;			/* privileged socket ? */

	/* cached policy */
	struct {
		struct secpolicy *cachesp;
		struct secpolicyindex cacheidx;
		int cachehint;		/* processing requirement hint: */
#define	IPSEC_PCBHINT_UNKNOWN	0	/* Unknown */
#define	IPSEC_PCBHINT_YES	1	/* IPsec processing is required */
#define	IPSEC_PCBHINT_NO	2	/* IPsec processing not required */
		u_int cachegen;		/* spdgen when cache filled */
	} sp_cache[3];			/* XXX 3 == IPSEC_DIR_MAX */
	int sp_cacheflags;
#define	IPSEC_PCBSP_CONNECTED	1
	struct inpcb *sp_inp;		/* back pointer */
};

extern u_int ipsec_spdgen;

static __inline bool
ipsec_pcb_skip_ipsec(struct inpcbpolicy *pcbsp, int dir)
{

	KASSERT(inp_locked(pcbsp->sp_inp));

	return pcbsp->sp_cache[(dir)].cachehint == IPSEC_PCBHINT_NO &&
	    pcbsp->sp_cache[(dir)].cachegen == ipsec_spdgen;
}

/* SP acquiring list table. */
struct secspacq {
	LIST_ENTRY(secspacq) chain;

	struct secpolicyindex spidx;

	time_t created;		/* for lifetime */
	int count;		/* for lifetime */
	/* XXX: here is mbuf place holder to be sent ? */
};
#endif /* _KERNEL */

/* buffer size for formatted output of ipsec address (addr + '%' + scope_id?) */
#define	IPSEC_ADDRSTRLEN	(INET6_ADDRSTRLEN + 11)
/* buffer size for ipsec_logsastr() */
#define	IPSEC_LOGSASTRLEN	192

/* according to IANA assignment, port 0x0000 and proto 0xff are reserved. */
#define IPSEC_PORT_ANY		0
#define IPSEC_ULPROTO_ANY	255
#define IPSEC_PROTO_ANY		255

/* mode of security protocol */
/* NOTE: DON'T use IPSEC_MODE_ANY at SPD.  It's only use in SAD */
#define	IPSEC_MODE_ANY		0	/* i.e. wildcard. */
#define	IPSEC_MODE_TRANSPORT	1
#define	IPSEC_MODE_TUNNEL	2
#define	IPSEC_MODE_TCPMD5	3	/* TCP MD5 mode */

/*
 * Direction of security policy.
 * NOTE: Since INVALID is used just as flag.
 * The other are used for loop counter too.
 */
#define IPSEC_DIR_ANY		0
#define IPSEC_DIR_INBOUND	1
#define IPSEC_DIR_OUTBOUND	2
#define IPSEC_DIR_MAX		3
#define IPSEC_DIR_INVALID	4

#define IPSEC_DIR_IS_VALID(dir)		((dir) >= 0 && (dir) <= IPSEC_DIR_MAX)
#define IPSEC_DIR_IS_INOROUT(dir)	((dir) == IPSEC_DIR_INBOUND || \
					 (dir) == IPSEC_DIR_OUTBOUND)

/* Policy level */
/*
 * IPSEC, ENTRUST and BYPASS are allowed for setsockopt() in PCB,
 * DISCARD, IPSEC and NONE are allowed for setkey() in SPD.
 * DISCARD and NONE are allowed for system default.
 */
#define IPSEC_POLICY_DISCARD	0	/* discarding packet */
#define IPSEC_POLICY_NONE	1	/* through IPsec engine */
#define IPSEC_POLICY_IPSEC	2	/* do IPsec */
#define IPSEC_POLICY_ENTRUST	3	/* consulting SPD if present. */
#define IPSEC_POLICY_BYPASS	4	/* only for privileged socket. */

/* Security protocol level */
#define	IPSEC_LEVEL_DEFAULT	0	/* reference to system default */
#define	IPSEC_LEVEL_USE		1	/* use SA if present. */
#define	IPSEC_LEVEL_REQUIRE	2	/* require SA. */
#define	IPSEC_LEVEL_UNIQUE	3	/* unique SA. */

#define IPSEC_MANUAL_REQID_MAX	0x3fff
				/*
				 * if security policy level == unique, this id
				 * indicate to a relative SA for use, else is
				 * zero.
				 * 1 - 0x3fff are reserved for manual keying.
				 * 0 are reserved for above reason.  Others is
				 * for kernel use.
				 * Note that this id doesn't identify SA
				 * by only itself.
				 */
#define IPSEC_REPLAYWSIZE  32

#ifdef _KERNEL

extern int ipsec_debug;
#ifdef IPSEC_DEBUG
extern int ipsec_replay;
extern int ipsec_integrity;
#endif

extern struct secpolicy ip4_def_policy;
extern int ip4_esp_trans_deflev;
extern int ip4_esp_net_deflev;
extern int ip4_ah_trans_deflev;
extern int ip4_ah_net_deflev;
extern int ip4_ah_cleartos;
extern int ip4_ah_offsetmask;
extern int ip4_ipsec_dfbit;
extern int ip4_ipsec_ecn;
extern int crypto_support;

#include <sys/syslog.h>

#define	DPRINTF(fmt, args...) 						\
	do {								\
		if (ipsec_debug)					\
			log(LOG_DEBUG, "%s: " fmt, __func__, ##args);	\
	} while (/*CONSTCOND*/0)

#define IPSECLOG(level, fmt, args...) 					\
	do {								\
		if (ipsec_debug)					\
			log(level, "%s: " fmt, __func__, ##args);	\
	} while (/*CONSTCOND*/0)

#define ipsec_indone(m)	\
	((m->m_flags & M_AUTHIPHDR) || (m->m_flags & M_DECRYPTED))
#define ipsec_outdone(m) \
	(m_tag_find((m), PACKET_TAG_IPSEC_OUT_DONE) != NULL)

static __inline bool
ipsec_skip_pfil(struct mbuf *m)
{
	bool rv;

	if (ipsec_indone(m) &&
	    ((m->m_pkthdr.pkthdr_flags & PKTHDR_FLAG_IPSEC_SKIP_PFIL) != 0)) {
		m->m_pkthdr.pkthdr_flags &= ~PKTHDR_FLAG_IPSEC_SKIP_PFIL;
		rv = true;
	} else {
		rv = false;
	}

	return rv;
}

void ipsec_pcbconn(struct inpcbpolicy *);
void ipsec_pcbdisconn(struct inpcbpolicy *);
void ipsec_invalpcbcacheall(void);

struct inpcb;
int ipsec4_output(struct mbuf *, struct inpcb *, int, u_long *, bool *, bool *, bool *);

int ipsec_ip_input_checkpolicy(struct mbuf *, bool);
void ipsec_mtu(struct mbuf *, int *);
#ifdef INET6
void ipsec6_udp_cksum(struct mbuf *);
#endif

struct inpcb;
int ipsec_init_pcbpolicy(struct socket *so, struct inpcbpolicy **);
int ipsec_copy_policy(const struct inpcbpolicy *, struct inpcbpolicy *);
u_int ipsec_get_reqlevel(const struct ipsecrequest *);

int ipsec_set_policy(struct inpcb *, const void *, size_t, kauth_cred_t);
int ipsec_get_policy(struct inpcb *, const void *, size_t, struct mbuf **);
int ipsec_delete_pcbpolicy(struct inpcb *);
int ipsec_in_reject(struct mbuf *, struct inpcb *);

struct secasvar *ipsec_lookup_sa(const struct ipsecrequest *,
    const struct mbuf *);

struct secas;
struct tcpcb;
int ipsec_chkreplay(u_int32_t, const struct secasvar *);
int ipsec_updatereplay(u_int32_t, const struct secasvar *);

size_t ipsec_hdrsiz(struct mbuf *, u_int, struct inpcb *);
size_t ipsec4_hdrsiz_tcp(struct tcpcb *);

union sockaddr_union;
const char *ipsec_address(const union sockaddr_union* sa, char *, size_t);
const char *ipsec_logsastr(const struct secasvar *, char *, size_t);

/* NetBSD protosw ctlin entrypoint */
void *esp4_ctlinput(int, const struct sockaddr *, void *);
void *ah4_ctlinput(int, const struct sockaddr *, void *);

void ipsec_output_init(void);
struct m_tag;
void ipsec4_common_input(struct mbuf *m, int, int);
int ipsec4_common_input_cb(struct mbuf *, struct secasvar *, int, int);
int ipsec4_process_packet(struct mbuf *, const struct ipsecrequest *, u_long *);
int ipsec_process_done(struct mbuf *, const struct ipsecrequest *,
    struct secasvar *, int);

struct mbuf *m_clone(struct mbuf *);
struct mbuf *m_makespace(struct mbuf *, int, int, int *);
void *m_pad(struct mbuf *, int);
int m_striphdr(struct mbuf *, int, int);

extern int ipsec_used __read_mostly;
extern int ipsec_enabled __read_mostly;

#endif /* _KERNEL */

#ifndef _KERNEL
char *ipsec_set_policy(const char *, int);
int ipsec_get_policylen(char *);
char *ipsec_dump_policy(char *, const char *);
const char *ipsec_strerror(void);
#endif /* !_KERNEL */

#ifdef _KERNEL
/* External declarations of per-file init functions */
void ah_attach(void);
void esp_attach(void);
void ipcomp_attach(void);
void ipe4_attach(void);
void tcpsignature_attach(void);

void ipsec_attach(void);

void sysctl_net_inet_ipsec_setup(struct sysctllog **);
#ifdef INET6
void sysctl_net_inet6_ipsec6_setup(struct sysctllog **);
#endif

#endif /* _KERNEL */
#endif /* !_NETIPSEC_IPSEC_H_ */