/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _MEMORYAPI_H_
#define _MEMORYAPI_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  typedef enum _MEMORY_RESOURCE_NOTIFICATION_TYPE {
    LowMemoryResourceNotification,
    HighMemoryResourceNotification
  } MEMORY_RESOURCE_NOTIFICATION_TYPE;

#if _WIN32_WINNT >= 0x0602
  typedef struct _WIN32_MEMORY_RANGE_ENTRY {
    PVOID VirtualAddress;
    SIZE_T NumberOfBytes;
  } WIN32_MEMORY_RANGE_ENTRY, *PWIN32_MEMORY_RANGE_ENTRY;
#endif

#if _WIN32_WINNT >= 0x0603
  typedef enum _OFFER_PRIORITY {
    VmOfferPriorityVeryLow = 1,
    VmOfferPriorityLow,
    VmOfferPriorityBelowNormal,
    VmOfferPriorityNormal
  } OFFER_PRIORITY;
#endif
#endif

#if (WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP) && _WIN32_WINNT >= 0x0A00) || WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
    WINBASEAPI WINBOOL WINAPI VirtualFree (LPVOID lpAddress, SIZE_T dwSize, DWORD dwFreeType);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#define FILE_MAP_WRITE SECTION_MAP_WRITE
#define FILE_MAP_READ SECTION_MAP_READ
#define FILE_MAP_ALL_ACCESS SECTION_ALL_ACCESS
#define FILE_MAP_COPY 0x1
#define FILE_MAP_RESERVE 0x80000000

  WINBASEAPI SIZE_T WINAPI VirtualQuery (LPCVOID lpAddress, PMEMORY_BASIC_INFORMATION lpBuffer, SIZE_T dwLength);
  WINBASEAPI WINBOOL WINAPI FlushViewOfFile (LPCVOID lpBaseAddress, SIZE_T dwNumberOfBytesToFlush);
  WINBASEAPI WINBOOL WINAPI UnmapViewOfFile (LPCVOID lpBaseAddress);
  WINBASEAPI HANDLE WINAPI CreateFileMappingFromApp (HANDLE hFile, PSECURITY_ATTRIBUTES SecurityAttributes, ULONG PageProtection, ULONG64 MaximumSize, PCWSTR Name);
  WINBASEAPI PVOID WINAPI MapViewOfFileFromApp (HANDLE hFileMappingObject, ULONG DesiredAccess, ULONG64 FileOffset, SIZE_T NumberOfBytesToMap);
#if _WIN32_WINNT >= 0x0A00
  WINBASEAPI PVOID WINAPI VirtualAllocFromApp(PVOID BaseAddress, SIZE_T Size, ULONG AllocationType, ULONG  Protection);
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || defined(WINSTORECOMPAT)
  WINBASEAPI WINBOOL WINAPI VirtualProtect (LPVOID lpAddress, SIZE_T dwSize, DWORD flNewProtect, PDWORD lpflOldProtect);
#endif
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP) && _WIN32_WINNT >= 0x0A00
  WINBASEAPI WINBOOL WINAPI VirtualProtectFromApp (PVOID lpAddress, SIZE_T dwSize, ULONG flNewProtect, PULONG lpflOldProtect);
#endif
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#define FILE_MAP_EXECUTE SECTION_MAP_EXECUTE_EXPLICIT

#define FILE_CACHE_FLAGS_DEFINED
#define FILE_CACHE_MAX_HARD_ENABLE 0x00000001
#define FILE_CACHE_MAX_HARD_DISABLE 0x00000002
#define FILE_CACHE_MIN_HARD_ENABLE 0x00000004
#define FILE_CACHE_MIN_HARD_DISABLE 0x00000008

  WINBASEAPI LPVOID WINAPI VirtualAlloc (LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect);
  WINBASEAPI LPVOID WINAPI VirtualAllocEx (HANDLE hProcess, LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect);
  WINBASEAPI WINBOOL WINAPI VirtualFreeEx (HANDLE hProcess, LPVOID lpAddress, SIZE_T dwSize, DWORD dwFreeType);
  WINBASEAPI WINBOOL WINAPI VirtualProtectEx (HANDLE hProcess, LPVOID lpAddress, SIZE_T dwSize, DWORD flNewProtect, PDWORD lpflOldProtect);
  WINBASEAPI SIZE_T WINAPI VirtualQueryEx (HANDLE hProcess, LPCVOID lpAddress, PMEMORY_BASIC_INFORMATION lpBuffer, SIZE_T dwLength);
  WINBASEAPI WINBOOL WINAPI ReadProcessMemory (HANDLE hProcess, LPCVOID lpBaseAddress, LPVOID lpBuffer, SIZE_T nSize, SIZE_T *lpNumberOfBytesRead);
  WINBASEAPI WINBOOL WINAPI WriteProcessMemory (HANDLE hProcess, LPVOID lpBaseAddress, LPCVOID lpBuffer, SIZE_T nSize, SIZE_T *lpNumberOfBytesWritten);
  WINBASEAPI HANDLE WINAPI CreateFileMappingW (HANDLE hFile, LPSECURITY_ATTRIBUTES lpFileMappingAttributes, DWORD flProtect, DWORD dwMaximumSizeHigh, DWORD dwMaximumSizeLow, LPCWSTR lpName);
  WINBASEAPI HANDLE WINAPI OpenFileMappingW (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCWSTR lpName);
  WINBASEAPI LPVOID WINAPI MapViewOfFile (HANDLE hFileMappingObject, DWORD dwDesiredAccess, DWORD dwFileOffsetHigh, DWORD dwFileOffsetLow, SIZE_T dwNumberOfBytesToMap);
  WINBASEAPI LPVOID WINAPI MapViewOfFileEx (HANDLE hFileMappingObject, DWORD dwDesiredAccess, DWORD dwFileOffsetHigh, DWORD dwFileOffsetLow, SIZE_T dwNumberOfBytesToMap, LPVOID lpBaseAddress);
  WINBASEAPI SIZE_T WINAPI GetLargePageMinimum (VOID);
  WINBASEAPI WINBOOL WINAPI GetProcessWorkingSetSizeEx (HANDLE hProcess, PSIZE_T lpMinimumWorkingSetSize, PSIZE_T lpMaximumWorkingSetSize, PDWORD Flags);
  WINBASEAPI WINBOOL WINAPI SetProcessWorkingSetSizeEx (HANDLE hProcess, SIZE_T dwMinimumWorkingSetSize, SIZE_T dwMaximumWorkingSetSize, DWORD Flags);
  WINBASEAPI WINBOOL WINAPI VirtualLock (LPVOID lpAddress, SIZE_T dwSize);
  WINBASEAPI WINBOOL WINAPI VirtualUnlock (LPVOID lpAddress, SIZE_T dwSize);
  WINBASEAPI UINT WINAPI GetWriteWatch (DWORD dwFlags, PVOID lpBaseAddress, SIZE_T dwRegionSize, PVOID *lpAddresses, ULONG_PTR *lpdwCount, LPDWORD lpdwGranularity);
  WINBASEAPI UINT WINAPI ResetWriteWatch (LPVOID lpBaseAddress, SIZE_T dwRegionSize);
  WINBASEAPI HANDLE WINAPI CreateMemoryResourceNotification (MEMORY_RESOURCE_NOTIFICATION_TYPE NotificationType);
  WINBASEAPI WINBOOL WINAPI QueryMemoryResourceNotification (HANDLE ResourceNotificationHandle, PBOOL ResourceState);
  WINBASEAPI WINBOOL WINAPI GetSystemFileCacheSize (PSIZE_T lpMinimumFileCacheSize, PSIZE_T lpMaximumFileCacheSize, PDWORD lpFlags);
  WINBASEAPI WINBOOL WINAPI SetSystemFileCacheSize (SIZE_T MinimumFileCacheSize, SIZE_T MaximumFileCacheSize, DWORD Flags);

#ifdef UNICODE
#define CreateFileMapping CreateFileMappingW
#define OpenFileMapping OpenFileMappingW
#endif

#if _WIN32_WINNT >= 0x0600
  WINBASEAPI HANDLE WINAPI CreateFileMappingNumaW (HANDLE hFile, LPSECURITY_ATTRIBUTES lpFileMappingAttributes, DWORD flProtect, DWORD dwMaximumSizeHigh, DWORD dwMaximumSizeLow, LPCWSTR lpName, DWORD nndPreferred);

#ifdef UNICODE
#define CreateFileMappingNuma CreateFileMappingNumaW
#endif
#endif
#if _WIN32_WINNT >= 0x0602
  WINBASEAPI WINBOOL WINAPI PrefetchVirtualMemory (HANDLE hProcess, ULONG_PTR NumberOfEntries, PWIN32_MEMORY_RANGE_ENTRY VirtualAddresses, ULONG Flags);
  WINBASEAPI WINBOOL WINAPI UnmapViewOfFileEx (PVOID BaseAddress, ULONG UnmapFlags);
#endif
#if _WIN32_WINNT >= 0x0603
  WINBASEAPI DWORD WINAPI DiscardVirtualMemory (PVOID VirtualAddress, SIZE_T Size);
  WINBASEAPI DWORD WINAPI OfferVirtualMemory (PVOID VirtualAddress, SIZE_T Size, OFFER_PRIORITY Priority);
  WINBASEAPI DWORD WINAPI ReclaimVirtualMemory (PVOID VirtualAddress, SIZE_T Size);
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
