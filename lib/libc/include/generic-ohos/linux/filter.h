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
#ifndef _UAPI__LINUX_FILTER_H__
#define _UAPI__LINUX_FILTER_H__
#include <linux/compiler.h>
#include <linux/types.h>
#include <linux/bpf_common.h>
#define BPF_MAJOR_VERSION 1
#define BPF_MINOR_VERSION 1
struct sock_filter {
  __u16 code;
  __u8 jt;
  __u8 jf;
  __u32 k;
};
struct sock_fprog {
  unsigned short len;
  struct sock_filter __user * filter;
};
#define BPF_RVAL(code) ((code) & 0x18)
#define BPF_A 0x10
#define BPF_MISCOP(code) ((code) & 0xf8)
#define BPF_TAX 0x00
#define BPF_TXA 0x80
#ifndef BPF_STMT
#define BPF_STMT(code,k) { (unsigned short) (code), 0, 0, k }
#endif
#ifndef BPF_JUMP
#define BPF_JUMP(code,k,jt,jf) { (unsigned short) (code), jt, jf, k }
#endif
#define BPF_MEMWORDS 16
#define SKF_AD_OFF (- 0x1000)
#define SKF_AD_PROTOCOL 0
#define SKF_AD_PKTTYPE 4
#define SKF_AD_IFINDEX 8
#define SKF_AD_NLATTR 12
#define SKF_AD_NLATTR_NEST 16
#define SKF_AD_MARK 20
#define SKF_AD_QUEUE 24
#define SKF_AD_HATYPE 28
#define SKF_AD_RXHASH 32
#define SKF_AD_CPU 36
#define SKF_AD_ALU_XOR_X 40
#define SKF_AD_VLAN_TAG 44
#define SKF_AD_VLAN_TAG_PRESENT 48
#define SKF_AD_PAY_OFFSET 52
#define SKF_AD_RANDOM 56
#define SKF_AD_VLAN_TPID 60
#define SKF_AD_MAX 64
#define SKF_NET_OFF (- 0x100000)
#define SKF_LL_OFF (- 0x200000)
#define BPF_NET_OFF SKF_NET_OFF
#define BPF_LL_OFF SKF_LL_OFF
#endif