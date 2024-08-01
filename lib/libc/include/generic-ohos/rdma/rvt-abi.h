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
#ifndef RVT_ABI_USER_H
#define RVT_ABI_USER_H
#include <linux/types.h>
#include <rdma/ib_user_verbs.h>
#ifndef RDMA_ATOMIC_UAPI
#define RDMA_ATOMIC_UAPI(_type,_name) struct { _type val; } _name
#endif
struct rvt_wqe_sge {
  __aligned_u64 addr;
  __u32 length;
  __u32 lkey;
};
struct rvt_cq_wc {
  RDMA_ATOMIC_UAPI(__u32, head);
  RDMA_ATOMIC_UAPI(__u32, tail);
  struct ib_uverbs_wc uqueue[];
};
struct rvt_rwqe {
  __u64 wr_id;
  __u8 num_sge;
  __u8 padding[7];
  struct rvt_wqe_sge sg_list[];
};
struct rvt_rwq {
  RDMA_ATOMIC_UAPI(__u32, head);
  RDMA_ATOMIC_UAPI(__u32, tail);
  struct rvt_rwqe wq[];
};
#endif