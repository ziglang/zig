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
#ifndef _UAPI__LINUX_VIDEODEV2_H
#define _UAPI__LINUX_VIDEODEV2_H
#include <sys/time.h>
#include <linux/compiler.h>
#include <linux/ioctl.h>
#include <linux/types.h>
#include <linux/v4l2-common.h>
#include <linux/v4l2-controls.h>
#define VIDEO_MAX_FRAME 64
#define VIDEO_MAX_PLANES 8
#define v4l2_fourcc(a,b,c,d) ((__u32) (a) | ((__u32) (b) << 8) | ((__u32) (c) << 16) | ((__u32) (d) << 24))
#define v4l2_fourcc_be(a,b,c,d) (v4l2_fourcc(a, b, c, d) | (1U << 31))
enum v4l2_field {
  V4L2_FIELD_ANY = 0,
  V4L2_FIELD_NONE = 1,
  V4L2_FIELD_TOP = 2,
  V4L2_FIELD_BOTTOM = 3,
  V4L2_FIELD_INTERLACED = 4,
  V4L2_FIELD_SEQ_TB = 5,
  V4L2_FIELD_SEQ_BT = 6,
  V4L2_FIELD_ALTERNATE = 7,
  V4L2_FIELD_INTERLACED_TB = 8,
  V4L2_FIELD_INTERLACED_BT = 9,
};
#define V4L2_FIELD_HAS_TOP(field) ((field) == V4L2_FIELD_TOP || (field) == V4L2_FIELD_INTERLACED || (field) == V4L2_FIELD_INTERLACED_TB || (field) == V4L2_FIELD_INTERLACED_BT || (field) == V4L2_FIELD_SEQ_TB || (field) == V4L2_FIELD_SEQ_BT)
#define V4L2_FIELD_HAS_BOTTOM(field) ((field) == V4L2_FIELD_BOTTOM || (field) == V4L2_FIELD_INTERLACED || (field) == V4L2_FIELD_INTERLACED_TB || (field) == V4L2_FIELD_INTERLACED_BT || (field) == V4L2_FIELD_SEQ_TB || (field) == V4L2_FIELD_SEQ_BT)
#define V4L2_FIELD_HAS_BOTH(field) ((field) == V4L2_FIELD_INTERLACED || (field) == V4L2_FIELD_INTERLACED_TB || (field) == V4L2_FIELD_INTERLACED_BT || (field) == V4L2_FIELD_SEQ_TB || (field) == V4L2_FIELD_SEQ_BT)
#define V4L2_FIELD_HAS_T_OR_B(field) ((field) == V4L2_FIELD_BOTTOM || (field) == V4L2_FIELD_TOP || (field) == V4L2_FIELD_ALTERNATE)
#define V4L2_FIELD_IS_INTERLACED(field) ((field) == V4L2_FIELD_INTERLACED || (field) == V4L2_FIELD_INTERLACED_TB || (field) == V4L2_FIELD_INTERLACED_BT)
#define V4L2_FIELD_IS_SEQUENTIAL(field) ((field) == V4L2_FIELD_SEQ_TB || (field) == V4L2_FIELD_SEQ_BT)
enum v4l2_buf_type {
  V4L2_BUF_TYPE_VIDEO_CAPTURE = 1,
  V4L2_BUF_TYPE_VIDEO_OUTPUT = 2,
  V4L2_BUF_TYPE_VIDEO_OVERLAY = 3,
  V4L2_BUF_TYPE_VBI_CAPTURE = 4,
  V4L2_BUF_TYPE_VBI_OUTPUT = 5,
  V4L2_BUF_TYPE_SLICED_VBI_CAPTURE = 6,
  V4L2_BUF_TYPE_SLICED_VBI_OUTPUT = 7,
  V4L2_BUF_TYPE_VIDEO_OUTPUT_OVERLAY = 8,
  V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE = 9,
  V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE = 10,
  V4L2_BUF_TYPE_SDR_CAPTURE = 11,
  V4L2_BUF_TYPE_SDR_OUTPUT = 12,
  V4L2_BUF_TYPE_META_CAPTURE = 13,
  V4L2_BUF_TYPE_META_OUTPUT = 14,
  V4L2_BUF_TYPE_PRIVATE = 0x80,
};
#define V4L2_TYPE_IS_MULTIPLANAR(type) ((type) == V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE || (type) == V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE)
#define V4L2_TYPE_IS_OUTPUT(type) ((type) == V4L2_BUF_TYPE_VIDEO_OUTPUT || (type) == V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE || (type) == V4L2_BUF_TYPE_VIDEO_OVERLAY || (type) == V4L2_BUF_TYPE_VIDEO_OUTPUT_OVERLAY || (type) == V4L2_BUF_TYPE_VBI_OUTPUT || (type) == V4L2_BUF_TYPE_SLICED_VBI_OUTPUT || (type) == V4L2_BUF_TYPE_SDR_OUTPUT || (type) == V4L2_BUF_TYPE_META_OUTPUT)
#define V4L2_TYPE_IS_CAPTURE(type) (! V4L2_TYPE_IS_OUTPUT(type))
enum v4l2_tuner_type {
  V4L2_TUNER_RADIO = 1,
  V4L2_TUNER_ANALOG_TV = 2,
  V4L2_TUNER_DIGITAL_TV = 3,
  V4L2_TUNER_SDR = 4,
  V4L2_TUNER_RF = 5,
};
#define V4L2_TUNER_ADC V4L2_TUNER_SDR
enum v4l2_memory {
  V4L2_MEMORY_MMAP = 1,
  V4L2_MEMORY_USERPTR = 2,
  V4L2_MEMORY_OVERLAY = 3,
  V4L2_MEMORY_DMABUF = 4,
};
enum v4l2_colorspace {
  V4L2_COLORSPACE_DEFAULT = 0,
  V4L2_COLORSPACE_SMPTE170M = 1,
  V4L2_COLORSPACE_SMPTE240M = 2,
  V4L2_COLORSPACE_REC709 = 3,
  V4L2_COLORSPACE_BT878 = 4,
  V4L2_COLORSPACE_470_SYSTEM_M = 5,
  V4L2_COLORSPACE_470_SYSTEM_BG = 6,
  V4L2_COLORSPACE_JPEG = 7,
  V4L2_COLORSPACE_SRGB = 8,
  V4L2_COLORSPACE_OPRGB = 9,
  V4L2_COLORSPACE_BT2020 = 10,
  V4L2_COLORSPACE_RAW = 11,
  V4L2_COLORSPACE_DCI_P3 = 12,
};
#define V4L2_MAP_COLORSPACE_DEFAULT(is_sdtv,is_hdtv) ((is_sdtv) ? V4L2_COLORSPACE_SMPTE170M : ((is_hdtv) ? V4L2_COLORSPACE_REC709 : V4L2_COLORSPACE_SRGB))
enum v4l2_xfer_func {
  V4L2_XFER_FUNC_DEFAULT = 0,
  V4L2_XFER_FUNC_709 = 1,
  V4L2_XFER_FUNC_SRGB = 2,
  V4L2_XFER_FUNC_OPRGB = 3,
  V4L2_XFER_FUNC_SMPTE240M = 4,
  V4L2_XFER_FUNC_NONE = 5,
  V4L2_XFER_FUNC_DCI_P3 = 6,
  V4L2_XFER_FUNC_SMPTE2084 = 7,
};
#define V4L2_MAP_XFER_FUNC_DEFAULT(colsp) ((colsp) == V4L2_COLORSPACE_OPRGB ? V4L2_XFER_FUNC_OPRGB : ((colsp) == V4L2_COLORSPACE_SMPTE240M ? V4L2_XFER_FUNC_SMPTE240M : ((colsp) == V4L2_COLORSPACE_DCI_P3 ? V4L2_XFER_FUNC_DCI_P3 : ((colsp) == V4L2_COLORSPACE_RAW ? V4L2_XFER_FUNC_NONE : ((colsp) == V4L2_COLORSPACE_SRGB || (colsp) == V4L2_COLORSPACE_JPEG ? V4L2_XFER_FUNC_SRGB : V4L2_XFER_FUNC_709)))))
enum v4l2_ycbcr_encoding {
  V4L2_YCBCR_ENC_DEFAULT = 0,
  V4L2_YCBCR_ENC_601 = 1,
  V4L2_YCBCR_ENC_709 = 2,
  V4L2_YCBCR_ENC_XV601 = 3,
  V4L2_YCBCR_ENC_XV709 = 4,
  V4L2_YCBCR_ENC_SYCC = 5,
  V4L2_YCBCR_ENC_BT2020 = 6,
  V4L2_YCBCR_ENC_BT2020_CONST_LUM = 7,
  V4L2_YCBCR_ENC_SMPTE240M = 8,
};
enum v4l2_hsv_encoding {
  V4L2_HSV_ENC_180 = 128,
  V4L2_HSV_ENC_256 = 129,
};
#define V4L2_MAP_YCBCR_ENC_DEFAULT(colsp) (((colsp) == V4L2_COLORSPACE_REC709 || (colsp) == V4L2_COLORSPACE_DCI_P3) ? V4L2_YCBCR_ENC_709 : ((colsp) == V4L2_COLORSPACE_BT2020 ? V4L2_YCBCR_ENC_BT2020 : ((colsp) == V4L2_COLORSPACE_SMPTE240M ? V4L2_YCBCR_ENC_SMPTE240M : V4L2_YCBCR_ENC_601)))
enum v4l2_quantization {
  V4L2_QUANTIZATION_DEFAULT = 0,
  V4L2_QUANTIZATION_FULL_RANGE = 1,
  V4L2_QUANTIZATION_LIM_RANGE = 2,
};
#define V4L2_MAP_QUANTIZATION_DEFAULT(is_rgb_or_hsv,colsp,ycbcr_enc) (((is_rgb_or_hsv) || (colsp) == V4L2_COLORSPACE_JPEG) ? V4L2_QUANTIZATION_FULL_RANGE : V4L2_QUANTIZATION_LIM_RANGE)
#define V4L2_COLORSPACE_ADOBERGB V4L2_COLORSPACE_OPRGB
#define V4L2_XFER_FUNC_ADOBERGB V4L2_XFER_FUNC_OPRGB
enum v4l2_priority {
  V4L2_PRIORITY_UNSET = 0,
  V4L2_PRIORITY_BACKGROUND = 1,
  V4L2_PRIORITY_INTERACTIVE = 2,
  V4L2_PRIORITY_RECORD = 3,
  V4L2_PRIORITY_DEFAULT = V4L2_PRIORITY_INTERACTIVE,
};
struct v4l2_rect {
  __s32 left;
  __s32 top;
  __u32 width;
  __u32 height;
};
struct v4l2_fract {
  __u32 numerator;
  __u32 denominator;
};
struct v4l2_area {
  __u32 width;
  __u32 height;
};
struct v4l2_capability {
  __u8 driver[16];
  __u8 card[32];
  __u8 bus_info[32];
  __u32 version;
  __u32 capabilities;
  __u32 device_caps;
  __u32 reserved[3];
};
#define V4L2_CAP_VIDEO_CAPTURE 0x00000001
#define V4L2_CAP_VIDEO_OUTPUT 0x00000002
#define V4L2_CAP_VIDEO_OVERLAY 0x00000004
#define V4L2_CAP_VBI_CAPTURE 0x00000010
#define V4L2_CAP_VBI_OUTPUT 0x00000020
#define V4L2_CAP_SLICED_VBI_CAPTURE 0x00000040
#define V4L2_CAP_SLICED_VBI_OUTPUT 0x00000080
#define V4L2_CAP_RDS_CAPTURE 0x00000100
#define V4L2_CAP_VIDEO_OUTPUT_OVERLAY 0x00000200
#define V4L2_CAP_HW_FREQ_SEEK 0x00000400
#define V4L2_CAP_RDS_OUTPUT 0x00000800
#define V4L2_CAP_VIDEO_CAPTURE_MPLANE 0x00001000
#define V4L2_CAP_VIDEO_OUTPUT_MPLANE 0x00002000
#define V4L2_CAP_VIDEO_M2M_MPLANE 0x00004000
#define V4L2_CAP_VIDEO_M2M 0x00008000
#define V4L2_CAP_TUNER 0x00010000
#define V4L2_CAP_AUDIO 0x00020000
#define V4L2_CAP_RADIO 0x00040000
#define V4L2_CAP_MODULATOR 0x00080000
#define V4L2_CAP_SDR_CAPTURE 0x00100000
#define V4L2_CAP_EXT_PIX_FORMAT 0x00200000
#define V4L2_CAP_SDR_OUTPUT 0x00400000
#define V4L2_CAP_META_CAPTURE 0x00800000
#define V4L2_CAP_READWRITE 0x01000000
#define V4L2_CAP_ASYNCIO 0x02000000
#define V4L2_CAP_STREAMING 0x04000000
#define V4L2_CAP_META_OUTPUT 0x08000000
#define V4L2_CAP_TOUCH 0x10000000
#define V4L2_CAP_IO_MC 0x20000000
#define V4L2_CAP_DEVICE_CAPS 0x80000000
struct v4l2_pix_format {
  __u32 width;
  __u32 height;
  __u32 pixelformat;
  __u32 field;
  __u32 bytesperline;
  __u32 sizeimage;
  __u32 colorspace;
  __u32 priv;
  __u32 flags;
  union {
    __u32 ycbcr_enc;
    __u32 hsv_enc;
  };
  __u32 quantization;
  __u32 xfer_func;
};
#define V4L2_PIX_FMT_RGB332 v4l2_fourcc('R', 'G', 'B', '1')
#define V4L2_PIX_FMT_RGB444 v4l2_fourcc('R', '4', '4', '4')
#define V4L2_PIX_FMT_ARGB444 v4l2_fourcc('A', 'R', '1', '2')
#define V4L2_PIX_FMT_XRGB444 v4l2_fourcc('X', 'R', '1', '2')
#define V4L2_PIX_FMT_RGBA444 v4l2_fourcc('R', 'A', '1', '2')
#define V4L2_PIX_FMT_RGBX444 v4l2_fourcc('R', 'X', '1', '2')
#define V4L2_PIX_FMT_ABGR444 v4l2_fourcc('A', 'B', '1', '2')
#define V4L2_PIX_FMT_XBGR444 v4l2_fourcc('X', 'B', '1', '2')
#define V4L2_PIX_FMT_BGRA444 v4l2_fourcc('G', 'A', '1', '2')
#define V4L2_PIX_FMT_BGRX444 v4l2_fourcc('B', 'X', '1', '2')
#define V4L2_PIX_FMT_RGB555 v4l2_fourcc('R', 'G', 'B', 'O')
#define V4L2_PIX_FMT_ARGB555 v4l2_fourcc('A', 'R', '1', '5')
#define V4L2_PIX_FMT_XRGB555 v4l2_fourcc('X', 'R', '1', '5')
#define V4L2_PIX_FMT_RGBA555 v4l2_fourcc('R', 'A', '1', '5')
#define V4L2_PIX_FMT_RGBX555 v4l2_fourcc('R', 'X', '1', '5')
#define V4L2_PIX_FMT_ABGR555 v4l2_fourcc('A', 'B', '1', '5')
#define V4L2_PIX_FMT_XBGR555 v4l2_fourcc('X', 'B', '1', '5')
#define V4L2_PIX_FMT_BGRA555 v4l2_fourcc('B', 'A', '1', '5')
#define V4L2_PIX_FMT_BGRX555 v4l2_fourcc('B', 'X', '1', '5')
#define V4L2_PIX_FMT_RGB565 v4l2_fourcc('R', 'G', 'B', 'P')
#define V4L2_PIX_FMT_RGB555X v4l2_fourcc('R', 'G', 'B', 'Q')
#define V4L2_PIX_FMT_ARGB555X v4l2_fourcc_be('A', 'R', '1', '5')
#define V4L2_PIX_FMT_XRGB555X v4l2_fourcc_be('X', 'R', '1', '5')
#define V4L2_PIX_FMT_RGB565X v4l2_fourcc('R', 'G', 'B', 'R')
#define V4L2_PIX_FMT_BGR666 v4l2_fourcc('B', 'G', 'R', 'H')
#define V4L2_PIX_FMT_BGR24 v4l2_fourcc('B', 'G', 'R', '3')
#define V4L2_PIX_FMT_RGB24 v4l2_fourcc('R', 'G', 'B', '3')
#define V4L2_PIX_FMT_BGR32 v4l2_fourcc('B', 'G', 'R', '4')
#define V4L2_PIX_FMT_ABGR32 v4l2_fourcc('A', 'R', '2', '4')
#define V4L2_PIX_FMT_XBGR32 v4l2_fourcc('X', 'R', '2', '4')
#define V4L2_PIX_FMT_BGRA32 v4l2_fourcc('R', 'A', '2', '4')
#define V4L2_PIX_FMT_BGRX32 v4l2_fourcc('R', 'X', '2', '4')
#define V4L2_PIX_FMT_RGB32 v4l2_fourcc('R', 'G', 'B', '4')
#define V4L2_PIX_FMT_RGBA32 v4l2_fourcc('A', 'B', '2', '4')
#define V4L2_PIX_FMT_RGBX32 v4l2_fourcc('X', 'B', '2', '4')
#define V4L2_PIX_FMT_ARGB32 v4l2_fourcc('B', 'A', '2', '4')
#define V4L2_PIX_FMT_XRGB32 v4l2_fourcc('B', 'X', '2', '4')
#define V4L2_PIX_FMT_GREY v4l2_fourcc('G', 'R', 'E', 'Y')
#define V4L2_PIX_FMT_Y4 v4l2_fourcc('Y', '0', '4', ' ')
#define V4L2_PIX_FMT_Y6 v4l2_fourcc('Y', '0', '6', ' ')
#define V4L2_PIX_FMT_Y10 v4l2_fourcc('Y', '1', '0', ' ')
#define V4L2_PIX_FMT_Y12 v4l2_fourcc('Y', '1', '2', ' ')
#define V4L2_PIX_FMT_Y14 v4l2_fourcc('Y', '1', '4', ' ')
#define V4L2_PIX_FMT_Y16 v4l2_fourcc('Y', '1', '6', ' ')
#define V4L2_PIX_FMT_Y16_BE v4l2_fourcc_be('Y', '1', '6', ' ')
#define V4L2_PIX_FMT_Y10BPACK v4l2_fourcc('Y', '1', '0', 'B')
#define V4L2_PIX_FMT_Y10P v4l2_fourcc('Y', '1', '0', 'P')
#define V4L2_PIX_FMT_PAL8 v4l2_fourcc('P', 'A', 'L', '8')
#define V4L2_PIX_FMT_UV8 v4l2_fourcc('U', 'V', '8', ' ')
#define V4L2_PIX_FMT_YUYV v4l2_fourcc('Y', 'U', 'Y', 'V')
#define V4L2_PIX_FMT_YYUV v4l2_fourcc('Y', 'Y', 'U', 'V')
#define V4L2_PIX_FMT_YVYU v4l2_fourcc('Y', 'V', 'Y', 'U')
#define V4L2_PIX_FMT_UYVY v4l2_fourcc('U', 'Y', 'V', 'Y')
#define V4L2_PIX_FMT_VYUY v4l2_fourcc('V', 'Y', 'U', 'Y')
#define V4L2_PIX_FMT_Y41P v4l2_fourcc('Y', '4', '1', 'P')
#define V4L2_PIX_FMT_YUV444 v4l2_fourcc('Y', '4', '4', '4')
#define V4L2_PIX_FMT_YUV555 v4l2_fourcc('Y', 'U', 'V', 'O')
#define V4L2_PIX_FMT_YUV565 v4l2_fourcc('Y', 'U', 'V', 'P')
#define V4L2_PIX_FMT_YUV32 v4l2_fourcc('Y', 'U', 'V', '4')
#define V4L2_PIX_FMT_AYUV32 v4l2_fourcc('A', 'Y', 'U', 'V')
#define V4L2_PIX_FMT_XYUV32 v4l2_fourcc('X', 'Y', 'U', 'V')
#define V4L2_PIX_FMT_VUYA32 v4l2_fourcc('V', 'U', 'Y', 'A')
#define V4L2_PIX_FMT_VUYX32 v4l2_fourcc('V', 'U', 'Y', 'X')
#define V4L2_PIX_FMT_HI240 v4l2_fourcc('H', 'I', '2', '4')
#define V4L2_PIX_FMT_HM12 v4l2_fourcc('H', 'M', '1', '2')
#define V4L2_PIX_FMT_M420 v4l2_fourcc('M', '4', '2', '0')
#define V4L2_PIX_FMT_NV12 v4l2_fourcc('N', 'V', '1', '2')
#define V4L2_PIX_FMT_NV21 v4l2_fourcc('N', 'V', '2', '1')
#define V4L2_PIX_FMT_NV16 v4l2_fourcc('N', 'V', '1', '6')
#define V4L2_PIX_FMT_NV61 v4l2_fourcc('N', 'V', '6', '1')
#define V4L2_PIX_FMT_NV24 v4l2_fourcc('N', 'V', '2', '4')
#define V4L2_PIX_FMT_NV42 v4l2_fourcc('N', 'V', '4', '2')
#define V4L2_PIX_FMT_NV12M v4l2_fourcc('N', 'M', '1', '2')
#define V4L2_PIX_FMT_NV21M v4l2_fourcc('N', 'M', '2', '1')
#define V4L2_PIX_FMT_NV16M v4l2_fourcc('N', 'M', '1', '6')
#define V4L2_PIX_FMT_NV61M v4l2_fourcc('N', 'M', '6', '1')
#define V4L2_PIX_FMT_NV12MT v4l2_fourcc('T', 'M', '1', '2')
#define V4L2_PIX_FMT_NV12MT_16X16 v4l2_fourcc('V', 'M', '1', '2')
#define V4L2_PIX_FMT_YUV410 v4l2_fourcc('Y', 'U', 'V', '9')
#define V4L2_PIX_FMT_YVU410 v4l2_fourcc('Y', 'V', 'U', '9')
#define V4L2_PIX_FMT_YUV411P v4l2_fourcc('4', '1', '1', 'P')
#define V4L2_PIX_FMT_YUV420 v4l2_fourcc('Y', 'U', '1', '2')
#define V4L2_PIX_FMT_YVU420 v4l2_fourcc('Y', 'V', '1', '2')
#define V4L2_PIX_FMT_YUV422P v4l2_fourcc('4', '2', '2', 'P')
#define V4L2_PIX_FMT_YUV420M v4l2_fourcc('Y', 'M', '1', '2')
#define V4L2_PIX_FMT_YVU420M v4l2_fourcc('Y', 'M', '2', '1')
#define V4L2_PIX_FMT_YUV422M v4l2_fourcc('Y', 'M', '1', '6')
#define V4L2_PIX_FMT_YVU422M v4l2_fourcc('Y', 'M', '6', '1')
#define V4L2_PIX_FMT_YUV444M v4l2_fourcc('Y', 'M', '2', '4')
#define V4L2_PIX_FMT_YVU444M v4l2_fourcc('Y', 'M', '4', '2')
#define V4L2_PIX_FMT_SBGGR8 v4l2_fourcc('B', 'A', '8', '1')
#define V4L2_PIX_FMT_SGBRG8 v4l2_fourcc('G', 'B', 'R', 'G')
#define V4L2_PIX_FMT_SGRBG8 v4l2_fourcc('G', 'R', 'B', 'G')
#define V4L2_PIX_FMT_SRGGB8 v4l2_fourcc('R', 'G', 'G', 'B')
#define V4L2_PIX_FMT_SBGGR10 v4l2_fourcc('B', 'G', '1', '0')
#define V4L2_PIX_FMT_SGBRG10 v4l2_fourcc('G', 'B', '1', '0')
#define V4L2_PIX_FMT_SGRBG10 v4l2_fourcc('B', 'A', '1', '0')
#define V4L2_PIX_FMT_SRGGB10 v4l2_fourcc('R', 'G', '1', '0')
#define V4L2_PIX_FMT_SBGGR10P v4l2_fourcc('p', 'B', 'A', 'A')
#define V4L2_PIX_FMT_SGBRG10P v4l2_fourcc('p', 'G', 'A', 'A')
#define V4L2_PIX_FMT_SGRBG10P v4l2_fourcc('p', 'g', 'A', 'A')
#define V4L2_PIX_FMT_SRGGB10P v4l2_fourcc('p', 'R', 'A', 'A')
#define V4L2_PIX_FMT_SBGGR10ALAW8 v4l2_fourcc('a', 'B', 'A', '8')
#define V4L2_PIX_FMT_SGBRG10ALAW8 v4l2_fourcc('a', 'G', 'A', '8')
#define V4L2_PIX_FMT_SGRBG10ALAW8 v4l2_fourcc('a', 'g', 'A', '8')
#define V4L2_PIX_FMT_SRGGB10ALAW8 v4l2_fourcc('a', 'R', 'A', '8')
#define V4L2_PIX_FMT_SBGGR10DPCM8 v4l2_fourcc('b', 'B', 'A', '8')
#define V4L2_PIX_FMT_SGBRG10DPCM8 v4l2_fourcc('b', 'G', 'A', '8')
#define V4L2_PIX_FMT_SGRBG10DPCM8 v4l2_fourcc('B', 'D', '1', '0')
#define V4L2_PIX_FMT_SRGGB10DPCM8 v4l2_fourcc('b', 'R', 'A', '8')
#define V4L2_PIX_FMT_SBGGR12 v4l2_fourcc('B', 'G', '1', '2')
#define V4L2_PIX_FMT_SGBRG12 v4l2_fourcc('G', 'B', '1', '2')
#define V4L2_PIX_FMT_SGRBG12 v4l2_fourcc('B', 'A', '1', '2')
#define V4L2_PIX_FMT_SRGGB12 v4l2_fourcc('R', 'G', '1', '2')
#define V4L2_PIX_FMT_SBGGR12P v4l2_fourcc('p', 'B', 'C', 'C')
#define V4L2_PIX_FMT_SGBRG12P v4l2_fourcc('p', 'G', 'C', 'C')
#define V4L2_PIX_FMT_SGRBG12P v4l2_fourcc('p', 'g', 'C', 'C')
#define V4L2_PIX_FMT_SRGGB12P v4l2_fourcc('p', 'R', 'C', 'C')
#define V4L2_PIX_FMT_SBGGR14 v4l2_fourcc('B', 'G', '1', '4')
#define V4L2_PIX_FMT_SGBRG14 v4l2_fourcc('G', 'B', '1', '4')
#define V4L2_PIX_FMT_SGRBG14 v4l2_fourcc('G', 'R', '1', '4')
#define V4L2_PIX_FMT_SRGGB14 v4l2_fourcc('R', 'G', '1', '4')
#define V4L2_PIX_FMT_SBGGR14P v4l2_fourcc('p', 'B', 'E', 'E')
#define V4L2_PIX_FMT_SGBRG14P v4l2_fourcc('p', 'G', 'E', 'E')
#define V4L2_PIX_FMT_SGRBG14P v4l2_fourcc('p', 'g', 'E', 'E')
#define V4L2_PIX_FMT_SRGGB14P v4l2_fourcc('p', 'R', 'E', 'E')
#define V4L2_PIX_FMT_SBGGR16 v4l2_fourcc('B', 'Y', 'R', '2')
#define V4L2_PIX_FMT_SGBRG16 v4l2_fourcc('G', 'B', '1', '6')
#define V4L2_PIX_FMT_SGRBG16 v4l2_fourcc('G', 'R', '1', '6')
#define V4L2_PIX_FMT_SRGGB16 v4l2_fourcc('R', 'G', '1', '6')
#define V4L2_PIX_FMT_HSV24 v4l2_fourcc('H', 'S', 'V', '3')
#define V4L2_PIX_FMT_HSV32 v4l2_fourcc('H', 'S', 'V', '4')
#define V4L2_PIX_FMT_MJPEG v4l2_fourcc('M', 'J', 'P', 'G')
#define V4L2_PIX_FMT_JPEG v4l2_fourcc('J', 'P', 'E', 'G')
#define V4L2_PIX_FMT_DV v4l2_fourcc('d', 'v', 's', 'd')
#define V4L2_PIX_FMT_MPEG v4l2_fourcc('M', 'P', 'E', 'G')
#define V4L2_PIX_FMT_H264 v4l2_fourcc('H', '2', '6', '4')
#define V4L2_PIX_FMT_H264_NO_SC v4l2_fourcc('A', 'V', 'C', '1')
#define V4L2_PIX_FMT_H264_MVC v4l2_fourcc('M', '2', '6', '4')
#define V4L2_PIX_FMT_H263 v4l2_fourcc('H', '2', '6', '3')
#define V4L2_PIX_FMT_MPEG1 v4l2_fourcc('M', 'P', 'G', '1')
#define V4L2_PIX_FMT_MPEG2 v4l2_fourcc('M', 'P', 'G', '2')
#define V4L2_PIX_FMT_MPEG2_SLICE v4l2_fourcc('M', 'G', '2', 'S')
#define V4L2_PIX_FMT_MPEG4 v4l2_fourcc('M', 'P', 'G', '4')
#define V4L2_PIX_FMT_XVID v4l2_fourcc('X', 'V', 'I', 'D')
#define V4L2_PIX_FMT_VC1_ANNEX_G v4l2_fourcc('V', 'C', '1', 'G')
#define V4L2_PIX_FMT_VC1_ANNEX_L v4l2_fourcc('V', 'C', '1', 'L')
#define V4L2_PIX_FMT_VP8 v4l2_fourcc('V', 'P', '8', '0')
#define V4L2_PIX_FMT_VP9 v4l2_fourcc('V', 'P', '9', '0')
#define V4L2_PIX_FMT_HEVC v4l2_fourcc('H', 'E', 'V', 'C')
#define V4L2_PIX_FMT_FWHT v4l2_fourcc('F', 'W', 'H', 'T')
#define V4L2_PIX_FMT_FWHT_STATELESS v4l2_fourcc('S', 'F', 'W', 'H')
#define V4L2_PIX_FMT_CPIA1 v4l2_fourcc('C', 'P', 'I', 'A')
#define V4L2_PIX_FMT_WNVA v4l2_fourcc('W', 'N', 'V', 'A')
#define V4L2_PIX_FMT_SN9C10X v4l2_fourcc('S', '9', '1', '0')
#define V4L2_PIX_FMT_SN9C20X_I420 v4l2_fourcc('S', '9', '2', '0')
#define V4L2_PIX_FMT_PWC1 v4l2_fourcc('P', 'W', 'C', '1')
#define V4L2_PIX_FMT_PWC2 v4l2_fourcc('P', 'W', 'C', '2')
#define V4L2_PIX_FMT_ET61X251 v4l2_fourcc('E', '6', '2', '5')
#define V4L2_PIX_FMT_SPCA501 v4l2_fourcc('S', '5', '0', '1')
#define V4L2_PIX_FMT_SPCA505 v4l2_fourcc('S', '5', '0', '5')
#define V4L2_PIX_FMT_SPCA508 v4l2_fourcc('S', '5', '0', '8')
#define V4L2_PIX_FMT_SPCA561 v4l2_fourcc('S', '5', '6', '1')
#define V4L2_PIX_FMT_PAC207 v4l2_fourcc('P', '2', '0', '7')
#define V4L2_PIX_FMT_MR97310A v4l2_fourcc('M', '3', '1', '0')
#define V4L2_PIX_FMT_JL2005BCD v4l2_fourcc('J', 'L', '2', '0')
#define V4L2_PIX_FMT_SN9C2028 v4l2_fourcc('S', 'O', 'N', 'X')
#define V4L2_PIX_FMT_SQ905C v4l2_fourcc('9', '0', '5', 'C')
#define V4L2_PIX_FMT_PJPG v4l2_fourcc('P', 'J', 'P', 'G')
#define V4L2_PIX_FMT_OV511 v4l2_fourcc('O', '5', '1', '1')
#define V4L2_PIX_FMT_OV518 v4l2_fourcc('O', '5', '1', '8')
#define V4L2_PIX_FMT_STV0680 v4l2_fourcc('S', '6', '8', '0')
#define V4L2_PIX_FMT_TM6000 v4l2_fourcc('T', 'M', '6', '0')
#define V4L2_PIX_FMT_CIT_YYVYUY v4l2_fourcc('C', 'I', 'T', 'V')
#define V4L2_PIX_FMT_KONICA420 v4l2_fourcc('K', 'O', 'N', 'I')
#define V4L2_PIX_FMT_JPGL v4l2_fourcc('J', 'P', 'G', 'L')
#define V4L2_PIX_FMT_SE401 v4l2_fourcc('S', '4', '0', '1')
#define V4L2_PIX_FMT_S5C_UYVY_JPG v4l2_fourcc('S', '5', 'C', 'I')
#define V4L2_PIX_FMT_Y8I v4l2_fourcc('Y', '8', 'I', ' ')
#define V4L2_PIX_FMT_Y12I v4l2_fourcc('Y', '1', '2', 'I')
#define V4L2_PIX_FMT_Z16 v4l2_fourcc('Z', '1', '6', ' ')
#define V4L2_PIX_FMT_MT21C v4l2_fourcc('M', 'T', '2', '1')
#define V4L2_PIX_FMT_INZI v4l2_fourcc('I', 'N', 'Z', 'I')
#define V4L2_PIX_FMT_SUNXI_TILED_NV12 v4l2_fourcc('S', 'T', '1', '2')
#define V4L2_PIX_FMT_CNF4 v4l2_fourcc('C', 'N', 'F', '4')
#define V4L2_PIX_FMT_IPU3_SBGGR10 v4l2_fourcc('i', 'p', '3', 'b')
#define V4L2_PIX_FMT_IPU3_SGBRG10 v4l2_fourcc('i', 'p', '3', 'g')
#define V4L2_PIX_FMT_IPU3_SGRBG10 v4l2_fourcc('i', 'p', '3', 'G')
#define V4L2_PIX_FMT_IPU3_SRGGB10 v4l2_fourcc('i', 'p', '3', 'r')
#define V4L2_SDR_FMT_CU8 v4l2_fourcc('C', 'U', '0', '8')
#define V4L2_SDR_FMT_CU16LE v4l2_fourcc('C', 'U', '1', '6')
#define V4L2_SDR_FMT_CS8 v4l2_fourcc('C', 'S', '0', '8')
#define V4L2_SDR_FMT_CS14LE v4l2_fourcc('C', 'S', '1', '4')
#define V4L2_SDR_FMT_RU12LE v4l2_fourcc('R', 'U', '1', '2')
#define V4L2_SDR_FMT_PCU16BE v4l2_fourcc('P', 'C', '1', '6')
#define V4L2_SDR_FMT_PCU18BE v4l2_fourcc('P', 'C', '1', '8')
#define V4L2_SDR_FMT_PCU20BE v4l2_fourcc('P', 'C', '2', '0')
#define V4L2_TCH_FMT_DELTA_TD16 v4l2_fourcc('T', 'D', '1', '6')
#define V4L2_TCH_FMT_DELTA_TD08 v4l2_fourcc('T', 'D', '0', '8')
#define V4L2_TCH_FMT_TU16 v4l2_fourcc('T', 'U', '1', '6')
#define V4L2_TCH_FMT_TU08 v4l2_fourcc('T', 'U', '0', '8')
#define V4L2_META_FMT_VSP1_HGO v4l2_fourcc('V', 'S', 'P', 'H')
#define V4L2_META_FMT_VSP1_HGT v4l2_fourcc('V', 'S', 'P', 'T')
#define V4L2_META_FMT_UVC v4l2_fourcc('U', 'V', 'C', 'H')
#define V4L2_META_FMT_D4XX v4l2_fourcc('D', '4', 'X', 'X')
#define V4L2_META_FMT_VIVID v4l2_fourcc('V', 'I', 'V', 'D')
#define V4L2_PIX_FMT_PRIV_MAGIC 0xfeedcafe
#define V4L2_PIX_FMT_FLAG_PREMUL_ALPHA 0x00000001
#define V4L2_PIX_FMT_FLAG_SET_CSC 0x00000002
struct v4l2_fmtdesc {
  __u32 index;
  __u32 type;
  __u32 flags;
  __u8 description[32];
  __u32 pixelformat;
  __u32 mbus_code;
  __u32 reserved[3];
};
#define V4L2_FMT_FLAG_COMPRESSED 0x0001
#define V4L2_FMT_FLAG_EMULATED 0x0002
#define V4L2_FMT_FLAG_CONTINUOUS_BYTESTREAM 0x0004
#define V4L2_FMT_FLAG_DYN_RESOLUTION 0x0008
#define V4L2_FMT_FLAG_ENC_CAP_FRAME_INTERVAL 0x0010
#define V4L2_FMT_FLAG_CSC_COLORSPACE 0x0020
#define V4L2_FMT_FLAG_CSC_XFER_FUNC 0x0040
#define V4L2_FMT_FLAG_CSC_YCBCR_ENC 0x0080
#define V4L2_FMT_FLAG_CSC_HSV_ENC V4L2_FMT_FLAG_CSC_YCBCR_ENC
#define V4L2_FMT_FLAG_CSC_QUANTIZATION 0x0100
enum v4l2_frmsizetypes {
  V4L2_FRMSIZE_TYPE_DISCRETE = 1,
  V4L2_FRMSIZE_TYPE_CONTINUOUS = 2,
  V4L2_FRMSIZE_TYPE_STEPWISE = 3,
};
struct v4l2_frmsize_discrete {
  __u32 width;
  __u32 height;
};
struct v4l2_frmsize_stepwise {
  __u32 min_width;
  __u32 max_width;
  __u32 step_width;
  __u32 min_height;
  __u32 max_height;
  __u32 step_height;
};
struct v4l2_frmsizeenum {
  __u32 index;
  __u32 pixel_format;
  __u32 type;
  union {
    struct v4l2_frmsize_discrete discrete;
    struct v4l2_frmsize_stepwise stepwise;
  };
  __u32 reserved[2];
};
enum v4l2_frmivaltypes {
  V4L2_FRMIVAL_TYPE_DISCRETE = 1,
  V4L2_FRMIVAL_TYPE_CONTINUOUS = 2,
  V4L2_FRMIVAL_TYPE_STEPWISE = 3,
};
struct v4l2_frmival_stepwise {
  struct v4l2_fract min;
  struct v4l2_fract max;
  struct v4l2_fract step;
};
struct v4l2_frmivalenum {
  __u32 index;
  __u32 pixel_format;
  __u32 width;
  __u32 height;
  __u32 type;
  union {
    struct v4l2_fract discrete;
    struct v4l2_frmival_stepwise stepwise;
  };
  __u32 reserved[2];
};
struct v4l2_timecode {
  __u32 type;
  __u32 flags;
  __u8 frames;
  __u8 seconds;
  __u8 minutes;
  __u8 hours;
  __u8 userbits[4];
};
#define V4L2_TC_TYPE_24FPS 1
#define V4L2_TC_TYPE_25FPS 2
#define V4L2_TC_TYPE_30FPS 3
#define V4L2_TC_TYPE_50FPS 4
#define V4L2_TC_TYPE_60FPS 5
#define V4L2_TC_FLAG_DROPFRAME 0x0001
#define V4L2_TC_FLAG_COLORFRAME 0x0002
#define V4L2_TC_USERBITS_field 0x000C
#define V4L2_TC_USERBITS_USERDEFINED 0x0000
#define V4L2_TC_USERBITS_8BITCHARS 0x0008
struct v4l2_jpegcompression {
  int quality;
  int APPn;
  int APP_len;
  char APP_data[60];
  int COM_len;
  char COM_data[60];
  __u32 jpeg_markers;
#define V4L2_JPEG_MARKER_DHT (1 << 3)
#define V4L2_JPEG_MARKER_DQT (1 << 4)
#define V4L2_JPEG_MARKER_DRI (1 << 5)
#define V4L2_JPEG_MARKER_COM (1 << 6)
#define V4L2_JPEG_MARKER_APP (1 << 7)
};
struct v4l2_requestbuffers {
  __u32 count;
  __u32 type;
  __u32 memory;
  __u32 capabilities;
  __u32 reserved[1];
};
#define V4L2_BUF_CAP_SUPPORTS_MMAP (1 << 0)
#define V4L2_BUF_CAP_SUPPORTS_USERPTR (1 << 1)
#define V4L2_BUF_CAP_SUPPORTS_DMABUF (1 << 2)
#define V4L2_BUF_CAP_SUPPORTS_REQUESTS (1 << 3)
#define V4L2_BUF_CAP_SUPPORTS_ORPHANED_BUFS (1 << 4)
#define V4L2_BUF_CAP_SUPPORTS_M2M_HOLD_CAPTURE_BUF (1 << 5)
#define V4L2_BUF_CAP_SUPPORTS_MMAP_CACHE_HINTS (1 << 6)
struct v4l2_plane {
  __u32 bytesused;
  __u32 length;
  union {
    __u32 mem_offset;
    unsigned long userptr;
    __s32 fd;
  } m;
  __u32 data_offset;
  __u32 reserved[11];
};
struct v4l2_buffer {
  __u32 index;
  __u32 type;
  __u32 bytesused;
  __u32 flags;
  __u32 field;
  struct timeval timestamp;
  struct v4l2_timecode timecode;
  __u32 sequence;
  __u32 memory;
  union {
    __u32 offset;
    unsigned long userptr;
    struct v4l2_plane * planes;
    __s32 fd;
  } m;
  __u32 length;
  __u32 reserved2;
  union {
    __s32 request_fd;
    __u32 reserved;
  };
};
#define V4L2_BUF_FLAG_MAPPED 0x00000001
#define V4L2_BUF_FLAG_QUEUED 0x00000002
#define V4L2_BUF_FLAG_DONE 0x00000004
#define V4L2_BUF_FLAG_KEYFRAME 0x00000008
#define V4L2_BUF_FLAG_PFRAME 0x00000010
#define V4L2_BUF_FLAG_BFRAME 0x00000020
#define V4L2_BUF_FLAG_ERROR 0x00000040
#define V4L2_BUF_FLAG_IN_REQUEST 0x00000080
#define V4L2_BUF_FLAG_TIMECODE 0x00000100
#define V4L2_BUF_FLAG_M2M_HOLD_CAPTURE_BUF 0x00000200
#define V4L2_BUF_FLAG_PREPARED 0x00000400
#define V4L2_BUF_FLAG_NO_CACHE_INVALIDATE 0x00000800
#define V4L2_BUF_FLAG_NO_CACHE_CLEAN 0x00001000
#define V4L2_BUF_FLAG_TIMESTAMP_MASK 0x0000e000
#define V4L2_BUF_FLAG_TIMESTAMP_UNKNOWN 0x00000000
#define V4L2_BUF_FLAG_TIMESTAMP_MONOTONIC 0x00002000
#define V4L2_BUF_FLAG_TIMESTAMP_COPY 0x00004000
#define V4L2_BUF_FLAG_TSTAMP_SRC_MASK 0x00070000
#define V4L2_BUF_FLAG_TSTAMP_SRC_EOF 0x00000000
#define V4L2_BUF_FLAG_TSTAMP_SRC_SOE 0x00010000
#define V4L2_BUF_FLAG_LAST 0x00100000
#define V4L2_BUF_FLAG_REQUEST_FD 0x00800000
struct v4l2_exportbuffer {
  __u32 type;
  __u32 index;
  __u32 plane;
  __u32 flags;
  __s32 fd;
  __u32 reserved[11];
};
struct v4l2_framebuffer {
  __u32 capability;
  __u32 flags;
  void * base;
  struct {
    __u32 width;
    __u32 height;
    __u32 pixelformat;
    __u32 field;
    __u32 bytesperline;
    __u32 sizeimage;
    __u32 colorspace;
    __u32 priv;
  } fmt;
};
#define V4L2_FBUF_CAP_EXTERNOVERLAY 0x0001
#define V4L2_FBUF_CAP_CHROMAKEY 0x0002
#define V4L2_FBUF_CAP_LIST_CLIPPING 0x0004
#define V4L2_FBUF_CAP_BITMAP_CLIPPING 0x0008
#define V4L2_FBUF_CAP_LOCAL_ALPHA 0x0010
#define V4L2_FBUF_CAP_GLOBAL_ALPHA 0x0020
#define V4L2_FBUF_CAP_LOCAL_INV_ALPHA 0x0040
#define V4L2_FBUF_CAP_SRC_CHROMAKEY 0x0080
#define V4L2_FBUF_FLAG_PRIMARY 0x0001
#define V4L2_FBUF_FLAG_OVERLAY 0x0002
#define V4L2_FBUF_FLAG_CHROMAKEY 0x0004
#define V4L2_FBUF_FLAG_LOCAL_ALPHA 0x0008
#define V4L2_FBUF_FLAG_GLOBAL_ALPHA 0x0010
#define V4L2_FBUF_FLAG_LOCAL_INV_ALPHA 0x0020
#define V4L2_FBUF_FLAG_SRC_CHROMAKEY 0x0040
struct v4l2_clip {
  struct v4l2_rect c;
  struct v4l2_clip __user * next;
};
struct v4l2_window {
  struct v4l2_rect w;
  __u32 field;
  __u32 chromakey;
  struct v4l2_clip __user * clips;
  __u32 clipcount;
  void __user * bitmap;
  __u8 global_alpha;
};
struct v4l2_captureparm {
  __u32 capability;
  __u32 capturemode;
  struct v4l2_fract timeperframe;
  __u32 extendedmode;
  __u32 readbuffers;
  __u32 reserved[4];
};
#define V4L2_MODE_HIGHQUALITY 0x0001
#define V4L2_CAP_TIMEPERFRAME 0x1000
struct v4l2_outputparm {
  __u32 capability;
  __u32 outputmode;
  struct v4l2_fract timeperframe;
  __u32 extendedmode;
  __u32 writebuffers;
  __u32 reserved[4];
};
struct v4l2_cropcap {
  __u32 type;
  struct v4l2_rect bounds;
  struct v4l2_rect defrect;
  struct v4l2_fract pixelaspect;
};
struct v4l2_crop {
  __u32 type;
  struct v4l2_rect c;
};
struct v4l2_selection {
  __u32 type;
  __u32 target;
  __u32 flags;
  struct v4l2_rect r;
  __u32 reserved[9];
};
typedef __u64 v4l2_std_id;
#define V4L2_STD_PAL_B ((v4l2_std_id) 0x00000001)
#define V4L2_STD_PAL_B1 ((v4l2_std_id) 0x00000002)
#define V4L2_STD_PAL_G ((v4l2_std_id) 0x00000004)
#define V4L2_STD_PAL_H ((v4l2_std_id) 0x00000008)
#define V4L2_STD_PAL_I ((v4l2_std_id) 0x00000010)
#define V4L2_STD_PAL_D ((v4l2_std_id) 0x00000020)
#define V4L2_STD_PAL_D1 ((v4l2_std_id) 0x00000040)
#define V4L2_STD_PAL_K ((v4l2_std_id) 0x00000080)
#define V4L2_STD_PAL_M ((v4l2_std_id) 0x00000100)
#define V4L2_STD_PAL_N ((v4l2_std_id) 0x00000200)
#define V4L2_STD_PAL_Nc ((v4l2_std_id) 0x00000400)
#define V4L2_STD_PAL_60 ((v4l2_std_id) 0x00000800)
#define V4L2_STD_NTSC_M ((v4l2_std_id) 0x00001000)
#define V4L2_STD_NTSC_M_JP ((v4l2_std_id) 0x00002000)
#define V4L2_STD_NTSC_443 ((v4l2_std_id) 0x00004000)
#define V4L2_STD_NTSC_M_KR ((v4l2_std_id) 0x00008000)
#define V4L2_STD_SECAM_B ((v4l2_std_id) 0x00010000)
#define V4L2_STD_SECAM_D ((v4l2_std_id) 0x00020000)
#define V4L2_STD_SECAM_G ((v4l2_std_id) 0x00040000)
#define V4L2_STD_SECAM_H ((v4l2_std_id) 0x00080000)
#define V4L2_STD_SECAM_K ((v4l2_std_id) 0x00100000)
#define V4L2_STD_SECAM_K1 ((v4l2_std_id) 0x00200000)
#define V4L2_STD_SECAM_L ((v4l2_std_id) 0x00400000)
#define V4L2_STD_SECAM_LC ((v4l2_std_id) 0x00800000)
#define V4L2_STD_ATSC_8_VSB ((v4l2_std_id) 0x01000000)
#define V4L2_STD_ATSC_16_VSB ((v4l2_std_id) 0x02000000)
#define V4L2_STD_NTSC (V4L2_STD_NTSC_M | V4L2_STD_NTSC_M_JP | V4L2_STD_NTSC_M_KR)
#define V4L2_STD_SECAM_DK (V4L2_STD_SECAM_D | V4L2_STD_SECAM_K | V4L2_STD_SECAM_K1)
#define V4L2_STD_SECAM (V4L2_STD_SECAM_B | V4L2_STD_SECAM_G | V4L2_STD_SECAM_H | V4L2_STD_SECAM_DK | V4L2_STD_SECAM_L | V4L2_STD_SECAM_LC)
#define V4L2_STD_PAL_BG (V4L2_STD_PAL_B | V4L2_STD_PAL_B1 | V4L2_STD_PAL_G)
#define V4L2_STD_PAL_DK (V4L2_STD_PAL_D | V4L2_STD_PAL_D1 | V4L2_STD_PAL_K)
#define V4L2_STD_PAL (V4L2_STD_PAL_BG | V4L2_STD_PAL_DK | V4L2_STD_PAL_H | V4L2_STD_PAL_I)
#define V4L2_STD_B (V4L2_STD_PAL_B | V4L2_STD_PAL_B1 | V4L2_STD_SECAM_B)
#define V4L2_STD_G (V4L2_STD_PAL_G | V4L2_STD_SECAM_G)
#define V4L2_STD_H (V4L2_STD_PAL_H | V4L2_STD_SECAM_H)
#define V4L2_STD_L (V4L2_STD_SECAM_L | V4L2_STD_SECAM_LC)
#define V4L2_STD_GH (V4L2_STD_G | V4L2_STD_H)
#define V4L2_STD_DK (V4L2_STD_PAL_DK | V4L2_STD_SECAM_DK)
#define V4L2_STD_BG (V4L2_STD_B | V4L2_STD_G)
#define V4L2_STD_MN (V4L2_STD_PAL_M | V4L2_STD_PAL_N | V4L2_STD_PAL_Nc | V4L2_STD_NTSC)
#define V4L2_STD_MTS (V4L2_STD_NTSC_M | V4L2_STD_PAL_M | V4L2_STD_PAL_N | V4L2_STD_PAL_Nc)
#define V4L2_STD_525_60 (V4L2_STD_PAL_M | V4L2_STD_PAL_60 | V4L2_STD_NTSC | V4L2_STD_NTSC_443)
#define V4L2_STD_625_50 (V4L2_STD_PAL | V4L2_STD_PAL_N | V4L2_STD_PAL_Nc | V4L2_STD_SECAM)
#define V4L2_STD_ATSC (V4L2_STD_ATSC_8_VSB | V4L2_STD_ATSC_16_VSB)
#define V4L2_STD_UNKNOWN 0
#define V4L2_STD_ALL (V4L2_STD_525_60 | V4L2_STD_625_50)
struct v4l2_standard {
  __u32 index;
  v4l2_std_id id;
  __u8 name[24];
  struct v4l2_fract frameperiod;
  __u32 framelines;
  __u32 reserved[4];
};
struct v4l2_bt_timings {
  __u32 width;
  __u32 height;
  __u32 interlaced;
  __u32 polarities;
  __u64 pixelclock;
  __u32 hfrontporch;
  __u32 hsync;
  __u32 hbackporch;
  __u32 vfrontporch;
  __u32 vsync;
  __u32 vbackporch;
  __u32 il_vfrontporch;
  __u32 il_vsync;
  __u32 il_vbackporch;
  __u32 standards;
  __u32 flags;
  struct v4l2_fract picture_aspect;
  __u8 cea861_vic;
  __u8 hdmi_vic;
  __u8 reserved[46];
} __attribute__((packed));
#define V4L2_DV_PROGRESSIVE 0
#define V4L2_DV_INTERLACED 1
#define V4L2_DV_VSYNC_POS_POL 0x00000001
#define V4L2_DV_HSYNC_POS_POL 0x00000002
#define V4L2_DV_BT_STD_CEA861 (1 << 0)
#define V4L2_DV_BT_STD_DMT (1 << 1)
#define V4L2_DV_BT_STD_CVT (1 << 2)
#define V4L2_DV_BT_STD_GTF (1 << 3)
#define V4L2_DV_BT_STD_SDI (1 << 4)
#define V4L2_DV_FL_REDUCED_BLANKING (1 << 0)
#define V4L2_DV_FL_CAN_REDUCE_FPS (1 << 1)
#define V4L2_DV_FL_REDUCED_FPS (1 << 2)
#define V4L2_DV_FL_HALF_LINE (1 << 3)
#define V4L2_DV_FL_IS_CE_VIDEO (1 << 4)
#define V4L2_DV_FL_FIRST_FIELD_EXTRA_LINE (1 << 5)
#define V4L2_DV_FL_HAS_PICTURE_ASPECT (1 << 6)
#define V4L2_DV_FL_HAS_CEA861_VIC (1 << 7)
#define V4L2_DV_FL_HAS_HDMI_VIC (1 << 8)
#define V4L2_DV_FL_CAN_DETECT_REDUCED_FPS (1 << 9)
#define V4L2_DV_BT_BLANKING_WIDTH(bt) ((bt)->hfrontporch + (bt)->hsync + (bt)->hbackporch)
#define V4L2_DV_BT_FRAME_WIDTH(bt) ((bt)->width + V4L2_DV_BT_BLANKING_WIDTH(bt))
#define V4L2_DV_BT_BLANKING_HEIGHT(bt) ((bt)->vfrontporch + (bt)->vsync + (bt)->vbackporch + (bt)->il_vfrontporch + (bt)->il_vsync + (bt)->il_vbackporch)
#define V4L2_DV_BT_FRAME_HEIGHT(bt) ((bt)->height + V4L2_DV_BT_BLANKING_HEIGHT(bt))
struct v4l2_dv_timings {
  __u32 type;
  union {
    struct v4l2_bt_timings bt;
    __u32 reserved[32];
  };
} __attribute__((packed));
#define V4L2_DV_BT_656_1120 0
struct v4l2_enum_dv_timings {
  __u32 index;
  __u32 pad;
  __u32 reserved[2];
  struct v4l2_dv_timings timings;
};
struct v4l2_bt_timings_cap {
  __u32 min_width;
  __u32 max_width;
  __u32 min_height;
  __u32 max_height;
  __u64 min_pixelclock;
  __u64 max_pixelclock;
  __u32 standards;
  __u32 capabilities;
  __u32 reserved[16];
} __attribute__((packed));
#define V4L2_DV_BT_CAP_INTERLACED (1 << 0)
#define V4L2_DV_BT_CAP_PROGRESSIVE (1 << 1)
#define V4L2_DV_BT_CAP_REDUCED_BLANKING (1 << 2)
#define V4L2_DV_BT_CAP_CUSTOM (1 << 3)
struct v4l2_dv_timings_cap {
  __u32 type;
  __u32 pad;
  __u32 reserved[2];
  union {
    struct v4l2_bt_timings_cap bt;
    __u32 raw_data[32];
  };
};
struct v4l2_input {
  __u32 index;
  __u8 name[32];
  __u32 type;
  __u32 audioset;
  __u32 tuner;
  v4l2_std_id std;
  __u32 status;
  __u32 capabilities;
  __u32 reserved[3];
};
#define V4L2_INPUT_TYPE_TUNER 1
#define V4L2_INPUT_TYPE_CAMERA 2
#define V4L2_INPUT_TYPE_TOUCH 3
#define V4L2_IN_ST_NO_POWER 0x00000001
#define V4L2_IN_ST_NO_SIGNAL 0x00000002
#define V4L2_IN_ST_NO_COLOR 0x00000004
#define V4L2_IN_ST_HFLIP 0x00000010
#define V4L2_IN_ST_VFLIP 0x00000020
#define V4L2_IN_ST_NO_H_LOCK 0x00000100
#define V4L2_IN_ST_COLOR_KILL 0x00000200
#define V4L2_IN_ST_NO_V_LOCK 0x00000400
#define V4L2_IN_ST_NO_STD_LOCK 0x00000800
#define V4L2_IN_ST_NO_SYNC 0x00010000
#define V4L2_IN_ST_NO_EQU 0x00020000
#define V4L2_IN_ST_NO_CARRIER 0x00040000
#define V4L2_IN_ST_MACROVISION 0x01000000
#define V4L2_IN_ST_NO_ACCESS 0x02000000
#define V4L2_IN_ST_VTR 0x04000000
#define V4L2_IN_CAP_DV_TIMINGS 0x00000002
#define V4L2_IN_CAP_CUSTOM_TIMINGS V4L2_IN_CAP_DV_TIMINGS
#define V4L2_IN_CAP_STD 0x00000004
#define V4L2_IN_CAP_NATIVE_SIZE 0x00000008
struct v4l2_output {
  __u32 index;
  __u8 name[32];
  __u32 type;
  __u32 audioset;
  __u32 modulator;
  v4l2_std_id std;
  __u32 capabilities;
  __u32 reserved[3];
};
#define V4L2_OUTPUT_TYPE_MODULATOR 1
#define V4L2_OUTPUT_TYPE_ANALOG 2
#define V4L2_OUTPUT_TYPE_ANALOGVGAOVERLAY 3
#define V4L2_OUT_CAP_DV_TIMINGS 0x00000002
#define V4L2_OUT_CAP_CUSTOM_TIMINGS V4L2_OUT_CAP_DV_TIMINGS
#define V4L2_OUT_CAP_STD 0x00000004
#define V4L2_OUT_CAP_NATIVE_SIZE 0x00000008
struct v4l2_control {
  __u32 id;
  __s32 value;
};
struct v4l2_ext_control {
  __u32 id;
  __u32 size;
  __u32 reserved2[1];
  union {
    __s32 value;
    __s64 value64;
    char __user * string;
    __u8 __user * p_u8;
    __u16 __user * p_u16;
    __u32 __user * p_u32;
    struct v4l2_area __user * p_area;
    void __user * ptr;
  };
} __attribute__((packed));
struct v4l2_ext_controls {
  union {
    __u32 ctrl_class;
    __u32 which;
  };
  __u32 count;
  __u32 error_idx;
  __s32 request_fd;
  __u32 reserved[1];
  struct v4l2_ext_control * controls;
};
#define V4L2_CTRL_ID_MASK (0x0fffffff)
#define V4L2_CTRL_ID2CLASS(id) ((id) & 0x0fff0000UL)
#define V4L2_CTRL_ID2WHICH(id) ((id) & 0x0fff0000UL)
#define V4L2_CTRL_DRIVER_PRIV(id) (((id) & 0xffff) >= 0x1000)
#define V4L2_CTRL_MAX_DIMS (4)
#define V4L2_CTRL_WHICH_CUR_VAL 0
#define V4L2_CTRL_WHICH_DEF_VAL 0x0f000000
#define V4L2_CTRL_WHICH_REQUEST_VAL 0x0f010000
enum v4l2_ctrl_type {
  V4L2_CTRL_TYPE_INTEGER = 1,
  V4L2_CTRL_TYPE_BOOLEAN = 2,
  V4L2_CTRL_TYPE_MENU = 3,
  V4L2_CTRL_TYPE_BUTTON = 4,
  V4L2_CTRL_TYPE_INTEGER64 = 5,
  V4L2_CTRL_TYPE_CTRL_CLASS = 6,
  V4L2_CTRL_TYPE_STRING = 7,
  V4L2_CTRL_TYPE_BITMASK = 8,
  V4L2_CTRL_TYPE_INTEGER_MENU = 9,
  V4L2_CTRL_COMPOUND_TYPES = 0x0100,
  V4L2_CTRL_TYPE_U8 = 0x0100,
  V4L2_CTRL_TYPE_U16 = 0x0101,
  V4L2_CTRL_TYPE_U32 = 0x0102,
  V4L2_CTRL_TYPE_AREA = 0x0106,
};
struct v4l2_queryctrl {
  __u32 id;
  __u32 type;
  __u8 name[32];
  __s32 minimum;
  __s32 maximum;
  __s32 step;
  __s32 default_value;
  __u32 flags;
  __u32 reserved[2];
};
struct v4l2_query_ext_ctrl {
  __u32 id;
  __u32 type;
  char name[32];
  __s64 minimum;
  __s64 maximum;
  __u64 step;
  __s64 default_value;
  __u32 flags;
  __u32 elem_size;
  __u32 elems;
  __u32 nr_of_dims;
  __u32 dims[V4L2_CTRL_MAX_DIMS];
  __u32 reserved[32];
};
struct v4l2_querymenu {
  __u32 id;
  __u32 index;
  union {
    __u8 name[32];
    __s64 value;
  };
  __u32 reserved;
} __attribute__((packed));
#define V4L2_CTRL_FLAG_DISABLED 0x0001
#define V4L2_CTRL_FLAG_GRABBED 0x0002
#define V4L2_CTRL_FLAG_READ_ONLY 0x0004
#define V4L2_CTRL_FLAG_UPDATE 0x0008
#define V4L2_CTRL_FLAG_INACTIVE 0x0010
#define V4L2_CTRL_FLAG_SLIDER 0x0020
#define V4L2_CTRL_FLAG_WRITE_ONLY 0x0040
#define V4L2_CTRL_FLAG_VOLATILE 0x0080
#define V4L2_CTRL_FLAG_HAS_PAYLOAD 0x0100
#define V4L2_CTRL_FLAG_EXECUTE_ON_WRITE 0x0200
#define V4L2_CTRL_FLAG_MODIFY_LAYOUT 0x0400
#define V4L2_CTRL_FLAG_NEXT_CTRL 0x80000000
#define V4L2_CTRL_FLAG_NEXT_COMPOUND 0x40000000
#define V4L2_CID_MAX_CTRLS 1024
#define V4L2_CID_PRIVATE_BASE 0x08000000
struct v4l2_tuner {
  __u32 index;
  __u8 name[32];
  __u32 type;
  __u32 capability;
  __u32 rangelow;
  __u32 rangehigh;
  __u32 rxsubchans;
  __u32 audmode;
  __s32 signal;
  __s32 afc;
  __u32 reserved[4];
};
struct v4l2_modulator {
  __u32 index;
  __u8 name[32];
  __u32 capability;
  __u32 rangelow;
  __u32 rangehigh;
  __u32 txsubchans;
  __u32 type;
  __u32 reserved[3];
};
#define V4L2_TUNER_CAP_LOW 0x0001
#define V4L2_TUNER_CAP_NORM 0x0002
#define V4L2_TUNER_CAP_HWSEEK_BOUNDED 0x0004
#define V4L2_TUNER_CAP_HWSEEK_WRAP 0x0008
#define V4L2_TUNER_CAP_STEREO 0x0010
#define V4L2_TUNER_CAP_LANG2 0x0020
#define V4L2_TUNER_CAP_SAP 0x0020
#define V4L2_TUNER_CAP_LANG1 0x0040
#define V4L2_TUNER_CAP_RDS 0x0080
#define V4L2_TUNER_CAP_RDS_BLOCK_IO 0x0100
#define V4L2_TUNER_CAP_RDS_CONTROLS 0x0200
#define V4L2_TUNER_CAP_FREQ_BANDS 0x0400
#define V4L2_TUNER_CAP_HWSEEK_PROG_LIM 0x0800
#define V4L2_TUNER_CAP_1HZ 0x1000
#define V4L2_TUNER_SUB_MONO 0x0001
#define V4L2_TUNER_SUB_STEREO 0x0002
#define V4L2_TUNER_SUB_LANG2 0x0004
#define V4L2_TUNER_SUB_SAP 0x0004
#define V4L2_TUNER_SUB_LANG1 0x0008
#define V4L2_TUNER_SUB_RDS 0x0010
#define V4L2_TUNER_MODE_MONO 0x0000
#define V4L2_TUNER_MODE_STEREO 0x0001
#define V4L2_TUNER_MODE_LANG2 0x0002
#define V4L2_TUNER_MODE_SAP 0x0002
#define V4L2_TUNER_MODE_LANG1 0x0003
#define V4L2_TUNER_MODE_LANG1_LANG2 0x0004
struct v4l2_frequency {
  __u32 tuner;
  __u32 type;
  __u32 frequency;
  __u32 reserved[8];
};
#define V4L2_BAND_MODULATION_VSB (1 << 1)
#define V4L2_BAND_MODULATION_FM (1 << 2)
#define V4L2_BAND_MODULATION_AM (1 << 3)
struct v4l2_frequency_band {
  __u32 tuner;
  __u32 type;
  __u32 index;
  __u32 capability;
  __u32 rangelow;
  __u32 rangehigh;
  __u32 modulation;
  __u32 reserved[9];
};
struct v4l2_hw_freq_seek {
  __u32 tuner;
  __u32 type;
  __u32 seek_upward;
  __u32 wrap_around;
  __u32 spacing;
  __u32 rangelow;
  __u32 rangehigh;
  __u32 reserved[5];
};
struct v4l2_rds_data {
  __u8 lsb;
  __u8 msb;
  __u8 block;
} __attribute__((packed));
#define V4L2_RDS_BLOCK_MSK 0x7
#define V4L2_RDS_BLOCK_A 0
#define V4L2_RDS_BLOCK_B 1
#define V4L2_RDS_BLOCK_C 2
#define V4L2_RDS_BLOCK_D 3
#define V4L2_RDS_BLOCK_C_ALT 4
#define V4L2_RDS_BLOCK_INVALID 7
#define V4L2_RDS_BLOCK_CORRECTED 0x40
#define V4L2_RDS_BLOCK_ERROR 0x80
struct v4l2_audio {
  __u32 index;
  __u8 name[32];
  __u32 capability;
  __u32 mode;
  __u32 reserved[2];
};
#define V4L2_AUDCAP_STEREO 0x00001
#define V4L2_AUDCAP_AVL 0x00002
#define V4L2_AUDMODE_AVL 0x00001
struct v4l2_audioout {
  __u32 index;
  __u8 name[32];
  __u32 capability;
  __u32 mode;
  __u32 reserved[2];
};
#define V4L2_ENC_IDX_FRAME_I (0)
#define V4L2_ENC_IDX_FRAME_P (1)
#define V4L2_ENC_IDX_FRAME_B (2)
#define V4L2_ENC_IDX_FRAME_MASK (0xf)
struct v4l2_enc_idx_entry {
  __u64 offset;
  __u64 pts;
  __u32 length;
  __u32 flags;
  __u32 reserved[2];
};
#define V4L2_ENC_IDX_ENTRIES (64)
struct v4l2_enc_idx {
  __u32 entries;
  __u32 entries_cap;
  __u32 reserved[4];
  struct v4l2_enc_idx_entry entry[V4L2_ENC_IDX_ENTRIES];
};
#define V4L2_ENC_CMD_START (0)
#define V4L2_ENC_CMD_STOP (1)
#define V4L2_ENC_CMD_PAUSE (2)
#define V4L2_ENC_CMD_RESUME (3)
#define V4L2_ENC_CMD_STOP_AT_GOP_END (1 << 0)
struct v4l2_encoder_cmd {
  __u32 cmd;
  __u32 flags;
  union {
    struct {
      __u32 data[8];
    } raw;
  };
};
#define V4L2_DEC_CMD_START (0)
#define V4L2_DEC_CMD_STOP (1)
#define V4L2_DEC_CMD_PAUSE (2)
#define V4L2_DEC_CMD_RESUME (3)
#define V4L2_DEC_CMD_FLUSH (4)
#define V4L2_DEC_CMD_START_MUTE_AUDIO (1 << 0)
#define V4L2_DEC_CMD_PAUSE_TO_BLACK (1 << 0)
#define V4L2_DEC_CMD_STOP_TO_BLACK (1 << 0)
#define V4L2_DEC_CMD_STOP_IMMEDIATELY (1 << 1)
#define V4L2_DEC_START_FMT_NONE (0)
#define V4L2_DEC_START_FMT_GOP (1)
struct v4l2_decoder_cmd {
  __u32 cmd;
  __u32 flags;
  union {
    struct {
      __u64 pts;
    } stop;
    struct {
      __s32 speed;
      __u32 format;
    } start;
    struct {
      __u32 data[16];
    } raw;
  };
};
struct v4l2_vbi_format {
  __u32 sampling_rate;
  __u32 offset;
  __u32 samples_per_line;
  __u32 sample_format;
  __s32 start[2];
  __u32 count[2];
  __u32 flags;
  __u32 reserved[2];
};
#define V4L2_VBI_UNSYNC (1 << 0)
#define V4L2_VBI_INTERLACED (1 << 1)
#define V4L2_VBI_ITU_525_F1_START (1)
#define V4L2_VBI_ITU_525_F2_START (264)
#define V4L2_VBI_ITU_625_F1_START (1)
#define V4L2_VBI_ITU_625_F2_START (314)
struct v4l2_sliced_vbi_format {
  __u16 service_set;
  __u16 service_lines[2][24];
  __u32 io_size;
  __u32 reserved[2];
};
#define V4L2_SLICED_TELETEXT_B (0x0001)
#define V4L2_SLICED_VPS (0x0400)
#define V4L2_SLICED_CAPTION_525 (0x1000)
#define V4L2_SLICED_WSS_625 (0x4000)
#define V4L2_SLICED_VBI_525 (V4L2_SLICED_CAPTION_525)
#define V4L2_SLICED_VBI_625 (V4L2_SLICED_TELETEXT_B | V4L2_SLICED_VPS | V4L2_SLICED_WSS_625)
struct v4l2_sliced_vbi_cap {
  __u16 service_set;
  __u16 service_lines[2][24];
  __u32 type;
  __u32 reserved[3];
};
struct v4l2_sliced_vbi_data {
  __u32 id;
  __u32 field;
  __u32 line;
  __u32 reserved;
  __u8 data[48];
};
#define V4L2_MPEG_VBI_IVTV_TELETEXT_B (1)
#define V4L2_MPEG_VBI_IVTV_CAPTION_525 (4)
#define V4L2_MPEG_VBI_IVTV_WSS_625 (5)
#define V4L2_MPEG_VBI_IVTV_VPS (7)
struct v4l2_mpeg_vbi_itv0_line {
  __u8 id;
  __u8 data[42];
} __attribute__((packed));
struct v4l2_mpeg_vbi_itv0 {
  __le32 linemask[2];
  struct v4l2_mpeg_vbi_itv0_line line[35];
} __attribute__((packed));
struct v4l2_mpeg_vbi_ITV0 {
  struct v4l2_mpeg_vbi_itv0_line line[36];
} __attribute__((packed));
#define V4L2_MPEG_VBI_IVTV_MAGIC0 "itv0"
#define V4L2_MPEG_VBI_IVTV_MAGIC1 "ITV0"
struct v4l2_mpeg_vbi_fmt_ivtv {
  __u8 magic[4];
  union {
    struct v4l2_mpeg_vbi_itv0 itv0;
    struct v4l2_mpeg_vbi_ITV0 ITV0;
  };
} __attribute__((packed));
struct v4l2_plane_pix_format {
  __u32 sizeimage;
  __u32 bytesperline;
  __u16 reserved[6];
} __attribute__((packed));
struct v4l2_pix_format_mplane {
  __u32 width;
  __u32 height;
  __u32 pixelformat;
  __u32 field;
  __u32 colorspace;
  struct v4l2_plane_pix_format plane_fmt[VIDEO_MAX_PLANES];
  __u8 num_planes;
  __u8 flags;
  union {
    __u8 ycbcr_enc;
    __u8 hsv_enc;
  };
  __u8 quantization;
  __u8 xfer_func;
  __u8 reserved[7];
} __attribute__((packed));
struct v4l2_sdr_format {
  __u32 pixelformat;
  __u32 buffersize;
  __u8 reserved[24];
} __attribute__((packed));
struct v4l2_meta_format {
  __u32 dataformat;
  __u32 buffersize;
} __attribute__((packed));
struct v4l2_format {
  __u32 type;
  union {
    struct v4l2_pix_format pix;
    struct v4l2_pix_format_mplane pix_mp;
    struct v4l2_window win;
    struct v4l2_vbi_format vbi;
    struct v4l2_sliced_vbi_format sliced;
    struct v4l2_sdr_format sdr;
    struct v4l2_meta_format meta;
    __u8 raw_data[200];
  } fmt;
};
struct v4l2_streamparm {
  __u32 type;
  union {
    struct v4l2_captureparm capture;
    struct v4l2_outputparm output;
    __u8 raw_data[200];
  } parm;
};
#define V4L2_EVENT_ALL 0
#define V4L2_EVENT_VSYNC 1
#define V4L2_EVENT_EOS 2
#define V4L2_EVENT_CTRL 3
#define V4L2_EVENT_FRAME_SYNC 4
#define V4L2_EVENT_SOURCE_CHANGE 5
#define V4L2_EVENT_MOTION_DET 6
#define V4L2_EVENT_PRIVATE_START 0x08000000
struct v4l2_event_vsync {
  __u8 field;
} __attribute__((packed));
#define V4L2_EVENT_CTRL_CH_VALUE (1 << 0)
#define V4L2_EVENT_CTRL_CH_FLAGS (1 << 1)
#define V4L2_EVENT_CTRL_CH_RANGE (1 << 2)
struct v4l2_event_ctrl {
  __u32 changes;
  __u32 type;
  union {
    __s32 value;
    __s64 value64;
  };
  __u32 flags;
  __s32 minimum;
  __s32 maximum;
  __s32 step;
  __s32 default_value;
};
struct v4l2_event_frame_sync {
  __u32 frame_sequence;
};
#define V4L2_EVENT_SRC_CH_RESOLUTION (1 << 0)
struct v4l2_event_src_change {
  __u32 changes;
};
#define V4L2_EVENT_MD_FL_HAVE_FRAME_SEQ (1 << 0)
struct v4l2_event_motion_det {
  __u32 flags;
  __u32 frame_sequence;
  __u32 region_mask;
};
struct v4l2_event {
  __u32 type;
  union {
    struct v4l2_event_vsync vsync;
    struct v4l2_event_ctrl ctrl;
    struct v4l2_event_frame_sync frame_sync;
    struct v4l2_event_src_change src_change;
    struct v4l2_event_motion_det motion_det;
    __u8 data[64];
  } u;
  __u32 pending;
  __u32 sequence;
  struct timespec timestamp;
  __u32 id;
  __u32 reserved[8];
};
#define V4L2_EVENT_SUB_FL_SEND_INITIAL (1 << 0)
#define V4L2_EVENT_SUB_FL_ALLOW_FEEDBACK (1 << 1)
struct v4l2_event_subscription {
  __u32 type;
  __u32 id;
  __u32 flags;
  __u32 reserved[5];
};
#define V4L2_CHIP_MATCH_BRIDGE 0
#define V4L2_CHIP_MATCH_SUBDEV 4
#define V4L2_CHIP_MATCH_HOST V4L2_CHIP_MATCH_BRIDGE
#define V4L2_CHIP_MATCH_I2C_DRIVER 1
#define V4L2_CHIP_MATCH_I2C_ADDR 2
#define V4L2_CHIP_MATCH_AC97 3
struct v4l2_dbg_match {
  __u32 type;
  union {
    __u32 addr;
    char name[32];
  };
} __attribute__((packed));
struct v4l2_dbg_register {
  struct v4l2_dbg_match match;
  __u32 size;
  __u64 reg;
  __u64 val;
} __attribute__((packed));
#define V4L2_CHIP_FL_READABLE (1 << 0)
#define V4L2_CHIP_FL_WRITABLE (1 << 1)
struct v4l2_dbg_chip_info {
  struct v4l2_dbg_match match;
  char name[32];
  __u32 flags;
  __u32 reserved[32];
} __attribute__((packed));
struct v4l2_create_buffers {
  __u32 index;
  __u32 count;
  __u32 memory;
  struct v4l2_format format;
  __u32 capabilities;
  __u32 reserved[7];
};
#define VIDIOC_QUERYCAP _IOR('V', 0, struct v4l2_capability)
#define VIDIOC_ENUM_FMT _IOWR('V', 2, struct v4l2_fmtdesc)
#define VIDIOC_G_FMT _IOWR('V', 4, struct v4l2_format)
#define VIDIOC_S_FMT _IOWR('V', 5, struct v4l2_format)
#define VIDIOC_REQBUFS _IOWR('V', 8, struct v4l2_requestbuffers)
#define VIDIOC_QUERYBUF _IOWR('V', 9, struct v4l2_buffer)
#define VIDIOC_G_FBUF _IOR('V', 10, struct v4l2_framebuffer)
#define VIDIOC_S_FBUF _IOW('V', 11, struct v4l2_framebuffer)
#define VIDIOC_OVERLAY _IOW('V', 14, int)
#define VIDIOC_QBUF _IOWR('V', 15, struct v4l2_buffer)
#define VIDIOC_EXPBUF _IOWR('V', 16, struct v4l2_exportbuffer)
#define VIDIOC_DQBUF _IOWR('V', 17, struct v4l2_buffer)
#define VIDIOC_STREAMON _IOW('V', 18, int)
#define VIDIOC_STREAMOFF _IOW('V', 19, int)
#define VIDIOC_G_PARM _IOWR('V', 21, struct v4l2_streamparm)
#define VIDIOC_S_PARM _IOWR('V', 22, struct v4l2_streamparm)
#define VIDIOC_G_STD _IOR('V', 23, v4l2_std_id)
#define VIDIOC_S_STD _IOW('V', 24, v4l2_std_id)
#define VIDIOC_ENUMSTD _IOWR('V', 25, struct v4l2_standard)
#define VIDIOC_ENUMINPUT _IOWR('V', 26, struct v4l2_input)
#define VIDIOC_G_CTRL _IOWR('V', 27, struct v4l2_control)
#define VIDIOC_S_CTRL _IOWR('V', 28, struct v4l2_control)
#define VIDIOC_G_TUNER _IOWR('V', 29, struct v4l2_tuner)
#define VIDIOC_S_TUNER _IOW('V', 30, struct v4l2_tuner)
#define VIDIOC_G_AUDIO _IOR('V', 33, struct v4l2_audio)
#define VIDIOC_S_AUDIO _IOW('V', 34, struct v4l2_audio)
#define VIDIOC_QUERYCTRL _IOWR('V', 36, struct v4l2_queryctrl)
#define VIDIOC_QUERYMENU _IOWR('V', 37, struct v4l2_querymenu)
#define VIDIOC_G_INPUT _IOR('V', 38, int)
#define VIDIOC_S_INPUT _IOWR('V', 39, int)
#define VIDIOC_G_EDID _IOWR('V', 40, struct v4l2_edid)
#define VIDIOC_S_EDID _IOWR('V', 41, struct v4l2_edid)
#define VIDIOC_G_OUTPUT _IOR('V', 46, int)
#define VIDIOC_S_OUTPUT _IOWR('V', 47, int)
#define VIDIOC_ENUMOUTPUT _IOWR('V', 48, struct v4l2_output)
#define VIDIOC_G_AUDOUT _IOR('V', 49, struct v4l2_audioout)
#define VIDIOC_S_AUDOUT _IOW('V', 50, struct v4l2_audioout)
#define VIDIOC_G_MODULATOR _IOWR('V', 54, struct v4l2_modulator)
#define VIDIOC_S_MODULATOR _IOW('V', 55, struct v4l2_modulator)
#define VIDIOC_G_FREQUENCY _IOWR('V', 56, struct v4l2_frequency)
#define VIDIOC_S_FREQUENCY _IOW('V', 57, struct v4l2_frequency)
#define VIDIOC_CROPCAP _IOWR('V', 58, struct v4l2_cropcap)
#define VIDIOC_G_CROP _IOWR('V', 59, struct v4l2_crop)
#define VIDIOC_S_CROP _IOW('V', 60, struct v4l2_crop)
#define VIDIOC_G_JPEGCOMP _IOR('V', 61, struct v4l2_jpegcompression)
#define VIDIOC_S_JPEGCOMP _IOW('V', 62, struct v4l2_jpegcompression)
#define VIDIOC_QUERYSTD _IOR('V', 63, v4l2_std_id)
#define VIDIOC_TRY_FMT _IOWR('V', 64, struct v4l2_format)
#define VIDIOC_ENUMAUDIO _IOWR('V', 65, struct v4l2_audio)
#define VIDIOC_ENUMAUDOUT _IOWR('V', 66, struct v4l2_audioout)
#define VIDIOC_G_PRIORITY _IOR('V', 67, __u32)
#define VIDIOC_S_PRIORITY _IOW('V', 68, __u32)
#define VIDIOC_G_SLICED_VBI_CAP _IOWR('V', 69, struct v4l2_sliced_vbi_cap)
#define VIDIOC_LOG_STATUS _IO('V', 70)
#define VIDIOC_G_EXT_CTRLS _IOWR('V', 71, struct v4l2_ext_controls)
#define VIDIOC_S_EXT_CTRLS _IOWR('V', 72, struct v4l2_ext_controls)
#define VIDIOC_TRY_EXT_CTRLS _IOWR('V', 73, struct v4l2_ext_controls)
#define VIDIOC_ENUM_FRAMESIZES _IOWR('V', 74, struct v4l2_frmsizeenum)
#define VIDIOC_ENUM_FRAMEINTERVALS _IOWR('V', 75, struct v4l2_frmivalenum)
#define VIDIOC_G_ENC_INDEX _IOR('V', 76, struct v4l2_enc_idx)
#define VIDIOC_ENCODER_CMD _IOWR('V', 77, struct v4l2_encoder_cmd)
#define VIDIOC_TRY_ENCODER_CMD _IOWR('V', 78, struct v4l2_encoder_cmd)
#define VIDIOC_DBG_S_REGISTER _IOW('V', 79, struct v4l2_dbg_register)
#define VIDIOC_DBG_G_REGISTER _IOWR('V', 80, struct v4l2_dbg_register)
#define VIDIOC_S_HW_FREQ_SEEK _IOW('V', 82, struct v4l2_hw_freq_seek)
#define VIDIOC_S_DV_TIMINGS _IOWR('V', 87, struct v4l2_dv_timings)
#define VIDIOC_G_DV_TIMINGS _IOWR('V', 88, struct v4l2_dv_timings)
#define VIDIOC_DQEVENT _IOR('V', 89, struct v4l2_event)
#define VIDIOC_SUBSCRIBE_EVENT _IOW('V', 90, struct v4l2_event_subscription)
#define VIDIOC_UNSUBSCRIBE_EVENT _IOW('V', 91, struct v4l2_event_subscription)
#define VIDIOC_CREATE_BUFS _IOWR('V', 92, struct v4l2_create_buffers)
#define VIDIOC_PREPARE_BUF _IOWR('V', 93, struct v4l2_buffer)
#define VIDIOC_G_SELECTION _IOWR('V', 94, struct v4l2_selection)
#define VIDIOC_S_SELECTION _IOWR('V', 95, struct v4l2_selection)
#define VIDIOC_DECODER_CMD _IOWR('V', 96, struct v4l2_decoder_cmd)
#define VIDIOC_TRY_DECODER_CMD _IOWR('V', 97, struct v4l2_decoder_cmd)
#define VIDIOC_ENUM_DV_TIMINGS _IOWR('V', 98, struct v4l2_enum_dv_timings)
#define VIDIOC_QUERY_DV_TIMINGS _IOR('V', 99, struct v4l2_dv_timings)
#define VIDIOC_DV_TIMINGS_CAP _IOWR('V', 100, struct v4l2_dv_timings_cap)
#define VIDIOC_ENUM_FREQ_BANDS _IOWR('V', 101, struct v4l2_frequency_band)
#define VIDIOC_DBG_G_CHIP_INFO _IOWR('V', 102, struct v4l2_dbg_chip_info)
#define VIDIOC_QUERY_EXT_CTRL _IOWR('V', 103, struct v4l2_query_ext_ctrl)
#define BASE_VIDIOC_PRIVATE 192
#endif