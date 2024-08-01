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
#ifndef _UAPI_SCREEN_INFO_H
#define _UAPI_SCREEN_INFO_H
#include <linux/types.h>
struct screen_info {
  __u8 orig_x;
  __u8 orig_y;
  __u16 ext_mem_k;
  __u16 orig_video_page;
  __u8 orig_video_mode;
  __u8 orig_video_cols;
  __u8 flags;
  __u8 unused2;
  __u16 orig_video_ega_bx;
  __u16 unused3;
  __u8 orig_video_lines;
  __u8 orig_video_isVGA;
  __u16 orig_video_points;
  __u16 lfb_width;
  __u16 lfb_height;
  __u16 lfb_depth;
  __u32 lfb_base;
  __u32 lfb_size;
  __u16 cl_magic, cl_offset;
  __u16 lfb_linelength;
  __u8 red_size;
  __u8 red_pos;
  __u8 green_size;
  __u8 green_pos;
  __u8 blue_size;
  __u8 blue_pos;
  __u8 rsvd_size;
  __u8 rsvd_pos;
  __u16 vesapm_seg;
  __u16 vesapm_off;
  __u16 pages;
  __u16 vesa_attributes;
  __u32 capabilities;
  __u32 ext_lfb_base;
  __u8 _reserved[2];
} __attribute__((packed));
#define VIDEO_TYPE_MDA 0x10
#define VIDEO_TYPE_CGA 0x11
#define VIDEO_TYPE_EGAM 0x20
#define VIDEO_TYPE_EGAC 0x21
#define VIDEO_TYPE_VGAC 0x22
#define VIDEO_TYPE_VLFB 0x23
#define VIDEO_TYPE_PICA_S3 0x30
#define VIDEO_TYPE_MIPS_G364 0x31
#define VIDEO_TYPE_SGI 0x33
#define VIDEO_TYPE_TGAC 0x40
#define VIDEO_TYPE_SUN 0x50
#define VIDEO_TYPE_SUNPCI 0x51
#define VIDEO_TYPE_PMAC 0x60
#define VIDEO_TYPE_EFI 0x70
#define VIDEO_FLAGS_NOCURSOR (1 << 0)
#define VIDEO_CAPABILITY_SKIP_QUIRKS (1 << 0)
#define VIDEO_CAPABILITY_64BIT_BASE (1 << 1)
#endif