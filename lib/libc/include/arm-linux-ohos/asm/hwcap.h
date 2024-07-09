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
#ifndef _UAPI__ASMARM_HWCAP_H
#define _UAPI__ASMARM_HWCAP_H
#define HWCAP_SWP (1 << 0)
#define HWCAP_HALF (1 << 1)
#define HWCAP_THUMB (1 << 2)
#define HWCAP_26BIT (1 << 3)
#define HWCAP_FAST_MULT (1 << 4)
#define HWCAP_FPA (1 << 5)
#define HWCAP_VFP (1 << 6)
#define HWCAP_EDSP (1 << 7)
#define HWCAP_JAVA (1 << 8)
#define HWCAP_IWMMXT (1 << 9)
#define HWCAP_CRUNCH (1 << 10)
#define HWCAP_THUMBEE (1 << 11)
#define HWCAP_NEON (1 << 12)
#define HWCAP_VFPv3 (1 << 13)
#define HWCAP_VFPv3D16 (1 << 14)
#define HWCAP_TLS (1 << 15)
#define HWCAP_VFPv4 (1 << 16)
#define HWCAP_IDIVA (1 << 17)
#define HWCAP_IDIVT (1 << 18)
#define HWCAP_VFPD32 (1 << 19)
#define HWCAP_IDIV (HWCAP_IDIVA | HWCAP_IDIVT)
#define HWCAP_LPAE (1 << 20)
#define HWCAP_EVTSTRM (1 << 21)
#define HWCAP2_AES (1 << 0)
#define HWCAP2_PMULL (1 << 1)
#define HWCAP2_SHA1 (1 << 2)
#define HWCAP2_SHA2 (1 << 3)
#define HWCAP2_CRC32 (1 << 4)
#endif
