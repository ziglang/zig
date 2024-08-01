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
#ifndef __BNXT_RE_UVERBS_ABI_H__
#define __BNXT_RE_UVERBS_ABI_H__
#include <linux/types.h>
#define BNXT_RE_ABI_VERSION 1
#define BNXT_RE_CHIP_ID0_CHIP_NUM_SFT 0x00
#define BNXT_RE_CHIP_ID0_CHIP_REV_SFT 0x10
#define BNXT_RE_CHIP_ID0_CHIP_MET_SFT 0x18
enum {
  BNXT_RE_UCNTX_CMASK_HAVE_CCTX = 0x1ULL
};
struct bnxt_re_uctx_resp {
  __u32 dev_id;
  __u32 max_qp;
  __u32 pg_size;
  __u32 cqe_sz;
  __u32 max_cqd;
  __u32 rsvd;
  __aligned_u64 comp_mask;
  __u32 chip_id0;
  __u32 chip_id1;
};
struct bnxt_re_pd_resp {
  __u32 pdid;
  __u32 dpi;
  __u64 dbr;
} __attribute__((packed, aligned(4)));
struct bnxt_re_cq_req {
  __aligned_u64 cq_va;
  __aligned_u64 cq_handle;
};
struct bnxt_re_cq_resp {
  __u32 cqid;
  __u32 tail;
  __u32 phase;
  __u32 rsvd;
};
struct bnxt_re_qp_req {
  __aligned_u64 qpsva;
  __aligned_u64 qprva;
  __aligned_u64 qp_handle;
};
struct bnxt_re_qp_resp {
  __u32 qpid;
  __u32 rsvd;
};
struct bnxt_re_srq_req {
  __aligned_u64 srqva;
  __aligned_u64 srq_handle;
};
struct bnxt_re_srq_resp {
  __u32 srqid;
};
enum bnxt_re_shpg_offt {
  BNXT_RE_BEG_RESV_OFFT = 0x00,
  BNXT_RE_AVID_OFFT = 0x10,
  BNXT_RE_AVID_SIZE = 0x04,
  BNXT_RE_END_RESV_OFFT = 0xFF0
};
#endif