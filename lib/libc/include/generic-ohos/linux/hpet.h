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
#ifndef _UAPI__HPET__
#define _UAPI__HPET__
#include <linux/compiler.h>
struct hpet_info {
  unsigned long hi_ireqfreq;
  unsigned long hi_flags;
  unsigned short hi_hpet;
  unsigned short hi_timer;
};
#define HPET_INFO_PERIODIC 0x0010
#define HPET_IE_ON _IO('h', 0x01)
#define HPET_IE_OFF _IO('h', 0x02)
#define HPET_INFO _IOR('h', 0x03, struct hpet_info)
#define HPET_EPI _IO('h', 0x04)
#define HPET_DPI _IO('h', 0x05)
#define HPET_IRQFREQ _IOW('h', 0x6, unsigned long)
#define MAX_HPET_TBS 8
#endif