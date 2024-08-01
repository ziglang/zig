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
#ifndef _UAPI_IPTABLES_H
#define _UAPI_IPTABLES_H
#include <linux/types.h>
#include <linux/compiler.h>
#include <linux/if.h>
#include <linux/netfilter_ipv4.h>
#include <linux/netfilter/x_tables.h>
#define IPT_FUNCTION_MAXNAMELEN XT_FUNCTION_MAXNAMELEN
#define IPT_TABLE_MAXNAMELEN XT_TABLE_MAXNAMELEN
#define ipt_match xt_match
#define ipt_target xt_target
#define ipt_table xt_table
#define ipt_get_revision xt_get_revision
#define ipt_entry_match xt_entry_match
#define ipt_entry_target xt_entry_target
#define ipt_standard_target xt_standard_target
#define ipt_error_target xt_error_target
#define ipt_counters xt_counters
#define IPT_CONTINUE XT_CONTINUE
#define IPT_RETURN XT_RETURN
#include <linux/netfilter/xt_tcpudp.h>
#define ipt_udp xt_udp
#define ipt_tcp xt_tcp
#define IPT_TCP_INV_SRCPT XT_TCP_INV_SRCPT
#define IPT_TCP_INV_DSTPT XT_TCP_INV_DSTPT
#define IPT_TCP_INV_FLAGS XT_TCP_INV_FLAGS
#define IPT_TCP_INV_OPTION XT_TCP_INV_OPTION
#define IPT_TCP_INV_MASK XT_TCP_INV_MASK
#define IPT_UDP_INV_SRCPT XT_UDP_INV_SRCPT
#define IPT_UDP_INV_DSTPT XT_UDP_INV_DSTPT
#define IPT_UDP_INV_MASK XT_UDP_INV_MASK
#define ipt_counters_info xt_counters_info
#define IPT_STANDARD_TARGET XT_STANDARD_TARGET
#define IPT_ERROR_TARGET XT_ERROR_TARGET
#define IPT_MATCH_ITERATE(e,fn,args...) XT_MATCH_ITERATE(struct ipt_entry, e, fn, ##args)
#define IPT_ENTRY_ITERATE(entries,size,fn,args...) XT_ENTRY_ITERATE(struct ipt_entry, entries, size, fn, ##args)
struct ipt_ip {
  struct in_addr src, dst;
  struct in_addr smsk, dmsk;
  char iniface[IFNAMSIZ], outiface[IFNAMSIZ];
  unsigned char iniface_mask[IFNAMSIZ], outiface_mask[IFNAMSIZ];
  __u16 proto;
  __u8 flags;
  __u8 invflags;
};
#define IPT_F_FRAG 0x01
#define IPT_F_GOTO 0x02
#define IPT_F_MASK 0x03
#define IPT_INV_VIA_IN 0x01
#define IPT_INV_VIA_OUT 0x02
#define IPT_INV_TOS 0x04
#define IPT_INV_SRCIP 0x08
#define IPT_INV_DSTIP 0x10
#define IPT_INV_FRAG 0x20
#define IPT_INV_PROTO XT_INV_PROTO
#define IPT_INV_MASK 0x7F
struct ipt_entry {
  struct ipt_ip ip;
  unsigned int nfcache;
  __u16 target_offset;
  __u16 next_offset;
  unsigned int comefrom;
  struct xt_counters counters;
  unsigned char elems[0];
};
#define IPT_BASE_CTL 64
#define IPT_SO_SET_REPLACE (IPT_BASE_CTL)
#define IPT_SO_SET_ADD_COUNTERS (IPT_BASE_CTL + 1)
#define IPT_SO_SET_MAX IPT_SO_SET_ADD_COUNTERS
#define IPT_SO_GET_INFO (IPT_BASE_CTL)
#define IPT_SO_GET_ENTRIES (IPT_BASE_CTL + 1)
#define IPT_SO_GET_REVISION_MATCH (IPT_BASE_CTL + 2)
#define IPT_SO_GET_REVISION_TARGET (IPT_BASE_CTL + 3)
#define IPT_SO_GET_MAX IPT_SO_GET_REVISION_TARGET
struct ipt_icmp {
  __u8 type;
  __u8 code[2];
  __u8 invflags;
};
#define IPT_ICMP_INV 0x01
struct ipt_getinfo {
  char name[XT_TABLE_MAXNAMELEN];
  unsigned int valid_hooks;
  unsigned int hook_entry[NF_INET_NUMHOOKS];
  unsigned int underflow[NF_INET_NUMHOOKS];
  unsigned int num_entries;
  unsigned int size;
};
struct ipt_replace {
  char name[XT_TABLE_MAXNAMELEN];
  unsigned int valid_hooks;
  unsigned int num_entries;
  unsigned int size;
  unsigned int hook_entry[NF_INET_NUMHOOKS];
  unsigned int underflow[NF_INET_NUMHOOKS];
  unsigned int num_counters;
  struct xt_counters __user * counters;
  struct ipt_entry entries[0];
};
struct ipt_get_entries {
  char name[XT_TABLE_MAXNAMELEN];
  unsigned int size;
  struct ipt_entry entrytable[0];
};
static __inline__ struct xt_entry_target * ipt_get_target(struct ipt_entry * e) {
  return(struct xt_entry_target *) ((char *) e + e->target_offset);
}
#endif