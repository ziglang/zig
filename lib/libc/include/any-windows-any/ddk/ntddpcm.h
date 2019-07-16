/*
 * ntddpcm.h
 *
 * PCMCIA IOCTL interface
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

#ifndef _NTDDPCMH_
#define _NTDDPCMH_

#ifdef __cplusplus
extern "C" {
#endif

#define IOCTL_PCMCIA_BASE                 FILE_DEVICE_CONTROLLER

#define DD_PCMCIA_DEVICE_NAME             "\\\\.\\Pcmcia"
#define DD_PCMCIA_DEVICE_NAME_U           L"\\\\.\\Pcmcia"

#define IOCTL_GET_TUPLE_DATA \
  CTL_CODE(IOCTL_PCMCIA_BASE, 3000, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_SOCKET_INFORMATION \
  CTL_CODE(IOCTL_PCMCIA_BASE, 3004, METHOD_BUFFERED, FILE_ANY_ACCESS)

#define DEVICE_IDENTIFIER_LENGTH          64
#define DRIVER_NAME_LENGTH                32
#define MANUFACTURER_NAME_LENGTH          64

#define PcmciaInvalidControllerType       0xffffffff

typedef struct _TUPLE_REQUEST {
 USHORT  Socket;
} TUPLE_REQUEST, *PTUPLE_REQUEST;

typedef enum _PCMCIA_CONTROLLER_CLASS {
	PcmciaInvalidControllerClass = -1,
	PcmciaIntelCompatible,
	PcmciaCardBusCompatible,
	PcmciaElcController,
	PcmciaDatabook,
	PcmciaPciPcmciaBridge,
	PcmciaCirrusLogic,
	PcmciaTI,
	PcmciaTopic,
	PcmciaRicoh,
	PcmciaDatabookCB,
	PcmciaOpti,
	PcmciaTrid,
	PcmciaO2Micro,
	PcmciaNEC,
	PcmciaNEC_98
} PCMCIA_CONTROLLER_CLASS, *PPCMCIA_CONTROLLER_CLASS;

typedef struct _PCMCIA_SOCKET_INFORMATION {
	USHORT  Socket;
	USHORT  TupleCrc;
	UCHAR  Manufacturer[MANUFACTURER_NAME_LENGTH];
	UCHAR  Identifier[DEVICE_IDENTIFIER_LENGTH];
	UCHAR  DriverName[DRIVER_NAME_LENGTH];
	UCHAR  DeviceFunctionId;
	UCHAR  Reserved;
	UCHAR  CardInSocket;
	UCHAR  CardEnabled;
	ULONG  ControllerType;
} PCMCIA_SOCKET_INFORMATION, *PPCMCIA_SOCKET_INFORMATION;

#define PcmciaClassFromControllerType(type)     ((PCMCIA_CONTROLLER_CLASS)((type) & 0xff))
#define PcmciaModelFromControllerType(type)     (((type) >> 8) & 0x3ffff)
#define PcmciaRevisionFromControllerType(type)  ((type) >> 26)


DEFINE_GUID(GUID_PCMCIA_INTERFACE_STANDARD, \
  0xbed5dadfL, 0x38fb, 0x11d1, 0x94, 0x62, 0x00, 0xc0, 0x4f, 0xb9, 0x60, 0xee);

typedef ULONG MEMORY_SPACE;

typedef ULONG
(NTAPI *PPCMCIA_READ_WRITE_CONFIG)(
  IN PVOID  Context,
  IN ULONG  WhichSpace,
  IN PUCHAR  Buffer,
  IN ULONG  Offset,
  IN ULONG  Length);

#define PCCARD_PCI_CONFIGURATION_SPACE    0
#define PCCARD_ATTRIBUTE_MEMORY           1
#define PCCARD_COMMON_MEMORY              2
#define PCCARD_ATTRIBUTE_MEMORY_INDIRECT  3
#define PCCARD_COMMON_MEMORY_INDIRECT     4

typedef struct _PCMCIA_BUS_INTERFACE_STANDARD {
	USHORT  Size;
	USHORT  Version;
	PVOID  Context;
	PINTERFACE_REFERENCE  InterfaceReference;
	PINTERFACE_DEREFERENCE  InterfaceDereference;
	PPCMCIA_READ_WRITE_CONFIG ReadConfig;
	PPCMCIA_READ_WRITE_CONFIG  WriteConfig;
} PCMCIA_BUS_INTERFACE_STANDARD, *PPCMCIA_BUS_INTERFACE_STANDARD;

#define PCMCIA_MEMORY_8BIT_ACCESS         0
#define PCMCIA_MEMORY_16BIT_ACCESS        1

typedef BOOLEAN
(NTAPI *PPCMCIA_MODIFY_MEMORY_WINDOW)(
  IN PVOID  Context,
  IN ULONGLONG  HostBase,
  IN ULONGLONG  CardBase,
  IN BOOLEAN  Enable,
  IN ULONG  WindowSize  OPTIONAL,
  IN UCHAR  AccessSpeed  OPTIONAL,
  IN UCHAR  BusWidth  OPTIONAL,
  IN BOOLEAN  IsAttributeMemory  OPTIONAL);

#define PCMCIA_VPP_0V                     0
#define PCMCIA_VPP_12V                    1
#define PCMCIA_VPP_IS_VCC                 2

typedef BOOLEAN
(NTAPI *PPCMCIA_SET_VPP)(
  IN PVOID  Context,
  IN UCHAR  VppLevel);

typedef BOOLEAN
(NTAPI *PPCMCIA_IS_WRITE_PROTECTED)(
  IN PVOID  Context);

typedef struct _PCMCIA_INTERFACE_STANDARD {
	USHORT  Size;
	USHORT  Version;
	PINTERFACE_REFERENCE  InterfaceReference;
	PINTERFACE_DEREFERENCE  InterfaceDereference;
	PVOID  Context;
	PPCMCIA_MODIFY_MEMORY_WINDOW  ModifyMemoryWindow;
	PPCMCIA_SET_VPP  SetVpp;
	PPCMCIA_IS_WRITE_PROTECTED  IsWriteProtected;
} PCMCIA_INTERFACE_STANDARD, *PPCMCIA_INTERFACE_STANDARD;

#ifdef __cplusplus
}
#endif

#endif /* _NTDDPCMH_ */
