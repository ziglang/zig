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
#ifndef __UAPI_CORESIGHT_STM_H_
#define __UAPI_CORESIGHT_STM_H_
#include <linux/const.h>
#define STM_FLAG_TIMESTAMPED _BITUL(3)
#define STM_FLAG_MARKED _BITUL(4)
#define STM_FLAG_GUARANTEED _BITUL(7)
enum {
  STM_OPTION_GUARANTEED = 0,
  STM_OPTION_INVARIANT,
};
#endif