/*
 * scsiwmi.h
 *
 * SCSI WMILIB interface.
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

#ifndef __SCSIWMI_H
#define __SCSIWMI_H

#include "srb.h"

#ifdef __cplusplus
extern "C" {
#endif

#pragma pack(push,4)

typedef struct _SCSIWMI_REQUEST_CONTEXT {
  PVOID  UserContext;
  ULONG  BufferSize;
  PUCHAR  Buffer;
  UCHAR  MinorFunction;
  UCHAR  ReturnStatus;
  ULONG  ReturnSize;
} SCSIWMI_REQUEST_CONTEXT, *PSCSIWMI_REQUEST_CONTEXT;

#ifdef _GUID_DEFINED
# warning _GUID_DEFINED is deprecated, use GUID_DEFINED instead
#endif

#if ! (defined _GUID_DEFINED || defined GUID_DEFINED)
#define GUID_DEFINED
typedef struct _GUID {
    ULONG          Data1;
    unsigned short Data2;
    unsigned short Data3;
    unsigned char  Data4[ 8 ];
} GUID;
#endif

typedef struct _SCSIWMIGUIDREGINFO {
  LPCGUID  Guid;
  ULONG  InstanceCount;
  ULONG  Flags;
} SCSIWMIGUIDREGINFO, *PSCSIWMIGUIDREGINFO;

typedef UCHAR
(NTAPI *PSCSIWMI_QUERY_REGINFO)(
	IN PVOID  DeviceContext,
	IN PSCSIWMI_REQUEST_CONTEXT  RequestContext,
	OUT PWCHAR  *MofResourceName);

typedef BOOLEAN
(NTAPI *PSCSIWMI_QUERY_DATABLOCK)(
  IN PVOID  Context,
  IN PSCSIWMI_REQUEST_CONTEXT  DispatchContext,
  IN ULONG  GuidIndex,
  IN ULONG  InstanceIndex,
  IN ULONG  InstanceCount,
  IN OUT PULONG  InstanceLengthArray,
  IN ULONG  BufferAvail,
  OUT PUCHAR  Buffer);

typedef BOOLEAN
(NTAPI *PSCSIWMI_SET_DATABLOCK)(
  IN PVOID  DeviceContext,
  IN PSCSIWMI_REQUEST_CONTEXT  RequestContext,
  IN ULONG  GuidIndex,
  IN ULONG  InstanceIndex,
  IN ULONG  BufferSize,
  IN PUCHAR  Buffer);

typedef BOOLEAN
(NTAPI *PSCSIWMI_SET_DATAITEM)(
  IN PVOID  DeviceContext,
  IN PSCSIWMI_REQUEST_CONTEXT  RequestContext,
  IN ULONG  GuidIndex,
  IN ULONG  InstanceIndex,
  IN ULONG  DataItemId,
  IN ULONG  BufferSize,
  IN PUCHAR  Buffer);

typedef BOOLEAN
(NTAPI *PSCSIWMI_EXECUTE_METHOD)(
  IN PVOID  DeviceContext,
  IN PSCSIWMI_REQUEST_CONTEXT  RequestContext,
  IN ULONG  GuidIndex,
  IN ULONG  InstanceIndex,
  IN ULONG  MethodId,
  IN ULONG  InBufferSize,
  IN ULONG  OutBufferSize,
  IN OUT PUCHAR  Buffer);

typedef enum _SCSIWMI_ENABLE_DISABLE_CONTROL {
	ScsiWmiEventControl,
	ScsiWmiDataBlockControl
} SCSIWMI_ENABLE_DISABLE_CONTROL;

typedef BOOLEAN
(NTAPI *PSCSIWMI_FUNCTION_CONTROL)(
  IN PVOID  DeviceContext,
  IN PSCSIWMI_REQUEST_CONTEXT  RequestContext,
  IN ULONG  GuidIndex,
  IN SCSIWMI_ENABLE_DISABLE_CONTROL  Function,
  IN BOOLEAN  Enable);

typedef struct _SCSIWMILIB_CONTEXT {
  ULONG  GuidCount;
  PSCSIWMIGUIDREGINFO  GuidList;
  PSCSIWMI_QUERY_REGINFO  QueryWmiRegInfo;
  PSCSIWMI_QUERY_DATABLOCK  QueryWmiDataBlock;
  PSCSIWMI_SET_DATABLOCK  SetWmiDataBlock;
  PSCSIWMI_SET_DATAITEM  SetWmiDataItem;
  PSCSIWMI_EXECUTE_METHOD  ExecuteWmiMethod;
  PSCSIWMI_FUNCTION_CONTROL  WmiFunctionControl;
} SCSI_WMILIB_CONTEXT, *PSCSI_WMILIB_CONTEXT;

SCSIPORTAPI
BOOLEAN
NTAPI
ScsiPortWmiDispatchFunction(
  IN PSCSI_WMILIB_CONTEXT  WmiLibInfo,
  IN UCHAR  MinorFunction,
  IN PVOID  DeviceContext,
  IN PSCSIWMI_REQUEST_CONTEXT  RequestContext,
  IN PVOID  DataPath,
  IN ULONG  BufferSize,
  IN PVOID  Buffer);

#define ScsiPortWmiFireAdapterEvent(  \
  HwDeviceExtension,                  \
  Guid,                               \
  InstanceIndex,                      \
  EventDataSize,                      \
  EventData)                          \
    ScsiPortWmiFireLogicalUnitEvent(  \
	  HwDeviceExtension,                \
	  0xff,                             \
	  0,                                \
	  0,                                \
	  Guid,                             \
	  InstanceIndex,                    \
	  EventDataSize,                    \
	  EventData)

/*
 * ULONG
 * ScsiPortWmiGetReturnSize(
 *   PSCSIWMI_REQUEST_CONTEXT  RequestContext);
 */
#define ScsiPortWmiGetReturnSize(RequestContext) \
  ((RequestContext)->ReturnSize)

/* UCHAR
 * ScsiPortWmiGetReturnStatus(
 *   PSCSIWMI_REQUEST_CONTEXT  RequestContext);
 */
#define ScsiPortWmiGetReturnStatus(RequestContext) \
  ((RequestContext)->ReturnStatus)

SCSIPORTAPI
VOID
NTAPI
ScsiPortWmiPostProcess(
  IN PSCSIWMI_REQUEST_CONTEXT  RequestContext,
  IN UCHAR  SrbStatus,
  IN ULONG  BufferUsed);

SCSIPORTAPI
VOID
NTAPI
ScsiPortWmiFireLogicalUnitEvent(
  IN PVOID  HwDeviceExtension,
  IN UCHAR  PathId,
  IN UCHAR  TargetId,
  IN UCHAR  Lun,
  IN LPGUID  Guid,
  IN ULONG  InstanceIndex,
  IN ULONG  EventDataSize,
  IN PVOID  EventData);

#pragma pack(pop)

#ifdef __cplusplus
}
#endif

#endif /* __SCSIWMI_H */
