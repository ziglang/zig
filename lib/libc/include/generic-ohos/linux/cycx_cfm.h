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
#ifndef _CYCX_CFM_H
#define _CYCX_CFM_H
#define CFM_VERSION 2
#define CFM_SIGNATURE "CFM - Cyclades CYCX Firmware Module"
#define CFM_IMAGE_SIZE 0x20000
#define CFM_DESCR_LEN 256
#define CFM_MAX_CYCX 1
#define CFM_LOAD_BUFSZ 0x400
#define GEN_POWER_ON 0x1280
#define GEN_SET_SEG 0x1401
#define GEN_BOOT_DAT 0x1402
#define GEN_START 0x1403
#define GEN_DEFPAR 0x1404
#define CYCX_2X 2
#define CYCX_8X 8
#define CYCX_16X 16
#define CFID_X25_2X 5200
struct cycx_fw_info {
  unsigned short codeid;
  unsigned short version;
  unsigned short adapter[CFM_MAX_CYCX];
  unsigned long memsize;
  unsigned short reserved[2];
  unsigned short startoffs;
  unsigned short winoffs;
  unsigned short codeoffs;
  unsigned long codesize;
  unsigned short dataoffs;
  unsigned long datasize;
};
struct cycx_firmware {
  char signature[80];
  unsigned short version;
  unsigned short checksum;
  unsigned short reserved[6];
  char descr[CFM_DESCR_LEN];
  struct cycx_fw_info info;
  unsigned char image[0];
};
struct cycx_fw_header {
  unsigned long reset_size;
  unsigned long data_size;
  unsigned long code_size;
};
#endif