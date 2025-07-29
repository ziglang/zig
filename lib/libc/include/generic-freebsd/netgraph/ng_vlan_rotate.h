/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019-2021 IKS Service GmbH
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
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * Author: Lutz Donnerhacke <lutz@donnerhacke.de>
 */

#ifndef _NETGRAPH_NG_VLAN_ROTATE_H_
#define _NETGRAPH_NG_VLAN_ROTATE_H_

#define NG_VLANROTATE_NODE_TYPE		"vlan_rotate"
#define NGM_VLANROTATE_COOKIE		1568378766

/* Hook names */
#define NG_VLANROTATE_HOOK_ORDERED	"ordered"
#define NG_VLANROTATE_HOOK_ORIGINAL	"original"
#define NG_VLANROTATE_HOOK_EXCESSIVE	"excessive"
#define NG_VLANROTATE_HOOK_INCOMPLETE	"incomplete"

/* Limits */
#define NG_VLANROTATE_MAX_VLANS		10

/* Datastructures for netgraph commands */
struct ng_vlanrotate_conf {
	int8_t		rot;
	uint8_t		min, max;
};

struct ng_vlanrotate_stat {
	uint64_t	drops, excessive, incomplete;
	uint64_t	histogram[NG_VLANROTATE_MAX_VLANS];
};

/* Netgraph commands understood by this node type */
enum {
	NGM_VLANROTATE_GET_CONF = 1,
	NGM_VLANROTATE_SET_CONF,
	NGM_VLANROTATE_GET_STAT,
	NGM_VLANROTATE_CLR_STAT,
	NGM_VLANROTATE_GETCLR_STAT
};

#endif				/* _NETGRAPH_NG_VLAN_ROTATE_H_ */