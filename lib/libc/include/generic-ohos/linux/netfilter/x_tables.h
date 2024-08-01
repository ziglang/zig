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
#ifndef _UAPI_X_TABLES_H
#define _UAPI_X_TABLES_H
#include <linux/kernel.h>
#include <linux/types.h>
#define XT_FUNCTION_MAXNAMELEN 30
#define XT_EXTENSION_MAXNAMELEN 29
#define XT_TABLE_MAXNAMELEN 32
struct xt_entry_match {
  union {
    struct {
      __u16 match_size;
      char name[XT_EXTENSION_MAXNAMELEN];
      __u8 revision;
    } user;
    struct {
      __u16 match_size;
      struct xt_match * match;
    } kernel;
    __u16 match_size;
  } u;
  unsigned char data[0];
};
struct xt_entry_target {
  union {
    struct {
      __u16 target_size;
      char name[XT_EXTENSION_MAXNAMELEN];
      __u8 revision;
    } user;
    struct {
      __u16 target_size;
      struct xt_target * target;
    } kernel;
    __u16 target_size;
  } u;
  unsigned char data[0];
};
#define XT_TARGET_INIT(__name,__size) \
{.target.u.user = {.target_size = XT_ALIGN(__size),.name = __name, }, \
}
struct xt_standard_target {
  struct xt_entry_target target;
  int verdict;
};
struct xt_error_target {
  struct xt_entry_target target;
  char errorname[XT_FUNCTION_MAXNAMELEN];
};
struct xt_get_revision {
  char name[XT_EXTENSION_MAXNAMELEN];
  __u8 revision;
};
#define XT_CONTINUE 0xFFFFFFFF
#define XT_RETURN (- NF_REPEAT - 1)
struct _xt_align {
  __u8 u8;
  __u16 u16;
  __u32 u32;
  __u64 u64;
};
#define XT_ALIGN(s) __ALIGN_KERNEL((s), __alignof__(struct _xt_align))
#define XT_STANDARD_TARGET ""
#define XT_ERROR_TARGET "ERROR"
#define SET_COUNTER(c,b,p) do { (c).bcnt = (b); (c).pcnt = (p); } while(0)
#define ADD_COUNTER(c,b,p) do { (c).bcnt += (b); (c).pcnt += (p); } while(0)
struct xt_counters {
  __u64 pcnt, bcnt;
};
struct xt_counters_info {
  char name[XT_TABLE_MAXNAMELEN];
  unsigned int num_counters;
  struct xt_counters counters[0];
};
#define XT_INV_PROTO 0x40
#define XT_MATCH_ITERATE(type,e,fn,args...) \
({ unsigned int __i; int __ret = 0; struct xt_entry_match * __m; for(__i = sizeof(type); __i < (e)->target_offset; __i += __m->u.match_size) { __m = (void *) e + __i; __ret = fn(__m, ##args); if(__ret != 0) break; } __ret; \
})
#define XT_ENTRY_ITERATE_CONTINUE(type,entries,size,n,fn,args...) \
({ unsigned int __i, __n; int __ret = 0; type * __entry; for(__i = 0, __n = 0; __i < (size); __i += __entry->next_offset, __n ++) { __entry = (void *) (entries) + __i; if(__n < n) continue; __ret = fn(__entry, ##args); if(__ret != 0) break; } __ret; \
})
#define XT_ENTRY_ITERATE(type,entries,size,fn,args...) XT_ENTRY_ITERATE_CONTINUE(type, entries, size, 0, fn, args)
#define xt_entry_foreach(pos,ehead,esize) for((pos) = (typeof(pos)) (ehead); (pos) < (typeof(pos)) ((char *) (ehead) + (esize)); (pos) = (typeof(pos)) ((char *) (pos) + (pos)->next_offset))
#define xt_ematch_foreach(pos,entry) for((pos) = (struct xt_entry_match *) entry->elems; (pos) < (struct xt_entry_match *) ((char *) (entry) + (entry)->target_offset); (pos) = (struct xt_entry_match *) ((char *) (pos) + (pos)->u.match_size))
#endif