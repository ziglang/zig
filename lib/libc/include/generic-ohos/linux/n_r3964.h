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
#ifndef _UAPI__LINUX_N_R3964_H__
#define _UAPI__LINUX_N_R3964_H__
#define R3964_ENABLE_SIGNALS 0x5301
#define R3964_SETPRIORITY 0x5302
#define R3964_USE_BCC 0x5303
#define R3964_READ_TELEGRAM 0x5304
#define R3964_MASTER 0
#define R3964_SLAVE 1
#define R3964_SIG_ACK 0x0001
#define R3964_SIG_DATA 0x0002
#define R3964_SIG_ALL 0x000f
#define R3964_SIG_NONE 0x0000
#define R3964_USE_SIGIO 0x1000
enum {
  R3964_MSG_ACK = 1,
  R3964_MSG_DATA
};
#define R3964_MAX_MSG_COUNT 32
#define R3964_OK 0
#define R3964_TX_FAIL - 1
#define R3964_OVERFLOW - 2
struct r3964_client_message {
  int msg_id;
  int arg;
  int error_code;
};
#define R3964_MTU 256
#endif