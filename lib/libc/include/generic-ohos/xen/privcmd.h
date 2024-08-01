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
#ifndef __LINUX_PUBLIC_PRIVCMD_H__
#define __LINUX_PUBLIC_PRIVCMD_H__
#include <linux/types.h>
#include <linux/compiler.h>
#include <xen/interface/xen.h>
struct privcmd_hypercall {
  __u64 op;
  __u64 arg[5];
};
struct privcmd_mmap_entry {
  __u64 va;
  __u64 mfn;
  __u64 npages;
};
struct privcmd_mmap {
  int num;
  domid_t dom;
  struct privcmd_mmap_entry __user * entry;
};
struct privcmd_mmapbatch {
  int num;
  domid_t dom;
  __u64 addr;
  xen_pfn_t __user * arr;
};
#define PRIVCMD_MMAPBATCH_MFN_ERROR 0xf0000000U
#define PRIVCMD_MMAPBATCH_PAGED_ERROR 0x80000000U
struct privcmd_mmapbatch_v2 {
  unsigned int num;
  domid_t dom;
  __u64 addr;
  const xen_pfn_t __user * arr;
  int __user * err;
};
struct privcmd_dm_op_buf {
  void __user * uptr;
  size_t size;
};
struct privcmd_dm_op {
  domid_t dom;
  __u16 num;
  const struct privcmd_dm_op_buf __user * ubufs;
};
struct privcmd_mmap_resource {
  domid_t dom;
  __u32 type;
  __u32 id;
  __u32 idx;
  __u64 num;
  __u64 addr;
};
#define IOCTL_PRIVCMD_HYPERCALL _IOC(_IOC_NONE, 'P', 0, sizeof(struct privcmd_hypercall))
#define IOCTL_PRIVCMD_MMAP _IOC(_IOC_NONE, 'P', 2, sizeof(struct privcmd_mmap))
#define IOCTL_PRIVCMD_MMAPBATCH _IOC(_IOC_NONE, 'P', 3, sizeof(struct privcmd_mmapbatch))
#define IOCTL_PRIVCMD_MMAPBATCH_V2 _IOC(_IOC_NONE, 'P', 4, sizeof(struct privcmd_mmapbatch_v2))
#define IOCTL_PRIVCMD_DM_OP _IOC(_IOC_NONE, 'P', 5, sizeof(struct privcmd_dm_op))
#define IOCTL_PRIVCMD_RESTRICT _IOC(_IOC_NONE, 'P', 6, sizeof(domid_t))
#define IOCTL_PRIVCMD_MMAP_RESOURCE _IOC(_IOC_NONE, 'P', 7, sizeof(struct privcmd_mmap_resource))
#endif