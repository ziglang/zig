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
#ifndef _UAPI_LINUX_ELF_FDPIC_H
#define _UAPI_LINUX_ELF_FDPIC_H
#include <linux/elf.h>
#define PT_GNU_STACK (PT_LOOS + 0x474e551)
struct elf32_fdpic_loadseg {
  Elf32_Addr addr;
  Elf32_Addr p_vaddr;
  Elf32_Word p_memsz;
};
struct elf32_fdpic_loadmap {
  Elf32_Half version;
  Elf32_Half nsegs;
  struct elf32_fdpic_loadseg segs[];
};
#define ELF32_FDPIC_LOADMAP_VERSION 0x0000
#endif