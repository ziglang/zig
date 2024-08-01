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
#ifndef _LINUX_NILFS2_ONDISK_H
#define _LINUX_NILFS2_ONDISK_H
#include <linux/types.h>
#include <linux/magic.h>
#include <asm/byteorder.h>
#define NILFS_INODE_BMAP_SIZE 7
struct nilfs_inode {
  __le64 i_blocks;
  __le64 i_size;
  __le64 i_ctime;
  __le64 i_mtime;
  __le32 i_ctime_nsec;
  __le32 i_mtime_nsec;
  __le32 i_uid;
  __le32 i_gid;
  __le16 i_mode;
  __le16 i_links_count;
  __le32 i_flags;
  __le64 i_bmap[NILFS_INODE_BMAP_SIZE];
#define i_device_code i_bmap[0]
  __le64 i_xattr;
  __le32 i_generation;
  __le32 i_pad;
};
#define NILFS_MIN_INODE_SIZE 128
struct nilfs_super_root {
  __le32 sr_sum;
  __le16 sr_bytes;
  __le16 sr_flags;
  __le64 sr_nongc_ctime;
  struct nilfs_inode sr_dat;
  struct nilfs_inode sr_cpfile;
  struct nilfs_inode sr_sufile;
};
#define NILFS_SR_MDT_OFFSET(inode_size,i) ((unsigned long) & ((struct nilfs_super_root *) 0)->sr_dat + (inode_size) * (i))
#define NILFS_SR_DAT_OFFSET(inode_size) NILFS_SR_MDT_OFFSET(inode_size, 0)
#define NILFS_SR_CPFILE_OFFSET(inode_size) NILFS_SR_MDT_OFFSET(inode_size, 1)
#define NILFS_SR_SUFILE_OFFSET(inode_size) NILFS_SR_MDT_OFFSET(inode_size, 2)
#define NILFS_SR_BYTES(inode_size) NILFS_SR_MDT_OFFSET(inode_size, 3)
#define NILFS_DFL_MAX_MNT_COUNT 50
#define NILFS_VALID_FS 0x0001
#define NILFS_ERROR_FS 0x0002
#define NILFS_RESIZE_FS 0x0004
#define NILFS_MOUNT_ERROR_MODE 0x0070
#define NILFS_MOUNT_ERRORS_CONT 0x0010
#define NILFS_MOUNT_ERRORS_RO 0x0020
#define NILFS_MOUNT_ERRORS_PANIC 0x0040
#define NILFS_MOUNT_BARRIER 0x1000
#define NILFS_MOUNT_STRICT_ORDER 0x2000
#define NILFS_MOUNT_NORECOVERY 0x4000
#define NILFS_MOUNT_DISCARD 0x8000
struct nilfs_super_block {
  __le32 s_rev_level;
  __le16 s_minor_rev_level;
  __le16 s_magic;
  __le16 s_bytes;
  __le16 s_flags;
  __le32 s_crc_seed;
  __le32 s_sum;
  __le32 s_log_block_size;
  __le64 s_nsegments;
  __le64 s_dev_size;
  __le64 s_first_data_block;
  __le32 s_blocks_per_segment;
  __le32 s_r_segments_percentage;
  __le64 s_last_cno;
  __le64 s_last_pseg;
  __le64 s_last_seq;
  __le64 s_free_blocks_count;
  __le64 s_ctime;
  __le64 s_mtime;
  __le64 s_wtime;
  __le16 s_mnt_count;
  __le16 s_max_mnt_count;
  __le16 s_state;
  __le16 s_errors;
  __le64 s_lastcheck;
  __le32 s_checkinterval;
  __le32 s_creator_os;
  __le16 s_def_resuid;
  __le16 s_def_resgid;
  __le32 s_first_ino;
  __le16 s_inode_size;
  __le16 s_dat_entry_size;
  __le16 s_checkpoint_size;
  __le16 s_segment_usage_size;
  __u8 s_uuid[16];
  char s_volume_name[80];
  __le32 s_c_interval;
  __le32 s_c_block_max;
  __le64 s_feature_compat;
  __le64 s_feature_compat_ro;
  __le64 s_feature_incompat;
  __u32 s_reserved[186];
};
#define NILFS_OS_LINUX 0
#define NILFS_CURRENT_REV 2
#define NILFS_MINOR_REV 0
#define NILFS_MIN_SUPP_REV 2
#define NILFS_FEATURE_COMPAT_RO_BLOCK_COUNT 0x00000001ULL
#define NILFS_FEATURE_COMPAT_SUPP 0ULL
#define NILFS_FEATURE_COMPAT_RO_SUPP NILFS_FEATURE_COMPAT_RO_BLOCK_COUNT
#define NILFS_FEATURE_INCOMPAT_SUPP 0ULL
#define NILFS_SB_BYTES ((long) & ((struct nilfs_super_block *) 0)->s_reserved)
#define NILFS_ROOT_INO 2
#define NILFS_DAT_INO 3
#define NILFS_CPFILE_INO 4
#define NILFS_SUFILE_INO 5
#define NILFS_IFILE_INO 6
#define NILFS_ATIME_INO 7
#define NILFS_XATTR_INO 8
#define NILFS_SKETCH_INO 10
#define NILFS_USER_INO 11
#define NILFS_SB_OFFSET_BYTES 1024
#define NILFS_SEG_MIN_BLOCKS 16
#define NILFS_PSEG_MIN_BLOCKS 2
#define NILFS_MIN_NRSVSEGS 8
#define NILFS_ROOT_METADATA_FILE(ino) ((ino) >= NILFS_DAT_INO && (ino) <= NILFS_SUFILE_INO)
#define NILFS_SB2_OFFSET_BYTES(devsize) ((((devsize) >> 12) - 1) << 12)
#define NILFS_LINK_MAX 32000
#define NILFS_NAME_LEN 255
#define NILFS_MIN_BLOCK_SIZE 1024
#define NILFS_MAX_BLOCK_SIZE 65536
struct nilfs_dir_entry {
  __le64 inode;
  __le16 rec_len;
  __u8 name_len;
  __u8 file_type;
  char name[NILFS_NAME_LEN];
  char pad;
};
enum {
  NILFS_FT_UNKNOWN,
  NILFS_FT_REG_FILE,
  NILFS_FT_DIR,
  NILFS_FT_CHRDEV,
  NILFS_FT_BLKDEV,
  NILFS_FT_FIFO,
  NILFS_FT_SOCK,
  NILFS_FT_SYMLINK,
  NILFS_FT_MAX
};
#define NILFS_DIR_PAD 8
#define NILFS_DIR_ROUND (NILFS_DIR_PAD - 1)
#define NILFS_DIR_REC_LEN(name_len) (((name_len) + 12 + NILFS_DIR_ROUND) & ~NILFS_DIR_ROUND)
#define NILFS_MAX_REC_LEN ((1 << 16) - 1)
struct nilfs_finfo {
  __le64 fi_ino;
  __le64 fi_cno;
  __le32 fi_nblocks;
  __le32 fi_ndatablk;
};
struct nilfs_binfo_v {
  __le64 bi_vblocknr;
  __le64 bi_blkoff;
};
struct nilfs_binfo_dat {
  __le64 bi_blkoff;
  __u8 bi_level;
  __u8 bi_pad[7];
};
union nilfs_binfo {
  struct nilfs_binfo_v bi_v;
  struct nilfs_binfo_dat bi_dat;
};
struct nilfs_segment_summary {
  __le32 ss_datasum;
  __le32 ss_sumsum;
  __le32 ss_magic;
  __le16 ss_bytes;
  __le16 ss_flags;
  __le64 ss_seq;
  __le64 ss_create;
  __le64 ss_next;
  __le32 ss_nblocks;
  __le32 ss_nfinfo;
  __le32 ss_sumbytes;
  __le32 ss_pad;
  __le64 ss_cno;
};
#define NILFS_SEGSUM_MAGIC 0x1eaffa11
#define NILFS_SS_LOGBGN 0x0001
#define NILFS_SS_LOGEND 0x0002
#define NILFS_SS_SR 0x0004
#define NILFS_SS_SYNDT 0x0008
#define NILFS_SS_GC 0x0010
struct nilfs_btree_node {
  __u8 bn_flags;
  __u8 bn_level;
  __le16 bn_nchildren;
  __le32 bn_pad;
};
#define NILFS_BTREE_NODE_ROOT 0x01
#define NILFS_BTREE_LEVEL_DATA 0
#define NILFS_BTREE_LEVEL_NODE_MIN (NILFS_BTREE_LEVEL_DATA + 1)
#define NILFS_BTREE_LEVEL_MAX 14
struct nilfs_direct_node {
  __u8 dn_flags;
  __u8 pad[7];
};
struct nilfs_palloc_group_desc {
  __le32 pg_nfrees;
};
struct nilfs_dat_entry {
  __le64 de_blocknr;
  __le64 de_start;
  __le64 de_end;
  __le64 de_rsv;
};
#define NILFS_MIN_DAT_ENTRY_SIZE 32
struct nilfs_snapshot_list {
  __le64 ssl_next;
  __le64 ssl_prev;
};
struct nilfs_checkpoint {
  __le32 cp_flags;
  __le32 cp_checkpoints_count;
  struct nilfs_snapshot_list cp_snapshot_list;
  __le64 cp_cno;
  __le64 cp_create;
  __le64 cp_nblk_inc;
  __le64 cp_inodes_count;
  __le64 cp_blocks_count;
  struct nilfs_inode cp_ifile_inode;
};
#define NILFS_MIN_CHECKPOINT_SIZE (64 + NILFS_MIN_INODE_SIZE)
enum {
  NILFS_CHECKPOINT_SNAPSHOT,
  NILFS_CHECKPOINT_INVALID,
  NILFS_CHECKPOINT_SKETCH,
  NILFS_CHECKPOINT_MINOR,
};
#define NILFS_CHECKPOINT_FNS(flag,name) static inline void nilfs_checkpoint_set_ ##name(struct nilfs_checkpoint * cp) \
{ cp->cp_flags = __cpu_to_le32(__le32_to_cpu(cp->cp_flags) | (1UL << NILFS_CHECKPOINT_ ##flag)); \
} static inline void nilfs_checkpoint_clear_ ##name(struct nilfs_checkpoint * cp) \
{ cp->cp_flags = __cpu_to_le32(__le32_to_cpu(cp->cp_flags) & ~(1UL << NILFS_CHECKPOINT_ ##flag)); \
} static inline int nilfs_checkpoint_ ##name(const struct nilfs_checkpoint * cp) \
{ return ! ! (__le32_to_cpu(cp->cp_flags) & (1UL << NILFS_CHECKPOINT_ ##flag)); \
}
struct nilfs_cpfile_header {
  __le64 ch_ncheckpoints;
  __le64 ch_nsnapshots;
  struct nilfs_snapshot_list ch_snapshot_list;
};
#define NILFS_CPFILE_FIRST_CHECKPOINT_OFFSET ((sizeof(struct nilfs_cpfile_header) + sizeof(struct nilfs_checkpoint) - 1) / sizeof(struct nilfs_checkpoint))
struct nilfs_segment_usage {
  __le64 su_lastmod;
  __le32 su_nblocks;
  __le32 su_flags;
};
#define NILFS_MIN_SEGMENT_USAGE_SIZE 16
enum {
  NILFS_SEGMENT_USAGE_ACTIVE,
  NILFS_SEGMENT_USAGE_DIRTY,
  NILFS_SEGMENT_USAGE_ERROR,
};
#define NILFS_SEGMENT_USAGE_FNS(flag,name) static inline void nilfs_segment_usage_set_ ##name(struct nilfs_segment_usage * su) \
{ su->su_flags = __cpu_to_le32(__le32_to_cpu(su->su_flags) | (1UL << NILFS_SEGMENT_USAGE_ ##flag)); \
} static inline void nilfs_segment_usage_clear_ ##name(struct nilfs_segment_usage * su) \
{ su->su_flags = __cpu_to_le32(__le32_to_cpu(su->su_flags) & ~(1UL << NILFS_SEGMENT_USAGE_ ##flag)); \
} static inline int nilfs_segment_usage_ ##name(const struct nilfs_segment_usage * su) \
{ return ! ! (__le32_to_cpu(su->su_flags) & (1UL << NILFS_SEGMENT_USAGE_ ##flag)); \
}
struct nilfs_sufile_header {
  __le64 sh_ncleansegs;
  __le64 sh_ndirtysegs;
  __le64 sh_last_alloc;
};
#define NILFS_SUFILE_FIRST_SEGMENT_USAGE_OFFSET ((sizeof(struct nilfs_sufile_header) + sizeof(struct nilfs_segment_usage) - 1) / sizeof(struct nilfs_segment_usage))
#endif