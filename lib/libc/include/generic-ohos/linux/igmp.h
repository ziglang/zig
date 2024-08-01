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
#ifndef _UAPI_LINUX_IGMP_H
#define _UAPI_LINUX_IGMP_H
#include <linux/types.h>
#include <asm/byteorder.h>
struct igmphdr {
  __u8 type;
  __u8 code;
  __sum16 csum;
  __be32 group;
};
#define IGMPV3_MODE_IS_INCLUDE 1
#define IGMPV3_MODE_IS_EXCLUDE 2
#define IGMPV3_CHANGE_TO_INCLUDE 3
#define IGMPV3_CHANGE_TO_EXCLUDE 4
#define IGMPV3_ALLOW_NEW_SOURCES 5
#define IGMPV3_BLOCK_OLD_SOURCES 6
struct igmpv3_grec {
  __u8 grec_type;
  __u8 grec_auxwords;
  __be16 grec_nsrcs;
  __be32 grec_mca;
  __be32 grec_src[0];
};
struct igmpv3_report {
  __u8 type;
  __u8 resv1;
  __sum16 csum;
  __be16 resv2;
  __be16 ngrec;
  struct igmpv3_grec grec[0];
};
struct igmpv3_query {
  __u8 type;
  __u8 code;
  __sum16 csum;
  __be32 group;
#ifdef __LITTLE_ENDIAN_BITFIELD
  __u8 qrv : 3, suppress : 1, resv : 4;
#elif defined(__BIG_ENDIAN_BITFIELD)
  __u8 resv : 4, suppress : 1, qrv : 3;
#else
#error "Please fix <asm/byteorder.h>"
#endif
  __u8 qqic;
  __be16 nsrcs;
  __be32 srcs[0];
};
#define IGMP_HOST_MEMBERSHIP_QUERY 0x11
#define IGMP_HOST_MEMBERSHIP_REPORT 0x12
#define IGMP_DVMRP 0x13
#define IGMP_PIM 0x14
#define IGMP_TRACE 0x15
#define IGMPV2_HOST_MEMBERSHIP_REPORT 0x16
#define IGMP_HOST_LEAVE_MESSAGE 0x17
#define IGMPV3_HOST_MEMBERSHIP_REPORT 0x22
#define IGMP_MTRACE_RESP 0x1e
#define IGMP_MTRACE 0x1f
#define IGMP_MRDISC_ADV 0x30
#define IGMP_DELAYING_MEMBER 0x01
#define IGMP_IDLE_MEMBER 0x02
#define IGMP_LAZY_MEMBER 0x03
#define IGMP_SLEEPING_MEMBER 0x04
#define IGMP_AWAKENING_MEMBER 0x05
#define IGMP_MINLEN 8
#define IGMP_MAX_HOST_REPORT_DELAY 10
#define IGMP_TIMER_SCALE 10
#define IGMP_AGE_THRESHOLD 400
#define IGMP_ALL_HOSTS htonl(0xE0000001L)
#define IGMP_ALL_ROUTER htonl(0xE0000002L)
#define IGMPV3_ALL_MCR htonl(0xE0000016L)
#define IGMP_LOCAL_GROUP htonl(0xE0000000L)
#define IGMP_LOCAL_GROUP_MASK htonl(0xFFFFFF00L)
#endif