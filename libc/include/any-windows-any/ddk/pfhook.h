/*
 * pfhook.h
 *
 * Packet filter API
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Casper S. Hornstrup <chorns@users.sourceforge.net>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef __PFHOOK_H
#define __PFHOOK_H

#ifdef __cplusplus
extern "C" {
#endif

#define DD_IPFLTRDRVR_DEVICE_NAME         L"\\Device\\IPFILTERDRIVER"

#define INVALID_PF_IF_INDEX               0xffffffff
#define ZERO_PF_IP_ADDR                   0

typedef ULONG IPAddr;

typedef enum _PF_FORWARD_ACTION {
	PF_FORWARD = 0,
	PF_DROP = 1,
	PF_PASS = 2,
	PF_ICMP_ON_DROP = 3
} PF_FORWARD_ACTION;

typedef PF_FORWARD_ACTION
(NTAPI *PacketFilterExtensionPtr)(
  IN unsigned char  *PacketHeader,
  IN unsigned char  *Packet,
  IN unsigned int  PacketLength,
  IN unsigned int  RecvInterfaceIndex,
  IN unsigned int  SendInterfaceIndex,
  IN IPAddr  RecvLinkNextHop,
  IN IPAddr  SendLinkNextHop);

typedef struct _PF_SET_EXTENSION_HOOK_INFO {
  PacketFilterExtensionPtr  ExtensionPointer;
} PF_SET_EXTENSION_HOOK_INFO, *PPF_SET_EXTENSION_HOOK_INFO;

#define FSCTL_IPFLTRDRVR_BASE             FILE_DEVICE_NETWORK

#define _IPFLTRDRVR_CTL_CODE(function, method, access) \
  CTL_CODE(FSCTL_IPFLTRDRVR_BASE, function, method, access)

#define IOCTL_PF_SET_EXTENSION_POINTER \
  _IPFLTRDRVR_CTL_CODE(22, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#ifdef __cplusplus
}
#endif

#endif /* __PFHOOK_H */
