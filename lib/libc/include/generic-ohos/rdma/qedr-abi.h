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
#ifndef __QEDR_USER_H__
#define __QEDR_USER_H__
#include <linux/types.h>
#define QEDR_ABI_VERSION (8)
enum qedr_alloc_ucontext_flags {
  QEDR_ALLOC_UCTX_EDPM_MODE = 1 << 0,
  QEDR_ALLOC_UCTX_DB_REC = 1 << 1,
  QEDR_SUPPORT_DPM_SIZES = 1 << 2,
};
struct qedr_alloc_ucontext_req {
  __u32 context_flags;
  __u32 reserved;
};
#define QEDR_LDPM_MAX_SIZE (8192)
#define QEDR_EDPM_TRANS_SIZE (64)
#define QEDR_EDPM_MAX_SIZE (ROCE_REQ_MAX_INLINE_DATA_SIZE)
enum qedr_rdma_dpm_type {
  QEDR_DPM_TYPE_NONE = 0,
  QEDR_DPM_TYPE_ROCE_ENHANCED = 1 << 0,
  QEDR_DPM_TYPE_ROCE_LEGACY = 1 << 1,
  QEDR_DPM_TYPE_IWARP_LEGACY = 1 << 2,
  QEDR_DPM_TYPE_ROCE_EDPM_MODE = 1 << 3,
  QEDR_DPM_SIZES_SET = 1 << 4,
};
struct qedr_alloc_ucontext_resp {
  __aligned_u64 db_pa;
  __u32 db_size;
  __u32 max_send_wr;
  __u32 max_recv_wr;
  __u32 max_srq_wr;
  __u32 sges_per_send_wr;
  __u32 sges_per_recv_wr;
  __u32 sges_per_srq_wr;
  __u32 max_cqes;
  __u8 dpm_flags;
  __u8 wids_enabled;
  __u16 wid_count;
  __u16 ldpm_limit_size;
  __u8 edpm_trans_size;
  __u8 reserved;
  __u16 edpm_limit_size;
  __u8 padding[6];
};
struct qedr_alloc_pd_ureq {
  __aligned_u64 rsvd1;
};
struct qedr_alloc_pd_uresp {
  __u32 pd_id;
  __u32 reserved;
};
struct qedr_create_cq_ureq {
  __aligned_u64 addr;
  __aligned_u64 len;
};
struct qedr_create_cq_uresp {
  __u32 db_offset;
  __u16 icid;
  __u16 reserved;
  __aligned_u64 db_rec_addr;
};
struct qedr_create_qp_ureq {
  __u32 qp_handle_hi;
  __u32 qp_handle_lo;
  __aligned_u64 sq_addr;
  __aligned_u64 sq_len;
  __aligned_u64 rq_addr;
  __aligned_u64 rq_len;
};
struct qedr_create_qp_uresp {
  __u32 qp_id;
  __u32 atomic_supported;
  __u32 sq_db_offset;
  __u16 sq_icid;
  __u32 rq_db_offset;
  __u16 rq_icid;
  __u32 rq_db2_offset;
  __u32 reserved;
  __aligned_u64 sq_db_rec_addr;
  __aligned_u64 rq_db_rec_addr;
};
struct qedr_create_srq_ureq {
  __aligned_u64 prod_pair_addr;
  __aligned_u64 srq_addr;
  __aligned_u64 srq_len;
};
struct qedr_create_srq_uresp {
  __u16 srq_id;
  __u16 reserved0;
  __u32 reserved1;
};
struct qedr_user_db_rec {
  __aligned_u64 db_data;
};
#endif