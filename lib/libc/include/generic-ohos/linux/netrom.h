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
#ifndef NETROM_KERNEL_H
#define NETROM_KERNEL_H
#include <linux/ax25.h>
#define NETROM_MTU 236
#define NETROM_T1 1
#define NETROM_T2 2
#define NETROM_N2 3
#define NETROM_T4 6
#define NETROM_IDLE 7
#define SIOCNRDECOBS (SIOCPROTOPRIVATE + 2)
struct nr_route_struct {
#define NETROM_NEIGH 0
#define NETROM_NODE 1
  int type;
  ax25_address callsign;
  char device[16];
  unsigned int quality;
  char mnemonic[7];
  ax25_address neighbour;
  unsigned int obs_count;
  unsigned int ndigis;
  ax25_address digipeaters[AX25_MAX_DIGIS];
};
#endif