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
#ifndef _UAPI_LINUX_AUTO_DEV_IOCTL_H
#define _UAPI_LINUX_AUTO_DEV_IOCTL_H
#include <linux/auto_fs.h>
#include <linux/string.h>
#define AUTOFS_DEVICE_NAME "autofs"
#define AUTOFS_DEV_IOCTL_VERSION_MAJOR 1
#define AUTOFS_DEV_IOCTL_VERSION_MINOR 1
#define AUTOFS_DEV_IOCTL_SIZE sizeof(struct autofs_dev_ioctl)
struct args_protover {
  __u32 version;
};
struct args_protosubver {
  __u32 sub_version;
};
struct args_openmount {
  __u32 devid;
};
struct args_ready {
  __u32 token;
};
struct args_fail {
  __u32 token;
  __s32 status;
};
struct args_setpipefd {
  __s32 pipefd;
};
struct args_timeout {
  __u64 timeout;
};
struct args_requester {
  __u32 uid;
  __u32 gid;
};
struct args_expire {
  __u32 how;
};
struct args_askumount {
  __u32 may_umount;
};
struct args_ismountpoint {
  union {
    struct args_in {
      __u32 type;
    } in;
    struct args_out {
      __u32 devid;
      __u32 magic;
    } out;
  };
};
struct autofs_dev_ioctl {
  __u32 ver_major;
  __u32 ver_minor;
  __u32 size;
  __s32 ioctlfd;
  union {
    struct args_protover protover;
    struct args_protosubver protosubver;
    struct args_openmount openmount;
    struct args_ready ready;
    struct args_fail fail;
    struct args_setpipefd setpipefd;
    struct args_timeout timeout;
    struct args_requester requester;
    struct args_expire expire;
    struct args_askumount askumount;
    struct args_ismountpoint ismountpoint;
  };
  char path[0];
};
enum {
  AUTOFS_DEV_IOCTL_VERSION_CMD = 0x71,
  AUTOFS_DEV_IOCTL_PROTOVER_CMD,
  AUTOFS_DEV_IOCTL_PROTOSUBVER_CMD,
  AUTOFS_DEV_IOCTL_OPENMOUNT_CMD,
  AUTOFS_DEV_IOCTL_CLOSEMOUNT_CMD,
  AUTOFS_DEV_IOCTL_READY_CMD,
  AUTOFS_DEV_IOCTL_FAIL_CMD,
  AUTOFS_DEV_IOCTL_SETPIPEFD_CMD,
  AUTOFS_DEV_IOCTL_CATATONIC_CMD,
  AUTOFS_DEV_IOCTL_TIMEOUT_CMD,
  AUTOFS_DEV_IOCTL_REQUESTER_CMD,
  AUTOFS_DEV_IOCTL_EXPIRE_CMD,
  AUTOFS_DEV_IOCTL_ASKUMOUNT_CMD,
  AUTOFS_DEV_IOCTL_ISMOUNTPOINT_CMD,
};
#define AUTOFS_DEV_IOCTL_VERSION _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_VERSION_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_PROTOVER _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_PROTOVER_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_PROTOSUBVER _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_PROTOSUBVER_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_OPENMOUNT _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_OPENMOUNT_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_CLOSEMOUNT _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_CLOSEMOUNT_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_READY _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_READY_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_FAIL _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_FAIL_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_SETPIPEFD _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_SETPIPEFD_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_CATATONIC _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_CATATONIC_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_TIMEOUT _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_TIMEOUT_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_REQUESTER _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_REQUESTER_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_EXPIRE _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_EXPIRE_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_ASKUMOUNT _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_ASKUMOUNT_CMD, struct autofs_dev_ioctl)
#define AUTOFS_DEV_IOCTL_ISMOUNTPOINT _IOWR(AUTOFS_IOCTL, AUTOFS_DEV_IOCTL_ISMOUNTPOINT_CMD, struct autofs_dev_ioctl)
#endif