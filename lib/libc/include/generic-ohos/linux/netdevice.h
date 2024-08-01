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
#ifndef _UAPI_LINUX_NETDEVICE_H
#define _UAPI_LINUX_NETDEVICE_H
#include <linux/if.h>
#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <linux/if_link.h>
#define MAX_ADDR_LEN 32
#define INIT_NETDEV_GROUP 0
#define NET_NAME_UNKNOWN 0
#define NET_NAME_ENUM 1
#define NET_NAME_PREDICTABLE 2
#define NET_NAME_USER 3
#define NET_NAME_RENAMED 4
enum {
  IF_PORT_UNKNOWN = 0,
  IF_PORT_10BASE2,
  IF_PORT_10BASET,
  IF_PORT_AUI,
  IF_PORT_100BASET,
  IF_PORT_100BASETX,
  IF_PORT_100BASEFX
};
#define NET_ADDR_PERM 0
#define NET_ADDR_RANDOM 1
#define NET_ADDR_STOLEN 2
#define NET_ADDR_SET 3
#endif