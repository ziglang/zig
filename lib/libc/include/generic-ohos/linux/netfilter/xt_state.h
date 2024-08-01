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
#ifndef _XT_STATE_H
#define _XT_STATE_H
#define XT_STATE_BIT(ctinfo) (1 << ((ctinfo) % IP_CT_IS_REPLY + 1))
#define XT_STATE_INVALID (1 << 0)
#define XT_STATE_UNTRACKED (1 << (IP_CT_NUMBER + 1))
struct xt_state_info {
  unsigned int statemask;
};
#endif