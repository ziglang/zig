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
#ifndef _UAPI_LINUX_ICMP_H
#define _UAPI_LINUX_ICMP_H
#include <linux/types.h>
#include <asm/byteorder.h>
#define ICMP_ECHOREPLY 0
#define ICMP_DEST_UNREACH 3
#define ICMP_SOURCE_QUENCH 4
#define ICMP_REDIRECT 5
#define ICMP_ECHO 8
#define ICMP_TIME_EXCEEDED 11
#define ICMP_PARAMETERPROB 12
#define ICMP_TIMESTAMP 13
#define ICMP_TIMESTAMPREPLY 14
#define ICMP_INFO_REQUEST 15
#define ICMP_INFO_REPLY 16
#define ICMP_ADDRESS 17
#define ICMP_ADDRESSREPLY 18
#define NR_ICMP_TYPES 18
#define ICMP_NET_UNREACH 0
#define ICMP_HOST_UNREACH 1
#define ICMP_PROT_UNREACH 2
#define ICMP_PORT_UNREACH 3
#define ICMP_FRAG_NEEDED 4
#define ICMP_SR_FAILED 5
#define ICMP_NET_UNKNOWN 6
#define ICMP_HOST_UNKNOWN 7
#define ICMP_HOST_ISOLATED 8
#define ICMP_NET_ANO 9
#define ICMP_HOST_ANO 10
#define ICMP_NET_UNR_TOS 11
#define ICMP_HOST_UNR_TOS 12
#define ICMP_PKT_FILTERED 13
#define ICMP_PREC_VIOLATION 14
#define ICMP_PREC_CUTOFF 15
#define NR_ICMP_UNREACH 15
#define ICMP_REDIR_NET 0
#define ICMP_REDIR_HOST 1
#define ICMP_REDIR_NETTOS 2
#define ICMP_REDIR_HOSTTOS 3
#define ICMP_EXC_TTL 0
#define ICMP_EXC_FRAGTIME 1
struct icmphdr {
  __u8 type;
  __u8 code;
  __sum16 checksum;
  union {
    struct {
      __be16 id;
      __be16 sequence;
    } echo;
    __be32 gateway;
    struct {
      __be16 __linux_unused;
      __be16 mtu;
    } frag;
    __u8 reserved[4];
  } un;
};
#define ICMP_FILTER 1
struct icmp_filter {
  __u32 data;
};
struct icmp_ext_hdr {
#ifdef __LITTLE_ENDIAN_BITFIELD
  __u8 reserved1 : 4, version : 4;
#elif defined(__BIG_ENDIAN_BITFIELD)
  __u8 version : 4, reserved1 : 4;
#else
#error "Please fix <asm/byteorder.h>"
#endif
  __u8 reserved2;
  __sum16 checksum;
};
struct icmp_extobj_hdr {
  __be16 length;
  __u8 class_num;
  __u8 class_type;
};
#endif