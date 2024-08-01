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
#ifndef __LINUX_FIB_RULES_H
#define __LINUX_FIB_RULES_H
#include <linux/types.h>
#include <linux/rtnetlink.h>
#define FIB_RULE_PERMANENT 0x00000001
#define FIB_RULE_INVERT 0x00000002
#define FIB_RULE_UNRESOLVED 0x00000004
#define FIB_RULE_IIF_DETACHED 0x00000008
#define FIB_RULE_DEV_DETACHED FIB_RULE_IIF_DETACHED
#define FIB_RULE_OIF_DETACHED 0x00000010
#define FIB_RULE_FIND_SADDR 0x00010000
struct fib_rule_hdr {
  __u8 family;
  __u8 dst_len;
  __u8 src_len;
  __u8 tos;
  __u8 table;
  __u8 res1;
  __u8 res2;
  __u8 action;
  __u32 flags;
};
struct fib_rule_uid_range {
  __u32 start;
  __u32 end;
};
struct fib_rule_port_range {
  __u16 start;
  __u16 end;
};
enum {
  FRA_UNSPEC,
  FRA_DST,
  FRA_SRC,
  FRA_IIFNAME,
#define FRA_IFNAME FRA_IIFNAME
  FRA_GOTO,
  FRA_UNUSED2,
  FRA_PRIORITY,
  FRA_UNUSED3,
  FRA_UNUSED4,
  FRA_UNUSED5,
  FRA_FWMARK,
  FRA_FLOW,
  FRA_TUN_ID,
  FRA_SUPPRESS_IFGROUP,
  FRA_SUPPRESS_PREFIXLEN,
  FRA_TABLE,
  FRA_FWMASK,
  FRA_OIFNAME,
  FRA_PAD,
  FRA_L3MDEV,
  FRA_UID_RANGE,
  FRA_PROTOCOL,
  FRA_IP_PROTO,
  FRA_SPORT_RANGE,
  FRA_DPORT_RANGE,
  __FRA_MAX
};
#define FRA_MAX (__FRA_MAX - 1)
enum {
  FR_ACT_UNSPEC,
  FR_ACT_TO_TBL,
  FR_ACT_GOTO,
  FR_ACT_NOP,
  FR_ACT_RES3,
  FR_ACT_RES4,
  FR_ACT_BLACKHOLE,
  FR_ACT_UNREACHABLE,
  FR_ACT_PROHIBIT,
  __FR_ACT_MAX,
};
#define FR_ACT_MAX (__FR_ACT_MAX - 1)
#endif