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
#ifndef __NETLINK_DIAG_H__
#define __NETLINK_DIAG_H__
#include <linux/types.h>
struct netlink_diag_req {
  __u8 sdiag_family;
  __u8 sdiag_protocol;
  __u16 pad;
  __u32 ndiag_ino;
  __u32 ndiag_show;
  __u32 ndiag_cookie[2];
};
struct netlink_diag_msg {
  __u8 ndiag_family;
  __u8 ndiag_type;
  __u8 ndiag_protocol;
  __u8 ndiag_state;
  __u32 ndiag_portid;
  __u32 ndiag_dst_portid;
  __u32 ndiag_dst_group;
  __u32 ndiag_ino;
  __u32 ndiag_cookie[2];
};
struct netlink_diag_ring {
  __u32 ndr_block_size;
  __u32 ndr_block_nr;
  __u32 ndr_frame_size;
  __u32 ndr_frame_nr;
};
enum {
  NETLINK_DIAG_MEMINFO,
  NETLINK_DIAG_GROUPS,
  NETLINK_DIAG_RX_RING,
  NETLINK_DIAG_TX_RING,
  NETLINK_DIAG_FLAGS,
  __NETLINK_DIAG_MAX,
};
#define NETLINK_DIAG_MAX (__NETLINK_DIAG_MAX - 1)
#define NDIAG_PROTO_ALL ((__u8) ~0)
#define NDIAG_SHOW_MEMINFO 0x00000001
#define NDIAG_SHOW_GROUPS 0x00000002
#define NDIAG_SHOW_RING_CFG 0x00000004
#define NDIAG_SHOW_FLAGS 0x00000008
#define NDIAG_FLAG_CB_RUNNING 0x00000001
#define NDIAG_FLAG_PKTINFO 0x00000002
#define NDIAG_FLAG_BROADCAST_ERROR 0x00000004
#define NDIAG_FLAG_NO_ENOBUFS 0x00000008
#define NDIAG_FLAG_LISTEN_ALL_NSID 0x00000010
#define NDIAG_FLAG_CAP_ACK 0x00000020
#endif