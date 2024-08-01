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
#ifndef _UAPI_CAN_J1939_H_
#define _UAPI_CAN_J1939_H_
#include <linux/types.h>
#include <linux/socket.h>
#include <linux/can.h>
#define J1939_MAX_UNICAST_ADDR 0xfd
#define J1939_IDLE_ADDR 0xfe
#define J1939_NO_ADDR 0xff
#define J1939_NO_NAME 0
#define J1939_PGN_REQUEST 0x0ea00
#define J1939_PGN_ADDRESS_CLAIMED 0x0ee00
#define J1939_PGN_ADDRESS_COMMANDED 0x0fed8
#define J1939_PGN_PDU1_MAX 0x3ff00
#define J1939_PGN_MAX 0x3ffff
#define J1939_NO_PGN 0x40000
typedef __u32 pgn_t;
typedef __u8 priority_t;
typedef __u64 name_t;
#define SOL_CAN_J1939 (SOL_CAN_BASE + CAN_J1939)
enum {
  SO_J1939_FILTER = 1,
  SO_J1939_PROMISC = 2,
  SO_J1939_SEND_PRIO = 3,
  SO_J1939_ERRQUEUE = 4,
};
enum {
  SCM_J1939_DEST_ADDR = 1,
  SCM_J1939_DEST_NAME = 2,
  SCM_J1939_PRIO = 3,
  SCM_J1939_ERRQUEUE = 4,
};
enum {
  J1939_NLA_PAD,
  J1939_NLA_BYTES_ACKED,
};
enum {
  J1939_EE_INFO_NONE,
  J1939_EE_INFO_TX_ABORT,
};
struct j1939_filter {
  name_t name;
  name_t name_mask;
  pgn_t pgn;
  pgn_t pgn_mask;
  __u8 addr;
  __u8 addr_mask;
};
#define J1939_FILTER_MAX 512
#endif