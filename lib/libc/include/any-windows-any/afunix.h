/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _AFUNIX_
#define _AFUNIX_

#define UNIX_PATH_MAX 108

typedef struct sockaddr_un {
  ADDRESS_FAMILY sun_family;
  char sun_path[UNIX_PATH_MAX];
} SOCKADDR_UN, *PSOCKADDR_UN;

#define SIO_AF_UNIX_GETPEERPID _WSAIOR(IOC_VENDOR, 256)
#define SIO_AF_UNIX_SETBINDPARENTPATH _WSAIOW(IOC_VENDOR, 257)
#define SIO_AF_UNIX_SETCONNPARENTPATH _WSAIOW(IOC_VENDOR, 258)

#endif /* _AFUNIX_ */
