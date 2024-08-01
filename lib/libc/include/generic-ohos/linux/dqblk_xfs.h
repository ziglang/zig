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
#ifndef _LINUX_DQBLK_XFS_H
#define _LINUX_DQBLK_XFS_H
#include <linux/types.h>
#define XQM_CMD(x) (('X' << 8) + (x))
#define XQM_COMMAND(x) (((x) & (0xff << 8)) == ('X' << 8))
#define XQM_USRQUOTA 0
#define XQM_GRPQUOTA 1
#define XQM_PRJQUOTA 2
#define XQM_MAXQUOTAS 3
#define Q_XQUOTAON XQM_CMD(1)
#define Q_XQUOTAOFF XQM_CMD(2)
#define Q_XGETQUOTA XQM_CMD(3)
#define Q_XSETQLIM XQM_CMD(4)
#define Q_XGETQSTAT XQM_CMD(5)
#define Q_XQUOTARM XQM_CMD(6)
#define Q_XQUOTASYNC XQM_CMD(7)
#define Q_XGETQSTATV XQM_CMD(8)
#define Q_XGETNEXTQUOTA XQM_CMD(9)
#define FS_DQUOT_VERSION 1
typedef struct fs_disk_quota {
  __s8 d_version;
  __s8 d_flags;
  __u16 d_fieldmask;
  __u32 d_id;
  __u64 d_blk_hardlimit;
  __u64 d_blk_softlimit;
  __u64 d_ino_hardlimit;
  __u64 d_ino_softlimit;
  __u64 d_bcount;
  __u64 d_icount;
  __s32 d_itimer;
  __s32 d_btimer;
  __u16 d_iwarns;
  __u16 d_bwarns;
  __s8 d_itimer_hi;
  __s8 d_btimer_hi;
  __s8 d_rtbtimer_hi;
  __s8 d_padding2;
  __u64 d_rtb_hardlimit;
  __u64 d_rtb_softlimit;
  __u64 d_rtbcount;
  __s32 d_rtbtimer;
  __u16 d_rtbwarns;
  __s16 d_padding3;
  char d_padding4[8];
} fs_disk_quota_t;
#define FS_DQ_ISOFT (1 << 0)
#define FS_DQ_IHARD (1 << 1)
#define FS_DQ_BSOFT (1 << 2)
#define FS_DQ_BHARD (1 << 3)
#define FS_DQ_RTBSOFT (1 << 4)
#define FS_DQ_RTBHARD (1 << 5)
#define FS_DQ_LIMIT_MASK (FS_DQ_ISOFT | FS_DQ_IHARD | FS_DQ_BSOFT | FS_DQ_BHARD | FS_DQ_RTBSOFT | FS_DQ_RTBHARD)
#define FS_DQ_BTIMER (1 << 6)
#define FS_DQ_ITIMER (1 << 7)
#define FS_DQ_RTBTIMER (1 << 8)
#define FS_DQ_TIMER_MASK (FS_DQ_BTIMER | FS_DQ_ITIMER | FS_DQ_RTBTIMER)
#define FS_DQ_BWARNS (1 << 9)
#define FS_DQ_IWARNS (1 << 10)
#define FS_DQ_RTBWARNS (1 << 11)
#define FS_DQ_WARNS_MASK (FS_DQ_BWARNS | FS_DQ_IWARNS | FS_DQ_RTBWARNS)
#define FS_DQ_BCOUNT (1 << 12)
#define FS_DQ_ICOUNT (1 << 13)
#define FS_DQ_RTBCOUNT (1 << 14)
#define FS_DQ_ACCT_MASK (FS_DQ_BCOUNT | FS_DQ_ICOUNT | FS_DQ_RTBCOUNT)
#define FS_DQ_BIGTIME (1 << 15)
#define FS_QUOTA_UDQ_ACCT (1 << 0)
#define FS_QUOTA_UDQ_ENFD (1 << 1)
#define FS_QUOTA_GDQ_ACCT (1 << 2)
#define FS_QUOTA_GDQ_ENFD (1 << 3)
#define FS_QUOTA_PDQ_ACCT (1 << 4)
#define FS_QUOTA_PDQ_ENFD (1 << 5)
#define FS_USER_QUOTA (1 << 0)
#define FS_PROJ_QUOTA (1 << 1)
#define FS_GROUP_QUOTA (1 << 2)
#define FS_QSTAT_VERSION 1
typedef struct fs_qfilestat {
  __u64 qfs_ino;
  __u64 qfs_nblks;
  __u32 qfs_nextents;
} fs_qfilestat_t;
typedef struct fs_quota_stat {
  __s8 qs_version;
  __u16 qs_flags;
  __s8 qs_pad;
  fs_qfilestat_t qs_uquota;
  fs_qfilestat_t qs_gquota;
  __u32 qs_incoredqs;
  __s32 qs_btimelimit;
  __s32 qs_itimelimit;
  __s32 qs_rtbtimelimit;
  __u16 qs_bwarnlimit;
  __u16 qs_iwarnlimit;
} fs_quota_stat_t;
#define FS_QSTATV_VERSION1 1
struct fs_qfilestatv {
  __u64 qfs_ino;
  __u64 qfs_nblks;
  __u32 qfs_nextents;
  __u32 qfs_pad;
};
struct fs_quota_statv {
  __s8 qs_version;
  __u8 qs_pad1;
  __u16 qs_flags;
  __u32 qs_incoredqs;
  struct fs_qfilestatv qs_uquota;
  struct fs_qfilestatv qs_gquota;
  struct fs_qfilestatv qs_pquota;
  __s32 qs_btimelimit;
  __s32 qs_itimelimit;
  __s32 qs_rtbtimelimit;
  __u16 qs_bwarnlimit;
  __u16 qs_iwarnlimit;
  __u64 qs_pad2[8];
};
#endif