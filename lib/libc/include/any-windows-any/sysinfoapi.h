/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _SYSINFOAPI_H_
#define _SYSINFOAPI_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  typedef struct _SYSTEM_INFO {
    __C89_NAMELESS union {
      DWORD dwOemId;
      __C89_NAMELESS struct {
	WORD wProcessorArchitecture;
	WORD wReserved;
      } DUMMYSTRUCTNAME;
    } DUMMYUNIONNAME;
    DWORD dwPageSize;
    LPVOID lpMinimumApplicationAddress;
    LPVOID lpMaximumApplicationAddress;
    DWORD_PTR dwActiveProcessorMask;
    DWORD dwNumberOfProcessors;
    DWORD dwProcessorType;
    DWORD dwAllocationGranularity;
    WORD wProcessorLevel;
    WORD wProcessorRevision;
  } SYSTEM_INFO, *LPSYSTEM_INFO;

  WINBASEAPI VOID WINAPI GetSystemTime (LPSYSTEMTIME lpSystemTime);
  WINBASEAPI VOID WINAPI GetSystemTimeAsFileTime (LPFILETIME lpSystemTimeAsFileTime);
  WINBASEAPI VOID WINAPI GetLocalTime (LPSYSTEMTIME lpSystemTime);
  WINBASEAPI VOID WINAPI GetNativeSystemInfo (LPSYSTEM_INFO lpSystemInfo);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI ULONGLONG WINAPI GetTickCount64 (VOID);
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || _WIN32_WINNT >= _WIN32_WINNT_WIN10

  typedef struct _MEMORYSTATUSEX {
    DWORD dwLength;
    DWORD dwMemoryLoad;
    DWORDLONG ullTotalPhys;
    DWORDLONG ullAvailPhys;
    DWORDLONG ullTotalPageFile;
    DWORDLONG ullAvailPageFile;
    DWORDLONG ullTotalVirtual;
    DWORDLONG ullAvailVirtual;
    DWORDLONG ullAvailExtendedVirtual;
  } MEMORYSTATUSEX,*LPMEMORYSTATUSEX;

  WINBASEAPI VOID WINAPI GetSystemInfo (LPSYSTEM_INFO lpSystemInfo);
  WINBASEAPI WINBOOL WINAPI GlobalMemoryStatusEx (LPMEMORYSTATUSEX lpBuffer);
  WINBASEAPI DWORD WINAPI GetTickCount (VOID);
  WINBASEAPI VOID WINAPI GetSystemTimePreciseAsFileTime (LPFILETIME lpSystemTimeAsFileTime);
  WINBASEAPI WINBOOL WINAPI GetVersionExA (LPOSVERSIONINFOA lpVersionInformation);
  WINBASEAPI WINBOOL WINAPI GetVersionExW (LPOSVERSIONINFOW lpVersionInformation);

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  typedef enum _COMPUTER_NAME_FORMAT {
    ComputerNameNetBIOS,
    ComputerNameDnsHostname,
    ComputerNameDnsDomain,
    ComputerNameDnsFullyQualified,
    ComputerNamePhysicalNetBIOS,
    ComputerNamePhysicalDnsHostname,
    ComputerNamePhysicalDnsDomain,
    ComputerNamePhysicalDnsFullyQualified,
    ComputerNameMax
  } COMPUTER_NAME_FORMAT;

  WINBASEAPI DWORD WINAPI GetVersion (VOID);

  WINBASEAPI WINBOOL WINAPI SetLocalTime (CONST SYSTEMTIME *lpSystemTime);
  WINBASEAPI WINBOOL WINAPI GetSystemTimeAdjustment (PDWORD lpTimeAdjustment, PDWORD lpTimeIncrement, PBOOL lpTimeAdjustmentDisabled);
  WINBASEAPI UINT WINAPI GetWindowsDirectoryA (LPSTR lpBuffer, UINT uSize);
  WINBASEAPI UINT WINAPI GetWindowsDirectoryW (LPWSTR lpBuffer, UINT uSize);
  WINBASEAPI UINT WINAPI GetSystemWindowsDirectoryA (LPSTR lpBuffer, UINT uSize);
  WINBASEAPI UINT WINAPI GetSystemWindowsDirectoryW (LPWSTR lpBuffer, UINT uSize);
  WINBASEAPI WINBOOL WINAPI GetComputerNameExA (COMPUTER_NAME_FORMAT NameType, LPSTR lpBuffer, LPDWORD nSize);
  WINBASEAPI WINBOOL WINAPI GetComputerNameExW (COMPUTER_NAME_FORMAT NameType, LPWSTR lpBuffer, LPDWORD nSize);
  WINBASEAPI WINBOOL WINAPI SetComputerNameExW (COMPUTER_NAME_FORMAT NameType, LPCWSTR lpBuffer);
  WINBASEAPI WINBOOL WINAPI SetSystemTime (CONST SYSTEMTIME *lpSystemTime);
  NTSYSAPI ULONGLONG NTAPI VerSetConditionMask (ULONGLONG ConditionMask, ULONG TypeMask, UCHAR Condition);
#if _WIN32_WINNT >= 0x0601
  WINBASEAPI WINBOOL WINAPI GetOsSafeBootMode (PDWORD Flags);
#endif

#define GetSystemDirectory __MINGW_NAME_AW(GetSystemDirectory)
#define GetWindowsDirectory __MINGW_NAME_AW(GetWindowsDirectory)
#define GetSystemWindowsDirectory __MINGW_NAME_AW(GetSystemWindowsDirectory)
#define GetComputerNameEx __MINGW_NAME_AW(GetComputerNameEx)
#define GetVersionEx __MINGW_NAME_AW(GetVersionEx)

#ifdef UNICODE
#define SetComputerNameEx SetComputerNameExW
#endif
#elif defined(WINSTORECOMPAT)
  WINBASEAPI DWORD WINAPI GetTickCount (VOID);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI UINT WINAPI GetSystemDirectoryA (LPSTR lpBuffer, UINT uSize);
  WINBASEAPI UINT WINAPI GetSystemDirectoryW (LPWSTR lpBuffer, UINT uSize);
  WINBASEAPI WINBOOL WINAPI GetLogicalProcessorInformation (PSYSTEM_LOGICAL_PROCESSOR_INFORMATION Buffer, PDWORD ReturnedLength);
  WINBASEAPI UINT WINAPI EnumSystemFirmwareTables (DWORD FirmwareTableProviderSignature, PVOID pFirmwareTableEnumBuffer, DWORD BufferSize);
  WINBASEAPI UINT WINAPI GetSystemFirmwareTable (DWORD FirmwareTableProviderSignature, DWORD FirmwareTableID, PVOID pFirmwareTableBuffer, DWORD BufferSize);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI GetProductInfo (DWORD dwOSMajorVersion, DWORD dwOSMinorVersion, DWORD dwSpMajorVersion, DWORD dwSpMinorVersion, PDWORD pdwReturnedProductType);
#endif
#if _WIN32_WINNT >= 0x0601
  WINBASEAPI WINBOOL WINAPI GetLogicalProcessorInformationEx (LOGICAL_PROCESSOR_RELATIONSHIP RelationshipType, PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX Buffer, PDWORD ReturnedLength);
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
