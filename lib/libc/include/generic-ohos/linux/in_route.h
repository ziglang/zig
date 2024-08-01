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
#ifndef _LINUX_IN_ROUTE_H
#define _LINUX_IN_ROUTE_H
#define RTCF_DEAD RTNH_F_DEAD
#define RTCF_ONLINK RTNH_F_ONLINK
#define RTCF_NOPMTUDISC RTM_F_NOPMTUDISC
#define RTCF_NOTIFY 0x00010000
#define RTCF_DIRECTDST 0x00020000
#define RTCF_REDIRECTED 0x00040000
#define RTCF_TPROXY 0x00080000
#define RTCF_FAST 0x00200000
#define RTCF_MASQ 0x00400000
#define RTCF_SNAT 0x00800000
#define RTCF_DOREDIRECT 0x01000000
#define RTCF_DIRECTSRC 0x04000000
#define RTCF_DNAT 0x08000000
#define RTCF_BROADCAST 0x10000000
#define RTCF_MULTICAST 0x20000000
#define RTCF_REJECT 0x40000000
#define RTCF_LOCAL 0x80000000
#define RTCF_NAT (RTCF_DNAT | RTCF_SNAT)
#define RT_TOS(tos) ((tos) & IPTOS_TOS_MASK)
#endif