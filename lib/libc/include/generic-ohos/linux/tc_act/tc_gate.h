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
#ifndef __LINUX_TC_GATE_H
#define __LINUX_TC_GATE_H
#include <linux/pkt_cls.h>
struct tc_gate {
  tc_gen;
};
enum {
  TCA_GATE_ENTRY_UNSPEC,
  TCA_GATE_ENTRY_INDEX,
  TCA_GATE_ENTRY_GATE,
  TCA_GATE_ENTRY_INTERVAL,
  TCA_GATE_ENTRY_IPV,
  TCA_GATE_ENTRY_MAX_OCTETS,
  __TCA_GATE_ENTRY_MAX,
};
#define TCA_GATE_ENTRY_MAX (__TCA_GATE_ENTRY_MAX - 1)
enum {
  TCA_GATE_ONE_ENTRY_UNSPEC,
  TCA_GATE_ONE_ENTRY,
  __TCA_GATE_ONE_ENTRY_MAX,
};
#define TCA_GATE_ONE_ENTRY_MAX (__TCA_GATE_ONE_ENTRY_MAX - 1)
enum {
  TCA_GATE_UNSPEC,
  TCA_GATE_TM,
  TCA_GATE_PARMS,
  TCA_GATE_PAD,
  TCA_GATE_PRIORITY,
  TCA_GATE_ENTRY_LIST,
  TCA_GATE_BASE_TIME,
  TCA_GATE_CYCLE_TIME,
  TCA_GATE_CYCLE_TIME_EXT,
  TCA_GATE_FLAGS,
  TCA_GATE_CLOCKID,
  __TCA_GATE_MAX,
};
#define TCA_GATE_MAX (__TCA_GATE_MAX - 1)
#endif