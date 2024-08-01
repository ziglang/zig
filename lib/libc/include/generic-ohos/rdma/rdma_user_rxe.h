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
#ifndef RDMA_USER_RXE_H
#define RDMA_USER_RXE_H
#include <linux/types.h>
#include <linux/socket.h>
#include <linux/in.h>
#include <linux/in6.h>
enum {
  RXE_NETWORK_TYPE_IPV4 = 1,
  RXE_NETWORK_TYPE_IPV6 = 2,
};
union rxe_gid {
  __u8 raw[16];
  struct {
    __be64 subnet_prefix;
    __be64 interface_id;
  } global;
};
struct rxe_global_route {
  union rxe_gid dgid;
  __u32 flow_label;
  __u8 sgid_index;
  __u8 hop_limit;
  __u8 traffic_class;
};
struct rxe_av {
  __u8 port_num;
  __u8 network_type;
  __u8 dmac[6];
  struct rxe_global_route grh;
  union {
    struct sockaddr_in _sockaddr_in;
    struct sockaddr_in6 _sockaddr_in6;
  } sgid_addr, dgid_addr;
};
struct rxe_send_wr {
  __aligned_u64 wr_id;
  __u32 num_sge;
  __u32 opcode;
  __u32 send_flags;
  union {
    __be32 imm_data;
    __u32 invalidate_rkey;
  } ex;
  union {
    struct {
      __aligned_u64 remote_addr;
      __u32 rkey;
      __u32 reserved;
    } rdma;
    struct {
      __aligned_u64 remote_addr;
      __aligned_u64 compare_add;
      __aligned_u64 swap;
      __u32 rkey;
      __u32 reserved;
    } atomic;
    struct {
      __u32 remote_qpn;
      __u32 remote_qkey;
      __u16 pkey_index;
    } ud;
    struct {
      union {
        struct ib_mr * mr;
        __aligned_u64 reserved;
      };
      __u32 key;
      __u32 access;
    } reg;
  } wr;
};
struct rxe_sge {
  __aligned_u64 addr;
  __u32 length;
  __u32 lkey;
};
struct mminfo {
  __aligned_u64 offset;
  __u32 size;
  __u32 pad;
};
struct rxe_dma_info {
  __u32 length;
  __u32 resid;
  __u32 cur_sge;
  __u32 num_sge;
  __u32 sge_offset;
  __u32 reserved;
  union {
    __u8 inline_data[0];
    struct rxe_sge sge[0];
  };
};
struct rxe_send_wqe {
  struct rxe_send_wr wr;
  struct rxe_av av;
  __u32 status;
  __u32 state;
  __aligned_u64 iova;
  __u32 mask;
  __u32 first_psn;
  __u32 last_psn;
  __u32 ack_length;
  __u32 ssn;
  __u32 has_rd_atomic;
  struct rxe_dma_info dma;
};
struct rxe_recv_wqe {
  __aligned_u64 wr_id;
  __u32 num_sge;
  __u32 padding;
  struct rxe_dma_info dma;
};
struct rxe_create_cq_resp {
  struct mminfo mi;
};
struct rxe_resize_cq_resp {
  struct mminfo mi;
};
struct rxe_create_qp_resp {
  struct mminfo rq_mi;
  struct mminfo sq_mi;
};
struct rxe_create_srq_resp {
  struct mminfo mi;
  __u32 srq_num;
  __u32 reserved;
};
struct rxe_modify_srq_cmd {
  __aligned_u64 mmap_info_addr;
};
#endif