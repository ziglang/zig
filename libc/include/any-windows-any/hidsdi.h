/*
 * hidsdi.h
 *
 * Public interface for USB HID user space functions.
 *
 * Contributors:
 *   Created by Simon Josefsson <simon@josefsson.org>
 *   Extended by Kai Tietz
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

#include <winapifamily.h>

#ifndef _HIDSDI_H
#define _HIDSDI_H

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <pshpack4.h>

typedef LONG NTSTATUS;

#include "hidusage.h"
#include "hidpi.h"

typedef struct _HIDD_CONFIGURATION {
  PVOID cookie;
  ULONG size;
  ULONG RingBufferSize;
} HIDD_CONFIGURATION,*PHIDD_CONFIGURATION;

typedef struct _HIDD_ATTRIBUTES {
  ULONG Size;
  USHORT VendorID;
  USHORT ProductID;
  USHORT VersionNumber;
} HIDD_ATTRIBUTES,*PHIDD_ATTRIBUTES;

BOOLEAN NTAPI HidD_FlushQueue (HANDLE HidDeviceObject);
BOOLEAN NTAPI HidD_FreePreparsedData (PHIDP_PREPARSED_DATA PreparsedData);
BOOLEAN NTAPI HidD_GetAttributes (HANDLE HidDeviceObject, PHIDD_ATTRIBUTES Attributes);
BOOLEAN NTAPI HidD_GetConfiguration (HANDLE HidDeviceObject, PHIDD_CONFIGURATION Configuration, ULONG ConfigurationLength);
BOOLEAN NTAPI HidD_GetFeature (HANDLE HidDeviceObject, PVOID ReportBuffer, ULONG ReportBufferLength);
void NTAPI HidD_GetHidGuid (LPGUID HidGuid);
BOOLEAN NTAPI HidD_GetInputReport (HANDLE HidDeviceObject, PVOID ReportBuffer, ULONG ReportBufferLength);
BOOLEAN NTAPI HidD_GetIndexedString (HANDLE HidDeviceObject, ULONG StringIndex, PVOID Buffer, ULONG BufferLength);
BOOLEAN NTAPI HidD_GetManufacturerString (HANDLE HidDeviceObject, PVOID Buffer, ULONG BufferLength);
BOOLEAN NTAPI HidD_GetMsGenreDescriptor (HANDLE HidDeviceObject, PVOID Buffer, ULONG BufferLength);
BOOLEAN NTAPI HidD_GetNumInputBuffers (HANDLE HidDeviceObject, PULONG NumberBuffers);
BOOLEAN NTAPI HidD_GetPhysicalDescriptor (HANDLE HidDeviceObject, PVOID Buffer, ULONG BufferLength);
BOOLEAN NTAPI HidD_GetPreparsedData (HANDLE HidDeviceObject, PHIDP_PREPARSED_DATA *PreparsedData);
BOOLEAN NTAPI HidD_GetProductString (HANDLE HidDeviceObject, PVOID Buffer, ULONG BufferLength);
BOOLEAN NTAPI HidD_GetSerialNumberString (HANDLE HidDeviceObject, PVOID Buffer, ULONG BufferLength);
BOOLEAN NTAPI HidD_SetConfiguration (HANDLE HidDeviceObject, PHIDD_CONFIGURATION Configuration, ULONG ConfigurationLength);
BOOLEAN NTAPI HidD_SetFeature (HANDLE HidDeviceObject, PVOID ReportBuffer, ULONG ReportBufferLength);
BOOLEAN NTAPI HidD_SetNumInputBuffers (HANDLE HidDeviceObject, ULONG NumberBuffers);
BOOLEAN NTAPI HidD_SetOutputReport (HANDLE HidDeviceObject, PVOID ReportBuffer, ULONG ReportBufferLength);

#include <poppack.h>

#endif
#endif
