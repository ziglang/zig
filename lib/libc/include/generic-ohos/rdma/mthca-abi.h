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
#ifndef MTHCA_ABI_USER_H
#define MTHCA_ABI_USER_H
#include <linux/types.h>
#define MTHCA_UVERBS_ABI_VERSION 1
struct mthca_alloc_ucontext_resp {
  __u32 qp_tab_size;
  __u32 uarc_size;
};
struct mthca_alloc_pd_resp {
  __u32 pdn;
  __u32 reserved;
};
#define MTHCA_MR_DMASYNC 0x1
struct mthca_reg_mr {
  __u32 mr_attrs;
  __u32 reserved;
};
struct mthca_create_cq {
  __u32 lkey;
  __u32 pdn;
  __aligned_u64 arm_db_page;
  __aligned_u64 set_db_page;
  __u32 arm_db_index;
  __u32 set_db_index;
};
struct mthca_create_cq_resp {
  __u32 cqn;
  __u32 reserved;
};
struct mthca_resize_cq {
  __u32 lkey;
  __u32 reserved;
};
struct mthca_create_srq {
  __u32 lkey;
  __u32 db_index;
  __aligned_u64 db_page;
};
struct mthca_create_srq_resp {
  __u32 srqn;
  __u32 reserved;
};
struct mthca_create_qp {
  __u32 lkey;
  __u32 reserved;
  __aligned_u64 sq_db_page;
  __aligned_u64 rq_db_page;
  __u32 sq_db_index;
  __u32 rq_db_index;
};
#endif