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
#ifndef HNS_ABI_USER_H
#define HNS_ABI_USER_H
#include <linux/types.h>
struct hns_roce_ib_create_cq {
  __aligned_u64 buf_addr;
  __aligned_u64 db_addr;
  __u32 cqe_size;
  __u32 reserved;
};
struct hns_roce_ib_create_cq_resp {
  __aligned_u64 cqn;
  __aligned_u64 cap_flags;
};
struct hns_roce_ib_create_srq {
  __aligned_u64 buf_addr;
  __aligned_u64 db_addr;
  __aligned_u64 que_addr;
};
struct hns_roce_ib_create_srq_resp {
  __u32 srqn;
  __u32 reserved;
};
struct hns_roce_ib_create_qp {
  __aligned_u64 buf_addr;
  __aligned_u64 db_addr;
  __u8 log_sq_bb_count;
  __u8 log_sq_stride;
  __u8 sq_no_prefetch;
  __u8 reserved[5];
  __aligned_u64 sdb_addr;
};
struct hns_roce_ib_create_qp_resp {
  __aligned_u64 cap_flags;
};
struct hns_roce_ib_alloc_ucontext_resp {
  __u32 qp_tab_size;
  __u32 cqe_size;
};
struct hns_roce_ib_alloc_pd_resp {
  __u32 pdn;
};
#endif