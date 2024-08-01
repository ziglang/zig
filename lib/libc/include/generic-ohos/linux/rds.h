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
#ifndef _LINUX_RDS_H
#define _LINUX_RDS_H
#include <linux/types.h>
#include <linux/socket.h>
#include <linux/in6.h>
#define RDS_IB_ABI_VERSION 0x301
#define SOL_RDS 276
#define RDS_CANCEL_SENT_TO 1
#define RDS_GET_MR 2
#define RDS_FREE_MR 3
#define RDS_RECVERR 5
#define RDS_CONG_MONITOR 6
#define RDS_GET_MR_FOR_DEST 7
#define SO_RDS_TRANSPORT 8
#define SO_RDS_MSG_RXPATH_LATENCY 10
#define RDS_TRANS_IB 0
#define RDS_TRANS_GAP 1
#define RDS_TRANS_TCP 2
#define RDS_TRANS_COUNT 3
#define RDS_TRANS_NONE (~0)
#define RDS_TRANS_IWARP RDS_TRANS_GAP
#define SIOCRDSSETTOS (SIOCPROTOPRIVATE)
#define SIOCRDSGETTOS (SIOCPROTOPRIVATE + 1)
typedef __u8 rds_tos_t;
#define RDS_CMSG_RDMA_ARGS 1
#define RDS_CMSG_RDMA_DEST 2
#define RDS_CMSG_RDMA_MAP 3
#define RDS_CMSG_RDMA_STATUS 4
#define RDS_CMSG_CONG_UPDATE 5
#define RDS_CMSG_ATOMIC_FADD 6
#define RDS_CMSG_ATOMIC_CSWP 7
#define RDS_CMSG_MASKED_ATOMIC_FADD 8
#define RDS_CMSG_MASKED_ATOMIC_CSWP 9
#define RDS_CMSG_RXPATH_LATENCY 11
#define RDS_CMSG_ZCOPY_COOKIE 12
#define RDS_CMSG_ZCOPY_COMPLETION 13
#define RDS_INFO_FIRST 10000
#define RDS_INFO_COUNTERS 10000
#define RDS_INFO_CONNECTIONS 10001
#define RDS_INFO_SEND_MESSAGES 10003
#define RDS_INFO_RETRANS_MESSAGES 10004
#define RDS_INFO_RECV_MESSAGES 10005
#define RDS_INFO_SOCKETS 10006
#define RDS_INFO_TCP_SOCKETS 10007
#define RDS_INFO_IB_CONNECTIONS 10008
#define RDS_INFO_CONNECTION_STATS 10009
#define RDS_INFO_IWARP_CONNECTIONS 10010
#define RDS6_INFO_CONNECTIONS 10011
#define RDS6_INFO_SEND_MESSAGES 10012
#define RDS6_INFO_RETRANS_MESSAGES 10013
#define RDS6_INFO_RECV_MESSAGES 10014
#define RDS6_INFO_SOCKETS 10015
#define RDS6_INFO_TCP_SOCKETS 10016
#define RDS6_INFO_IB_CONNECTIONS 10017
#define RDS_INFO_LAST 10017
struct rds_info_counter {
  __u8 name[32];
  __u64 value;
} __attribute__((packed));
#define RDS_INFO_CONNECTION_FLAG_SENDING 0x01
#define RDS_INFO_CONNECTION_FLAG_CONNECTING 0x02
#define RDS_INFO_CONNECTION_FLAG_CONNECTED 0x04
#define TRANSNAMSIZ 16
struct rds_info_connection {
  __u64 next_tx_seq;
  __u64 next_rx_seq;
  __be32 laddr;
  __be32 faddr;
  __u8 transport[TRANSNAMSIZ];
  __u8 flags;
  __u8 tos;
} __attribute__((packed));
struct rds6_info_connection {
  __u64 next_tx_seq;
  __u64 next_rx_seq;
  struct in6_addr laddr;
  struct in6_addr faddr;
  __u8 transport[TRANSNAMSIZ];
  __u8 flags;
} __attribute__((packed));
#define RDS_INFO_MESSAGE_FLAG_ACK 0x01
#define RDS_INFO_MESSAGE_FLAG_FAST_ACK 0x02
struct rds_info_message {
  __u64 seq;
  __u32 len;
  __be32 laddr;
  __be32 faddr;
  __be16 lport;
  __be16 fport;
  __u8 flags;
  __u8 tos;
} __attribute__((packed));
struct rds6_info_message {
  __u64 seq;
  __u32 len;
  struct in6_addr laddr;
  struct in6_addr faddr;
  __be16 lport;
  __be16 fport;
  __u8 flags;
  __u8 tos;
} __attribute__((packed));
struct rds_info_socket {
  __u32 sndbuf;
  __be32 bound_addr;
  __be32 connected_addr;
  __be16 bound_port;
  __be16 connected_port;
  __u32 rcvbuf;
  __u64 inum;
} __attribute__((packed));
struct rds6_info_socket {
  __u32 sndbuf;
  struct in6_addr bound_addr;
  struct in6_addr connected_addr;
  __be16 bound_port;
  __be16 connected_port;
  __u32 rcvbuf;
  __u64 inum;
} __attribute__((packed));
struct rds_info_tcp_socket {
  __be32 local_addr;
  __be16 local_port;
  __be32 peer_addr;
  __be16 peer_port;
  __u64 hdr_rem;
  __u64 data_rem;
  __u32 last_sent_nxt;
  __u32 last_expected_una;
  __u32 last_seen_una;
  __u8 tos;
} __attribute__((packed));
struct rds6_info_tcp_socket {
  struct in6_addr local_addr;
  __be16 local_port;
  struct in6_addr peer_addr;
  __be16 peer_port;
  __u64 hdr_rem;
  __u64 data_rem;
  __u32 last_sent_nxt;
  __u32 last_expected_una;
  __u32 last_seen_una;
} __attribute__((packed));
#define RDS_IB_GID_LEN 16
struct rds_info_rdma_connection {
  __be32 src_addr;
  __be32 dst_addr;
  __u8 src_gid[RDS_IB_GID_LEN];
  __u8 dst_gid[RDS_IB_GID_LEN];
  __u32 max_send_wr;
  __u32 max_recv_wr;
  __u32 max_send_sge;
  __u32 rdma_mr_max;
  __u32 rdma_mr_size;
  __u8 tos;
  __u8 sl;
  __u32 cache_allocs;
};
struct rds6_info_rdma_connection {
  struct in6_addr src_addr;
  struct in6_addr dst_addr;
  __u8 src_gid[RDS_IB_GID_LEN];
  __u8 dst_gid[RDS_IB_GID_LEN];
  __u32 max_send_wr;
  __u32 max_recv_wr;
  __u32 max_send_sge;
  __u32 rdma_mr_max;
  __u32 rdma_mr_size;
  __u8 tos;
  __u8 sl;
  __u32 cache_allocs;
};
enum rds_message_rxpath_latency {
  RDS_MSG_RX_HDR_TO_DGRAM_START = 0,
  RDS_MSG_RX_DGRAM_REASSEMBLE,
  RDS_MSG_RX_DGRAM_DELIVERED,
  RDS_MSG_RX_DGRAM_TRACE_MAX
};
struct rds_rx_trace_so {
  __u8 rx_traces;
  __u8 rx_trace_pos[RDS_MSG_RX_DGRAM_TRACE_MAX];
};
struct rds_cmsg_rx_trace {
  __u8 rx_traces;
  __u8 rx_trace_pos[RDS_MSG_RX_DGRAM_TRACE_MAX];
  __u64 rx_trace[RDS_MSG_RX_DGRAM_TRACE_MAX];
};
#define RDS_CONG_MONITOR_SIZE 64
#define RDS_CONG_MONITOR_BIT(port) (((unsigned int) port) % RDS_CONG_MONITOR_SIZE)
#define RDS_CONG_MONITOR_MASK(port) (1ULL << RDS_CONG_MONITOR_BIT(port))
typedef __u64 rds_rdma_cookie_t;
struct rds_iovec {
  __u64 addr;
  __u64 bytes;
};
struct rds_get_mr_args {
  struct rds_iovec vec;
  __u64 cookie_addr;
  __u64 flags;
};
struct rds_get_mr_for_dest_args {
  struct sockaddr_storage dest_addr;
  struct rds_iovec vec;
  __u64 cookie_addr;
  __u64 flags;
};
struct rds_free_mr_args {
  rds_rdma_cookie_t cookie;
  __u64 flags;
};
struct rds_rdma_args {
  rds_rdma_cookie_t cookie;
  struct rds_iovec remote_vec;
  __u64 local_vec_addr;
  __u64 nr_local;
  __u64 flags;
  __u64 user_token;
};
struct rds_atomic_args {
  rds_rdma_cookie_t cookie;
  __u64 local_addr;
  __u64 remote_addr;
  union {
    struct {
      __u64 compare;
      __u64 swap;
    } cswp;
    struct {
      __u64 add;
    } fadd;
    struct {
      __u64 compare;
      __u64 swap;
      __u64 compare_mask;
      __u64 swap_mask;
    } m_cswp;
    struct {
      __u64 add;
      __u64 nocarry_mask;
    } m_fadd;
  };
  __u64 flags;
  __u64 user_token;
};
struct rds_rdma_notify {
  __u64 user_token;
  __s32 status;
};
#define RDS_RDMA_SUCCESS 0
#define RDS_RDMA_REMOTE_ERROR 1
#define RDS_RDMA_CANCELED 2
#define RDS_RDMA_DROPPED 3
#define RDS_RDMA_OTHER_ERROR 4
#define RDS_MAX_ZCOOKIES 8
struct rds_zcopy_cookies {
  __u32 num;
  __u32 cookies[RDS_MAX_ZCOOKIES];
};
#define RDS_RDMA_READWRITE 0x0001
#define RDS_RDMA_FENCE 0x0002
#define RDS_RDMA_INVALIDATE 0x0004
#define RDS_RDMA_USE_ONCE 0x0008
#define RDS_RDMA_DONTWAIT 0x0010
#define RDS_RDMA_NOTIFY_ME 0x0020
#define RDS_RDMA_SILENT 0x0040
#endif