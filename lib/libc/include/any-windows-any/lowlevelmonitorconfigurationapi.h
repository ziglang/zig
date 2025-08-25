/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef LowLevelMonitorConfigurationAPI_h
#define LowLevelMonitorConfigurationAPI_h

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#include <physicalmonitorenumerationapi.h>

#ifdef __cplusplus
extern "C" {
#endif

#pragma pack(push, 1)

typedef struct _MC_TIMING_REPORT {
  DWORD dwHorizontalFrequencyInHZ;
  DWORD dwVerticalFrequencyInHZ;
  BYTE bTimingStatusByte;
} MC_TIMING_REPORT, *LPMC_TIMING_REPORT;

typedef enum _MC_VCP_CODE_TYPE {
  MC_MOMENTARY,
  MC_SET_PARAMETER
} MC_VCP_CODE_TYPE, *LPMC_VCP_CODE_TYPE;

_BOOL WINAPI GetVCPFeatureAndVCPFeatureReply(HANDLE hMonitor, BYTE bVCPCode, LPMC_VCP_CODE_TYPE pvct, LPDWORD pdwCurrentValue, LPDWORD pdwMaximumValue);
_BOOL WINAPI SetVCPFeature(HANDLE hMonitor, BYTE bVCPCode, DWORD dwNewValue);
_BOOL WINAPI SaveCurrentSettings(HANDLE hMonitor);
_BOOL WINAPI GetCapabilitiesStringLength(HANDLE hMonitor, LPDWORD pdwCapabilitiesStringLengthInCharacters);
_BOOL WINAPI CapabilitiesRequestAndCapabilitiesReply(HANDLE hMonitor, LPSTR pszASCIICapabilitiesString, DWORD dwCapabilitiesStringLengthInCharacters);
_BOOL WINAPI GetTimingReport(HANDLE hMonitor, LPMC_TIMING_REPORT pmtrMonitorTimingReport);

#pragma pack(pop)

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#endif /* LowLevelMonitorConfigurationAPI_h */
