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
#ifndef _DVBOSD_H_
#define _DVBOSD_H_
#include <linux/compiler.h>
typedef enum {
  OSD_Close = 1,
  OSD_Open,
  OSD_Show,
  OSD_Hide,
  OSD_Clear,
  OSD_Fill,
  OSD_SetColor,
  OSD_SetPalette,
  OSD_SetTrans,
  OSD_SetPixel,
  OSD_GetPixel,
  OSD_SetRow,
  OSD_SetBlock,
  OSD_FillRow,
  OSD_FillBlock,
  OSD_Line,
  OSD_Query,
  OSD_Test,
  OSD_Text,
  OSD_SetWindow,
  OSD_MoveWindow,
  OSD_OpenRaw,
} OSD_Command;
typedef struct osd_cmd_s {
  OSD_Command cmd;
  int x0;
  int y0;
  int x1;
  int y1;
  int color;
  void __user * data;
} osd_cmd_t;
typedef enum {
  OSD_BITMAP1,
  OSD_BITMAP2,
  OSD_BITMAP4,
  OSD_BITMAP8,
  OSD_BITMAP1HR,
  OSD_BITMAP2HR,
  OSD_BITMAP4HR,
  OSD_BITMAP8HR,
  OSD_YCRCB422,
  OSD_YCRCB444,
  OSD_YCRCB444HR,
  OSD_VIDEOTSIZE,
  OSD_VIDEOHSIZE,
  OSD_VIDEOQSIZE,
  OSD_VIDEODSIZE,
  OSD_VIDEOTHSIZE,
  OSD_VIDEOTQSIZE,
  OSD_VIDEOTDSIZE,
  OSD_VIDEONSIZE,
  OSD_CURSOR
} osd_raw_window_t;
typedef struct osd_cap_s {
  int cmd;
#define OSD_CAP_MEMSIZE 1
  long val;
} osd_cap_t;
#define OSD_SEND_CMD _IOW('o', 160, osd_cmd_t)
#define OSD_GET_CAPABILITY _IOR('o', 161, osd_cap_t)
#endif