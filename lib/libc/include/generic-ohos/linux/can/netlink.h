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
#ifndef _UAPI_CAN_NETLINK_H
#define _UAPI_CAN_NETLINK_H
#include <linux/types.h>
struct can_bittiming {
  __u32 bitrate;
  __u32 sample_point;
  __u32 tq;
  __u32 prop_seg;
  __u32 phase_seg1;
  __u32 phase_seg2;
  __u32 sjw;
  __u32 brp;
};
struct can_bittiming_const {
  char name[16];
  __u32 tseg1_min;
  __u32 tseg1_max;
  __u32 tseg2_min;
  __u32 tseg2_max;
  __u32 sjw_max;
  __u32 brp_min;
  __u32 brp_max;
  __u32 brp_inc;
};
struct can_clock {
  __u32 freq;
};
enum can_state {
  CAN_STATE_ERROR_ACTIVE = 0,
  CAN_STATE_ERROR_WARNING,
  CAN_STATE_ERROR_PASSIVE,
  CAN_STATE_BUS_OFF,
  CAN_STATE_STOPPED,
  CAN_STATE_SLEEPING,
  CAN_STATE_MAX
};
struct can_berr_counter {
  __u16 txerr;
  __u16 rxerr;
};
struct can_ctrlmode {
  __u32 mask;
  __u32 flags;
};
#define CAN_CTRLMODE_LOOPBACK 0x01
#define CAN_CTRLMODE_LISTENONLY 0x02
#define CAN_CTRLMODE_3_SAMPLES 0x04
#define CAN_CTRLMODE_ONE_SHOT 0x08
#define CAN_CTRLMODE_BERR_REPORTING 0x10
#define CAN_CTRLMODE_FD 0x20
#define CAN_CTRLMODE_PRESUME_ACK 0x40
#define CAN_CTRLMODE_FD_NON_ISO 0x80
struct can_device_stats {
  __u32 bus_error;
  __u32 error_warning;
  __u32 error_passive;
  __u32 bus_off;
  __u32 arbitration_lost;
  __u32 restarts;
};
enum {
  IFLA_CAN_UNSPEC,
  IFLA_CAN_BITTIMING,
  IFLA_CAN_BITTIMING_CONST,
  IFLA_CAN_CLOCK,
  IFLA_CAN_STATE,
  IFLA_CAN_CTRLMODE,
  IFLA_CAN_RESTART_MS,
  IFLA_CAN_RESTART,
  IFLA_CAN_BERR_COUNTER,
  IFLA_CAN_DATA_BITTIMING,
  IFLA_CAN_DATA_BITTIMING_CONST,
  IFLA_CAN_TERMINATION,
  IFLA_CAN_TERMINATION_CONST,
  IFLA_CAN_BITRATE_CONST,
  IFLA_CAN_DATA_BITRATE_CONST,
  IFLA_CAN_BITRATE_MAX,
  __IFLA_CAN_MAX
};
#define IFLA_CAN_MAX (__IFLA_CAN_MAX - 1)
#define CAN_TERMINATION_DISABLED 0
#endif