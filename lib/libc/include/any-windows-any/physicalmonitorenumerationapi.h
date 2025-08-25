/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef PhysicalMonitorEnumerationAPI_h
#define PhysicalMonitorEnumerationAPI_h

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <d3d9.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PHYSICAL_MONITOR_DESCRIPTION_SIZE 128

  typedef WINBOOL _BOOL;

#include <pshpack1.h>

  typedef struct _PHYSICAL_MONITOR {
    HANDLE hPhysicalMonitor;
    WCHAR szPhysicalMonitorDescription[PHYSICAL_MONITOR_DESCRIPTION_SIZE];
  } PHYSICAL_MONITOR,*LPPHYSICAL_MONITOR;

#include <poppack.h>

  _BOOL WINAPI DestroyPhysicalMonitor (HANDLE hMonitor);
  _BOOL WINAPI DestroyPhysicalMonitors (DWORD dwPhysicalMonitorArraySize, LPPHYSICAL_MONITOR pPhysicalMonitorArray);
  _BOOL WINAPI GetNumberOfPhysicalMonitorsFromHMONITOR (HMONITOR hMonitor, LPDWORD pdwNumberOfPhysicalMonitors);
  HRESULT WINAPI GetNumberOfPhysicalMonitorsFromIDirect3DDevice9 (IDirect3DDevice9 *pDirect3DDevice9, LPDWORD pdwNumberOfPhysicalMonitors);
  _BOOL WINAPI GetPhysicalMonitorsFromHMONITOR (HMONITOR hMonitor, DWORD dwPhysicalMonitorArraySize, LPPHYSICAL_MONITOR pPhysicalMonitorArray);
  HRESULT WINAPI GetPhysicalMonitorsFromIDirect3DDevice9 (IDirect3DDevice9 *pDirect3DDevice9, DWORD dwPhysicalMonitorArraySize, LPPHYSICAL_MONITOR pPhysicalMonitorArray);

#ifdef __cplusplus
}
#endif
#endif
#endif
