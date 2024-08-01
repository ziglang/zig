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
#ifndef _UAPINFSD_EXPORT_H
#define _UAPINFSD_EXPORT_H
#include <linux/types.h>
#define NFSCLNT_IDMAX 1024
#define NFSCLNT_ADDRMAX 16
#define NFSCLNT_KEYMAX 32
#define NFSEXP_READONLY 0x0001
#define NFSEXP_INSECURE_PORT 0x0002
#define NFSEXP_ROOTSQUASH 0x0004
#define NFSEXP_ALLSQUASH 0x0008
#define NFSEXP_ASYNC 0x0010
#define NFSEXP_GATHERED_WRITES 0x0020
#define NFSEXP_NOREADDIRPLUS 0x0040
#define NFSEXP_SECURITY_LABEL 0x0080
#define NFSEXP_NOHIDE 0x0200
#define NFSEXP_NOSUBTREECHECK 0x0400
#define NFSEXP_NOAUTHNLM 0x0800
#define NFSEXP_MSNFS 0x1000
#define NFSEXP_FSID 0x2000
#define NFSEXP_CROSSMOUNT 0x4000
#define NFSEXP_NOACL 0x8000
#define NFSEXP_V4ROOT 0x10000
#define NFSEXP_PNFS 0x20000
#define NFSEXP_ALLFLAGS 0x3FEFF
#define NFSEXP_SECINFO_FLAGS (NFSEXP_READONLY | NFSEXP_ROOTSQUASH | NFSEXP_ALLSQUASH | NFSEXP_INSECURE_PORT)
#endif