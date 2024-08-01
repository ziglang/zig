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
#ifndef __UAPI_IFE_H
#define __UAPI_IFE_H
#define IFE_METAHDRLEN 2
enum {
  IFE_META_SKBMARK = 1,
  IFE_META_HASHID,
  IFE_META_PRIO,
  IFE_META_QMAP,
  IFE_META_TCINDEX,
  __IFE_META_MAX
};
#define IFE_META_MAX (__IFE_META_MAX - 1)
#endif