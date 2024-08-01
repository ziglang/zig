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
#ifndef _UAPI__PKTCDVD_H
#define _UAPI__PKTCDVD_H
#include <linux/types.h>
#define PACKET_DEBUG 1
#define MAX_WRITERS 8
#define PKT_RB_POOL_SIZE 512
#define PACKET_WAIT_TIME (HZ * 5 / 1000)
#define USE_WCACHING 0
#define PACKET_CDR 1
#define PACKET_CDRW 2
#define PACKET_DVDR 3
#define PACKET_DVDRW 4
#define PACKET_WRITABLE 1
#define PACKET_NWA_VALID 2
#define PACKET_LRA_VALID 3
#define PACKET_MERGE_SEGS 4
#define PACKET_DISC_EMPTY 0
#define PACKET_DISC_INCOMPLETE 1
#define PACKET_DISC_COMPLETE 2
#define PACKET_DISC_OTHER 3
#define PACKET_MODE1 1
#define PACKET_MODE2 2
#define PACKET_BLOCK_MODE1 8
#define PACKET_BLOCK_MODE2 10
#define PACKET_SESSION_EMPTY 0
#define PACKET_SESSION_INCOMPLETE 1
#define PACKET_SESSION_RESERVED 2
#define PACKET_SESSION_COMPLETE 3
#define PACKET_MCN "4a656e734178626f65323030300000"
#undef PACKET_USE_LS
#define PKT_CTRL_CMD_SETUP 0
#define PKT_CTRL_CMD_TEARDOWN 1
#define PKT_CTRL_CMD_STATUS 2
struct pkt_ctrl_command {
  __u32 command;
  __u32 dev_index;
  __u32 dev;
  __u32 pkt_dev;
  __u32 num_devices;
  __u32 padding;
};
#define PACKET_IOCTL_MAGIC ('X')
#define PACKET_CTRL_CMD _IOWR(PACKET_IOCTL_MAGIC, 1, struct pkt_ctrl_command)
#endif