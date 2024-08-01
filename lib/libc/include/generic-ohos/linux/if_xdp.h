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
#ifndef _LINUX_IF_XDP_H
#define _LINUX_IF_XDP_H
#include <linux/types.h>
#define XDP_SHARED_UMEM (1 << 0)
#define XDP_COPY (1 << 1)
#define XDP_ZEROCOPY (1 << 2)
#define XDP_USE_NEED_WAKEUP (1 << 3)
#define XDP_UMEM_UNALIGNED_CHUNK_FLAG (1 << 0)
struct sockaddr_xdp {
  __u16 sxdp_family;
  __u16 sxdp_flags;
  __u32 sxdp_ifindex;
  __u32 sxdp_queue_id;
  __u32 sxdp_shared_umem_fd;
};
#define XDP_RING_NEED_WAKEUP (1 << 0)
struct xdp_ring_offset {
  __u64 producer;
  __u64 consumer;
  __u64 desc;
  __u64 flags;
};
struct xdp_mmap_offsets {
  struct xdp_ring_offset rx;
  struct xdp_ring_offset tx;
  struct xdp_ring_offset fr;
  struct xdp_ring_offset cr;
};
#define XDP_MMAP_OFFSETS 1
#define XDP_RX_RING 2
#define XDP_TX_RING 3
#define XDP_UMEM_REG 4
#define XDP_UMEM_FILL_RING 5
#define XDP_UMEM_COMPLETION_RING 6
#define XDP_STATISTICS 7
#define XDP_OPTIONS 8
struct xdp_umem_reg {
  __u64 addr;
  __u64 len;
  __u32 chunk_size;
  __u32 headroom;
  __u32 flags;
};
struct xdp_statistics {
  __u64 rx_dropped;
  __u64 rx_invalid_descs;
  __u64 tx_invalid_descs;
  __u64 rx_ring_full;
  __u64 rx_fill_ring_empty_descs;
  __u64 tx_ring_empty_descs;
};
struct xdp_options {
  __u32 flags;
};
#define XDP_OPTIONS_ZEROCOPY (1 << 0)
#define XDP_PGOFF_RX_RING 0
#define XDP_PGOFF_TX_RING 0x80000000
#define XDP_UMEM_PGOFF_FILL_RING 0x100000000ULL
#define XDP_UMEM_PGOFF_COMPLETION_RING 0x180000000ULL
#define XSK_UNALIGNED_BUF_OFFSET_SHIFT 48
#define XSK_UNALIGNED_BUF_ADDR_MASK ((1ULL << XSK_UNALIGNED_BUF_OFFSET_SHIFT) - 1)
struct xdp_desc {
  __u64 addr;
  __u32 len;
  __u32 options;
};
#endif