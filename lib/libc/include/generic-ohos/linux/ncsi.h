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
#ifndef __UAPI_NCSI_NETLINK_H__
#define __UAPI_NCSI_NETLINK_H__
enum ncsi_nl_commands {
  NCSI_CMD_UNSPEC,
  NCSI_CMD_PKG_INFO,
  NCSI_CMD_SET_INTERFACE,
  NCSI_CMD_CLEAR_INTERFACE,
  NCSI_CMD_SEND_CMD,
  NCSI_CMD_SET_PACKAGE_MASK,
  NCSI_CMD_SET_CHANNEL_MASK,
  __NCSI_CMD_AFTER_LAST,
  NCSI_CMD_MAX = __NCSI_CMD_AFTER_LAST - 1
};
enum ncsi_nl_attrs {
  NCSI_ATTR_UNSPEC,
  NCSI_ATTR_IFINDEX,
  NCSI_ATTR_PACKAGE_LIST,
  NCSI_ATTR_PACKAGE_ID,
  NCSI_ATTR_CHANNEL_ID,
  NCSI_ATTR_DATA,
  NCSI_ATTR_MULTI_FLAG,
  NCSI_ATTR_PACKAGE_MASK,
  NCSI_ATTR_CHANNEL_MASK,
  __NCSI_ATTR_AFTER_LAST,
  NCSI_ATTR_MAX = __NCSI_ATTR_AFTER_LAST - 1
};
enum ncsi_nl_pkg_attrs {
  NCSI_PKG_ATTR_UNSPEC,
  NCSI_PKG_ATTR,
  NCSI_PKG_ATTR_ID,
  NCSI_PKG_ATTR_FORCED,
  NCSI_PKG_ATTR_CHANNEL_LIST,
  __NCSI_PKG_ATTR_AFTER_LAST,
  NCSI_PKG_ATTR_MAX = __NCSI_PKG_ATTR_AFTER_LAST - 1
};
enum ncsi_nl_channel_attrs {
  NCSI_CHANNEL_ATTR_UNSPEC,
  NCSI_CHANNEL_ATTR,
  NCSI_CHANNEL_ATTR_ID,
  NCSI_CHANNEL_ATTR_VERSION_MAJOR,
  NCSI_CHANNEL_ATTR_VERSION_MINOR,
  NCSI_CHANNEL_ATTR_VERSION_STR,
  NCSI_CHANNEL_ATTR_LINK_STATE,
  NCSI_CHANNEL_ATTR_ACTIVE,
  NCSI_CHANNEL_ATTR_FORCED,
  NCSI_CHANNEL_ATTR_VLAN_LIST,
  NCSI_CHANNEL_ATTR_VLAN_ID,
  __NCSI_CHANNEL_ATTR_AFTER_LAST,
  NCSI_CHANNEL_ATTR_MAX = __NCSI_CHANNEL_ATTR_AFTER_LAST - 1
};
#endif