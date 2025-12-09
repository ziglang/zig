/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2021 Ng Peng Nam Sean
 * Copyright (c) 2022 Alexander V. Chernikov <melifaro@FreeBSD.org>
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#ifndef _NETLINK_NETLINK_VAR_H_
#define _NETLINK_NETLINK_VAR_H_

#ifdef _KERNEL

#include <sys/ck.h>
#include <sys/epoch.h>
#include <sys/sysctl.h>
#include <sys/taskqueue.h>
#include <net/vnet.h>

#define	NLSNDQ  	65536 /* Default socket sendspace */
#define	NLRCVQ		65536 /* Default socket recvspace */

#define	NLMBUFSIZE	2048	/* External storage size for Netlink mbufs */

struct ucred;

struct nl_buf {
	TAILQ_ENTRY(nl_buf)	tailq;
	u_int			buflen;
	u_int			datalen;
	u_int			offset;
	char			data[];
};

#define	NLP_MAX_GROUPS		128

BITSET_DEFINE(nl_groups, NLP_MAX_GROUPS);
struct nlpcb {
        struct socket           *nl_socket;
	struct nl_groups	nl_groups;
	uint32_t                nl_port;
	uint32_t	        nl_flags;
	uint32_t	        nl_process_id;
        int                     nl_proto;
	bool			nl_bound;
        bool			nl_task_pending;
	bool			nl_tx_blocked; /* No new requests accepted */
	bool			nl_linux; /* true if running under compat */
	bool			nl_unconstrained_vnet; /* true if running under VNET jail (or without jail) */
	bool			nl_need_thread_setup;
	struct taskqueue	*nl_taskqueue;
	struct task		nl_task;
	uint64_t		nl_dropped_bytes;
	uint64_t		nl_dropped_messages;
        CK_LIST_ENTRY(nlpcb)    nl_next;
        CK_LIST_ENTRY(nlpcb)    nl_port_next;
	volatile u_int		nl_refcount;
	struct mtx		nl_lock;
	struct epoch_context	nl_epoch_ctx;
};
#define sotonlpcb(so)       ((struct nlpcb *)(so)->so_pcb)

#define	NLP_LOCK_INIT(_nlp)	mtx_init(&((_nlp)->nl_lock), "nlp mtx", NULL, MTX_DEF)
#define	NLP_LOCK_DESTROY(_nlp)	mtx_destroy(&((_nlp)->nl_lock))
#define	NLP_LOCK(_nlp)		mtx_lock(&((_nlp)->nl_lock))
#define	NLP_UNLOCK(_nlp)	mtx_unlock(&((_nlp)->nl_lock))

#define	ALIGNED_NL_SZ(_data)	roundup2((((struct nlmsghdr *)(_data))->nlmsg_len), 16)

/* nl_flags */
#define NLF_CAP_ACK             0x01 /* Do not send message body with errmsg */
#define NLF_EXT_ACK             0x02 /* Allow including extended TLVs in ack */
#define	NLF_STRICT		0x04 /* Perform strict header checks */
#define	NLF_MSG_INFO		0x08 /* Send caller info along with the notifications */

SYSCTL_DECL(_net_netlink);
SYSCTL_DECL(_net_netlink_debug);

struct nl_control {
	CK_LIST_HEAD(nl_pid_head, nlpcb)	ctl_port_head;
	CK_LIST_HEAD(nlpcb_head, nlpcb)		ctl_pcb_head;
	CK_LIST_ENTRY(nl_control)		ctl_next;
	struct rmlock				ctl_lock;
};
VNET_DECLARE(struct nl_control, nl_ctl);
#define	V_nl_ctl	VNET(nl_ctl)

struct sockaddr_nl;
struct sockaddr;
struct nlmsghdr;

int nl_verify_proto(int proto);
const char *nl_get_proto_name(int proto);

extern int netlink_unloading;

struct nl_proto_handler {
	nl_handler_f	cb;
	const char	*proto_name;
};
extern struct nl_proto_handler *nl_handlers;

/* netlink_domain.c */
bool nl_send_group(struct nl_writer *);
void nl_clear_group(u_int);
void nl_osd_register(void);
void nl_osd_unregister(void);
void nl_set_thread_nlp(struct thread *td, struct nlpcb *nlp);

/* netlink_io.c */
bool nl_send(struct nl_writer *, struct nlpcb *);
void nlmsg_ack(struct nlpcb *nlp, int error, struct nlmsghdr *nlmsg,
    struct nl_pstate *npt);
void nl_on_transmit(struct nlpcb *nlp);

void nl_taskqueue_handler(void *_arg, int pending);
void nl_schedule_taskqueue(struct nlpcb *nlp);
void nl_process_receive_locked(struct nlpcb *nlp);
void nl_set_source_metadata(struct mbuf *m, int num_messages);
struct nl_buf *nl_buf_alloc(size_t len, int mflag);
void nl_buf_free(struct nl_buf *nb);

#define	MAX_FAMILIES	20
#define	MAX_GROUPS	64

#define	MIN_GROUP_NUM	48

#define	CTRL_FAMILY_ID		0
#define	CTRL_FAMILY_NAME	"nlctrl"
#define	CTRL_GROUP_ID		0
#define	CTRL_GROUP_NAME		"notify"

struct ifnet;
struct nl_parsed_link;
struct nlattr_bmask;
struct nl_pstate;

/* Function map */
struct nl_function_wrapper {
	bool (*nlmsg_add)(struct nl_writer *nw, uint32_t portid, uint32_t seq, uint16_t type,
	    uint16_t flags, uint32_t len);
	bool (*nlmsg_refill_buffer)(struct nl_writer *nw, size_t required_len);
	bool (*nlmsg_flush)(struct nl_writer *nw);
	bool (*nlmsg_end)(struct nl_writer *nw);
	void (*nlmsg_abort)(struct nl_writer *nw);
	void (*nlmsg_ignore_limit)(struct nl_writer *nw);
	bool (*nl_writer_unicast)(struct nl_writer *nw, size_t size,
	    struct nlpcb *nlp, bool waitok);
	bool (*nl_writer_group)(struct nl_writer *nw, size_t size,
	    uint16_t protocol, uint16_t group_id, int priv, bool waitok);
	bool (*nlmsg_end_dump)(struct nl_writer *nw, int error, struct nlmsghdr *hdr);
	int (*nl_modify_ifp_generic)(struct ifnet *ifp, struct nl_parsed_link *lattrs,
	    const struct nlattr_bmask *bm, struct nl_pstate *npt);
	void (*nl_store_ifp_cookie)(struct nl_pstate *npt, struct ifnet *ifp);
	struct nlpcb * (*nl_get_thread_nlp)(struct  thread *td);
};
void nl_set_functions(const struct nl_function_wrapper *nl);



#endif
#endif