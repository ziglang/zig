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
#ifndef _FC_NS_H_
#define _FC_NS_H_
#include <linux/types.h>
#define FC_NS_SUBTYPE 2
enum fc_ns_req {
  FC_NS_GA_NXT = 0x0100,
  FC_NS_GI_A = 0x0101,
  FC_NS_GPN_ID = 0x0112,
  FC_NS_GNN_ID = 0x0113,
  FC_NS_GSPN_ID = 0x0118,
  FC_NS_GID_PN = 0x0121,
  FC_NS_GID_NN = 0x0131,
  FC_NS_GID_FT = 0x0171,
  FC_NS_GPN_FT = 0x0172,
  FC_NS_GID_PT = 0x01a1,
  FC_NS_RPN_ID = 0x0212,
  FC_NS_RNN_ID = 0x0213,
  FC_NS_RFT_ID = 0x0217,
  FC_NS_RSPN_ID = 0x0218,
  FC_NS_RFF_ID = 0x021f,
  FC_NS_RSNN_NN = 0x0239,
};
enum fc_ns_pt {
  FC_NS_UNID_PORT = 0x00,
  FC_NS_N_PORT = 0x01,
  FC_NS_NL_PORT = 0x02,
  FC_NS_FNL_PORT = 0x03,
  FC_NS_NX_PORT = 0x7f,
  FC_NS_F_PORT = 0x81,
  FC_NS_FL_PORT = 0x82,
  FC_NS_E_PORT = 0x84,
  FC_NS_B_PORT = 0x85,
};
struct fc_ns_pt_obj {
  __u8 pt_type;
};
struct fc_ns_fid {
  __u8 fp_flags;
  __u8 fp_fid[3];
};
#define FC_NS_FID_LAST 0x80
#define FC_NS_TYPES 256
#define FC_NS_BPW 32
struct fc_ns_fts {
  __be32 ff_type_map[FC_NS_TYPES / FC_NS_BPW];
};
struct fc_ns_ff {
  __be32 fd_feat[FC_NS_TYPES * 4 / FC_NS_BPW];
};
struct fc_ns_gid_pt {
  __u8 fn_pt_type;
  __u8 fn_domain_id_scope;
  __u8 fn_area_id_scope;
  __u8 fn_resvd;
};
struct fc_ns_gid_ft {
  __u8 fn_resvd;
  __u8 fn_domain_id_scope;
  __u8 fn_area_id_scope;
  __u8 fn_fc4_type;
};
struct fc_gpn_ft_resp {
  __u8 fp_flags;
  __u8 fp_fid[3];
  __be32 fp_resvd;
  __be64 fp_wwpn;
};
struct fc_ns_gid_pn {
  __be64 fn_wwpn;
};
struct fc_gid_pn_resp {
  __u8 fp_resvd;
  __u8 fp_fid[3];
};
struct fc_gspn_resp {
  __u8 fp_name_len;
  char fp_name[];
};
struct fc_ns_rft_id {
  struct fc_ns_fid fr_fid;
  struct fc_ns_fts fr_fts;
};
struct fc_ns_rn_id {
  struct fc_ns_fid fr_fid;
  __be64 fr_wwn;
} __attribute__((__packed__));
struct fc_ns_rsnn {
  __be64 fr_wwn;
  __u8 fr_name_len;
  char fr_name[];
} __attribute__((__packed__));
struct fc_ns_rspn {
  struct fc_ns_fid fr_fid;
  __u8 fr_name_len;
  char fr_name[];
} __attribute__((__packed__));
struct fc_ns_rff_id {
  struct fc_ns_fid fr_fid;
  __u8 fr_resvd[2];
  __u8 fr_feat;
  __u8 fr_type;
} __attribute__((__packed__));
#endif