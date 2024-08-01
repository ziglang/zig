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
#ifndef I40IW_ABI_H
#define I40IW_ABI_H
#include <linux/types.h>
#define I40IW_ABI_VER 5
struct i40iw_alloc_ucontext_req {
  __u32 reserved32;
  __u8 userspace_ver;
  __u8 reserved8[3];
};
struct i40iw_alloc_ucontext_resp {
  __u32 max_pds;
  __u32 max_qps;
  __u32 wq_size;
  __u8 kernel_ver;
  __u8 reserved[3];
};
struct i40iw_alloc_pd_resp {
  __u32 pd_id;
  __u8 reserved[4];
};
struct i40iw_create_cq_req {
  __aligned_u64 user_cq_buffer;
  __aligned_u64 user_shadow_area;
};
struct i40iw_create_qp_req {
  __aligned_u64 user_wqe_buffers;
  __aligned_u64 user_compl_ctx;
  __aligned_u64 user_sq_phb;
  __aligned_u64 user_rq_phb;
};
enum i40iw_memreg_type {
  IW_MEMREG_TYPE_MEM = 0x0000,
  IW_MEMREG_TYPE_QP = 0x0001,
  IW_MEMREG_TYPE_CQ = 0x0002,
};
struct i40iw_mem_reg_req {
  __u16 reg_type;
  __u16 cq_pages;
  __u16 rq_pages;
  __u16 sq_pages;
};
struct i40iw_create_cq_resp {
  __u32 cq_id;
  __u32 cq_size;
  __u32 mmap_db_index;
  __u32 reserved;
};
struct i40iw_create_qp_resp {
  __u32 qp_id;
  __u32 actual_sq_size;
  __u32 actual_rq_size;
  __u32 i40iw_drv_opt;
  __u16 push_idx;
  __u8 lsmm;
  __u8 rsvd2;
};
#endif