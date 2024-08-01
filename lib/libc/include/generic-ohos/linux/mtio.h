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
#ifndef _LINUX_MTIO_H
#define _LINUX_MTIO_H
#include <linux/types.h>
#include <linux/ioctl.h>
struct mtop {
  short mt_op;
  int mt_count;
};
#define MTRESET 0
#define MTFSF 1
#define MTBSF 2
#define MTFSR 3
#define MTBSR 4
#define MTWEOF 5
#define MTREW 6
#define MTOFFL 7
#define MTNOP 8
#define MTRETEN 9
#define MTBSFM 10
#define MTFSFM 11
#define MTEOM 12
#define MTERASE 13
#define MTRAS1 14
#define MTRAS2 15
#define MTRAS3 16
#define MTSETBLK 20
#define MTSETDENSITY 21
#define MTSEEK 22
#define MTTELL 23
#define MTSETDRVBUFFER 24
#define MTFSS 25
#define MTBSS 26
#define MTWSM 27
#define MTLOCK 28
#define MTUNLOCK 29
#define MTLOAD 30
#define MTUNLOAD 31
#define MTCOMPRESSION 32
#define MTSETPART 33
#define MTMKPART 34
#define MTWEOFI 35
struct mtget {
  long mt_type;
  long mt_resid;
  long mt_dsreg;
  long mt_gstat;
  long mt_erreg;
  __kernel_daddr_t mt_fileno;
  __kernel_daddr_t mt_blkno;
};
#define MT_ISUNKNOWN 0x01
#define MT_ISQIC02 0x02
#define MT_ISWT5150 0x03
#define MT_ISARCHIVE_5945L2 0x04
#define MT_ISCMSJ500 0x05
#define MT_ISTDC3610 0x06
#define MT_ISARCHIVE_VP60I 0x07
#define MT_ISARCHIVE_2150L 0x08
#define MT_ISARCHIVE_2060L 0x09
#define MT_ISARCHIVESC499 0x0A
#define MT_ISQIC02_ALL_FEATURES 0x0F
#define MT_ISWT5099EEN24 0x11
#define MT_ISTEAC_MT2ST 0x12
#define MT_ISEVEREX_FT40A 0x32
#define MT_ISDDS1 0x51
#define MT_ISDDS2 0x52
#define MT_ISONSTREAM_SC 0x61
#define MT_ISSCSI1 0x71
#define MT_ISSCSI2 0x72
#define MT_ISFTAPE_UNKNOWN 0x800000
#define MT_ISFTAPE_FLAG 0x800000
struct mtpos {
  long mt_blkno;
};
#define MTIOCTOP _IOW('m', 1, struct mtop)
#define MTIOCGET _IOR('m', 2, struct mtget)
#define MTIOCPOS _IOR('m', 3, struct mtpos)
#define GMT_EOF(x) ((x) & 0x80000000)
#define GMT_BOT(x) ((x) & 0x40000000)
#define GMT_EOT(x) ((x) & 0x20000000)
#define GMT_SM(x) ((x) & 0x10000000)
#define GMT_EOD(x) ((x) & 0x08000000)
#define GMT_WR_PROT(x) ((x) & 0x04000000)
#define GMT_ONLINE(x) ((x) & 0x01000000)
#define GMT_D_6250(x) ((x) & 0x00800000)
#define GMT_D_1600(x) ((x) & 0x00400000)
#define GMT_D_800(x) ((x) & 0x00200000)
#define GMT_DR_OPEN(x) ((x) & 0x00040000)
#define GMT_IM_REP_EN(x) ((x) & 0x00010000)
#define GMT_CLN(x) ((x) & 0x00008000)
#define MT_ST_BLKSIZE_SHIFT 0
#define MT_ST_BLKSIZE_MASK 0xffffff
#define MT_ST_DENSITY_SHIFT 24
#define MT_ST_DENSITY_MASK 0xff000000
#define MT_ST_SOFTERR_SHIFT 0
#define MT_ST_SOFTERR_MASK 0xffff
#define MT_ST_OPTIONS 0xf0000000
#define MT_ST_BOOLEANS 0x10000000
#define MT_ST_SETBOOLEANS 0x30000000
#define MT_ST_CLEARBOOLEANS 0x40000000
#define MT_ST_WRITE_THRESHOLD 0x20000000
#define MT_ST_DEF_BLKSIZE 0x50000000
#define MT_ST_DEF_OPTIONS 0x60000000
#define MT_ST_TIMEOUTS 0x70000000
#define MT_ST_SET_TIMEOUT (MT_ST_TIMEOUTS | 0x000000)
#define MT_ST_SET_LONG_TIMEOUT (MT_ST_TIMEOUTS | 0x100000)
#define MT_ST_SET_CLN 0x80000000
#define MT_ST_BUFFER_WRITES 0x1
#define MT_ST_ASYNC_WRITES 0x2
#define MT_ST_READ_AHEAD 0x4
#define MT_ST_DEBUGGING 0x8
#define MT_ST_TWO_FM 0x10
#define MT_ST_FAST_MTEOM 0x20
#define MT_ST_AUTO_LOCK 0x40
#define MT_ST_DEF_WRITES 0x80
#define MT_ST_CAN_BSR 0x100
#define MT_ST_NO_BLKLIMS 0x200
#define MT_ST_CAN_PARTITIONS 0x400
#define MT_ST_SCSI2LOGICAL 0x800
#define MT_ST_SYSV 0x1000
#define MT_ST_NOWAIT 0x2000
#define MT_ST_SILI 0x4000
#define MT_ST_NOWAIT_EOF 0x8000
#define MT_ST_CLEAR_DEFAULT 0xfffff
#define MT_ST_DEF_DENSITY (MT_ST_DEF_OPTIONS | 0x100000)
#define MT_ST_DEF_COMPRESSION (MT_ST_DEF_OPTIONS | 0x200000)
#define MT_ST_DEF_DRVBUFFER (MT_ST_DEF_OPTIONS | 0x300000)
#define MT_ST_HPLOADER_OFFSET 10000
#endif