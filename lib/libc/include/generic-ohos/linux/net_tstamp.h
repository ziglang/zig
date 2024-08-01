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
#ifndef _NET_TIMESTAMPING_H
#define _NET_TIMESTAMPING_H
#include <linux/types.h>
#include <linux/socket.h>
enum {
  SOF_TIMESTAMPING_TX_HARDWARE = (1 << 0),
  SOF_TIMESTAMPING_TX_SOFTWARE = (1 << 1),
  SOF_TIMESTAMPING_RX_HARDWARE = (1 << 2),
  SOF_TIMESTAMPING_RX_SOFTWARE = (1 << 3),
  SOF_TIMESTAMPING_SOFTWARE = (1 << 4),
  SOF_TIMESTAMPING_SYS_HARDWARE = (1 << 5),
  SOF_TIMESTAMPING_RAW_HARDWARE = (1 << 6),
  SOF_TIMESTAMPING_OPT_ID = (1 << 7),
  SOF_TIMESTAMPING_TX_SCHED = (1 << 8),
  SOF_TIMESTAMPING_TX_ACK = (1 << 9),
  SOF_TIMESTAMPING_OPT_CMSG = (1 << 10),
  SOF_TIMESTAMPING_OPT_TSONLY = (1 << 11),
  SOF_TIMESTAMPING_OPT_STATS = (1 << 12),
  SOF_TIMESTAMPING_OPT_PKTINFO = (1 << 13),
  SOF_TIMESTAMPING_OPT_TX_SWHW = (1 << 14),
  SOF_TIMESTAMPING_LAST = SOF_TIMESTAMPING_OPT_TX_SWHW,
  SOF_TIMESTAMPING_MASK = (SOF_TIMESTAMPING_LAST - 1) | SOF_TIMESTAMPING_LAST
};
#define SOF_TIMESTAMPING_TX_RECORD_MASK (SOF_TIMESTAMPING_TX_HARDWARE | SOF_TIMESTAMPING_TX_SOFTWARE | SOF_TIMESTAMPING_TX_SCHED | SOF_TIMESTAMPING_TX_ACK)
struct hwtstamp_config {
  int flags;
  int tx_type;
  int rx_filter;
};
enum hwtstamp_tx_types {
  HWTSTAMP_TX_OFF,
  HWTSTAMP_TX_ON,
  HWTSTAMP_TX_ONESTEP_SYNC,
  HWTSTAMP_TX_ONESTEP_P2P,
  __HWTSTAMP_TX_CNT
};
enum hwtstamp_rx_filters {
  HWTSTAMP_FILTER_NONE,
  HWTSTAMP_FILTER_ALL,
  HWTSTAMP_FILTER_SOME,
  HWTSTAMP_FILTER_PTP_V1_L4_EVENT,
  HWTSTAMP_FILTER_PTP_V1_L4_SYNC,
  HWTSTAMP_FILTER_PTP_V1_L4_DELAY_REQ,
  HWTSTAMP_FILTER_PTP_V2_L4_EVENT,
  HWTSTAMP_FILTER_PTP_V2_L4_SYNC,
  HWTSTAMP_FILTER_PTP_V2_L4_DELAY_REQ,
  HWTSTAMP_FILTER_PTP_V2_L2_EVENT,
  HWTSTAMP_FILTER_PTP_V2_L2_SYNC,
  HWTSTAMP_FILTER_PTP_V2_L2_DELAY_REQ,
  HWTSTAMP_FILTER_PTP_V2_EVENT,
  HWTSTAMP_FILTER_PTP_V2_SYNC,
  HWTSTAMP_FILTER_PTP_V2_DELAY_REQ,
  HWTSTAMP_FILTER_NTP_ALL,
  __HWTSTAMP_FILTER_CNT
};
struct scm_ts_pktinfo {
  __u32 if_index;
  __u32 pkt_length;
  __u32 reserved[2];
};
enum txtime_flags {
  SOF_TXTIME_DEADLINE_MODE = (1 << 0),
  SOF_TXTIME_REPORT_ERRORS = (1 << 1),
  SOF_TXTIME_FLAGS_LAST = SOF_TXTIME_REPORT_ERRORS,
  SOF_TXTIME_FLAGS_MASK = (SOF_TXTIME_FLAGS_LAST - 1) | SOF_TXTIME_FLAGS_LAST
};
struct sock_txtime {
  __kernel_clockid_t clockid;
  __u32 flags;
};
#endif