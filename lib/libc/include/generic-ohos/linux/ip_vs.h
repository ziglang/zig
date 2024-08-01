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
#ifndef _IP_VS_H
#define _IP_VS_H
#include <linux/types.h>
#define IP_VS_VERSION_CODE 0x010201
#define NVERSION(version) (version >> 16) & 0xFF, (version >> 8) & 0xFF, version & 0xFF
#define IP_VS_SVC_F_PERSISTENT 0x0001
#define IP_VS_SVC_F_HASHED 0x0002
#define IP_VS_SVC_F_ONEPACKET 0x0004
#define IP_VS_SVC_F_SCHED1 0x0008
#define IP_VS_SVC_F_SCHED2 0x0010
#define IP_VS_SVC_F_SCHED3 0x0020
#define IP_VS_SVC_F_SCHED_SH_FALLBACK IP_VS_SVC_F_SCHED1
#define IP_VS_SVC_F_SCHED_SH_PORT IP_VS_SVC_F_SCHED2
#define IP_VS_DEST_F_AVAILABLE 0x0001
#define IP_VS_DEST_F_OVERLOAD 0x0002
#define IP_VS_STATE_NONE 0x0000
#define IP_VS_STATE_MASTER 0x0001
#define IP_VS_STATE_BACKUP 0x0002
#define IP_VS_BASE_CTL (64 + 1024 + 64)
#define IP_VS_SO_SET_NONE IP_VS_BASE_CTL
#define IP_VS_SO_SET_INSERT (IP_VS_BASE_CTL + 1)
#define IP_VS_SO_SET_ADD (IP_VS_BASE_CTL + 2)
#define IP_VS_SO_SET_EDIT (IP_VS_BASE_CTL + 3)
#define IP_VS_SO_SET_DEL (IP_VS_BASE_CTL + 4)
#define IP_VS_SO_SET_FLUSH (IP_VS_BASE_CTL + 5)
#define IP_VS_SO_SET_LIST (IP_VS_BASE_CTL + 6)
#define IP_VS_SO_SET_ADDDEST (IP_VS_BASE_CTL + 7)
#define IP_VS_SO_SET_DELDEST (IP_VS_BASE_CTL + 8)
#define IP_VS_SO_SET_EDITDEST (IP_VS_BASE_CTL + 9)
#define IP_VS_SO_SET_TIMEOUT (IP_VS_BASE_CTL + 10)
#define IP_VS_SO_SET_STARTDAEMON (IP_VS_BASE_CTL + 11)
#define IP_VS_SO_SET_STOPDAEMON (IP_VS_BASE_CTL + 12)
#define IP_VS_SO_SET_RESTORE (IP_VS_BASE_CTL + 13)
#define IP_VS_SO_SET_SAVE (IP_VS_BASE_CTL + 14)
#define IP_VS_SO_SET_ZERO (IP_VS_BASE_CTL + 15)
#define IP_VS_SO_SET_MAX IP_VS_SO_SET_ZERO
#define IP_VS_SO_GET_VERSION IP_VS_BASE_CTL
#define IP_VS_SO_GET_INFO (IP_VS_BASE_CTL + 1)
#define IP_VS_SO_GET_SERVICES (IP_VS_BASE_CTL + 2)
#define IP_VS_SO_GET_SERVICE (IP_VS_BASE_CTL + 3)
#define IP_VS_SO_GET_DESTS (IP_VS_BASE_CTL + 4)
#define IP_VS_SO_GET_DEST (IP_VS_BASE_CTL + 5)
#define IP_VS_SO_GET_TIMEOUT (IP_VS_BASE_CTL + 6)
#define IP_VS_SO_GET_DAEMON (IP_VS_BASE_CTL + 7)
#define IP_VS_SO_GET_MAX IP_VS_SO_GET_DAEMON
#define IP_VS_CONN_F_FWD_MASK 0x0007
#define IP_VS_CONN_F_MASQ 0x0000
#define IP_VS_CONN_F_LOCALNODE 0x0001
#define IP_VS_CONN_F_TUNNEL 0x0002
#define IP_VS_CONN_F_DROUTE 0x0003
#define IP_VS_CONN_F_BYPASS 0x0004
#define IP_VS_CONN_F_SYNC 0x0020
#define IP_VS_CONN_F_HASHED 0x0040
#define IP_VS_CONN_F_NOOUTPUT 0x0080
#define IP_VS_CONN_F_INACTIVE 0x0100
#define IP_VS_CONN_F_OUT_SEQ 0x0200
#define IP_VS_CONN_F_IN_SEQ 0x0400
#define IP_VS_CONN_F_SEQ_MASK 0x0600
#define IP_VS_CONN_F_NO_CPORT 0x0800
#define IP_VS_CONN_F_TEMPLATE 0x1000
#define IP_VS_CONN_F_ONE_PACKET 0x2000
#define IP_VS_CONN_F_BACKUP_MASK (IP_VS_CONN_F_FWD_MASK | IP_VS_CONN_F_NOOUTPUT | IP_VS_CONN_F_INACTIVE | IP_VS_CONN_F_SEQ_MASK | IP_VS_CONN_F_NO_CPORT | IP_VS_CONN_F_TEMPLATE)
#define IP_VS_CONN_F_BACKUP_UPD_MASK (IP_VS_CONN_F_INACTIVE | IP_VS_CONN_F_SEQ_MASK)
#define IP_VS_CONN_F_NFCT (1 << 16)
#define IP_VS_CONN_F_DEST_MASK (IP_VS_CONN_F_FWD_MASK | IP_VS_CONN_F_ONE_PACKET | IP_VS_CONN_F_NFCT | 0)
#define IP_VS_SCHEDNAME_MAXLEN 16
#define IP_VS_PENAME_MAXLEN 16
#define IP_VS_IFNAME_MAXLEN 16
#define IP_VS_PEDATA_MAXLEN 255
enum {
  IP_VS_CONN_F_TUNNEL_TYPE_IPIP = 0,
  IP_VS_CONN_F_TUNNEL_TYPE_GUE,
  IP_VS_CONN_F_TUNNEL_TYPE_GRE,
  IP_VS_CONN_F_TUNNEL_TYPE_MAX,
};
#define IP_VS_TUNNEL_ENCAP_FLAG_NOCSUM (0)
#define IP_VS_TUNNEL_ENCAP_FLAG_CSUM (1 << 0)
#define IP_VS_TUNNEL_ENCAP_FLAG_REMCSUM (1 << 1)
struct ip_vs_service_user {
  __u16 protocol;
  __be32 addr;
  __be16 port;
  __u32 fwmark;
  char sched_name[IP_VS_SCHEDNAME_MAXLEN];
  unsigned int flags;
  unsigned int timeout;
  __be32 netmask;
};
struct ip_vs_dest_user {
  __be32 addr;
  __be16 port;
  unsigned int conn_flags;
  int weight;
  __u32 u_threshold;
  __u32 l_threshold;
};
struct ip_vs_stats_user {
  __u32 conns;
  __u32 inpkts;
  __u32 outpkts;
  __u64 inbytes;
  __u64 outbytes;
  __u32 cps;
  __u32 inpps;
  __u32 outpps;
  __u32 inbps;
  __u32 outbps;
};
struct ip_vs_getinfo {
  unsigned int version;
  unsigned int size;
  unsigned int num_services;
};
struct ip_vs_service_entry {
  __u16 protocol;
  __be32 addr;
  __be16 port;
  __u32 fwmark;
  char sched_name[IP_VS_SCHEDNAME_MAXLEN];
  unsigned int flags;
  unsigned int timeout;
  __be32 netmask;
  unsigned int num_dests;
  struct ip_vs_stats_user stats;
};
struct ip_vs_dest_entry {
  __be32 addr;
  __be16 port;
  unsigned int conn_flags;
  int weight;
  __u32 u_threshold;
  __u32 l_threshold;
  __u32 activeconns;
  __u32 inactconns;
  __u32 persistconns;
  struct ip_vs_stats_user stats;
};
struct ip_vs_get_dests {
  __u16 protocol;
  __be32 addr;
  __be16 port;
  __u32 fwmark;
  unsigned int num_dests;
  struct ip_vs_dest_entry entrytable[0];
};
struct ip_vs_get_services {
  unsigned int num_services;
  struct ip_vs_service_entry entrytable[0];
};
struct ip_vs_timeout_user {
  int tcp_timeout;
  int tcp_fin_timeout;
  int udp_timeout;
};
struct ip_vs_daemon_user {
  int state;
  char mcast_ifn[IP_VS_IFNAME_MAXLEN];
  int syncid;
};
#define IPVS_GENL_NAME "IPVS"
#define IPVS_GENL_VERSION 0x1
struct ip_vs_flags {
  __u32 flags;
  __u32 mask;
};
enum {
  IPVS_CMD_UNSPEC = 0,
  IPVS_CMD_NEW_SERVICE,
  IPVS_CMD_SET_SERVICE,
  IPVS_CMD_DEL_SERVICE,
  IPVS_CMD_GET_SERVICE,
  IPVS_CMD_NEW_DEST,
  IPVS_CMD_SET_DEST,
  IPVS_CMD_DEL_DEST,
  IPVS_CMD_GET_DEST,
  IPVS_CMD_NEW_DAEMON,
  IPVS_CMD_DEL_DAEMON,
  IPVS_CMD_GET_DAEMON,
  IPVS_CMD_SET_CONFIG,
  IPVS_CMD_GET_CONFIG,
  IPVS_CMD_SET_INFO,
  IPVS_CMD_GET_INFO,
  IPVS_CMD_ZERO,
  IPVS_CMD_FLUSH,
  __IPVS_CMD_MAX,
};
#define IPVS_CMD_MAX (__IPVS_CMD_MAX - 1)
enum {
  IPVS_CMD_ATTR_UNSPEC = 0,
  IPVS_CMD_ATTR_SERVICE,
  IPVS_CMD_ATTR_DEST,
  IPVS_CMD_ATTR_DAEMON,
  IPVS_CMD_ATTR_TIMEOUT_TCP,
  IPVS_CMD_ATTR_TIMEOUT_TCP_FIN,
  IPVS_CMD_ATTR_TIMEOUT_UDP,
  __IPVS_CMD_ATTR_MAX,
};
#define IPVS_CMD_ATTR_MAX (__IPVS_CMD_ATTR_MAX - 1)
enum {
  IPVS_SVC_ATTR_UNSPEC = 0,
  IPVS_SVC_ATTR_AF,
  IPVS_SVC_ATTR_PROTOCOL,
  IPVS_SVC_ATTR_ADDR,
  IPVS_SVC_ATTR_PORT,
  IPVS_SVC_ATTR_FWMARK,
  IPVS_SVC_ATTR_SCHED_NAME,
  IPVS_SVC_ATTR_FLAGS,
  IPVS_SVC_ATTR_TIMEOUT,
  IPVS_SVC_ATTR_NETMASK,
  IPVS_SVC_ATTR_STATS,
  IPVS_SVC_ATTR_PE_NAME,
  IPVS_SVC_ATTR_STATS64,
  __IPVS_SVC_ATTR_MAX,
};
#define IPVS_SVC_ATTR_MAX (__IPVS_SVC_ATTR_MAX - 1)
enum {
  IPVS_DEST_ATTR_UNSPEC = 0,
  IPVS_DEST_ATTR_ADDR,
  IPVS_DEST_ATTR_PORT,
  IPVS_DEST_ATTR_FWD_METHOD,
  IPVS_DEST_ATTR_WEIGHT,
  IPVS_DEST_ATTR_U_THRESH,
  IPVS_DEST_ATTR_L_THRESH,
  IPVS_DEST_ATTR_ACTIVE_CONNS,
  IPVS_DEST_ATTR_INACT_CONNS,
  IPVS_DEST_ATTR_PERSIST_CONNS,
  IPVS_DEST_ATTR_STATS,
  IPVS_DEST_ATTR_ADDR_FAMILY,
  IPVS_DEST_ATTR_STATS64,
  IPVS_DEST_ATTR_TUN_TYPE,
  IPVS_DEST_ATTR_TUN_PORT,
  IPVS_DEST_ATTR_TUN_FLAGS,
  __IPVS_DEST_ATTR_MAX,
};
#define IPVS_DEST_ATTR_MAX (__IPVS_DEST_ATTR_MAX - 1)
enum {
  IPVS_DAEMON_ATTR_UNSPEC = 0,
  IPVS_DAEMON_ATTR_STATE,
  IPVS_DAEMON_ATTR_MCAST_IFN,
  IPVS_DAEMON_ATTR_SYNC_ID,
  IPVS_DAEMON_ATTR_SYNC_MAXLEN,
  IPVS_DAEMON_ATTR_MCAST_GROUP,
  IPVS_DAEMON_ATTR_MCAST_GROUP6,
  IPVS_DAEMON_ATTR_MCAST_PORT,
  IPVS_DAEMON_ATTR_MCAST_TTL,
  __IPVS_DAEMON_ATTR_MAX,
};
#define IPVS_DAEMON_ATTR_MAX (__IPVS_DAEMON_ATTR_MAX - 1)
enum {
  IPVS_STATS_ATTR_UNSPEC = 0,
  IPVS_STATS_ATTR_CONNS,
  IPVS_STATS_ATTR_INPKTS,
  IPVS_STATS_ATTR_OUTPKTS,
  IPVS_STATS_ATTR_INBYTES,
  IPVS_STATS_ATTR_OUTBYTES,
  IPVS_STATS_ATTR_CPS,
  IPVS_STATS_ATTR_INPPS,
  IPVS_STATS_ATTR_OUTPPS,
  IPVS_STATS_ATTR_INBPS,
  IPVS_STATS_ATTR_OUTBPS,
  IPVS_STATS_ATTR_PAD,
  __IPVS_STATS_ATTR_MAX,
};
#define IPVS_STATS_ATTR_MAX (__IPVS_STATS_ATTR_MAX - 1)
enum {
  IPVS_INFO_ATTR_UNSPEC = 0,
  IPVS_INFO_ATTR_VERSION,
  IPVS_INFO_ATTR_CONN_TAB_SIZE,
  __IPVS_INFO_ATTR_MAX,
};
#define IPVS_INFO_ATTR_MAX (__IPVS_INFO_ATTR_MAX - 1)
#endif