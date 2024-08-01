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
#ifndef __LINUX_V4L2_SUBDEV_H
#define __LINUX_V4L2_SUBDEV_H
#include <linux/ioctl.h>
#include <linux/types.h>
#include <linux/v4l2-common.h>
#include <linux/v4l2-mediabus.h>
enum v4l2_subdev_format_whence {
  V4L2_SUBDEV_FORMAT_TRY = 0,
  V4L2_SUBDEV_FORMAT_ACTIVE = 1,
};
struct v4l2_subdev_format {
  __u32 which;
  __u32 pad;
  struct v4l2_mbus_framefmt format;
  __u32 reserved[8];
};
struct v4l2_subdev_crop {
  __u32 which;
  __u32 pad;
  struct v4l2_rect rect;
  __u32 reserved[8];
};
#define V4L2_SUBDEV_MBUS_CODE_CSC_COLORSPACE 0x00000001
#define V4L2_SUBDEV_MBUS_CODE_CSC_XFER_FUNC 0x00000002
#define V4L2_SUBDEV_MBUS_CODE_CSC_YCBCR_ENC 0x00000004
#define V4L2_SUBDEV_MBUS_CODE_CSC_HSV_ENC V4L2_SUBDEV_MBUS_CODE_CSC_YCBCR_ENC
#define V4L2_SUBDEV_MBUS_CODE_CSC_QUANTIZATION 0x00000008
struct v4l2_subdev_mbus_code_enum {
  __u32 pad;
  __u32 index;
  __u32 code;
  __u32 which;
  __u32 flags;
  __u32 reserved[7];
};
struct v4l2_subdev_frame_size_enum {
  __u32 index;
  __u32 pad;
  __u32 code;
  __u32 min_width;
  __u32 max_width;
  __u32 min_height;
  __u32 max_height;
  __u32 which;
  __u32 reserved[8];
};
struct v4l2_subdev_frame_interval {
  __u32 pad;
  struct v4l2_fract interval;
  __u32 reserved[9];
};
struct v4l2_subdev_frame_interval_enum {
  __u32 index;
  __u32 pad;
  __u32 code;
  __u32 width;
  __u32 height;
  struct v4l2_fract interval;
  __u32 which;
  __u32 reserved[8];
};
struct v4l2_subdev_selection {
  __u32 which;
  __u32 pad;
  __u32 target;
  __u32 flags;
  struct v4l2_rect r;
  __u32 reserved[8];
};
struct v4l2_subdev_capability {
  __u32 version;
  __u32 capabilities;
  __u32 reserved[14];
};
#define V4L2_SUBDEV_CAP_RO_SUBDEV BIT(0)
#define v4l2_subdev_edid v4l2_edid
#define VIDIOC_SUBDEV_QUERYCAP _IOR('V', 0, struct v4l2_subdev_capability)
#define VIDIOC_SUBDEV_G_FMT _IOWR('V', 4, struct v4l2_subdev_format)
#define VIDIOC_SUBDEV_S_FMT _IOWR('V', 5, struct v4l2_subdev_format)
#define VIDIOC_SUBDEV_G_FRAME_INTERVAL _IOWR('V', 21, struct v4l2_subdev_frame_interval)
#define VIDIOC_SUBDEV_S_FRAME_INTERVAL _IOWR('V', 22, struct v4l2_subdev_frame_interval)
#define VIDIOC_SUBDEV_ENUM_MBUS_CODE _IOWR('V', 2, struct v4l2_subdev_mbus_code_enum)
#define VIDIOC_SUBDEV_ENUM_FRAME_SIZE _IOWR('V', 74, struct v4l2_subdev_frame_size_enum)
#define VIDIOC_SUBDEV_ENUM_FRAME_INTERVAL _IOWR('V', 75, struct v4l2_subdev_frame_interval_enum)
#define VIDIOC_SUBDEV_G_CROP _IOWR('V', 59, struct v4l2_subdev_crop)
#define VIDIOC_SUBDEV_S_CROP _IOWR('V', 60, struct v4l2_subdev_crop)
#define VIDIOC_SUBDEV_G_SELECTION _IOWR('V', 61, struct v4l2_subdev_selection)
#define VIDIOC_SUBDEV_S_SELECTION _IOWR('V', 62, struct v4l2_subdev_selection)
#define VIDIOC_SUBDEV_G_STD _IOR('V', 23, v4l2_std_id)
#define VIDIOC_SUBDEV_S_STD _IOW('V', 24, v4l2_std_id)
#define VIDIOC_SUBDEV_ENUMSTD _IOWR('V', 25, struct v4l2_standard)
#define VIDIOC_SUBDEV_G_EDID _IOWR('V', 40, struct v4l2_edid)
#define VIDIOC_SUBDEV_S_EDID _IOWR('V', 41, struct v4l2_edid)
#define VIDIOC_SUBDEV_QUERYSTD _IOR('V', 63, v4l2_std_id)
#define VIDIOC_SUBDEV_S_DV_TIMINGS _IOWR('V', 87, struct v4l2_dv_timings)
#define VIDIOC_SUBDEV_G_DV_TIMINGS _IOWR('V', 88, struct v4l2_dv_timings)
#define VIDIOC_SUBDEV_ENUM_DV_TIMINGS _IOWR('V', 98, struct v4l2_enum_dv_timings)
#define VIDIOC_SUBDEV_QUERY_DV_TIMINGS _IOR('V', 99, struct v4l2_dv_timings)
#define VIDIOC_SUBDEV_DV_TIMINGS_CAP _IOWR('V', 100, struct v4l2_dv_timings_cap)
#endif