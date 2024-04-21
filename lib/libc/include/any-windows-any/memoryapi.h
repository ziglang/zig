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

#if _WIN32_WINNT >= _WIN32_WINNT_WIN8
  typedef struct _WIN32_MEMORY_RANGE_ENTRY {
    PVOID VirtualAddress;
    SIZE_T NumberOfBytes;
  } WIN32_MEMORY_RANGE_ENTRY, *PWIN32_MEMORY_RANGE_ENTRY;
#endif
#endif

#if (WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP) && _WIN32_WINNT >= _WIN32_WINNT_WIN10) || WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
    WINBASEAPI WINBOOL WINAPI VirtualFree (LPVOID lpAddress, SIZE_T dwSize, DWORD dwFreeType);
#endif
#if (WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP) && NTDDI_VERSION >= NTDDI_WIN10_19H1) || WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
    WINBASEAPI LPVOID WINAPI VirtualAlloc (LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect);
#endif
#if (WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP) && NTDDI_VERSION >= NTDDI_WIN10_VB) || WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
    WINBASEAPI LPVOID WINAPI VirtualAllocEx (HANDLE hProcess, LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)

#define FILE_MAP_WRITE SECTION_MAP_WRITE
#define FILE_MAP_READ SECTION_MAP_READ
#define FILE_MAP_ALL_ACCESS SECTION_ALL_ACCESS
#define FILE_MAP_COPY 0x1
#define FILE_MAP_RESERVE 0x80000000
#define FILE_MAP_TARGETS_INVALID 0x40000000
#define FILE_MAP_LARGE_PAGES 0x20000000

  WINBASEAPI SIZE_T WINAPI VirtualQuery (LPCVOID lpAddress, PMEMORY_BASIC_INFORMATION lpBuffer, SIZE_T dwLength);
  WINBASEAPI WINBOOL WINAPI FlushViewOfFile (LPCVOID lpBaseAddress, SIZE_T dwNumberOfBytesToFlush);
  WINBASEAPI WINBOOL WINAPI UnmapViewOfFile (LPCVOID lpBaseAddress);
  WINBASEAPI WINBOOL WINAPI UnmapViewOfFile2(HANDLE Process, PVOID BaseAddress, ULONG UnmapFlags);
  WINBASEAPI HANDLE WINAPI CreateFileMappingFromApp (HANDLE hFile, PSECURITY_ATTRIBUTES SecurityAttributes, ULONG PageProtection, ULONG64 MaximumSize, PCWSTR Name);
  WINBASEAPI PVOID WINAPI MapViewOfFileFromApp (HANDLE hFileMappingObject, ULONG DesiredAccess, ULONG64 FileOffset, SIZE_T NumberOfBytesToMap);
  WINBASEAPI WINBOOL WINAPI VirtualUnlockEx(HANDLE Process, LPVOID Address, SIZE_T Size);

#if _WIN32_WINNT >= _WIN32_WINNT_WIN10
  WINBASEAPI WINBOOL WINAPI SetProcessValidCallTargets(HANDLE hProcess, PVOID VirtualAddress, SIZE_T RegionSize, ULONG NumberOfOffsets, PCFG_CALL_TARGET_INFO OffsetInformation);
  WINBASEAPI WINBOOL WINAPI SetProcessValidCallTargetsForMappedView(HANDLE Process, PVOID VirtualAddress, SIZE_T RegionSize, ULONG NumberOfOffsets, PCFG_CALL_TARGET_INFO OffsetInformation, HANDLE Section, ULONG64 ExpectedFileOffset);
  WINBASEAPI PVOID WINAPI VirtualAllocFromApp(PVOID BaseAddress, SIZE_T Size, ULONG AllocationType, ULONG  Protection);
  WINBASEAPI WINBOOL WINAPI VirtualProtectFromApp (PVOID lpAddress, SIZE_T dwSize, ULONG flNewProtect, PULONG lpflOldProtect);
  WINBASEAPI HANDLE WINAPI OpenFileMappingFromApp(ULONG DesiredAccess, WINBOOL InheritHandle, PCWSTR Name);
#endif

#if NTDDI_VERSION >= NTDDI_WIN10_RS4
  WINBASEAPI PVOID WINAPI VirtualAlloc2FromApp(HANDLE Process, PVOID BaseAddress, SIZE_T Size, ULONG AllocationType, ULONG PageProtection, MEM_EXTENDED_PARAMETER* ExtendedParameters, ULONG ParameterCount);
  WINBASEAPI PVOID WINAPI MapViewOfFile3FromApp(HANDLE FileMapping, HANDLE Process, PVOID BaseAddress, ULONG64 Offset, SIZE_T ViewSize, ULONG AllocationType, ULONG PageProtection, MEM_EXTENDED_PARAMETER* ExtendedParameters, ULONG ParameterCount);
#endif

#endif /* WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP) */

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || defined(WINSTORECOMPAT)
  WINBASEAPI WINBOOL WINAPI VirtualProtect (LPVOID lpAddress, SIZE_T dwSize, DWORD flNewProtect, PDWORD lpflOldProtect);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#define FILE_MAP_EXECUTE SECTION_MAP_EXECUTE_EXPLICIT

#define FILE_CACHE_FLAGS_DEFINED
#define FILE_CACHE_MAX_HARD_ENABLE 0x00000001
#define FILE_CACHE_MAX_HARD_DISABLE 0x00000002
#define FILE_CACHE_MIN_HARD_ENABLE 0x00000004
#define FILE_CACHE_MIN_HARD_DISABLE 0x00000008

  WINBASEAPI WINBOOL WINAPI VirtualProtectEx (HANDLE hProcess, LPVOID lpAddress, SIZE_T dwSize, DWORD flNewProtect, PDWORD lpflOldProtect);
  WINBASEAPI SIZE_T WINAPI VirtualQueryEx (HANDLE hProcess, LPCVOID lpAddress, PMEMORY_BASIC_INFORMATION lpBuffer, SIZE_T dwLength);
  WINBASEAPI WINBOOL WINAPI ReadProcessMemory (HANDLE hProcess, LPCVOID lpBaseAddress, LPVOID lpBuffer, SIZE_T nSize, SIZE_T *lpNumberOfBytesRead);
  WINBASEAPI WINBOOL WINAPI WriteProcessMemory (HANDLE hProcess, LPVOID lpBaseAddress, LPCVOID lpBuffer, SIZE_T nSize, SIZE_T *lpNumberOfBytesWritten);
  WINBASEAPI HANDLE WINAPI CreateFileMappingW (HANDLE hFile, LPSECURITY_ATTRIBUTES lpFileMappingAttributes, DWORD flProtect, DWORD dwMaximumSizeHigh, DWORD dwMaximumSizeLow, LPCWSTR lpName);
  WINBASEAPI HANDLE WINAPI OpenFileMappingW (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCWSTR lpName);
  WINBASEAPI LPVOID WINAPI MapViewOfFile (HANDLE hFileMappingObject, DWORD dwDesiredAccess, DWORD dwFileOffsetHigh, DWORD dwFileOffsetLow, SIZE_T dwNumberOfBytesToMap);
  WINBASEAPI LPVOID WINAPI MapViewOfFileEx (HANDLE hFileMappingObject, DWORD dwDesiredAccess, DWORD dwFileOffsetHigh, DWORD dwFileOffsetLow, SIZE_T dwNumberOfBytesToMap, LPVOID lpBaseAddress);
  WINBASEAPI WINBOOL WINAPI VirtualLock (LPVOID lpAddress, SIZE_T dwSize);
  WINBASEAPI WINBOOL WINAPI VirtualUnlock (LPVOID lpAddress, SIZE_T dwSize);
  WINBASEAPI HANDLE WINAPI CreateMemoryResourceNotification (MEMORY_RESOURCE_NOTIFICATION_TYPE NotificationType);
  WINBASEAPI WINBOOL WINAPI QueryMemoryResourceNotification (HANDLE ResourceNotificationHandle, PBOOL ResourceState);
  WINBASEAPI WINBOOL WINAPI GetSystemFileCacheSize (PSIZE_T lpMinimumFileCacheSize, PSIZE_T lpMaximumFileCacheSize, PDWORD lpFlags);
  WINBASEAPI WINBOOL WINAPI SetSystemFileCacheSize (SIZE_T MinimumFileCacheSize, SIZE_T MaximumFileCacheSize, DWORD Flags);

#ifdef UNICODE
#define CreateFileMapping CreateFileMappingW
#define OpenFileMapping OpenFileMappingW
#endif

#if _WIN32_WINNT >= _WIN32_WINNT_WINXP
  WINBASEAPI WINBOOL WINAPI AllocateUserPhysicalPages(HANDLE hProcess, PULONG_PTR NumberOfPages, PULONG_PTR PageArray);
  WINBASEAPI WINBOOL WINAPI FreeUserPhysicalPages(HANDLE hProcess, PULONG_PTR NumberOfPages, PULONG_PTR PageArray);
  WINBASEAPI WINBOOL WINAPI MapUserPhysicalPages(PVOID VirtualAddress, ULONG_PTR NumberOfPages, PULONG_PTR PageArray);
#endif

#if _WIN32_WINNT >= _WIN32_WINNT_VISTA
  WINBASEAPI WINBOOL WINAPI AllocateUserPhysicalPagesNuma(HANDLE hProcess, PULONG_PTR NumberOfPages, PULONG_PTR PageArray, DWORD nndPreferred);
  WINBASEAPI HANDLE WINAPI CreateFileMappingNumaW (HANDLE hFile, LPSECURITY_ATTRIBUTES lpFileMappingAttributes, DWORD flProtect, DWORD dwMaximumSizeHigh, DWORD dwMaximumSizeLow, LPCWSTR lpName, DWORD nndPreferred);
  WINBASEAPI LPVOID WINAPI VirtualAllocExNuma(HANDLE hProcess, LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect, DWORD nndPreferred);
#ifdef UNICODE
#define CreateFileMappingNuma CreateFileMappingNumaW
#endif
#endif

#if _WIN32_WINNT >= _WIN32_WINNT_WIN8
#define MEHC_PATROL_SCRUBBER_PRESENT 0x1
  WINBASEAPI WINBOOL WINAPI GetMemoryErrorHandlingCapabilities(PULONG Capabilities);
  WINBASEAPI WINBOOL WINAPI PrefetchVirtualMemory (HANDLE hProcess, ULONG_PTR NumberOfEntries, PWIN32_MEMORY_RANGE_ENTRY VirtualAddresses, ULONG Flags);
  typedef VOID WINAPI BAD_MEMORY_CALLBACK_ROUTINE(VOID);
  typedef BAD_MEMORY_CALLBACK_ROUTINE *PBAD_MEMORY_CALLBACK_ROUTINE;
  WINBASEAPI PVOID WINAPI RegisterBadMemoryNotification(PBAD_MEMORY_CALLBACK_ROUTINE Callback);
  WINBASEAPI WINBOOL WINAPI UnregisterBadMemoryNotification(PVOID RegistrationHandle);
#endif

#if NTDDI_VERSION >= NTDDI_WIN10_RS1
  typedef enum WIN32_MEMORY_INFORMATION_CLASS {
    MemoryRegionInfo
  } WIN32_MEMORY_INFORMATION_CLASS;

  typedef struct WIN32_MEMORY_REGION_INFORMATION {
    PVOID AllocationBase;
    ULONG AllocationProtect;
    __C89_NAMELESS union {
        ULONG Flags;
        __C89_NAMELESS struct {
            ULONG Private : 1;
            ULONG MappedDataFile : 1;
            ULONG MappedImage : 1;
            ULONG MappedPageFile : 1;
            ULONG MappedPhysical : 1;
            ULONG DirectMapped : 1;
            ULONG Reserved : 26;
        };
    };
    SIZE_T RegionSize;
    SIZE_T CommitSize;
  } WIN32_MEMORY_REGION_INFORMATION;

  WINBASEAPI WINBOOL WINAPI QueryVirtualMemoryInformation(HANDLE Process, const VOID* VirtualAddress, WIN32_MEMORY_INFORMATION_CLASS MemoryInformationClass, PVOID MemoryInformation, SIZE_T MemoryInformationSize, PSIZE_T ReturnSize);

#endif /* NTDDI_VERSION >= NTDDI_WIN10_RS1 */

#if NTDDI_VERSION >= NTDDI_WIN10_RS2
  WINBASEAPI PVOID WINAPI MapViewOfFileNuma2(HANDLE FileMappingHandle, HANDLE ProcessHandle, ULONG64 Offset, PVOID BaseAddress, SIZE_T ViewSize, ULONG AllocationType, ULONG PageProtection, ULONG PreferredNode);
  WINBASEAPI PVOID MapViewOfFile2(HANDLE FileMappingHandle, HANDLE ProcessHandle, ULONG64 Offset, PVOID BaseAddress, SIZE_T ViewSize, ULONG AllocationType, ULONG PageProtection);
#endif

#if NTDDI_VERSION >= NTDDI_WIN10_RS4
  WINBASEAPI PVOID WINAPI VirtualAlloc2(HANDLE Process, PVOID BaseAddress, SIZE_T Size, ULONG AllocationType, ULONG PageProtection, MEM_EXTENDED_PARAMETER* ExtendedParameters, ULONG ParameterCount);
  WINBASEAPI PVOID WINAPI MapViewOfFile3(HANDLE FileMapping, HANDLE Process, PVOID BaseAddress, ULONG64 Offset, SIZE_T ViewSize, ULONG AllocationType, ULONG PageProtection, MEM_EXTENDED_PARAMETER* ExtendedParameters, ULONG ParameterCount);
#endif

#if NTDDI_VERSION >= NTDDI_WIN10_RS5
  WINBASEAPI HANDLE WINAPI CreateFileMapping2(HANDLE File, SECURITY_ATTRIBUTES* SecurityAttributes, ULONG DesiredAccess, ULONG PageProtection, ULONG AllocationAttributes, ULONG64 MaximumSize, PCWSTR Name, MEM_EXTENDED_PARAMETER* ExtendedParameters, ULONG ParameterCount);
#endif

#endif /* WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) */
  
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI SIZE_T WINAPI GetLargePageMinimum (VOID);
  WINBASEAPI WINBOOL WINAPI GetProcessWorkingSetSizeEx (HANDLE hProcess, PSIZE_T lpMinimumWorkingSetSize, PSIZE_T lpMaximumWorkingSetSize, PDWORD Flags);
  WINBASEAPI WINBOOL WINAPI SetProcessWorkingSetSizeEx (HANDLE hProcess, SIZE_T dwMinimumWorkingSetSize, SIZE_T dwMaximumWorkingSetSize, DWORD Flags);
  WINBASEAPI UINT WINAPI GetWriteWatch (DWORD dwFlags, PVOID lpBaseAddress, SIZE_T dwRegionSize, PVOID *lpAddresses, ULONG_PTR *lpdwCount, LPDWORD lpdwGranularity);
  WINBASEAPI UINT WINAPI ResetWriteWatch (LPVOID lpBaseAddress, SIZE_T dwRegionSize);
  WINBASEAPI WINBOOL WINAPI VirtualFreeEx (HANDLE hProcess, LPVOID lpAddress, SIZE_T dwSize, DWORD dwFreeType);

#if _WIN32_WINNT >= _WIN32_WINNT_WINBLUE
  typedef enum _OFFER_PRIORITY {
    VmOfferPriorityVeryLow = 1,
    VmOfferPriorityLow,
    VmOfferPriorityBelowNormal,
    VmOfferPriorityNormal
  } OFFER_PRIORITY;

  WINBASEAPI DWORD WINAPI DiscardVirtualMemory (PVOID VirtualAddress, SIZE_T Size);
  WINBASEAPI DWORD WINAPI OfferVirtualMemory (PVOID VirtualAddress, SIZE_T Size, OFFER_PRIORITY Priority);
  WINBASEAPI DWORD WINAPI ReclaimVirtualMemory (PVOID VirtualAddress, SIZE_T Size);
#endif

#if _WIN32_WINNT >= _WIN32_WINNT_WIN8
  WINBASEAPI WINBOOL WINAPI UnmapViewOfFileEx (PVOID BaseAddress, ULONG UnmapFlags);
#endif
#endif /* WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP) */


#ifdef __cplusplus
}
#endif
#endif
