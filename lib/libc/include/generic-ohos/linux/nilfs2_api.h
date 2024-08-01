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
#ifndef _LINUX_NILFS2_API_H
#define _LINUX_NILFS2_API_H
#include <linux/types.h>
#include <linux/ioctl.h>
struct nilfs_cpinfo {
  __u32 ci_flags;
  __u32 ci_pad;
  __u64 ci_cno;
  __u64 ci_create;
  __u64 ci_nblk_inc;
  __u64 ci_inodes_count;
  __u64 ci_blocks_count;
  __u64 ci_next;
};
enum {
  NILFS_CPINFO_SNAPSHOT,
  NILFS_CPINFO_INVALID,
  NILFS_CPINFO_SKETCH,
  NILFS_CPINFO_MINOR,
};
#define NILFS_CPINFO_FNS(flag,name) static inline int nilfs_cpinfo_ ##name(const struct nilfs_cpinfo * cpinfo) \
{ return ! ! (cpinfo->ci_flags & (1UL << NILFS_CPINFO_ ##flag)); \
}
struct nilfs_suinfo {
  __u64 sui_lastmod;
  __u32 sui_nblocks;
  __u32 sui_flags;
};
enum {
  NILFS_SUINFO_ACTIVE,
  NILFS_SUINFO_DIRTY,
  NILFS_SUINFO_ERROR,
};
#define NILFS_SUINFO_FNS(flag,name) static inline int nilfs_suinfo_ ##name(const struct nilfs_suinfo * si) \
{ return si->sui_flags & (1UL << NILFS_SUINFO_ ##flag); \
}
struct nilfs_suinfo_update {
  __u64 sup_segnum;
  __u32 sup_flags;
  __u32 sup_reserved;
  struct nilfs_suinfo sup_sui;
};
enum {
  NILFS_SUINFO_UPDATE_LASTMOD,
  NILFS_SUINFO_UPDATE_NBLOCKS,
  NILFS_SUINFO_UPDATE_FLAGS,
  __NR_NILFS_SUINFO_UPDATE_FIELDS,
};
#define NILFS_SUINFO_UPDATE_FNS(flag,name) static inline void nilfs_suinfo_update_set_ ##name(struct nilfs_suinfo_update * sup) \
{ sup->sup_flags |= 1UL << NILFS_SUINFO_UPDATE_ ##flag; \
} static inline void nilfs_suinfo_update_clear_ ##name(struct nilfs_suinfo_update * sup) \
{ sup->sup_flags &= ~(1UL << NILFS_SUINFO_UPDATE_ ##flag); \
} static inline int nilfs_suinfo_update_ ##name(const struct nilfs_suinfo_update * sup) \
{ return ! ! (sup->sup_flags & (1UL << NILFS_SUINFO_UPDATE_ ##flag)); \
}
enum {
  NILFS_CHECKPOINT,
  NILFS_SNAPSHOT,
};
struct nilfs_cpmode {
  __u64 cm_cno;
  __u32 cm_mode;
  __u32 cm_pad;
};
struct nilfs_argv {
  __u64 v_base;
  __u32 v_nmembs;
  __u16 v_size;
  __u16 v_flags;
  __u64 v_index;
};
struct nilfs_period {
  __u64 p_start;
  __u64 p_end;
};
struct nilfs_cpstat {
  __u64 cs_cno;
  __u64 cs_ncps;
  __u64 cs_nsss;
};
struct nilfs_sustat {
  __u64 ss_nsegs;
  __u64 ss_ncleansegs;
  __u64 ss_ndirtysegs;
  __u64 ss_ctime;
  __u64 ss_nongc_ctime;
  __u64 ss_prot_seq;
};
struct nilfs_vinfo {
  __u64 vi_vblocknr;
  __u64 vi_start;
  __u64 vi_end;
  __u64 vi_blocknr;
};
struct nilfs_vdesc {
  __u64 vd_ino;
  __u64 vd_cno;
  __u64 vd_vblocknr;
  struct nilfs_period vd_period;
  __u64 vd_blocknr;
  __u64 vd_offset;
  __u32 vd_flags;
  __u32 vd_pad;
};
struct nilfs_bdesc {
  __u64 bd_ino;
  __u64 bd_oblocknr;
  __u64 bd_blocknr;
  __u64 bd_offset;
  __u32 bd_level;
  __u32 bd_pad;
};
#define NILFS_IOCTL_IDENT 'n'
#define NILFS_IOCTL_CHANGE_CPMODE _IOW(NILFS_IOCTL_IDENT, 0x80, struct nilfs_cpmode)
#define NILFS_IOCTL_DELETE_CHECKPOINT _IOW(NILFS_IOCTL_IDENT, 0x81, __u64)
#define NILFS_IOCTL_GET_CPINFO _IOR(NILFS_IOCTL_IDENT, 0x82, struct nilfs_argv)
#define NILFS_IOCTL_GET_CPSTAT _IOR(NILFS_IOCTL_IDENT, 0x83, struct nilfs_cpstat)
#define NILFS_IOCTL_GET_SUINFO _IOR(NILFS_IOCTL_IDENT, 0x84, struct nilfs_argv)
#define NILFS_IOCTL_GET_SUSTAT _IOR(NILFS_IOCTL_IDENT, 0x85, struct nilfs_sustat)
#define NILFS_IOCTL_GET_VINFO _IOWR(NILFS_IOCTL_IDENT, 0x86, struct nilfs_argv)
#define NILFS_IOCTL_GET_BDESCS _IOWR(NILFS_IOCTL_IDENT, 0x87, struct nilfs_argv)
#define NILFS_IOCTL_CLEAN_SEGMENTS _IOW(NILFS_IOCTL_IDENT, 0x88, struct nilfs_argv[5])
#define NILFS_IOCTL_SYNC _IOR(NILFS_IOCTL_IDENT, 0x8A, __u64)
#define NILFS_IOCTL_RESIZE _IOW(NILFS_IOCTL_IDENT, 0x8B, __u64)
#define NILFS_IOCTL_SET_ALLOC_RANGE _IOW(NILFS_IOCTL_IDENT, 0x8C, __u64[2])
#define NILFS_IOCTL_SET_SUINFO _IOW(NILFS_IOCTL_IDENT, 0x8D, struct nilfs_argv)
#endif