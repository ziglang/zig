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
#ifndef _UAPI_VSOCKMON_H
#define _UAPI_VSOCKMON_H
#include <linux/virtio_vsock.h>
struct af_vsockmon_hdr {
  __le64 src_cid;
  __le64 dst_cid;
  __le32 src_port;
  __le32 dst_port;
  __le16 op;
  __le16 transport;
  __le16 len;
  __u8 reserved[2];
};
enum af_vsockmon_op {
  AF_VSOCK_OP_UNKNOWN = 0,
  AF_VSOCK_OP_CONNECT = 1,
  AF_VSOCK_OP_DISCONNECT = 2,
  AF_VSOCK_OP_CONTROL = 3,
  AF_VSOCK_OP_PAYLOAD = 4,
};
enum af_vsockmon_transport {
  AF_VSOCK_TRANSPORT_UNKNOWN = 0,
  AF_VSOCK_TRANSPORT_NO_INFO = 1,
  AF_VSOCK_TRANSPORT_VIRTIO = 2,
};
#endif