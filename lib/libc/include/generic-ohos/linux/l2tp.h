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
#ifndef _UAPI_LINUX_L2TP_H_
#define _UAPI_LINUX_L2TP_H_
#include <linux/types.h>
#include <linux/socket.h>
#include <linux/in.h>
#include <linux/in6.h>
#define IPPROTO_L2TP 115
#define __SOCK_SIZE__ 16
struct sockaddr_l2tpip {
  __kernel_sa_family_t l2tp_family;
  __be16 l2tp_unused;
  struct in_addr l2tp_addr;
  __u32 l2tp_conn_id;
  unsigned char __pad[__SOCK_SIZE__ - sizeof(__kernel_sa_family_t) - sizeof(__be16) - sizeof(struct in_addr) - sizeof(__u32)];
};
struct sockaddr_l2tpip6 {
  __kernel_sa_family_t l2tp_family;
  __be16 l2tp_unused;
  __be32 l2tp_flowinfo;
  struct in6_addr l2tp_addr;
  __u32 l2tp_scope_id;
  __u32 l2tp_conn_id;
};
enum {
  L2TP_CMD_NOOP,
  L2TP_CMD_TUNNEL_CREATE,
  L2TP_CMD_TUNNEL_DELETE,
  L2TP_CMD_TUNNEL_MODIFY,
  L2TP_CMD_TUNNEL_GET,
  L2TP_CMD_SESSION_CREATE,
  L2TP_CMD_SESSION_DELETE,
  L2TP_CMD_SESSION_MODIFY,
  L2TP_CMD_SESSION_GET,
  __L2TP_CMD_MAX,
};
#define L2TP_CMD_MAX (__L2TP_CMD_MAX - 1)
enum {
  L2TP_ATTR_NONE,
  L2TP_ATTR_PW_TYPE,
  L2TP_ATTR_ENCAP_TYPE,
  L2TP_ATTR_OFFSET,
  L2TP_ATTR_DATA_SEQ,
  L2TP_ATTR_L2SPEC_TYPE,
  L2TP_ATTR_L2SPEC_LEN,
  L2TP_ATTR_PROTO_VERSION,
  L2TP_ATTR_IFNAME,
  L2TP_ATTR_CONN_ID,
  L2TP_ATTR_PEER_CONN_ID,
  L2TP_ATTR_SESSION_ID,
  L2TP_ATTR_PEER_SESSION_ID,
  L2TP_ATTR_UDP_CSUM,
  L2TP_ATTR_VLAN_ID,
  L2TP_ATTR_COOKIE,
  L2TP_ATTR_PEER_COOKIE,
  L2TP_ATTR_DEBUG,
  L2TP_ATTR_RECV_SEQ,
  L2TP_ATTR_SEND_SEQ,
  L2TP_ATTR_LNS_MODE,
  L2TP_ATTR_USING_IPSEC,
  L2TP_ATTR_RECV_TIMEOUT,
  L2TP_ATTR_FD,
  L2TP_ATTR_IP_SADDR,
  L2TP_ATTR_IP_DADDR,
  L2TP_ATTR_UDP_SPORT,
  L2TP_ATTR_UDP_DPORT,
  L2TP_ATTR_MTU,
  L2TP_ATTR_MRU,
  L2TP_ATTR_STATS,
  L2TP_ATTR_IP6_SADDR,
  L2TP_ATTR_IP6_DADDR,
  L2TP_ATTR_UDP_ZERO_CSUM6_TX,
  L2TP_ATTR_UDP_ZERO_CSUM6_RX,
  L2TP_ATTR_PAD,
  __L2TP_ATTR_MAX,
};
#define L2TP_ATTR_MAX (__L2TP_ATTR_MAX - 1)
enum {
  L2TP_ATTR_STATS_NONE,
  L2TP_ATTR_TX_PACKETS,
  L2TP_ATTR_TX_BYTES,
  L2TP_ATTR_TX_ERRORS,
  L2TP_ATTR_RX_PACKETS,
  L2TP_ATTR_RX_BYTES,
  L2TP_ATTR_RX_SEQ_DISCARDS,
  L2TP_ATTR_RX_OOS_PACKETS,
  L2TP_ATTR_RX_ERRORS,
  L2TP_ATTR_STATS_PAD,
  L2TP_ATTR_RX_COOKIE_DISCARDS,
  __L2TP_ATTR_STATS_MAX,
};
#define L2TP_ATTR_STATS_MAX (__L2TP_ATTR_STATS_MAX - 1)
enum l2tp_pwtype {
  L2TP_PWTYPE_NONE = 0x0000,
  L2TP_PWTYPE_ETH_VLAN = 0x0004,
  L2TP_PWTYPE_ETH = 0x0005,
  L2TP_PWTYPE_PPP = 0x0007,
  L2TP_PWTYPE_PPP_AC = 0x0008,
  L2TP_PWTYPE_IP = 0x000b,
  __L2TP_PWTYPE_MAX
};
enum l2tp_l2spec_type {
  L2TP_L2SPECTYPE_NONE,
  L2TP_L2SPECTYPE_DEFAULT,
};
enum l2tp_encap_type {
  L2TP_ENCAPTYPE_UDP,
  L2TP_ENCAPTYPE_IP,
};
enum l2tp_seqmode {
  L2TP_SEQ_NONE = 0,
  L2TP_SEQ_IP = 1,
  L2TP_SEQ_ALL = 2,
};
enum l2tp_debug_flags {
  L2TP_MSG_DEBUG = (1 << 0),
  L2TP_MSG_CONTROL = (1 << 1),
  L2TP_MSG_SEQ = (1 << 2),
  L2TP_MSG_DATA = (1 << 3),
};
#define L2TP_GENL_NAME "l2tp"
#define L2TP_GENL_VERSION 0x1
#define L2TP_GENL_MCGROUP "l2tp"
#endif