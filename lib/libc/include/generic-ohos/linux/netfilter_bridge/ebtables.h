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
#ifndef _UAPI__LINUX_BRIDGE_EFF_H
#define _UAPI__LINUX_BRIDGE_EFF_H
#include <linux/types.h>
#include <linux/if.h>
#include <linux/netfilter_bridge.h>
#define EBT_TABLE_MAXNAMELEN 32
#define EBT_CHAIN_MAXNAMELEN EBT_TABLE_MAXNAMELEN
#define EBT_FUNCTION_MAXNAMELEN EBT_TABLE_MAXNAMELEN
#define EBT_EXTENSION_MAXNAMELEN 31
#define EBT_ACCEPT - 1
#define EBT_DROP - 2
#define EBT_CONTINUE - 3
#define EBT_RETURN - 4
#define NUM_STANDARD_TARGETS 4
#define EBT_VERDICT_BITS 0x0000000F
struct xt_match;
struct xt_target;
struct ebt_counter {
  __u64 pcnt;
  __u64 bcnt;
};
struct ebt_replace {
  char name[EBT_TABLE_MAXNAMELEN];
  unsigned int valid_hooks;
  unsigned int nentries;
  unsigned int entries_size;
  struct ebt_entries __user * hook_entry[NF_BR_NUMHOOKS];
  unsigned int num_counters;
  struct ebt_counter __user * counters;
  char __user * entries;
};
struct ebt_replace_kernel {
  char name[EBT_TABLE_MAXNAMELEN];
  unsigned int valid_hooks;
  unsigned int nentries;
  unsigned int entries_size;
  struct ebt_entries * hook_entry[NF_BR_NUMHOOKS];
  unsigned int num_counters;
  struct ebt_counter * counters;
  char * entries;
};
struct ebt_entries {
  unsigned int distinguisher;
  char name[EBT_CHAIN_MAXNAMELEN];
  unsigned int counter_offset;
  int policy;
  unsigned int nentries;
  char data[0] __attribute__((aligned(__alignof__(struct ebt_replace))));
};
#define EBT_ENTRY_OR_ENTRIES 0x01
#define EBT_NOPROTO 0x02
#define EBT_802_3 0x04
#define EBT_SOURCEMAC 0x08
#define EBT_DESTMAC 0x10
#define EBT_F_MASK (EBT_NOPROTO | EBT_802_3 | EBT_SOURCEMAC | EBT_DESTMAC | EBT_ENTRY_OR_ENTRIES)
#define EBT_IPROTO 0x01
#define EBT_IIN 0x02
#define EBT_IOUT 0x04
#define EBT_ISOURCE 0x8
#define EBT_IDEST 0x10
#define EBT_ILOGICALIN 0x20
#define EBT_ILOGICALOUT 0x40
#define EBT_INV_MASK (EBT_IPROTO | EBT_IIN | EBT_IOUT | EBT_ILOGICALIN | EBT_ILOGICALOUT | EBT_ISOURCE | EBT_IDEST)
struct ebt_entry_match {
  union {
    struct {
      char name[EBT_EXTENSION_MAXNAMELEN];
      __u8 revision;
    };
    struct xt_match * match;
  } u;
  unsigned int match_size;
  unsigned char data[0] __attribute__((aligned(__alignof__(struct ebt_replace))));
};
struct ebt_entry_watcher {
  union {
    struct {
      char name[EBT_EXTENSION_MAXNAMELEN];
      __u8 revision;
    };
    struct xt_target * watcher;
  } u;
  unsigned int watcher_size;
  unsigned char data[0] __attribute__((aligned(__alignof__(struct ebt_replace))));
};
struct ebt_entry_target {
  union {
    struct {
      char name[EBT_EXTENSION_MAXNAMELEN];
      __u8 revision;
    };
    struct xt_target * target;
  } u;
  unsigned int target_size;
  unsigned char data[0] __attribute__((aligned(__alignof__(struct ebt_replace))));
};
#define EBT_STANDARD_TARGET "standard"
struct ebt_standard_target {
  struct ebt_entry_target target;
  int verdict;
};
struct ebt_entry {
  unsigned int bitmask;
  unsigned int invflags;
  __be16 ethproto;
  char in[IFNAMSIZ];
  char logical_in[IFNAMSIZ];
  char out[IFNAMSIZ];
  char logical_out[IFNAMSIZ];
  unsigned char sourcemac[ETH_ALEN];
  unsigned char sourcemsk[ETH_ALEN];
  unsigned char destmac[ETH_ALEN];
  unsigned char destmsk[ETH_ALEN];
  unsigned int watchers_offset;
  unsigned int target_offset;
  unsigned int next_offset;
  unsigned char elems[0] __attribute__((aligned(__alignof__(struct ebt_replace))));
};
#define EBT_BASE_CTL 128
#define EBT_SO_SET_ENTRIES (EBT_BASE_CTL)
#define EBT_SO_SET_COUNTERS (EBT_SO_SET_ENTRIES + 1)
#define EBT_SO_SET_MAX (EBT_SO_SET_COUNTERS + 1)
#define EBT_SO_GET_INFO (EBT_BASE_CTL)
#define EBT_SO_GET_ENTRIES (EBT_SO_GET_INFO + 1)
#define EBT_SO_GET_INIT_INFO (EBT_SO_GET_ENTRIES + 1)
#define EBT_SO_GET_INIT_ENTRIES (EBT_SO_GET_INIT_INFO + 1)
#define EBT_SO_GET_MAX (EBT_SO_GET_INIT_ENTRIES + 1)
#define EBT_MATCH_ITERATE(e,fn,args...) \
({ unsigned int __i; int __ret = 0; struct ebt_entry_match * __match; for(__i = sizeof(struct ebt_entry); __i < (e)->watchers_offset; __i += __match->match_size + sizeof(struct ebt_entry_match)) { __match = (void *) (e) + __i; __ret = fn(__match, ##args); if(__ret != 0) break; } if(__ret == 0) { if(__i != (e)->watchers_offset) __ret = - EINVAL; } __ret; \
})
#define EBT_WATCHER_ITERATE(e,fn,args...) \
({ unsigned int __i; int __ret = 0; struct ebt_entry_watcher * __watcher; for(__i = e->watchers_offset; __i < (e)->target_offset; __i += __watcher->watcher_size + sizeof(struct ebt_entry_watcher)) { __watcher = (void *) (e) + __i; __ret = fn(__watcher, ##args); if(__ret != 0) break; } if(__ret == 0) { if(__i != (e)->target_offset) __ret = - EINVAL; } __ret; \
})
#define EBT_ENTRY_ITERATE(entries,size,fn,args...) \
({ unsigned int __i; int __ret = 0; struct ebt_entry * __entry; for(__i = 0; __i < (size);) { __entry = (void *) (entries) + __i; __ret = fn(__entry, ##args); if(__ret != 0) break; if(__entry->bitmask != 0) __i += __entry->next_offset; else __i += sizeof(struct ebt_entries); } if(__ret == 0) { if(__i != (size)) __ret = - EINVAL; } __ret; \
})
#endif