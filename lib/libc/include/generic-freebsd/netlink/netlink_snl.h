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
#ifndef	_NETLINK_NETLINK_SNL_H_
#define	_NETLINK_NETLINK_SNL_H_

/*
 * Simple Netlink Library
 */

#include <assert.h>
#include <errno.h>
#include <stdalign.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netlink/netlink.h>
#include <netlink/netlink_bitset.h>

#define _roundup2(x, y)         (((x)+((y)-1))&(~((y)-1)))

#define NETLINK_ALIGN_SIZE      sizeof(uint32_t)
#define NETLINK_ALIGN(_len)     _roundup2(_len, NETLINK_ALIGN_SIZE)

#define NLA_ALIGN_SIZE          sizeof(uint32_t)
#define	NLA_HDRLEN		((int)sizeof(struct nlattr))
#define	NLA_DATA_LEN(_nla)	((int)((_nla)->nla_len - NLA_HDRLEN))
#define	NLA_DATA(_nla)		NL_ITEM_DATA(_nla, NLA_HDRLEN)
#define	NLA_DATA_CONST(_nla)	NL_ITEM_DATA_CONST(_nla, NLA_HDRLEN)

#define	NLA_TYPE(_nla)		((_nla)->nla_type & 0x3FFF)

#define NLA_NEXT(_attr) (struct nlattr *)(void *)((char *)_attr + NLA_ALIGN(_attr->nla_len))

#define	_NLA_END(_start, _len)	((char *)(_start) + (_len))
#define NLA_FOREACH(_attr, _start, _len)      \
        for (_attr = (struct nlattr *)(_start);		\
		((char *)_attr < _NLA_END(_start, _len)) && \
		((char *)NLA_NEXT(_attr) <= _NLA_END(_start, _len));	\
		_attr =  NLA_NEXT(_attr))

#define	NL_ARRAY_LEN(_a)	(sizeof(_a) / sizeof((_a)[0]))

struct linear_buffer {
	char			*base;	/* Base allocated memory pointer */
	uint32_t		offset;	/* Currently used offset */
	uint32_t		size;	/* Total buffer size */
	struct linear_buffer	*next;	/* Buffer chaining */
} __aligned(alignof(__max_align_t));

static inline struct linear_buffer *
lb_init(uint32_t size)
{
	struct linear_buffer *lb = (struct linear_buffer *)calloc(1, size);

	if (lb != NULL) {
		lb->base = (char *)(lb + 1);
		lb->size = size - sizeof(*lb);
	}

	return (lb);
}

static inline void
lb_free(struct linear_buffer *lb)
{
	free(lb);
}

static inline char *
lb_allocz(struct linear_buffer *lb, int len)
{
	len = roundup2(len, alignof(__max_align_t));
	if (lb->offset + len > lb->size)
		return (NULL);
	char *data = (lb->base + lb->offset);
	lb->offset += len;
	return (data);
}

static inline void
lb_clear(struct linear_buffer *lb)
{
	memset(lb->base, 0, lb->offset);
	lb->offset = 0;
}

struct snl_state {
	int fd;
	char *buf;
	size_t off;
	size_t bufsize;
	size_t datalen;
	uint32_t seq;
	bool init_done;
	struct linear_buffer *lb;
};
#define	SCRATCH_BUFFER_SIZE	1024
#define	SNL_WRITER_BUFFER_SIZE	256

typedef void snl_parse_field_f(struct snl_state *ss, void *hdr, void *target);
struct snl_field_parser {
	uint16_t		off_in;
	uint16_t		off_out;
	snl_parse_field_f	*cb;
};

typedef bool snl_parse_attr_f(struct snl_state *ss, struct nlattr *attr,
    const void *arg, void *target);
struct snl_attr_parser {
	uint16_t		type;	/* Attribute type */
	uint16_t		off;	/* field offset in the target structure */
	snl_parse_attr_f	*cb;	/* parser function to call */

	/* Optional parser argument */
	union {
		const void		*arg;
		const uint32_t		 arg_u32;
	};
};

typedef bool snl_parse_post_f(struct snl_state *ss, void *target);

struct snl_hdr_parser {
	uint16_t			in_hdr_size; /* Input header size */
	uint16_t			out_size; /* Output structure size */
	uint16_t			fp_size; /* Number of items in field parser */
	uint16_t			np_size; /* Number of items in attribute parser */
	const struct snl_field_parser	*fp; /* array of header field parsers */
	const struct snl_attr_parser	*np; /* array of attribute parsers */
	snl_parse_post_f		*cb_post; /* post-parse callback */
};

#define	SNL_DECLARE_PARSER_EXT(_name, _sz_h_in, _sz_out, _fp, _np, _cb)	\
static const struct snl_hdr_parser _name = {				\
	.in_hdr_size = _sz_h_in,					\
	.out_size = _sz_out,						\
	.fp = &((_fp)[0]),						\
	.np = &((_np)[0]),						\
	.fp_size = NL_ARRAY_LEN(_fp),					\
	.np_size = NL_ARRAY_LEN(_np),					\
	.cb_post = _cb,							\
}

#define	SNL_DECLARE_PARSER(_name, _t, _fp, _np)				\
	SNL_DECLARE_PARSER_EXT(_name, sizeof(_t), 0, _fp, _np, NULL)

#define	SNL_DECLARE_FIELD_PARSER_EXT(_name, _sz_h_in, _sz_out, _fp, _cb) \
static const struct snl_hdr_parser _name = {				\
	.in_hdr_size = _sz_h_in,					\
	.out_size = _sz_out,						\
	.fp = &((_fp)[0]),						\
	.fp_size = NL_ARRAY_LEN(_fp),					\
	.cb_post = _cb,							\
}

#define	SNL_DECLARE_FIELD_PARSER(_name, _t, _fp)			\
	SNL_DECLARE_FIELD_PARSER_EXT(_name, sizeof(_t), 0, _fp, NULL)

#define	SNL_DECLARE_ATTR_PARSER_EXT(_name, _sz_out, _np, _cb)		\
static const struct snl_hdr_parser _name = {				\
	.out_size = _sz_out,						\
	.np = &((_np)[0]),						\
	.np_size = NL_ARRAY_LEN(_np),					\
	.cb_post = _cb,							\
}

#define	SNL_DECLARE_ATTR_PARSER(_name, _np)				\
	SNL_DECLARE_ATTR_PARSER_EXT(_name, 0, _np, NULL)


static inline void *
snl_allocz(struct snl_state *ss, int len)
{
	void *data = lb_allocz(ss->lb, len);

	if (data == NULL) {
		uint32_t size = ss->lb->size * 2;

		while (size < len + sizeof(struct linear_buffer))
			size *= 2;

		struct linear_buffer *lb = lb_init(size);

		if (lb != NULL) {
			lb->next = ss->lb;
			ss->lb = lb;
			data = lb_allocz(ss->lb, len);
		}
	}

	return (data);
}

static inline void
snl_clear_lb(struct snl_state *ss)
{
	struct linear_buffer *lb = ss->lb;

	lb_clear(lb);
	lb = lb->next;
	ss->lb->next = NULL;
	/* Remove all linear bufs except the largest one */
	while (lb != NULL) {
		struct linear_buffer *lb_next = lb->next;
		lb_free(lb);
		lb = lb_next;
	}
}

static void
snl_free(struct snl_state *ss)
{
	if (ss->init_done) {
		close(ss->fd);
		if (ss->buf != NULL)
			free(ss->buf);
		if (ss->lb != NULL) {
			snl_clear_lb(ss);
			lb_free(ss->lb);
		}
	}
}

static inline bool
snl_init(struct snl_state *ss, int netlink_family)
{
	memset(ss, 0, sizeof(*ss));

	ss->fd = socket(AF_NETLINK, SOCK_RAW, netlink_family);
	if (ss->fd == -1)
		return (false);
	ss->init_done = true;

	int val = 1;
	socklen_t optlen = sizeof(val);
	if (setsockopt(ss->fd, SOL_NETLINK, NETLINK_EXT_ACK, &val, optlen) == -1) {
		snl_free(ss);
		return (false);
	}

	int rcvbuf;
	if (getsockopt(ss->fd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, &optlen) == -1) {
		snl_free(ss);
		return (false);
	}

	ss->bufsize = rcvbuf;
	ss->buf = (char *)malloc(ss->bufsize);
	if (ss->buf == NULL) {
		snl_free(ss);
		return (false);
	}

	ss->lb = lb_init(SCRATCH_BUFFER_SIZE);
	if (ss->lb == NULL) {
		snl_free(ss);
		return (false);
	}

	return (true);
}

static inline bool
snl_send(struct snl_state *ss, void *data, int sz)
{
	return (send(ss->fd, data, sz, 0) == sz);
}

static inline bool
snl_send_message(struct snl_state *ss, struct nlmsghdr *hdr)
{
	ssize_t sz = NLMSG_ALIGN(hdr->nlmsg_len);

	return (send(ss->fd, hdr, sz, 0) == sz);
}

static inline uint32_t
snl_get_seq(struct snl_state *ss)
{
	return (++ss->seq);
}

struct snl_msg_info {
	int		cmsg_type;
	int		cmsg_level;
	uint32_t	process_id;
	uint8_t		port_id;
	uint8_t		seq_id;
};
static inline bool parse_cmsg(struct snl_state *ss, const struct msghdr *msg,
    struct snl_msg_info *attrs);

static inline struct nlmsghdr *
snl_read_message_dbg(struct snl_state *ss, struct snl_msg_info *cinfo)
{
	memset(cinfo, 0, sizeof(*cinfo));

	if (ss->off == ss->datalen) {
		struct sockaddr_nl nladdr;
		char cbuf[64];

		struct iovec iov = {
			.iov_base = ss->buf,
			.iov_len = ss->bufsize,
		};
		struct msghdr msg = {
			.msg_name = &nladdr,
			.msg_namelen = sizeof(nladdr),
			.msg_iov = &iov,
			.msg_iovlen = 1,
			.msg_control = cbuf,
			.msg_controllen = sizeof(cbuf),
		};
		ss->off = 0;
		ss->datalen = 0;
		for (;;) {
			ssize_t datalen = recvmsg(ss->fd, &msg, 0);
			if (datalen > 0) {
				ss->datalen = datalen;
				parse_cmsg(ss, &msg, cinfo);
				break;
			} else if (errno != EINTR)
				return (NULL);
		}
	}
	struct nlmsghdr *hdr = (struct nlmsghdr *)(void *)&ss->buf[ss->off];
	ss->off += NLMSG_ALIGN(hdr->nlmsg_len);
	return (hdr);
}


static inline struct nlmsghdr *
snl_read_message(struct snl_state *ss)
{
	if (ss->off == ss->datalen) {
		struct sockaddr_nl nladdr;
		struct iovec iov = {
			.iov_base = ss->buf,
			.iov_len = ss->bufsize,
		};
		struct msghdr msg = {
			.msg_name = &nladdr,
			.msg_namelen = sizeof(nladdr),
			.msg_iov = &iov,
			.msg_iovlen = 1,
		};
		ss->off = 0;
		ss->datalen = 0;
		for (;;) {
			ssize_t datalen = recvmsg(ss->fd, &msg, 0);
			if (datalen > 0) {
				ss->datalen = datalen;
				break;
			} else if (errno != EINTR)
				return (NULL);
		}
	}
	struct nlmsghdr *hdr = (struct nlmsghdr *)(void *)&ss->buf[ss->off];
	ss->off += NLMSG_ALIGN(hdr->nlmsg_len);
	return (hdr);
}

static inline struct nlmsghdr *
snl_read_reply(struct snl_state *ss, uint32_t nlmsg_seq)
{
	struct nlmsghdr *hdr;

	while ((hdr = snl_read_message(ss)) != NULL) {
		if (hdr->nlmsg_seq == nlmsg_seq)
			return (hdr);
	}

	return (NULL);
}

/*
 * Checks that attributes are sorted by attribute type.
 */
static inline void
snl_verify_parsers(const struct snl_hdr_parser **parser, int count)
{
	for (int i = 0; i < count; i++) {
		const struct snl_hdr_parser *p = parser[i];
		int attr_type = 0;
		for (int j = 0; j < p->np_size; j++) {
			assert(p->np[j].type > attr_type);
			attr_type = p->np[j].type;
		}
	}
}
#define	SNL_VERIFY_PARSERS(_p)	snl_verify_parsers((_p), NL_ARRAY_LEN(_p))

static const struct snl_attr_parser *
find_parser(const struct snl_attr_parser *ps, int pslen, int key)
{
	int left_i = 0, right_i = pslen - 1;

	if (key < ps[0].type || key > ps[pslen - 1].type)
		return (NULL);

	while (left_i + 1 < right_i) {
		int mid_i = (left_i + right_i) / 2;
		if (key < ps[mid_i].type)
			right_i = mid_i;
		else if (key > ps[mid_i].type)
			left_i = mid_i + 1;
		else
			return (&ps[mid_i]);
	}
	if (ps[left_i].type == key)
		return (&ps[left_i]);
	else if (ps[right_i].type == key)
		return (&ps[right_i]);
	return (NULL);
}

static inline bool
snl_parse_attrs_raw(struct snl_state *ss, struct nlattr *nla_head, int len,
    const struct snl_attr_parser *ps, int pslen, void *target)
{
	struct nlattr *nla;

	NLA_FOREACH(nla, nla_head, len) {
		if (nla->nla_len < sizeof(struct nlattr))
			return (false);
		int nla_type = nla->nla_type & NLA_TYPE_MASK;
		const struct snl_attr_parser *s = find_parser(ps, pslen, nla_type);
		if (s != NULL) {
			void *ptr = (void *)((char *)target + s->off);
			if (!s->cb(ss, nla, s->arg, ptr))
				return (false);
		}
	}
	return (true);
}

static inline bool
snl_parse_attrs(struct snl_state *ss, struct nlmsghdr *hdr, int hdrlen,
    const struct snl_attr_parser *ps, int pslen, void *target)
{
	int off = NLMSG_HDRLEN + NETLINK_ALIGN(hdrlen);
	int len = hdr->nlmsg_len - off;
	struct nlattr *nla_head = (struct nlattr *)(void *)((char *)hdr + off);

	return (snl_parse_attrs_raw(ss, nla_head, len, ps, pslen, target));
}

static inline void
snl_parse_fields(struct snl_state *ss, struct nlmsghdr *hdr, int hdrlen __unused,
    const struct snl_field_parser *ps, int pslen, void *target)
{
	for (int i = 0; i < pslen; i++) {
		const struct snl_field_parser *fp = &ps[i];
		void *src = (char *)hdr + fp->off_in;
		void *dst = (char *)target + fp->off_out;

		fp->cb(ss, src, dst);
	}
}

static inline bool
snl_parse_header(struct snl_state *ss, void *hdr, int len,
    const struct snl_hdr_parser *parser, void *target)
{
	struct nlattr *nla_head;

	/* Extract fields first (if any) */
	snl_parse_fields(ss, (struct nlmsghdr *)hdr, parser->in_hdr_size,
	    parser->fp, parser->fp_size, target);

	nla_head = (struct nlattr *)(void *)((char *)hdr + parser->in_hdr_size);
	bool result = snl_parse_attrs_raw(ss, nla_head, len - parser->in_hdr_size,
	    parser->np, parser->np_size, target);

	if (result && parser->cb_post != NULL)
		result = parser->cb_post(ss, target);

	return (result);
}

static inline bool
snl_parse_nlmsg(struct snl_state *ss, struct nlmsghdr *hdr,
    const struct snl_hdr_parser *parser, void *target)
{
	return (snl_parse_header(ss, hdr + 1, hdr->nlmsg_len - sizeof(*hdr), parser, target));
}

static inline bool
snl_attr_get_flag(struct snl_state *ss __unused, struct nlattr *nla, const void *arg __unused,
    void *target)
{
	if (NLA_DATA_LEN(nla) == 0) {
		*((uint8_t *)target) = 1;
		return (true);
	}
	return (false);
}

static inline bool
snl_attr_get_uint8(struct snl_state *ss __unused, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	if (NLA_DATA_LEN(nla) == sizeof(uint8_t)) {
		*((uint8_t *)target) = *((const uint8_t *)NLA_DATA_CONST(nla));
		return (true);
	}
	return (false);
}

static inline bool
snl_attr_get_uint16(struct snl_state *ss __unused, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	if (NLA_DATA_LEN(nla) == sizeof(uint16_t)) {
		*((uint16_t *)target) = *((const uint16_t *)NLA_DATA_CONST(nla));
		return (true);
	}
	return (false);
}

static inline bool
snl_attr_get_uint32(struct snl_state *ss __unused, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	if (NLA_DATA_LEN(nla) == sizeof(uint32_t)) {
		*((uint32_t *)target) = *((const uint32_t *)NLA_DATA_CONST(nla));
		return (true);
	}
	return (false);
}

static inline bool
snl_attr_get_uint64(struct snl_state *ss __unused, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	if (NLA_DATA_LEN(nla) == sizeof(uint64_t)) {
		memcpy(target, NLA_DATA_CONST(nla), sizeof(uint64_t));
		return (true);
	}
	return (false);
}

static inline bool
snl_attr_get_int8(struct snl_state *ss, struct nlattr *nla, const void *arg,
    void *target)
{
	return (snl_attr_get_uint8(ss, nla, arg, target));
}

static inline bool
snl_attr_get_int16(struct snl_state *ss, struct nlattr *nla, const void *arg,
    void *target)
{
	return (snl_attr_get_uint16(ss, nla, arg, target));
}

static inline bool
snl_attr_get_int32(struct snl_state *ss, struct nlattr *nla, const void *arg,
    void *target)
{
	return (snl_attr_get_uint32(ss, nla, arg, target));
}

static inline bool
snl_attr_get_int64(struct snl_state *ss, struct nlattr *nla, const void *arg,
    void *target)
{
	return (snl_attr_get_uint64(ss, nla, arg, target));
}

static inline bool
snl_attr_get_string(struct snl_state *ss __unused, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	size_t maxlen = NLA_DATA_LEN(nla);

	if (strnlen((char *)NLA_DATA(nla), maxlen) < maxlen) {
		*((char **)target) = (char *)NLA_DATA(nla);
		return (true);
	}
	return (false);
}

static inline bool
snl_attr_get_stringn(struct snl_state *ss, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	int maxlen = NLA_DATA_LEN(nla);

	char *buf = (char *)snl_allocz(ss, maxlen + 1);
	if (buf == NULL)
		return (false);
	buf[maxlen] = '\0';
	memcpy(buf, NLA_DATA(nla), maxlen);

	*((char **)target) = buf;
	return (true);
}

static inline bool
snl_attr_copy_string(struct snl_state *ss, struct nlattr *nla,
    const void *arg, void *target)
{
	char *tmp;

	if (snl_attr_get_string(ss, nla, NULL, &tmp)) {
		strlcpy((char *)target, tmp, (size_t)arg);
		return (true);
	}
	return (false);
}

static inline bool
snl_attr_dup_string(struct snl_state *ss __unused, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	size_t maxlen = NLA_DATA_LEN(nla);

	if (strnlen((char *)NLA_DATA(nla), maxlen) < maxlen) {
		char *buf = (char *)snl_allocz(ss, maxlen);
		if (buf == NULL)
			return (false);
		memcpy(buf, NLA_DATA(nla), maxlen);
		*((char **)target) = buf;
		return (true);
	}
	return (false);
}

static inline bool
snl_attr_get_nested(struct snl_state *ss, struct nlattr *nla, const void *arg, void *target)
{
	const struct snl_hdr_parser *p = (const struct snl_hdr_parser *)arg;

	/* Assumes target points to the beginning of the structure */
	return (snl_parse_header(ss, NLA_DATA(nla), NLA_DATA_LEN(nla), p, target));
}

struct snl_parray {
	uint32_t count;
	void **items;
};

static inline bool
snl_attr_get_parray_sz(struct snl_state *ss, struct nlattr *container_nla,
    uint32_t start_size, const void *arg, void *target)
{
	const struct snl_hdr_parser *p = (const struct snl_hdr_parser *)arg;
	struct snl_parray *array = (struct snl_parray *)target;
	struct nlattr *nla;
	uint32_t count = 0, size = start_size;

	if (p->out_size == 0)
		return (false);

	array->items = (void **)snl_allocz(ss, size * sizeof(void *));
	if (array->items == NULL)
		return (false);

	/*
	 * If the provided parser is an attribute parser, assume that each
	 *  nla in the container nla is the container nla itself and parse
	 *  the contents of this nla.
	 * Otherwise, run the parser on raw data, assuming the header of this
	 * data has u16 field with total size in the beginning.
	 */
	uint32_t data_off = 0;

	if (p->in_hdr_size == 0)
		data_off = sizeof(struct nlattr);

	NLA_FOREACH(nla, NLA_DATA(container_nla), NLA_DATA_LEN(container_nla)) {
		void *item = snl_allocz(ss, p->out_size);

		if (item == NULL)
			return (false);

		void *data = (char *)(void *)nla + data_off;
		int data_len = nla->nla_len - data_off;

		if (!(snl_parse_header(ss, data, data_len, p, item)))
			return (false);

		if (count == size) {
			uint32_t new_size = size * 2;
			void **new_array = (void **)snl_allocz(ss, new_size *sizeof(void *));

			memcpy(new_array, array->items, size * sizeof(void *));
			array->items = new_array;
			size = new_size;
		}
		array->items[count++] = item;
	}
	array->count = count;

	return (true);
}

/*
 * Parses and stores the unknown-size array.
 * Assumes each array item is a container and the NLAs in the container are parsable
 *  by the parser provided in @arg.
 * Assumes @target is struct snl_parray
 */
static inline bool
snl_attr_get_parray(struct snl_state *ss, struct nlattr *nla, const void *arg, void *target)
{
	return (snl_attr_get_parray_sz(ss, nla, 8, arg, target));
}

static inline bool
snl_attr_get_nla(struct snl_state *ss __unused, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	*((struct nlattr **)target) = nla;
	return (true);
}

static inline bool
snl_attr_dup_nla(struct snl_state *ss, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	void *ptr = snl_allocz(ss, nla->nla_len);

	if (ptr != NULL) {
		memcpy(ptr, nla, nla->nla_len);
		*((void **)target) = ptr;
		return (true);
	}
	return (false);
}

static inline bool
snl_attr_copy_struct(struct snl_state *ss, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	void *ptr = snl_allocz(ss, NLA_DATA_LEN(nla));

	if (ptr != NULL) {
		memcpy(ptr, NLA_DATA(nla), NLA_DATA_LEN(nla));
		*((void **)target) = ptr;
		return (true);
	}
	return (false);
}

static inline bool
snl_attr_dup_struct(struct snl_state *ss, struct nlattr *nla,
    const void *arg __unused, void *target)
{
	void *ptr = snl_allocz(ss, NLA_DATA_LEN(nla));

	if (ptr != NULL) {
		memcpy(ptr, NLA_DATA(nla), NLA_DATA_LEN(nla));
		*((void **)target) = ptr;
		return (true);
	}
	return (false);
}

struct snl_attr_bit {
	uint32_t	bit_index;
	char		*bit_name;
	int		bit_value;
};

struct snl_attr_bits {
	uint32_t num_bits;
	struct snl_attr_bit **bits;
};

#define	_OUT(_field)	offsetof(struct snl_attr_bit, _field)
static const struct snl_attr_parser _nla_p_bit[] = {
	{ .type = NLA_BITSET_BIT_INDEX, .off = _OUT(bit_index), .cb = snl_attr_get_uint32 },
	{ .type = NLA_BITSET_BIT_NAME, .off = _OUT(bit_name), .cb = snl_attr_dup_string },
	{ .type = NLA_BITSET_BIT_VALUE, .off = _OUT(bit_value), .cb = snl_attr_get_flag },
};
#undef _OUT
SNL_DECLARE_ATTR_PARSER_EXT(_nla_bit_parser, sizeof(struct snl_attr_bit), _nla_p_bit, NULL);

struct snl_attr_bitset {
	uint32_t		nla_bitset_size;
	uint32_t		*nla_bitset_mask;
	uint32_t		*nla_bitset_value;
	struct snl_attr_bits	bits;
};

#define	_OUT(_field)	offsetof(struct snl_attr_bitset, _field)
static const struct snl_attr_parser _nla_p_bitset[] = {
	{ .type = NLA_BITSET_SIZE, .off = _OUT(nla_bitset_size), .cb = snl_attr_get_uint32 },
	{ .type = NLA_BITSET_BITS, .off = _OUT(bits), .cb = snl_attr_get_parray, .arg = &_nla_bit_parser },
	{ .type = NLA_BITSET_VALUE, .off = _OUT(nla_bitset_mask), .cb = snl_attr_dup_nla },
	{ .type = NLA_BITSET_MASK, .off = _OUT(nla_bitset_value), .cb = snl_attr_dup_nla },
};

static inline bool
_cb_p_bitset(struct snl_state *ss __unused, void *_target)
{
	struct snl_attr_bitset *target = (struct snl_attr_bitset *)_target;

	uint32_t sz_bytes = _roundup2(target->nla_bitset_size, 32) / 8;

	if (target->nla_bitset_mask != NULL) {
		struct nlattr *nla = (struct nlattr *)target->nla_bitset_mask;
		uint32_t data_len = NLA_DATA_LEN(nla);

		if (data_len != sz_bytes || _roundup2(data_len, 4) != data_len)
			return (false);
		target->nla_bitset_mask = (uint32_t *)NLA_DATA(nla);
	}

	if (target->nla_bitset_value != NULL) {
		struct nlattr *nla = (struct nlattr *)target->nla_bitset_value;
		uint32_t data_len = NLA_DATA_LEN(nla);

		if (data_len != sz_bytes || _roundup2(data_len, 4) != data_len)
			return (false);
		target->nla_bitset_value = (uint32_t *)NLA_DATA(nla);
	}
	return (true);
}
#undef _OUT
SNL_DECLARE_ATTR_PARSER_EXT(_nla_bitset_parser,
		sizeof(struct snl_attr_bitset),
		_nla_p_bitset, _cb_p_bitset);

/*
 * Parses the compact bitset representation.
 */
static inline bool
snl_attr_get_bitset_c(struct snl_state *ss, struct nlattr *nla,
    const void *arg __unused, void *_target)
{
	const struct snl_hdr_parser *p = &_nla_bitset_parser;
	struct snl_attr_bitset *target = (struct snl_attr_bitset *)_target;

	/* Assumes target points to the beginning of the structure */
	if (!snl_parse_header(ss, NLA_DATA(nla), NLA_DATA_LEN(nla), p, _target))
		return (false);
	if (target->nla_bitset_mask == NULL || target->nla_bitset_value == NULL)
		return (false);
	return (true);
}

static inline void
snl_field_get_uint8(struct snl_state *ss __unused, void *src, void *target)
{
	*((uint8_t *)target) = *((uint8_t *)src);
}

static inline void
snl_field_get_uint16(struct snl_state *ss __unused, void *src, void *target)
{
	*((uint16_t *)target) = *((uint16_t *)src);
}

static inline void
snl_field_get_uint32(struct snl_state *ss __unused, void *src, void *target)
{
	*((uint32_t *)target) = *((uint32_t *)src);
}

static inline void
snl_field_get_ptr(struct snl_state *ss __unused, void *src, void *target)
{
	*((void **)target) = src;
}

struct snl_errmsg_data {
	struct nlmsghdr	*orig_hdr;
	int		error;
	uint32_t	error_offs;
	char		*error_str;
	struct nlattr	*cookie;
};

#define	_IN(_field)	offsetof(struct nlmsgerr, _field)
#define	_OUT(_field)	offsetof(struct snl_errmsg_data, _field)
static const struct snl_attr_parser nla_p_errmsg[] = {
	{ .type = NLMSGERR_ATTR_MSG, .off = _OUT(error_str), .cb = snl_attr_get_string },
	{ .type = NLMSGERR_ATTR_OFFS, .off = _OUT(error_offs), .cb = snl_attr_get_uint32 },
	{ .type = NLMSGERR_ATTR_COOKIE, .off = _OUT(cookie), .cb = snl_attr_get_nla },
};

static const struct snl_field_parser nlf_p_errmsg[] = {
	{ .off_in = _IN(error), .off_out = _OUT(error), .cb = snl_field_get_uint32 },
	{ .off_in = _IN(msg), .off_out = _OUT(orig_hdr), .cb = snl_field_get_ptr },
};
#undef _IN
#undef _OUT
SNL_DECLARE_PARSER(snl_errmsg_parser, struct nlmsgerr, nlf_p_errmsg, nla_p_errmsg);

#define	_IN(_field)	offsetof(struct nlmsgerr, _field)
#define	_OUT(_field)	offsetof(struct snl_errmsg_data, _field)
static const struct snl_field_parser nlf_p_donemsg[] = {
	{ .off_in = _IN(error), .off_out = _OUT(error), .cb = snl_field_get_uint32 },
};
#undef _IN
#undef _OUT
SNL_DECLARE_FIELD_PARSER(snl_donemsg_parser, struct nlmsgerr, nlf_p_donemsg);

static inline bool
snl_parse_errmsg(struct snl_state *ss, struct nlmsghdr *hdr, struct snl_errmsg_data *e)
{
	if ((hdr->nlmsg_flags & NLM_F_CAPPED) != 0)
		return (snl_parse_nlmsg(ss, hdr, &snl_errmsg_parser, e));

	const struct snl_hdr_parser *ps = &snl_errmsg_parser;
	struct nlmsgerr *errmsg = (struct nlmsgerr *)(hdr + 1);
	int hdrlen = sizeof(int) + NLMSG_ALIGN(errmsg->msg.nlmsg_len);
	struct nlattr *attr_head = (struct nlattr *)(void *)((char *)errmsg + hdrlen);
	int attr_len = hdr->nlmsg_len - sizeof(struct nlmsghdr) - hdrlen;

	snl_parse_fields(ss, (struct nlmsghdr *)errmsg, hdrlen, ps->fp, ps->fp_size, e);
	return (snl_parse_attrs_raw(ss, attr_head, attr_len, ps->np, ps->np_size, e));
}

static inline bool
snl_read_reply_code(struct snl_state *ss, uint32_t nlmsg_seq, struct snl_errmsg_data *e)
{
	struct nlmsghdr *hdr = snl_read_reply(ss, nlmsg_seq);

	if (hdr == NULL) {
		e->error = EINVAL;
	} else if (hdr->nlmsg_type == NLMSG_ERROR) {
		if (!snl_parse_errmsg(ss, hdr, e))
			e->error = EINVAL;
		return (e->error == 0);
	}

	return (false);
}

#define	_OUT(_field)	offsetof(struct snl_msg_info, _field)
static const struct snl_attr_parser _nla_p_cinfo[] = {
	{ .type = NLMSGINFO_ATTR_PROCESS_ID, .off = _OUT(process_id), .cb = snl_attr_get_uint32 },
	{ .type = NLMSGINFO_ATTR_PORT_ID, .off = _OUT(port_id), .cb = snl_attr_get_uint32 },
	{ .type = NLMSGINFO_ATTR_SEQ_ID, .off = _OUT(seq_id), .cb = snl_attr_get_uint32 },
};
#undef _OUT
SNL_DECLARE_ATTR_PARSER(snl_msg_info_parser, _nla_p_cinfo);

static inline bool
parse_cmsg(struct snl_state *ss, const struct msghdr *msg, struct snl_msg_info *attrs)
{
	for (struct cmsghdr *cmsg = CMSG_FIRSTHDR(msg); cmsg != NULL;
	    cmsg = CMSG_NXTHDR(msg, cmsg)) {
		if (cmsg->cmsg_level != SOL_NETLINK || cmsg->cmsg_type != NETLINK_MSG_INFO)
			continue;

		void *data = CMSG_DATA(cmsg);
		int len = cmsg->cmsg_len - ((char *)data - (char *)cmsg);
		const struct snl_hdr_parser *ps = &snl_msg_info_parser;

		return (snl_parse_attrs_raw(ss, (struct nlattr *)data, len, ps->np, ps->np_size, attrs));
	}

	return (false);
}

/*
 * Assumes e is zeroed
 */
static inline struct nlmsghdr *
snl_read_reply_multi(struct snl_state *ss, uint32_t nlmsg_seq, struct snl_errmsg_data *e)
{
	struct nlmsghdr *hdr = snl_read_reply(ss, nlmsg_seq);

	if (hdr == NULL) {
		e->error = EINVAL;
	} else if (hdr->nlmsg_type == NLMSG_ERROR) {
		if (!snl_parse_errmsg(ss, hdr, e))
			e->error = EINVAL;
	} else if (hdr->nlmsg_type == NLMSG_DONE) {
		snl_parse_nlmsg(ss, hdr, &snl_donemsg_parser, e);
	} else
		return (hdr);

	return (NULL);
}


/* writer logic */
struct snl_writer {
	char			*base;
	uint32_t		offset;
	uint32_t		size;
	struct nlmsghdr		*hdr;
	struct snl_state	*ss;
	bool			error;
};

static inline void
snl_init_writer(struct snl_state *ss, struct snl_writer *nw)
{
	nw->size = SNL_WRITER_BUFFER_SIZE;
	nw->base = (char *)snl_allocz(ss, nw->size);
	if (nw->base == NULL) {
		nw->error = true;
		nw->size = 0;
	}

	nw->offset = 0;
	nw->hdr = NULL;
	nw->error = false;
	nw->ss = ss;
}

static inline bool
snl_realloc_msg_buffer(struct snl_writer *nw, size_t sz)
{
	uint32_t new_size = nw->size * 2;

	while (new_size < nw->size + sz)
		new_size *= 2;

	if (nw->error)
		return (false);

	if (snl_allocz(nw->ss, new_size) == NULL) {
		nw->error = true;
		return (false);
	}
	nw->size = new_size;

	void *new_base = nw->ss->lb->base;
	if (new_base != nw->base) {
		memcpy(new_base, nw->base, nw->offset);
		if (nw->hdr != NULL) {
			int hdr_off = (char *)(nw->hdr) - nw->base;

			nw->hdr = (struct nlmsghdr *)
			    (void *)((char *)new_base + hdr_off);
		}
		nw->base = (char *)new_base;
	}

	return (true);
}

static inline void *
snl_reserve_msg_data_raw(struct snl_writer *nw, size_t sz)
{
	sz = NETLINK_ALIGN(sz);

        if (__predict_false(nw->offset + sz > nw->size)) {
		if (!snl_realloc_msg_buffer(nw, sz))
			return (NULL);
        }

        void *data_ptr = &nw->base[nw->offset];
        nw->offset += sz;

        return (data_ptr);
}
#define snl_reserve_msg_object(_ns, _t)	((_t *)snl_reserve_msg_data_raw(_ns, sizeof(_t)))
#define snl_reserve_msg_data(_ns, _sz, _t)	((_t *)snl_reserve_msg_data_raw(_ns, _sz))

static inline void *
_snl_reserve_msg_attr(struct snl_writer *nw, uint16_t nla_type, uint16_t sz)
{
	sz += sizeof(struct nlattr);

	struct nlattr *nla = snl_reserve_msg_data(nw, sz, struct nlattr);
	if (__predict_false(nla == NULL))
		return (NULL);
	nla->nla_type = nla_type;
	nla->nla_len = sz;

	return ((void *)(nla + 1));
}
#define	snl_reserve_msg_attr(_ns, _at, _t)	((_t *)_snl_reserve_msg_attr(_ns, _at, sizeof(_t)))

static inline bool
snl_add_msg_attr(struct snl_writer *nw, int attr_type, int attr_len, const void *data)
{
	int required_len = NLA_ALIGN(attr_len + sizeof(struct nlattr));

        if (__predict_false(nw->offset + required_len > nw->size)) {
		if (!snl_realloc_msg_buffer(nw, required_len))
			return (false);
	}

        struct nlattr *nla = (struct nlattr *)(void *)(&nw->base[nw->offset]);

        nla->nla_len = attr_len + sizeof(struct nlattr);
        nla->nla_type = attr_type;
        if (attr_len > 0) {
		if ((attr_len % 4) != 0) {
			/* clear padding bytes */
			bzero((char *)nla + required_len - 4, 4);
		}
                memcpy((nla + 1), data, attr_len);
	}
        nw->offset += required_len;
        return (true);
}

static inline bool
snl_add_msg_attr_raw(struct snl_writer *nw, const struct nlattr *nla_src)
{
	int attr_len = nla_src->nla_len - sizeof(struct nlattr);

	assert(attr_len >= 0);

	return (snl_add_msg_attr(nw, nla_src->nla_type, attr_len, (const void *)(nla_src + 1)));
}

static inline bool
snl_add_msg_attr_u8(struct snl_writer *nw, int attrtype, uint8_t value)
{
	return (snl_add_msg_attr(nw, attrtype, sizeof(uint8_t), &value));
}

static inline bool
snl_add_msg_attr_u16(struct snl_writer *nw, int attrtype, uint16_t value)
{
	return (snl_add_msg_attr(nw, attrtype, sizeof(uint16_t), &value));
}

static inline bool
snl_add_msg_attr_u32(struct snl_writer *nw, int attrtype, uint32_t value)
{
	return (snl_add_msg_attr(nw, attrtype, sizeof(uint32_t), &value));
}

static inline bool
snl_add_msg_attr_u64(struct snl_writer *nw, int attrtype, uint64_t value)
{
	return (snl_add_msg_attr(nw, attrtype, sizeof(uint64_t), &value));
}

static inline bool
snl_add_msg_attr_s8(struct snl_writer *nw, int attrtype, int8_t value)
{
	return (snl_add_msg_attr(nw, attrtype, sizeof(int8_t), &value));
}

static inline bool
snl_add_msg_attr_s16(struct snl_writer *nw, int attrtype, int16_t value)
{
	return (snl_add_msg_attr(nw, attrtype, sizeof(int16_t), &value));
}

static inline bool
snl_add_msg_attr_s32(struct snl_writer *nw, int attrtype, int32_t value)
{
	return (snl_add_msg_attr(nw, attrtype, sizeof(int32_t), &value));
}

static inline bool
snl_add_msg_attr_s64(struct snl_writer *nw, int attrtype, int64_t value)
{
	return (snl_add_msg_attr(nw, attrtype, sizeof(int64_t), &value));
}

static inline bool
snl_add_msg_attr_flag(struct snl_writer *nw, int attrtype)
{
	return (snl_add_msg_attr(nw, attrtype, 0, NULL));
}

static inline bool
snl_add_msg_attr_string(struct snl_writer *nw, int attrtype, const char *str)
{
	return (snl_add_msg_attr(nw, attrtype, strlen(str) + 1, str));
}


static inline int
snl_get_msg_offset(const struct snl_writer *nw)
{
        return (nw->offset - ((char *)nw->hdr - nw->base));
}

static inline void *
_snl_restore_msg_offset(const struct snl_writer *nw, int off)
{
	return ((void *)((char *)nw->hdr + off));
}
#define	snl_restore_msg_offset(_ns, _off, _t)	((_t *)_snl_restore_msg_offset(_ns, _off))

static inline int
snl_add_msg_attr_nested(struct snl_writer *nw, int attrtype)
{
	int off = snl_get_msg_offset(nw);
	struct nlattr *nla = snl_reserve_msg_data(nw, sizeof(struct nlattr), struct nlattr);
	if (__predict_false(nla == NULL))
		return (0);
	nla->nla_type = attrtype;
	return (off);
}

static inline void
snl_end_attr_nested(const struct snl_writer *nw, int off)
{
	if (!nw->error) {
		struct nlattr *nla = snl_restore_msg_offset(nw, off, struct nlattr);
		nla->nla_len = NETLINK_ALIGN(snl_get_msg_offset(nw) - off);
	}
}

static inline struct nlmsghdr *
snl_create_msg_request(struct snl_writer *nw, int nlmsg_type)
{
	assert(nw->hdr == NULL);

	struct nlmsghdr *hdr = snl_reserve_msg_object(nw, struct nlmsghdr);
	hdr->nlmsg_type = nlmsg_type;
	hdr->nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
	nw->hdr = hdr;

	return (hdr);
}

static void
snl_abort_msg(struct snl_writer *nw)
{
	if (nw->hdr != NULL) {
		int offset = (char *)(&nw->base[nw->offset]) - (char *)(nw->hdr);

		nw->offset -= offset;
		nw->hdr = NULL;
	}
}

static inline struct nlmsghdr *
snl_finalize_msg(struct snl_writer *nw)
{
	if (nw->error)
		snl_abort_msg(nw);
	if (nw->hdr != NULL) {
		struct nlmsghdr *hdr = nw->hdr;

		int offset = (char *)(&nw->base[nw->offset]) - (char *)(nw->hdr);
		hdr->nlmsg_len = offset;
		hdr->nlmsg_seq = snl_get_seq(nw->ss);
		nw->hdr = NULL;

		return (hdr);
	}
	return (NULL);
}

static inline bool
snl_send_msgs(struct snl_writer *nw)
{
	int offset = nw->offset;

	assert(nw->hdr == NULL);
	nw->offset = 0;

	return (snl_send(nw->ss, nw->base, offset));
}

static const struct snl_hdr_parser *snl_all_core_parsers[] = {
	&snl_errmsg_parser, &snl_donemsg_parser,
	&_nla_bit_parser, &_nla_bitset_parser,
};

#endif