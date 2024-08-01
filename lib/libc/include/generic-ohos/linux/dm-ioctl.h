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
#ifndef _LINUX_DM_IOCTL_V4_H
#define _LINUX_DM_IOCTL_V4_H
#include <linux/types.h>
#define DM_DIR "mapper"
#define DM_CONTROL_NODE "control"
#define DM_MAX_TYPE_NAME 16
#define DM_NAME_LEN 128
#define DM_UUID_LEN 129
struct dm_ioctl {
  __u32 version[3];
  __u32 data_size;
  __u32 data_start;
  __u32 target_count;
  __s32 open_count;
  __u32 flags;
  __u32 event_nr;
  __u32 padding;
  __u64 dev;
  char name[DM_NAME_LEN];
  char uuid[DM_UUID_LEN];
  char data[7];
};
struct dm_target_spec {
  __u64 sector_start;
  __u64 length;
  __s32 status;
  __u32 next;
  char target_type[DM_MAX_TYPE_NAME];
};
struct dm_target_deps {
  __u32 count;
  __u32 padding;
  __u64 dev[0];
};
struct dm_name_list {
  __u64 dev;
  __u32 next;
  char name[0];
};
struct dm_target_versions {
  __u32 next;
  __u32 version[3];
  char name[0];
};
struct dm_target_msg {
  __u64 sector;
  char message[0];
};
enum {
  DM_VERSION_CMD = 0,
  DM_REMOVE_ALL_CMD,
  DM_LIST_DEVICES_CMD,
  DM_DEV_CREATE_CMD,
  DM_DEV_REMOVE_CMD,
  DM_DEV_RENAME_CMD,
  DM_DEV_SUSPEND_CMD,
  DM_DEV_STATUS_CMD,
  DM_DEV_WAIT_CMD,
  DM_TABLE_LOAD_CMD,
  DM_TABLE_CLEAR_CMD,
  DM_TABLE_DEPS_CMD,
  DM_TABLE_STATUS_CMD,
  DM_LIST_VERSIONS_CMD,
  DM_TARGET_MSG_CMD,
  DM_DEV_SET_GEOMETRY_CMD,
  DM_DEV_ARM_POLL_CMD,
  DM_GET_TARGET_VERSION_CMD,
};
#define DM_IOCTL 0xfd
#define DM_VERSION _IOWR(DM_IOCTL, DM_VERSION_CMD, struct dm_ioctl)
#define DM_REMOVE_ALL _IOWR(DM_IOCTL, DM_REMOVE_ALL_CMD, struct dm_ioctl)
#define DM_LIST_DEVICES _IOWR(DM_IOCTL, DM_LIST_DEVICES_CMD, struct dm_ioctl)
#define DM_DEV_CREATE _IOWR(DM_IOCTL, DM_DEV_CREATE_CMD, struct dm_ioctl)
#define DM_DEV_REMOVE _IOWR(DM_IOCTL, DM_DEV_REMOVE_CMD, struct dm_ioctl)
#define DM_DEV_RENAME _IOWR(DM_IOCTL, DM_DEV_RENAME_CMD, struct dm_ioctl)
#define DM_DEV_SUSPEND _IOWR(DM_IOCTL, DM_DEV_SUSPEND_CMD, struct dm_ioctl)
#define DM_DEV_STATUS _IOWR(DM_IOCTL, DM_DEV_STATUS_CMD, struct dm_ioctl)
#define DM_DEV_WAIT _IOWR(DM_IOCTL, DM_DEV_WAIT_CMD, struct dm_ioctl)
#define DM_DEV_ARM_POLL _IOWR(DM_IOCTL, DM_DEV_ARM_POLL_CMD, struct dm_ioctl)
#define DM_TABLE_LOAD _IOWR(DM_IOCTL, DM_TABLE_LOAD_CMD, struct dm_ioctl)
#define DM_TABLE_CLEAR _IOWR(DM_IOCTL, DM_TABLE_CLEAR_CMD, struct dm_ioctl)
#define DM_TABLE_DEPS _IOWR(DM_IOCTL, DM_TABLE_DEPS_CMD, struct dm_ioctl)
#define DM_TABLE_STATUS _IOWR(DM_IOCTL, DM_TABLE_STATUS_CMD, struct dm_ioctl)
#define DM_LIST_VERSIONS _IOWR(DM_IOCTL, DM_LIST_VERSIONS_CMD, struct dm_ioctl)
#define DM_GET_TARGET_VERSION _IOWR(DM_IOCTL, DM_GET_TARGET_VERSION_CMD, struct dm_ioctl)
#define DM_TARGET_MSG _IOWR(DM_IOCTL, DM_TARGET_MSG_CMD, struct dm_ioctl)
#define DM_DEV_SET_GEOMETRY _IOWR(DM_IOCTL, DM_DEV_SET_GEOMETRY_CMD, struct dm_ioctl)
#define DM_VERSION_MAJOR 4
#define DM_VERSION_MINOR 43
#define DM_VERSION_PATCHLEVEL 0
#define DM_VERSION_EXTRA "-ioctl(2020-10-01)"
#define DM_READONLY_FLAG (1 << 0)
#define DM_SUSPEND_FLAG (1 << 1)
#define DM_PERSISTENT_DEV_FLAG (1 << 3)
#define DM_STATUS_TABLE_FLAG (1 << 4)
#define DM_ACTIVE_PRESENT_FLAG (1 << 5)
#define DM_INACTIVE_PRESENT_FLAG (1 << 6)
#define DM_BUFFER_FULL_FLAG (1 << 8)
#define DM_SKIP_BDGET_FLAG (1 << 9)
#define DM_SKIP_LOCKFS_FLAG (1 << 10)
#define DM_NOFLUSH_FLAG (1 << 11)
#define DM_QUERY_INACTIVE_TABLE_FLAG (1 << 12)
#define DM_UEVENT_GENERATED_FLAG (1 << 13)
#define DM_UUID_FLAG (1 << 14)
#define DM_SECURE_DATA_FLAG (1 << 15)
#define DM_DATA_OUT_FLAG (1 << 16)
#define DM_DEFERRED_REMOVE (1 << 17)
#define DM_INTERNAL_SUSPEND_FLAG (1 << 18)
#endif