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
#ifndef _LINUX_ATMIOC_H
#define _LINUX_ATMIOC_H
#include <asm/ioctl.h>
#define ATMIOC_PHYCOM 0x00
#define ATMIOC_PHYCOM_END 0x0f
#define ATMIOC_PHYTYP 0x10
#define ATMIOC_PHYTYP_END 0x2f
#define ATMIOC_PHYPRV 0x30
#define ATMIOC_PHYPRV_END 0x4f
#define ATMIOC_SARCOM 0x50
#define ATMIOC_SARCOM_END 0x50
#define ATMIOC_SARPRV 0x60
#define ATMIOC_SARPRV_END 0x7f
#define ATMIOC_ITF 0x80
#define ATMIOC_ITF_END 0x8f
#define ATMIOC_BACKEND 0x90
#define ATMIOC_BACKEND_END 0xaf
#define ATMIOC_AREQUIPA 0xc0
#define ATMIOC_LANE 0xd0
#define ATMIOC_MPOA 0xd8
#define ATMIOC_CLIP 0xe0
#define ATMIOC_CLIP_END 0xef
#define ATMIOC_SPECIAL 0xf0
#define ATMIOC_SPECIAL_END 0xff
#endif