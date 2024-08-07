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
#ifndef SCSI_BSG_FC_H
#define SCSI_BSG_FC_H
#include <linux/types.h>
#define FC_DEFAULT_BSG_TIMEOUT (10 * HZ)
#define FC_BSG_CLS_MASK 0xF0000000
#define FC_BSG_HST_MASK 0x80000000
#define FC_BSG_RPT_MASK 0x40000000
#define FC_BSG_HST_ADD_RPORT (FC_BSG_HST_MASK | 0x00000001)
#define FC_BSG_HST_DEL_RPORT (FC_BSG_HST_MASK | 0x00000002)
#define FC_BSG_HST_ELS_NOLOGIN (FC_BSG_HST_MASK | 0x00000003)
#define FC_BSG_HST_CT (FC_BSG_HST_MASK | 0x00000004)
#define FC_BSG_HST_VENDOR (FC_BSG_HST_MASK | 0x000000FF)
#define FC_BSG_RPT_ELS (FC_BSG_RPT_MASK | 0x00000001)
#define FC_BSG_RPT_CT (FC_BSG_RPT_MASK | 0x00000002)
struct fc_bsg_host_add_rport {
  __u8 reserved;
  __u8 port_id[3];
};
struct fc_bsg_host_del_rport {
  __u8 reserved;
  __u8 port_id[3];
};
struct fc_bsg_host_els {
  __u8 command_code;
  __u8 port_id[3];
};
#define FC_CTELS_STATUS_OK 0x00000000
#define FC_CTELS_STATUS_REJECT 0x00000001
#define FC_CTELS_STATUS_P_RJT 0x00000002
#define FC_CTELS_STATUS_F_RJT 0x00000003
#define FC_CTELS_STATUS_P_BSY 0x00000004
#define FC_CTELS_STATUS_F_BSY 0x00000006
struct fc_bsg_ctels_reply {
  __u32 status;
  struct {
    __u8 action;
    __u8 reason_code;
    __u8 reason_explanation;
    __u8 vendor_unique;
  } rjt_data;
};
struct fc_bsg_host_ct {
  __u8 reserved;
  __u8 port_id[3];
  __u32 preamble_word0;
  __u32 preamble_word1;
  __u32 preamble_word2;
};
struct fc_bsg_host_vendor {
  __u64 vendor_id;
  __u32 vendor_cmd[0];
};
struct fc_bsg_host_vendor_reply {
  __u32 vendor_rsp[0];
};
struct fc_bsg_rport_els {
  __u8 els_code;
};
struct fc_bsg_rport_ct {
  __u32 preamble_word0;
  __u32 preamble_word1;
  __u32 preamble_word2;
};
struct fc_bsg_request {
  __u32 msgcode;
  union {
    struct fc_bsg_host_add_rport h_addrport;
    struct fc_bsg_host_del_rport h_delrport;
    struct fc_bsg_host_els h_els;
    struct fc_bsg_host_ct h_ct;
    struct fc_bsg_host_vendor h_vendor;
    struct fc_bsg_rport_els r_els;
    struct fc_bsg_rport_ct r_ct;
  } rqst_data;
} __attribute__((packed));
struct fc_bsg_reply {
  __u32 result;
  __u32 reply_payload_rcv_len;
  union {
    struct fc_bsg_host_vendor_reply vendor_reply;
    struct fc_bsg_ctels_reply ctels_reply;
  } reply_data;
};
#endif