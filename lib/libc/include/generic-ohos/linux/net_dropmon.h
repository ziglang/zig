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
#ifndef __NET_DROPMON_H
#define __NET_DROPMON_H
#include <linux/types.h>
#include <linux/netlink.h>
struct net_dm_drop_point {
  __u8 pc[8];
  __u32 count;
};
#define is_drop_point_hw(x) do { int ____i, ____j; for(____i = 0; ____i < 8; i ____i ++) ____j |= x[____i]; ____j; \
} while(0)
#define NET_DM_CFG_VERSION 0
#define NET_DM_CFG_ALERT_COUNT 1
#define NET_DM_CFG_ALERT_DELAY 2
#define NET_DM_CFG_MAX 3
struct net_dm_config_entry {
  __u32 type;
  __u64 data __attribute__((aligned(8)));
};
struct net_dm_config_msg {
  __u32 entries;
  struct net_dm_config_entry options[0];
};
struct net_dm_alert_msg {
  __u32 entries;
  struct net_dm_drop_point points[0];
};
struct net_dm_user_msg {
  union {
    struct net_dm_config_msg user;
    struct net_dm_alert_msg alert;
  } u;
};
enum {
  NET_DM_CMD_UNSPEC = 0,
  NET_DM_CMD_ALERT,
  NET_DM_CMD_CONFIG,
  NET_DM_CMD_START,
  NET_DM_CMD_STOP,
  NET_DM_CMD_PACKET_ALERT,
  NET_DM_CMD_CONFIG_GET,
  NET_DM_CMD_CONFIG_NEW,
  NET_DM_CMD_STATS_GET,
  NET_DM_CMD_STATS_NEW,
  _NET_DM_CMD_MAX,
};
#define NET_DM_CMD_MAX (_NET_DM_CMD_MAX - 1)
#define NET_DM_GRP_ALERT 1
enum net_dm_attr {
  NET_DM_ATTR_UNSPEC,
  NET_DM_ATTR_ALERT_MODE,
  NET_DM_ATTR_PC,
  NET_DM_ATTR_SYMBOL,
  NET_DM_ATTR_IN_PORT,
  NET_DM_ATTR_TIMESTAMP,
  NET_DM_ATTR_PROTO,
  NET_DM_ATTR_PAYLOAD,
  NET_DM_ATTR_PAD,
  NET_DM_ATTR_TRUNC_LEN,
  NET_DM_ATTR_ORIG_LEN,
  NET_DM_ATTR_QUEUE_LEN,
  NET_DM_ATTR_STATS,
  NET_DM_ATTR_HW_STATS,
  NET_DM_ATTR_ORIGIN,
  NET_DM_ATTR_HW_TRAP_GROUP_NAME,
  NET_DM_ATTR_HW_TRAP_NAME,
  NET_DM_ATTR_HW_ENTRIES,
  NET_DM_ATTR_HW_ENTRY,
  NET_DM_ATTR_HW_TRAP_COUNT,
  NET_DM_ATTR_SW_DROPS,
  NET_DM_ATTR_HW_DROPS,
  NET_DM_ATTR_FLOW_ACTION_COOKIE,
  __NET_DM_ATTR_MAX,
  NET_DM_ATTR_MAX = __NET_DM_ATTR_MAX - 1
};
enum net_dm_alert_mode {
  NET_DM_ALERT_MODE_SUMMARY,
  NET_DM_ALERT_MODE_PACKET,
};
enum {
  NET_DM_ATTR_PORT_NETDEV_IFINDEX,
  NET_DM_ATTR_PORT_NETDEV_NAME,
  __NET_DM_ATTR_PORT_MAX,
  NET_DM_ATTR_PORT_MAX = __NET_DM_ATTR_PORT_MAX - 1
};
enum {
  NET_DM_ATTR_STATS_DROPPED,
  __NET_DM_ATTR_STATS_MAX,
  NET_DM_ATTR_STATS_MAX = __NET_DM_ATTR_STATS_MAX - 1
};
enum net_dm_origin {
  NET_DM_ORIGIN_SW,
  NET_DM_ORIGIN_HW,
};
#endif