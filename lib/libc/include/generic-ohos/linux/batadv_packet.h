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
#ifndef _UAPI_LINUX_BATADV_PACKET_H_
#define _UAPI_LINUX_BATADV_PACKET_H_
#include <asm/byteorder.h>
#include <linux/if_ether.h>
#include <linux/types.h>
#define batadv_tp_is_error(n) ((__u8) (n) > 127 ? 1 : 0)
enum batadv_packettype {
  BATADV_IV_OGM = 0x00,
  BATADV_BCAST = 0x01,
  BATADV_CODED = 0x02,
  BATADV_ELP = 0x03,
  BATADV_OGM2 = 0x04,
#define BATADV_UNICAST_MIN 0x40
  BATADV_UNICAST = 0x40,
  BATADV_UNICAST_FRAG = 0x41,
  BATADV_UNICAST_4ADDR = 0x42,
  BATADV_ICMP = 0x43,
  BATADV_UNICAST_TVLV = 0x44,
#define BATADV_UNICAST_MAX 0x7f
};
enum batadv_subtype {
  BATADV_P_DATA = 0x01,
  BATADV_P_DAT_DHT_GET = 0x02,
  BATADV_P_DAT_DHT_PUT = 0x03,
  BATADV_P_DAT_CACHE_REPLY = 0x04,
};
#define BATADV_COMPAT_VERSION 15
enum batadv_iv_flags {
  BATADV_NOT_BEST_NEXT_HOP = 1UL << 0,
  BATADV_PRIMARIES_FIRST_HOP = 1UL << 1,
  BATADV_DIRECTLINK = 1UL << 2,
};
enum batadv_icmp_packettype {
  BATADV_ECHO_REPLY = 0,
  BATADV_DESTINATION_UNREACHABLE = 3,
  BATADV_ECHO_REQUEST = 8,
  BATADV_TTL_EXCEEDED = 11,
  BATADV_PARAMETER_PROBLEM = 12,
  BATADV_TP = 15,
};
enum batadv_mcast_flags {
  BATADV_MCAST_WANT_ALL_UNSNOOPABLES = 1UL << 0,
  BATADV_MCAST_WANT_ALL_IPV4 = 1UL << 1,
  BATADV_MCAST_WANT_ALL_IPV6 = 1UL << 2,
  BATADV_MCAST_WANT_NO_RTR4 = 1UL << 3,
  BATADV_MCAST_WANT_NO_RTR6 = 1UL << 4,
};
#define BATADV_TT_DATA_TYPE_MASK 0x0F
enum batadv_tt_data_flags {
  BATADV_TT_OGM_DIFF = 1UL << 0,
  BATADV_TT_REQUEST = 1UL << 1,
  BATADV_TT_RESPONSE = 1UL << 2,
  BATADV_TT_FULL_TABLE = 1UL << 4,
};
enum batadv_vlan_flags {
  BATADV_VLAN_HAS_TAG = 1UL << 15,
};
enum batadv_bla_claimframe {
  BATADV_CLAIM_TYPE_CLAIM = 0x00,
  BATADV_CLAIM_TYPE_UNCLAIM = 0x01,
  BATADV_CLAIM_TYPE_ANNOUNCE = 0x02,
  BATADV_CLAIM_TYPE_REQUEST = 0x03,
  BATADV_CLAIM_TYPE_LOOPDETECT = 0x04,
};
enum batadv_tvlv_type {
  BATADV_TVLV_GW = 0x01,
  BATADV_TVLV_DAT = 0x02,
  BATADV_TVLV_NC = 0x03,
  BATADV_TVLV_TT = 0x04,
  BATADV_TVLV_ROAM = 0x05,
  BATADV_TVLV_MCAST = 0x06,
};
#pragma pack(2)
struct batadv_bla_claim_dst {
  __u8 magic[3];
  __u8 type;
  __be16 group;
};
struct batadv_ogm_packet {
  __u8 packet_type;
  __u8 version;
  __u8 ttl;
  __u8 flags;
  __be32 seqno;
  __u8 orig[ETH_ALEN];
  __u8 prev_sender[ETH_ALEN];
  __u8 reserved;
  __u8 tq;
  __be16 tvlv_len;
};
#define BATADV_OGM_HLEN sizeof(struct batadv_ogm_packet)
struct batadv_ogm2_packet {
  __u8 packet_type;
  __u8 version;
  __u8 ttl;
  __u8 flags;
  __be32 seqno;
  __u8 orig[ETH_ALEN];
  __be16 tvlv_len;
  __be32 throughput;
};
#define BATADV_OGM2_HLEN sizeof(struct batadv_ogm2_packet)
struct batadv_elp_packet {
  __u8 packet_type;
  __u8 version;
  __u8 orig[ETH_ALEN];
  __be32 seqno;
  __be32 elp_interval;
};
#define BATADV_ELP_HLEN sizeof(struct batadv_elp_packet)
struct batadv_icmp_header {
  __u8 packet_type;
  __u8 version;
  __u8 ttl;
  __u8 msg_type;
  __u8 dst[ETH_ALEN];
  __u8 orig[ETH_ALEN];
  __u8 uid;
  __u8 align[3];
};
struct batadv_icmp_packet {
  __u8 packet_type;
  __u8 version;
  __u8 ttl;
  __u8 msg_type;
  __u8 dst[ETH_ALEN];
  __u8 orig[ETH_ALEN];
  __u8 uid;
  __u8 reserved;
  __be16 seqno;
};
struct batadv_icmp_tp_packet {
  __u8 packet_type;
  __u8 version;
  __u8 ttl;
  __u8 msg_type;
  __u8 dst[ETH_ALEN];
  __u8 orig[ETH_ALEN];
  __u8 uid;
  __u8 subtype;
  __u8 session[2];
  __be32 seqno;
  __be32 timestamp;
};
enum batadv_icmp_tp_subtype {
  BATADV_TP_MSG = 0,
  BATADV_TP_ACK,
};
#define BATADV_RR_LEN 16
struct batadv_icmp_packet_rr {
  __u8 packet_type;
  __u8 version;
  __u8 ttl;
  __u8 msg_type;
  __u8 dst[ETH_ALEN];
  __u8 orig[ETH_ALEN];
  __u8 uid;
  __u8 rr_cur;
  __be16 seqno;
  __u8 rr[BATADV_RR_LEN][ETH_ALEN];
};
#define BATADV_ICMP_MAX_PACKET_SIZE sizeof(struct batadv_icmp_packet_rr)
struct batadv_unicast_packet {
  __u8 packet_type;
  __u8 version;
  __u8 ttl;
  __u8 ttvn;
  __u8 dest[ETH_ALEN];
};
struct batadv_unicast_4addr_packet {
  struct batadv_unicast_packet u;
  __u8 src[ETH_ALEN];
  __u8 subtype;
  __u8 reserved;
};
struct batadv_frag_packet {
  __u8 packet_type;
  __u8 version;
  __u8 ttl;
#ifdef __BIG_ENDIAN_BITFIELD
  __u8 no : 4;
  __u8 priority : 3;
  __u8 reserved : 1;
#elif defined(__LITTLE_ENDIAN_BITFIELD)
  __u8 reserved : 1;
  __u8 priority : 3;
  __u8 no : 4;
#else
#error "unknown bitfield endianness"
#endif
  __u8 dest[ETH_ALEN];
  __u8 orig[ETH_ALEN];
  __be16 seqno;
  __be16 total_size;
};
struct batadv_bcast_packet {
  __u8 packet_type;
  __u8 version;
  __u8 ttl;
  __u8 reserved;
  __be32 seqno;
  __u8 orig[ETH_ALEN];
};
struct batadv_coded_packet {
  __u8 packet_type;
  __u8 version;
  __u8 ttl;
  __u8 first_ttvn;
  __u8 first_source[ETH_ALEN];
  __u8 first_orig_dest[ETH_ALEN];
  __be32 first_crc;
  __u8 second_ttl;
  __u8 second_ttvn;
  __u8 second_dest[ETH_ALEN];
  __u8 second_source[ETH_ALEN];
  __u8 second_orig_dest[ETH_ALEN];
  __be32 second_crc;
  __be16 coded_len;
};
struct batadv_unicast_tvlv_packet {
  __u8 packet_type;
  __u8 version;
  __u8 ttl;
  __u8 reserved;
  __u8 dst[ETH_ALEN];
  __u8 src[ETH_ALEN];
  __be16 tvlv_len;
  __u16 align;
};
struct batadv_tvlv_hdr {
  __u8 type;
  __u8 version;
  __be16 len;
};
struct batadv_tvlv_gateway_data {
  __be32 bandwidth_down;
  __be32 bandwidth_up;
};
struct batadv_tvlv_tt_data {
  __u8 flags;
  __u8 ttvn;
  __be16 num_vlan;
};
struct batadv_tvlv_tt_vlan_data {
  __be32 crc;
  __be16 vid;
  __u16 reserved;
};
struct batadv_tvlv_tt_change {
  __u8 flags;
  __u8 reserved[3];
  __u8 addr[ETH_ALEN];
  __be16 vid;
};
struct batadv_tvlv_roam_adv {
  __u8 client[ETH_ALEN];
  __be16 vid;
};
struct batadv_tvlv_mcast_data {
  __u8 flags;
  __u8 reserved[3];
};
#pragma pack()
#endif