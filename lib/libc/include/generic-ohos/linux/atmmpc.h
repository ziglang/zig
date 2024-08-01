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
#ifndef _ATMMPC_H_
#define _ATMMPC_H_
#include <linux/atmapi.h>
#include <linux/atmioc.h>
#include <linux/atm.h>
#include <linux/types.h>
#define ATMMPC_CTRL _IO('a', ATMIOC_MPOA)
#define ATMMPC_DATA _IO('a', ATMIOC_MPOA + 1)
#define MPC_SOCKET_INGRESS 1
#define MPC_SOCKET_EGRESS 2
struct atmmpc_ioc {
  int dev_num;
  __be32 ipaddr;
  int type;
};
typedef struct in_ctrl_info {
  __u8 Last_NHRP_CIE_code;
  __u8 Last_Q2931_cause_value;
  __u8 eg_MPC_ATM_addr[ATM_ESA_LEN];
  __be32 tag;
  __be32 in_dst_ip;
  __u16 holding_time;
  __u32 request_id;
} in_ctrl_info;
typedef struct eg_ctrl_info {
  __u8 DLL_header[256];
  __u8 DH_length;
  __be32 cache_id;
  __be32 tag;
  __be32 mps_ip;
  __be32 eg_dst_ip;
  __u8 in_MPC_data_ATM_addr[ATM_ESA_LEN];
  __u16 holding_time;
} eg_ctrl_info;
struct mpc_parameters {
  __u16 mpc_p1;
  __u16 mpc_p2;
  __u8 mpc_p3[8];
  __u16 mpc_p4;
  __u16 mpc_p5;
  __u16 mpc_p6;
};
struct k_message {
  __u16 type;
  __be32 ip_mask;
  __u8 MPS_ctrl[ATM_ESA_LEN];
  union {
    in_ctrl_info in_info;
    eg_ctrl_info eg_info;
    struct mpc_parameters params;
  } content;
  struct atm_qos qos;
} __ATM_API_ALIGN;
struct llc_snap_hdr {
  __u8 dsap;
  __u8 ssap;
  __u8 ui;
  __u8 org[3];
  __u8 type[2];
};
#define TLV_MPOA_DEVICE_TYPE 0x00a03e2a
#define NON_MPOA 0
#define MPS 1
#define MPC 2
#define MPS_AND_MPC 3
#define MPC_P1 10
#define MPC_P2 1
#define MPC_P3 0
#define MPC_P4 5
#define MPC_P5 40
#define MPC_P6 160
#define HOLDING_TIME_DEFAULT 1200
#define MPC_C1 2
#define MPC_C2 60
#define SND_MPOA_RES_RQST 201
#define SET_MPS_CTRL_ADDR 202
#define SND_MPOA_RES_RTRY 203
#define STOP_KEEP_ALIVE_SM 204
#define EGRESS_ENTRY_REMOVED 205
#define SND_EGRESS_PURGE 206
#define DIE 207
#define DATA_PLANE_PURGE 208
#define OPEN_INGRESS_SVC 209
#define MPOA_TRIGGER_RCVD 101
#define MPOA_RES_REPLY_RCVD 102
#define INGRESS_PURGE_RCVD 103
#define EGRESS_PURGE_RCVD 104
#define MPS_DEATH 105
#define CACHE_IMPOS_RCVD 106
#define SET_MPC_CTRL_ADDR 107
#define SET_MPS_MAC_ADDR 108
#define CLEAN_UP_AND_EXIT 109
#define SET_MPC_PARAMS 110
#define RELOAD 301
#endif