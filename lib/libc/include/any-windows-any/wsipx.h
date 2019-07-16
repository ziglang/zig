/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WSIPX_
#define _WSIPX_

typedef struct sockaddr_ipx {
  short sa_family;
  char sa_netnum[4];
  char sa_nodenum[6];
  unsigned short sa_socket;
} SOCKADDR_IPX,*PSOCKADDR_IPX,*LPSOCKADDR_IPX;

#define NSPROTO_IPX 1000
#define NSPROTO_SPX 1256
#define NSPROTO_SPXII 1257
#endif
