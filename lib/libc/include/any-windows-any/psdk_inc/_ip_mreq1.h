/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _MINGW_IP_MREQ1_H
#define _MINGW_IP_MREQ1_H

#include <inaddr.h>

struct ip_mreq {
	struct in_addr	imr_multiaddr;
	struct in_addr	imr_interface;
};

#endif	/* _MINGW_IP_MREQ1_H */

