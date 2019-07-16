/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _TIMEZONEAPI_H_
#define _TIMEZONEAPI_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)

#define TIME_ZONE_ID_INVALID ((DWORD)0xffffffff)

  typedef struct _TIME_ZONE_INFORMATION {
    LONG Bias;
    WCHAR StandardName[32];
    SYSTEMTIME StandardDate;
    LONG StandardBias;
    WCHAR DaylightName[32];
    SYSTEMTIME DaylightDate;
    LONG DaylightBias;
  } TIME_ZONE_INFORMATION,*PTIME_ZONE_INFORMATION,*LPTIME_ZONE_INFORMATION;

  typedef struct _TIME_DYNAMIC_ZONE_INFORMATION {
    LONG Bias;
    WCHAR StandardName[32];
    SYSTEMTIME StandardDate;
    LONG StandardBias;
    WCHAR DaylightName[32];
    SYSTEMTIME DaylightDate;
    LONG DaylightBias;
    WCHAR TimeZoneKeyName[128];
    BOOLEAN DynamicDaylightTimeDisabled;
  } DYNAMIC_TIME_ZONE_INFORMATION,*PDYNAMIC_TIME_ZONE_INFORMATION;

  WINBASEAPI WINBOOL WINAPI SystemTimeToTzSpecificLocalTime (CONST TIME_ZONE_INFORMATION *lpTimeZoneInformation, CONST SYSTEMTIME *lpUniversalTime, LPSYSTEMTIME lpLocalTime);
  WINBASEAPI WINBOOL WINAPI TzSpecificLocalTimeToSystemTime (CONST TIME_ZONE_INFORMATION *lpTimeZoneInformation, CONST SYSTEMTIME *lpLocalTime, LPSYSTEMTIME lpUniversalTime);
  WINBASEAPI WINBOOL WINAPI FileTimeToSystemTime (CONST FILETIME *lpFileTime, LPSYSTEMTIME lpSystemTime);
  WINBASEAPI WINBOOL WINAPI SystemTimeToFileTime (CONST SYSTEMTIME *lpSystemTime, LPFILETIME lpFileTime);
  WINBASEAPI DWORD WINAPI GetTimeZoneInformation (LPTIME_ZONE_INFORMATION lpTimeZoneInformation);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI DWORD WINAPI GetDynamicTimeZoneInformation (PDYNAMIC_TIME_ZONE_INFORMATION pTimeZoneInformation);
#endif
#if _WIN32_WINNT >= 0x0601
  WINBOOL WINAPI GetTimeZoneInformationForYear (USHORT wYear, PDYNAMIC_TIME_ZONE_INFORMATION pdtzi, LPTIME_ZONE_INFORMATION ptzi);
#endif
#if _WIN32_WINNT >= 0x0602
  WINBASEAPI DWORD WINAPI EnumDynamicTimeZoneInformation (CONST DWORD dwIndex, PDYNAMIC_TIME_ZONE_INFORMATION lpTimeZoneInformation);
  WINBASEAPI DWORD WINAPI GetDynamicTimeZoneInformationEffectiveYears (CONST PDYNAMIC_TIME_ZONE_INFORMATION lpTimeZoneInformation, LPDWORD FirstYear, LPDWORD LastYear);
  WINBASEAPI WINBOOL WINAPI SystemTimeToTzSpecificLocalTimeEx (CONST DYNAMIC_TIME_ZONE_INFORMATION *lpTimeZoneInformation, CONST SYSTEMTIME *lpUniversalTime, LPSYSTEMTIME lpLocalTime);
  WINBASEAPI WINBOOL WINAPI TzSpecificLocalTimeToSystemTimeEx (CONST DYNAMIC_TIME_ZONE_INFORMATION *lpTimeZoneInformation, CONST SYSTEMTIME *lpLocalTime, LPSYSTEMTIME lpUniversalTime);
#endif

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI SetTimeZoneInformation (CONST TIME_ZONE_INFORMATION *lpTimeZoneInformation);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI SetDynamicTimeZoneInformation (CONST DYNAMIC_TIME_ZONE_INFORMATION *lpTimeZoneInformation);
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
