/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _PSAPI_H_
#define _PSAPI_H_

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef PSAPI_VERSION
#if NTDDI_VERSION >= NTDDI_WIN7
#define PSAPI_VERSION 2
#else
#define PSAPI_VERSION 1
#endif
#endif

#if PSAPI_VERSION > 1
#define EnumProcesses               K32EnumProcesses
#define EnumProcessModules          K32EnumProcessModules
#define EnumProcessModulesEx        K32EnumProcessModulesEx
#define GetModuleBaseNameA          K32GetModuleBaseNameA
#define GetModuleBaseNameW          K32GetModuleBaseNameW
#define GetModuleFileNameExA        K32GetModuleFileNameExA
#define GetModuleFileNameExW        K32GetModuleFileNameExW
#define GetModuleInformation        K32GetModuleInformation
#define EmptyWorkingSet             K32EmptyWorkingSet
#define QueryWorkingSet             K32QueryWorkingSet
#define QueryWorkingSetEx           K32QueryWorkingSetEx
#define InitializeProcessForWsWatch K32InitializeProcessForWsWatch
#define GetWsChanges                K32GetWsChanges
#define GetWsChangesEx              K32GetWsChangesEx
#define GetMappedFileNameW          K32GetMappedFileNameW
#define GetMappedFileNameA          K32GetMappedFileNameA
#define EnumDeviceDrivers           K32EnumDeviceDrivers
#define GetDeviceDriverBaseNameA    K32GetDeviceDriverBaseNameA
#define GetDeviceDriverBaseNameW    K32GetDeviceDriverBaseNameW
#define GetDeviceDriverFileNameA    K32GetDeviceDriverFileNameA
#define GetDeviceDriverFileNameW    K32GetDeviceDriverFileNameW
#define GetProcessMemoryInfo        K32GetProcessMemoryInfo
#define GetPerformanceInfo          K32GetPerformanceInfo
#define EnumPageFilesW              K32EnumPageFilesW
#define EnumPageFilesA              K32EnumPageFilesA
#define GetProcessImageFileNameA    K32GetProcessImageFileNameA
#define GetProcessImageFileNameW    K32GetProcessImageFileNameW
#endif

#define GetModuleBaseName __MINGW_NAME_AW(GetModuleBaseName)
#define GetModuleFileNameEx __MINGW_NAME_AW(GetModuleFileNameEx)
#define GetMappedFileName __MINGW_NAME_AW(GetMappedFileName)
#define GetDeviceDriverBaseName __MINGW_NAME_AW(GetDeviceDriverBaseName)
#define GetDeviceDriverFileName __MINGW_NAME_AW(GetDeviceDriverFileName)
#define PENUM_PAGE_FILE_CALLBACK __MINGW_NAME_AW(PENUM_PAGE_FILE_CALLBACK)
#define EnumPageFiles __MINGW_NAME_AW(EnumPageFiles)
#define GetProcessImageFileName __MINGW_NAME_AW(GetProcessImageFileName)

#ifndef LIST_MODULES_DEFAULT
#define LIST_MODULES_DEFAULT 0x0
#endif
#ifndef LIST_MODULES_32BIT
#define LIST_MODULES_32BIT 0x01
#endif
#ifndef LIST_MODULES_64BIT
#define LIST_MODULES_64BIT 0x02
#endif
#ifndef LIST_MODULES_ALL
#define LIST_MODULES_ALL (LIST_MODULES_32BIT|LIST_MODULES_64BIT)
#endif

  WINBOOL WINAPI EnumProcesses(DWORD *lpidProcess,DWORD cb,DWORD *cbNeeded);
  WINBOOL WINAPI EnumProcessModules(HANDLE hProcess,HMODULE *lphModule,DWORD cb,LPDWORD lpcbNeeded);
  DWORD WINAPI GetModuleBaseNameA(HANDLE hProcess,HMODULE hModule,LPSTR lpBaseName,DWORD nSize);
  DWORD WINAPI GetModuleBaseNameW(HANDLE hProcess,HMODULE hModule,LPWSTR lpBaseName,DWORD nSize);
  DWORD WINAPI GetModuleFileNameExA(HANDLE hProcess,HMODULE hModule,LPSTR lpFilename,DWORD nSize);
  DWORD WINAPI GetModuleFileNameExW(HANDLE hProcess,HMODULE hModule,LPWSTR lpFilename,DWORD nSize);

  typedef struct _MODULEINFO {
    LPVOID lpBaseOfDll;
    DWORD SizeOfImage;
    LPVOID EntryPoint;
  } MODULEINFO,*LPMODULEINFO;

  WINBOOL WINAPI GetModuleInformation(HANDLE hProcess,HMODULE hModule,LPMODULEINFO lpmodinfo,DWORD cb);
  WINBOOL WINAPI EmptyWorkingSet(HANDLE hProcess);
  WINBOOL WINAPI QueryWorkingSet(HANDLE hProcess,PVOID pv,DWORD cb);
  WINBOOL WINAPI QueryWorkingSetEx(HANDLE hProcess,PVOID pv,DWORD cb);
  WINBOOL WINAPI InitializeProcessForWsWatch(HANDLE hProcess);

  typedef struct _PSAPI_WS_WATCH_INFORMATION {
    LPVOID FaultingPc;
    LPVOID FaultingVa;
  } PSAPI_WS_WATCH_INFORMATION,*PPSAPI_WS_WATCH_INFORMATION;

  WINBOOL WINAPI GetWsChanges(HANDLE hProcess,PPSAPI_WS_WATCH_INFORMATION lpWatchInfo,DWORD cb);
  DWORD WINAPI GetMappedFileNameW(HANDLE hProcess,LPVOID lpv,LPWSTR lpFilename,DWORD nSize);
  DWORD WINAPI GetMappedFileNameA(HANDLE hProcess,LPVOID lpv,LPSTR lpFilename,DWORD nSize);
  WINBOOL WINAPI EnumDeviceDrivers(LPVOID *lpImageBase,DWORD cb,LPDWORD lpcbNeeded);
  DWORD WINAPI GetDeviceDriverBaseNameA(LPVOID ImageBase,LPSTR lpBaseName,DWORD nSize);
  DWORD WINAPI GetDeviceDriverBaseNameW(LPVOID ImageBase,LPWSTR lpBaseName,DWORD nSize);
  DWORD WINAPI GetDeviceDriverFileNameA(LPVOID ImageBase,LPSTR lpFilename,DWORD nSize);
  DWORD WINAPI GetDeviceDriverFileNameW(LPVOID ImageBase,LPWSTR lpFilename,DWORD nSize);

  typedef struct _PROCESS_MEMORY_COUNTERS {
    DWORD cb;
    DWORD PageFaultCount;
    SIZE_T PeakWorkingSetSize;
    SIZE_T WorkingSetSize;
    SIZE_T QuotaPeakPagedPoolUsage;
    SIZE_T QuotaPagedPoolUsage;
    SIZE_T QuotaPeakNonPagedPoolUsage;
    SIZE_T QuotaNonPagedPoolUsage;
    SIZE_T PagefileUsage;
    SIZE_T PeakPagefileUsage;
  } PROCESS_MEMORY_COUNTERS;
  typedef PROCESS_MEMORY_COUNTERS *PPROCESS_MEMORY_COUNTERS;

  typedef struct _PROCESS_MEMORY_COUNTERS_EX {
    DWORD cb;
    DWORD PageFaultCount;
    SIZE_T PeakWorkingSetSize;
    SIZE_T WorkingSetSize;
    SIZE_T QuotaPeakPagedPoolUsage;
    SIZE_T QuotaPagedPoolUsage;
    SIZE_T QuotaPeakNonPagedPoolUsage;
    SIZE_T QuotaNonPagedPoolUsage;
    SIZE_T PagefileUsage;
    SIZE_T PeakPagefileUsage;
    SIZE_T PrivateUsage;
  } PROCESS_MEMORY_COUNTERS_EX;
  typedef PROCESS_MEMORY_COUNTERS_EX *PPROCESS_MEMORY_COUNTERS_EX;

  WINBOOL WINAPI GetProcessMemoryInfo(HANDLE Process,PPROCESS_MEMORY_COUNTERS ppsmemCounters,DWORD cb);

  typedef struct _PERFORMANCE_INFORMATION {
    DWORD cb;
    SIZE_T CommitTotal;
    SIZE_T CommitLimit;
    SIZE_T CommitPeak;
    SIZE_T PhysicalTotal;
    SIZE_T PhysicalAvailable;
    SIZE_T SystemCache;
    SIZE_T KernelTotal;
    SIZE_T KernelPaged;
    SIZE_T KernelNonpaged;
    SIZE_T PageSize;
    DWORD HandleCount;
    DWORD ProcessCount;
    DWORD ThreadCount;
  } PERFORMANCE_INFORMATION,*PPERFORMANCE_INFORMATION,PERFORMACE_INFORMATION,*PPERFORMACE_INFORMATION;

  WINBOOL WINAPI GetPerformanceInfo (PPERFORMACE_INFORMATION pPerformanceInformation,DWORD cb);

  typedef struct _ENUM_PAGE_FILE_INFORMATION {
    DWORD cb;
    DWORD Reserved;
    SIZE_T TotalSize;
    SIZE_T TotalInUse;
    SIZE_T PeakUsage;
  } ENUM_PAGE_FILE_INFORMATION,*PENUM_PAGE_FILE_INFORMATION;

  typedef WINBOOL (CALLBACK *PENUM_PAGE_FILE_CALLBACKW) (LPVOID pContext,PENUM_PAGE_FILE_INFORMATION pPageFileInfo,LPCWSTR lpFilename);
  typedef WINBOOL (CALLBACK *PENUM_PAGE_FILE_CALLBACKA) (LPVOID pContext,PENUM_PAGE_FILE_INFORMATION pPageFileInfo,LPCSTR lpFilename);

  WINBOOL WINAPI EnumPageFilesW (PENUM_PAGE_FILE_CALLBACKW pCallBackRoutine,LPVOID pContext);
  WINBOOL WINAPI EnumPageFilesA (PENUM_PAGE_FILE_CALLBACKA pCallBackRoutine,LPVOID pContext);
  DWORD WINAPI GetProcessImageFileNameA(HANDLE hProcess,LPSTR lpImageFileName,DWORD nSize);
  DWORD WINAPI GetProcessImageFileNameW(HANDLE hProcess,LPWSTR lpImageFileName,DWORD nSize);
  
typedef struct _PSAPI_WS_WATCH_INFORMATION_EX {
  PSAPI_WS_WATCH_INFORMATION BasicInfo;
  ULONG_PTR                  FaultingThreadId;
  ULONG_PTR                  Flags;
} PSAPI_WS_WATCH_INFORMATION_EX, *PPSAPI_WS_WATCH_INFORMATION_EX;

WINBOOL WINAPI GetWsChangesEx(
  HANDLE hProcess,
  PPSAPI_WS_WATCH_INFORMATION_EX lpWatchInfoEx,
  DWORD cb
);

WINBOOL WINAPI EnumProcessModulesEx(
  HANDLE hProcess,
  HMODULE *lphModule,
  DWORD cb,
  LPDWORD lpcbNeeded,
  DWORD dwFilterFlag
);

typedef union _PSAPI_WORKING_SET_BLOCK {
  ULONG_PTR Flags;
  __C89_NAMELESS struct {
    ULONG_PTR Protection  :5;
    ULONG_PTR ShareCount  :3;
    ULONG_PTR Shared  :1;
    ULONG_PTR Reserved  :3;
#ifdef _WIN64
    ULONG_PTR VirtualPage  :52;
#else
    ULONG_PTR VirtualPage  :20;
#endif
  } ;
} PSAPI_WORKING_SET_BLOCK, *PPSAPI_WORKING_SET_BLOCK;

typedef struct _PSAPI_WORKING_SET_INFORMATION {
  ULONG_PTR               NumberOfEntries;
  PSAPI_WORKING_SET_BLOCK WorkingSetInfo[1];
} PSAPI_WORKING_SET_INFORMATION, *PPSAPI_WORKING_SET_INFORMATION;

typedef union _PSAPI_WORKING_SET_EX_BLOCK {
  ULONG_PTR Flags;
  __C89_NAMELESS union {
    __C89_NAMELESS struct {
      ULONG_PTR Valid : 1;
      ULONG_PTR ShareCount : 3;
      ULONG_PTR Win32Protection : 11;
      ULONG_PTR Shared : 1;
      ULONG_PTR Node : 6;
      ULONG_PTR Locked : 1;
      ULONG_PTR LargePage : 1;
      ULONG_PTR Reserved : 7;
      ULONG_PTR Bad : 1;
#ifdef _WIN64
      ULONG_PTR ReservedUlong : 32;
#endif
    };
    struct {
      ULONG_PTR Valid : 1;
      ULONG_PTR Reserved0 : 14;
      ULONG_PTR Shared : 1;
      ULONG_PTR Reserved1 : 15;
      ULONG_PTR Bad : 1;
#ifdef _WIN64
      ULONG_PTR ReservedUlong : 32;
#endif
    } Invalid;
  };
} PSAPI_WORKING_SET_EX_BLOCK, *PPSAPI_WORKING_SET_EX_BLOCK;

typedef struct _PSAPI_WORKING_SET_EX_INFORMATION {
  PVOID                      VirtualAddress;
  PSAPI_WORKING_SET_EX_BLOCK VirtualAttributes;
} PSAPI_WORKING_SET_EX_INFORMATION, *PPSAPI_WORKING_SET_EX_INFORMATION;

#ifdef __cplusplus
}
#endif
#endif
