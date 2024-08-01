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
#ifndef _LINUX_TIPC_H_
#define _LINUX_TIPC_H_
#include <linux/types.h>
#include <linux/sockios.h>
struct tipc_socket_addr {
  __u32 ref;
  __u32 node;
};
struct tipc_service_addr {
  __u32 type;
  __u32 instance;
};
struct tipc_service_range {
  __u32 type;
  __u32 lower;
  __u32 upper;
};
#define TIPC_NODE_STATE 0
#define TIPC_TOP_SRV 1
#define TIPC_LINK_STATE 2
#define TIPC_RESERVED_TYPES 64
enum tipc_scope {
  TIPC_CLUSTER_SCOPE = 2,
  TIPC_NODE_SCOPE = 3
};
#define TIPC_MAX_USER_MSG_SIZE 66000U
#define TIPC_LOW_IMPORTANCE 0
#define TIPC_MEDIUM_IMPORTANCE 1
#define TIPC_HIGH_IMPORTANCE 2
#define TIPC_CRITICAL_IMPORTANCE 3
#define TIPC_OK 0
#define TIPC_ERR_NO_NAME 1
#define TIPC_ERR_NO_PORT 2
#define TIPC_ERR_NO_NODE 3
#define TIPC_ERR_OVERLOAD 4
#define TIPC_CONN_SHUTDOWN 5
#define TIPC_SUB_PORTS 0x01
#define TIPC_SUB_SERVICE 0x02
#define TIPC_SUB_CANCEL 0x04
#define TIPC_WAIT_FOREVER (~0)
struct tipc_subscr {
  struct tipc_service_range seq;
  __u32 timeout;
  __u32 filter;
  char usr_handle[8];
};
#define TIPC_PUBLISHED 1
#define TIPC_WITHDRAWN 2
#define TIPC_SUBSCR_TIMEOUT 3
struct tipc_event {
  __u32 event;
  __u32 found_lower;
  __u32 found_upper;
  struct tipc_socket_addr port;
  struct tipc_subscr s;
};
#ifndef AF_TIPC
#define AF_TIPC 30
#endif
#ifndef PF_TIPC
#define PF_TIPC AF_TIPC
#endif
#ifndef SOL_TIPC
#define SOL_TIPC 271
#endif
#define TIPC_ADDR_MCAST 1
#define TIPC_SERVICE_RANGE 1
#define TIPC_SERVICE_ADDR 2
#define TIPC_SOCKET_ADDR 3
struct sockaddr_tipc {
  unsigned short family;
  unsigned char addrtype;
  signed char scope;
  union {
    struct tipc_socket_addr id;
    struct tipc_service_range nameseq;
    struct {
      struct tipc_service_addr name;
      __u32 domain;
    } name;
  } addr;
};
#define TIPC_ERRINFO 1
#define TIPC_RETDATA 2
#define TIPC_DESTNAME 3
#define TIPC_IMPORTANCE 127
#define TIPC_SRC_DROPPABLE 128
#define TIPC_DEST_DROPPABLE 129
#define TIPC_CONN_TIMEOUT 130
#define TIPC_NODE_RECVQ_DEPTH 131
#define TIPC_SOCK_RECVQ_DEPTH 132
#define TIPC_MCAST_BROADCAST 133
#define TIPC_MCAST_REPLICAST 134
#define TIPC_GROUP_JOIN 135
#define TIPC_GROUP_LEAVE 136
#define TIPC_SOCK_RECVQ_USED 137
#define TIPC_NODELAY 138
#define TIPC_GROUP_LOOPBACK 0x1
#define TIPC_GROUP_MEMBER_EVTS 0x2
struct tipc_group_req {
  __u32 type;
  __u32 instance;
  __u32 scope;
  __u32 flags;
};
#define TIPC_NODEID_LEN 16
#define TIPC_MAX_MEDIA_NAME 16
#define TIPC_MAX_IF_NAME 16
#define TIPC_MAX_BEARER_NAME 32
#define TIPC_MAX_LINK_NAME 68
#define SIOCGETLINKNAME SIOCPROTOPRIVATE
#define SIOCGETNODEID (SIOCPROTOPRIVATE + 1)
struct tipc_sioc_ln_req {
  __u32 peer;
  __u32 bearer_id;
  char linkname[TIPC_MAX_LINK_NAME];
};
struct tipc_sioc_nodeid_req {
  __u32 peer;
  char node_id[TIPC_NODEID_LEN];
};
#define TIPC_AEAD_ALG_NAME (32)
struct tipc_aead_key {
  char alg_name[TIPC_AEAD_ALG_NAME];
  unsigned int keylen;
  char key[];
};
#define TIPC_AEAD_KEYLEN_MIN (16 + 4)
#define TIPC_AEAD_KEYLEN_MAX (32 + 4)
#define TIPC_AEAD_KEY_SIZE_MAX (sizeof(struct tipc_aead_key) + TIPC_AEAD_KEYLEN_MAX)
#define TIPC_REKEYING_NOW (~0U)
#define TIPC_CFG_SRV 0
#define TIPC_ZONE_SCOPE 1
#define TIPC_ADDR_NAMESEQ 1
#define TIPC_ADDR_NAME 2
#define TIPC_ADDR_ID 3
#define TIPC_NODE_BITS 12
#define TIPC_CLUSTER_BITS 12
#define TIPC_ZONE_BITS 8
#define TIPC_NODE_OFFSET 0
#define TIPC_CLUSTER_OFFSET TIPC_NODE_BITS
#define TIPC_ZONE_OFFSET (TIPC_CLUSTER_OFFSET + TIPC_CLUSTER_BITS)
#define TIPC_NODE_SIZE ((1UL << TIPC_NODE_BITS) - 1)
#define TIPC_CLUSTER_SIZE ((1UL << TIPC_CLUSTER_BITS) - 1)
#define TIPC_ZONE_SIZE ((1UL << TIPC_ZONE_BITS) - 1)
#define TIPC_NODE_MASK (TIPC_NODE_SIZE << TIPC_NODE_OFFSET)
#define TIPC_CLUSTER_MASK (TIPC_CLUSTER_SIZE << TIPC_CLUSTER_OFFSET)
#define TIPC_ZONE_MASK (TIPC_ZONE_SIZE << TIPC_ZONE_OFFSET)
#define TIPC_ZONE_CLUSTER_MASK (TIPC_ZONE_MASK | TIPC_CLUSTER_MASK)
#define tipc_portid tipc_socket_addr
#define tipc_name tipc_service_addr
#define tipc_name_seq tipc_service_range
#endif