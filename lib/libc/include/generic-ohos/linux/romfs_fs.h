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
#ifndef __LINUX_ROMFS_FS_H
#define __LINUX_ROMFS_FS_H
#include <linux/types.h>
#include <linux/fs.h>
#define ROMBSIZE BLOCK_SIZE
#define ROMBSBITS BLOCK_SIZE_BITS
#define ROMBMASK (ROMBSIZE - 1)
#define ROMFS_MAGIC 0x7275
#define ROMFS_MAXFN 128
#define __mkw(h,l) (((h) & 0x00ff) << 8 | ((l) & 0x00ff))
#define __mkl(h,l) (((h) & 0xffff) << 16 | ((l) & 0xffff))
#define __mk4(a,b,c,d) cpu_to_be32(__mkl(__mkw(a, b), __mkw(c, d)))
#define ROMSB_WORD0 __mk4('-', 'r', 'o', 'm')
#define ROMSB_WORD1 __mk4('1', 'f', 's', '-')
struct romfs_super_block {
  __be32 word0;
  __be32 word1;
  __be32 size;
  __be32 checksum;
  char name[0];
};
struct romfs_inode {
  __be32 next;
  __be32 spec;
  __be32 size;
  __be32 checksum;
  char name[0];
};
#define ROMFH_TYPE 7
#define ROMFH_HRD 0
#define ROMFH_DIR 1
#define ROMFH_REG 2
#define ROMFH_SYM 3
#define ROMFH_BLK 4
#define ROMFH_CHR 5
#define ROMFH_SCK 6
#define ROMFH_FIF 7
#define ROMFH_EXEC 8
#define ROMFH_SIZE 16
#define ROMFH_PAD (ROMFH_SIZE - 1)
#define ROMFH_MASK (~ROMFH_PAD)
#endif