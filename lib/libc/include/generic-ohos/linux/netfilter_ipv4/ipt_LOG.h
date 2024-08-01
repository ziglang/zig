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
#ifndef _IPT_LOG_H
#define _IPT_LOG_H
#define IPT_LOG_TCPSEQ 0x01
#define IPT_LOG_TCPOPT 0x02
#define IPT_LOG_IPOPT 0x04
#define IPT_LOG_UID 0x08
#define IPT_LOG_NFLOG 0x10
#define IPT_LOG_MACDECODE 0x20
#define IPT_LOG_MASK 0x2f
struct ipt_log_info {
  unsigned char level;
  unsigned char logflags;
  char prefix[30];
};
#endif