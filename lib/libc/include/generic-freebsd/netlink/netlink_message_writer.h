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

#ifndef _NETLINK_NETLINK_MESSAGE_WRITER_H_
#define _NETLINK_NETLINK_MESSAGE_WRITER_H_

#ifdef _KERNEL

#include <netinet/in.h>

/*
 * It is not meant to be included directly
 */

struct nl_buf;
struct nl_writer;
typedef bool nl_writer_cb(struct nl_writer *nw);

struct nl_writer {
	struct nl_buf		*buf;	/* Underlying storage pointer */
	struct nlmsghdr		*hdr;	/* Pointer to the currently-filled msg */
	nl_writer_cb		*cb;	/* Callback to flush data */
	union {
		struct nlpcb	*nlp;
		struct {
			uint16_t	proto;
			uint16_t	id;
			int		priv;
		} group;
	};
	u_int		num_messages;	/* Number of messages in the buffer */
	int		malloc_flag;	/* M_WAITOK or M_NOWAIT */
	bool		ignore_limit;	/* If true, ignores RCVBUF limit */
	bool		enomem;		/* True if ENOMEM occured */
	bool		suppress_ack;	/* If true, don't send NLMSG_ERR */
};

#define	NLMSG_SMALL	128
#define	NLMSG_LARGE	2048

/* Message and attribute writing */
#if defined(NETLINK) || defined(NETLINK_MODULE)
/* Provide optimized calls to the functions inside the same linking unit */

bool _nl_writer_unicast(struct nl_writer *, size_t, struct nlpcb *nlp, bool);
bool _nl_writer_group(struct nl_writer *, size_t, uint16_t, uint16_t, int,
    bool);
bool _nlmsg_flush(struct nl_writer *nw);
void _nlmsg_ignore_limit(struct nl_writer *nw);

bool _nlmsg_refill_buffer(struct nl_writer *nw, size_t required_len);
bool _nlmsg_add(struct nl_writer *nw, uint32_t portid, uint32_t seq,
    uint16_t type, uint16_t flags, uint32_t len);
bool _nlmsg_end(struct nl_writer *nw);
void _nlmsg_abort(struct nl_writer *nw);

bool _nlmsg_end_dump(struct nl_writer *nw, int error, struct nlmsghdr *hdr);


static inline bool
nl_writer_unicast(struct nl_writer *nw, size_t size, struct nlpcb *nlp,
    bool waitok)
{
	return (_nl_writer_unicast(nw, size, nlp, waitok));
}

static inline bool
nl_writer_group(struct nl_writer *nw, size_t size, uint16_t proto,
    uint16_t group_id, int priv, bool waitok)
{
	return (_nl_writer_group(nw, size, proto, group_id, priv, waitok));
}

static inline bool
nlmsg_flush(struct nl_writer *nw)
{
	return (_nlmsg_flush(nw));
}

static inline void
nlmsg_ignore_limit(struct nl_writer *nw)
{
	_nlmsg_ignore_limit(nw);
}

static inline bool
nlmsg_refill_buffer(struct nl_writer *nw, size_t required_size)
{
	return (_nlmsg_refill_buffer(nw, required_size));
}

static inline bool
nlmsg_add(struct nl_writer *nw, uint32_t portid, uint32_t seq, uint16_t type,
    uint16_t flags, uint32_t len)
{
	return (_nlmsg_add(nw, portid, seq, type, flags, len));
}

static inline bool
nlmsg_end(struct nl_writer *nw)
{
	return (_nlmsg_end(nw));
}

static inline void
nlmsg_abort(struct nl_writer *nw)
{
	return (_nlmsg_abort(nw));
}

static inline bool
nlmsg_end_dump(struct nl_writer *nw, int error, struct nlmsghdr *hdr)
{
	return (_nlmsg_end_dump(nw, error, hdr));
}

#else
/* Provide access to the functions via netlink_glue.c */

bool nl_writer_unicast(struct nl_writer *, size_t, struct nlpcb *, bool waitok);
bool nl_writer_group(struct nl_writer *, size_t, uint16_t, uint16_t, int,
    bool waitok);
bool nlmsg_flush(struct nl_writer *nw);
void nlmsg_ignore_limit(struct nl_writer *nw);

bool nlmsg_refill_buffer(struct nl_writer *nw, size_t required_size);
bool nlmsg_add(struct nl_writer *nw, uint32_t portid, uint32_t seq,
    uint16_t type, uint16_t flags, uint32_t len);
bool nlmsg_end(struct nl_writer *nw);
void nlmsg_abort(struct nl_writer *nw);

bool nlmsg_end_dump(struct nl_writer *nw, int error, struct nlmsghdr *hdr);

#endif /* defined(NETLINK) || defined(NETLINK_MODULE) */

static inline bool
nlmsg_reply(struct nl_writer *nw, const struct nlmsghdr *hdr, int payload_len)
{
	return (nlmsg_add(nw, hdr->nlmsg_pid, hdr->nlmsg_seq, hdr->nlmsg_type,
	    hdr->nlmsg_flags, payload_len));
}

/*
 * KPI similar to mtodo():
 * current (uncompleted) header is guaranteed to be contiguous,
 *  but can be reallocated, thus pointers may need to be readjusted.
 */
u_int nlattr_save_offset(const struct nl_writer *nw);

static inline void *
_nlattr_restore_offset(const struct nl_writer *nw, int off)
{
	return ((void *)((char *)nw->hdr + off));
}
#define	nlattr_restore_offset(_ns, _off, _t)	((_t *)_nlattr_restore_offset(_ns, _off))

static inline void
nlattr_set_len(const struct nl_writer *nw, int off)
{
	struct nlattr *nla = nlattr_restore_offset(nw, off, struct nlattr);
	nla->nla_len = nlattr_save_offset(nw) - off;
}

void *nlmsg_reserve_data_raw(struct nl_writer *nw, size_t sz);
#define nlmsg_reserve_object(_ns, _t)	((_t *)nlmsg_reserve_data_raw(_ns, sizeof(_t)))
#define nlmsg_reserve_data(_ns, _sz, _t)	((_t *)nlmsg_reserve_data_raw(_ns, _sz))

static inline int
nlattr_add_nested(struct nl_writer *nw, uint16_t nla_type)
{
	int off = nlattr_save_offset(nw);
	struct nlattr *nla = nlmsg_reserve_data(nw, sizeof(struct nlattr), struct nlattr);
	if (__predict_false(nla == NULL))
		return (0);
	nla->nla_type = nla_type;
	return (off);
}

static inline void *
_nlmsg_reserve_attr(struct nl_writer *nw, uint16_t nla_type, uint16_t sz)
{
	sz += sizeof(struct nlattr);

	struct nlattr *nla = nlmsg_reserve_data(nw, sz, struct nlattr);
	if (__predict_false(nla == NULL))
		return (NULL);
	nla->nla_type = nla_type;
	nla->nla_len = sz;

	return ((void *)(nla + 1));
}
#define	nlmsg_reserve_attr(_ns, _at, _t)	((_t *)_nlmsg_reserve_attr(_ns, _at, NLA_ALIGN(sizeof(_t))))

bool nlattr_add(struct nl_writer *nw, uint16_t attr_type, uint16_t attr_len,
    const void *data);

static inline bool
nlattr_add_raw(struct nl_writer *nw, const struct nlattr *nla_src)
{
	MPASS(nla_src->nla_len >= sizeof(struct nlattr));

	return (nlattr_add(nw, nla_src->nla_type,
	    nla_src->nla_len - sizeof(struct nlattr),
	    (const void *)(nla_src + 1)));
}

static inline bool
nlattr_add_bool(struct nl_writer *nw, uint16_t attrtype, bool value)
{
	return (nlattr_add(nw, attrtype, sizeof(bool), &value));
}

static inline bool
nlattr_add_u8(struct nl_writer *nw, uint16_t attrtype, uint8_t value)
{
	return (nlattr_add(nw, attrtype, sizeof(uint8_t), &value));
}

static inline bool
nlattr_add_u16(struct nl_writer *nw, uint16_t attrtype, uint16_t value)
{
	return (nlattr_add(nw, attrtype, sizeof(uint16_t), &value));
}

static inline bool
nlattr_add_u32(struct nl_writer *nw, uint16_t attrtype, uint32_t value)
{
	return (nlattr_add(nw, attrtype, sizeof(uint32_t), &value));
}

static inline bool
nlattr_add_u64(struct nl_writer *nw, uint16_t attrtype, uint64_t value)
{
	return (nlattr_add(nw, attrtype, sizeof(uint64_t), &value));
}

static inline bool
nlattr_add_s8(struct nl_writer *nw, uint16_t attrtype, int8_t value)
{
	return (nlattr_add(nw, attrtype, sizeof(int8_t), &value));
}

static inline bool
nlattr_add_s16(struct nl_writer *nw, uint16_t attrtype, int16_t value)
{
	return (nlattr_add(nw, attrtype, sizeof(int16_t), &value));
}

static inline bool
nlattr_add_s32(struct nl_writer *nw, uint16_t attrtype, int32_t value)
{
	return (nlattr_add(nw, attrtype, sizeof(int32_t), &value));
}

static inline bool
nlattr_add_s64(struct nl_writer *nw, uint16_t attrtype, int64_t value)
{
	return (nlattr_add(nw, attrtype, sizeof(int64_t), &value));
}

static inline bool
nlattr_add_flag(struct nl_writer *nw, uint16_t attrtype)
{
	return (nlattr_add(nw, attrtype, 0, NULL));
}

static inline bool
nlattr_add_string(struct nl_writer *nw, uint16_t attrtype, const char *str)
{
	return (nlattr_add(nw, attrtype, strlen(str) + 1, str));
}

static inline bool
nlattr_add_in_addr(struct nl_writer *nw, uint16_t attrtype,
    const struct in_addr *in)
{
	return (nlattr_add(nw, attrtype, sizeof(*in), in));
}

static inline bool
nlattr_add_in6_addr(struct nl_writer *nw, uint16_t attrtype,
    const struct in6_addr *in6)
{
	return (nlattr_add(nw, attrtype, sizeof(*in6), in6));
}
#endif
#endif