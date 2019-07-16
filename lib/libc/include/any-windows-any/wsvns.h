/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WSVNS_
#define _WSVNS_

typedef struct sockaddr_vns {
  u_short sin_family;
  u_char net_address[4];
  u_char subnet_addr[2];
  u_char port[2];
  u_char hops;
  u_char filler[5];
} SOCKADDR_VNS,*PSOCKADDR_VNS,*LPSOCKADDR_VNS;

#define VNSPROTO_IPC 1
#define VNSPROTO_RELIABLE_IPC 2
#define VNSPROTO_SPP 3
#endif
