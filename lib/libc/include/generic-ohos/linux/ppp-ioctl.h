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
#ifndef _PPP_IOCTL_H
#define _PPP_IOCTL_H
#include <linux/types.h>
#include <linux/compiler.h>
#include <linux/ppp_defs.h>
#define SC_COMP_PROT 0x00000001
#define SC_COMP_AC 0x00000002
#define SC_COMP_TCP 0x00000004
#define SC_NO_TCP_CCID 0x00000008
#define SC_REJ_COMP_AC 0x00000010
#define SC_REJ_COMP_TCP 0x00000020
#define SC_CCP_OPEN 0x00000040
#define SC_CCP_UP 0x00000080
#define SC_ENABLE_IP 0x00000100
#define SC_LOOP_TRAFFIC 0x00000200
#define SC_MULTILINK 0x00000400
#define SC_MP_SHORTSEQ 0x00000800
#define SC_COMP_RUN 0x00001000
#define SC_DECOMP_RUN 0x00002000
#define SC_MP_XSHORTSEQ 0x00004000
#define SC_DEBUG 0x00010000
#define SC_LOG_INPKT 0x00020000
#define SC_LOG_OUTPKT 0x00040000
#define SC_LOG_RAWIN 0x00080000
#define SC_LOG_FLUSH 0x00100000
#define SC_SYNC 0x00200000
#define SC_MUST_COMP 0x00400000
#define SC_MASK 0x0f600fff
#define SC_XMIT_BUSY 0x10000000
#define SC_RCV_ODDP 0x08000000
#define SC_RCV_EVNP 0x04000000
#define SC_RCV_B7_1 0x02000000
#define SC_RCV_B7_0 0x01000000
#define SC_DC_FERROR 0x00800000
#define SC_DC_ERROR 0x00400000
struct npioctl {
  int protocol;
  enum NPmode mode;
};
struct ppp_option_data {
  __u8 __user * ptr;
  __u32 length;
  int transmit;
};
struct pppol2tp_ioc_stats {
  __u16 tunnel_id;
  __u16 session_id;
  __u32 using_ipsec : 1;
  __aligned_u64 tx_packets;
  __aligned_u64 tx_bytes;
  __aligned_u64 tx_errors;
  __aligned_u64 rx_packets;
  __aligned_u64 rx_bytes;
  __aligned_u64 rx_seq_discards;
  __aligned_u64 rx_oos_packets;
  __aligned_u64 rx_errors;
};
#define PPPIOCGFLAGS _IOR('t', 90, int)
#define PPPIOCSFLAGS _IOW('t', 89, int)
#define PPPIOCGASYNCMAP _IOR('t', 88, int)
#define PPPIOCSASYNCMAP _IOW('t', 87, int)
#define PPPIOCGUNIT _IOR('t', 86, int)
#define PPPIOCGRASYNCMAP _IOR('t', 85, int)
#define PPPIOCSRASYNCMAP _IOW('t', 84, int)
#define PPPIOCGMRU _IOR('t', 83, int)
#define PPPIOCSMRU _IOW('t', 82, int)
#define PPPIOCSMAXCID _IOW('t', 81, int)
#define PPPIOCGXASYNCMAP _IOR('t', 80, ext_accm)
#define PPPIOCSXASYNCMAP _IOW('t', 79, ext_accm)
#define PPPIOCXFERUNIT _IO('t', 78)
#define PPPIOCSCOMPRESS _IOW('t', 77, struct ppp_option_data)
#define PPPIOCGNPMODE _IOWR('t', 76, struct npioctl)
#define PPPIOCSNPMODE _IOW('t', 75, struct npioctl)
#define PPPIOCSPASS _IOW('t', 71, struct sock_fprog)
#define PPPIOCSACTIVE _IOW('t', 70, struct sock_fprog)
#define PPPIOCGDEBUG _IOR('t', 65, int)
#define PPPIOCSDEBUG _IOW('t', 64, int)
#define PPPIOCGIDLE _IOR('t', 63, struct ppp_idle)
#define PPPIOCGIDLE32 _IOR('t', 63, struct ppp_idle32)
#define PPPIOCGIDLE64 _IOR('t', 63, struct ppp_idle64)
#define PPPIOCNEWUNIT _IOWR('t', 62, int)
#define PPPIOCATTACH _IOW('t', 61, int)
#define PPPIOCDETACH _IOW('t', 60, int)
#define PPPIOCSMRRU _IOW('t', 59, int)
#define PPPIOCCONNECT _IOW('t', 58, int)
#define PPPIOCDISCONN _IO('t', 57)
#define PPPIOCATTCHAN _IOW('t', 56, int)
#define PPPIOCGCHAN _IOR('t', 55, int)
#define PPPIOCGL2TPSTATS _IOR('t', 54, struct pppol2tp_ioc_stats)
#define SIOCGPPPSTATS (SIOCDEVPRIVATE + 0)
#define SIOCGPPPVER (SIOCDEVPRIVATE + 1)
#define SIOCGPPPCSTATS (SIOCDEVPRIVATE + 2)
#endif