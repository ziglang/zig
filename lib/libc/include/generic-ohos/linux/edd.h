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
#ifndef _UAPI_LINUX_EDD_H
#define _UAPI_LINUX_EDD_H
#include <linux/types.h>
#define EDDNR 0x1e9
#define EDDBUF 0xd00
#define EDDMAXNR 6
#define EDDEXTSIZE 8
#define EDDPARMSIZE 74
#define CHECKEXTENSIONSPRESENT 0x41
#define GETDEVICEPARAMETERS 0x48
#define LEGACYGETDEVICEPARAMETERS 0x08
#define EDDMAGIC1 0x55AA
#define EDDMAGIC2 0xAA55
#define READ_SECTORS 0x02
#define EDD_MBR_SIG_OFFSET 0x1B8
#define EDD_MBR_SIG_BUF 0x290
#define EDD_MBR_SIG_MAX 16
#define EDD_MBR_SIG_NR_BUF 0x1ea
#ifndef __ASSEMBLY__
#define EDD_EXT_FIXED_DISK_ACCESS (1 << 0)
#define EDD_EXT_DEVICE_LOCKING_AND_EJECTING (1 << 1)
#define EDD_EXT_ENHANCED_DISK_DRIVE_SUPPORT (1 << 2)
#define EDD_EXT_64BIT_EXTENSIONS (1 << 3)
#define EDD_INFO_DMA_BOUNDARY_ERROR_TRANSPARENT (1 << 0)
#define EDD_INFO_GEOMETRY_VALID (1 << 1)
#define EDD_INFO_REMOVABLE (1 << 2)
#define EDD_INFO_WRITE_VERIFY (1 << 3)
#define EDD_INFO_MEDIA_CHANGE_NOTIFICATION (1 << 4)
#define EDD_INFO_LOCKABLE (1 << 5)
#define EDD_INFO_NO_MEDIA_PRESENT (1 << 6)
#define EDD_INFO_USE_INT13_FN50 (1 << 7)
struct edd_device_params {
  __u16 length;
  __u16 info_flags;
  __u32 num_default_cylinders;
  __u32 num_default_heads;
  __u32 sectors_per_track;
  __u64 number_of_sectors;
  __u16 bytes_per_sector;
  __u32 dpte_ptr;
  __u16 key;
  __u8 device_path_info_length;
  __u8 reserved2;
  __u16 reserved3;
  __u8 host_bus_type[4];
  __u8 interface_type[8];
  union {
    struct {
      __u16 base_address;
      __u16 reserved1;
      __u32 reserved2;
    } __attribute__((packed)) isa;
    struct {
      __u8 bus;
      __u8 slot;
      __u8 function;
      __u8 channel;
      __u32 reserved;
    } __attribute__((packed)) pci;
    struct {
      __u64 reserved;
    } __attribute__((packed)) ibnd;
    struct {
      __u64 reserved;
    } __attribute__((packed)) xprs;
    struct {
      __u64 reserved;
    } __attribute__((packed)) htpt;
    struct {
      __u64 reserved;
    } __attribute__((packed)) unknown;
  } interface_path;
  union {
    struct {
      __u8 device;
      __u8 reserved1;
      __u16 reserved2;
      __u32 reserved3;
      __u64 reserved4;
    } __attribute__((packed)) ata;
    struct {
      __u8 device;
      __u8 lun;
      __u8 reserved1;
      __u8 reserved2;
      __u32 reserved3;
      __u64 reserved4;
    } __attribute__((packed)) atapi;
    struct {
      __u16 id;
      __u64 lun;
      __u16 reserved1;
      __u32 reserved2;
    } __attribute__((packed)) scsi;
    struct {
      __u64 serial_number;
      __u64 reserved;
    } __attribute__((packed)) usb;
    struct {
      __u64 eui;
      __u64 reserved;
    } __attribute__((packed)) i1394;
    struct {
      __u64 wwid;
      __u64 lun;
    } __attribute__((packed)) fibre;
    struct {
      __u64 identity_tag;
      __u64 reserved;
    } __attribute__((packed)) i2o;
    struct {
      __u32 array_number;
      __u32 reserved1;
      __u64 reserved2;
    } __attribute__((packed)) raid;
    struct {
      __u8 device;
      __u8 reserved1;
      __u16 reserved2;
      __u32 reserved3;
      __u64 reserved4;
    } __attribute__((packed)) sata;
    struct {
      __u64 reserved1;
      __u64 reserved2;
    } __attribute__((packed)) unknown;
  } device_path;
  __u8 reserved4;
  __u8 checksum;
} __attribute__((packed));
struct edd_info {
  __u8 device;
  __u8 version;
  __u16 interface_support;
  __u16 legacy_max_cylinder;
  __u8 legacy_max_head;
  __u8 legacy_sectors_per_track;
  struct edd_device_params params;
} __attribute__((packed));
struct edd {
  unsigned int mbr_signature[EDD_MBR_SIG_MAX];
  struct edd_info edd_info[EDDMAXNR];
  unsigned char mbr_signature_nr;
  unsigned char edd_info_nr;
};
#endif
#endif