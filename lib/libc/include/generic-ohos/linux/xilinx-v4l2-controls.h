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
#ifndef __UAPI_XILINX_V4L2_CONTROLS_H__
#define __UAPI_XILINX_V4L2_CONTROLS_H__
#include <linux/v4l2-controls.h>
#define V4L2_CID_XILINX_OFFSET 0xc000
#define V4L2_CID_XILINX_BASE (V4L2_CID_USER_BASE + V4L2_CID_XILINX_OFFSET)
#define V4L2_CID_XILINX_TPG (V4L2_CID_USER_BASE + 0xc000)
#define V4L2_CID_XILINX_TPG_CROSS_HAIRS (V4L2_CID_XILINX_TPG + 1)
#define V4L2_CID_XILINX_TPG_MOVING_BOX (V4L2_CID_XILINX_TPG + 2)
#define V4L2_CID_XILINX_TPG_COLOR_MASK (V4L2_CID_XILINX_TPG + 3)
#define V4L2_CID_XILINX_TPG_STUCK_PIXEL (V4L2_CID_XILINX_TPG + 4)
#define V4L2_CID_XILINX_TPG_NOISE (V4L2_CID_XILINX_TPG + 5)
#define V4L2_CID_XILINX_TPG_MOTION (V4L2_CID_XILINX_TPG + 6)
#define V4L2_CID_XILINX_TPG_MOTION_SPEED (V4L2_CID_XILINX_TPG + 7)
#define V4L2_CID_XILINX_TPG_CROSS_HAIR_ROW (V4L2_CID_XILINX_TPG + 8)
#define V4L2_CID_XILINX_TPG_CROSS_HAIR_COLUMN (V4L2_CID_XILINX_TPG + 9)
#define V4L2_CID_XILINX_TPG_ZPLATE_HOR_START (V4L2_CID_XILINX_TPG + 10)
#define V4L2_CID_XILINX_TPG_ZPLATE_HOR_SPEED (V4L2_CID_XILINX_TPG + 11)
#define V4L2_CID_XILINX_TPG_ZPLATE_VER_START (V4L2_CID_XILINX_TPG + 12)
#define V4L2_CID_XILINX_TPG_ZPLATE_VER_SPEED (V4L2_CID_XILINX_TPG + 13)
#define V4L2_CID_XILINX_TPG_BOX_SIZE (V4L2_CID_XILINX_TPG + 14)
#define V4L2_CID_XILINX_TPG_BOX_COLOR (V4L2_CID_XILINX_TPG + 15)
#define V4L2_CID_XILINX_TPG_STUCK_PIXEL_THRESH (V4L2_CID_XILINX_TPG + 16)
#define V4L2_CID_XILINX_TPG_NOISE_GAIN (V4L2_CID_XILINX_TPG + 17)
#endif