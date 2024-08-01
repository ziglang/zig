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
#ifndef _UAPI__LINUX_BTF_H__
#define _UAPI__LINUX_BTF_H__
#include <linux/types.h>
#define BTF_MAGIC 0xeB9F
#define BTF_VERSION 1
struct btf_header {
  __u16 magic;
  __u8 version;
  __u8 flags;
  __u32 hdr_len;
  __u32 type_off;
  __u32 type_len;
  __u32 str_off;
  __u32 str_len;
};
#define BTF_MAX_TYPE 0x000fffff
#define BTF_MAX_NAME_OFFSET 0x00ffffff
#define BTF_MAX_VLEN 0xffff
struct btf_type {
  __u32 name_off;
  __u32 info;
  union {
    __u32 size;
    __u32 type;
  };
};
#define BTF_INFO_KIND(info) (((info) >> 24) & 0x0f)
#define BTF_INFO_VLEN(info) ((info) & 0xffff)
#define BTF_INFO_KFLAG(info) ((info) >> 31)
#define BTF_KIND_UNKN 0
#define BTF_KIND_INT 1
#define BTF_KIND_PTR 2
#define BTF_KIND_ARRAY 3
#define BTF_KIND_STRUCT 4
#define BTF_KIND_UNION 5
#define BTF_KIND_ENUM 6
#define BTF_KIND_FWD 7
#define BTF_KIND_TYPEDEF 8
#define BTF_KIND_VOLATILE 9
#define BTF_KIND_CONST 10
#define BTF_KIND_RESTRICT 11
#define BTF_KIND_FUNC 12
#define BTF_KIND_FUNC_PROTO 13
#define BTF_KIND_VAR 14
#define BTF_KIND_DATASEC 15
#define BTF_KIND_MAX BTF_KIND_DATASEC
#define NR_BTF_KINDS (BTF_KIND_MAX + 1)
#define BTF_INT_ENCODING(VAL) (((VAL) & 0x0f000000) >> 24)
#define BTF_INT_OFFSET(VAL) (((VAL) & 0x00ff0000) >> 16)
#define BTF_INT_BITS(VAL) ((VAL) & 0x000000ff)
#define BTF_INT_SIGNED (1 << 0)
#define BTF_INT_CHAR (1 << 1)
#define BTF_INT_BOOL (1 << 2)
struct btf_enum {
  __u32 name_off;
  __s32 val;
};
struct btf_array {
  __u32 type;
  __u32 index_type;
  __u32 nelems;
};
struct btf_member {
  __u32 name_off;
  __u32 type;
  __u32 offset;
};
#define BTF_MEMBER_BITFIELD_SIZE(val) ((val) >> 24)
#define BTF_MEMBER_BIT_OFFSET(val) ((val) & 0xffffff)
struct btf_param {
  __u32 name_off;
  __u32 type;
};
enum {
  BTF_VAR_STATIC = 0,
  BTF_VAR_GLOBAL_ALLOCATED = 1,
  BTF_VAR_GLOBAL_EXTERN = 2,
};
enum btf_func_linkage {
  BTF_FUNC_STATIC = 0,
  BTF_FUNC_GLOBAL = 1,
  BTF_FUNC_EXTERN = 2,
};
struct btf_var {
  __u32 linkage;
};
struct btf_var_secinfo {
  __u32 type;
  __u32 offset;
  __u32 size;
};
#endif