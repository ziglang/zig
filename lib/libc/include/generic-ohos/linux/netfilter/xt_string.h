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
#ifndef _XT_STRING_H
#define _XT_STRING_H
#include <linux/types.h>
#define XT_STRING_MAX_PATTERN_SIZE 128
#define XT_STRING_MAX_ALGO_NAME_SIZE 16
enum {
  XT_STRING_FLAG_INVERT = 0x01,
  XT_STRING_FLAG_IGNORECASE = 0x02
};
struct xt_string_info {
  __u16 from_offset;
  __u16 to_offset;
  char algo[XT_STRING_MAX_ALGO_NAME_SIZE];
  char pattern[XT_STRING_MAX_PATTERN_SIZE];
  __u8 patlen;
  union {
    struct {
      __u8 invert;
    } v0;
    struct {
      __u8 flags;
    } v1;
  } u;
  struct ts_config __attribute__((aligned(8))) * config;
};
#endif