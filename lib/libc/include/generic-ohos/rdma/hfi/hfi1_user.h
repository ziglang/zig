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
#ifndef _LINUX__HFI1_USER_H
#define _LINUX__HFI1_USER_H
#include <linux/types.h>
#include <rdma/rdma_user_ioctl.h>
#define HFI1_USER_SWMAJOR 6
#define HFI1_USER_SWMINOR 3
#define HFI1_SWMAJOR_SHIFT 16
#define HFI1_CAP_DMA_RTAIL (1UL << 0)
#define HFI1_CAP_SDMA (1UL << 1)
#define HFI1_CAP_SDMA_AHG (1UL << 2)
#define HFI1_CAP_EXTENDED_PSN (1UL << 3)
#define HFI1_CAP_HDRSUPP (1UL << 4)
#define HFI1_CAP_TID_RDMA (1UL << 5)
#define HFI1_CAP_USE_SDMA_HEAD (1UL << 6)
#define HFI1_CAP_MULTI_PKT_EGR (1UL << 7)
#define HFI1_CAP_NODROP_RHQ_FULL (1UL << 8)
#define HFI1_CAP_NODROP_EGR_FULL (1UL << 9)
#define HFI1_CAP_TID_UNMAP (1UL << 10)
#define HFI1_CAP_PRINT_UNIMPL (1UL << 11)
#define HFI1_CAP_ALLOW_PERM_JKEY (1UL << 12)
#define HFI1_CAP_NO_INTEGRITY (1UL << 13)
#define HFI1_CAP_PKEY_CHECK (1UL << 14)
#define HFI1_CAP_STATIC_RATE_CTRL (1UL << 15)
#define HFI1_CAP_OPFN (1UL << 16)
#define HFI1_CAP_SDMA_HEAD_CHECK (1UL << 17)
#define HFI1_CAP_EARLY_CREDIT_RETURN (1UL << 18)
#define HFI1_CAP_AIP (1UL << 19)
#define HFI1_RCVHDR_ENTSIZE_2 (1UL << 0)
#define HFI1_RCVHDR_ENTSIZE_16 (1UL << 1)
#define HFI1_RCVDHR_ENTSIZE_32 (1UL << 2)
#define _HFI1_EVENT_FROZEN_BIT 0
#define _HFI1_EVENT_LINKDOWN_BIT 1
#define _HFI1_EVENT_LID_CHANGE_BIT 2
#define _HFI1_EVENT_LMC_CHANGE_BIT 3
#define _HFI1_EVENT_SL2VL_CHANGE_BIT 4
#define _HFI1_EVENT_TID_MMU_NOTIFY_BIT 5
#define _HFI1_MAX_EVENT_BIT _HFI1_EVENT_TID_MMU_NOTIFY_BIT
#define HFI1_EVENT_FROZEN (1UL << _HFI1_EVENT_FROZEN_BIT)
#define HFI1_EVENT_LINKDOWN (1UL << _HFI1_EVENT_LINKDOWN_BIT)
#define HFI1_EVENT_LID_CHANGE (1UL << _HFI1_EVENT_LID_CHANGE_BIT)
#define HFI1_EVENT_LMC_CHANGE (1UL << _HFI1_EVENT_LMC_CHANGE_BIT)
#define HFI1_EVENT_SL2VL_CHANGE (1UL << _HFI1_EVENT_SL2VL_CHANGE_BIT)
#define HFI1_EVENT_TID_MMU_NOTIFY (1UL << _HFI1_EVENT_TID_MMU_NOTIFY_BIT)
#define HFI1_STATUS_INITTED 0x1
#define HFI1_STATUS_CHIP_PRESENT 0x20
#define HFI1_STATUS_IB_READY 0x40
#define HFI1_STATUS_IB_CONF 0x80
#define HFI1_STATUS_HWERROR 0x200
#define HFI1_MAX_SHARED_CTXTS 8
#define HFI1_POLL_TYPE_ANYRCV 0x0
#define HFI1_POLL_TYPE_URGENT 0x1
enum hfi1_sdma_comp_state {
  FREE = 0,
  QUEUED,
  COMPLETE,
  ERROR
};
struct hfi1_sdma_comp_entry {
  __u32 status;
  __u32 errcode;
};
struct hfi1_status {
  __aligned_u64 dev;
  __aligned_u64 port;
  char freezemsg[0];
};
enum sdma_req_opcode {
  EXPECTED = 0,
  EAGER
};
#define HFI1_SDMA_REQ_VERSION_MASK 0xF
#define HFI1_SDMA_REQ_VERSION_SHIFT 0x0
#define HFI1_SDMA_REQ_OPCODE_MASK 0xF
#define HFI1_SDMA_REQ_OPCODE_SHIFT 0x4
#define HFI1_SDMA_REQ_IOVCNT_MASK 0xFF
#define HFI1_SDMA_REQ_IOVCNT_SHIFT 0x8
struct sdma_req_info {
  __u16 ctrl;
  __u16 npkts;
  __u16 fragsize;
  __u16 comp_idx;
} __attribute__((__packed__));
struct hfi1_kdeth_header {
  __le32 ver_tid_offset;
  __le16 jkey;
  __le16 hcrc;
  __le32 swdata[7];
} __attribute__((__packed__));
struct hfi1_pkt_header {
  __le16 pbc[4];
  __be16 lrh[4];
  __be32 bth[3];
  struct hfi1_kdeth_header kdeth;
} __attribute__((__packed__));
enum hfi1_ureg {
  ur_rcvhdrtail = 0,
  ur_rcvhdrhead = 1,
  ur_rcvegrindextail = 2,
  ur_rcvegrindexhead = 3,
  ur_rcvegroffsettail = 4,
  ur_maxreg,
  ur_rcvtidflowtable = 256
};
#endif