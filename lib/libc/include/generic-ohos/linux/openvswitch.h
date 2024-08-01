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
#ifndef _UAPI__LINUX_OPENVSWITCH_H
#define _UAPI__LINUX_OPENVSWITCH_H 1
#include <linux/types.h>
#include <linux/if_ether.h>
struct ovs_header {
  int dp_ifindex;
};
#define OVS_DATAPATH_FAMILY "ovs_datapath"
#define OVS_DATAPATH_MCGROUP "ovs_datapath"
#define OVS_DATAPATH_VERSION 2
#define OVS_DP_VER_FEATURES 2
enum ovs_datapath_cmd {
  OVS_DP_CMD_UNSPEC,
  OVS_DP_CMD_NEW,
  OVS_DP_CMD_DEL,
  OVS_DP_CMD_GET,
  OVS_DP_CMD_SET
};
enum ovs_datapath_attr {
  OVS_DP_ATTR_UNSPEC,
  OVS_DP_ATTR_NAME,
  OVS_DP_ATTR_UPCALL_PID,
  OVS_DP_ATTR_STATS,
  OVS_DP_ATTR_MEGAFLOW_STATS,
  OVS_DP_ATTR_USER_FEATURES,
  OVS_DP_ATTR_PAD,
  OVS_DP_ATTR_MASKS_CACHE_SIZE,
  __OVS_DP_ATTR_MAX
};
#define OVS_DP_ATTR_MAX (__OVS_DP_ATTR_MAX - 1)
struct ovs_dp_stats {
  __u64 n_hit;
  __u64 n_missed;
  __u64 n_lost;
  __u64 n_flows;
};
struct ovs_dp_megaflow_stats {
  __u64 n_mask_hit;
  __u32 n_masks;
  __u32 pad0;
  __u64 n_cache_hit;
  __u64 pad1;
};
struct ovs_vport_stats {
  __u64 rx_packets;
  __u64 tx_packets;
  __u64 rx_bytes;
  __u64 tx_bytes;
  __u64 rx_errors;
  __u64 tx_errors;
  __u64 rx_dropped;
  __u64 tx_dropped;
};
#define OVS_DP_F_UNALIGNED (1 << 0)
#define OVS_DP_F_VPORT_PIDS (1 << 1)
#define OVS_DP_F_TC_RECIRC_SHARING (1 << 2)
#define OVSP_LOCAL ((__u32) 0)
#define OVS_PACKET_FAMILY "ovs_packet"
#define OVS_PACKET_VERSION 0x1
enum ovs_packet_cmd {
  OVS_PACKET_CMD_UNSPEC,
  OVS_PACKET_CMD_MISS,
  OVS_PACKET_CMD_ACTION,
  OVS_PACKET_CMD_EXECUTE
};
enum ovs_packet_attr {
  OVS_PACKET_ATTR_UNSPEC,
  OVS_PACKET_ATTR_PACKET,
  OVS_PACKET_ATTR_KEY,
  OVS_PACKET_ATTR_ACTIONS,
  OVS_PACKET_ATTR_USERDATA,
  OVS_PACKET_ATTR_EGRESS_TUN_KEY,
  OVS_PACKET_ATTR_UNUSED1,
  OVS_PACKET_ATTR_UNUSED2,
  OVS_PACKET_ATTR_PROBE,
  OVS_PACKET_ATTR_MRU,
  OVS_PACKET_ATTR_LEN,
  OVS_PACKET_ATTR_HASH,
  __OVS_PACKET_ATTR_MAX
};
#define OVS_PACKET_ATTR_MAX (__OVS_PACKET_ATTR_MAX - 1)
#define OVS_VPORT_FAMILY "ovs_vport"
#define OVS_VPORT_MCGROUP "ovs_vport"
#define OVS_VPORT_VERSION 0x1
enum ovs_vport_cmd {
  OVS_VPORT_CMD_UNSPEC,
  OVS_VPORT_CMD_NEW,
  OVS_VPORT_CMD_DEL,
  OVS_VPORT_CMD_GET,
  OVS_VPORT_CMD_SET
};
enum ovs_vport_type {
  OVS_VPORT_TYPE_UNSPEC,
  OVS_VPORT_TYPE_NETDEV,
  OVS_VPORT_TYPE_INTERNAL,
  OVS_VPORT_TYPE_GRE,
  OVS_VPORT_TYPE_VXLAN,
  OVS_VPORT_TYPE_GENEVE,
  __OVS_VPORT_TYPE_MAX
};
#define OVS_VPORT_TYPE_MAX (__OVS_VPORT_TYPE_MAX - 1)
enum ovs_vport_attr {
  OVS_VPORT_ATTR_UNSPEC,
  OVS_VPORT_ATTR_PORT_NO,
  OVS_VPORT_ATTR_TYPE,
  OVS_VPORT_ATTR_NAME,
  OVS_VPORT_ATTR_OPTIONS,
  OVS_VPORT_ATTR_UPCALL_PID,
  OVS_VPORT_ATTR_STATS,
  OVS_VPORT_ATTR_PAD,
  OVS_VPORT_ATTR_IFINDEX,
  OVS_VPORT_ATTR_NETNSID,
  __OVS_VPORT_ATTR_MAX
};
#define OVS_VPORT_ATTR_MAX (__OVS_VPORT_ATTR_MAX - 1)
enum {
  OVS_VXLAN_EXT_UNSPEC,
  OVS_VXLAN_EXT_GBP,
  __OVS_VXLAN_EXT_MAX,
};
#define OVS_VXLAN_EXT_MAX (__OVS_VXLAN_EXT_MAX - 1)
enum {
  OVS_TUNNEL_ATTR_UNSPEC,
  OVS_TUNNEL_ATTR_DST_PORT,
  OVS_TUNNEL_ATTR_EXTENSION,
  __OVS_TUNNEL_ATTR_MAX
};
#define OVS_TUNNEL_ATTR_MAX (__OVS_TUNNEL_ATTR_MAX - 1)
#define OVS_FLOW_FAMILY "ovs_flow"
#define OVS_FLOW_MCGROUP "ovs_flow"
#define OVS_FLOW_VERSION 0x1
enum ovs_flow_cmd {
  OVS_FLOW_CMD_UNSPEC,
  OVS_FLOW_CMD_NEW,
  OVS_FLOW_CMD_DEL,
  OVS_FLOW_CMD_GET,
  OVS_FLOW_CMD_SET
};
struct ovs_flow_stats {
  __u64 n_packets;
  __u64 n_bytes;
};
enum ovs_key_attr {
  OVS_KEY_ATTR_UNSPEC,
  OVS_KEY_ATTR_ENCAP,
  OVS_KEY_ATTR_PRIORITY,
  OVS_KEY_ATTR_IN_PORT,
  OVS_KEY_ATTR_ETHERNET,
  OVS_KEY_ATTR_VLAN,
  OVS_KEY_ATTR_ETHERTYPE,
  OVS_KEY_ATTR_IPV4,
  OVS_KEY_ATTR_IPV6,
  OVS_KEY_ATTR_TCP,
  OVS_KEY_ATTR_UDP,
  OVS_KEY_ATTR_ICMP,
  OVS_KEY_ATTR_ICMPV6,
  OVS_KEY_ATTR_ARP,
  OVS_KEY_ATTR_ND,
  OVS_KEY_ATTR_SKB_MARK,
  OVS_KEY_ATTR_TUNNEL,
  OVS_KEY_ATTR_SCTP,
  OVS_KEY_ATTR_TCP_FLAGS,
  OVS_KEY_ATTR_DP_HASH,
  OVS_KEY_ATTR_RECIRC_ID,
  OVS_KEY_ATTR_MPLS,
  OVS_KEY_ATTR_CT_STATE,
  OVS_KEY_ATTR_CT_ZONE,
  OVS_KEY_ATTR_CT_MARK,
  OVS_KEY_ATTR_CT_LABELS,
  OVS_KEY_ATTR_CT_ORIG_TUPLE_IPV4,
  OVS_KEY_ATTR_CT_ORIG_TUPLE_IPV6,
  OVS_KEY_ATTR_NSH,
  __OVS_KEY_ATTR_MAX
};
#define OVS_KEY_ATTR_MAX (__OVS_KEY_ATTR_MAX - 1)
enum ovs_tunnel_key_attr {
  OVS_TUNNEL_KEY_ATTR_ID,
  OVS_TUNNEL_KEY_ATTR_IPV4_SRC,
  OVS_TUNNEL_KEY_ATTR_IPV4_DST,
  OVS_TUNNEL_KEY_ATTR_TOS,
  OVS_TUNNEL_KEY_ATTR_TTL,
  OVS_TUNNEL_KEY_ATTR_DONT_FRAGMENT,
  OVS_TUNNEL_KEY_ATTR_CSUM,
  OVS_TUNNEL_KEY_ATTR_OAM,
  OVS_TUNNEL_KEY_ATTR_GENEVE_OPTS,
  OVS_TUNNEL_KEY_ATTR_TP_SRC,
  OVS_TUNNEL_KEY_ATTR_TP_DST,
  OVS_TUNNEL_KEY_ATTR_VXLAN_OPTS,
  OVS_TUNNEL_KEY_ATTR_IPV6_SRC,
  OVS_TUNNEL_KEY_ATTR_IPV6_DST,
  OVS_TUNNEL_KEY_ATTR_PAD,
  OVS_TUNNEL_KEY_ATTR_ERSPAN_OPTS,
  OVS_TUNNEL_KEY_ATTR_IPV4_INFO_BRIDGE,
  __OVS_TUNNEL_KEY_ATTR_MAX
};
#define OVS_TUNNEL_KEY_ATTR_MAX (__OVS_TUNNEL_KEY_ATTR_MAX - 1)
enum ovs_frag_type {
  OVS_FRAG_TYPE_NONE,
  OVS_FRAG_TYPE_FIRST,
  OVS_FRAG_TYPE_LATER,
  __OVS_FRAG_TYPE_MAX
};
#define OVS_FRAG_TYPE_MAX (__OVS_FRAG_TYPE_MAX - 1)
struct ovs_key_ethernet {
  __u8 eth_src[ETH_ALEN];
  __u8 eth_dst[ETH_ALEN];
};
struct ovs_key_mpls {
  __be32 mpls_lse;
};
struct ovs_key_ipv4 {
  __be32 ipv4_src;
  __be32 ipv4_dst;
  __u8 ipv4_proto;
  __u8 ipv4_tos;
  __u8 ipv4_ttl;
  __u8 ipv4_frag;
};
struct ovs_key_ipv6 {
  __be32 ipv6_src[4];
  __be32 ipv6_dst[4];
  __be32 ipv6_label;
  __u8 ipv6_proto;
  __u8 ipv6_tclass;
  __u8 ipv6_hlimit;
  __u8 ipv6_frag;
};
struct ovs_key_tcp {
  __be16 tcp_src;
  __be16 tcp_dst;
};
struct ovs_key_udp {
  __be16 udp_src;
  __be16 udp_dst;
};
struct ovs_key_sctp {
  __be16 sctp_src;
  __be16 sctp_dst;
};
struct ovs_key_icmp {
  __u8 icmp_type;
  __u8 icmp_code;
};
struct ovs_key_icmpv6 {
  __u8 icmpv6_type;
  __u8 icmpv6_code;
};
struct ovs_key_arp {
  __be32 arp_sip;
  __be32 arp_tip;
  __be16 arp_op;
  __u8 arp_sha[ETH_ALEN];
  __u8 arp_tha[ETH_ALEN];
};
struct ovs_key_nd {
  __be32 nd_target[4];
  __u8 nd_sll[ETH_ALEN];
  __u8 nd_tll[ETH_ALEN];
};
#define OVS_CT_LABELS_LEN_32 4
#define OVS_CT_LABELS_LEN (OVS_CT_LABELS_LEN_32 * sizeof(__u32))
struct ovs_key_ct_labels {
  union {
    __u8 ct_labels[OVS_CT_LABELS_LEN];
    __u32 ct_labels_32[OVS_CT_LABELS_LEN_32];
  };
};
#define OVS_CS_F_NEW 0x01
#define OVS_CS_F_ESTABLISHED 0x02
#define OVS_CS_F_RELATED 0x04
#define OVS_CS_F_REPLY_DIR 0x08
#define OVS_CS_F_INVALID 0x10
#define OVS_CS_F_TRACKED 0x20
#define OVS_CS_F_SRC_NAT 0x40
#define OVS_CS_F_DST_NAT 0x80
#define OVS_CS_F_NAT_MASK (OVS_CS_F_SRC_NAT | OVS_CS_F_DST_NAT)
struct ovs_key_ct_tuple_ipv4 {
  __be32 ipv4_src;
  __be32 ipv4_dst;
  __be16 src_port;
  __be16 dst_port;
  __u8 ipv4_proto;
};
struct ovs_key_ct_tuple_ipv6 {
  __be32 ipv6_src[4];
  __be32 ipv6_dst[4];
  __be16 src_port;
  __be16 dst_port;
  __u8 ipv6_proto;
};
enum ovs_nsh_key_attr {
  OVS_NSH_KEY_ATTR_UNSPEC,
  OVS_NSH_KEY_ATTR_BASE,
  OVS_NSH_KEY_ATTR_MD1,
  OVS_NSH_KEY_ATTR_MD2,
  __OVS_NSH_KEY_ATTR_MAX
};
#define OVS_NSH_KEY_ATTR_MAX (__OVS_NSH_KEY_ATTR_MAX - 1)
struct ovs_nsh_key_base {
  __u8 flags;
  __u8 ttl;
  __u8 mdtype;
  __u8 np;
  __be32 path_hdr;
};
#define NSH_MD1_CONTEXT_SIZE 4
struct ovs_nsh_key_md1 {
  __be32 context[NSH_MD1_CONTEXT_SIZE];
};
enum ovs_flow_attr {
  OVS_FLOW_ATTR_UNSPEC,
  OVS_FLOW_ATTR_KEY,
  OVS_FLOW_ATTR_ACTIONS,
  OVS_FLOW_ATTR_STATS,
  OVS_FLOW_ATTR_TCP_FLAGS,
  OVS_FLOW_ATTR_USED,
  OVS_FLOW_ATTR_CLEAR,
  OVS_FLOW_ATTR_MASK,
  OVS_FLOW_ATTR_PROBE,
  OVS_FLOW_ATTR_UFID,
  OVS_FLOW_ATTR_UFID_FLAGS,
  OVS_FLOW_ATTR_PAD,
  __OVS_FLOW_ATTR_MAX
};
#define OVS_FLOW_ATTR_MAX (__OVS_FLOW_ATTR_MAX - 1)
#define OVS_UFID_F_OMIT_KEY (1 << 0)
#define OVS_UFID_F_OMIT_MASK (1 << 1)
#define OVS_UFID_F_OMIT_ACTIONS (1 << 2)
enum ovs_sample_attr {
  OVS_SAMPLE_ATTR_UNSPEC,
  OVS_SAMPLE_ATTR_PROBABILITY,
  OVS_SAMPLE_ATTR_ACTIONS,
  __OVS_SAMPLE_ATTR_MAX,
};
#define OVS_SAMPLE_ATTR_MAX (__OVS_SAMPLE_ATTR_MAX - 1)
enum ovs_userspace_attr {
  OVS_USERSPACE_ATTR_UNSPEC,
  OVS_USERSPACE_ATTR_PID,
  OVS_USERSPACE_ATTR_USERDATA,
  OVS_USERSPACE_ATTR_EGRESS_TUN_PORT,
  OVS_USERSPACE_ATTR_ACTIONS,
  __OVS_USERSPACE_ATTR_MAX
};
#define OVS_USERSPACE_ATTR_MAX (__OVS_USERSPACE_ATTR_MAX - 1)
struct ovs_action_trunc {
  __u32 max_len;
};
struct ovs_action_push_mpls {
  __be32 mpls_lse;
  __be16 mpls_ethertype;
};
struct ovs_action_add_mpls {
  __be32 mpls_lse;
  __be16 mpls_ethertype;
  __u16 tun_flags;
};
#define OVS_MPLS_L3_TUNNEL_FLAG_MASK (1 << 0)
struct ovs_action_push_vlan {
  __be16 vlan_tpid;
  __be16 vlan_tci;
};
enum ovs_hash_alg {
  OVS_HASH_ALG_L4,
};
struct ovs_action_hash {
  __u32 hash_alg;
  __u32 hash_basis;
};
enum ovs_ct_attr {
  OVS_CT_ATTR_UNSPEC,
  OVS_CT_ATTR_COMMIT,
  OVS_CT_ATTR_ZONE,
  OVS_CT_ATTR_MARK,
  OVS_CT_ATTR_LABELS,
  OVS_CT_ATTR_HELPER,
  OVS_CT_ATTR_NAT,
  OVS_CT_ATTR_FORCE_COMMIT,
  OVS_CT_ATTR_EVENTMASK,
  OVS_CT_ATTR_TIMEOUT,
  __OVS_CT_ATTR_MAX
};
#define OVS_CT_ATTR_MAX (__OVS_CT_ATTR_MAX - 1)
enum ovs_nat_attr {
  OVS_NAT_ATTR_UNSPEC,
  OVS_NAT_ATTR_SRC,
  OVS_NAT_ATTR_DST,
  OVS_NAT_ATTR_IP_MIN,
  OVS_NAT_ATTR_IP_MAX,
  OVS_NAT_ATTR_PROTO_MIN,
  OVS_NAT_ATTR_PROTO_MAX,
  OVS_NAT_ATTR_PERSISTENT,
  OVS_NAT_ATTR_PROTO_HASH,
  OVS_NAT_ATTR_PROTO_RANDOM,
  __OVS_NAT_ATTR_MAX,
};
#define OVS_NAT_ATTR_MAX (__OVS_NAT_ATTR_MAX - 1)
struct ovs_action_push_eth {
  struct ovs_key_ethernet addresses;
};
enum ovs_check_pkt_len_attr {
  OVS_CHECK_PKT_LEN_ATTR_UNSPEC,
  OVS_CHECK_PKT_LEN_ATTR_PKT_LEN,
  OVS_CHECK_PKT_LEN_ATTR_ACTIONS_IF_GREATER,
  OVS_CHECK_PKT_LEN_ATTR_ACTIONS_IF_LESS_EQUAL,
  __OVS_CHECK_PKT_LEN_ATTR_MAX,
};
#define OVS_CHECK_PKT_LEN_ATTR_MAX (__OVS_CHECK_PKT_LEN_ATTR_MAX - 1)
enum ovs_action_attr {
  OVS_ACTION_ATTR_UNSPEC,
  OVS_ACTION_ATTR_OUTPUT,
  OVS_ACTION_ATTR_USERSPACE,
  OVS_ACTION_ATTR_SET,
  OVS_ACTION_ATTR_PUSH_VLAN,
  OVS_ACTION_ATTR_POP_VLAN,
  OVS_ACTION_ATTR_SAMPLE,
  OVS_ACTION_ATTR_RECIRC,
  OVS_ACTION_ATTR_HASH,
  OVS_ACTION_ATTR_PUSH_MPLS,
  OVS_ACTION_ATTR_POP_MPLS,
  OVS_ACTION_ATTR_SET_MASKED,
  OVS_ACTION_ATTR_CT,
  OVS_ACTION_ATTR_TRUNC,
  OVS_ACTION_ATTR_PUSH_ETH,
  OVS_ACTION_ATTR_POP_ETH,
  OVS_ACTION_ATTR_CT_CLEAR,
  OVS_ACTION_ATTR_PUSH_NSH,
  OVS_ACTION_ATTR_POP_NSH,
  OVS_ACTION_ATTR_METER,
  OVS_ACTION_ATTR_CLONE,
  OVS_ACTION_ATTR_CHECK_PKT_LEN,
  OVS_ACTION_ATTR_ADD_MPLS,
  OVS_ACTION_ATTR_DEC_TTL,
  __OVS_ACTION_ATTR_MAX,
};
#define OVS_ACTION_ATTR_MAX (__OVS_ACTION_ATTR_MAX - 1)
#define OVS_METER_FAMILY "ovs_meter"
#define OVS_METER_MCGROUP "ovs_meter"
#define OVS_METER_VERSION 0x1
enum ovs_meter_cmd {
  OVS_METER_CMD_UNSPEC,
  OVS_METER_CMD_FEATURES,
  OVS_METER_CMD_SET,
  OVS_METER_CMD_DEL,
  OVS_METER_CMD_GET
};
enum ovs_meter_attr {
  OVS_METER_ATTR_UNSPEC,
  OVS_METER_ATTR_ID,
  OVS_METER_ATTR_KBPS,
  OVS_METER_ATTR_STATS,
  OVS_METER_ATTR_BANDS,
  OVS_METER_ATTR_USED,
  OVS_METER_ATTR_CLEAR,
  OVS_METER_ATTR_MAX_METERS,
  OVS_METER_ATTR_MAX_BANDS,
  OVS_METER_ATTR_PAD,
  __OVS_METER_ATTR_MAX
};
#define OVS_METER_ATTR_MAX (__OVS_METER_ATTR_MAX - 1)
enum ovs_band_attr {
  OVS_BAND_ATTR_UNSPEC,
  OVS_BAND_ATTR_TYPE,
  OVS_BAND_ATTR_RATE,
  OVS_BAND_ATTR_BURST,
  OVS_BAND_ATTR_STATS,
  __OVS_BAND_ATTR_MAX
};
#define OVS_BAND_ATTR_MAX (__OVS_BAND_ATTR_MAX - 1)
enum ovs_meter_band_type {
  OVS_METER_BAND_TYPE_UNSPEC,
  OVS_METER_BAND_TYPE_DROP,
  __OVS_METER_BAND_TYPE_MAX
};
#define OVS_METER_BAND_TYPE_MAX (__OVS_METER_BAND_TYPE_MAX - 1)
#define OVS_CT_LIMIT_FAMILY "ovs_ct_limit"
#define OVS_CT_LIMIT_MCGROUP "ovs_ct_limit"
#define OVS_CT_LIMIT_VERSION 0x1
enum ovs_ct_limit_cmd {
  OVS_CT_LIMIT_CMD_UNSPEC,
  OVS_CT_LIMIT_CMD_SET,
  OVS_CT_LIMIT_CMD_DEL,
  OVS_CT_LIMIT_CMD_GET
};
enum ovs_ct_limit_attr {
  OVS_CT_LIMIT_ATTR_UNSPEC,
  OVS_CT_LIMIT_ATTR_ZONE_LIMIT,
  __OVS_CT_LIMIT_ATTR_MAX
};
#define OVS_CT_LIMIT_ATTR_MAX (__OVS_CT_LIMIT_ATTR_MAX - 1)
#define OVS_ZONE_LIMIT_DEFAULT_ZONE - 1
struct ovs_zone_limit {
  int zone_id;
  __u32 limit;
  __u32 count;
};
enum ovs_dec_ttl_attr {
  OVS_DEC_TTL_ATTR_UNSPEC,
  OVS_DEC_TTL_ATTR_ACTION,
  __OVS_DEC_TTL_ATTR_MAX
};
#define OVS_DEC_TTL_ATTR_MAX (__OVS_DEC_TTL_ATTR_MAX - 1)
#endif