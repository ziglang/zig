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
#ifndef _USERIO_H
#define _USERIO_H
#include <linux/types.h>
enum userio_cmd_type {
  USERIO_CMD_REGISTER = 0,
  USERIO_CMD_SET_PORT_TYPE = 1,
  USERIO_CMD_SEND_INTERRUPT = 2
};
struct userio_cmd {
  __u8 type;
  __u8 data;
} __attribute__((__packed__));
#endif