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
#ifndef MLX4_ABI_USER_H
#define MLX4_ABI_USER_H
#include <linux/types.h>
#define MLX4_IB_UVERBS_NO_DEV_CAPS_ABI_VERSION 3
#define MLX4_IB_UVERBS_ABI_VERSION 4
struct mlx4_ib_alloc_ucontext_resp_v3 {
  __u32 qp_tab_size;
  __u16 bf_reg_size;
  __u16 bf_regs_per_page;
};
enum {
  MLX4_USER_DEV_CAP_LARGE_CQE = 1L << 0,
};
struct mlx4_ib_alloc_ucontext_resp {
  __u32 dev_caps;
  __u32 qp_tab_size;
  __u16 bf_reg_size;
  __u16 bf_regs_per_page;
  __u32 cqe_size;
};
struct mlx4_ib_alloc_pd_resp {
  __u32 pdn;
  __u32 reserved;
};
struct mlx4_ib_create_cq {
  __aligned_u64 buf_addr;
  __aligned_u64 db_addr;
};
struct mlx4_ib_create_cq_resp {
  __u32 cqn;
  __u32 reserved;
};
struct mlx4_ib_resize_cq {
  __aligned_u64 buf_addr;
};
struct mlx4_ib_create_srq {
  __aligned_u64 buf_addr;
  __aligned_u64 db_addr;
};
struct mlx4_ib_create_srq_resp {
  __u32 srqn;
  __u32 reserved;
};
struct mlx4_ib_create_qp_rss {
  __aligned_u64 rx_hash_fields_mask;
  __u8 rx_hash_function;
  __u8 reserved[7];
  __u8 rx_hash_key[40];
  __u32 comp_mask;
  __u32 reserved1;
};
struct mlx4_ib_create_qp {
  __aligned_u64 buf_addr;
  __aligned_u64 db_addr;
  __u8 log_sq_bb_count;
  __u8 log_sq_stride;
  __u8 sq_no_prefetch;
  __u8 reserved;
  __u32 inl_recv_sz;
};
struct mlx4_ib_create_wq {
  __aligned_u64 buf_addr;
  __aligned_u64 db_addr;
  __u8 log_range_size;
  __u8 reserved[3];
  __u32 comp_mask;
};
struct mlx4_ib_modify_wq {
  __u32 comp_mask;
  __u32 reserved;
};
struct mlx4_ib_create_rwq_ind_tbl_resp {
  __u32 response_length;
  __u32 reserved;
};
enum mlx4_ib_rx_hash_function_flags {
  MLX4_IB_RX_HASH_FUNC_TOEPLITZ = 1 << 0,
};
enum mlx4_ib_rx_hash_fields {
  MLX4_IB_RX_HASH_SRC_IPV4 = 1 << 0,
  MLX4_IB_RX_HASH_DST_IPV4 = 1 << 1,
  MLX4_IB_RX_HASH_SRC_IPV6 = 1 << 2,
  MLX4_IB_RX_HASH_DST_IPV6 = 1 << 3,
  MLX4_IB_RX_HASH_SRC_PORT_TCP = 1 << 4,
  MLX4_IB_RX_HASH_DST_PORT_TCP = 1 << 5,
  MLX4_IB_RX_HASH_SRC_PORT_UDP = 1 << 6,
  MLX4_IB_RX_HASH_DST_PORT_UDP = 1 << 7,
  MLX4_IB_RX_HASH_INNER = 1ULL << 31,
};
struct mlx4_ib_rss_caps {
  __aligned_u64 rx_hash_fields_mask;
  __u8 rx_hash_function;
  __u8 reserved[7];
};
enum query_device_resp_mask {
  MLX4_IB_QUERY_DEV_RESP_MASK_CORE_CLOCK_OFFSET = 1UL << 0,
};
struct mlx4_ib_tso_caps {
  __u32 max_tso;
  __u32 supported_qpts;
};
struct mlx4_uverbs_ex_query_device_resp {
  __u32 comp_mask;
  __u32 response_length;
  __aligned_u64 hca_core_clock_offset;
  __u32 max_inl_recv_sz;
  __u32 reserved;
  struct mlx4_ib_rss_caps rss_caps;
  struct mlx4_ib_tso_caps tso_caps;
};
#endif