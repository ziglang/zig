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
#ifndef _UAPILINUX_NBD_NETLINK_H
#define _UAPILINUX_NBD_NETLINK_H
#define NBD_GENL_FAMILY_NAME "nbd"
#define NBD_GENL_VERSION 0x1
#define NBD_GENL_MCAST_GROUP_NAME "nbd_mc_group"
enum {
  NBD_ATTR_UNSPEC,
  NBD_ATTR_INDEX,
  NBD_ATTR_SIZE_BYTES,
  NBD_ATTR_BLOCK_SIZE_BYTES,
  NBD_ATTR_TIMEOUT,
  NBD_ATTR_SERVER_FLAGS,
  NBD_ATTR_CLIENT_FLAGS,
  NBD_ATTR_SOCKETS,
  NBD_ATTR_DEAD_CONN_TIMEOUT,
  NBD_ATTR_DEVICE_LIST,
  __NBD_ATTR_MAX,
};
#define NBD_ATTR_MAX (__NBD_ATTR_MAX - 1)
enum {
  NBD_DEVICE_ITEM_UNSPEC,
  NBD_DEVICE_ITEM,
  __NBD_DEVICE_ITEM_MAX,
};
#define NBD_DEVICE_ITEM_MAX (__NBD_DEVICE_ITEM_MAX - 1)
enum {
  NBD_DEVICE_UNSPEC,
  NBD_DEVICE_INDEX,
  NBD_DEVICE_CONNECTED,
  __NBD_DEVICE_MAX,
};
#define NBD_DEVICE_ATTR_MAX (__NBD_DEVICE_MAX - 1)
enum {
  NBD_SOCK_ITEM_UNSPEC,
  NBD_SOCK_ITEM,
  __NBD_SOCK_ITEM_MAX,
};
#define NBD_SOCK_ITEM_MAX (__NBD_SOCK_ITEM_MAX - 1)
enum {
  NBD_SOCK_UNSPEC,
  NBD_SOCK_FD,
  __NBD_SOCK_MAX,
};
#define NBD_SOCK_MAX (__NBD_SOCK_MAX - 1)
enum {
  NBD_CMD_UNSPEC,
  NBD_CMD_CONNECT,
  NBD_CMD_DISCONNECT,
  NBD_CMD_RECONFIGURE,
  NBD_CMD_LINK_DEAD,
  NBD_CMD_STATUS,
  __NBD_CMD_MAX,
};
#define NBD_CMD_MAX (__NBD_CMD_MAX - 1)
#endif