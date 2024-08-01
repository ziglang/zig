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
#ifndef _UAPI_LINUX_SMC_H_
#define _UAPI_LINUX_SMC_H_
enum {
  SMC_PNETID_UNSPEC,
  SMC_PNETID_NAME,
  SMC_PNETID_ETHNAME,
  SMC_PNETID_IBNAME,
  SMC_PNETID_IBPORT,
  __SMC_PNETID_MAX,
  SMC_PNETID_MAX = __SMC_PNETID_MAX - 1
};
enum {
  SMC_PNETID_GET = 1,
  SMC_PNETID_ADD,
  SMC_PNETID_DEL,
  SMC_PNETID_FLUSH
};
#define SMCR_GENL_FAMILY_NAME "SMC_PNETID"
#define SMCR_GENL_FAMILY_VERSION 1
#endif