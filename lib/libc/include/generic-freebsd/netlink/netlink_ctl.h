/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
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

#ifndef _NETLINK_NETLINK_CTL_H_
#define _NETLINK_NETLINK_CTL_H_

#ifdef _KERNEL
/*
 * This file provides headers for the public KPI of the netlink
 * subsystem
 */
#include <sys/_eventhandler.h>

MALLOC_DECLARE(M_NETLINK);

/*
 * Macro for handling attribute TLVs
 */
#define _roundup2(x, y)         (((x)+((y)-1))&(~((y)-1)))

#define NETLINK_ALIGN_SIZE      sizeof(uint32_t)
#define NETLINK_ALIGN(_len)     _roundup2(_len, NETLINK_ALIGN_SIZE)

#define NLA_ALIGN_SIZE          sizeof(uint32_t)
#define NLA_ALIGN(_len)         _roundup2(_len, NLA_ALIGN_SIZE)
#define	NLA_HDRLEN		((uint16_t)sizeof(struct nlattr))
#define	NLA_DATA_LEN(_nla)	((_nla)->nla_len - NLA_HDRLEN)
#define	NLA_DATA(_nla)		NL_ITEM_DATA(_nla, NLA_HDRLEN)
#define	NLA_DATA_CONST(_nla)	NL_ITEM_DATA_CONST(_nla, NLA_HDRLEN)
#define	NLA_TYPE(_nla)		((_nla)->nla_type & 0x3FFF)

#ifndef	typeof
#define	typeof	__typeof
#endif

#define NLA_NEXT(_attr) (struct nlattr *)((char *)_attr + NLA_ALIGN(_attr->nla_len))
#define	_NLA_END(_start, _len)	((char *)(_start) + (_len))
#define NLA_FOREACH(_attr, _start, _len)      \
        for (typeof(_attr) _end = (typeof(_attr))_NLA_END(_start, _len), _attr = (_start);		\
		((char *)_attr < (char *)_end) && \
		((char *)NLA_NEXT(_attr) <= (char *)_end);	\
		_attr = (_len -= NLA_ALIGN(_attr->nla_len), NLA_NEXT(_attr)))

#include <netlink/netlink_message_writer.h>
#include <netlink/netlink_message_parser.h>


/* Protocol handlers */
struct nl_pstate;
typedef int (*nl_handler_f)(struct nlmsghdr *hdr, struct nl_pstate *npt);

bool netlink_register_proto(int proto, const char *proto_name, nl_handler_f handler);
bool netlink_unregister_proto(int proto);

/* Common helpers */
bool nlp_has_priv(struct nlpcb *nlp, int priv);
struct ucred *nlp_get_cred(struct nlpcb *nlp);
uint32_t nlp_get_pid(const struct nlpcb *nlp);
bool nlp_unconstrained_vnet(const struct nlpcb *nlp);

/* netlink_generic.c */
struct genl_cmd {
	const char	*cmd_name;
	nl_handler_f	cmd_cb;
	uint32_t	cmd_flags;
	uint32_t	cmd_priv;
	uint32_t	cmd_num;
};

uint16_t genl_register_family(const char *family_name, size_t hdrsize,
    uint16_t family_version, uint16_t max_attr_idx);
void genl_unregister_family(uint16_t family);
bool genl_register_cmds(uint16_t family, const struct genl_cmd *cmds,
    u_int count);
uint32_t genl_register_group(uint16_t family, const char *group_name);
void genl_unregister_group(uint16_t family, uint32_t group);

typedef void (*genl_family_event_handler_t)(void *arg, const char *family_name,
    uint16_t family_id, u_int action);
EVENTHANDLER_DECLARE(genl_family_event, genl_family_event_handler_t);

struct thread;
#if defined(NETLINK) || defined(NETLINK_MODULE)
/* Provide optimized calls to the functions inside the same linking unit */
struct nlpcb *_nl_get_thread_nlp(struct thread *td);

static inline struct nlpcb *
nl_get_thread_nlp(struct thread *td)
{
	return (_nl_get_thread_nlp(td));
}

#else
/* Provide access to the functions via netlink_glue.c */
struct nlpcb *nl_get_thread_nlp(struct thread *td);

#endif /* defined(NETLINK) || defined(NETLINK_MODULE) */

#endif
#endif