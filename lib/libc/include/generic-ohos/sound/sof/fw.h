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
#ifndef __INCLUDE_UAPI_SOF_FW_H__
#define __INCLUDE_UAPI_SOF_FW_H__
#include <linux/types.h>
#define SND_SOF_FW_SIG_SIZE 4
#define SND_SOF_FW_ABI 1
#define SND_SOF_FW_SIG "Reef"
enum snd_sof_fw_blk_type {
  SOF_FW_BLK_TYPE_INVALID = - 1,
  SOF_FW_BLK_TYPE_START = 0,
  SOF_FW_BLK_TYPE_RSRVD0 = SOF_FW_BLK_TYPE_START,
  SOF_FW_BLK_TYPE_IRAM = 1,
  SOF_FW_BLK_TYPE_DRAM = 2,
  SOF_FW_BLK_TYPE_SRAM = 3,
  SOF_FW_BLK_TYPE_ROM = 4,
  SOF_FW_BLK_TYPE_IMR = 5,
  SOF_FW_BLK_TYPE_RSRVD6 = 6,
  SOF_FW_BLK_TYPE_RSRVD7 = 7,
  SOF_FW_BLK_TYPE_RSRVD8 = 8,
  SOF_FW_BLK_TYPE_RSRVD9 = 9,
  SOF_FW_BLK_TYPE_RSRVD10 = 10,
  SOF_FW_BLK_TYPE_RSRVD11 = 11,
  SOF_FW_BLK_TYPE_RSRVD12 = 12,
  SOF_FW_BLK_TYPE_RSRVD13 = 13,
  SOF_FW_BLK_TYPE_RSRVD14 = 14,
  SOF_FW_BLK_TYPE_NUM
};
struct snd_sof_blk_hdr {
  enum snd_sof_fw_blk_type type;
  __u32 size;
  __u32 offset;
} __packed;
enum snd_sof_fw_mod_type {
  SOF_FW_BASE = 0,
  SOF_FW_MODULE = 1,
};
struct snd_sof_mod_hdr {
  enum snd_sof_fw_mod_type type;
  __u32 size;
  __u32 num_blocks;
} __packed;
struct snd_sof_fw_header {
  unsigned char sig[SND_SOF_FW_SIG_SIZE];
  __u32 file_size;
  __u32 num_modules;
  __u32 abi;
} __packed;
#endif