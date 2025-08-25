/*
 * usbrpmif.h
 *
 * This file is part of the ReactOS PSDK package.
 *
 * Contributors:
 *   Created by Amine Khaldi <amine.khaldi@reactos.org>
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

#pragma once

#include "windef.h"
#include "usb100.h"

#if !defined(_USBRPM_DRIVER_)
#define USBRPMAPI DECLSPEC_IMPORT
#else
#define USBRPMAPI
#endif

typedef struct _USBRPM_DEVICE_INFORMATION {
  ULONG64 HubId;
  ULONG ConnectionIndex;
  UCHAR DeviceClass;
  USHORT VendorId;
  USHORT ProductId;
  WCHAR ManufacturerString[MAXIMUM_USB_STRING_LENGTH];
  WCHAR ProductString[MAXIMUM_USB_STRING_LENGTH];
  WCHAR HubSymbolicLinkName[MAX_PATH];
} USBRPM_DEVICE_INFORMATION, *PUSBRPM_DEVICE_INFORMATION;

typedef struct _USBRPM_DEVICE_LIST {
  ULONG NumberOfDevices;
  USBRPM_DEVICE_INFORMATION Device[0];
} USBRPM_DEVICE_LIST, *PUSBRPM_DEVICE_LIST;

USBRPMAPI
NTSTATUS
NTAPI
RPMRegisterAlternateDriver(
  PDRIVER_OBJECT  DriverObject,
  LPCWSTR CompatibleId, 
  PHANDLE RegisteredDriver);

USBRPMAPI
NTSTATUS
NTAPI
RPMUnregisterAlternateDriver(
  HANDLE RegisteredDriver);

USBRPMAPI
NTSTATUS
RPMGetAvailableDevices(
  HANDLE RegisteredDriver,
  USHORT Locale,
  PUSBRPM_DEVICE_LIST *DeviceList);

USBRPMAPI
NTSTATUS
NTAPI
RPMLoadAlternateDriverForDevice(
  HANDLE RegisteredDriver,
  ULONG64 HubID,
  ULONG ConnectionIndex,
  REFGUID OwnerGuid);

USBRPMAPI
NTSTATUS
NTAPI
RPMUnloadAlternateDriverForDevice(
  HANDLE RegisteredDriver,
  ULONG64 HubID,
  ULONG ConnectionIndex);
