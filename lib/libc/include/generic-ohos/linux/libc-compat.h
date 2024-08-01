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
#ifndef _UAPI_LIBC_COMPAT_H
#define _UAPI_LIBC_COMPAT_H
#ifdef __GLIBC__
#if defined(_NET_IF_H) && defined(__USE_MISC)
#define __UAPI_DEF_IF_IFCONF 0
#define __UAPI_DEF_IF_IFMAP 0
#define __UAPI_DEF_IF_IFNAMSIZ 0
#define __UAPI_DEF_IF_IFREQ 0
#define __UAPI_DEF_IF_NET_DEVICE_FLAGS 0
#ifndef __UAPI_DEF_IF_NET_DEVICE_FLAGS_LOWER_UP_DORMANT_ECHO
#define __UAPI_DEF_IF_NET_DEVICE_FLAGS_LOWER_UP_DORMANT_ECHO 1
#endif
#else
#define __UAPI_DEF_IF_IFCONF 1
#define __UAPI_DEF_IF_IFMAP 1
#define __UAPI_DEF_IF_IFNAMSIZ 1
#define __UAPI_DEF_IF_IFREQ 1
#define __UAPI_DEF_IF_NET_DEVICE_FLAGS 1
#define __UAPI_DEF_IF_NET_DEVICE_FLAGS_LOWER_UP_DORMANT_ECHO 1
#endif
#ifdef _NETINET_IN_H
#define __UAPI_DEF_IN_ADDR 0
#define __UAPI_DEF_IN_IPPROTO 0
#define __UAPI_DEF_IN_PKTINFO 0
#define __UAPI_DEF_IP_MREQ 0
#define __UAPI_DEF_SOCKADDR_IN 0
#define __UAPI_DEF_IN_CLASS 0
#define __UAPI_DEF_IN6_ADDR 0
#if defined(__USE_MISC) || defined(__USE_GNU)
#define __UAPI_DEF_IN6_ADDR_ALT 0
#else
#define __UAPI_DEF_IN6_ADDR_ALT 1
#endif
#define __UAPI_DEF_SOCKADDR_IN6 0
#define __UAPI_DEF_IPV6_MREQ 0
#define __UAPI_DEF_IPPROTO_V6 0
#define __UAPI_DEF_IPV6_OPTIONS 0
#define __UAPI_DEF_IN6_PKTINFO 0
#define __UAPI_DEF_IP6_MTUINFO 0
#else
#define __UAPI_DEF_IN_ADDR 1
#define __UAPI_DEF_IN_IPPROTO 1
#define __UAPI_DEF_IN_PKTINFO 1
#define __UAPI_DEF_IP_MREQ 1
#define __UAPI_DEF_SOCKADDR_IN 1
#define __UAPI_DEF_IN_CLASS 1
#define __UAPI_DEF_IN6_ADDR 1
#define __UAPI_DEF_IN6_ADDR_ALT 1
#define __UAPI_DEF_SOCKADDR_IN6 1
#define __UAPI_DEF_IPV6_MREQ 1
#define __UAPI_DEF_IPPROTO_V6 1
#define __UAPI_DEF_IPV6_OPTIONS 1
#define __UAPI_DEF_IN6_PKTINFO 1
#define __UAPI_DEF_IP6_MTUINFO 1
#endif
#ifdef __NETIPX_IPX_H
#define __UAPI_DEF_SOCKADDR_IPX 0
#define __UAPI_DEF_IPX_ROUTE_DEFINITION 0
#define __UAPI_DEF_IPX_INTERFACE_DEFINITION 0
#define __UAPI_DEF_IPX_CONFIG_DATA 0
#define __UAPI_DEF_IPX_ROUTE_DEF 0
#else
#define __UAPI_DEF_SOCKADDR_IPX 1
#define __UAPI_DEF_IPX_ROUTE_DEFINITION 1
#define __UAPI_DEF_IPX_INTERFACE_DEFINITION 1
#define __UAPI_DEF_IPX_CONFIG_DATA 1
#define __UAPI_DEF_IPX_ROUTE_DEF 1
#endif
#ifdef _SYS_XATTR_H
#define __UAPI_DEF_XATTR 0
#else
#define __UAPI_DEF_XATTR 1
#endif
#else
#ifndef __UAPI_DEF_IF_IFCONF
#define __UAPI_DEF_IF_IFCONF 1
#endif
#ifndef __UAPI_DEF_IF_IFMAP
#define __UAPI_DEF_IF_IFMAP 1
#endif
#ifndef __UAPI_DEF_IF_IFNAMSIZ
#define __UAPI_DEF_IF_IFNAMSIZ 1
#endif
#ifndef __UAPI_DEF_IF_IFREQ
#define __UAPI_DEF_IF_IFREQ 1
#endif
#ifndef __UAPI_DEF_IF_NET_DEVICE_FLAGS
#define __UAPI_DEF_IF_NET_DEVICE_FLAGS 1
#endif
#ifndef __UAPI_DEF_IF_NET_DEVICE_FLAGS_LOWER_UP_DORMANT_ECHO
#define __UAPI_DEF_IF_NET_DEVICE_FLAGS_LOWER_UP_DORMANT_ECHO 1
#endif
#ifndef __UAPI_DEF_IN_ADDR
#define __UAPI_DEF_IN_ADDR 1
#endif
#ifndef __UAPI_DEF_IN_IPPROTO
#define __UAPI_DEF_IN_IPPROTO 1
#endif
#ifndef __UAPI_DEF_IN_PKTINFO
#define __UAPI_DEF_IN_PKTINFO 1
#endif
#ifndef __UAPI_DEF_IP_MREQ
#define __UAPI_DEF_IP_MREQ 1
#endif
#ifndef __UAPI_DEF_SOCKADDR_IN
#define __UAPI_DEF_SOCKADDR_IN 1
#endif
#ifndef __UAPI_DEF_IN_CLASS
#define __UAPI_DEF_IN_CLASS 1
#endif
#ifndef __UAPI_DEF_IN6_ADDR
#define __UAPI_DEF_IN6_ADDR 1
#endif
#ifndef __UAPI_DEF_IN6_ADDR_ALT
#define __UAPI_DEF_IN6_ADDR_ALT 1
#endif
#ifndef __UAPI_DEF_SOCKADDR_IN6
#define __UAPI_DEF_SOCKADDR_IN6 1
#endif
#ifndef __UAPI_DEF_IPV6_MREQ
#define __UAPI_DEF_IPV6_MREQ 1
#endif
#ifndef __UAPI_DEF_IPPROTO_V6
#define __UAPI_DEF_IPPROTO_V6 1
#endif
#ifndef __UAPI_DEF_IPV6_OPTIONS
#define __UAPI_DEF_IPV6_OPTIONS 1
#endif
#ifndef __UAPI_DEF_IN6_PKTINFO
#define __UAPI_DEF_IN6_PKTINFO 1
#endif
#ifndef __UAPI_DEF_IP6_MTUINFO
#define __UAPI_DEF_IP6_MTUINFO 1
#endif
#ifndef __UAPI_DEF_SOCKADDR_IPX
#define __UAPI_DEF_SOCKADDR_IPX 1
#endif
#ifndef __UAPI_DEF_IPX_ROUTE_DEFINITION
#define __UAPI_DEF_IPX_ROUTE_DEFINITION 1
#endif
#ifndef __UAPI_DEF_IPX_INTERFACE_DEFINITION
#define __UAPI_DEF_IPX_INTERFACE_DEFINITION 1
#endif
#ifndef __UAPI_DEF_IPX_CONFIG_DATA
#define __UAPI_DEF_IPX_CONFIG_DATA 1
#endif
#ifndef __UAPI_DEF_IPX_ROUTE_DEF
#define __UAPI_DEF_IPX_ROUTE_DEF 1
#endif
#ifndef __UAPI_DEF_XATTR
#define __UAPI_DEF_XATTR 1
#endif
#endif
#endif