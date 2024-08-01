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
#ifndef MLX5_USER_IOCTL_VERBS_H
#define MLX5_USER_IOCTL_VERBS_H
#include <linux/types.h>
enum mlx5_ib_uapi_flow_action_flags {
  MLX5_IB_UAPI_FLOW_ACTION_FLAGS_REQUIRE_METADATA = 1 << 0,
};
enum mlx5_ib_uapi_flow_table_type {
  MLX5_IB_UAPI_FLOW_TABLE_TYPE_NIC_RX = 0x0,
  MLX5_IB_UAPI_FLOW_TABLE_TYPE_NIC_TX = 0x1,
  MLX5_IB_UAPI_FLOW_TABLE_TYPE_FDB = 0x2,
  MLX5_IB_UAPI_FLOW_TABLE_TYPE_RDMA_RX = 0x3,
  MLX5_IB_UAPI_FLOW_TABLE_TYPE_RDMA_TX = 0x4,
};
enum mlx5_ib_uapi_flow_action_packet_reformat_type {
  MLX5_IB_UAPI_FLOW_ACTION_PACKET_REFORMAT_TYPE_L2_TUNNEL_TO_L2 = 0x0,
  MLX5_IB_UAPI_FLOW_ACTION_PACKET_REFORMAT_TYPE_L2_TO_L2_TUNNEL = 0x1,
  MLX5_IB_UAPI_FLOW_ACTION_PACKET_REFORMAT_TYPE_L3_TUNNEL_TO_L2 = 0x2,
  MLX5_IB_UAPI_FLOW_ACTION_PACKET_REFORMAT_TYPE_L2_TO_L3_TUNNEL = 0x3,
};
struct mlx5_ib_uapi_devx_async_cmd_hdr {
  __aligned_u64 wr_id;
  __u8 out_data[];
};
enum mlx5_ib_uapi_dm_type {
  MLX5_IB_UAPI_DM_TYPE_MEMIC,
  MLX5_IB_UAPI_DM_TYPE_STEERING_SW_ICM,
  MLX5_IB_UAPI_DM_TYPE_HEADER_MODIFY_SW_ICM,
};
enum mlx5_ib_uapi_devx_create_event_channel_flags {
  MLX5_IB_UAPI_DEVX_CR_EV_CH_FLAGS_OMIT_DATA = 1 << 0,
};
struct mlx5_ib_uapi_devx_async_event_hdr {
  __aligned_u64 cookie;
  __u8 out_data[];
};
enum mlx5_ib_uapi_pp_alloc_flags {
  MLX5_IB_UAPI_PP_ALLOC_FLAGS_DEDICATED_INDEX = 1 << 0,
};
enum mlx5_ib_uapi_uar_alloc_type {
  MLX5_IB_UAPI_UAR_ALLOC_TYPE_BF = 0x0,
  MLX5_IB_UAPI_UAR_ALLOC_TYPE_NC = 0x1,
};
#endif