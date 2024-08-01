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
#ifndef __UAPI_LINUX_PCITEST_H
#define __UAPI_LINUX_PCITEST_H
#define PCITEST_BAR _IO('P', 0x1)
#define PCITEST_LEGACY_IRQ _IO('P', 0x2)
#define PCITEST_MSI _IOW('P', 0x3, int)
#define PCITEST_WRITE _IOW('P', 0x4, unsigned long)
#define PCITEST_READ _IOW('P', 0x5, unsigned long)
#define PCITEST_COPY _IOW('P', 0x6, unsigned long)
#define PCITEST_MSIX _IOW('P', 0x7, int)
#define PCITEST_SET_IRQTYPE _IOW('P', 0x8, int)
#define PCITEST_GET_IRQTYPE _IO('P', 0x9)
#define PCITEST_CLEAR_IRQ _IO('P', 0x10)
#define PCITEST_FLAGS_USE_DMA 0x00000001
struct pci_endpoint_test_xfer_param {
  unsigned long size;
  unsigned char flags;
};
#endif