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
#ifndef _UAPI__INCLUDE_LINUX_OOM_H
#define _UAPI__INCLUDE_LINUX_OOM_H
#define OOM_SCORE_ADJ_MIN (- 1000)
#define OOM_SCORE_ADJ_MAX 1000
#define OOM_DISABLE (- 17)
#define OOM_ADJUST_MIN (- 16)
#define OOM_ADJUST_MAX 15
#endif