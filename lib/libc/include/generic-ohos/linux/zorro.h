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
#ifndef _UAPI_LINUX_ZORRO_H
#define _UAPI_LINUX_ZORRO_H
#include <linux/types.h>
#define ZORRO_MANUF(id) ((id) >> 16)
#define ZORRO_PROD(id) (((id) >> 8) & 0xff)
#define ZORRO_EPC(id) ((id) & 0xff)
#define ZORRO_ID(manuf,prod,epc) ((ZORRO_MANUF_ ##manuf << 16) | ((prod) << 8) | (epc))
typedef __u32 zorro_id;
#include <linux/zorro_ids.h>
#define GVP_PRODMASK (0xf8)
#define GVP_SCSICLKMASK (0x01)
enum GVP_flags {
  GVP_IO = 0x01,
  GVP_ACCEL = 0x02,
  GVP_SCSI = 0x04,
  GVP_24BITDMA = 0x08,
  GVP_25BITDMA = 0x10,
  GVP_NOBANK = 0x20,
  GVP_14MHZ = 0x40,
};
struct Node {
  __be32 ln_Succ;
  __be32 ln_Pred;
  __u8 ln_Type;
  __s8 ln_Pri;
  __be32 ln_Name;
} __packed;
struct ExpansionRom {
  __u8 er_Type;
  __u8 er_Product;
  __u8 er_Flags;
  __u8 er_Reserved03;
  __be16 er_Manufacturer;
  __be32 er_SerialNumber;
  __be16 er_InitDiagVec;
  __u8 er_Reserved0c;
  __u8 er_Reserved0d;
  __u8 er_Reserved0e;
  __u8 er_Reserved0f;
} __packed;
#define ERT_TYPEMASK 0xc0
#define ERT_ZORROII 0xc0
#define ERT_ZORROIII 0x80
#define ERTB_MEMLIST 5
#define ERTF_MEMLIST (1 << 5)
struct ConfigDev {
  struct Node cd_Node;
  __u8 cd_Flags;
  __u8 cd_Pad;
  struct ExpansionRom cd_Rom;
  __be32 cd_BoardAddr;
  __be32 cd_BoardSize;
  __be16 cd_SlotAddr;
  __be16 cd_SlotSize;
  __be32 cd_Driver;
  __be32 cd_NextCD;
  __be32 cd_Unused[4];
} __packed;
#define ZORRO_NUM_AUTO 16
#endif