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
#ifndef _UAPI_XT_CGROUP_H
#define _UAPI_XT_CGROUP_H
#include <linux/types.h>
#include <linux/limits.h>
struct xt_cgroup_info_v0 {
  __u32 id;
  __u32 invert;
};
struct xt_cgroup_info_v1 {
  __u8 has_path;
  __u8 has_classid;
  __u8 invert_path;
  __u8 invert_classid;
  char path[PATH_MAX];
  __u32 classid;
  void * priv __attribute__((aligned(8)));
};
#define XT_CGROUP_PATH_MAX 512
struct xt_cgroup_info_v2 {
  __u8 has_path;
  __u8 has_classid;
  __u8 invert_path;
  __u8 invert_classid;
  union {
    char path[XT_CGROUP_PATH_MAX];
    __u32 classid;
  };
  void * priv __attribute__((aligned(8)));
};
#endif