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
#ifndef __V4L2_COMMON__
#define __V4L2_COMMON__
#include <linux/types.h>
#define V4L2_SEL_TGT_CROP 0x0000
#define V4L2_SEL_TGT_CROP_DEFAULT 0x0001
#define V4L2_SEL_TGT_CROP_BOUNDS 0x0002
#define V4L2_SEL_TGT_NATIVE_SIZE 0x0003
#define V4L2_SEL_TGT_COMPOSE 0x0100
#define V4L2_SEL_TGT_COMPOSE_DEFAULT 0x0101
#define V4L2_SEL_TGT_COMPOSE_BOUNDS 0x0102
#define V4L2_SEL_TGT_COMPOSE_PADDED 0x0103
#define V4L2_SEL_FLAG_GE (1 << 0)
#define V4L2_SEL_FLAG_LE (1 << 1)
#define V4L2_SEL_FLAG_KEEP_CONFIG (1 << 2)
struct v4l2_edid {
  __u32 pad;
  __u32 start_block;
  __u32 blocks;
  __u32 reserved[5];
  __u8 * edid;
};
#define V4L2_SEL_TGT_CROP_ACTIVE V4L2_SEL_TGT_CROP
#define V4L2_SEL_TGT_COMPOSE_ACTIVE V4L2_SEL_TGT_COMPOSE
#define V4L2_SUBDEV_SEL_TGT_CROP_ACTUAL V4L2_SEL_TGT_CROP
#define V4L2_SUBDEV_SEL_TGT_COMPOSE_ACTUAL V4L2_SEL_TGT_COMPOSE
#define V4L2_SUBDEV_SEL_TGT_CROP_BOUNDS V4L2_SEL_TGT_CROP_BOUNDS
#define V4L2_SUBDEV_SEL_TGT_COMPOSE_BOUNDS V4L2_SEL_TGT_COMPOSE_BOUNDS
#define V4L2_SUBDEV_SEL_FLAG_SIZE_GE V4L2_SEL_FLAG_GE
#define V4L2_SUBDEV_SEL_FLAG_SIZE_LE V4L2_SEL_FLAG_LE
#define V4L2_SUBDEV_SEL_FLAG_KEEP_CONFIG V4L2_SEL_FLAG_KEEP_CONFIG
#endif