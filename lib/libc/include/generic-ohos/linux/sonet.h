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
#ifndef _UAPILINUX_SONET_H
#define _UAPILINUX_SONET_H
#define __SONET_ITEMS __HANDLE_ITEM(section_bip); __HANDLE_ITEM(line_bip); __HANDLE_ITEM(path_bip); __HANDLE_ITEM(line_febe); __HANDLE_ITEM(path_febe); __HANDLE_ITEM(corr_hcs); __HANDLE_ITEM(uncorr_hcs); __HANDLE_ITEM(tx_cells); __HANDLE_ITEM(rx_cells);
struct sonet_stats {
#define __HANDLE_ITEM(i) int i
  __SONET_ITEMS
#undef __HANDLE_ITEM
} __attribute__((packed));
#define SONET_GETSTAT _IOR('a', ATMIOC_PHYTYP, struct sonet_stats)
#define SONET_GETSTATZ _IOR('a', ATMIOC_PHYTYP + 1, struct sonet_stats)
#define SONET_SETDIAG _IOWR('a', ATMIOC_PHYTYP + 2, int)
#define SONET_CLRDIAG _IOWR('a', ATMIOC_PHYTYP + 3, int)
#define SONET_GETDIAG _IOR('a', ATMIOC_PHYTYP + 4, int)
#define SONET_SETFRAMING _IOW('a', ATMIOC_PHYTYP + 5, int)
#define SONET_GETFRAMING _IOR('a', ATMIOC_PHYTYP + 6, int)
#define SONET_GETFRSENSE _IOR('a', ATMIOC_PHYTYP + 7, unsigned char[SONET_FRSENSE_SIZE])
#define SONET_INS_SBIP 1
#define SONET_INS_LBIP 2
#define SONET_INS_PBIP 4
#define SONET_INS_FRAME 8
#define SONET_INS_LOS 16
#define SONET_INS_LAIS 32
#define SONET_INS_PAIS 64
#define SONET_INS_HCS 128
#define SONET_FRAME_SONET 0
#define SONET_FRAME_SDH 1
#define SONET_FRSENSE_SIZE 6
#endif