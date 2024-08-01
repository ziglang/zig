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
#ifndef _LINUX_USERFAULTFD_H
#define _LINUX_USERFAULTFD_H
#include <linux/types.h>
#define UFFD_API ((__u64) 0xAA)
#define UFFD_API_FEATURES (UFFD_FEATURE_PAGEFAULT_FLAG_WP | UFFD_FEATURE_EVENT_FORK | UFFD_FEATURE_EVENT_REMAP | UFFD_FEATURE_EVENT_REMOVE | UFFD_FEATURE_EVENT_UNMAP | UFFD_FEATURE_MISSING_HUGETLBFS | UFFD_FEATURE_MISSING_SHMEM | UFFD_FEATURE_SIGBUS | UFFD_FEATURE_THREAD_ID)
#define UFFD_API_IOCTLS ((__u64) 1 << _UFFDIO_REGISTER | (__u64) 1 << _UFFDIO_UNREGISTER | (__u64) 1 << _UFFDIO_API)
#define UFFD_API_RANGE_IOCTLS ((__u64) 1 << _UFFDIO_WAKE | (__u64) 1 << _UFFDIO_COPY | (__u64) 1 << _UFFDIO_ZEROPAGE | (__u64) 1 << _UFFDIO_WRITEPROTECT)
#define UFFD_API_RANGE_IOCTLS_BASIC ((__u64) 1 << _UFFDIO_WAKE | (__u64) 1 << _UFFDIO_COPY)
#define _UFFDIO_REGISTER (0x00)
#define _UFFDIO_UNREGISTER (0x01)
#define _UFFDIO_WAKE (0x02)
#define _UFFDIO_COPY (0x03)
#define _UFFDIO_ZEROPAGE (0x04)
#define _UFFDIO_WRITEPROTECT (0x06)
#define _UFFDIO_API (0x3F)
#define UFFDIO 0xAA
#define UFFDIO_API _IOWR(UFFDIO, _UFFDIO_API, struct uffdio_api)
#define UFFDIO_REGISTER _IOWR(UFFDIO, _UFFDIO_REGISTER, struct uffdio_register)
#define UFFDIO_UNREGISTER _IOR(UFFDIO, _UFFDIO_UNREGISTER, struct uffdio_range)
#define UFFDIO_WAKE _IOR(UFFDIO, _UFFDIO_WAKE, struct uffdio_range)
#define UFFDIO_COPY _IOWR(UFFDIO, _UFFDIO_COPY, struct uffdio_copy)
#define UFFDIO_ZEROPAGE _IOWR(UFFDIO, _UFFDIO_ZEROPAGE, struct uffdio_zeropage)
#define UFFDIO_WRITEPROTECT _IOWR(UFFDIO, _UFFDIO_WRITEPROTECT, struct uffdio_writeprotect)
struct uffd_msg {
  __u8 event;
  __u8 reserved1;
  __u16 reserved2;
  __u32 reserved3;
  union {
    struct {
      __u64 flags;
      __u64 address;
      union {
        __u32 ptid;
      } feat;
    } pagefault;
    struct {
      __u32 ufd;
    } fork;
    struct {
      __u64 from;
      __u64 to;
      __u64 len;
    } remap;
    struct {
      __u64 start;
      __u64 end;
    } remove;
    struct {
      __u64 reserved1;
      __u64 reserved2;
      __u64 reserved3;
    } reserved;
  } arg;
} __packed;
#define UFFD_EVENT_PAGEFAULT 0x12
#define UFFD_EVENT_FORK 0x13
#define UFFD_EVENT_REMAP 0x14
#define UFFD_EVENT_REMOVE 0x15
#define UFFD_EVENT_UNMAP 0x16
#define UFFD_PAGEFAULT_FLAG_WRITE (1 << 0)
#define UFFD_PAGEFAULT_FLAG_WP (1 << 1)
struct uffdio_api {
  __u64 api;
#define UFFD_FEATURE_PAGEFAULT_FLAG_WP (1 << 0)
#define UFFD_FEATURE_EVENT_FORK (1 << 1)
#define UFFD_FEATURE_EVENT_REMAP (1 << 2)
#define UFFD_FEATURE_EVENT_REMOVE (1 << 3)
#define UFFD_FEATURE_MISSING_HUGETLBFS (1 << 4)
#define UFFD_FEATURE_MISSING_SHMEM (1 << 5)
#define UFFD_FEATURE_EVENT_UNMAP (1 << 6)
#define UFFD_FEATURE_SIGBUS (1 << 7)
#define UFFD_FEATURE_THREAD_ID (1 << 8)
  __u64 features;
  __u64 ioctls;
};
struct uffdio_range {
  __u64 start;
  __u64 len;
};
struct uffdio_register {
  struct uffdio_range range;
#define UFFDIO_REGISTER_MODE_MISSING ((__u64) 1 << 0)
#define UFFDIO_REGISTER_MODE_WP ((__u64) 1 << 1)
  __u64 mode;
  __u64 ioctls;
};
struct uffdio_copy {
  __u64 dst;
  __u64 src;
  __u64 len;
#define UFFDIO_COPY_MODE_DONTWAKE ((__u64) 1 << 0)
#define UFFDIO_COPY_MODE_WP ((__u64) 1 << 1)
  __u64 mode;
  __s64 copy;
};
struct uffdio_zeropage {
  struct uffdio_range range;
#define UFFDIO_ZEROPAGE_MODE_DONTWAKE ((__u64) 1 << 0)
  __u64 mode;
  __s64 zeropage;
};
struct uffdio_writeprotect {
  struct uffdio_range range;
#define UFFDIO_WRITEPROTECT_MODE_WP ((__u64) 1 << 0)
#define UFFDIO_WRITEPROTECT_MODE_DONTWAKE ((__u64) 1 << 1)
  __u64 mode;
};
#endif