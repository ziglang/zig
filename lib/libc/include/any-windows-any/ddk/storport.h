/*
 * storport.h
 *
 * StorPort interface
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

#ifndef __STORPORT_H
#define __STORPORT_H

#include "srb.h"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_STORPORT_)
#define STORPORTAPI
#else
#define STORPORTAPI DECLSPEC_IMPORT
#endif


typedef PHYSICAL_ADDRESS STOR_PHYSICAL_ADDRESS;

typedef struct _STOR_SCATTER_GATHER_ELEMENT {
	STOR_PHYSICAL_ADDRESS  PhysicalAddress;
	ULONG  Length;
	ULONG_PTR  Reserved;
} STOR_SCATTER_GATHER_ELEMENT, *PSTOR_SCATTER_GATHER_ELEMENT;

typedef struct _STOR_SCATTER_GATHER_LIST {
    ULONG  NumberOfElements;
    ULONG_PTR  Reserved;
    STOR_SCATTER_GATHER_ELEMENT  List[0];
} STOR_SCATTER_GATHER_LIST, *PSTOR_SCATTER_GATHER_LIST;

typedef struct _SCSI_WMI_REQUEST_BLOCK {
  USHORT  Length;
  UCHAR  Function;
  UCHAR  SrbStatus;
  UCHAR  WMISubFunction;
  UCHAR  PathId;
  UCHAR  TargetId;
  UCHAR  Lun;
  UCHAR  Reserved1;
  UCHAR  WMIFlags;
  UCHAR  Reserved2[2];
  ULONG  SrbFlags;
  ULONG  DataTransferLength;
  ULONG  TimeOutValue;
  PVOID  DataBuffer;
  PVOID  DataPath;
  PVOID  Reserved3;
  PVOID  OriginalRequest;
  PVOID  SrbExtension;
  ULONG  Reserved4;
  UCHAR  Reserved5[16];
} SCSI_WMI_REQUEST_BLOCK, *PSCSI_WMI_REQUEST_BLOCK;


STORPORTAPI
ULONG
NTAPI
StorPortInitialize(
  IN PVOID  Argument1,
  IN PVOID  Argument2,
  IN PHW_INITIALIZATION_DATA  HwInitializationData,
  IN PVOID  Unused);

STORPORTAPI
VOID
NTAPI
StorPortFreeDeviceBase(
  IN PVOID  HwDeviceExtension,
  IN PVOID  MappedAddress);

STORPORTAPI
ULONG
NTAPI
StorPortGetBusData(
  IN PVOID  DeviceExtension,
  IN ULONG  BusDataType,
  IN ULONG  SystemIoBusNumber,
  IN ULONG  SlotNumber,
  IN PVOID  Buffer,
  IN ULONG  Length);

STORPORTAPI
ULONG
NTAPI
StorPortSetBusDataByOffset(
  IN PVOID  DeviceExtension,
  IN ULONG   BusDataType,
  IN ULONG  SystemIoBusNumber,
  IN ULONG  SlotNumber,
  IN PVOID  Buffer,
  IN ULONG  Offset,
  IN ULONG  Length);

STORPORTAPI
PVOID
NTAPI
StorPortGetDeviceBase(
  IN PVOID  HwDeviceExtension,
  IN INTERFACE_TYPE  BusType,
  IN ULONG  SystemIoBusNumber,
  IN SCSI_PHYSICAL_ADDRESS  IoAddress,
  IN ULONG  NumberOfBytes,
  IN BOOLEAN  InIoSpace);

STORPORTAPI
PVOID
NTAPI
StorPortGetLogicalUnit(
  IN PVOID  HwDeviceExtension,
  IN UCHAR  PathId,
  IN UCHAR  TargetId,
  IN UCHAR  Lun);

STORPORTAPI
PSCSI_REQUEST_BLOCK
NTAPI
StorPortGetSrb(
  IN PVOID  DeviceExtension,
  IN UCHAR  PathId,
  IN UCHAR  TargetId,
  IN UCHAR  Lun,
  IN LONG  QueueTag);

STORPORTAPI
STOR_PHYSICAL_ADDRESS
NTAPI
StorPortGetPhysicalAddress(
  IN PVOID  HwDeviceExtension,
  IN PSCSI_REQUEST_BLOCK  Srb,
  IN PVOID  VirtualAddress,
  OUT ULONG  *Length);

STORPORTAPI
PVOID
NTAPI
StorPortGetVirtualAddress(
  IN PVOID  HwDeviceExtension,
  IN STOR_PHYSICAL_ADDRESS  PhysicalAddress);

STORPORTAPI
PVOID
NTAPI
StorPortGetUncachedExtension(
  IN PVOID HwDeviceExtension,
  IN PPORT_CONFIGURATION_INFORMATION ConfigInfo,
  IN ULONG NumberOfBytes);

STORPORTAPI
VOID
__cdecl
StorPortNotification(
  IN SCSI_NOTIFICATION_TYPE  NotificationType,
  IN PVOID  HwDeviceExtension,
  IN ...);

STORPORTAPI
VOID
NTAPI
StorPortLogError(
  IN PVOID  HwDeviceExtension,
  IN PSCSI_REQUEST_BLOCK  Srb OPTIONAL,
  IN UCHAR  PathId,
  IN UCHAR  TargetId,
  IN UCHAR  Lun,
  IN ULONG  ErrorCode,
  IN ULONG  UniqueId);

STORPORTAPI
VOID
NTAPI
StorPortCompleteRequest(
  IN PVOID  HwDeviceExtension,
  IN UCHAR  PathId,
  IN UCHAR  TargetId,
  IN UCHAR  Lun,
  IN UCHAR  SrbStatus);

STORPORTAPI
VOID
NTAPI
StorPortMoveMemory(
  IN PVOID  WriteBuffer,
  IN PVOID  ReadBuffer,
  IN ULONG  Length);

STORPORTAPI
VOID
NTAPI
StorPortStallExecution(
  IN ULONG  Delay);

STORPORTAPI
STOR_PHYSICAL_ADDRESS
NTAPI
StorPortConvertUlong64ToPhysicalAddress(
  IN ULONG64  UlongAddress);

STORPORTAPI
ULONG64
NTAPI
StorPortConvertPhysicalAddressToUlong64(
  IN STOR_PHYSICAL_ADDRESS  Address);

STORPORTAPI
BOOLEAN
NTAPI
StorPortValidateRange(
  IN PVOID  HwDeviceExtension,
  IN INTERFACE_TYPE  BusType,
  IN ULONG  SystemIoBusNumber,
  IN STOR_PHYSICAL_ADDRESS  IoAddress,
  IN ULONG  NumberOfBytes,
  IN BOOLEAN  InIoSpace);

STORPORTAPI
VOID
__cdecl
StorPortDebugPrint(
  IN ULONG  DebugPrintLevel,
  IN PCCHAR  DebugMessage,
  IN ...);

STORPORTAPI
UCHAR
NTAPI
StorPortReadPortUchar(
  IN PUCHAR  Port);

STORPORTAPI
ULONG
NTAPI
StorPortReadPortUlong(
  IN PULONG  Port);

STORPORTAPI
USHORT
NTAPI
StorPortReadPortUshort(
  IN PUSHORT  Port);

STORPORTAPI
UCHAR
NTAPI
StorPortReadRegisterUchar(
  IN PUCHAR  Register);

STORPORTAPI
ULONG
NTAPI
StorPortReadRegisterUlong(
  IN PULONG  Register);

STORPORTAPI
USHORT
NTAPI
StorPortReadRegisterUshort(
  IN PUSHORT  Register);

STORPORTAPI
VOID
NTAPI
StorPortWritePortUchar(
  IN PUCHAR  Port,
  IN UCHAR  Value);

STORPORTAPI
VOID
NTAPI
StorPortWritePortUlong(
  IN PULONG  Port,
  IN ULONG  Value);

STORPORTAPI
VOID
NTAPI
StorPortWritePortUshort(
  IN PUSHORT  Port,
  IN USHORT  Value);

STORPORTAPI
VOID
NTAPI
StorPortWriteRegisterUchar(
  IN PUCHAR  Port,
  IN UCHAR  Value);

STORPORTAPI
VOID
NTAPI
StorPortWriteRegisterUlong(
  IN PULONG  Port,
  IN ULONG  Value);

STORPORTAPI
VOID
NTAPI
StorPortWriteRegisterUshort(
  IN PUSHORT  Port,
  IN USHORT  Value);

STORPORTAPI
BOOLEAN
NTAPI
StorPortPauseDevice(
  IN PVOID  HwDeviceExtension,
  IN UCHAR  PathId,
  IN UCHAR  TargetId,
  IN UCHAR  Lun,
  IN ULONG  TimeOut);

STORPORTAPI
BOOLEAN
NTAPI
StorPortResumeDevice(
  IN PVOID  HwDeviceExtension,
  IN UCHAR  PathId,
  IN UCHAR  TargetId,
  IN UCHAR  Lun);

STORPORTAPI
BOOLEAN
NTAPI
StorPortPause(
  IN PVOID  HwDeviceExtension,
  IN ULONG  TimeOut);

STORPORTAPI
BOOLEAN
NTAPI
StorPortResume(
  IN PVOID  HwDeviceExtension);

STORPORTAPI
BOOLEAN
NTAPI
StorPortDeviceBusy(
  IN PVOID  HwDeviceExtension,
  IN UCHAR  PathId,
  IN UCHAR  TargetId,
  IN UCHAR  Lun,
  IN ULONG  RequestsToComplete);

STORPORTAPI
BOOLEAN
NTAPI
StorPortDeviceReady(
  IN PVOID  HwDeviceExtension,
  IN UCHAR  PathId,
  IN UCHAR  TargetId,
  IN UCHAR  Lun);

STORPORTAPI
BOOLEAN
NTAPI
StorPortBusy(
  IN PVOID  HwDeviceExtension,
  IN ULONG  RequestsToComplete);

STORPORTAPI
BOOLEAN
NTAPI
StorPortReady(
  IN PVOID  HwDeviceExtension);

STORPORTAPI
PSTOR_SCATTER_GATHER_LIST
NTAPI
StorPortGetScatterGatherList(
  IN PVOID  DeviceExtension,
  IN PSCSI_REQUEST_BLOCK  Srb);

typedef BOOLEAN
(NTAPI *PSTOR_SYNCHRONIZED_ACCESS)(
  IN PVOID  HwDeviceExtension,
  IN PVOID  Context);

STORPORTAPI
VOID
NTAPI
StorPortSynchronizeAccess(
  IN PVOID  HwDeviceExtension,
  IN PSTOR_SYNCHRONIZED_ACCESS  SynchronizedAccessRoutine,
  IN PVOID  Context);

#if DBG
#define DebugPrint(x) StorPortDebugPrint x
#else
#define DebugPrint(x)
#endif

#ifdef __cplusplus
}
#endif

#endif /* __STORPORT_H */
