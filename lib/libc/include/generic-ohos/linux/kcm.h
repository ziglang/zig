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
#ifndef KCM_KERNEL_H
#define KCM_KERNEL_H
struct kcm_attach {
  int fd;
  int bpf_fd;
};
struct kcm_unattach {
  int fd;
};
struct kcm_clone {
  int fd;
};
#define SIOCKCMATTACH (SIOCPROTOPRIVATE + 0)
#define SIOCKCMUNATTACH (SIOCPROTOPRIVATE + 1)
#define SIOCKCMCLONE (SIOCPROTOPRIVATE + 2)
#define KCMPROTO_CONNECTED 0
#define KCM_RECV_DISABLE 1
#endif