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
#ifndef	_NETLINK_NETLINK_SNL_GENERIC_H_
#define	_NETLINK_NETLINK_SNL_GENERIC_H_

#include <netlink/netlink.h>
#include <netlink/netlink_generic.h>
#include <netlink/netlink_snl.h>

/* Genetlink helpers */
static inline struct nlmsghdr *
snl_create_genl_msg_request(struct snl_writer *nw, uint16_t genl_family,
    uint8_t genl_cmd)
{
	struct nlmsghdr *hdr;
	struct genlmsghdr *ghdr;

	assert(nw->hdr == NULL);

	hdr = snl_reserve_msg_object(nw, struct nlmsghdr);
	if (__predict_false(hdr == NULL))
		return (NULL);
	hdr->nlmsg_type = genl_family;
	hdr->nlmsg_flags = NLM_F_REQUEST | NLM_F_ACK;
	ghdr = snl_reserve_msg_object(nw, struct genlmsghdr);
	if (__predict_false(ghdr == NULL))
		return (NULL);
	ghdr->cmd = genl_cmd;
	nw->hdr = hdr;

	return (hdr);
}

static struct snl_field_parser snl_fp_genl[] = {};

#define	SNL_DECLARE_GENL_PARSER(_name, _np)	SNL_DECLARE_PARSER(_name,\
    struct genlmsghdr, snl_fp_genl, _np)

struct _snl_genl_ctrl_mcast_group {
	uint32_t mcast_grp_id;
	const char *mcast_grp_name;
};

struct _snl_genl_ctrl_mcast_groups {
	uint32_t num_groups;
	struct _snl_genl_ctrl_mcast_group **groups;
};

#define	_OUT(_field)	offsetof(struct _snl_genl_ctrl_mcast_group, _field)
static struct snl_attr_parser _nla_p_getmc[] = {
	{
		.type = CTRL_ATTR_MCAST_GRP_NAME,
		.off = _OUT(mcast_grp_name),
		.cb = snl_attr_get_string,
	},
	{
		.type = CTRL_ATTR_MCAST_GRP_ID,
		.off = _OUT(mcast_grp_id),
		.cb = snl_attr_get_uint32,
	},
};
#undef _OUT
SNL_DECLARE_ATTR_PARSER_EXT(_genl_ctrl_mc_parser,
    sizeof(struct _snl_genl_ctrl_mcast_group), _nla_p_getmc, NULL);

struct _getfamily_attrs {
	uint16_t family_id;
	const char *family_name;
	struct _snl_genl_ctrl_mcast_groups mcast_groups;
};

#define	_IN(_field)	offsetof(struct genlmsghdr, _field)
#define	_OUT(_field)	offsetof(struct _getfamily_attrs, _field)
static struct snl_attr_parser _nla_p_getfam[] = {
	{
		.type = CTRL_ATTR_FAMILY_ID,
		.off = _OUT(family_id),
		.cb = snl_attr_get_uint16,
	},
	{
		.type = CTRL_ATTR_FAMILY_NAME,
		.off = _OUT(family_name),
		.cb = snl_attr_get_string,
	},
	{
		.type = CTRL_ATTR_MCAST_GROUPS,
		.off = _OUT(mcast_groups),
		.cb = snl_attr_get_parray,
		.arg = &_genl_ctrl_mc_parser,
	},
};
#undef _IN
#undef _OUT
SNL_DECLARE_GENL_PARSER(_genl_ctrl_getfam_parser, _nla_p_getfam);

static bool
_snl_get_genl_family_info(struct snl_state *ss, const char *family_name,
    struct _getfamily_attrs *attrs)
{
	struct snl_writer nw;
	struct nlmsghdr *hdr;

	memset(attrs, 0, sizeof(*attrs));

	snl_init_writer(ss, &nw);
	snl_create_genl_msg_request(&nw, GENL_ID_CTRL, CTRL_CMD_GETFAMILY);
	snl_add_msg_attr_string(&nw, CTRL_ATTR_FAMILY_NAME, family_name);
	if ((hdr = snl_finalize_msg(&nw)) == NULL || !snl_send_message(ss, hdr))
		return (false);

	hdr = snl_read_reply(ss, hdr->nlmsg_seq);
	if (hdr != NULL && hdr->nlmsg_type != NLMSG_ERROR) {
		if (snl_parse_nlmsg(ss, hdr, &_genl_ctrl_getfam_parser, attrs))
			return (true);
	}

	return (false);
}

static inline uint16_t
snl_get_genl_family(struct snl_state *ss, const char *family_name)
{
	struct _getfamily_attrs attrs = {};

	if (__predict_false(!_snl_get_genl_family_info(ss, family_name,
	    &attrs)))
		return (0);
	return (attrs.family_id);
}

static inline uint16_t
snl_get_genl_mcast_group(struct snl_state *ss, const char *family_name,
    const char *group_name, uint16_t *family_id)
{
	struct _getfamily_attrs attrs = {};

	if (__predict_false(!_snl_get_genl_family_info(ss, family_name,
	    &attrs)))
		return (0);
	if (attrs.family_id == 0)
		return (0);
	if (family_id != NULL)
		*family_id = attrs.family_id;
	for (u_int i = 0; i < attrs.mcast_groups.num_groups; i++)
		if (strcmp(attrs.mcast_groups.groups[i]->mcast_grp_name,
                    group_name) == 0)
			return (attrs.mcast_groups.groups[i]->mcast_grp_id);
	return (0);
}

#endif