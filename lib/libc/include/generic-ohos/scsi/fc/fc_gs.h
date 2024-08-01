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
#ifndef _FC_GS_H_
#define _FC_GS_H_
#include <linux/types.h>
struct fc_ct_hdr {
  __u8 ct_rev;
  __u8 ct_in_id[3];
  __u8 ct_fs_type;
  __u8 ct_fs_subtype;
  __u8 ct_options;
  __u8 _ct_resvd1;
  __be16 ct_cmd;
  __be16 ct_mr_size;
  __u8 _ct_resvd2;
  __u8 ct_reason;
  __u8 ct_explan;
  __u8 ct_vendor;
};
#define FC_CT_HDR_LEN 16
enum fc_ct_rev {
  FC_CT_REV = 1
};
enum fc_ct_fs_type {
  FC_FST_ALIAS = 0xf8,
  FC_FST_MGMT = 0xfa,
  FC_FST_TIME = 0xfb,
  FC_FST_DIR = 0xfc,
};
enum fc_ct_cmd {
  FC_FS_RJT = 0x8001,
  FC_FS_ACC = 0x8002,
};
enum fc_ct_reason {
  FC_FS_RJT_CMD = 0x01,
  FC_FS_RJT_VER = 0x02,
  FC_FS_RJT_LOG = 0x03,
  FC_FS_RJT_IUSIZ = 0x04,
  FC_FS_RJT_BSY = 0x05,
  FC_FS_RJT_PROTO = 0x07,
  FC_FS_RJT_UNABL = 0x09,
  FC_FS_RJT_UNSUP = 0x0b,
};
enum fc_ct_explan {
  FC_FS_EXP_NONE = 0x00,
  FC_FS_EXP_PID = 0x01,
  FC_FS_EXP_PNAM = 0x02,
  FC_FS_EXP_NNAM = 0x03,
  FC_FS_EXP_COS = 0x04,
  FC_FS_EXP_FTNR = 0x07,
};
#endif