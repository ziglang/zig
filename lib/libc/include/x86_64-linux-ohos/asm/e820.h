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
#ifndef _UAPI_ASM_X86_E820_H
#define _UAPI_ASM_X86_E820_H
#define E820MAP 0x2d0
#define E820MAX 128
#define E820_X_MAX E820MAX
#define E820NR 0x1e8
#define E820_RAM 1
#define E820_RESERVED 2
#define E820_ACPI 3
#define E820_NVS 4
#define E820_UNUSABLE 5
#define E820_PMEM 7
#define E820_PRAM 12
#define E820_RESERVED_KERN 128
#ifndef __ASSEMBLY__
#include <linux/types.h>
struct e820entry {
  __u64 addr;
  __u64 size;
  __u32 type;
} __attribute__((packed));
struct e820map {
  __u32 nr_map;
  struct e820entry map[E820_X_MAX];
};
#define ISA_START_ADDRESS 0xa0000
#define ISA_END_ADDRESS 0x100000
#define BIOS_BEGIN 0x000a0000
#define BIOS_END 0x00100000
#define BIOS_ROM_BASE 0xffe00000
#define BIOS_ROM_END 0xffffffff
#endif
#endif
