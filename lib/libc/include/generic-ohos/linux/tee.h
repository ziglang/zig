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
#ifndef __TEE_H
#define __TEE_H
#include <linux/ioctl.h>
#include <linux/types.h>
#define TEE_IOC_MAGIC 0xa4
#define TEE_IOC_BASE 0
#define TEE_IOCTL_SHM_MAPPED 0x1
#define TEE_IOCTL_SHM_DMA_BUF 0x2
#define TEE_MAX_ARG_SIZE 1024
#define TEE_GEN_CAP_GP (1 << 0)
#define TEE_GEN_CAP_PRIVILEGED (1 << 1)
#define TEE_GEN_CAP_REG_MEM (1 << 2)
#define TEE_GEN_CAP_MEMREF_NULL (1 << 3)
#define TEE_MEMREF_NULL (__u64) (- 1)
#define TEE_IMPL_ID_OPTEE 1
#define TEE_IMPL_ID_AMDTEE 2
#define TEE_OPTEE_CAP_TZ (1 << 0)
struct tee_ioctl_version_data {
  __u32 impl_id;
  __u32 impl_caps;
  __u32 gen_caps;
};
#define TEE_IOC_VERSION _IOR(TEE_IOC_MAGIC, TEE_IOC_BASE + 0, struct tee_ioctl_version_data)
struct tee_ioctl_shm_alloc_data {
  __u64 size;
  __u32 flags;
  __s32 id;
};
#define TEE_IOC_SHM_ALLOC _IOWR(TEE_IOC_MAGIC, TEE_IOC_BASE + 1, struct tee_ioctl_shm_alloc_data)
struct tee_ioctl_buf_data {
  __u64 buf_ptr;
  __u64 buf_len;
};
#define TEE_IOCTL_PARAM_ATTR_TYPE_NONE 0
#define TEE_IOCTL_PARAM_ATTR_TYPE_VALUE_INPUT 1
#define TEE_IOCTL_PARAM_ATTR_TYPE_VALUE_OUTPUT 2
#define TEE_IOCTL_PARAM_ATTR_TYPE_VALUE_INOUT 3
#define TEE_IOCTL_PARAM_ATTR_TYPE_MEMREF_INPUT 5
#define TEE_IOCTL_PARAM_ATTR_TYPE_MEMREF_OUTPUT 6
#define TEE_IOCTL_PARAM_ATTR_TYPE_MEMREF_INOUT 7
#define TEE_IOCTL_PARAM_ATTR_TYPE_MASK 0xff
#define TEE_IOCTL_PARAM_ATTR_META 0x100
#define TEE_IOCTL_PARAM_ATTR_MASK (TEE_IOCTL_PARAM_ATTR_TYPE_MASK | TEE_IOCTL_PARAM_ATTR_META)
#define TEE_IOCTL_LOGIN_PUBLIC 0
#define TEE_IOCTL_LOGIN_USER 1
#define TEE_IOCTL_LOGIN_GROUP 2
#define TEE_IOCTL_LOGIN_APPLICATION 4
#define TEE_IOCTL_LOGIN_USER_APPLICATION 5
#define TEE_IOCTL_LOGIN_GROUP_APPLICATION 6
#define TEE_IOCTL_LOGIN_REE_KERNEL_MIN 0x80000000
#define TEE_IOCTL_LOGIN_REE_KERNEL_MAX 0xBFFFFFFF
#define TEE_IOCTL_LOGIN_REE_KERNEL 0x80000000
struct tee_ioctl_param {
  __u64 attr;
  __u64 a;
  __u64 b;
  __u64 c;
};
#define TEE_IOCTL_UUID_LEN 16
struct tee_ioctl_open_session_arg {
  __u8 uuid[TEE_IOCTL_UUID_LEN];
  __u8 clnt_uuid[TEE_IOCTL_UUID_LEN];
  __u32 clnt_login;
  __u32 cancel_id;
  __u32 session;
  __u32 ret;
  __u32 ret_origin;
  __u32 num_params;
  struct tee_ioctl_param params[];
};
#define TEE_IOC_OPEN_SESSION _IOR(TEE_IOC_MAGIC, TEE_IOC_BASE + 2, struct tee_ioctl_buf_data)
struct tee_ioctl_invoke_arg {
  __u32 func;
  __u32 session;
  __u32 cancel_id;
  __u32 ret;
  __u32 ret_origin;
  __u32 num_params;
  struct tee_ioctl_param params[];
};
#define TEE_IOC_INVOKE _IOR(TEE_IOC_MAGIC, TEE_IOC_BASE + 3, struct tee_ioctl_buf_data)
struct tee_ioctl_cancel_arg {
  __u32 cancel_id;
  __u32 session;
};
#define TEE_IOC_CANCEL _IOR(TEE_IOC_MAGIC, TEE_IOC_BASE + 4, struct tee_ioctl_cancel_arg)
struct tee_ioctl_close_session_arg {
  __u32 session;
};
#define TEE_IOC_CLOSE_SESSION _IOR(TEE_IOC_MAGIC, TEE_IOC_BASE + 5, struct tee_ioctl_close_session_arg)
struct tee_iocl_supp_recv_arg {
  __u32 func;
  __u32 num_params;
  struct tee_ioctl_param params[];
};
#define TEE_IOC_SUPPL_RECV _IOR(TEE_IOC_MAGIC, TEE_IOC_BASE + 6, struct tee_ioctl_buf_data)
struct tee_iocl_supp_send_arg {
  __u32 ret;
  __u32 num_params;
  struct tee_ioctl_param params[];
};
#define TEE_IOC_SUPPL_SEND _IOR(TEE_IOC_MAGIC, TEE_IOC_BASE + 7, struct tee_ioctl_buf_data)
struct tee_ioctl_shm_register_data {
  __u64 addr;
  __u64 length;
  __u32 flags;
  __s32 id;
};
#define TEE_IOC_SHM_REGISTER _IOWR(TEE_IOC_MAGIC, TEE_IOC_BASE + 9, struct tee_ioctl_shm_register_data)
#endif