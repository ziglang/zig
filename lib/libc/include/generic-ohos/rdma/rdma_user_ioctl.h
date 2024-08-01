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
#ifndef RDMA_USER_IOCTL_H
#define RDMA_USER_IOCTL_H
#include <rdma/ib_user_mad.h>
#include <rdma/hfi/hfi1_ioctl.h>
#include <rdma/rdma_user_ioctl_cmds.h>
#define IB_IOCTL_MAGIC RDMA_IOCTL_MAGIC
#define IB_USER_MAD_REGISTER_AGENT _IOWR(RDMA_IOCTL_MAGIC, 0x01, struct ib_user_mad_reg_req)
#define IB_USER_MAD_UNREGISTER_AGENT _IOW(RDMA_IOCTL_MAGIC, 0x02, __u32)
#define IB_USER_MAD_ENABLE_PKEY _IO(RDMA_IOCTL_MAGIC, 0x03)
#define IB_USER_MAD_REGISTER_AGENT2 _IOWR(RDMA_IOCTL_MAGIC, 0x04, struct ib_user_mad_reg_req2)
#define HFI1_IOCTL_ASSIGN_CTXT _IOWR(RDMA_IOCTL_MAGIC, 0xE1, struct hfi1_user_info)
#define HFI1_IOCTL_CTXT_INFO _IOW(RDMA_IOCTL_MAGIC, 0xE2, struct hfi1_ctxt_info)
#define HFI1_IOCTL_USER_INFO _IOW(RDMA_IOCTL_MAGIC, 0xE3, struct hfi1_base_info)
#define HFI1_IOCTL_TID_UPDATE _IOWR(RDMA_IOCTL_MAGIC, 0xE4, struct hfi1_tid_info)
#define HFI1_IOCTL_TID_FREE _IOWR(RDMA_IOCTL_MAGIC, 0xE5, struct hfi1_tid_info)
#define HFI1_IOCTL_CREDIT_UPD _IO(RDMA_IOCTL_MAGIC, 0xE6)
#define HFI1_IOCTL_RECV_CTRL _IOW(RDMA_IOCTL_MAGIC, 0xE8, int)
#define HFI1_IOCTL_POLL_TYPE _IOW(RDMA_IOCTL_MAGIC, 0xE9, int)
#define HFI1_IOCTL_ACK_EVENT _IOW(RDMA_IOCTL_MAGIC, 0xEA, unsigned long)
#define HFI1_IOCTL_SET_PKEY _IOW(RDMA_IOCTL_MAGIC, 0xEB, __u16)
#define HFI1_IOCTL_CTXT_RESET _IO(RDMA_IOCTL_MAGIC, 0xEC)
#define HFI1_IOCTL_TID_INVAL_READ _IOWR(RDMA_IOCTL_MAGIC, 0xED, struct hfi1_tid_info)
#define HFI1_IOCTL_GET_VERS _IOR(RDMA_IOCTL_MAGIC, 0xEE, int)
#endif