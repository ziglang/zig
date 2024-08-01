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
#ifndef _LINUX_MEI_H
#define _LINUX_MEI_H
#include <linux/uuid.h>
#define IOCTL_MEI_CONNECT_CLIENT _IOWR('H', 0x01, struct mei_connect_client_data)
struct mei_client {
  __u32 max_msg_length;
  __u8 protocol_version;
  __u8 reserved[3];
};
struct mei_connect_client_data {
  union {
    uuid_le in_client_uuid;
    struct mei_client out_client_properties;
  };
};
#define IOCTL_MEI_NOTIFY_SET _IOW('H', 0x02, __u32)
#define IOCTL_MEI_NOTIFY_GET _IOR('H', 0x03, __u32)
struct mei_connect_client_vtag {
  uuid_le in_client_uuid;
  __u8 vtag;
  __u8 reserved[3];
};
struct mei_connect_client_data_vtag {
  union {
    struct mei_connect_client_vtag connect;
    struct mei_client out_client_properties;
  };
};
#define IOCTL_MEI_CONNECT_CLIENT_VTAG _IOWR('H', 0x04, struct mei_connect_client_data_vtag)
#endif