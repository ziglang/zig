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
#ifndef _CXLFLASH_IOCTL_H
#define _CXLFLASH_IOCTL_H
#include <linux/types.h>
#define CXLFLASH_WWID_LEN 16
#define DK_CXLFLASH_VERSION_0 0
struct dk_cxlflash_hdr {
  __u16 version;
  __u16 rsvd[3];
  __u64 flags;
  __u64 return_flags;
};
#define DK_CXLFLASH_ALL_PORTS_ACTIVE 0x0000000000000001ULL
#define DK_CXLFLASH_APP_CLOSE_ADAP_FD 0x0000000000000002ULL
#define DK_CXLFLASH_CONTEXT_SQ_CMD_MODE 0x0000000000000004ULL
#define DK_CXLFLASH_ATTACH_REUSE_CONTEXT 0x8000000000000000ULL
struct dk_cxlflash_attach {
  struct dk_cxlflash_hdr hdr;
  __u64 num_interrupts;
  __u64 context_id;
  __u64 mmio_size;
  __u64 block_size;
  __u64 adap_fd;
  __u64 last_lba;
  __u64 max_xfer;
  __u64 reserved[8];
};
struct dk_cxlflash_detach {
  struct dk_cxlflash_hdr hdr;
  __u64 context_id;
  __u64 reserved[8];
};
struct dk_cxlflash_udirect {
  struct dk_cxlflash_hdr hdr;
  __u64 context_id;
  __u64 rsrc_handle;
  __u64 last_lba;
  __u64 reserved[8];
};
#define DK_CXLFLASH_UVIRTUAL_NEED_WRITE_SAME 0x8000000000000000ULL
struct dk_cxlflash_uvirtual {
  struct dk_cxlflash_hdr hdr;
  __u64 context_id;
  __u64 lun_size;
  __u64 rsrc_handle;
  __u64 last_lba;
  __u64 reserved[8];
};
struct dk_cxlflash_release {
  struct dk_cxlflash_hdr hdr;
  __u64 context_id;
  __u64 rsrc_handle;
  __u64 reserved[8];
};
struct dk_cxlflash_resize {
  struct dk_cxlflash_hdr hdr;
  __u64 context_id;
  __u64 rsrc_handle;
  __u64 req_size;
  __u64 last_lba;
  __u64 reserved[8];
};
struct dk_cxlflash_clone {
  struct dk_cxlflash_hdr hdr;
  __u64 context_id_src;
  __u64 context_id_dst;
  __u64 adap_fd_src;
  __u64 reserved[8];
};
#define DK_CXLFLASH_VERIFY_SENSE_LEN 18
#define DK_CXLFLASH_VERIFY_HINT_SENSE 0x8000000000000000ULL
struct dk_cxlflash_verify {
  struct dk_cxlflash_hdr hdr;
  __u64 context_id;
  __u64 rsrc_handle;
  __u64 hint;
  __u64 last_lba;
  __u8 sense_data[DK_CXLFLASH_VERIFY_SENSE_LEN];
  __u8 pad[6];
  __u64 reserved[8];
};
#define DK_CXLFLASH_RECOVER_AFU_CONTEXT_RESET 0x8000000000000000ULL
struct dk_cxlflash_recover_afu {
  struct dk_cxlflash_hdr hdr;
  __u64 reason;
  __u64 context_id;
  __u64 mmio_size;
  __u64 adap_fd;
  __u64 reserved[8];
};
#define DK_CXLFLASH_MANAGE_LUN_WWID_LEN CXLFLASH_WWID_LEN
#define DK_CXLFLASH_MANAGE_LUN_ENABLE_SUPERPIPE 0x8000000000000000ULL
#define DK_CXLFLASH_MANAGE_LUN_DISABLE_SUPERPIPE 0x4000000000000000ULL
#define DK_CXLFLASH_MANAGE_LUN_ALL_PORTS_ACCESSIBLE 0x2000000000000000ULL
struct dk_cxlflash_manage_lun {
  struct dk_cxlflash_hdr hdr;
  __u8 wwid[DK_CXLFLASH_MANAGE_LUN_WWID_LEN];
  __u64 reserved[8];
};
union cxlflash_ioctls {
  struct dk_cxlflash_attach attach;
  struct dk_cxlflash_detach detach;
  struct dk_cxlflash_udirect udirect;
  struct dk_cxlflash_uvirtual uvirtual;
  struct dk_cxlflash_release release;
  struct dk_cxlflash_resize resize;
  struct dk_cxlflash_clone clone;
  struct dk_cxlflash_verify verify;
  struct dk_cxlflash_recover_afu recover_afu;
  struct dk_cxlflash_manage_lun manage_lun;
};
#define MAX_CXLFLASH_IOCTL_SZ (sizeof(union cxlflash_ioctls))
#define CXL_MAGIC 0xCA
#define CXL_IOWR(_n,_s) _IOWR(CXL_MAGIC, _n, struct _s)
#define DK_CXLFLASH_ATTACH CXL_IOWR(0x80, dk_cxlflash_attach)
#define DK_CXLFLASH_USER_DIRECT CXL_IOWR(0x81, dk_cxlflash_udirect)
#define DK_CXLFLASH_RELEASE CXL_IOWR(0x82, dk_cxlflash_release)
#define DK_CXLFLASH_DETACH CXL_IOWR(0x83, dk_cxlflash_detach)
#define DK_CXLFLASH_VERIFY CXL_IOWR(0x84, dk_cxlflash_verify)
#define DK_CXLFLASH_RECOVER_AFU CXL_IOWR(0x85, dk_cxlflash_recover_afu)
#define DK_CXLFLASH_MANAGE_LUN CXL_IOWR(0x86, dk_cxlflash_manage_lun)
#define DK_CXLFLASH_USER_VIRTUAL CXL_IOWR(0x87, dk_cxlflash_uvirtual)
#define DK_CXLFLASH_VLUN_RESIZE CXL_IOWR(0x88, dk_cxlflash_resize)
#define DK_CXLFLASH_VLUN_CLONE CXL_IOWR(0x89, dk_cxlflash_clone)
#define HT_CXLFLASH_VERSION_0 0
struct ht_cxlflash_hdr {
  __u16 version;
  __u16 subcmd;
  __u16 rsvd[2];
  __u64 flags;
  __u64 return_flags;
};
#define HT_CXLFLASH_HOST_READ 0x0000000000000000ULL
#define HT_CXLFLASH_HOST_WRITE 0x0000000000000001ULL
#define HT_CXLFLASH_LUN_PROVISION_SUBCMD_CREATE_LUN 0x0001
#define HT_CXLFLASH_LUN_PROVISION_SUBCMD_DELETE_LUN 0x0002
#define HT_CXLFLASH_LUN_PROVISION_SUBCMD_QUERY_PORT 0x0003
struct ht_cxlflash_lun_provision {
  struct ht_cxlflash_hdr hdr;
  __u16 port;
  __u16 reserved16[3];
  __u64 size;
  __u64 lun_id;
  __u8 wwid[CXLFLASH_WWID_LEN];
  __u64 max_num_luns;
  __u64 cur_num_luns;
  __u64 max_cap_port;
  __u64 cur_cap_port;
  __u64 reserved[8];
};
#define HT_CXLFLASH_AFU_DEBUG_MAX_DATA_LEN 262144
#define HT_CXLFLASH_AFU_DEBUG_SUBCMD_LEN 12
struct ht_cxlflash_afu_debug {
  struct ht_cxlflash_hdr hdr;
  __u8 reserved8[4];
  __u8 afu_subcmd[HT_CXLFLASH_AFU_DEBUG_SUBCMD_LEN];
  __u64 data_ea;
  __u32 data_len;
  __u32 reserved32;
  __u64 reserved[8];
};
union cxlflash_ht_ioctls {
  struct ht_cxlflash_lun_provision lun_provision;
  struct ht_cxlflash_afu_debug afu_debug;
};
#define MAX_HT_CXLFLASH_IOCTL_SZ (sizeof(union cxlflash_ht_ioctls))
#define HT_CXLFLASH_LUN_PROVISION CXL_IOWR(0xBF, ht_cxlflash_lun_provision)
#define HT_CXLFLASH_AFU_DEBUG CXL_IOWR(0xBE, ht_cxlflash_afu_debug)
#endif