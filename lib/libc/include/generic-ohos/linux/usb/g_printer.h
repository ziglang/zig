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
#ifndef __LINUX_USB_G_PRINTER_H
#define __LINUX_USB_G_PRINTER_H
#define PRINTER_NOT_ERROR 0x08
#define PRINTER_SELECTED 0x10
#define PRINTER_PAPER_EMPTY 0x20
#define GADGET_GET_PRINTER_STATUS _IOR('g', 0x21, unsigned char)
#define GADGET_SET_PRINTER_STATUS _IOWR('g', 0x22, unsigned char)
#endif