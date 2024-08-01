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
#ifndef _UAPI_LINUX_UDP_H
#define _UAPI_LINUX_UDP_H
#include <linux/types.h>
struct __kernel_udphdr {
  __be16 source;
  __be16 dest;
  __be16 len;
  __sum16 check;
};
#define UDP_CORK 1
#define UDP_ENCAP 100
#define UDP_NO_CHECK6_TX 101
#define UDP_NO_CHECK6_RX 102
#define UDP_SEGMENT 103
#define UDP_GRO 104
#define UDP_ENCAP_ESPINUDP_NON_IKE 1
#define UDP_ENCAP_ESPINUDP 2
#define UDP_ENCAP_L2TPINUDP 3
#define UDP_ENCAP_GTP0 4
#define UDP_ENCAP_GTP1U 5
#define UDP_ENCAP_RXRPC 6
#define TCP_ENCAP_ESPINTCP 7
#endif