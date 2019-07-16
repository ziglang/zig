/*
 * newdev.h
 *
 * Driver installation DLL interface
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

#include <setupapi.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <pshpack1.h>

/* UpdateDriverForPlugAndPlayDevices.InstallFlags constants */
#define INSTALLFLAG_FORCE                 0x00000001
#define INSTALLFLAG_READONLY              0x00000002
#define INSTALLFLAG_NONINTERACTIVE        0x00000004
#define INSTALLFLAG_BITS                  0x00000007

#if (WINVER >= _WIN32_WINNT_WIN2K)

WINBOOL
WINAPI
UpdateDriverForPlugAndPlayDevicesA(
  HWND hwndParent,
  LPCSTR HardwareId,
  LPCSTR FullInfPath,
  DWORD InstallFlags,
  PBOOL bRebootRequired OPTIONAL);

WINBOOL
WINAPI
UpdateDriverForPlugAndPlayDevicesW(
  HWND hwndParent,
  LPCWSTR HardwareId,
  LPCWSTR FullInfPath,
  DWORD InstallFlags,
  PBOOL bRebootRequired OPTIONAL);

#ifdef UNICODE
#define UpdateDriverForPlugAndPlayDevices UpdateDriverForPlugAndPlayDevicesW
#else
#define UpdateDriverForPlugAndPlayDevices UpdateDriverForPlugAndPlayDevicesA
#endif /* UNICODE */

#endif /* (WINVER >= _WIN32_WINNT_WIN2K) */

#if (WINVER >= _WIN32_WINNT_VISTA)

#define DIIDFLAG_SHOWSEARCHUI             0x00000001
#define DIIDFLAG_NOFINISHINSTALLUI        0x00000002
#define DIIDFLAG_INSTALLNULLDRIVER        0x00000004
#define DIIDFLAG_BITS                     0x00000007

#define DIIRFLAG_INF_ALREADY_COPIED       0x00000001
#define DIIRFLAG_FORCE_INF                0x00000002
#define DIIRFLAG_HW_USING_THE_INF         0x00000004
#define DIIRFLAG_HOTPATCH                 0x00000008
#define DIIRFLAG_NOBACKUP                 0x00000010
#define DIIRFLAG_BITS ( DIIRFLAG_FORCE_INF | DIIRFLAG_HOTPATCH)
#define DIIRFLAG_SYSTEM_BITS ( DIIRFLAG_INF_ALREADY_COPIED |\
                               DIIRFLAG_FORCE_INF |\
                               DIIRFLAG_HW_USING_THE_INF |\
                               DIIRFLAG_HOTPATCH |\
                               DIIRFLAG_NOBACKUP )

#define ROLLBACK_FLAG_NO_UI               0x00000001
#define ROLLBACK_BITS                     0x00000001

WINBOOL
WINAPI
DiInstallDevice(
  HWND hwndParent OPTIONAL,
  HDEVINFO DeviceInfoSet,
  PSP_DEVINFO_DATA DeviceInfoData,
  PSP_DRVINFO_DATA DriverInfoData OPTIONAL,
  DWORD Flags,
  PBOOL NeedReboot OPTIONAL);

WINBOOL
WINAPI
DiShowUpdateDevice(
  HWND hwndParent OPTIONAL,
  HDEVINFO DeviceInfoSet,
  PSP_DEVINFO_DATA DeviceInfoData,
  DWORD Flags,
  PBOOL NeedReboot OPTIONAL);

WINBOOL
WINAPI
DiRollbackDriver(
  HDEVINFO DeviceInfoSet,
  PSP_DEVINFO_DATA DeviceInfoData,
  HWND hwndParent OPTIONAL,
  DWORD Flags,
  PBOOL NeedReboot OPTIONAL);

WINBOOL
WINAPI
DiInstallDriverW(
  HWND hwndParent OPTIONAL,
  LPCWSTR InfPath,
  DWORD Flags,
  PBOOL NeedReboot OPTIONAL);

WINBOOL
WINAPI
DiInstallDriverA(
  HWND hwndParent OPTIONAL,
  LPCSTR InfPath,
  DWORD Flags,
  PBOOL NeedReboot OPTIONAL);


#ifdef UNICODE
#define DiInstallDriver DiInstallDriverW
#else
#define DiInstallDriver DiInstallDriverA
#endif

#endif /* (WINVER >= _WIN32_WINNT_VISTA) */

#if (WINVER >= _WIN32_WINNT_WIN7)
WINBOOL
WINAPI
DiUninstallDevice(
  HWND hwndParent,
  HDEVINFO DeviceInfoSet,
  PSP_DEVINFO_DATA DeviceInfoData,
  DWORD Flags,
  PBOOL NeedReboot OPTIONAL);
#endif /* (WINVER >= _WIN32_WINNT_WIN7) */

#include <poppack.h>

#ifdef __cplusplus
}
#endif
