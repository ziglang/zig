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
#ifndef _LINUX_IF_H
#define _LINUX_IF_H
#include <linux/libc-compat.h>
#include <linux/types.h>
#include <linux/socket.h>
#include <linux/compiler.h>
#include <sys/socket.h>
#if __UAPI_DEF_IF_IFNAMSIZ
#define IFNAMSIZ 16
#endif
#define IFALIASZ 256
#define ALTIFNAMSIZ 128
#include <linux/hdlc/ioctl.h>
#if __UAPI_DEF_IF_NET_DEVICE_FLAGS_LOWER_UP_DORMANT_ECHO != 0 || __UAPI_DEF_IF_NET_DEVICE_FLAGS != 0
enum net_device_flags {
#if __UAPI_DEF_IF_NET_DEVICE_FLAGS
  IFF_UP = 1 << 0,
  IFF_BROADCAST = 1 << 1,
  IFF_DEBUG = 1 << 2,
  IFF_LOOPBACK = 1 << 3,
  IFF_POINTOPOINT = 1 << 4,
  IFF_NOTRAILERS = 1 << 5,
  IFF_RUNNING = 1 << 6,
  IFF_NOARP = 1 << 7,
  IFF_PROMISC = 1 << 8,
  IFF_ALLMULTI = 1 << 9,
  IFF_MASTER = 1 << 10,
  IFF_SLAVE = 1 << 11,
  IFF_MULTICAST = 1 << 12,
  IFF_PORTSEL = 1 << 13,
  IFF_AUTOMEDIA = 1 << 14,
  IFF_DYNAMIC = 1 << 15,
#endif
#if __UAPI_DEF_IF_NET_DEVICE_FLAGS_LOWER_UP_DORMANT_ECHO
  IFF_LOWER_UP = 1 << 16,
  IFF_DORMANT = 1 << 17,
  IFF_ECHO = 1 << 18,
#endif
};
#endif
#if __UAPI_DEF_IF_NET_DEVICE_FLAGS
#define IFF_UP IFF_UP
#define IFF_BROADCAST IFF_BROADCAST
#define IFF_DEBUG IFF_DEBUG
#define IFF_LOOPBACK IFF_LOOPBACK
#define IFF_POINTOPOINT IFF_POINTOPOINT
#define IFF_NOTRAILERS IFF_NOTRAILERS
#define IFF_RUNNING IFF_RUNNING
#define IFF_NOARP IFF_NOARP
#define IFF_PROMISC IFF_PROMISC
#define IFF_ALLMULTI IFF_ALLMULTI
#define IFF_MASTER IFF_MASTER
#define IFF_SLAVE IFF_SLAVE
#define IFF_MULTICAST IFF_MULTICAST
#define IFF_PORTSEL IFF_PORTSEL
#define IFF_AUTOMEDIA IFF_AUTOMEDIA
#define IFF_DYNAMIC IFF_DYNAMIC
#endif
#if __UAPI_DEF_IF_NET_DEVICE_FLAGS_LOWER_UP_DORMANT_ECHO
#define IFF_LOWER_UP IFF_LOWER_UP
#define IFF_DORMANT IFF_DORMANT
#define IFF_ECHO IFF_ECHO
#endif
#define IFF_VOLATILE (IFF_LOOPBACK | IFF_POINTOPOINT | IFF_BROADCAST | IFF_ECHO | IFF_MASTER | IFF_SLAVE | IFF_RUNNING | IFF_LOWER_UP | IFF_DORMANT)
#define IF_GET_IFACE 0x0001
#define IF_GET_PROTO 0x0002
#define IF_IFACE_V35 0x1000
#define IF_IFACE_V24 0x1001
#define IF_IFACE_X21 0x1002
#define IF_IFACE_T1 0x1003
#define IF_IFACE_E1 0x1004
#define IF_IFACE_SYNC_SERIAL 0x1005
#define IF_IFACE_X21D 0x1006
#define IF_PROTO_HDLC 0x2000
#define IF_PROTO_PPP 0x2001
#define IF_PROTO_CISCO 0x2002
#define IF_PROTO_FR 0x2003
#define IF_PROTO_FR_ADD_PVC 0x2004
#define IF_PROTO_FR_DEL_PVC 0x2005
#define IF_PROTO_X25 0x2006
#define IF_PROTO_HDLC_ETH 0x2007
#define IF_PROTO_FR_ADD_ETH_PVC 0x2008
#define IF_PROTO_FR_DEL_ETH_PVC 0x2009
#define IF_PROTO_FR_PVC 0x200A
#define IF_PROTO_FR_ETH_PVC 0x200B
#define IF_PROTO_RAW 0x200C
enum {
  IF_OPER_UNKNOWN,
  IF_OPER_NOTPRESENT,
  IF_OPER_DOWN,
  IF_OPER_LOWERLAYERDOWN,
  IF_OPER_TESTING,
  IF_OPER_DORMANT,
  IF_OPER_UP,
};
enum {
  IF_LINK_MODE_DEFAULT,
  IF_LINK_MODE_DORMANT,
  IF_LINK_MODE_TESTING,
};
#if __UAPI_DEF_IF_IFMAP
struct ifmap {
  unsigned long mem_start;
  unsigned long mem_end;
  unsigned short base_addr;
  unsigned char irq;
  unsigned char dma;
  unsigned char port;
};
#endif
struct if_settings {
  unsigned int type;
  unsigned int size;
  union {
    raw_hdlc_proto __user * raw_hdlc;
    cisco_proto __user * cisco;
    fr_proto __user * fr;
    fr_proto_pvc __user * fr_pvc;
    fr_proto_pvc_info __user * fr_pvc_info;
    x25_hdlc_proto __user * x25;
    sync_serial_settings __user * sync;
    te1_settings __user * te1;
  } ifs_ifsu;
};
#if __UAPI_DEF_IF_IFREQ
struct ifreq {
#define IFHWADDRLEN 6
  union {
    char ifrn_name[IFNAMSIZ];
  } ifr_ifrn;
  union {
    struct sockaddr ifru_addr;
    struct sockaddr ifru_dstaddr;
    struct sockaddr ifru_broadaddr;
    struct sockaddr ifru_netmask;
    struct sockaddr ifru_hwaddr;
    short ifru_flags;
    int ifru_ivalue;
    int ifru_mtu;
    struct ifmap ifru_map;
    char ifru_slave[IFNAMSIZ];
    char ifru_newname[IFNAMSIZ];
    void __user * ifru_data;
    struct if_settings ifru_settings;
  } ifr_ifru;
};
#endif
#define ifr_name ifr_ifrn.ifrn_name
#define ifr_hwaddr ifr_ifru.ifru_hwaddr
#define ifr_addr ifr_ifru.ifru_addr
#define ifr_dstaddr ifr_ifru.ifru_dstaddr
#define ifr_broadaddr ifr_ifru.ifru_broadaddr
#define ifr_netmask ifr_ifru.ifru_netmask
#define ifr_flags ifr_ifru.ifru_flags
#define ifr_metric ifr_ifru.ifru_ivalue
#define ifr_mtu ifr_ifru.ifru_mtu
#define ifr_map ifr_ifru.ifru_map
#define ifr_slave ifr_ifru.ifru_slave
#define ifr_data ifr_ifru.ifru_data
#define ifr_ifindex ifr_ifru.ifru_ivalue
#define ifr_bandwidth ifr_ifru.ifru_ivalue
#define ifr_qlen ifr_ifru.ifru_ivalue
#define ifr_newname ifr_ifru.ifru_newname
#define ifr_settings ifr_ifru.ifru_settings
#if __UAPI_DEF_IF_IFCONF
struct ifconf {
  int ifc_len;
  union {
    char __user * ifcu_buf;
    struct ifreq __user * ifcu_req;
  } ifc_ifcu;
};
#endif
#define ifc_buf ifc_ifcu.ifcu_buf
#define ifc_req ifc_ifcu.ifcu_req
#endif