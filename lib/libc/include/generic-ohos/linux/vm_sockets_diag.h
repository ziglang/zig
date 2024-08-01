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
#ifndef _UAPI__VM_SOCKETS_DIAG_H__
#define _UAPI__VM_SOCKETS_DIAG_H__
#include <linux/types.h>
struct vsock_diag_req {
  __u8 sdiag_family;
  __u8 sdiag_protocol;
  __u16 pad;
  __u32 vdiag_states;
  __u32 vdiag_ino;
  __u32 vdiag_show;
  __u32 vdiag_cookie[2];
};
struct vsock_diag_msg {
  __u8 vdiag_family;
  __u8 vdiag_type;
  __u8 vdiag_state;
  __u8 vdiag_shutdown;
  __u32 vdiag_src_cid;
  __u32 vdiag_src_port;
  __u32 vdiag_dst_cid;
  __u32 vdiag_dst_port;
  __u32 vdiag_ino;
  __u32 vdiag_cookie[2];
};
#endif