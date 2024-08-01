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
#ifndef __ASM_GENERIC_SOCKET_H
#define __ASM_GENERIC_SOCKET_H
#include <linux/posix_types.h>
#include <asm/sockios.h>
#define SOL_SOCKET 1
#define SO_DEBUG 1
#define SO_REUSEADDR 2
#define SO_TYPE 3
#define SO_ERROR 4
#define SO_DONTROUTE 5
#define SO_BROADCAST 6
#define SO_SNDBUF 7
#define SO_RCVBUF 8
#define SO_SNDBUFFORCE 32
#define SO_RCVBUFFORCE 33
#define SO_KEEPALIVE 9
#define SO_OOBINLINE 10
#define SO_NO_CHECK 11
#define SO_PRIORITY 12
#define SO_LINGER 13
#define SO_BSDCOMPAT 14
#define SO_REUSEPORT 15
#ifndef SO_PASSCRED
#define SO_PASSCRED 16
#define SO_PEERCRED 17
#define SO_RCVLOWAT 18
#define SO_SNDLOWAT 19
#define SO_RCVTIMEO_OLD 20
#define SO_SNDTIMEO_OLD 21
#endif
#define SO_SECURITY_AUTHENTICATION 22
#define SO_SECURITY_ENCRYPTION_TRANSPORT 23
#define SO_SECURITY_ENCRYPTION_NETWORK 24
#define SO_BINDTODEVICE 25
#define SO_ATTACH_FILTER 26
#define SO_DETACH_FILTER 27
#define SO_GET_FILTER SO_ATTACH_FILTER
#define SO_PEERNAME 28
#define SO_ACCEPTCONN 30
#define SO_PEERSEC 31
#define SO_PASSSEC 34
#define SO_MARK 36
#define SO_PROTOCOL 38
#define SO_DOMAIN 39
#define SO_RXQ_OVFL 40
#define SO_WIFI_STATUS 41
#define SCM_WIFI_STATUS SO_WIFI_STATUS
#define SO_PEEK_OFF 42
#define SO_NOFCS 43
#define SO_LOCK_FILTER 44
#define SO_SELECT_ERR_QUEUE 45
#define SO_BUSY_POLL 46
#define SO_MAX_PACING_RATE 47
#define SO_BPF_EXTENSIONS 48
#define SO_INCOMING_CPU 49
#define SO_ATTACH_BPF 50
#define SO_DETACH_BPF SO_DETACH_FILTER
#define SO_ATTACH_REUSEPORT_CBPF 51
#define SO_ATTACH_REUSEPORT_EBPF 52
#define SO_CNX_ADVICE 53
#define SCM_TIMESTAMPING_OPT_STATS 54
#define SO_MEMINFO 55
#define SO_INCOMING_NAPI_ID 56
#define SO_COOKIE 57
#define SCM_TIMESTAMPING_PKTINFO 58
#define SO_PEERGROUPS 59
#define SO_ZEROCOPY 60
#define SO_TXTIME 61
#define SCM_TXTIME SO_TXTIME
#define SO_BINDTOIFINDEX 62
#define SO_TIMESTAMP_OLD 29
#define SO_TIMESTAMPNS_OLD 35
#define SO_TIMESTAMPING_OLD 37
#define SO_TIMESTAMP_NEW 63
#define SO_TIMESTAMPNS_NEW 64
#define SO_TIMESTAMPING_NEW 65
#define SO_RCVTIMEO_NEW 66
#define SO_SNDTIMEO_NEW 67
#define SO_DETACH_REUSEPORT_BPF 68
#if __BITS_PER_LONG == 64 || defined(__x86_64__) && defined(__ILP32__)
#define SO_TIMESTAMP SO_TIMESTAMP_OLD
#define SO_TIMESTAMPNS SO_TIMESTAMPNS_OLD
#define SO_TIMESTAMPING SO_TIMESTAMPING_OLD
#define SO_RCVTIMEO SO_RCVTIMEO_OLD
#define SO_SNDTIMEO SO_SNDTIMEO_OLD
#else
#define SO_TIMESTAMP (sizeof(time_t) == sizeof(__kernel_long_t) ? SO_TIMESTAMP_OLD : SO_TIMESTAMP_NEW)
#define SO_TIMESTAMPNS (sizeof(time_t) == sizeof(__kernel_long_t) ? SO_TIMESTAMPNS_OLD : SO_TIMESTAMPNS_NEW)
#define SO_TIMESTAMPING (sizeof(time_t) == sizeof(__kernel_long_t) ? SO_TIMESTAMPING_OLD : SO_TIMESTAMPING_NEW)
#define SO_RCVTIMEO (sizeof(time_t) == sizeof(__kernel_long_t) ? SO_RCVTIMEO_OLD : SO_RCVTIMEO_NEW)
#define SO_SNDTIMEO (sizeof(time_t) == sizeof(__kernel_long_t) ? SO_SNDTIMEO_OLD : SO_SNDTIMEO_NEW)
#endif
#define SCM_TIMESTAMP SO_TIMESTAMP
#define SCM_TIMESTAMPNS SO_TIMESTAMPNS
#define SCM_TIMESTAMPING SO_TIMESTAMPING
#endif