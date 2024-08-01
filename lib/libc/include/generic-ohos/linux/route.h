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
#ifndef _LINUX_ROUTE_H
#define _LINUX_ROUTE_H
#include <linux/if.h>
#include <linux/compiler.h>
struct rtentry {
  unsigned long rt_pad1;
  struct sockaddr rt_dst;
  struct sockaddr rt_gateway;
  struct sockaddr rt_genmask;
  unsigned short rt_flags;
  short rt_pad2;
  unsigned long rt_pad3;
  void * rt_pad4;
  short rt_metric;
  char __user * rt_dev;
  unsigned long rt_mtu;
#define rt_mss rt_mtu
  unsigned long rt_window;
  unsigned short rt_irtt;
};
#define RTF_UP 0x0001
#define RTF_GATEWAY 0x0002
#define RTF_HOST 0x0004
#define RTF_REINSTATE 0x0008
#define RTF_DYNAMIC 0x0010
#define RTF_MODIFIED 0x0020
#define RTF_MTU 0x0040
#define RTF_MSS RTF_MTU
#define RTF_WINDOW 0x0080
#define RTF_IRTT 0x0100
#define RTF_REJECT 0x0200
#endif