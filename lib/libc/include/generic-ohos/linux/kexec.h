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
#ifndef _UAPILINUX_KEXEC_H
#define _UAPILINUX_KEXEC_H
#include <linux/types.h>
#define KEXEC_ON_CRASH 0x00000001
#define KEXEC_PRESERVE_CONTEXT 0x00000002
#define KEXEC_ARCH_MASK 0xffff0000
#define KEXEC_FILE_UNLOAD 0x00000001
#define KEXEC_FILE_ON_CRASH 0x00000002
#define KEXEC_FILE_NO_INITRAMFS 0x00000004
#define KEXEC_ARCH_DEFAULT (0 << 16)
#define KEXEC_ARCH_386 (3 << 16)
#define KEXEC_ARCH_68K (4 << 16)
#define KEXEC_ARCH_PARISC (15 << 16)
#define KEXEC_ARCH_X86_64 (62 << 16)
#define KEXEC_ARCH_PPC (20 << 16)
#define KEXEC_ARCH_PPC64 (21 << 16)
#define KEXEC_ARCH_IA_64 (50 << 16)
#define KEXEC_ARCH_ARM (40 << 16)
#define KEXEC_ARCH_S390 (22 << 16)
#define KEXEC_ARCH_SH (42 << 16)
#define KEXEC_ARCH_MIPS_LE (10 << 16)
#define KEXEC_ARCH_MIPS (8 << 16)
#define KEXEC_ARCH_AARCH64 (183 << 16)
#define KEXEC_SEGMENT_MAX 16
struct kexec_segment {
  const void * buf;
  size_t bufsz;
  const void * mem;
  size_t memsz;
};
#endif