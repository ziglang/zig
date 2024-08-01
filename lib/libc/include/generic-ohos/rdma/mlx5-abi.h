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
#ifndef MLX5_ABI_USER_H
#define MLX5_ABI_USER_H
#include <linux/types.h>
#include <linux/if_ether.h>
#include <rdma/ib_user_ioctl_verbs.h>
enum {
  MLX5_QP_FLAG_SIGNATURE = 1 << 0,
  MLX5_QP_FLAG_SCATTER_CQE = 1 << 1,
  MLX5_QP_FLAG_TUNNEL_OFFLOADS = 1 << 2,
  MLX5_QP_FLAG_BFREG_INDEX = 1 << 3,
  MLX5_QP_FLAG_TYPE_DCT = 1 << 4,
  MLX5_QP_FLAG_TYPE_DCI = 1 << 5,
  MLX5_QP_FLAG_TIR_ALLOW_SELF_LB_UC = 1 << 6,
  MLX5_QP_FLAG_TIR_ALLOW_SELF_LB_MC = 1 << 7,
  MLX5_QP_FLAG_ALLOW_SCATTER_CQE = 1 << 8,
  MLX5_QP_FLAG_PACKET_BASED_CREDIT_MODE = 1 << 9,
  MLX5_QP_FLAG_UAR_PAGE_INDEX = 1 << 10,
};
enum {
  MLX5_SRQ_FLAG_SIGNATURE = 1 << 0,
};
enum {
  MLX5_WQ_FLAG_SIGNATURE = 1 << 0,
};
#define MLX5_IB_UVERBS_ABI_VERSION 1
struct mlx5_ib_alloc_ucontext_req {
  __u32 total_num_bfregs;
  __u32 num_low_latency_bfregs;
};
enum mlx5_lib_caps {
  MLX5_LIB_CAP_4K_UAR = (__u64) 1 << 0,
  MLX5_LIB_CAP_DYN_UAR = (__u64) 1 << 1,
};
enum mlx5_ib_alloc_uctx_v2_flags {
  MLX5_IB_ALLOC_UCTX_DEVX = 1 << 0,
};
struct mlx5_ib_alloc_ucontext_req_v2 {
  __u32 total_num_bfregs;
  __u32 num_low_latency_bfregs;
  __u32 flags;
  __u32 comp_mask;
  __u8 max_cqe_version;
  __u8 reserved0;
  __u16 reserved1;
  __u32 reserved2;
  __aligned_u64 lib_caps;
};
enum mlx5_ib_alloc_ucontext_resp_mask {
  MLX5_IB_ALLOC_UCONTEXT_RESP_MASK_CORE_CLOCK_OFFSET = 1UL << 0,
  MLX5_IB_ALLOC_UCONTEXT_RESP_MASK_DUMP_FILL_MKEY = 1UL << 1,
  MLX5_IB_ALLOC_UCONTEXT_RESP_MASK_ECE = 1UL << 2,
};
enum mlx5_user_cmds_supp_uhw {
  MLX5_USER_CMDS_SUPP_UHW_QUERY_DEVICE = 1 << 0,
  MLX5_USER_CMDS_SUPP_UHW_CREATE_AH = 1 << 1,
};
enum mlx5_user_inline_mode {
  MLX5_USER_INLINE_MODE_NA,
  MLX5_USER_INLINE_MODE_NONE,
  MLX5_USER_INLINE_MODE_L2,
  MLX5_USER_INLINE_MODE_IP,
  MLX5_USER_INLINE_MODE_TCP_UDP,
};
enum {
  MLX5_USER_ALLOC_UCONTEXT_FLOW_ACTION_FLAGS_ESP_AES_GCM = 1 << 0,
  MLX5_USER_ALLOC_UCONTEXT_FLOW_ACTION_FLAGS_ESP_AES_GCM_REQ_METADATA = 1 << 1,
  MLX5_USER_ALLOC_UCONTEXT_FLOW_ACTION_FLAGS_ESP_AES_GCM_SPI_STEERING = 1 << 2,
  MLX5_USER_ALLOC_UCONTEXT_FLOW_ACTION_FLAGS_ESP_AES_GCM_FULL_OFFLOAD = 1 << 3,
  MLX5_USER_ALLOC_UCONTEXT_FLOW_ACTION_FLAGS_ESP_AES_GCM_TX_IV_IS_ESN = 1 << 4,
};
struct mlx5_ib_alloc_ucontext_resp {
  __u32 qp_tab_size;
  __u32 bf_reg_size;
  __u32 tot_bfregs;
  __u32 cache_line_size;
  __u16 max_sq_desc_sz;
  __u16 max_rq_desc_sz;
  __u32 max_send_wqebb;
  __u32 max_recv_wr;
  __u32 max_srq_recv_wr;
  __u16 num_ports;
  __u16 flow_action_flags;
  __u32 comp_mask;
  __u32 response_length;
  __u8 cqe_version;
  __u8 cmds_supp_uhw;
  __u8 eth_min_inline;
  __u8 clock_info_versions;
  __aligned_u64 hca_core_clock_offset;
  __u32 log_uar_size;
  __u32 num_uars_per_page;
  __u32 num_dyn_bfregs;
  __u32 dump_fill_mkey;
};
struct mlx5_ib_alloc_pd_resp {
  __u32 pdn;
};
struct mlx5_ib_tso_caps {
  __u32 max_tso;
  __u32 supported_qpts;
};
struct mlx5_ib_rss_caps {
  __aligned_u64 rx_hash_fields_mask;
  __u8 rx_hash_function;
  __u8 reserved[7];
};
enum mlx5_ib_cqe_comp_res_format {
  MLX5_IB_CQE_RES_FORMAT_HASH = 1 << 0,
  MLX5_IB_CQE_RES_FORMAT_CSUM = 1 << 1,
  MLX5_IB_CQE_RES_FORMAT_CSUM_STRIDX = 1 << 2,
};
struct mlx5_ib_cqe_comp_caps {
  __u32 max_num;
  __u32 supported_format;
};
enum mlx5_ib_packet_pacing_cap_flags {
  MLX5_IB_PP_SUPPORT_BURST = 1 << 0,
};
struct mlx5_packet_pacing_caps {
  __u32 qp_rate_limit_min;
  __u32 qp_rate_limit_max;
  __u32 supported_qpts;
  __u8 cap_flags;
  __u8 reserved[3];
};
enum mlx5_ib_mpw_caps {
  MPW_RESERVED = 1 << 0,
  MLX5_IB_ALLOW_MPW = 1 << 1,
  MLX5_IB_SUPPORT_EMPW = 1 << 2,
};
enum mlx5_ib_sw_parsing_offloads {
  MLX5_IB_SW_PARSING = 1 << 0,
  MLX5_IB_SW_PARSING_CSUM = 1 << 1,
  MLX5_IB_SW_PARSING_LSO = 1 << 2,
};
struct mlx5_ib_sw_parsing_caps {
  __u32 sw_parsing_offloads;
  __u32 supported_qpts;
};
struct mlx5_ib_striding_rq_caps {
  __u32 min_single_stride_log_num_of_bytes;
  __u32 max_single_stride_log_num_of_bytes;
  __u32 min_single_wqe_log_num_of_strides;
  __u32 max_single_wqe_log_num_of_strides;
  __u32 supported_qpts;
  __u32 reserved;
};
enum mlx5_ib_query_dev_resp_flags {
  MLX5_IB_QUERY_DEV_RESP_FLAGS_CQE_128B_COMP = 1 << 0,
  MLX5_IB_QUERY_DEV_RESP_FLAGS_CQE_128B_PAD = 1 << 1,
  MLX5_IB_QUERY_DEV_RESP_PACKET_BASED_CREDIT_MODE = 1 << 2,
  MLX5_IB_QUERY_DEV_RESP_FLAGS_SCAT2CQE_DCT = 1 << 3,
};
enum mlx5_ib_tunnel_offloads {
  MLX5_IB_TUNNELED_OFFLOADS_VXLAN = 1 << 0,
  MLX5_IB_TUNNELED_OFFLOADS_GRE = 1 << 1,
  MLX5_IB_TUNNELED_OFFLOADS_GENEVE = 1 << 2,
  MLX5_IB_TUNNELED_OFFLOADS_MPLS_GRE = 1 << 3,
  MLX5_IB_TUNNELED_OFFLOADS_MPLS_UDP = 1 << 4,
};
struct mlx5_ib_query_device_resp {
  __u32 comp_mask;
  __u32 response_length;
  struct mlx5_ib_tso_caps tso_caps;
  struct mlx5_ib_rss_caps rss_caps;
  struct mlx5_ib_cqe_comp_caps cqe_comp_caps;
  struct mlx5_packet_pacing_caps packet_pacing_caps;
  __u32 mlx5_ib_support_multi_pkt_send_wqes;
  __u32 flags;
  struct mlx5_ib_sw_parsing_caps sw_parsing_caps;
  struct mlx5_ib_striding_rq_caps striding_rq_caps;
  __u32 tunnel_offloads_caps;
  __u32 reserved;
};
enum mlx5_ib_create_cq_flags {
  MLX5_IB_CREATE_CQ_FLAGS_CQE_128B_PAD = 1 << 0,
  MLX5_IB_CREATE_CQ_FLAGS_UAR_PAGE_INDEX = 1 << 1,
};
struct mlx5_ib_create_cq {
  __aligned_u64 buf_addr;
  __aligned_u64 db_addr;
  __u32 cqe_size;
  __u8 cqe_comp_en;
  __u8 cqe_comp_res_format;
  __u16 flags;
  __u16 uar_page_index;
  __u16 reserved0;
  __u32 reserved1;
};
struct mlx5_ib_create_cq_resp {
  __u32 cqn;
  __u32 reserved;
};
struct mlx5_ib_resize_cq {
  __aligned_u64 buf_addr;
  __u16 cqe_size;
  __u16 reserved0;
  __u32 reserved1;
};
struct mlx5_ib_create_srq {
  __aligned_u64 buf_addr;
  __aligned_u64 db_addr;
  __u32 flags;
  __u32 reserved0;
  __u32 uidx;
  __u32 reserved1;
};
struct mlx5_ib_create_srq_resp {
  __u32 srqn;
  __u32 reserved;
};
struct mlx5_ib_create_qp {
  __aligned_u64 buf_addr;
  __aligned_u64 db_addr;
  __u32 sq_wqe_count;
  __u32 rq_wqe_count;
  __u32 rq_wqe_shift;
  __u32 flags;
  __u32 uidx;
  __u32 bfreg_index;
  union {
    __aligned_u64 sq_buf_addr;
    __aligned_u64 access_key;
  };
  __u32 ece_options;
  __u32 reserved;
};
enum mlx5_rx_hash_function_flags {
  MLX5_RX_HASH_FUNC_TOEPLITZ = 1 << 0,
};
enum mlx5_rx_hash_fields {
  MLX5_RX_HASH_SRC_IPV4 = 1 << 0,
  MLX5_RX_HASH_DST_IPV4 = 1 << 1,
  MLX5_RX_HASH_SRC_IPV6 = 1 << 2,
  MLX5_RX_HASH_DST_IPV6 = 1 << 3,
  MLX5_RX_HASH_SRC_PORT_TCP = 1 << 4,
  MLX5_RX_HASH_DST_PORT_TCP = 1 << 5,
  MLX5_RX_HASH_SRC_PORT_UDP = 1 << 6,
  MLX5_RX_HASH_DST_PORT_UDP = 1 << 7,
  MLX5_RX_HASH_IPSEC_SPI = 1 << 8,
  MLX5_RX_HASH_INNER = (1UL << 31),
};
struct mlx5_ib_create_qp_rss {
  __aligned_u64 rx_hash_fields_mask;
  __u8 rx_hash_function;
  __u8 rx_key_len;
  __u8 reserved[6];
  __u8 rx_hash_key[128];
  __u32 comp_mask;
  __u32 flags;
};
enum mlx5_ib_create_qp_resp_mask {
  MLX5_IB_CREATE_QP_RESP_MASK_TIRN = 1UL << 0,
  MLX5_IB_CREATE_QP_RESP_MASK_TISN = 1UL << 1,
  MLX5_IB_CREATE_QP_RESP_MASK_RQN = 1UL << 2,
  MLX5_IB_CREATE_QP_RESP_MASK_SQN = 1UL << 3,
  MLX5_IB_CREATE_QP_RESP_MASK_TIR_ICM_ADDR = 1UL << 4,
};
struct mlx5_ib_create_qp_resp {
  __u32 bfreg_index;
  __u32 ece_options;
  __u32 comp_mask;
  __u32 tirn;
  __u32 tisn;
  __u32 rqn;
  __u32 sqn;
  __u32 reserved1;
  __u64 tir_icm_addr;
};
struct mlx5_ib_alloc_mw {
  __u32 comp_mask;
  __u8 num_klms;
  __u8 reserved1;
  __u16 reserved2;
};
enum mlx5_ib_create_wq_mask {
  MLX5_IB_CREATE_WQ_STRIDING_RQ = (1 << 0),
};
struct mlx5_ib_create_wq {
  __aligned_u64 buf_addr;
  __aligned_u64 db_addr;
  __u32 rq_wqe_count;
  __u32 rq_wqe_shift;
  __u32 user_index;
  __u32 flags;
  __u32 comp_mask;
  __u32 single_stride_log_num_of_bytes;
  __u32 single_wqe_log_num_of_strides;
  __u32 two_byte_shift_en;
};
struct mlx5_ib_create_ah_resp {
  __u32 response_length;
  __u8 dmac[ETH_ALEN];
  __u8 reserved[6];
};
struct mlx5_ib_burst_info {
  __u32 max_burst_sz;
  __u16 typical_pkt_sz;
  __u16 reserved;
};
struct mlx5_ib_modify_qp {
  __u32 comp_mask;
  struct mlx5_ib_burst_info burst_info;
  __u32 ece_options;
};
struct mlx5_ib_modify_qp_resp {
  __u32 response_length;
  __u32 dctn;
  __u32 ece_options;
  __u32 reserved;
};
struct mlx5_ib_create_wq_resp {
  __u32 response_length;
  __u32 reserved;
};
struct mlx5_ib_create_rwq_ind_tbl_resp {
  __u32 response_length;
  __u32 reserved;
};
struct mlx5_ib_modify_wq {
  __u32 comp_mask;
  __u32 reserved;
};
struct mlx5_ib_clock_info {
  __u32 sign;
  __u32 resv;
  __aligned_u64 nsec;
  __aligned_u64 cycles;
  __aligned_u64 frac;
  __u32 mult;
  __u32 shift;
  __aligned_u64 mask;
  __aligned_u64 overflow_period;
};
enum mlx5_ib_mmap_cmd {
  MLX5_IB_MMAP_REGULAR_PAGE = 0,
  MLX5_IB_MMAP_GET_CONTIGUOUS_PAGES = 1,
  MLX5_IB_MMAP_WC_PAGE = 2,
  MLX5_IB_MMAP_NC_PAGE = 3,
  MLX5_IB_MMAP_CORE_CLOCK = 5,
  MLX5_IB_MMAP_ALLOC_WC = 6,
  MLX5_IB_MMAP_CLOCK_INFO = 7,
  MLX5_IB_MMAP_DEVICE_MEM = 8,
};
enum {
  MLX5_IB_CLOCK_INFO_KERNEL_UPDATING = 1,
};
enum {
  MLX5_IB_CLOCK_INFO_V1 = 0,
};
struct mlx5_ib_flow_counters_desc {
  __u32 description;
  __u32 index;
};
struct mlx5_ib_flow_counters_data {
  RDMA_UAPI_PTR(struct mlx5_ib_flow_counters_desc *, counters_data);
  __u32 ncounters;
  __u32 reserved;
};
struct mlx5_ib_create_flow {
  __u32 ncounters_data;
  __u32 reserved;
  struct mlx5_ib_flow_counters_data data[];
};
#endif