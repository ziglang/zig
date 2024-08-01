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
#ifndef _UAPI_LINUX_IF_BRIDGE_H
#define _UAPI_LINUX_IF_BRIDGE_H
#include <linux/types.h>
#include <linux/if_ether.h>
#include <linux/in6.h>
#define SYSFS_BRIDGE_ATTR "bridge"
#define SYSFS_BRIDGE_FDB "brforward"
#define SYSFS_BRIDGE_PORT_SUBDIR "brif"
#define SYSFS_BRIDGE_PORT_ATTR "brport"
#define SYSFS_BRIDGE_PORT_LINK "bridge"
#define BRCTL_VERSION 1
#define BRCTL_GET_VERSION 0
#define BRCTL_GET_BRIDGES 1
#define BRCTL_ADD_BRIDGE 2
#define BRCTL_DEL_BRIDGE 3
#define BRCTL_ADD_IF 4
#define BRCTL_DEL_IF 5
#define BRCTL_GET_BRIDGE_INFO 6
#define BRCTL_GET_PORT_LIST 7
#define BRCTL_SET_BRIDGE_FORWARD_DELAY 8
#define BRCTL_SET_BRIDGE_HELLO_TIME 9
#define BRCTL_SET_BRIDGE_MAX_AGE 10
#define BRCTL_SET_AGEING_TIME 11
#define BRCTL_SET_GC_INTERVAL 12
#define BRCTL_GET_PORT_INFO 13
#define BRCTL_SET_BRIDGE_STP_STATE 14
#define BRCTL_SET_BRIDGE_PRIORITY 15
#define BRCTL_SET_PORT_PRIORITY 16
#define BRCTL_SET_PATH_COST 17
#define BRCTL_GET_FDB_ENTRIES 18
#define BR_STATE_DISABLED 0
#define BR_STATE_LISTENING 1
#define BR_STATE_LEARNING 2
#define BR_STATE_FORWARDING 3
#define BR_STATE_BLOCKING 4
struct __bridge_info {
  __u64 designated_root;
  __u64 bridge_id;
  __u32 root_path_cost;
  __u32 max_age;
  __u32 hello_time;
  __u32 forward_delay;
  __u32 bridge_max_age;
  __u32 bridge_hello_time;
  __u32 bridge_forward_delay;
  __u8 topology_change;
  __u8 topology_change_detected;
  __u8 root_port;
  __u8 stp_enabled;
  __u32 ageing_time;
  __u32 gc_interval;
  __u32 hello_timer_value;
  __u32 tcn_timer_value;
  __u32 topology_change_timer_value;
  __u32 gc_timer_value;
};
struct __port_info {
  __u64 designated_root;
  __u64 designated_bridge;
  __u16 port_id;
  __u16 designated_port;
  __u32 path_cost;
  __u32 designated_cost;
  __u8 state;
  __u8 top_change_ack;
  __u8 config_pending;
  __u8 unused0;
  __u32 message_age_timer_value;
  __u32 forward_delay_timer_value;
  __u32 hold_timer_value;
};
struct __fdb_entry {
  __u8 mac_addr[ETH_ALEN];
  __u8 port_no;
  __u8 is_local;
  __u32 ageing_timer_value;
  __u8 port_hi;
  __u8 pad0;
  __u16 unused;
};
#define BRIDGE_FLAGS_MASTER 1
#define BRIDGE_FLAGS_SELF 2
#define BRIDGE_MODE_VEB 0
#define BRIDGE_MODE_VEPA 1
#define BRIDGE_MODE_UNDEF 0xFFFF
enum {
  IFLA_BRIDGE_FLAGS,
  IFLA_BRIDGE_MODE,
  IFLA_BRIDGE_VLAN_INFO,
  IFLA_BRIDGE_VLAN_TUNNEL_INFO,
  IFLA_BRIDGE_MRP,
  __IFLA_BRIDGE_MAX,
};
#define IFLA_BRIDGE_MAX (__IFLA_BRIDGE_MAX - 1)
#define BRIDGE_VLAN_INFO_MASTER (1 << 0)
#define BRIDGE_VLAN_INFO_PVID (1 << 1)
#define BRIDGE_VLAN_INFO_UNTAGGED (1 << 2)
#define BRIDGE_VLAN_INFO_RANGE_BEGIN (1 << 3)
#define BRIDGE_VLAN_INFO_RANGE_END (1 << 4)
#define BRIDGE_VLAN_INFO_BRENTRY (1 << 5)
#define BRIDGE_VLAN_INFO_ONLY_OPTS (1 << 6)
struct bridge_vlan_info {
  __u16 flags;
  __u16 vid;
};
enum {
  IFLA_BRIDGE_VLAN_TUNNEL_UNSPEC,
  IFLA_BRIDGE_VLAN_TUNNEL_ID,
  IFLA_BRIDGE_VLAN_TUNNEL_VID,
  IFLA_BRIDGE_VLAN_TUNNEL_FLAGS,
  __IFLA_BRIDGE_VLAN_TUNNEL_MAX,
};
#define IFLA_BRIDGE_VLAN_TUNNEL_MAX (__IFLA_BRIDGE_VLAN_TUNNEL_MAX - 1)
struct bridge_vlan_xstats {
  __u64 rx_bytes;
  __u64 rx_packets;
  __u64 tx_bytes;
  __u64 tx_packets;
  __u16 vid;
  __u16 flags;
  __u32 pad2;
};
enum {
  IFLA_BRIDGE_MRP_UNSPEC,
  IFLA_BRIDGE_MRP_INSTANCE,
  IFLA_BRIDGE_MRP_PORT_STATE,
  IFLA_BRIDGE_MRP_PORT_ROLE,
  IFLA_BRIDGE_MRP_RING_STATE,
  IFLA_BRIDGE_MRP_RING_ROLE,
  IFLA_BRIDGE_MRP_START_TEST,
  IFLA_BRIDGE_MRP_INFO,
  IFLA_BRIDGE_MRP_IN_ROLE,
  IFLA_BRIDGE_MRP_IN_STATE,
  IFLA_BRIDGE_MRP_START_IN_TEST,
  __IFLA_BRIDGE_MRP_MAX,
};
#define IFLA_BRIDGE_MRP_MAX (__IFLA_BRIDGE_MRP_MAX - 1)
enum {
  IFLA_BRIDGE_MRP_INSTANCE_UNSPEC,
  IFLA_BRIDGE_MRP_INSTANCE_RING_ID,
  IFLA_BRIDGE_MRP_INSTANCE_P_IFINDEX,
  IFLA_BRIDGE_MRP_INSTANCE_S_IFINDEX,
  IFLA_BRIDGE_MRP_INSTANCE_PRIO,
  __IFLA_BRIDGE_MRP_INSTANCE_MAX,
};
#define IFLA_BRIDGE_MRP_INSTANCE_MAX (__IFLA_BRIDGE_MRP_INSTANCE_MAX - 1)
enum {
  IFLA_BRIDGE_MRP_PORT_STATE_UNSPEC,
  IFLA_BRIDGE_MRP_PORT_STATE_STATE,
  __IFLA_BRIDGE_MRP_PORT_STATE_MAX,
};
#define IFLA_BRIDGE_MRP_PORT_STATE_MAX (__IFLA_BRIDGE_MRP_PORT_STATE_MAX - 1)
enum {
  IFLA_BRIDGE_MRP_PORT_ROLE_UNSPEC,
  IFLA_BRIDGE_MRP_PORT_ROLE_ROLE,
  __IFLA_BRIDGE_MRP_PORT_ROLE_MAX,
};
#define IFLA_BRIDGE_MRP_PORT_ROLE_MAX (__IFLA_BRIDGE_MRP_PORT_ROLE_MAX - 1)
enum {
  IFLA_BRIDGE_MRP_RING_STATE_UNSPEC,
  IFLA_BRIDGE_MRP_RING_STATE_RING_ID,
  IFLA_BRIDGE_MRP_RING_STATE_STATE,
  __IFLA_BRIDGE_MRP_RING_STATE_MAX,
};
#define IFLA_BRIDGE_MRP_RING_STATE_MAX (__IFLA_BRIDGE_MRP_RING_STATE_MAX - 1)
enum {
  IFLA_BRIDGE_MRP_RING_ROLE_UNSPEC,
  IFLA_BRIDGE_MRP_RING_ROLE_RING_ID,
  IFLA_BRIDGE_MRP_RING_ROLE_ROLE,
  __IFLA_BRIDGE_MRP_RING_ROLE_MAX,
};
#define IFLA_BRIDGE_MRP_RING_ROLE_MAX (__IFLA_BRIDGE_MRP_RING_ROLE_MAX - 1)
enum {
  IFLA_BRIDGE_MRP_START_TEST_UNSPEC,
  IFLA_BRIDGE_MRP_START_TEST_RING_ID,
  IFLA_BRIDGE_MRP_START_TEST_INTERVAL,
  IFLA_BRIDGE_MRP_START_TEST_MAX_MISS,
  IFLA_BRIDGE_MRP_START_TEST_PERIOD,
  IFLA_BRIDGE_MRP_START_TEST_MONITOR,
  __IFLA_BRIDGE_MRP_START_TEST_MAX,
};
#define IFLA_BRIDGE_MRP_START_TEST_MAX (__IFLA_BRIDGE_MRP_START_TEST_MAX - 1)
enum {
  IFLA_BRIDGE_MRP_INFO_UNSPEC,
  IFLA_BRIDGE_MRP_INFO_RING_ID,
  IFLA_BRIDGE_MRP_INFO_P_IFINDEX,
  IFLA_BRIDGE_MRP_INFO_S_IFINDEX,
  IFLA_BRIDGE_MRP_INFO_PRIO,
  IFLA_BRIDGE_MRP_INFO_RING_STATE,
  IFLA_BRIDGE_MRP_INFO_RING_ROLE,
  IFLA_BRIDGE_MRP_INFO_TEST_INTERVAL,
  IFLA_BRIDGE_MRP_INFO_TEST_MAX_MISS,
  IFLA_BRIDGE_MRP_INFO_TEST_MONITOR,
  IFLA_BRIDGE_MRP_INFO_I_IFINDEX,
  IFLA_BRIDGE_MRP_INFO_IN_STATE,
  IFLA_BRIDGE_MRP_INFO_IN_ROLE,
  IFLA_BRIDGE_MRP_INFO_IN_TEST_INTERVAL,
  IFLA_BRIDGE_MRP_INFO_IN_TEST_MAX_MISS,
  __IFLA_BRIDGE_MRP_INFO_MAX,
};
#define IFLA_BRIDGE_MRP_INFO_MAX (__IFLA_BRIDGE_MRP_INFO_MAX - 1)
enum {
  IFLA_BRIDGE_MRP_IN_STATE_UNSPEC,
  IFLA_BRIDGE_MRP_IN_STATE_IN_ID,
  IFLA_BRIDGE_MRP_IN_STATE_STATE,
  __IFLA_BRIDGE_MRP_IN_STATE_MAX,
};
#define IFLA_BRIDGE_MRP_IN_STATE_MAX (__IFLA_BRIDGE_MRP_IN_STATE_MAX - 1)
enum {
  IFLA_BRIDGE_MRP_IN_ROLE_UNSPEC,
  IFLA_BRIDGE_MRP_IN_ROLE_RING_ID,
  IFLA_BRIDGE_MRP_IN_ROLE_IN_ID,
  IFLA_BRIDGE_MRP_IN_ROLE_ROLE,
  IFLA_BRIDGE_MRP_IN_ROLE_I_IFINDEX,
  __IFLA_BRIDGE_MRP_IN_ROLE_MAX,
};
#define IFLA_BRIDGE_MRP_IN_ROLE_MAX (__IFLA_BRIDGE_MRP_IN_ROLE_MAX - 1)
enum {
  IFLA_BRIDGE_MRP_START_IN_TEST_UNSPEC,
  IFLA_BRIDGE_MRP_START_IN_TEST_IN_ID,
  IFLA_BRIDGE_MRP_START_IN_TEST_INTERVAL,
  IFLA_BRIDGE_MRP_START_IN_TEST_MAX_MISS,
  IFLA_BRIDGE_MRP_START_IN_TEST_PERIOD,
  __IFLA_BRIDGE_MRP_START_IN_TEST_MAX,
};
#define IFLA_BRIDGE_MRP_START_IN_TEST_MAX (__IFLA_BRIDGE_MRP_START_IN_TEST_MAX - 1)
struct br_mrp_instance {
  __u32 ring_id;
  __u32 p_ifindex;
  __u32 s_ifindex;
  __u16 prio;
};
struct br_mrp_ring_state {
  __u32 ring_id;
  __u32 ring_state;
};
struct br_mrp_ring_role {
  __u32 ring_id;
  __u32 ring_role;
};
struct br_mrp_start_test {
  __u32 ring_id;
  __u32 interval;
  __u32 max_miss;
  __u32 period;
  __u32 monitor;
};
struct br_mrp_in_state {
  __u32 in_state;
  __u16 in_id;
};
struct br_mrp_in_role {
  __u32 ring_id;
  __u32 in_role;
  __u32 i_ifindex;
  __u16 in_id;
};
struct br_mrp_start_in_test {
  __u32 interval;
  __u32 max_miss;
  __u32 period;
  __u16 in_id;
};
struct bridge_stp_xstats {
  __u64 transition_blk;
  __u64 transition_fwd;
  __u64 rx_bpdu;
  __u64 tx_bpdu;
  __u64 rx_tcn;
  __u64 tx_tcn;
};
struct br_vlan_msg {
  __u8 family;
  __u8 reserved1;
  __u16 reserved2;
  __u32 ifindex;
};
enum {
  BRIDGE_VLANDB_DUMP_UNSPEC,
  BRIDGE_VLANDB_DUMP_FLAGS,
  __BRIDGE_VLANDB_DUMP_MAX,
};
#define BRIDGE_VLANDB_DUMP_MAX (__BRIDGE_VLANDB_DUMP_MAX - 1)
#define BRIDGE_VLANDB_DUMPF_STATS (1 << 0)
enum {
  BRIDGE_VLANDB_UNSPEC,
  BRIDGE_VLANDB_ENTRY,
  __BRIDGE_VLANDB_MAX,
};
#define BRIDGE_VLANDB_MAX (__BRIDGE_VLANDB_MAX - 1)
enum {
  BRIDGE_VLANDB_ENTRY_UNSPEC,
  BRIDGE_VLANDB_ENTRY_INFO,
  BRIDGE_VLANDB_ENTRY_RANGE,
  BRIDGE_VLANDB_ENTRY_STATE,
  BRIDGE_VLANDB_ENTRY_TUNNEL_INFO,
  BRIDGE_VLANDB_ENTRY_STATS,
  __BRIDGE_VLANDB_ENTRY_MAX,
};
#define BRIDGE_VLANDB_ENTRY_MAX (__BRIDGE_VLANDB_ENTRY_MAX - 1)
enum {
  BRIDGE_VLANDB_TINFO_UNSPEC,
  BRIDGE_VLANDB_TINFO_ID,
  BRIDGE_VLANDB_TINFO_CMD,
  __BRIDGE_VLANDB_TINFO_MAX,
};
#define BRIDGE_VLANDB_TINFO_MAX (__BRIDGE_VLANDB_TINFO_MAX - 1)
enum {
  BRIDGE_VLANDB_STATS_UNSPEC,
  BRIDGE_VLANDB_STATS_RX_BYTES,
  BRIDGE_VLANDB_STATS_RX_PACKETS,
  BRIDGE_VLANDB_STATS_TX_BYTES,
  BRIDGE_VLANDB_STATS_TX_PACKETS,
  BRIDGE_VLANDB_STATS_PAD,
  __BRIDGE_VLANDB_STATS_MAX,
};
#define BRIDGE_VLANDB_STATS_MAX (__BRIDGE_VLANDB_STATS_MAX - 1)
enum {
  MDBA_UNSPEC,
  MDBA_MDB,
  MDBA_ROUTER,
  __MDBA_MAX,
};
#define MDBA_MAX (__MDBA_MAX - 1)
enum {
  MDBA_MDB_UNSPEC,
  MDBA_MDB_ENTRY,
  __MDBA_MDB_MAX,
};
#define MDBA_MDB_MAX (__MDBA_MDB_MAX - 1)
enum {
  MDBA_MDB_ENTRY_UNSPEC,
  MDBA_MDB_ENTRY_INFO,
  __MDBA_MDB_ENTRY_MAX,
};
#define MDBA_MDB_ENTRY_MAX (__MDBA_MDB_ENTRY_MAX - 1)
enum {
  MDBA_MDB_EATTR_UNSPEC,
  MDBA_MDB_EATTR_TIMER,
  MDBA_MDB_EATTR_SRC_LIST,
  MDBA_MDB_EATTR_GROUP_MODE,
  MDBA_MDB_EATTR_SOURCE,
  MDBA_MDB_EATTR_RTPROT,
  __MDBA_MDB_EATTR_MAX
};
#define MDBA_MDB_EATTR_MAX (__MDBA_MDB_EATTR_MAX - 1)
enum {
  MDBA_MDB_SRCLIST_UNSPEC,
  MDBA_MDB_SRCLIST_ENTRY,
  __MDBA_MDB_SRCLIST_MAX
};
#define MDBA_MDB_SRCLIST_MAX (__MDBA_MDB_SRCLIST_MAX - 1)
enum {
  MDBA_MDB_SRCATTR_UNSPEC,
  MDBA_MDB_SRCATTR_ADDRESS,
  MDBA_MDB_SRCATTR_TIMER,
  __MDBA_MDB_SRCATTR_MAX
};
#define MDBA_MDB_SRCATTR_MAX (__MDBA_MDB_SRCATTR_MAX - 1)
enum {
  MDB_RTR_TYPE_DISABLED,
  MDB_RTR_TYPE_TEMP_QUERY,
  MDB_RTR_TYPE_PERM,
  MDB_RTR_TYPE_TEMP
};
enum {
  MDBA_ROUTER_UNSPEC,
  MDBA_ROUTER_PORT,
  __MDBA_ROUTER_MAX,
};
#define MDBA_ROUTER_MAX (__MDBA_ROUTER_MAX - 1)
enum {
  MDBA_ROUTER_PATTR_UNSPEC,
  MDBA_ROUTER_PATTR_TIMER,
  MDBA_ROUTER_PATTR_TYPE,
  __MDBA_ROUTER_PATTR_MAX
};
#define MDBA_ROUTER_PATTR_MAX (__MDBA_ROUTER_PATTR_MAX - 1)
struct br_port_msg {
  __u8 family;
  __u32 ifindex;
};
struct br_mdb_entry {
  __u32 ifindex;
#define MDB_TEMPORARY 0
#define MDB_PERMANENT 1
  __u8 state;
#define MDB_FLAGS_OFFLOAD (1 << 0)
#define MDB_FLAGS_FAST_LEAVE (1 << 1)
#define MDB_FLAGS_STAR_EXCL (1 << 2)
#define MDB_FLAGS_BLOCKED (1 << 3)
  __u8 flags;
  __u16 vid;
  struct {
    union {
      __be32 ip4;
      struct in6_addr ip6;
    } u;
    __be16 proto;
  } addr;
};
enum {
  MDBA_SET_ENTRY_UNSPEC,
  MDBA_SET_ENTRY,
  MDBA_SET_ENTRY_ATTRS,
  __MDBA_SET_ENTRY_MAX,
};
#define MDBA_SET_ENTRY_MAX (__MDBA_SET_ENTRY_MAX - 1)
enum {
  MDBE_ATTR_UNSPEC,
  MDBE_ATTR_SOURCE,
  __MDBE_ATTR_MAX,
};
#define MDBE_ATTR_MAX (__MDBE_ATTR_MAX - 1)
enum {
  BRIDGE_XSTATS_UNSPEC,
  BRIDGE_XSTATS_VLAN,
  BRIDGE_XSTATS_MCAST,
  BRIDGE_XSTATS_PAD,
  BRIDGE_XSTATS_STP,
  __BRIDGE_XSTATS_MAX
};
#define BRIDGE_XSTATS_MAX (__BRIDGE_XSTATS_MAX - 1)
enum {
  BR_MCAST_DIR_RX,
  BR_MCAST_DIR_TX,
  BR_MCAST_DIR_SIZE
};
struct br_mcast_stats {
  __u64 igmp_v1queries[BR_MCAST_DIR_SIZE];
  __u64 igmp_v2queries[BR_MCAST_DIR_SIZE];
  __u64 igmp_v3queries[BR_MCAST_DIR_SIZE];
  __u64 igmp_leaves[BR_MCAST_DIR_SIZE];
  __u64 igmp_v1reports[BR_MCAST_DIR_SIZE];
  __u64 igmp_v2reports[BR_MCAST_DIR_SIZE];
  __u64 igmp_v3reports[BR_MCAST_DIR_SIZE];
  __u64 igmp_parse_errors;
  __u64 mld_v1queries[BR_MCAST_DIR_SIZE];
  __u64 mld_v2queries[BR_MCAST_DIR_SIZE];
  __u64 mld_leaves[BR_MCAST_DIR_SIZE];
  __u64 mld_v1reports[BR_MCAST_DIR_SIZE];
  __u64 mld_v2reports[BR_MCAST_DIR_SIZE];
  __u64 mld_parse_errors;
  __u64 mcast_bytes[BR_MCAST_DIR_SIZE];
  __u64 mcast_packets[BR_MCAST_DIR_SIZE];
};
enum br_boolopt_id {
  BR_BOOLOPT_NO_LL_LEARN,
  BR_BOOLOPT_MAX
};
struct br_boolopt_multi {
  __u32 optval;
  __u32 optmask;
};
#endif