/*
 * poclass.h
 *
 * Power policy driver interface
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

#ifndef __POCLASS_H
#define __POCLASS_H

#include "batclass.h"

#ifdef __cplusplus
extern "C" {
#endif

DEFINE_GUID(GUID_CLASS_INPUT,
  0x4D1E55B2L, 0xF16F, 0x11CF, 0x88, 0xCB, 0x00, 0x11, 0x11, 0x00, 0x00, 0x30);

DEFINE_GUID(GUID_DEVICE_LID,
  0x4AFA3D52L, 0x74A7, 0x11d0, 0xbe, 0x5e, 0x00, 0xA0, 0xC9, 0x06, 0x28, 0x57);

DEFINE_GUID(GUID_DEVICE_MEMORY,
  0x3fd0f03dL, 0x92e0, 0x45fb, 0xb7, 0x5c, 0x5e, 0xd8, 0xff, 0xb0, 0x10, 0x21);

DEFINE_GUID(GUID_DEVICE_MESSAGE_INDICATOR,
  0XCD48A365L, 0xfa94, 0x4ce2, 0xa2, 0x32, 0xa1, 0xb7, 0x64, 0xe5, 0xd8, 0xb4);

DEFINE_GUID(GUID_DEVICE_PROCESSOR,
  0x97fadb10L, 0x4e33, 0x40ae, 0x35, 0x9c, 0x8b, 0xef, 0x02, 0x9d, 0xbd, 0xd0);

DEFINE_GUID(GUID_DEVICE_SYS_BUTTON,
  0x4AFA3D53L, 0x74A7, 0x11d0, 0xbe, 0x5e, 0x00, 0xA0, 0xC9, 0x06, 0x28, 0x57);

DEFINE_GUID(GUID_DEVICE_THERMAL_ZONE,
  0x4AFA3D51L, 0x74A7, 0x11d0, 0xbe, 0x5e, 0x00, 0xA0, 0xC9, 0x06, 0x28, 0x57);


#define IOCTL_GET_PROCESSOR_OBJ_INFO \
  CTL_CODE(FILE_DEVICE_BATTERY, 0x60, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_GET_SYS_BUTTON_CAPS \
  CTL_CODE(FILE_DEVICE_BATTERY, 0x50, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_GET_SYS_BUTTON_EVENT \
  CTL_CODE(FILE_DEVICE_BATTERY, 0x51, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_SET_SYS_MESSAGE_INDICATOR \
  CTL_CODE(FILE_DEVICE_BATTERY, 0x70, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_NOTIFY_SWITCH_EVENT \
  CTL_CODE(FILE_DEVICE_BATTERY, 0x40, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_THERMAL_QUERY_INFORMATION \
  CTL_CODE(FILE_DEVICE_BATTERY, 0x20, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_THERMAL_SET_COOLING_POLICY \
  CTL_CODE(FILE_DEVICE_BATTERY, 0x21, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_QUERY_LID \
  CTL_CODE(FILE_DEVICE_BATTERY, 0x30, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_RUN_ACTIVE_COOLING_METHOD \
  CTL_CODE(FILE_DEVICE_BATTERY, 0x22, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define SYS_BUTTON_POWER                  0x00000001
#define SYS_BUTTON_SLEEP                  0x00000002
#define SYS_BUTTON_LID                    0x00000004
#define SYS_BUTTON_WAKE                   0x80000000

#define MAX_ACTIVE_COOLING_LEVELS         10
#define ACTIVE_COOLING                    0
#define PASSIVE_COOLING                   1

typedef struct _THERMAL_INFORMATION {
  ULONG  ThermalStamp;
  ULONG  ThermalConstant1;
  ULONG  ThermalConstant2;
  KAFFINITY  Processors;
  ULONG  SamplingPeriod;
  ULONG  CurrentTemperature;
  ULONG  PassiveTripPoint;
  ULONG  CriticalTripPoint;
  UCHAR  ActiveTripPointCount;
  ULONG  ActiveTripPoint[MAX_ACTIVE_COOLING_LEVELS];
} THERMAL_INFORMATION, *PTHERMAL_INFORMATION;

typedef struct _PROCESSOR_OBJECT_INFO {
	ULONG  PhysicalID;
	ULONG  PBlkAddress;
	UCHAR  PBlkLength;
} PROCESSOR_OBJECT_INFO, *PPROCESSOR_OBJECT_INFO;

#ifdef __cplusplus
}
#endif

#endif /* __POCLASS_H */
