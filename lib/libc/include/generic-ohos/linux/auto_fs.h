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
#ifndef _UAPI_LINUX_AUTO_FS_H
#define _UAPI_LINUX_AUTO_FS_H
#include <linux/types.h>
#include <linux/limits.h>
#include <sys/ioctl.h>
#define AUTOFS_PROTO_VERSION 5
#define AUTOFS_MIN_PROTO_VERSION 3
#define AUTOFS_MAX_PROTO_VERSION 5
#define AUTOFS_PROTO_SUBVERSION 5
#if defined(__ia64__) || defined(__alpha__)
typedef unsigned long autofs_wqt_t;
#else
typedef unsigned int autofs_wqt_t;
#endif
#define autofs_ptype_missing 0
#define autofs_ptype_expire 1
struct autofs_packet_hdr {
  int proto_version;
  int type;
};
struct autofs_packet_missing {
  struct autofs_packet_hdr hdr;
  autofs_wqt_t wait_queue_token;
  int len;
  char name[NAME_MAX + 1];
};
struct autofs_packet_expire {
  struct autofs_packet_hdr hdr;
  int len;
  char name[NAME_MAX + 1];
};
#define AUTOFS_IOCTL 0x93
enum {
  AUTOFS_IOC_READY_CMD = 0x60,
  AUTOFS_IOC_FAIL_CMD,
  AUTOFS_IOC_CATATONIC_CMD,
  AUTOFS_IOC_PROTOVER_CMD,
  AUTOFS_IOC_SETTIMEOUT_CMD,
  AUTOFS_IOC_EXPIRE_CMD,
};
#define AUTOFS_IOC_READY _IO(AUTOFS_IOCTL, AUTOFS_IOC_READY_CMD)
#define AUTOFS_IOC_FAIL _IO(AUTOFS_IOCTL, AUTOFS_IOC_FAIL_CMD)
#define AUTOFS_IOC_CATATONIC _IO(AUTOFS_IOCTL, AUTOFS_IOC_CATATONIC_CMD)
#define AUTOFS_IOC_PROTOVER _IOR(AUTOFS_IOCTL, AUTOFS_IOC_PROTOVER_CMD, int)
#define AUTOFS_IOC_SETTIMEOUT32 _IOWR(AUTOFS_IOCTL, AUTOFS_IOC_SETTIMEOUT_CMD, compat_ulong_t)
#define AUTOFS_IOC_SETTIMEOUT _IOWR(AUTOFS_IOCTL, AUTOFS_IOC_SETTIMEOUT_CMD, unsigned long)
#define AUTOFS_IOC_EXPIRE _IOR(AUTOFS_IOCTL, AUTOFS_IOC_EXPIRE_CMD, struct autofs_packet_expire)
#define AUTOFS_EXP_NORMAL 0x00
#define AUTOFS_EXP_IMMEDIATE 0x01
#define AUTOFS_EXP_LEAVES 0x02
#define AUTOFS_EXP_FORCED 0x04
#define AUTOFS_TYPE_ANY 0U
#define AUTOFS_TYPE_INDIRECT 1U
#define AUTOFS_TYPE_DIRECT 2U
#define AUTOFS_TYPE_OFFSET 4U
enum autofs_notify {
  NFY_NONE,
  NFY_MOUNT,
  NFY_EXPIRE
};
#define autofs_ptype_expire_multi 2
#define autofs_ptype_missing_indirect 3
#define autofs_ptype_expire_indirect 4
#define autofs_ptype_missing_direct 5
#define autofs_ptype_expire_direct 6
struct autofs_packet_expire_multi {
  struct autofs_packet_hdr hdr;
  autofs_wqt_t wait_queue_token;
  int len;
  char name[NAME_MAX + 1];
};
union autofs_packet_union {
  struct autofs_packet_hdr hdr;
  struct autofs_packet_missing missing;
  struct autofs_packet_expire expire;
  struct autofs_packet_expire_multi expire_multi;
};
struct autofs_v5_packet {
  struct autofs_packet_hdr hdr;
  autofs_wqt_t wait_queue_token;
  __u32 dev;
  __u64 ino;
  __u32 uid;
  __u32 gid;
  __u32 pid;
  __u32 tgid;
  __u32 len;
  char name[NAME_MAX + 1];
};
typedef struct autofs_v5_packet autofs_packet_missing_indirect_t;
typedef struct autofs_v5_packet autofs_packet_expire_indirect_t;
typedef struct autofs_v5_packet autofs_packet_missing_direct_t;
typedef struct autofs_v5_packet autofs_packet_expire_direct_t;
union autofs_v5_packet_union {
  struct autofs_packet_hdr hdr;
  struct autofs_v5_packet v5_packet;
  autofs_packet_missing_indirect_t missing_indirect;
  autofs_packet_expire_indirect_t expire_indirect;
  autofs_packet_missing_direct_t missing_direct;
  autofs_packet_expire_direct_t expire_direct;
};
enum {
  AUTOFS_IOC_EXPIRE_MULTI_CMD = 0x66,
  AUTOFS_IOC_PROTOSUBVER_CMD,
  AUTOFS_IOC_ASKUMOUNT_CMD = 0x70,
};
#define AUTOFS_IOC_EXPIRE_MULTI _IOW(AUTOFS_IOCTL, AUTOFS_IOC_EXPIRE_MULTI_CMD, int)
#define AUTOFS_IOC_PROTOSUBVER _IOR(AUTOFS_IOCTL, AUTOFS_IOC_PROTOSUBVER_CMD, int)
#define AUTOFS_IOC_ASKUMOUNT _IOR(AUTOFS_IOCTL, AUTOFS_IOC_ASKUMOUNT_CMD, int)
#endif