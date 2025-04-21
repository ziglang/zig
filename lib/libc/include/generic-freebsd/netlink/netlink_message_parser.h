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

#ifndef _NETLINK_NETLINK_MESSAGE_PARSER_H_
#define _NETLINK_NETLINK_MESSAGE_PARSER_H_

#ifdef _KERNEL

#include <sys/bitset.h>

/*
 * It is not meant to be included directly
 */

/* Parsing state */
struct linear_buffer {
	char		*base;	/* Base allocated memory pointer */
	uint32_t	offset;	/* Currently used offset */
	uint32_t	size;	/* Total buffer size */
} __aligned(_Alignof(__max_align_t));

static inline void *
lb_alloc(struct linear_buffer *lb, int len)
{
	len = roundup2(len, _Alignof(__max_align_t));
	if (lb->offset + len > lb->size)
		return (NULL);
	void *data = (void *)(lb->base + lb->offset);
	lb->offset += len;
	return (data);
}

static inline void
lb_clear(struct linear_buffer *lb)
{
	memset(lb->base, 0, lb->size);
	lb->offset = 0;
}

#define	NL_MAX_ERROR_BUF	128
#define	SCRATCH_BUFFER_SIZE	(1024 + NL_MAX_ERROR_BUF)
struct nl_pstate {
        struct linear_buffer    lb;		/* Per-message scratch buffer */
        struct nlpcb		*nlp;		/* Originator socket */
	struct nl_writer	*nw;		/* Message writer to use */
	struct nlmsghdr		*hdr;		/* Current parsed message header */
	uint32_t		err_off;	/* error offset from hdr start */
        int			error;		/* last operation error */
	char			*err_msg;	/* Description of last error */
	struct nlattr		*cookie;	/* NLA to return to the userspace */
	bool			strict;		/* Strict parsing required */
};

static inline void *
npt_alloc(struct nl_pstate *npt, int len)
{
	return (lb_alloc(&npt->lb, len));
}
#define npt_alloc_sockaddr(_npt, _len)  ((struct sockaddr *)(npt_alloc(_npt, _len)))

typedef int parse_field_f(void *hdr, struct nl_pstate *npt,
    void *target);
struct nlfield_parser {
	uint16_t	off_in;
	uint16_t	off_out;
	parse_field_f	*cb;
};
static const struct nlfield_parser nlf_p_empty[] = {};

int nlf_get_ifp(void *src, struct nl_pstate *npt, void *target);
int nlf_get_ifpz(void *src, struct nl_pstate *npt, void *target);
int nlf_get_u8(void *src, struct nl_pstate *npt, void *target);
int nlf_get_u16(void *src, struct nl_pstate *npt, void *target);
int nlf_get_u32(void *src, struct nl_pstate *npt, void *target);
int nlf_get_u8_u32(void *src, struct nl_pstate *npt, void *target);


struct nlattr_parser;
typedef int parse_attr_f(struct nlattr *attr, struct nl_pstate *npt,
    const void *arg, void *target);
struct nlattr_parser {
	uint16_t			type;	/* Attribute type */
	uint16_t			off;	/* field offset in the target structure */
	parse_attr_f			*cb;	/* parser function to call */
	const void			*arg;
};

typedef bool strict_parser_f(void *hdr, struct nl_pstate *npt);
typedef bool post_parser_f(void *parsed_attrs, struct nl_pstate *npt);

struct nlhdr_parser {
	int				nl_hdr_off; /* aligned netlink header size */
	int				out_hdr_off; /* target header size */
	int				fp_size;
	int				np_size;
	const struct nlfield_parser	*fp; /* array of header field parsers */
	const struct nlattr_parser	*np; /* array of attribute parsers */
	strict_parser_f			*sp; /* Pre-parse strict validation function */
	post_parser_f			*post_parse;
};

#define	NL_DECLARE_PARSER_EXT(_name, _t, _sp, _fp, _np, _pp)	\
static const struct nlhdr_parser _name = {			\
	.nl_hdr_off = sizeof(_t),				\
	.fp = &((_fp)[0]),					\
	.np = &((_np)[0]),					\
	.fp_size = NL_ARRAY_LEN(_fp),				\
	.np_size = NL_ARRAY_LEN(_np),				\
	.sp = _sp,						\
	.post_parse = _pp,					\
}

#define	NL_DECLARE_PARSER(_name, _t, _fp, _np)			\
	NL_DECLARE_PARSER_EXT(_name, _t, NULL, _fp, _np, NULL)

#define	NL_DECLARE_STRICT_PARSER(_name, _t, _sp, _fp, _np)	\
	NL_DECLARE_PARSER_EXT(_name, _t, _sp, _fp, _np, NULL)

#define	NL_DECLARE_ARR_PARSER(_name, _t, _o, _fp, _np)	\
static const struct nlhdr_parser _name = {		\
	.nl_hdr_off = sizeof(_t),			\
	.out_hdr_off = sizeof(_o),			\
	.fp = &((_fp)[0]),				\
	.np = &((_np)[0]),				\
	.fp_size = NL_ARRAY_LEN(_fp),			\
	.np_size = NL_ARRAY_LEN(_np),			\
}

#define	NL_DECLARE_ATTR_PARSER(_name, _np)		\
static const struct nlhdr_parser _name = {		\
	.np = &((_np)[0]),				\
	.np_size = NL_ARRAY_LEN(_np),			\
}

#define	NL_ATTR_BMASK_SIZE	128
BITSET_DEFINE(nlattr_bmask, NL_ATTR_BMASK_SIZE);

void nl_get_attrs_bmask_raw(struct nlattr *nla_head, int len, struct nlattr_bmask *bm);
bool nl_has_attr(const struct nlattr_bmask *bm, unsigned int nla_type);

int nl_parse_attrs_raw(struct nlattr *nla_head, int len, const struct nlattr_parser *ps,
    int pslen, struct nl_pstate *npt, void *target);

int nlattr_get_flag(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_ip(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_uint8(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_uint16(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_uint32(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_uint64(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_in_addr(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_in6_addr(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_ifp(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_ifpz(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_ipvia(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_string(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_stringn(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_nla(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);
int nlattr_get_nested(struct nlattr *nla, struct nl_pstate *npt,
    const void *arg, void *target);

bool nlmsg_report_err_msg(struct nl_pstate *npt, const char *fmt, ...);

#define	NLMSG_REPORT_ERR_MSG(_npt, _fmt, ...) {	\
	nlmsg_report_err_msg(_npt, _fmt, ## __VA_ARGS__); \
	NLP_LOG(LOG_DEBUG, (_npt)->nlp, _fmt, ## __VA_ARGS__); \
}

bool nlmsg_report_err_offset(struct nl_pstate *npt, uint32_t off);

void nlmsg_report_cookie(struct nl_pstate *npt, struct nlattr *nla);
void nlmsg_report_cookie_u32(struct nl_pstate *npt, uint32_t val);

/*
 * Have it inline so compiler can optimize field accesses into
 * the list of direct function calls without iteration.
 */
static inline int
nl_parse_header(void *hdr, int len, const struct nlhdr_parser *parser,
    struct nl_pstate *npt, void *target)
{
	int error;

	if (__predict_false(len < parser->nl_hdr_off)) {
		if (npt->strict) {
			nlmsg_report_err_msg(npt, "header too short: expected %d, got %d",
			    parser->nl_hdr_off, len);
			return (EINVAL);
		}

		/* Compat with older applications: pretend there's a full header */
		void *tmp_hdr = npt_alloc(npt, parser->nl_hdr_off);
		if (tmp_hdr == NULL)
			return (EINVAL);
		memcpy(tmp_hdr, hdr, len);
		hdr = tmp_hdr;
		len = parser->nl_hdr_off;
	}

	if (npt->strict && parser->sp != NULL && !parser->sp(hdr, npt))
		return (EINVAL);

	/* Extract fields first */
	for (int i = 0; i < parser->fp_size; i++) {
		const struct nlfield_parser *fp = &parser->fp[i];
		void *src = (char *)hdr + fp->off_in;
		void *dst = (char *)target + fp->off_out;

		error = fp->cb(src, npt, dst);
		if (error != 0)
			return (error);
	}

	struct nlattr *nla_head = (struct nlattr *)((char *)hdr + parser->nl_hdr_off);
	error = nl_parse_attrs_raw(nla_head, len - parser->nl_hdr_off, parser->np,
	    parser->np_size, npt, target);

	if (parser->post_parse != NULL && error == 0) {
		if (!parser->post_parse(target, npt))
			return (EINVAL);
	}

	return (error);
}

static inline int
nl_parse_nested(struct nlattr *nla, const struct nlhdr_parser *parser,
    struct nl_pstate *npt, void *target)
{
	struct nlattr *nla_head = (struct nlattr *)NLA_DATA(nla);

	return (nl_parse_attrs_raw(nla_head, NLA_DATA_LEN(nla), parser->np,
	    parser->np_size, npt, target));
}

/*
 * Checks that attributes are sorted by attribute type.
 */
static inline void
nl_verify_parsers(const struct nlhdr_parser **parser, int count)
{
#ifdef INVARIANTS
	for (int i = 0; i < count; i++) {
		const struct nlhdr_parser *p = parser[i];
		int attr_type = 0;
		for (int j = 0; j < p->np_size; j++) {
			MPASS(p->np[j].type > attr_type);
			attr_type = p->np[j].type;
		}
	}
#endif
}
void nl_verify_parsers(const struct nlhdr_parser **parser, int count);
#define	NL_VERIFY_PARSERS(_p)	nl_verify_parsers((_p), NL_ARRAY_LEN(_p))

static inline int
nl_parse_nlmsg(struct nlmsghdr *hdr, const struct nlhdr_parser *parser,
    struct nl_pstate *npt, void *target)
{
	return (nl_parse_header(hdr + 1, hdr->nlmsg_len - sizeof(*hdr), parser, npt, target));
}

static inline void
nl_get_attrs_bmask_nlmsg(struct nlmsghdr *hdr, const struct nlhdr_parser *parser,
    struct nlattr_bmask *bm)
{
	struct nlattr *nla_head;

	nla_head = (struct nlattr *)((char *)(hdr + 1) + parser->nl_hdr_off);
	int len = hdr->nlmsg_len - sizeof(*hdr) - parser->nl_hdr_off;

	nl_get_attrs_bmask_raw(nla_head, len, bm);
}

#endif
#endif