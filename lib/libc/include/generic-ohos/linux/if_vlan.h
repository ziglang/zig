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
#ifndef _UAPI_LINUX_IF_VLAN_H_
#define _UAPI_LINUX_IF_VLAN_H_
enum vlan_ioctl_cmds {
  ADD_VLAN_CMD,
  DEL_VLAN_CMD,
  SET_VLAN_INGRESS_PRIORITY_CMD,
  SET_VLAN_EGRESS_PRIORITY_CMD,
  GET_VLAN_INGRESS_PRIORITY_CMD,
  GET_VLAN_EGRESS_PRIORITY_CMD,
  SET_VLAN_NAME_TYPE_CMD,
  SET_VLAN_FLAG_CMD,
  GET_VLAN_REALDEV_NAME_CMD,
  GET_VLAN_VID_CMD
};
enum vlan_flags {
  VLAN_FLAG_REORDER_HDR = 0x1,
  VLAN_FLAG_GVRP = 0x2,
  VLAN_FLAG_LOOSE_BINDING = 0x4,
  VLAN_FLAG_MVRP = 0x8,
  VLAN_FLAG_BRIDGE_BINDING = 0x10,
};
enum vlan_name_types {
  VLAN_NAME_TYPE_PLUS_VID,
  VLAN_NAME_TYPE_RAW_PLUS_VID,
  VLAN_NAME_TYPE_PLUS_VID_NO_PAD,
  VLAN_NAME_TYPE_RAW_PLUS_VID_NO_PAD,
  VLAN_NAME_TYPE_HIGHEST
};
struct vlan_ioctl_args {
  int cmd;
  char device1[24];
  union {
    char device2[24];
    int VID;
    unsigned int skb_priority;
    unsigned int name_type;
    unsigned int bind_type;
    unsigned int flag;
  } u;
  short vlan_qos;
};
#endif