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
#ifndef _UAPI_LINUX_TOSHIBA_H
#define _UAPI_LINUX_TOSHIBA_H
#define TOSH_PROC "/proc/toshiba"
#define TOSH_DEVICE "/dev/toshiba"
#define TOSHIBA_ACPI_PROC "/proc/acpi/toshiba"
#define TOSHIBA_ACPI_DEVICE "/dev/toshiba_acpi"
typedef struct {
  unsigned int eax;
  unsigned int ebx __attribute__((packed));
  unsigned int ecx __attribute__((packed));
  unsigned int edx __attribute__((packed));
  unsigned int esi __attribute__((packed));
  unsigned int edi __attribute__((packed));
} SMMRegisters;
#define TOSH_SMM _IOWR('t', 0x90, SMMRegisters)
#define TOSHIBA_ACPI_SCI _IOWR('t', 0x91, SMMRegisters)
#endif