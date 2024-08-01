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
#ifndef _UAPI__LINUX_MROUTE_H
#define _UAPI__LINUX_MROUTE_H
#include <linux/sockios.h>
#include <linux/types.h>
#include <linux/in.h>
#define MRT_BASE 200
#define MRT_INIT (MRT_BASE)
#define MRT_DONE (MRT_BASE + 1)
#define MRT_ADD_VIF (MRT_BASE + 2)
#define MRT_DEL_VIF (MRT_BASE + 3)
#define MRT_ADD_MFC (MRT_BASE + 4)
#define MRT_DEL_MFC (MRT_BASE + 5)
#define MRT_VERSION (MRT_BASE + 6)
#define MRT_ASSERT (MRT_BASE + 7)
#define MRT_PIM (MRT_BASE + 8)
#define MRT_TABLE (MRT_BASE + 9)
#define MRT_ADD_MFC_PROXY (MRT_BASE + 10)
#define MRT_DEL_MFC_PROXY (MRT_BASE + 11)
#define MRT_FLUSH (MRT_BASE + 12)
#define MRT_MAX (MRT_BASE + 12)
#define SIOCGETVIFCNT SIOCPROTOPRIVATE
#define SIOCGETSGCNT (SIOCPROTOPRIVATE + 1)
#define SIOCGETRPF (SIOCPROTOPRIVATE + 2)
#define MRT_FLUSH_MFC 1
#define MRT_FLUSH_MFC_STATIC 2
#define MRT_FLUSH_VIFS 4
#define MRT_FLUSH_VIFS_STATIC 8
#define MAXVIFS 32
typedef unsigned long vifbitmap_t;
typedef unsigned short vifi_t;
#define ALL_VIFS ((vifi_t) (- 1))
#define VIFM_SET(n,m) ((m) |= (1 << (n)))
#define VIFM_CLR(n,m) ((m) &= ~(1 << (n)))
#define VIFM_ISSET(n,m) ((m) & (1 << (n)))
#define VIFM_CLRALL(m) ((m) = 0)
#define VIFM_COPY(mfrom,mto) ((mto) = (mfrom))
#define VIFM_SAME(m1,m2) ((m1) == (m2))
struct vifctl {
  vifi_t vifc_vifi;
  unsigned char vifc_flags;
  unsigned char vifc_threshold;
  unsigned int vifc_rate_limit;
  union {
    struct in_addr vifc_lcl_addr;
    int vifc_lcl_ifindex;
  };
  struct in_addr vifc_rmt_addr;
};
#define VIFF_TUNNEL 0x1
#define VIFF_SRCRT 0x2
#define VIFF_REGISTER 0x4
#define VIFF_USE_IFINDEX 0x8
struct mfcctl {
  struct in_addr mfcc_origin;
  struct in_addr mfcc_mcastgrp;
  vifi_t mfcc_parent;
  unsigned char mfcc_ttls[MAXVIFS];
  unsigned int mfcc_pkt_cnt;
  unsigned int mfcc_byte_cnt;
  unsigned int mfcc_wrong_if;
  int mfcc_expire;
};
struct sioc_sg_req {
  struct in_addr src;
  struct in_addr grp;
  unsigned long pktcnt;
  unsigned long bytecnt;
  unsigned long wrong_if;
};
struct sioc_vif_req {
  vifi_t vifi;
  unsigned long icount;
  unsigned long ocount;
  unsigned long ibytes;
  unsigned long obytes;
};
struct igmpmsg {
  __u32 unused1, unused2;
  unsigned char im_msgtype;
  unsigned char im_mbz;
  unsigned char im_vif;
  unsigned char im_vif_hi;
  struct in_addr im_src, im_dst;
};
enum {
  IPMRA_TABLE_UNSPEC,
  IPMRA_TABLE_ID,
  IPMRA_TABLE_CACHE_RES_QUEUE_LEN,
  IPMRA_TABLE_MROUTE_REG_VIF_NUM,
  IPMRA_TABLE_MROUTE_DO_ASSERT,
  IPMRA_TABLE_MROUTE_DO_PIM,
  IPMRA_TABLE_VIFS,
  IPMRA_TABLE_MROUTE_DO_WRVIFWHOLE,
  __IPMRA_TABLE_MAX
};
#define IPMRA_TABLE_MAX (__IPMRA_TABLE_MAX - 1)
enum {
  IPMRA_VIF_UNSPEC,
  IPMRA_VIF,
  __IPMRA_VIF_MAX
};
#define IPMRA_VIF_MAX (__IPMRA_VIF_MAX - 1)
enum {
  IPMRA_VIFA_UNSPEC,
  IPMRA_VIFA_IFINDEX,
  IPMRA_VIFA_VIF_ID,
  IPMRA_VIFA_FLAGS,
  IPMRA_VIFA_BYTES_IN,
  IPMRA_VIFA_BYTES_OUT,
  IPMRA_VIFA_PACKETS_IN,
  IPMRA_VIFA_PACKETS_OUT,
  IPMRA_VIFA_LOCAL_ADDR,
  IPMRA_VIFA_REMOTE_ADDR,
  IPMRA_VIFA_PAD,
  __IPMRA_VIFA_MAX
};
#define IPMRA_VIFA_MAX (__IPMRA_VIFA_MAX - 1)
enum {
  IPMRA_CREPORT_UNSPEC,
  IPMRA_CREPORT_MSGTYPE,
  IPMRA_CREPORT_VIF_ID,
  IPMRA_CREPORT_SRC_ADDR,
  IPMRA_CREPORT_DST_ADDR,
  IPMRA_CREPORT_PKT,
  IPMRA_CREPORT_TABLE,
  __IPMRA_CREPORT_MAX
};
#define IPMRA_CREPORT_MAX (__IPMRA_CREPORT_MAX - 1)
#define MFC_ASSERT_THRESH (3 * HZ)
#define IGMPMSG_NOCACHE 1
#define IGMPMSG_WRONGVIF 2
#define IGMPMSG_WHOLEPKT 3
#define IGMPMSG_WRVIFWHOLE 4
#endif