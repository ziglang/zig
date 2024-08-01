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
#ifndef _LINUX_ATMPPP_H
#define _LINUX_ATMPPP_H
#include <linux/atm.h>
#define PPPOATM_ENCAPS_AUTODETECT (0)
#define PPPOATM_ENCAPS_VC (1)
#define PPPOATM_ENCAPS_LLC (2)
struct atm_backend_ppp {
  atm_backend_t backend_num;
  int encaps;
};
#endif