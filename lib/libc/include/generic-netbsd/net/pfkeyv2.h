/*	$NetBSD: pfkeyv2.h,v 1.34.2.1 2023/01/04 12:17:08 martin Exp $	*/
/*	$KAME: pfkeyv2.h,v 1.36 2003/07/25 09:33:37 itojun Exp $	*/

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

/*
 * This file has been derived rfc 2367,
 * And added some flags of SADB_KEY_FLAGS_ as SADB_X_EXT_.
 *	sakane@ydc.co.jp
 */

#ifndef _NET_PFKEYV2_H_
#define _NET_PFKEYV2_H_

/*
This file defines structures and symbols for the PF_KEY Version 2
key management interface. It was written at the U.S. Naval Research
Laboratory. This file is in the public domain. The authors ask that
you leave this credit intact on any copies of this file.
*/
#ifndef __PFKEY_V2_H
#define __PFKEY_V2_H 1

#define PF_KEY_V2 2
#define PFKEYV2_REVISION        199806L

#define SADB_RESERVED    0
#define SADB_GETSPI      1
#define SADB_UPDATE      2
#define SADB_ADD         3
#define SADB_DELETE      4
#define SADB_GET         5
#define SADB_ACQUIRE     6
#define SADB_REGISTER    7
#define SADB_EXPIRE      8
#define SADB_FLUSH       9
#define SADB_DUMP        10
#define SADB_X_PROMISC   11
#define SADB_X_PCHANGE   12

#define SADB_X_SPDUPDATE  13
#define SADB_X_SPDADD     14
#define SADB_X_SPDDELETE  15	/* by policy index */
#define SADB_X_SPDGET     16
#define SADB_X_SPDACQUIRE 17
#define SADB_X_SPDDUMP    18
#define SADB_X_SPDFLUSH   19
#define SADB_X_SPDSETIDX  20
#define SADB_X_SPDEXPIRE  21	/* not yet */
#define SADB_X_SPDDELETE2 22	/* by policy id */
#define SADB_X_NAT_T_NEW_MAPPING 23
#if 0
#define	SADB_X_MIGRATE    24	/* KAME */
#endif
#define SADB_MAX          23

struct sadb_msg {
  uint8_t sadb_msg_version;
  uint8_t sadb_msg_type;
  uint8_t sadb_msg_errno;
  uint8_t sadb_msg_satype;
  uint16_t sadb_msg_len;
  uint16_t sadb_msg_reserved;
  uint32_t sadb_msg_seq;
  uint32_t sadb_msg_pid;
};

struct sadb_ext {
  uint16_t sadb_ext_len;
  uint16_t sadb_ext_type;
};

struct sadb_sa {
  uint16_t sadb_sa_len;
  uint16_t sadb_sa_exttype;
  uint32_t sadb_sa_spi;
  uint8_t sadb_sa_replay;
  uint8_t sadb_sa_state;
  uint8_t sadb_sa_auth;
  uint8_t sadb_sa_encrypt;
  uint32_t sadb_sa_flags;
};

struct sadb_lifetime {
  uint16_t sadb_lifetime_len;
  uint16_t sadb_lifetime_exttype;
  uint32_t sadb_lifetime_allocations;
  uint64_t sadb_lifetime_bytes;
  uint64_t sadb_lifetime_addtime;
  uint64_t sadb_lifetime_usetime;
};

struct sadb_address {
  uint16_t sadb_address_len;
  uint16_t sadb_address_exttype;
  uint8_t sadb_address_proto;
  uint8_t sadb_address_prefixlen;
  uint16_t sadb_address_reserved;
};

struct sadb_key {
  uint16_t sadb_key_len;
  uint16_t sadb_key_exttype;
  uint16_t sadb_key_bits;
  uint16_t sadb_key_reserved;
};

struct sadb_ident {
  uint16_t sadb_ident_len;
  uint16_t sadb_ident_exttype;
  uint16_t sadb_ident_type;
  uint16_t sadb_ident_reserved;
  uint64_t sadb_ident_id;
};

struct sadb_sens {
  uint16_t sadb_sens_len;
  uint16_t sadb_sens_exttype;
  uint32_t sadb_sens_dpd;
  uint8_t sadb_sens_sens_level;
  uint8_t sadb_sens_sens_len;
  uint8_t sadb_sens_integ_level;
  uint8_t sadb_sens_integ_len;
  uint32_t sadb_sens_reserved;
};

struct sadb_prop {
  uint16_t sadb_prop_len;
  uint16_t sadb_prop_exttype;
  uint8_t sadb_prop_replay;
  uint8_t sadb_prop_reserved[3];
};

struct sadb_comb {
  uint8_t sadb_comb_auth;
  uint8_t sadb_comb_encrypt;
  uint16_t sadb_comb_flags;
  uint16_t sadb_comb_auth_minbits;
  uint16_t sadb_comb_auth_maxbits;
  uint16_t sadb_comb_encrypt_minbits;
  uint16_t sadb_comb_encrypt_maxbits;
  uint32_t sadb_comb_reserved;
  uint32_t sadb_comb_soft_allocations;
  uint32_t sadb_comb_hard_allocations;
  uint64_t sadb_comb_soft_bytes;
  uint64_t sadb_comb_hard_bytes;
  uint64_t sadb_comb_soft_addtime;
  uint64_t sadb_comb_hard_addtime;
  uint64_t sadb_comb_soft_usetime;
  uint64_t sadb_comb_hard_usetime;
};

struct sadb_supported {
  uint16_t sadb_supported_len;
  uint16_t sadb_supported_exttype;
  uint32_t sadb_supported_reserved;
};

struct sadb_alg {
  uint8_t sadb_alg_id;
  uint8_t sadb_alg_ivlen;
  uint16_t sadb_alg_minbits;
  uint16_t sadb_alg_maxbits;
  uint16_t sadb_alg_reserved;
};

struct sadb_spirange {
  uint16_t sadb_spirange_len;
  uint16_t sadb_spirange_exttype;
  uint32_t sadb_spirange_min;
  uint32_t sadb_spirange_max;
  uint32_t sadb_spirange_reserved;
};

struct sadb_x_kmprivate {
  uint16_t sadb_x_kmprivate_len;
  uint16_t sadb_x_kmprivate_exttype;
  uint32_t sadb_x_kmprivate_reserved;
};

/*
 * XXX Additional SA Extension.
 * mode: tunnel or transport
 * reqid: to make SA unique nevertheless the address pair of SA are same.
 *        Mainly it's for VPN.
 */
struct sadb_x_sa2 {
  uint16_t sadb_x_sa2_len;
  uint16_t sadb_x_sa2_exttype;
  uint8_t sadb_x_sa2_mode;
  uint8_t sadb_x_sa2_reserved1;
  uint16_t sadb_x_sa2_reserved2;
  uint32_t sadb_x_sa2_sequence;
  uint32_t sadb_x_sa2_reqid;		/* topmost 16bits are always 0 */
};

/* XXX Policy Extension */
/* sizeof(struct sadb_x_policy) == 16 */
struct sadb_x_policy {
  uint16_t sadb_x_policy_len;
  uint16_t sadb_x_policy_exttype;
  uint16_t sadb_x_policy_type;		/* See policy type of ipsec.h */
  uint8_t sadb_x_policy_dir;		/* direction, see ipsec.h */
  uint8_t sadb_x_policy_flags;
#define IPSEC_POLICY_FLAG_ORIGIN_KERNEL 0x80	/* policy is generated by kernel */
#define	sadb_x_policy_reserved	sadb_x_policy_flags
  uint32_t sadb_x_policy_id;
  uint32_t sadb_x_policy_reserved2;
};
/*
 * When policy_type == IPSEC, it is followed by some of
 * the ipsec policy request.
 * [total length of ipsec policy requests]
 *	= (sadb_x_policy_len * sizeof(uint64_t) - sizeof(struct sadb_x_policy))
 */

/* XXX IPsec Policy Request Extension */
/*
 * This structure is aligned 8 bytes.
 */
struct sadb_x_ipsecrequest {
  uint16_t sadb_x_ipsecrequest_len;	/* structure length in 64 bits. */
  uint16_t sadb_x_ipsecrequest_proto;	/* See ipsec.h */
  uint8_t sadb_x_ipsecrequest_mode;	/* See IPSEC_MODE_XX in ipsec.h. */
  uint8_t sadb_x_ipsecrequest_level;	/* See IPSEC_LEVEL_XX in ipsec.h */
  uint16_t sadb_x_ipsecrequest_reqid;	/* See ipsec.h */

  /*
   * followed by source IP address of SA, and immediately followed by
   * destination IP address of SA.  These encoded into two of sockaddr
   * structure without any padding.  Must set each sa_len exactly.
   * Each of length of the sockaddr structure are not aligned to 64bits,
   * but sum of x_request and addresses is aligned to 64bits.
   */
};

/* NAT traversal type, see draft-ietf-ipsec-udp-encaps-06 */
/* sizeof(struct sadb_x_nat_t_type) == 8 */
struct sadb_x_nat_t_type {
  uint16_t sadb_x_nat_t_type_len;
  uint16_t sadb_x_nat_t_type_exttype;
  uint8_t sadb_x_nat_t_type_type;
  uint8_t sadb_x_nat_t_type_reserved[3];
};

/* NAT traversal source or destination port */
/* sizeof(struct sadb_x_nat_t_port) == 8 */
struct sadb_x_nat_t_port {
  uint16_t sadb_x_nat_t_port_len;
  uint16_t sadb_x_nat_t_port_exttype;
  uint16_t sadb_x_nat_t_port_port;
  uint16_t sadb_x_nat_t_port_reserved;
};

/* ESP fragmentation size */
/* sizeof(struct sadb_x_nat_t_frag) == 8 */
struct sadb_x_nat_t_frag {
  uint16_t sadb_x_nat_t_frag_len;
  uint16_t sadb_x_nat_t_frag_exttype;
  uint16_t sadb_x_nat_t_frag_fraglen;
  uint16_t sadb_x_nat_t_frag_reserved;
};


#define SADB_EXT_RESERVED             0
#define SADB_EXT_SA                   1
#define SADB_EXT_LIFETIME_CURRENT     2
#define SADB_EXT_LIFETIME_HARD        3
#define SADB_EXT_LIFETIME_SOFT        4
#define SADB_EXT_ADDRESS_SRC          5
#define SADB_EXT_ADDRESS_DST          6
#define SADB_EXT_ADDRESS_PROXY        7
#define SADB_EXT_KEY_AUTH             8
#define SADB_EXT_KEY_ENCRYPT          9
#define SADB_EXT_IDENTITY_SRC         10
#define SADB_EXT_IDENTITY_DST         11
#define SADB_EXT_SENSITIVITY          12
#define SADB_EXT_PROPOSAL             13
#define SADB_EXT_SUPPORTED_AUTH       14
#define SADB_EXT_SUPPORTED_ENCRYPT    15
#define SADB_EXT_SPIRANGE             16
#define SADB_X_EXT_KMPRIVATE          17
#define SADB_X_EXT_POLICY             18
#define SADB_X_EXT_SA2                19
#define SADB_X_EXT_NAT_T_TYPE         20
#define SADB_X_EXT_NAT_T_SPORT        21
#define SADB_X_EXT_NAT_T_DPORT        22
#define SADB_X_EXT_NAT_T_OA           23	/* compat */
#define SADB_X_EXT_NAT_T_OAI          23
#define SADB_X_EXT_NAT_T_OAR          24
#define SADB_X_EXT_NAT_T_FRAG	      25
#if 0
#define	SADB_X_EXT_TAG		      25	/* KAME */
#define	SADB_X_EXT_SA3		      26	/* KAME */
#define	SADB_X_EXT_PACKET	      27	/* KAME */
#endif
#define SADB_EXT_MAX                  25

#define SADB_SATYPE_UNSPEC	0
#define SADB_SATYPE_AH		2
#define SADB_SATYPE_ESP		3
#define SADB_SATYPE_RSVP	5
#define SADB_SATYPE_OSPFV2	6
#define SADB_SATYPE_RIPV2	7
#define SADB_SATYPE_MIP		8
#define SADB_X_SATYPE_IPCOMP	9
/*#define SADB_X_SATYPE_POLICY	10	obsolete, do not reuse */
#define SADB_X_SATYPE_TCPSIGNATURE	11
#define SADB_SATYPE_MAX		12

#define SADB_SASTATE_LARVAL   0
#define SADB_SASTATE_MATURE   1
#define SADB_SASTATE_DYING    2
#define SADB_SASTATE_DEAD     3
#define SADB_SASTATE_MAX      3

#define SADB_SASTATE_USABLE_P(sav) \
    ((sav)->state == SADB_SASTATE_MATURE || (sav)->state == SADB_SASTATE_DYING)

#define SADB_SAFLAGS_PFS      1

/*
 * Statistics variable definitions. For ESP/AH/IPCOMP we define
 * indirection arrays of 256 elements indexed by algorithm (which
 * is uint8_t. All unknown/unhandled entries are summed in the 0th
 * element. We provide three variables per protocol:
 * 	1. *_STATS_INIT: a list of initializers
 * 	2. *_STATS_NUM: number of algorithms/statistics including (0/unknown)
 *	3. *_STATS_STR: a list of strings to symbolically print the statistics
 */

/* RFC2367 numbers - meets RFC2407 */
#define SADB_AALG_NONE		0
#define SADB_AALG_MD5HMAC	2
#define SADB_AALG_SHA1HMAC	3
#define SADB_AALG_MAX		251
/* private allocations - based on RFC2407/IANA assignment */
#define SADB_X_AALG_SHA2_256	5
#define SADB_X_AALG_SHA2_384	6
#define SADB_X_AALG_SHA2_512	7
#define SADB_X_AALG_RIPEMD160HMAC 8
#define SADB_X_AALG_AES_XCBC_MAC 9 /* RFC3566 */
#define SADB_X_AALG_AES128GMAC	11 /* RFC4543 + Errata1821 */
#define SADB_X_AALG_AES192GMAC	12
#define SADB_X_AALG_AES256GMAC	13
/* private allocations should use 249-255 (RFC2407) */
#define SADB_X_AALG_MD5		249	/* Keyed MD5 */
#define SADB_X_AALG_SHA		250	/* Keyed SHA */
#define SADB_X_AALG_NULL	251	/* null authentication */
#define SADB_X_AALG_TCP_MD5	252	/* Keyed TCP-MD5 (RFC2385) */


#define SADB_AALG_STATS_INIT \
    [SADB_AALG_NONE] = 1, \
    [SADB_AALG_MD5HMAC] = 2, \
    [SADB_AALG_SHA1HMAC] = 3, \
    [SADB_X_AALG_SHA2_256] = 4, \
    [SADB_X_AALG_SHA2_384] = 5, \
    [SADB_X_AALG_SHA2_512] = 6, \
    [SADB_X_AALG_RIPEMD160HMAC] = 7, \
    [SADB_X_AALG_AES_XCBC_MAC] = 8, \
    [SADB_X_AALG_AES128GMAC] = 9, \
    [SADB_X_AALG_AES192GMAC] = 10, \
    [SADB_X_AALG_AES256GMAC] = 11, \
    [SADB_X_AALG_MD5] = 12, \
    [SADB_X_AALG_SHA] = 13, \
    [SADB_X_AALG_NULL] = 14, \
    [SADB_X_AALG_TCP_MD5] = 15,

#define SADB_AALG_STATS_NUM 16
#define SADB_AALG_STATS_STR \
    "*unknown*", \
    "none", \
    "hmac-md5", \
    "hmac-sha1", \
    "hmac-sha2-256", \
    "hmac-sha2-384", \
    "hmac-sha2-512", \
    "hmac-ripe-md160", \
    "aes-xbc-mac", \
    "aes-128-mac", \
    "aes-192-mac", \
    "aes-256-mac", \
    "md5", \
    "sha", \
    "null", \
    "tcp-md5",

/* RFC2367 numbers - meets RFC2407 */
#define SADB_EALG_NONE		0
#define SADB_EALG_DESCBC	2
#define SADB_EALG_3DESCBC	3
#define SADB_EALG_NULL		11
#define SADB_EALG_MAX		250
/* private allocations - based on RFC2407/IANA assignment */
#define SADB_X_EALG_CAST128CBC	6
#define SADB_X_EALG_BLOWFISHCBC	7
#define SADB_X_EALG_RIJNDAELCBC	12
#define SADB_X_EALG_AES		12
#define SADB_X_EALG_AESCTR	13 /* RFC3686 */
#define SADB_X_EALG_AESGCM8	18 /* RFC4106 */
#define SADB_X_EALG_AESGCM12	19
#define SADB_X_EALG_AESGCM16	20
#define SADB_X_EALG_CAMELLIACBC	22 /* RFC4312 */
#define SADB_X_EALG_AESGMAC	23 /* RFC4543 + Errata1821 */
/* private allocations should use 249-255 (RFC2407) */
#define SADB_X_EALG_SKIPJACK    250

#define SADB_EALG_STATS_INIT \
    [SADB_EALG_NONE] = 1, \
    [SADB_EALG_DESCBC] = 2, \
    [SADB_EALG_3DESCBC] = 3, \
    [SADB_EALG_NULL] = 4, \
    [SADB_X_EALG_CAST128CBC] = 5, \
    [SADB_X_EALG_BLOWFISHCBC] = 6, \
    [SADB_X_EALG_RIJNDAELCBC] = 7, \
    [SADB_X_EALG_AESCTR] = 8, \
    [SADB_X_EALG_AESGCM8] = 9, \
    [SADB_X_EALG_AESGCM12] = 10, \
    [SADB_X_EALG_AESGCM16] = 11, \
    [SADB_X_EALG_CAMELLIACBC] = 12, \
    [SADB_X_EALG_AESGMAC] = 13, \
    [SADB_X_EALG_SKIPJACK] = 14,

#define SADB_EALG_STATS_NUM 15
#define SADB_EALG_STATS_STR \
    "*unknown*", \
    "none", \
    "des-cbc", \
    "3des-cbc", \
    "null", \
    "cast128-cbc", \
    "blowfish-cbc", \
    "aes-cbc", \
    "aes-ctr", \
    "aes-gcm-8", \
    "aes-gcm-12", \
    "aes-gcm-16", \
    "camelia-cbc", \
    "aes-gmac", \
    "skipjack",

/* private allocations - based on RFC2407/IANA assignment */
#define SADB_X_CALG_NONE	0
#define SADB_X_CALG_OUI		1
#define SADB_X_CALG_DEFLATE	2
#define SADB_X_CALG_LZS		3
#define SADB_X_CALG_MAX		4

#define SADB_CALG_STATS_INIT \
    [SADB_X_CALG_NONE] = 1, \
    [SADB_X_CALG_OUI] = 2, \
    [SADB_X_CALG_DEFLATE] = 3, \
    [SADB_X_CALG_LZS] = 4,

#define SADB_CALG_STATS_NUM 5

#define SADB_CALG_STATS_STR \
    "*unknown*", \
    "none", \
    "oui", \
    "deflate", \
    "lzs",


#define SADB_IDENTTYPE_RESERVED   0
#define SADB_IDENTTYPE_PREFIX     1
#define SADB_IDENTTYPE_FQDN       2
#define SADB_IDENTTYPE_USERFQDN   3
#define SADB_X_IDENTTYPE_ADDR     4
#define SADB_IDENTTYPE_MAX        4

/* `flags' in sadb_sa structure holds followings */
#define SADB_X_EXT_NONE		0x0000	/* i.e. new format. */
#define SADB_X_EXT_OLD		0x0001	/* old format. */

#define SADB_X_EXT_IV4B		0x0010	/* IV length of 4 bytes in use */
#define SADB_X_EXT_DERIV	0x0020	/* DES derived */
#define SADB_X_EXT_CYCSEQ	0x0040	/* allowing to cyclic sequence. */

	/* three of followings are exclusive flags each them */
#define SADB_X_EXT_PSEQ		0x0000	/* sequential padding for ESP */
#define SADB_X_EXT_PRAND	0x0100	/* random padding for ESP */
#define SADB_X_EXT_PZERO	0x0200	/* zero padding for ESP */
#define SADB_X_EXT_PMASK	0x0300	/* mask for padding flag */

#if 1
#define SADB_X_EXT_RAWCPI	0x0080	/* use well known CPI (IPComp) */
#endif

#define SADB_KEY_FLAGS_MAX	0x0fff

/* SPI size for PF_KEYv2 */
#define PFKEY_SPI_SIZE	sizeof(uint32_t)

/* Identifier for menber of lifetime structure */
#define SADB_X_LIFETIME_ALLOCATIONS	0
#define SADB_X_LIFETIME_BYTES		1
#define SADB_X_LIFETIME_ADDTIME		2
#define SADB_X_LIFETIME_USETIME		3

/* The rate for SOFT lifetime against HARD one. */
#define PFKEY_SOFT_LIFETIME_RATE	80

/* Utilities */
#define PFKEY_ALIGN8(a) (1 + (((a) - 1) | (8 - 1)))
#define	PFKEY_EXTLEN(msg) \
	PFKEY_UNUNIT64(((const struct sadb_ext *)(const void *)(msg))->sadb_ext_len)
#define PFKEY_ADDR_PREFIX(ext) \
	(((const struct sadb_address *)(const void *)(ext))->sadb_address_prefixlen)
#define PFKEY_ADDR_PROTO(ext) \
	(((const struct sadb_address *)(const void *)(ext))->sadb_address_proto)
#define PFKEY_ADDR_SADDR(ext) \
	((struct sockaddr *)(void *)((char *)(void *)(ext) + \
	sizeof(struct sadb_address)))

/* in 64bits */
#define	PFKEY_UNUNIT64(a)	((a) << 3)
#define	PFKEY_UNIT64(a)		((a) >> 3)

#endif /* __PFKEY_V2_H */

#endif /* !_NET_PFKEYV2_H_ */