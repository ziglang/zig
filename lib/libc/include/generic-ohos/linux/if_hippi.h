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
#ifndef _LINUX_IF_HIPPI_H
#define _LINUX_IF_HIPPI_H
#include <linux/types.h>
#include <asm/byteorder.h>
#define HIPPI_ALEN 6
#define HIPPI_HLEN sizeof(struct hippi_hdr)
#define HIPPI_ZLEN 0
#define HIPPI_DATA_LEN 65280
#define HIPPI_FRAME_LEN (HIPPI_DATA_LEN + HIPPI_HLEN)
#define HIPPI_EXTENDED_SAP 0xAA
#define HIPPI_UI_CMD 0x03
struct hipnet_statistics {
  int rx_packets;
  int tx_packets;
  int rx_errors;
  int tx_errors;
  int rx_dropped;
  int tx_dropped;
  int rx_length_errors;
  int rx_over_errors;
  int rx_crc_errors;
  int rx_frame_errors;
  int rx_fifo_errors;
  int rx_missed_errors;
  int tx_aborted_errors;
  int tx_carrier_errors;
  int tx_fifo_errors;
  int tx_heartbeat_errors;
  int tx_window_errors;
};
struct hippi_fp_hdr {
  __be32 fixed;
  __be32 d2_size;
} __attribute__((packed));
struct hippi_le_hdr {
#ifdef __BIG_ENDIAN_BITFIELD
  __u8 fc : 3;
  __u8 double_wide : 1;
  __u8 message_type : 4;
#elif defined(__LITTLE_ENDIAN_BITFIELD)
  __u8 message_type : 4;
  __u8 double_wide : 1;
  __u8 fc : 3;
#endif
  __u8 dest_switch_addr[3];
#ifdef __BIG_ENDIAN_BITFIELD
  __u8 dest_addr_type : 4, src_addr_type : 4;
#elif defined(__LITTLE_ENDIAN_BITFIELD)
  __u8 src_addr_type : 4, dest_addr_type : 4;
#endif
  __u8 src_switch_addr[3];
  __u16 reserved;
  __u8 daddr[HIPPI_ALEN];
  __u16 locally_administered;
  __u8 saddr[HIPPI_ALEN];
} __attribute__((packed));
#define HIPPI_OUI_LEN 3
struct hippi_snap_hdr {
  __u8 dsap;
  __u8 ssap;
  __u8 ctrl;
  __u8 oui[HIPPI_OUI_LEN];
  __be16 ethertype;
} __attribute__((packed));
struct hippi_hdr {
  struct hippi_fp_hdr fp;
  struct hippi_le_hdr le;
  struct hippi_snap_hdr snap;
} __attribute__((packed));
#endif