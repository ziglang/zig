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
#ifndef _LINUX_UN_H
#define _LINUX_UN_H
#include <linux/socket.h>
#define UNIX_PATH_MAX 108
struct sockaddr_un {
  __kernel_sa_family_t sun_family;
  char sun_path[UNIX_PATH_MAX];
};
#define SIOCUNIXFILE (SIOCPROTOPRIVATE + 0)
#endif