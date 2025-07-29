/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2002 Ericsson Research & Pekka Nikander
 * Copyright (c) 2020 Nick Hibma <n_hibma@FreeBSD.org>
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice unmodified, this list of conditions, and the following
 *    disclaimer.
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
 */

#ifndef _NETGRAPH_MACFILTER_H_
#define _NETGRAPH_MACFILTER_H_

#define NG_MACFILTER_NODE_TYPE		"macfilter"
#define NGM_MACFILTER_COOKIE 		1042445461

/* Hook names */
#define NG_MACFILTER_HOOK_ETHER		"ether"         /* connected to ether:lower */
#define NG_MACFILTER_HOOK_DEFAULT 	"default"       /* connected to ether:upper; upper[0] */
/* Other hooks may be named freely                         connected to ether:upper; upper[1..n]*/
#define NG_MACFILTER_HOOK_DEFAULT_ID    0

#define OFFSETOF(s, e) ((char *)&((s *)0)->e - (char *)((s *)0))

/* Netgraph commands understood/sent by this node type */
enum {
    NGM_MACFILTER_RESET = 1,
    NGM_MACFILTER_DIRECT = 2,
    NGM_MACFILTER_DIRECT_HOOKID = 3,
    NGM_MACFILTER_GET_MACS = 4,
    NGM_MACFILTER_GETCLR_MACS = 5,
    NGM_MACFILTER_CLR_MACS = 6,
    NGM_MACFILTER_GET_HOOKS = 7
};

/* This structure is supplied with the NGM_MACFILTER_DIRECT command */
struct ngm_macfilter_direct {
    u_char	ether[ETHER_ADDR_LEN];  	/* MAC address */
    u_char	hookname[NG_HOOKSIZ];   	/* Upper hook name*/
};
#define NGM_MACFILTER_DIRECT_FIELDS {                   \
    { "ether",          &ng_parse_enaddr_type },        \
    { "hookname",       &ng_parse_hookbuf_type },       \
    { NULL }                                            \
}

/* This structure is supplied with the NGM_MACFILTER_DIRECT_HOOKID command */
struct ngm_macfilter_direct_hookid {
    u_char	ether[ETHER_ADDR_LEN];  	/* MAC address */
    u_int16_t	hookid;		        	/* Upper hook hookid */
};
#define NGM_MACFILTER_DIRECT_NDX_FIELDS {               \
    { "ether",          &ng_parse_enaddr_type },        \
    { "hookid",         &ng_parse_uint16_type },        \
    { NULL }                                            \
}

/* This structure is returned in the array by the NGM_MACFILTER_GET(CLR)_MACS commands */
struct ngm_macfilter_mac {
    u_char	ether[ETHER_ADDR_LEN];  	/* MAC address */
    u_int16_t	hookid;		        	/* Upper hook hookid */
    u_int64_t	packets_in;			/* packets in from downstream */
    u_int64_t	bytes_in;			/* bytes in from upstream */
    u_int64_t	packets_out;			/* packets out towards downstream */
    u_int64_t	bytes_out;			/* bytes out towards downstream */
};
#define NGM_MACFILTER_MAC_FIELDS {                      \
    { "ether",          &ng_parse_enaddr_type },        \
    { "hookid",         &ng_parse_uint16_type },        \
    { "packets_in",	&ng_parse_uint64_type },        \
    { "bytes_in",  	&ng_parse_uint64_type },        \
    { "packets_out",    &ng_parse_uint64_type },        \
    { "bytes_out",      &ng_parse_uint64_type },        \
    { NULL }                                            \
}
/* This structure is returned by the NGM_MACFILTER_GET(CLR)_MACS commands */
struct ngm_macfilter_macs {
    u_int32_t   n;                              /* Number of entries in macs */
    struct ngm_macfilter_mac macs[];            /* Macs table */
};
#define NGM_MACFILTER_MACS_FIELDS {                     \
    { "n",              &ng_parse_uint32_type },        \
    { "macs",           &ng_macfilter_macs_array_type },\
    { NULL }                                            \
}

/* This structure is returned in an array by the NGM_MACFILTER_GET_HOOKS command */
struct ngm_macfilter_hook {
    u_char	hookname[NG_HOOKSIZ];   	/* Upper hook name*/
    u_int16_t	hookid;		        	/* Upper hook hookid */
    u_int32_t   maccnt;                         /* Number of mac addresses associated with hook */
};
#define NGM_MACFILTER_HOOK_FIELDS {                     \
    { "hookname",       &ng_parse_hookbuf_type },       \
    { "hookid",         &ng_parse_uint16_type },        \
    { "maccnt",         &ng_parse_uint32_type },        \
    { NULL }                                            \
}
/* This structure is returned by the NGM_MACFILTER_GET_HOOKS command */
struct ngm_macfilter_hooks {
    u_int32_t   n;                              /* Number of entries in hooks */
    struct ngm_macfilter_hook hooks[];          /* Hooks table */
};
#define NGM_MACFILTER_HOOKS_FIELDS {                     \
    { "n",              &ng_parse_uint32_type },         \
    { "hooks",          &ng_macfilter_hooks_array_type },\
    { NULL }                                             \
}

#endif /* _NETGRAPH_MACFILTER_H_ */