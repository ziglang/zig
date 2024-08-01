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
#ifndef _MEYE_H_
#define _MEYE_H_
struct meye_params {
  unsigned char subsample;
  unsigned char quality;
  unsigned char sharpness;
  unsigned char agc;
  unsigned char picture;
  unsigned char framerate;
};
#define MEYEIOC_G_PARAMS _IOR('v', BASE_VIDIOC_PRIVATE + 0, struct meye_params)
#define MEYEIOC_S_PARAMS _IOW('v', BASE_VIDIOC_PRIVATE + 1, struct meye_params)
#define MEYEIOC_QBUF_CAPT _IOW('v', BASE_VIDIOC_PRIVATE + 2, int)
#define MEYEIOC_SYNC _IOWR('v', BASE_VIDIOC_PRIVATE + 3, int)
#define MEYEIOC_STILLCAPT _IO('v', BASE_VIDIOC_PRIVATE + 4)
#define MEYEIOC_STILLJCAPT _IOR('v', BASE_VIDIOC_PRIVATE + 5, int)
#define V4L2_CID_MEYE_AGC (V4L2_CID_USER_MEYE_BASE + 0)
#define V4L2_CID_MEYE_PICTURE (V4L2_CID_USER_MEYE_BASE + 1)
#define V4L2_CID_MEYE_FRAMERATE (V4L2_CID_USER_MEYE_BASE + 2)
#endif