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
#ifndef _LINUX_VIRTIO_INPUT_H
#define _LINUX_VIRTIO_INPUT_H
#include <linux/types.h>
enum virtio_input_config_select {
  VIRTIO_INPUT_CFG_UNSET = 0x00,
  VIRTIO_INPUT_CFG_ID_NAME = 0x01,
  VIRTIO_INPUT_CFG_ID_SERIAL = 0x02,
  VIRTIO_INPUT_CFG_ID_DEVIDS = 0x03,
  VIRTIO_INPUT_CFG_PROP_BITS = 0x10,
  VIRTIO_INPUT_CFG_EV_BITS = 0x11,
  VIRTIO_INPUT_CFG_ABS_INFO = 0x12,
};
struct virtio_input_absinfo {
  __le32 min;
  __le32 max;
  __le32 fuzz;
  __le32 flat;
  __le32 res;
};
struct virtio_input_devids {
  __le16 bustype;
  __le16 vendor;
  __le16 product;
  __le16 version;
};
struct virtio_input_config {
  __u8 select;
  __u8 subsel;
  __u8 size;
  __u8 reserved[5];
  union {
    char string[128];
    __u8 bitmap[128];
    struct virtio_input_absinfo abs;
    struct virtio_input_devids ids;
  } u;
};
struct virtio_input_event {
  __le16 type;
  __le16 code;
  __le32 value;
};
#endif