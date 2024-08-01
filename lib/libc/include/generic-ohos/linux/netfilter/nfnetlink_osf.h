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
#ifndef _NF_OSF_H
#define _NF_OSF_H
#include <linux/types.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#define MAXGENRELEN 32
#define NF_OSF_GENRE (1 << 0)
#define NF_OSF_TTL (1 << 1)
#define NF_OSF_LOG (1 << 2)
#define NF_OSF_INVERT (1 << 3)
#define NF_OSF_LOGLEVEL_ALL 0
#define NF_OSF_LOGLEVEL_FIRST 1
#define NF_OSF_LOGLEVEL_ALL_KNOWN 2
#define NF_OSF_TTL_TRUE 0
#define NF_OSF_TTL_LESS 1
#define NF_OSF_TTL_NOCHECK 2
#define NF_OSF_FLAGMASK (NF_OSF_GENRE | NF_OSF_TTL | NF_OSF_LOG | NF_OSF_INVERT)
struct nf_osf_wc {
  __u32 wc;
  __u32 val;
};
struct nf_osf_opt {
  __u16 kind, length;
  struct nf_osf_wc wc;
};
struct nf_osf_info {
  char genre[MAXGENRELEN];
  __u32 len;
  __u32 flags;
  __u32 loglevel;
  __u32 ttl;
};
struct nf_osf_user_finger {
  struct nf_osf_wc wss;
  __u8 ttl, df;
  __u16 ss, mss;
  __u16 opt_num;
  char genre[MAXGENRELEN];
  char version[MAXGENRELEN];
  char subtype[MAXGENRELEN];
  struct nf_osf_opt opt[MAX_IPOPTLEN];
};
struct nf_osf_nlmsg {
  struct nf_osf_user_finger f;
  struct iphdr ip;
  struct tcphdr tcp;
};
enum iana_options {
  OSFOPT_EOL = 0,
  OSFOPT_NOP,
  OSFOPT_MSS,
  OSFOPT_WSO,
  OSFOPT_SACKP,
  OSFOPT_SACK,
  OSFOPT_ECHO,
  OSFOPT_ECHOREPLY,
  OSFOPT_TS,
  OSFOPT_POCP,
  OSFOPT_POSP,
  OSFOPT_EMPTY = 255,
};
enum nf_osf_window_size_options {
  OSF_WSS_PLAIN = 0,
  OSF_WSS_MSS,
  OSF_WSS_MTU,
  OSF_WSS_MODULO,
  OSF_WSS_MAX,
};
enum nf_osf_attr_type {
  OSF_ATTR_UNSPEC,
  OSF_ATTR_FINGER,
  OSF_ATTR_MAX,
};
enum nf_osf_msg_types {
  OSF_MSG_ADD,
  OSF_MSG_REMOVE,
  OSF_MSG_MAX,
};
#endif