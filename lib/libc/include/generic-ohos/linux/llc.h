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
#ifndef _UAPI__LINUX_LLC_H
#define _UAPI__LINUX_LLC_H
#include <linux/socket.h>
#include <linux/if.h>
#define __LLC_SOCK_SIZE__ 16
struct sockaddr_llc {
  __kernel_sa_family_t sllc_family;
  __kernel_sa_family_t sllc_arphrd;
  unsigned char sllc_test;
  unsigned char sllc_xid;
  unsigned char sllc_ua;
  unsigned char sllc_sap;
  unsigned char sllc_mac[IFHWADDRLEN];
  unsigned char __pad[__LLC_SOCK_SIZE__ - sizeof(__kernel_sa_family_t) * 2 - sizeof(unsigned char) * 4 - IFHWADDRLEN];
};
enum llc_sockopts {
  LLC_OPT_UNKNOWN = 0,
  LLC_OPT_RETRY,
  LLC_OPT_SIZE,
  LLC_OPT_ACK_TMR_EXP,
  LLC_OPT_P_TMR_EXP,
  LLC_OPT_REJ_TMR_EXP,
  LLC_OPT_BUSY_TMR_EXP,
  LLC_OPT_TX_WIN,
  LLC_OPT_RX_WIN,
  LLC_OPT_PKTINFO,
  LLC_OPT_MAX
};
#define LLC_OPT_MAX_RETRY 100
#define LLC_OPT_MAX_SIZE 4196
#define LLC_OPT_MAX_WIN 127
#define LLC_OPT_MAX_ACK_TMR_EXP 60
#define LLC_OPT_MAX_P_TMR_EXP 60
#define LLC_OPT_MAX_REJ_TMR_EXP 60
#define LLC_OPT_MAX_BUSY_TMR_EXP 60
#define LLC_SAP_NULL 0x00
#define LLC_SAP_LLC 0x02
#define LLC_SAP_SNA 0x04
#define LLC_SAP_PNM 0x0E
#define LLC_SAP_IP 0x06
#define LLC_SAP_BSPAN 0x42
#define LLC_SAP_MMS 0x4E
#define LLC_SAP_8208 0x7E
#define LLC_SAP_3COM 0x80
#define LLC_SAP_PRO 0x8E
#define LLC_SAP_SNAP 0xAA
#define LLC_SAP_BANYAN 0xBC
#define LLC_SAP_IPX 0xE0
#define LLC_SAP_NETBEUI 0xF0
#define LLC_SAP_LANMGR 0xF4
#define LLC_SAP_IMPL 0xF8
#define LLC_SAP_DISC 0xFC
#define LLC_SAP_OSI 0xFE
#define LLC_SAP_LAR 0xDC
#define LLC_SAP_RM 0xD4
#define LLC_SAP_GLOBAL 0xFF
struct llc_pktinfo {
  int lpi_ifindex;
  unsigned char lpi_sap;
  unsigned char lpi_mac[IFHWADDRLEN];
};
#endif