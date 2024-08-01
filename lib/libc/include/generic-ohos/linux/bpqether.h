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
#ifndef __BPQETHER_H
#define __BPQETHER_H
#include <linux/if_ether.h>
#define SIOCSBPQETHOPT (SIOCDEVPRIVATE + 0)
#define SIOCSBPQETHADDR (SIOCDEVPRIVATE + 1)
struct bpq_ethaddr {
  unsigned char destination[ETH_ALEN];
  unsigned char accept[ETH_ALEN];
};
#define SIOCGBPQETHPARAM 0x5000
#define SIOCSBPQETHPARAM 0x5001
struct bpq_req {
  int cmd;
  int speed;
  int clockmode;
  int txdelay;
  unsigned char persist;
  int slotime;
  int squeldelay;
  int dmachan;
  int irq;
};
#endif