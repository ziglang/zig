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
#ifndef _UAPI_NF_CONNTRACK_TCP_H
#define _UAPI_NF_CONNTRACK_TCP_H
#include <linux/types.h>
enum tcp_conntrack {
  TCP_CONNTRACK_NONE,
  TCP_CONNTRACK_SYN_SENT,
  TCP_CONNTRACK_SYN_RECV,
  TCP_CONNTRACK_ESTABLISHED,
  TCP_CONNTRACK_FIN_WAIT,
  TCP_CONNTRACK_CLOSE_WAIT,
  TCP_CONNTRACK_LAST_ACK,
  TCP_CONNTRACK_TIME_WAIT,
  TCP_CONNTRACK_CLOSE,
  TCP_CONNTRACK_LISTEN,
#define TCP_CONNTRACK_SYN_SENT2 TCP_CONNTRACK_LISTEN
  TCP_CONNTRACK_MAX,
  TCP_CONNTRACK_IGNORE,
  TCP_CONNTRACK_RETRANS,
  TCP_CONNTRACK_UNACK,
  TCP_CONNTRACK_TIMEOUT_MAX
};
#define IP_CT_TCP_FLAG_WINDOW_SCALE 0x01
#define IP_CT_TCP_FLAG_SACK_PERM 0x02
#define IP_CT_TCP_FLAG_CLOSE_INIT 0x04
#define IP_CT_TCP_FLAG_BE_LIBERAL 0x08
#define IP_CT_TCP_FLAG_DATA_UNACKNOWLEDGED 0x10
#define IP_CT_TCP_FLAG_MAXACK_SET 0x20
#define IP_CT_EXP_CHALLENGE_ACK 0x40
#define IP_CT_TCP_SIMULTANEOUS_OPEN 0x80
struct nf_ct_tcp_flags {
  __u8 flags;
  __u8 mask;
};
#endif