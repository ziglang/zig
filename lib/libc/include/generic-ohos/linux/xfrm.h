/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _LINUX_XFRM_H
#define _LINUX_XFRM_H
#include <linux/in6.h>
#include <linux/types.h>
typedef union {
  __be32 a4;
  __be32 a6[4];
  struct in6_addr in6;
} xfrm_address_t;
struct xfrm_id {
  xfrm_address_t daddr;
  __be32 spi;
  __u8 proto;
};
struct xfrm_sec_ctx {
  __u8 ctx_doi;
  __u8 ctx_alg;
  __u16 ctx_len;
  __u32 ctx_sid;
  char ctx_str[0];
};
#define XFRM_SC_DOI_RESERVED 0
#define XFRM_SC_DOI_LSM 1
#define XFRM_SC_ALG_RESERVED 0
#define XFRM_SC_ALG_SELINUX 1
struct xfrm_selector {
  xfrm_address_t daddr;
  xfrm_address_t saddr;
  __be16 dport;
  __be16 dport_mask;
  __be16 sport;
  __be16 sport_mask;
  __u16 family;
  __u8 prefixlen_d;
  __u8 prefixlen_s;
  __u8 proto;
  int ifindex;
  __kernel_uid32_t user;
};
#define XFRM_INF (~(__u64) 0)
struct xfrm_lifetime_cfg {
  __u64 soft_byte_limit;
  __u64 hard_byte_limit;
  __u64 soft_packet_limit;
  __u64 hard_packet_limit;
  __u64 soft_add_expires_seconds;
  __u64 hard_add_expires_seconds;
  __u64 soft_use_expires_seconds;
  __u64 hard_use_expires_seconds;
};
struct xfrm_lifetime_cur {
  __u64 bytes;
  __u64 packets;
  __u64 add_time;
  __u64 use_time;
};
struct xfrm_replay_state {
  __u32 oseq;
  __u32 seq;
  __u32 bitmap;
};
#define XFRMA_REPLAY_ESN_MAX 4096
struct xfrm_replay_state_esn {
  unsigned int bmp_len;
  __u32 oseq;
  __u32 seq;
  __u32 oseq_hi;
  __u32 seq_hi;
  __u32 replay_window;
  __u32 bmp[0];
};
struct xfrm_algo {
  char alg_name[64];
  unsigned int alg_key_len;
  char alg_key[0];
};
struct xfrm_algo_auth {
  char alg_name[64];
  unsigned int alg_key_len;
  unsigned int alg_trunc_len;
  char alg_key[0];
};
struct xfrm_algo_aead {
  char alg_name[64];
  unsigned int alg_key_len;
  unsigned int alg_icv_len;
  char alg_key[0];
};
struct xfrm_stats {
  __u32 replay_window;
  __u32 replay;
  __u32 integrity_failed;
};
enum {
  XFRM_POLICY_TYPE_MAIN = 0,
  XFRM_POLICY_TYPE_SUB = 1,
  XFRM_POLICY_TYPE_MAX = 2,
  XFRM_POLICY_TYPE_ANY = 255
};
enum {
  XFRM_POLICY_IN = 0,
  XFRM_POLICY_OUT = 1,
  XFRM_POLICY_FWD = 2,
  XFRM_POLICY_MASK = 3,
  XFRM_POLICY_MAX = 3
};
enum {
  XFRM_SHARE_ANY,
  XFRM_SHARE_SESSION,
  XFRM_SHARE_USER,
  XFRM_SHARE_UNIQUE
};
#define XFRM_MODE_TRANSPORT 0
#define XFRM_MODE_TUNNEL 1
#define XFRM_MODE_ROUTEOPTIMIZATION 2
#define XFRM_MODE_IN_TRIGGER 3
#define XFRM_MODE_BEET 4
#define XFRM_MODE_MAX 5
enum {
  XFRM_MSG_BASE = 0x10,
  XFRM_MSG_NEWSA = 0x10,
#define XFRM_MSG_NEWSA XFRM_MSG_NEWSA
  XFRM_MSG_DELSA,
#define XFRM_MSG_DELSA XFRM_MSG_DELSA
  XFRM_MSG_GETSA,
#define XFRM_MSG_GETSA XFRM_MSG_GETSA
  XFRM_MSG_NEWPOLICY,
#define XFRM_MSG_NEWPOLICY XFRM_MSG_NEWPOLICY
  XFRM_MSG_DELPOLICY,
#define XFRM_MSG_DELPOLICY XFRM_MSG_DELPOLICY
  XFRM_MSG_GETPOLICY,
#define XFRM_MSG_GETPOLICY XFRM_MSG_GETPOLICY
  XFRM_MSG_ALLOCSPI,
#define XFRM_MSG_ALLOCSPI XFRM_MSG_ALLOCSPI
  XFRM_MSG_ACQUIRE,
#define XFRM_MSG_ACQUIRE XFRM_MSG_ACQUIRE
  XFRM_MSG_EXPIRE,
#define XFRM_MSG_EXPIRE XFRM_MSG_EXPIRE
  XFRM_MSG_UPDPOLICY,
#define XFRM_MSG_UPDPOLICY XFRM_MSG_UPDPOLICY
  XFRM_MSG_UPDSA,
#define XFRM_MSG_UPDSA XFRM_MSG_UPDSA
  XFRM_MSG_POLEXPIRE,
#define XFRM_MSG_POLEXPIRE XFRM_MSG_POLEXPIRE
  XFRM_MSG_FLUSHSA,
#define XFRM_MSG_FLUSHSA XFRM_MSG_FLUSHSA
  XFRM_MSG_FLUSHPOLICY,
#define XFRM_MSG_FLUSHPOLICY XFRM_MSG_FLUSHPOLICY
  XFRM_MSG_NEWAE,
#define XFRM_MSG_NEWAE XFRM_MSG_NEWAE
  XFRM_MSG_GETAE,
#define XFRM_MSG_GETAE XFRM_MSG_GETAE
  XFRM_MSG_REPORT,
#define XFRM_MSG_REPORT XFRM_MSG_REPORT
  XFRM_MSG_MIGRATE,
#define XFRM_MSG_MIGRATE XFRM_MSG_MIGRATE
  XFRM_MSG_NEWSADINFO,
#define XFRM_MSG_NEWSADINFO XFRM_MSG_NEWSADINFO
  XFRM_MSG_GETSADINFO,
#define XFRM_MSG_GETSADINFO XFRM_MSG_GETSADINFO
  XFRM_MSG_NEWSPDINFO,
#define XFRM_MSG_NEWSPDINFO XFRM_MSG_NEWSPDINFO
  XFRM_MSG_GETSPDINFO,
#define XFRM_MSG_GETSPDINFO XFRM_MSG_GETSPDINFO
  XFRM_MSG_MAPPING,
#define XFRM_MSG_MAPPING XFRM_MSG_MAPPING
  __XFRM_MSG_MAX
};
#define XFRM_MSG_MAX (__XFRM_MSG_MAX - 1)
#define XFRM_NR_MSGTYPES (XFRM_MSG_MAX + 1 - XFRM_MSG_BASE)
struct xfrm_user_sec_ctx {
  __u16 len;
  __u16 exttype;
  __u8 ctx_alg;
  __u8 ctx_doi;
  __u16 ctx_len;
};
struct xfrm_user_tmpl {
  struct xfrm_id id;
  __u16 family;
  xfrm_address_t saddr;
  __u32 reqid;
  __u8 mode;
  __u8 share;
  __u8 optional;
  __u32 aalgos;
  __u32 ealgos;
  __u32 calgos;
};
struct xfrm_encap_tmpl {
  __u16 encap_type;
  __be16 encap_sport;
  __be16 encap_dport;
  xfrm_address_t encap_oa;
};
enum xfrm_ae_ftype_t {
  XFRM_AE_UNSPEC,
  XFRM_AE_RTHR = 1,
  XFRM_AE_RVAL = 2,
  XFRM_AE_LVAL = 4,
  XFRM_AE_ETHR = 8,
  XFRM_AE_CR = 16,
  XFRM_AE_CE = 32,
  XFRM_AE_CU = 64,
  __XFRM_AE_MAX
#define XFRM_AE_MAX (__XFRM_AE_MAX - 1)
};
struct xfrm_userpolicy_type {
  __u8 type;
  __u16 reserved1;
  __u8 reserved2;
};
enum xfrm_attr_type_t {
  XFRMA_UNSPEC,
  XFRMA_ALG_AUTH,
  XFRMA_ALG_CRYPT,
  XFRMA_ALG_COMP,
  XFRMA_ENCAP,
  XFRMA_TMPL,
  XFRMA_SA,
  XFRMA_POLICY,
  XFRMA_SEC_CTX,
  XFRMA_LTIME_VAL,
  XFRMA_REPLAY_VAL,
  XFRMA_REPLAY_THRESH,
  XFRMA_ETIMER_THRESH,
  XFRMA_SRCADDR,
  XFRMA_COADDR,
  XFRMA_LASTUSED,
  XFRMA_POLICY_TYPE,
  XFRMA_MIGRATE,
  XFRMA_ALG_AEAD,
  XFRMA_KMADDRESS,
  XFRMA_ALG_AUTH_TRUNC,
  XFRMA_MARK,
  XFRMA_TFCPAD,
  XFRMA_REPLAY_ESN_VAL,
  XFRMA_SA_EXTRA_FLAGS,
  XFRMA_PROTO,
  XFRMA_ADDRESS_FILTER,
  XFRMA_PAD,
  XFRMA_OFFLOAD_DEV,
  XFRMA_SET_MARK,
  XFRMA_SET_MARK_MASK,
  XFRMA_IF_ID,
  __XFRMA_MAX
#define XFRMA_OUTPUT_MARK XFRMA_SET_MARK
#define XFRMA_MAX (__XFRMA_MAX - 1)
};
struct xfrm_mark {
  __u32 v;
  __u32 m;
};
enum xfrm_sadattr_type_t {
  XFRMA_SAD_UNSPEC,
  XFRMA_SAD_CNT,
  XFRMA_SAD_HINFO,
  __XFRMA_SAD_MAX
#define XFRMA_SAD_MAX (__XFRMA_SAD_MAX - 1)
};
struct xfrmu_sadhinfo {
  __u32 sadhcnt;
  __u32 sadhmcnt;
};
enum xfrm_spdattr_type_t {
  XFRMA_SPD_UNSPEC,
  XFRMA_SPD_INFO,
  XFRMA_SPD_HINFO,
  XFRMA_SPD_IPV4_HTHRESH,
  XFRMA_SPD_IPV6_HTHRESH,
  __XFRMA_SPD_MAX
#define XFRMA_SPD_MAX (__XFRMA_SPD_MAX - 1)
};
struct xfrmu_spdinfo {
  __u32 incnt;
  __u32 outcnt;
  __u32 fwdcnt;
  __u32 inscnt;
  __u32 outscnt;
  __u32 fwdscnt;
};
struct xfrmu_spdhinfo {
  __u32 spdhcnt;
  __u32 spdhmcnt;
};
struct xfrmu_spdhthresh {
  __u8 lbits;
  __u8 rbits;
};
struct xfrm_usersa_info {
  struct xfrm_selector sel;
  struct xfrm_id id;
  xfrm_address_t saddr;
  struct xfrm_lifetime_cfg lft;
  struct xfrm_lifetime_cur curlft;
  struct xfrm_stats stats;
  __u32 seq;
  __u32 reqid;
  __u16 family;
  __u8 mode;
  __u8 replay_window;
  __u8 flags;
#define XFRM_STATE_NOECN 1
#define XFRM_STATE_DECAP_DSCP 2
#define XFRM_STATE_NOPMTUDISC 4
#define XFRM_STATE_WILDRECV 8
#define XFRM_STATE_ICMP 16
#define XFRM_STATE_AF_UNSPEC 32
#define XFRM_STATE_ALIGN4 64
#define XFRM_STATE_ESN 128
};
#define XFRM_SA_XFLAG_DONT_ENCAP_DSCP 1
#define XFRM_SA_XFLAG_OSEQ_MAY_WRAP 2
struct xfrm_usersa_id {
  xfrm_address_t daddr;
  __be32 spi;
  __u16 family;
  __u8 proto;
};
struct xfrm_aevent_id {
  struct xfrm_usersa_id sa_id;
  xfrm_address_t saddr;
  __u32 flags;
  __u32 reqid;
};
struct xfrm_userspi_info {
  struct xfrm_usersa_info info;
  __u32 min;
  __u32 max;
};
struct xfrm_userpolicy_info {
  struct xfrm_selector sel;
  struct xfrm_lifetime_cfg lft;
  struct xfrm_lifetime_cur curlft;
  __u32 priority;
  __u32 index;
  __u8 dir;
  __u8 action;
#define XFRM_POLICY_ALLOW 0
#define XFRM_POLICY_BLOCK 1
  __u8 flags;
#define XFRM_POLICY_LOCALOK 1
#define XFRM_POLICY_ICMP 2
  __u8 share;
};
struct xfrm_userpolicy_id {
  struct xfrm_selector sel;
  __u32 index;
  __u8 dir;
};
struct xfrm_user_acquire {
  struct xfrm_id id;
  xfrm_address_t saddr;
  struct xfrm_selector sel;
  struct xfrm_userpolicy_info policy;
  __u32 aalgos;
  __u32 ealgos;
  __u32 calgos;
  __u32 seq;
};
struct xfrm_user_expire {
  struct xfrm_usersa_info state;
  __u8 hard;
};
struct xfrm_user_polexpire {
  struct xfrm_userpolicy_info pol;
  __u8 hard;
};
struct xfrm_usersa_flush {
  __u8 proto;
};
struct xfrm_user_report {
  __u8 proto;
  struct xfrm_selector sel;
};
struct xfrm_user_kmaddress {
  xfrm_address_t local;
  xfrm_address_t remote;
  __u32 reserved;
  __u16 family;
};
struct xfrm_user_migrate {
  xfrm_address_t old_daddr;
  xfrm_address_t old_saddr;
  xfrm_address_t new_daddr;
  xfrm_address_t new_saddr;
  __u8 proto;
  __u8 mode;
  __u16 reserved;
  __u32 reqid;
  __u16 old_family;
  __u16 new_family;
};
struct xfrm_user_mapping {
  struct xfrm_usersa_id id;
  __u32 reqid;
  xfrm_address_t old_saddr;
  xfrm_address_t new_saddr;
  __be16 old_sport;
  __be16 new_sport;
};
struct xfrm_address_filter {
  xfrm_address_t saddr;
  xfrm_address_t daddr;
  __u16 family;
  __u8 splen;
  __u8 dplen;
};
struct xfrm_user_offload {
  int ifindex;
  __u8 flags;
};
#define XFRM_OFFLOAD_IPV6 1
#define XFRM_OFFLOAD_INBOUND 2
#define XFRMGRP_ACQUIRE 1
#define XFRMGRP_EXPIRE 2
#define XFRMGRP_SA 4
#define XFRMGRP_POLICY 8
#define XFRMGRP_REPORT 0x20
enum xfrm_nlgroups {
  XFRMNLGRP_NONE,
#define XFRMNLGRP_NONE XFRMNLGRP_NONE
  XFRMNLGRP_ACQUIRE,
#define XFRMNLGRP_ACQUIRE XFRMNLGRP_ACQUIRE
  XFRMNLGRP_EXPIRE,
#define XFRMNLGRP_EXPIRE XFRMNLGRP_EXPIRE
  XFRMNLGRP_SA,
#define XFRMNLGRP_SA XFRMNLGRP_SA
  XFRMNLGRP_POLICY,
#define XFRMNLGRP_POLICY XFRMNLGRP_POLICY
  XFRMNLGRP_AEVENTS,
#define XFRMNLGRP_AEVENTS XFRMNLGRP_AEVENTS
  XFRMNLGRP_REPORT,
#define XFRMNLGRP_REPORT XFRMNLGRP_REPORT
  XFRMNLGRP_MIGRATE,
#define XFRMNLGRP_MIGRATE XFRMNLGRP_MIGRATE
  XFRMNLGRP_MAPPING,
#define XFRMNLGRP_MAPPING XFRMNLGRP_MAPPING
  __XFRMNLGRP_MAX
};
#define XFRMNLGRP_MAX (__XFRMNLGRP_MAX - 1)
#endif