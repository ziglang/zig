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
#ifndef _UAPI_ARPTABLES_H
#define _UAPI_ARPTABLES_H
#include <linux/types.h>
#include <linux/compiler.h>
#include <linux/if.h>
#include <linux/netfilter_arp.h>
#include <linux/netfilter/x_tables.h>
#define ARPT_FUNCTION_MAXNAMELEN XT_FUNCTION_MAXNAMELEN
#define ARPT_TABLE_MAXNAMELEN XT_TABLE_MAXNAMELEN
#define arpt_entry_target xt_entry_target
#define arpt_standard_target xt_standard_target
#define arpt_error_target xt_error_target
#define ARPT_CONTINUE XT_CONTINUE
#define ARPT_RETURN XT_RETURN
#define arpt_counters_info xt_counters_info
#define arpt_counters xt_counters
#define ARPT_STANDARD_TARGET XT_STANDARD_TARGET
#define ARPT_ERROR_TARGET XT_ERROR_TARGET
#define ARPT_ENTRY_ITERATE(entries,size,fn,args...) XT_ENTRY_ITERATE(struct arpt_entry, entries, size, fn, ##args)
#define ARPT_DEV_ADDR_LEN_MAX 16
struct arpt_devaddr_info {
  char addr[ARPT_DEV_ADDR_LEN_MAX];
  char mask[ARPT_DEV_ADDR_LEN_MAX];
};
struct arpt_arp {
  struct in_addr src, tgt;
  struct in_addr smsk, tmsk;
  __u8 arhln, arhln_mask;
  struct arpt_devaddr_info src_devaddr;
  struct arpt_devaddr_info tgt_devaddr;
  __be16 arpop, arpop_mask;
  __be16 arhrd, arhrd_mask;
  __be16 arpro, arpro_mask;
  char iniface[IFNAMSIZ], outiface[IFNAMSIZ];
  unsigned char iniface_mask[IFNAMSIZ], outiface_mask[IFNAMSIZ];
  __u8 flags;
  __u16 invflags;
};
#define ARPT_F_MASK 0x00
#define ARPT_INV_VIA_IN 0x0001
#define ARPT_INV_VIA_OUT 0x0002
#define ARPT_INV_SRCIP 0x0004
#define ARPT_INV_TGTIP 0x0008
#define ARPT_INV_SRCDEVADDR 0x0010
#define ARPT_INV_TGTDEVADDR 0x0020
#define ARPT_INV_ARPOP 0x0040
#define ARPT_INV_ARPHRD 0x0080
#define ARPT_INV_ARPPRO 0x0100
#define ARPT_INV_ARPHLN 0x0200
#define ARPT_INV_MASK 0x03FF
struct arpt_entry {
  struct arpt_arp arp;
  __u16 target_offset;
  __u16 next_offset;
  unsigned int comefrom;
  struct xt_counters counters;
  unsigned char elems[0];
};
#define ARPT_BASE_CTL 96
#define ARPT_SO_SET_REPLACE (ARPT_BASE_CTL)
#define ARPT_SO_SET_ADD_COUNTERS (ARPT_BASE_CTL + 1)
#define ARPT_SO_SET_MAX ARPT_SO_SET_ADD_COUNTERS
#define ARPT_SO_GET_INFO (ARPT_BASE_CTL)
#define ARPT_SO_GET_ENTRIES (ARPT_BASE_CTL + 1)
#define ARPT_SO_GET_REVISION_TARGET (ARPT_BASE_CTL + 3)
#define ARPT_SO_GET_MAX (ARPT_SO_GET_REVISION_TARGET)
struct arpt_getinfo {
  char name[XT_TABLE_MAXNAMELEN];
  unsigned int valid_hooks;
  unsigned int hook_entry[NF_ARP_NUMHOOKS];
  unsigned int underflow[NF_ARP_NUMHOOKS];
  unsigned int num_entries;
  unsigned int size;
};
struct arpt_replace {
  char name[XT_TABLE_MAXNAMELEN];
  unsigned int valid_hooks;
  unsigned int num_entries;
  unsigned int size;
  unsigned int hook_entry[NF_ARP_NUMHOOKS];
  unsigned int underflow[NF_ARP_NUMHOOKS];
  unsigned int num_counters;
  struct xt_counters __user * counters;
  struct arpt_entry entries[0];
};
struct arpt_get_entries {
  char name[XT_TABLE_MAXNAMELEN];
  unsigned int size;
  struct arpt_entry entrytable[0];
};
#endif