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
#ifndef _FC_FS_H_
#define _FC_FS_H_
#include <linux/types.h>
struct fc_frame_header {
  __u8 fh_r_ctl;
  __u8 fh_d_id[3];
  __u8 fh_cs_ctl;
  __u8 fh_s_id[3];
  __u8 fh_type;
  __u8 fh_f_ctl[3];
  __u8 fh_seq_id;
  __u8 fh_df_ctl;
  __be16 fh_seq_cnt;
  __be16 fh_ox_id;
  __be16 fh_rx_id;
  __be32 fh_parm_offset;
};
#define FC_FRAME_HEADER_LEN 24
#define FC_MAX_PAYLOAD 2112U
#define FC_MIN_MAX_PAYLOAD 256U
#define FC_MAX_FRAME (FC_MAX_PAYLOAD + FC_FRAME_HEADER_LEN)
#define FC_MIN_MAX_FRAME (FC_MIN_MAX_PAYLOAD + FC_FRAME_HEADER_LEN)
enum fc_rctl {
  FC_RCTL_DD_UNCAT = 0x00,
  FC_RCTL_DD_SOL_DATA = 0x01,
  FC_RCTL_DD_UNSOL_CTL = 0x02,
  FC_RCTL_DD_SOL_CTL = 0x03,
  FC_RCTL_DD_UNSOL_DATA = 0x04,
  FC_RCTL_DD_DATA_DESC = 0x05,
  FC_RCTL_DD_UNSOL_CMD = 0x06,
  FC_RCTL_DD_CMD_STATUS = 0x07,
#define FC_RCTL_ILS_REQ FC_RCTL_DD_UNSOL_CTL
#define FC_RCTL_ILS_REP FC_RCTL_DD_SOL_CTL
  FC_RCTL_ELS_REQ = 0x22,
  FC_RCTL_ELS_REP = 0x23,
  FC_RCTL_ELS4_REQ = 0x32,
  FC_RCTL_ELS4_REP = 0x33,
  FC_RCTL_VFTH = 0x50,
  FC_RCTL_IFRH = 0x51,
  FC_RCTL_ENCH = 0x52,
  FC_RCTL_BA_NOP = 0x80,
  FC_RCTL_BA_ABTS = 0x81,
  FC_RCTL_BA_RMC = 0x82,
  FC_RCTL_BA_ACC = 0x84,
  FC_RCTL_BA_RJT = 0x85,
  FC_RCTL_BA_PRMT = 0x86,
  FC_RCTL_ACK_1 = 0xc0,
  FC_RCTL_ACK_0 = 0xc1,
  FC_RCTL_P_RJT = 0xc2,
  FC_RCTL_F_RJT = 0xc3,
  FC_RCTL_P_BSY = 0xc4,
  FC_RCTL_F_BSY = 0xc5,
  FC_RCTL_F_BSYL = 0xc6,
  FC_RCTL_LCR = 0xc7,
  FC_RCTL_END = 0xc9,
};
#define FC_RCTL_NAMES_INIT {[FC_RCTL_DD_UNCAT] = "uncat",[FC_RCTL_DD_SOL_DATA] = "sol data",[FC_RCTL_DD_UNSOL_CTL] = "unsol ctl",[FC_RCTL_DD_SOL_CTL] = "sol ctl/reply",[FC_RCTL_DD_UNSOL_DATA] = "unsol data",[FC_RCTL_DD_DATA_DESC] = "data desc",[FC_RCTL_DD_UNSOL_CMD] = "unsol cmd",[FC_RCTL_DD_CMD_STATUS] = "cmd status",[FC_RCTL_ELS_REQ] = "ELS req",[FC_RCTL_ELS_REP] = "ELS rep",[FC_RCTL_ELS4_REQ] = "FC-4 ELS req",[FC_RCTL_ELS4_REP] = "FC-4 ELS rep",[FC_RCTL_BA_NOP] = "BLS NOP",[FC_RCTL_BA_ABTS] = "BLS abort",[FC_RCTL_BA_RMC] = "BLS remove connection",[FC_RCTL_BA_ACC] = "BLS accept",[FC_RCTL_BA_RJT] = "BLS reject",[FC_RCTL_BA_PRMT] = "BLS dedicated connection preempted",[FC_RCTL_ACK_1] = "LC ACK_1",[FC_RCTL_ACK_0] = "LC ACK_0",[FC_RCTL_P_RJT] = "LC port reject",[FC_RCTL_F_RJT] = "LC fabric reject",[FC_RCTL_P_BSY] = "LC port busy",[FC_RCTL_F_BSY] = "LC fabric busy to data frame",[FC_RCTL_F_BSYL] = "LC fabric busy to link control frame",[FC_RCTL_LCR] = "LC link credit reset",[FC_RCTL_END] = "LC end", \
}
enum fc_well_known_fid {
  FC_FID_NONE = 0x000000,
  FC_FID_BCAST = 0xffffff,
  FC_FID_FLOGI = 0xfffffe,
  FC_FID_FCTRL = 0xfffffd,
  FC_FID_DIR_SERV = 0xfffffc,
  FC_FID_TIME_SERV = 0xfffffb,
  FC_FID_MGMT_SERV = 0xfffffa,
  FC_FID_QOS = 0xfffff9,
  FC_FID_ALIASES = 0xfffff8,
  FC_FID_SEC_KEY = 0xfffff7,
  FC_FID_CLOCK = 0xfffff6,
  FC_FID_MCAST_SERV = 0xfffff5,
};
#define FC_FID_WELL_KNOWN_MAX 0xffffff
#define FC_FID_WELL_KNOWN_BASE 0xfffff5
#define FC_FID_DOM_MGR 0xfffc00
#define FC_FID_DOMAIN 0
#define FC_FID_PORT 1
#define FC_FID_LINK 2
enum fc_fh_type {
  FC_TYPE_BLS = 0x00,
  FC_TYPE_ELS = 0x01,
  FC_TYPE_IP = 0x05,
  FC_TYPE_FCP = 0x08,
  FC_TYPE_CT = 0x20,
  FC_TYPE_ILS = 0x22,
  FC_TYPE_NVME = 0x28,
};
#define FC_TYPE_NAMES_INIT {[FC_TYPE_BLS] = "BLS",[FC_TYPE_ELS] = "ELS",[FC_TYPE_IP] = "IP",[FC_TYPE_FCP] = "FCP",[FC_TYPE_CT] = "CT",[FC_TYPE_ILS] = "ILS",[FC_TYPE_NVME] = "NVME", \
}
#define FC_XID_UNKNOWN 0xffff
#define FC_XID_MIN 0x0
#define FC_XID_MAX 0xfffe
#define FC_FC_EX_CTX (1 << 23)
#define FC_FC_SEQ_CTX (1 << 22)
#define FC_FC_FIRST_SEQ (1 << 21)
#define FC_FC_LAST_SEQ (1 << 20)
#define FC_FC_END_SEQ (1 << 19)
#define FC_FC_END_CONN (1 << 18)
#define FC_FC_RES_B17 (1 << 17)
#define FC_FC_SEQ_INIT (1 << 16)
#define FC_FC_X_ID_REASS (1 << 15)
#define FC_FC_X_ID_INVAL (1 << 14)
#define FC_FC_ACK_1 (1 << 12)
#define FC_FC_ACK_N (2 << 12)
#define FC_FC_ACK_0 (3 << 12)
#define FC_FC_RES_B11 (1 << 11)
#define FC_FC_RES_B10 (1 << 10)
#define FC_FC_RETX_SEQ (1 << 9)
#define FC_FC_UNI_TX (1 << 8)
#define FC_FC_CONT_SEQ(i) ((i) << 6)
#define FC_FC_ABT_SEQ(i) ((i) << 4)
#define FC_FC_REL_OFF (1 << 3)
#define FC_FC_RES2 (1 << 2)
#define FC_FC_FILL(i) ((i) & 3)
struct fc_ba_acc {
  __u8 ba_seq_id_val;
#define FC_BA_SEQ_ID_VAL 0x80
  __u8 ba_seq_id;
  __u8 ba_resvd[2];
  __be16 ba_ox_id;
  __be16 ba_rx_id;
  __be16 ba_low_seq_cnt;
  __be16 ba_high_seq_cnt;
};
struct fc_ba_rjt {
  __u8 br_resvd;
  __u8 br_reason;
  __u8 br_explan;
  __u8 br_vendor;
};
enum fc_ba_rjt_reason {
  FC_BA_RJT_NONE = 0,
  FC_BA_RJT_INVL_CMD = 0x01,
  FC_BA_RJT_LOG_ERR = 0x03,
  FC_BA_RJT_LOG_BUSY = 0x05,
  FC_BA_RJT_PROTO_ERR = 0x07,
  FC_BA_RJT_UNABLE = 0x09,
  FC_BA_RJT_VENDOR = 0xff,
};
enum fc_ba_rjt_explan {
  FC_BA_RJT_EXP_NONE = 0x00,
  FC_BA_RJT_INV_XID = 0x03,
  FC_BA_RJT_ABT = 0x05,
};
struct fc_pf_rjt {
  __u8 rj_action;
  __u8 rj_reason;
  __u8 rj_resvd;
  __u8 rj_vendor;
};
enum fc_pf_rjt_reason {
  FC_RJT_NONE = 0,
  FC_RJT_INVL_DID = 0x01,
  FC_RJT_INVL_SID = 0x02,
  FC_RJT_P_UNAV_T = 0x03,
  FC_RJT_P_UNAV = 0x04,
  FC_RJT_CLS_UNSUP = 0x05,
  FC_RJT_DEL_USAGE = 0x06,
  FC_RJT_TYPE_UNSUP = 0x07,
  FC_RJT_LINK_CTL = 0x08,
  FC_RJT_R_CTL = 0x09,
  FC_RJT_F_CTL = 0x0a,
  FC_RJT_OX_ID = 0x0b,
  FC_RJT_RX_ID = 0x0c,
  FC_RJT_SEQ_ID = 0x0d,
  FC_RJT_DF_CTL = 0x0e,
  FC_RJT_SEQ_CNT = 0x0f,
  FC_RJT_PARAM = 0x10,
  FC_RJT_EXCH_ERR = 0x11,
  FC_RJT_PROTO = 0x12,
  FC_RJT_LEN = 0x13,
  FC_RJT_UNEXP_ACK = 0x14,
  FC_RJT_FAB_CLASS = 0x15,
  FC_RJT_LOGI_REQ = 0x16,
  FC_RJT_SEQ_XS = 0x17,
  FC_RJT_EXCH_EST = 0x18,
  FC_RJT_FAB_UNAV = 0x1a,
  FC_RJT_VC_ID = 0x1b,
  FC_RJT_CS_CTL = 0x1c,
  FC_RJT_INSUF_RES = 0x1d,
  FC_RJT_INVL_CLS = 0x1f,
  FC_RJT_PREEMT_RJT = 0x20,
  FC_RJT_PREEMT_DIS = 0x21,
  FC_RJT_MCAST_ERR = 0x22,
  FC_RJT_MCAST_ET = 0x23,
  FC_RJT_PRLI_REQ = 0x24,
  FC_RJT_INVL_ATT = 0x25,
  FC_RJT_VENDOR = 0xff,
};
#define FC_DEF_E_D_TOV 2000UL
#define FC_DEF_R_A_TOV 10000UL
#endif