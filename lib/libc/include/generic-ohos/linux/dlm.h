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
#ifndef _UAPI__DLM_DOT_H__
#define _UAPI__DLM_DOT_H__
#include <linux/dlmconstants.h>
#include <linux/types.h>
typedef void dlm_lockspace_t;
#define DLM_SBF_DEMOTED 0x01
#define DLM_SBF_VALNOTVALID 0x02
#define DLM_SBF_ALTMODE 0x04
struct dlm_lksb {
  int sb_status;
  __u32 sb_lkid;
  char sb_flags;
  char * sb_lvbptr;
};
#define DLM_LSFL_TIMEWARN 0x00000002
#define DLM_LSFL_FS 0x00000004
#define DLM_LSFL_NEWEXCL 0x00000008
#endif