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
#ifndef _LINUX_IPSEC_H
#define _LINUX_IPSEC_H
#include <linux/pfkeyv2.h>
#define IPSEC_PORT_ANY 0
#define IPSEC_ULPROTO_ANY 255
#define IPSEC_PROTO_ANY 255
enum {
  IPSEC_MODE_ANY = 0,
  IPSEC_MODE_TRANSPORT = 1,
  IPSEC_MODE_TUNNEL = 2,
  IPSEC_MODE_BEET = 3
};
enum {
  IPSEC_DIR_ANY = 0,
  IPSEC_DIR_INBOUND = 1,
  IPSEC_DIR_OUTBOUND = 2,
  IPSEC_DIR_FWD = 3,
  IPSEC_DIR_MAX = 4,
  IPSEC_DIR_INVALID = 5
};
enum {
  IPSEC_POLICY_DISCARD = 0,
  IPSEC_POLICY_NONE = 1,
  IPSEC_POLICY_IPSEC = 2,
  IPSEC_POLICY_ENTRUST = 3,
  IPSEC_POLICY_BYPASS = 4
};
enum {
  IPSEC_LEVEL_DEFAULT = 0,
  IPSEC_LEVEL_USE = 1,
  IPSEC_LEVEL_REQUIRE = 2,
  IPSEC_LEVEL_UNIQUE = 3
};
#define IPSEC_MANUAL_REQID_MAX 0x3fff
#define IPSEC_REPLAYWSIZE 32
#endif