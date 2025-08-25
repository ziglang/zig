/*
 * smbus.h
 *
 * System Management Bus driver interface
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

#ifndef __SMBUS_H
#define __SMBUS_H

#ifdef __cplusplus
extern "C" {
#endif

#if !defined(SMBCLASS)
#define SMBCLASSAPI DECLSPEC_IMPORT
#else
#define SMBCLASSAPI
#endif

#define SMB_BUS_REQUEST \
  CTL_CODE(FILE_DEVICE_UNKNOWN, 0, METHOD_NEITHER, FILE_ANY_ACCESS)

#define SMB_DEREGISTER_ALARM_NOTIFY \
  CTL_CODE(FILE_DEVICE_UNKNOWN, 2, METHOD_NEITHER, FILE_ANY_ACCESS)

#define SMB_REGISTER_ALARM_NOTIFY \
  CTL_CODE(FILE_DEVICE_UNKNOWN, 1, METHOD_NEITHER, FILE_ANY_ACCESS)


struct _SMB_CLASS;

#define SMB_MAX_DATA_SIZE                 32

/* SMB_REQUEST.Status constants */
#define SMB_STATUS_OK                     0x00
#define SMB_UNKNOWN_FAILURE               0x07
#define SMB_ADDRESS_NOT_ACKNOWLEDGED      0x10
#define SMB_DEVICE_ERROR                  0x11
#define SMB_COMMAND_ACCESS_DENIED         0x12
#define SMB_UNKNOWN_ERROR                 0x13
#define SMB_DEVICE_ACCESS_DENIED          0x17
#define SMB_TIMEOUT                       0x18
#define SMB_UNSUPPORTED_PROTOCOL          0x19
#define SMB_BUS_BUSY                      0x1A

/* SMB_REQUEST.Protocol constants */
#define SMB_WRITE_QUICK                   0x00
#define SMB_READ_QUICK                    0x01
#define SMB_SEND_BYTE                     0x02
#define SMB_RECEIVE_BYTE                  0x03
#define SMB_WRITE_BYTE                    0x04
#define SMB_READ_BYTE                     0x05
#define SMB_WRITE_WORD                    0x06
#define SMB_READ_WORD                     0x07
#define SMB_WRITE_BLOCK                   0x08
#define SMB_READ_BLOCK                    0x09
#define SMB_PROCESS_CALL                  0x0A
#define SMB_MAXIMUM_PROTOCOL              0x0A

typedef struct _SMB_REQUEST {
  UCHAR  Status;
  UCHAR  Protocol;
  UCHAR  Address;
  UCHAR  Command;
  UCHAR  BlockLength;
  UCHAR  Data[SMB_MAX_DATA_SIZE];
} SMB_REQUEST, *PSMB_REQUEST;

typedef VOID
(NTAPI *SMB_ALARM_NOTIFY)(
  PVOID  Context,
  UCHAR  Address,
  USHORT  Data);

typedef struct _SMB_REGISTER_ALARM {
  UCHAR  MinAddress;
  UCHAR  MaxAddress;
  SMB_ALARM_NOTIFY  NotifyFunction;
  PVOID  NotifyContext;
} SMB_REGISTER_ALARM, *PSMB_REGISTER_ALARM;

/* SMB_CLASS.XxxVersion constants */
#define SMB_CLASS_MAJOR_VERSION           0x0001
#define SMB_CLASS_MINOR_VERSION           0x0000

typedef NTSTATUS
(NTAPI *SMB_RESET_DEVICE)(
  IN struct _SMB_CLASS  *SmbClass,
  IN PVOID  SmbMiniport);

typedef VOID
(NTAPI *SMB_START_IO)(
  IN struct _SMB_CLASS  *SmbClass,
  IN PVOID  SmbMiniport);

typedef NTSTATUS
(NTAPI *SMB_STOP_DEVICE)(
  IN struct _SMB_CLASS  *SmbClass,
  IN PVOID  SmbMiniport);

typedef struct _SMB_CLASS {
  USHORT  MajorVersion;
  USHORT  MinorVersion;
  PVOID  Miniport;
  PDEVICE_OBJECT  DeviceObject;
  PDEVICE_OBJECT  PDO;
  PDEVICE_OBJECT  LowerDeviceObject;
  PIRP  CurrentIrp;
  PSMB_REQUEST  CurrentSmb;
  SMB_RESET_DEVICE  ResetDevice;
  SMB_START_IO  StartIo;
  SMB_STOP_DEVICE  StopDevice;
} SMB_CLASS, *PSMB_CLASS;

SMBCLASSAPI
VOID
NTAPI
SmbClassAlarm(
  IN PSMB_CLASS  SmbClass,
  IN UCHAR  Address,
  IN USHORT  Data);

SMBCLASSAPI
VOID
NTAPI
SmbClassCompleteRequest(
  IN PSMB_CLASS  SmbClass);

typedef NTSTATUS
(NTAPI *PSMB_INITIALIZE_MINIPORT)(
  IN PSMB_CLASS  SmbClass,
  IN PVOID  MiniportExtension,
  IN PVOID  MiniportContext);

SMBCLASSAPI
NTSTATUS
NTAPI
SmbClassCreateFdo(
  IN PDRIVER_OBJECT  DriverObject,
  IN PDEVICE_OBJECT  PDO,
  IN ULONG  MiniportExtensionSize,
  IN PSMB_INITIALIZE_MINIPORT  MiniportInitialize,
  IN PVOID  MiniportContext,
  OUT PDEVICE_OBJECT  *FDO);

SMBCLASSAPI
NTSTATUS
NTAPI
SmbClassInitializeDevice(
  IN ULONG  MajorVersion,
  IN ULONG  MinorVersion,
  IN PDRIVER_OBJECT  DriverObject);

SMBCLASSAPI
VOID
NTAPI
SmbClassLockDevice(
  IN PSMB_CLASS  SmbClass);

SMBCLASSAPI
VOID
NTAPI
SmbClassUnlockDevice(
  IN PSMB_CLASS  SmbClass);

#ifdef __cplusplus
}
#endif

#endif /* __SMBUS_H */

