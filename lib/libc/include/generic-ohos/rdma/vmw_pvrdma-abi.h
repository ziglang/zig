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
#ifndef __VMW_PVRDMA_ABI_H__
#define __VMW_PVRDMA_ABI_H__
#include <linux/types.h>
#define PVRDMA_UVERBS_ABI_VERSION 3
#define PVRDMA_UAR_HANDLE_MASK 0x00FFFFFF
#define PVRDMA_UAR_QP_OFFSET 0
#define PVRDMA_UAR_QP_SEND (1 << 30)
#define PVRDMA_UAR_QP_RECV (1 << 31)
#define PVRDMA_UAR_CQ_OFFSET 4
#define PVRDMA_UAR_CQ_ARM_SOL (1 << 29)
#define PVRDMA_UAR_CQ_ARM (1 << 30)
#define PVRDMA_UAR_CQ_POLL (1 << 31)
#define PVRDMA_UAR_SRQ_OFFSET 8
#define PVRDMA_UAR_SRQ_RECV (1 << 30)
enum pvrdma_wr_opcode {
  PVRDMA_WR_RDMA_WRITE,
  PVRDMA_WR_RDMA_WRITE_WITH_IMM,
  PVRDMA_WR_SEND,
  PVRDMA_WR_SEND_WITH_IMM,
  PVRDMA_WR_RDMA_READ,
  PVRDMA_WR_ATOMIC_CMP_AND_SWP,
  PVRDMA_WR_ATOMIC_FETCH_AND_ADD,
  PVRDMA_WR_LSO,
  PVRDMA_WR_SEND_WITH_INV,
  PVRDMA_WR_RDMA_READ_WITH_INV,
  PVRDMA_WR_LOCAL_INV,
  PVRDMA_WR_FAST_REG_MR,
  PVRDMA_WR_MASKED_ATOMIC_CMP_AND_SWP,
  PVRDMA_WR_MASKED_ATOMIC_FETCH_AND_ADD,
  PVRDMA_WR_BIND_MW,
  PVRDMA_WR_REG_SIG_MR,
  PVRDMA_WR_ERROR,
};
enum pvrdma_wc_status {
  PVRDMA_WC_SUCCESS,
  PVRDMA_WC_LOC_LEN_ERR,
  PVRDMA_WC_LOC_QP_OP_ERR,
  PVRDMA_WC_LOC_EEC_OP_ERR,
  PVRDMA_WC_LOC_PROT_ERR,
  PVRDMA_WC_WR_FLUSH_ERR,
  PVRDMA_WC_MW_BIND_ERR,
  PVRDMA_WC_BAD_RESP_ERR,
  PVRDMA_WC_LOC_ACCESS_ERR,
  PVRDMA_WC_REM_INV_REQ_ERR,
  PVRDMA_WC_REM_ACCESS_ERR,
  PVRDMA_WC_REM_OP_ERR,
  PVRDMA_WC_RETRY_EXC_ERR,
  PVRDMA_WC_RNR_RETRY_EXC_ERR,
  PVRDMA_WC_LOC_RDD_VIOL_ERR,
  PVRDMA_WC_REM_INV_RD_REQ_ERR,
  PVRDMA_WC_REM_ABORT_ERR,
  PVRDMA_WC_INV_EECN_ERR,
  PVRDMA_WC_INV_EEC_STATE_ERR,
  PVRDMA_WC_FATAL_ERR,
  PVRDMA_WC_RESP_TIMEOUT_ERR,
  PVRDMA_WC_GENERAL_ERR,
};
enum pvrdma_wc_opcode {
  PVRDMA_WC_SEND,
  PVRDMA_WC_RDMA_WRITE,
  PVRDMA_WC_RDMA_READ,
  PVRDMA_WC_COMP_SWAP,
  PVRDMA_WC_FETCH_ADD,
  PVRDMA_WC_BIND_MW,
  PVRDMA_WC_LSO,
  PVRDMA_WC_LOCAL_INV,
  PVRDMA_WC_FAST_REG_MR,
  PVRDMA_WC_MASKED_COMP_SWAP,
  PVRDMA_WC_MASKED_FETCH_ADD,
  PVRDMA_WC_RECV = 1 << 7,
  PVRDMA_WC_RECV_RDMA_WITH_IMM,
};
enum pvrdma_wc_flags {
  PVRDMA_WC_GRH = 1 << 0,
  PVRDMA_WC_WITH_IMM = 1 << 1,
  PVRDMA_WC_WITH_INVALIDATE = 1 << 2,
  PVRDMA_WC_IP_CSUM_OK = 1 << 3,
  PVRDMA_WC_WITH_SMAC = 1 << 4,
  PVRDMA_WC_WITH_VLAN = 1 << 5,
  PVRDMA_WC_WITH_NETWORK_HDR_TYPE = 1 << 6,
  PVRDMA_WC_FLAGS_MAX = PVRDMA_WC_WITH_NETWORK_HDR_TYPE,
};
struct pvrdma_alloc_ucontext_resp {
  __u32 qp_tab_size;
  __u32 reserved;
};
struct pvrdma_alloc_pd_resp {
  __u32 pdn;
  __u32 reserved;
};
struct pvrdma_create_cq {
  __aligned_u64 buf_addr;
  __u32 buf_size;
  __u32 reserved;
};
struct pvrdma_create_cq_resp {
  __u32 cqn;
  __u32 reserved;
};
struct pvrdma_resize_cq {
  __aligned_u64 buf_addr;
  __u32 buf_size;
  __u32 reserved;
};
struct pvrdma_create_srq {
  __aligned_u64 buf_addr;
  __u32 buf_size;
  __u32 reserved;
};
struct pvrdma_create_srq_resp {
  __u32 srqn;
  __u32 reserved;
};
struct pvrdma_create_qp {
  __aligned_u64 rbuf_addr;
  __aligned_u64 sbuf_addr;
  __u32 rbuf_size;
  __u32 sbuf_size;
  __aligned_u64 qp_addr;
};
struct pvrdma_create_qp_resp {
  __u32 qpn;
  __u32 qp_handle;
};
struct pvrdma_ex_cmp_swap {
  __aligned_u64 swap_val;
  __aligned_u64 compare_val;
  __aligned_u64 swap_mask;
  __aligned_u64 compare_mask;
};
struct pvrdma_ex_fetch_add {
  __aligned_u64 add_val;
  __aligned_u64 field_boundary;
};
struct pvrdma_av {
  __u32 port_pd;
  __u32 sl_tclass_flowlabel;
  __u8 dgid[16];
  __u8 src_path_bits;
  __u8 gid_index;
  __u8 stat_rate;
  __u8 hop_limit;
  __u8 dmac[6];
  __u8 reserved[6];
};
struct pvrdma_sge {
  __aligned_u64 addr;
  __u32 length;
  __u32 lkey;
};
struct pvrdma_rq_wqe_hdr {
  __aligned_u64 wr_id;
  __u32 num_sge;
  __u32 total_len;
};
struct pvrdma_sq_wqe_hdr {
  __aligned_u64 wr_id;
  __u32 num_sge;
  __u32 total_len;
  __u32 opcode;
  __u32 send_flags;
  union {
    __be32 imm_data;
    __u32 invalidate_rkey;
  } ex;
  __u32 reserved;
  union {
    struct {
      __aligned_u64 remote_addr;
      __u32 rkey;
      __u8 reserved[4];
    } rdma;
    struct {
      __aligned_u64 remote_addr;
      __aligned_u64 compare_add;
      __aligned_u64 swap;
      __u32 rkey;
      __u32 reserved;
    } atomic;
    struct {
      __aligned_u64 remote_addr;
      __u32 log_arg_sz;
      __u32 rkey;
      union {
        struct pvrdma_ex_cmp_swap cmp_swap;
        struct pvrdma_ex_fetch_add fetch_add;
      } wr_data;
    } masked_atomics;
    struct {
      __aligned_u64 iova_start;
      __aligned_u64 pl_pdir_dma;
      __u32 page_shift;
      __u32 page_list_len;
      __u32 length;
      __u32 access_flags;
      __u32 rkey;
      __u32 reserved;
    } fast_reg;
    struct {
      __u32 remote_qpn;
      __u32 remote_qkey;
      struct pvrdma_av av;
    } ud;
  } wr;
};
struct pvrdma_cqe {
  __aligned_u64 wr_id;
  __aligned_u64 qp;
  __u32 opcode;
  __u32 status;
  __u32 byte_len;
  __be32 imm_data;
  __u32 src_qp;
  __u32 wc_flags;
  __u32 vendor_err;
  __u16 pkey_index;
  __u16 slid;
  __u8 sl;
  __u8 dlid_path_bits;
  __u8 port_num;
  __u8 smac[6];
  __u8 network_hdr_type;
  __u8 reserved2[6];
};
#endif