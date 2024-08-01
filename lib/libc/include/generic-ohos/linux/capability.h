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
#ifndef _UAPI_LINUX_CAPABILITY_H
#define _UAPI_LINUX_CAPABILITY_H
#include <linux/types.h>
#define _LINUX_CAPABILITY_VERSION_1 0x19980330
#define _LINUX_CAPABILITY_U32S_1 1
#define _LINUX_CAPABILITY_VERSION_2 0x20071026
#define _LINUX_CAPABILITY_U32S_2 2
#define _LINUX_CAPABILITY_VERSION_3 0x20080522
#define _LINUX_CAPABILITY_U32S_3 2
typedef struct __user_cap_header_struct {
  __u32 version;
  int pid;
} __user * cap_user_header_t;
typedef struct __user_cap_data_struct {
  __u32 effective;
  __u32 permitted;
  __u32 inheritable;
} __user * cap_user_data_t;
#define VFS_CAP_REVISION_MASK 0xFF000000
#define VFS_CAP_REVISION_SHIFT 24
#define VFS_CAP_FLAGS_MASK ~VFS_CAP_REVISION_MASK
#define VFS_CAP_FLAGS_EFFECTIVE 0x000001
#define VFS_CAP_REVISION_1 0x01000000
#define VFS_CAP_U32_1 1
#define XATTR_CAPS_SZ_1 (sizeof(__le32) * (1 + 2 * VFS_CAP_U32_1))
#define VFS_CAP_REVISION_2 0x02000000
#define VFS_CAP_U32_2 2
#define XATTR_CAPS_SZ_2 (sizeof(__le32) * (1 + 2 * VFS_CAP_U32_2))
#define VFS_CAP_REVISION_3 0x03000000
#define VFS_CAP_U32_3 2
#define XATTR_CAPS_SZ_3 (sizeof(__le32) * (2 + 2 * VFS_CAP_U32_3))
#define XATTR_CAPS_SZ XATTR_CAPS_SZ_3
#define VFS_CAP_U32 VFS_CAP_U32_3
#define VFS_CAP_REVISION VFS_CAP_REVISION_3
struct vfs_cap_data {
  __le32 magic_etc;
  struct {
    __le32 permitted;
    __le32 inheritable;
  } data[VFS_CAP_U32];
};
struct vfs_ns_cap_data {
  __le32 magic_etc;
  struct {
    __le32 permitted;
    __le32 inheritable;
  } data[VFS_CAP_U32];
  __le32 rootid;
};
#define _LINUX_CAPABILITY_VERSION _LINUX_CAPABILITY_VERSION_1
#define _LINUX_CAPABILITY_U32S _LINUX_CAPABILITY_U32S_1
#define CAP_CHOWN 0
#define CAP_DAC_OVERRIDE 1
#define CAP_DAC_READ_SEARCH 2
#define CAP_FOWNER 3
#define CAP_FSETID 4
#define CAP_KILL 5
#define CAP_SETGID 6
#define CAP_SETUID 7
#define CAP_SETPCAP 8
#define CAP_LINUX_IMMUTABLE 9
#define CAP_NET_BIND_SERVICE 10
#define CAP_NET_BROADCAST 11
#define CAP_NET_ADMIN 12
#define CAP_NET_RAW 13
#define CAP_IPC_LOCK 14
#define CAP_IPC_OWNER 15
#define CAP_SYS_MODULE 16
#define CAP_SYS_RAWIO 17
#define CAP_SYS_CHROOT 18
#define CAP_SYS_PTRACE 19
#define CAP_SYS_PACCT 20
#define CAP_SYS_ADMIN 21
#define CAP_SYS_BOOT 22
#define CAP_SYS_NICE 23
#define CAP_SYS_RESOURCE 24
#define CAP_SYS_TIME 25
#define CAP_SYS_TTY_CONFIG 26
#define CAP_MKNOD 27
#define CAP_LEASE 28
#define CAP_AUDIT_WRITE 29
#define CAP_AUDIT_CONTROL 30
#define CAP_SETFCAP 31
#define CAP_MAC_OVERRIDE 32
#define CAP_MAC_ADMIN 33
#define CAP_SYSLOG 34
#define CAP_WAKE_ALARM 35
#define CAP_BLOCK_SUSPEND 36
#define CAP_AUDIT_READ 37
#define CAP_PERFMON 38
#define CAP_BPF 39
#define CAP_CHECKPOINT_RESTORE 40
#define CAP_LAST_CAP CAP_CHECKPOINT_RESTORE
#define cap_valid(x) ((x) >= 0 && (x) <= CAP_LAST_CAP)
#define CAP_TO_INDEX(x) ((x) >> 5)
#define CAP_TO_MASK(x) (1 << ((x) & 31))
#endif