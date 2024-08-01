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
#ifndef _UAPI_LINUX_SISFB_H_
#define _UAPI_LINUX_SISFB_H_
#include <linux/types.h>
#include <asm/ioctl.h>
#define CRT2_DEFAULT 0x00000001
#define CRT2_LCD 0x00000002
#define CRT2_TV 0x00000004
#define CRT2_VGA 0x00000008
#define TV_NTSC 0x00000010
#define TV_PAL 0x00000020
#define TV_HIVISION 0x00000040
#define TV_YPBPR 0x00000080
#define TV_AVIDEO 0x00000100
#define TV_SVIDEO 0x00000200
#define TV_SCART 0x00000400
#define TV_PALM 0x00001000
#define TV_PALN 0x00002000
#define TV_NTSCJ 0x00001000
#define TV_CHSCART 0x00008000
#define TV_CHYPBPR525I 0x00010000
#define CRT1_VGA 0x00000000
#define CRT1_LCDA 0x00020000
#define VGA2_CONNECTED 0x00040000
#define VB_DISPTYPE_CRT1 0x00080000
#define VB_SINGLE_MODE 0x20000000
#define VB_MIRROR_MODE 0x40000000
#define VB_DUALVIEW_MODE 0x80000000
#define CRT2_ENABLE (CRT2_LCD | CRT2_TV | CRT2_VGA)
#define TV_STANDARD (TV_NTSC | TV_PAL | TV_PALM | TV_PALN | TV_NTSCJ)
#define TV_INTERFACE (TV_AVIDEO | TV_SVIDEO | TV_SCART | TV_HIVISION | TV_YPBPR | TV_CHSCART | TV_CHYPBPR525I)
#define TV_YPBPR525I TV_NTSC
#define TV_YPBPR525P TV_PAL
#define TV_YPBPR750P TV_PALM
#define TV_YPBPR1080I TV_PALN
#define TV_YPBPRALL (TV_YPBPR525I | TV_YPBPR525P | TV_YPBPR750P | TV_YPBPR1080I)
#define VB_DISPTYPE_DISP2 CRT2_ENABLE
#define VB_DISPTYPE_CRT2 CRT2_ENABLE
#define VB_DISPTYPE_DISP1 VB_DISPTYPE_CRT1
#define VB_DISPMODE_SINGLE VB_SINGLE_MODE
#define VB_DISPMODE_MIRROR VB_MIRROR_MODE
#define VB_DISPMODE_DUAL VB_DUALVIEW_MODE
#define VB_DISPLAY_MODE (SINGLE_MODE | MIRROR_MODE | DUALVIEW_MODE)
struct sisfb_info {
  __u32 sisfb_id;
#ifndef SISFB_ID
#define SISFB_ID 0x53495346
#endif
  __u32 chip_id;
  __u32 memory;
  __u32 heapstart;
  __u8 fbvidmode;
  __u8 sisfb_version;
  __u8 sisfb_revision;
  __u8 sisfb_patchlevel;
  __u8 sisfb_caps;
  __u32 sisfb_tqlen;
  __u32 sisfb_pcibus;
  __u32 sisfb_pcislot;
  __u32 sisfb_pcifunc;
  __u8 sisfb_lcdpdc;
  __u8 sisfb_lcda;
  __u32 sisfb_vbflags;
  __u32 sisfb_currentvbflags;
  __u32 sisfb_scalelcd;
  __u32 sisfb_specialtiming;
  __u8 sisfb_haveemi;
  __u8 sisfb_emi30, sisfb_emi31, sisfb_emi32, sisfb_emi33;
  __u8 sisfb_haveemilcd;
  __u8 sisfb_lcdpdca;
  __u16 sisfb_tvxpos, sisfb_tvypos;
  __u32 sisfb_heapsize;
  __u32 sisfb_videooffset;
  __u32 sisfb_curfstn;
  __u32 sisfb_curdstn;
  __u16 sisfb_pci_vendor;
  __u32 sisfb_vbflags2;
  __u8 sisfb_can_post;
  __u8 sisfb_card_posted;
  __u8 sisfb_was_boot_device;
  __u8 reserved[183];
};
#define SISFB_CMD_GETVBFLAGS 0x55AA0001
#define SISFB_CMD_SWITCHCRT1 0x55AA0010
#define SISFB_CMD_ERR_OK 0x80000000
#define SISFB_CMD_ERR_LOCKED 0x80000001
#define SISFB_CMD_ERR_EARLY 0x80000002
#define SISFB_CMD_ERR_NOVB 0x80000003
#define SISFB_CMD_ERR_NOCRT2 0x80000004
#define SISFB_CMD_ERR_UNKNOWN 0x8000ffff
#define SISFB_CMD_ERR_OTHER 0x80010000
struct sisfb_cmd {
  __u32 sisfb_cmd;
  __u32 sisfb_arg[16];
  __u32 sisfb_result[4];
};
#define SISFB_GET_INFO_SIZE _IOR(0xF3, 0x00, __u32)
#define SISFB_GET_INFO _IOR(0xF3, 0x01, struct sisfb_info)
#define SISFB_GET_VBRSTATUS _IOR(0xF3, 0x02, __u32)
#define SISFB_GET_AUTOMAXIMIZE _IOR(0xF3, 0x03, __u32)
#define SISFB_SET_AUTOMAXIMIZE _IOW(0xF3, 0x03, __u32)
#define SISFB_GET_TVPOSOFFSET _IOR(0xF3, 0x04, __u32)
#define SISFB_SET_TVPOSOFFSET _IOW(0xF3, 0x04, __u32)
#define SISFB_COMMAND _IOWR(0xF3, 0x05, struct sisfb_cmd)
#define SISFB_SET_LOCK _IOW(0xF3, 0x06, __u32)
#define SISFB_GET_INFO_OLD _IOR('n', 0xF8, __u32)
#define SISFB_GET_VBRSTATUS_OLD _IOR('n', 0xF9, __u32)
#define SISFB_GET_AUTOMAXIMIZE_OLD _IOR('n', 0xFA, __u32)
#define SISFB_SET_AUTOMAXIMIZE_OLD _IOW('n', 0xFA, __u32)
struct sis_memreq {
  __u32 offset;
  __u32 size;
};
#endif