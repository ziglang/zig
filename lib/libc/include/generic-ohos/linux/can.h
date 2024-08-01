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
#ifndef _UAPI_CAN_H
#define _UAPI_CAN_H
#include <linux/types.h>
#include <linux/socket.h>
#define CAN_EFF_FLAG 0x80000000U
#define CAN_RTR_FLAG 0x40000000U
#define CAN_ERR_FLAG 0x20000000U
#define CAN_SFF_MASK 0x000007FFU
#define CAN_EFF_MASK 0x1FFFFFFFU
#define CAN_ERR_MASK 0x1FFFFFFFU
typedef __u32 canid_t;
#define CAN_SFF_ID_BITS 11
#define CAN_EFF_ID_BITS 29
typedef __u32 can_err_mask_t;
#define CAN_MAX_DLC 8
#define CAN_MAX_DLEN 8
#define CANFD_MAX_DLC 15
#define CANFD_MAX_DLEN 64
struct can_frame {
  canid_t can_id;
  __u8 can_dlc;
  __u8 __pad;
  __u8 __res0;
  __u8 __res1;
  __u8 data[CAN_MAX_DLEN] __attribute__((aligned(8)));
};
#define CANFD_BRS 0x01
#define CANFD_ESI 0x02
struct canfd_frame {
  canid_t can_id;
  __u8 len;
  __u8 flags;
  __u8 __res0;
  __u8 __res1;
  __u8 data[CANFD_MAX_DLEN] __attribute__((aligned(8)));
};
#define CAN_MTU (sizeof(struct can_frame))
#define CANFD_MTU (sizeof(struct canfd_frame))
#define CAN_RAW 1
#define CAN_BCM 2
#define CAN_TP16 3
#define CAN_TP20 4
#define CAN_MCNET 5
#define CAN_ISOTP 6
#define CAN_J1939 7
#define CAN_NPROTO 8
#define SOL_CAN_BASE 100
struct sockaddr_can {
  __kernel_sa_family_t can_family;
  int can_ifindex;
  union {
    struct {
      canid_t rx_id, tx_id;
    } tp;
    struct {
      __u64 name;
      __u32 pgn;
      __u8 addr;
    } j1939;
  } can_addr;
};
struct can_filter {
  canid_t can_id;
  canid_t can_mask;
};
#define CAN_INV_FILTER 0x20000000U
#define CAN_RAW_FILTER_MAX 512
#endif