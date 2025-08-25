/*
 * videoagp.h
 *
 * Video miniport AGP interface
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

#pragma once

#define __VIDEOAGP_H__

#ifdef __cplusplus
extern "C" {
#endif

#define VIDEO_AGP_RATE_1X                 0x00000001
#define VIDEO_AGP_RATE_2X                 0x00000002
#define VIDEO_AGP_RATE_4X                 0x00000004
#define VIDEO_AGP_RATE_8X                 0x00000008

typedef enum _VIDEO_PORT_CACHE_TYPE {
  VpNonCached = 0,
  VpWriteCombined,
  VpCached
} VIDEO_PORT_CACHE_TYPE;

typedef BOOLEAN
(NTAPI *PAGP_COMMIT_PHYSICAL)(
  IN PVOID HwDeviceExtension,
  IN PVOID PhysicalReserveContext,
  IN ULONG Pages,
  IN ULONG Offset);

typedef PVOID
(NTAPI *PAGP_COMMIT_VIRTUAL)(
  IN PVOID HwDeviceExtension,
  IN PVOID VirtualReserveContext,
  IN ULONG Pages,
  IN ULONG Offset);

typedef VOID
(NTAPI *PAGP_FREE_PHYSICAL)(
  IN PVOID HwDeviceExtension,
  IN PVOID PhysicalReserveContext,
  IN ULONG Pages,
  IN ULONG Offset);

typedef VOID
(NTAPI *PAGP_FREE_VIRTUAL)(
  IN PVOID HwDeviceExtension,
  IN PVOID VirtualReserveContext,
  IN ULONG Pages,
  IN ULONG Offset);

typedef VOID
(NTAPI *PAGP_RELEASE_PHYSICAL)(
  IN PVOID HwDeviceExtension,
  IN PVOID PhysicalReserveContext);

typedef VOID
(NTAPI *PAGP_RELEASE_VIRTUAL)(
  IN PVOID HwDeviceExtension,
  IN PVOID VirtualReserveContext);

typedef PHYSICAL_ADDRESS
(NTAPI *PAGP_RESERVE_PHYSICAL)(
  IN PVOID HwDeviceExtension,
  IN ULONG Pages,
  IN VIDEO_PORT_CACHE_TYPE  Caching,
  OUT PVOID *PhysicalReserveContext);

typedef PVOID
(NTAPI *PAGP_RESERVE_VIRTUAL)(
  IN PVOID HwDeviceExtension,
  IN HANDLE ProcessHandle,
  IN PVOID PhysicalReserveContext,
  OUT PVOID *VirtualReserveContext);

typedef BOOLEAN
(NTAPI *PAGP_SET_RATE)(
  IN PVOID HwDeviceExtension,
  IN ULONG AgpRate);

typedef struct _VIDEO_PORT_AGP_SERVICES {
  PAGP_RESERVE_PHYSICAL AgpReservePhysical;
  PAGP_RELEASE_PHYSICAL AgpReleasePhysical;
  PAGP_COMMIT_PHYSICAL AgpCommitPhysical;
  PAGP_FREE_PHYSICAL AgpFreePhysical;
  PAGP_RESERVE_VIRTUAL AgpReserveVirtual;
  PAGP_RELEASE_VIRTUAL AgpReleaseVirtual;
  PAGP_COMMIT_VIRTUAL AgpCommitVirtual;
  PAGP_FREE_VIRTUAL AgpFreeVirtual;
  ULONGLONG AllocationLimit;
} VIDEO_PORT_AGP_SERVICES, *PVIDEO_PORT_AGP_SERVICES;

BOOLEAN
NTAPI
VideoPortGetAgpServices(
  IN PVOID HwDeviceExtension,
  IN PVIDEO_PORT_AGP_SERVICES AgpServices);

#ifdef __cplusplus
}
#endif
