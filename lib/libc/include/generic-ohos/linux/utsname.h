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
#ifndef _UAPI_LINUX_UTSNAME_H
#define _UAPI_LINUX_UTSNAME_H
#define __OLD_UTS_LEN 8
struct oldold_utsname {
  char sysname[9];
  char nodename[9];
  char release[9];
  char version[9];
  char machine[9];
};
#define __NEW_UTS_LEN 64
struct old_utsname {
  char sysname[65];
  char nodename[65];
  char release[65];
  char version[65];
  char machine[65];
};
struct new_utsname {
  char sysname[__NEW_UTS_LEN + 1];
  char nodename[__NEW_UTS_LEN + 1];
  char release[__NEW_UTS_LEN + 1];
  char version[__NEW_UTS_LEN + 1];
  char machine[__NEW_UTS_LEN + 1];
  char domainname[__NEW_UTS_LEN + 1];
};
#endif