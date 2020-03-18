/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _PROCESSTHREADSAPI_H_
#define _PROCESSTHREADSAPI_H_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef FLS_OUT_OF_INDEXES
#define FLS_OUT_OF_INDEXES ((DWORD)0xffffffff)
#endif

#define TLS_OUT_OF_INDEXES ((DWORD)0xffffffff)

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || defined(WINSTORECOMPAT)
WINBASEAPI WINBOOL WINAPI TerminateProcess (HANDLE hProcess, UINT uExitCode);
#endif
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || _WIN32_WINNT >= _WIN32_WINNT_WIN10
  WINBASEAPI HANDLE WINAPI OpenProcess (DWORD dwDesiredAccess, WINBOOL bInheritHandle, DWORD dwProcessId);

  WINBASEAPI DWORD WINAPI QueueUserAPC (PAPCFUNC pfnAPC, HANDLE hThread, ULONG_PTR dwData);
  WINBASEAPI WINBOOL WINAPI GetProcessTimes (HANDLE hProcess, LPFILETIME lpCreationTime, LPFILETIME lpExitTime, LPFILETIME lpKernelTime, LPFILETIME lpUserTime);
  WINBASEAPI DECLSPEC_NORETURN VOID WINAPI ExitProcess (UINT uExitCode);
  WINBASEAPI WINBOOL WINAPI GetExitCodeProcess (HANDLE hProcess, LPDWORD lpExitCode);
  WINBASEAPI WINBOOL WINAPI SwitchToThread (VOID);
  WINBASEAPI HANDLE WINAPI OpenThread (DWORD dwDesiredAccess, WINBOOL bInheritHandle, DWORD dwThreadId);
  WINBASEAPI WINBOOL WINAPI SetThreadPriorityBoost (HANDLE hThread, WINBOOL bDisablePriorityBoost);
  WINBASEAPI WINBOOL WINAPI GetThreadPriorityBoost (HANDLE hThread, PBOOL pDisablePriorityBoost);
  WINADVAPI WINBOOL APIENTRY SetThreadToken (PHANDLE Thread, HANDLE Token);
  WINADVAPI WINBOOL WINAPI OpenProcessToken (HANDLE ProcessHandle, DWORD DesiredAccess, PHANDLE TokenHandle);
  WINADVAPI WINBOOL WINAPI OpenThreadToken (HANDLE ThreadHandle, DWORD DesiredAccess, WINBOOL OpenAsSelf, PHANDLE TokenHandle);
  WINBASEAPI WINBOOL WINAPI SetPriorityClass (HANDLE hProcess, DWORD dwPriorityClass);
  WINBASEAPI DWORD WINAPI GetPriorityClass (HANDLE hProcess);
  WINBASEAPI DWORD WINAPI GetProcessId (HANDLE Process);
  WINBASEAPI DWORD WINAPI GetThreadId (HANDLE Thread);
  WINBASEAPI WINBOOL WINAPI GetThreadContext (HANDLE hThread, LPCONTEXT lpContext);
  WINBASEAPI WINBOOL WINAPI FlushInstructionCache (HANDLE hProcess, LPCVOID lpBaseAddress, SIZE_T dwSize);
  WINBASEAPI WINBOOL WINAPI GetThreadTimes (HANDLE hThread, LPFILETIME lpCreationTime, LPFILETIME lpExitTime, LPFILETIME lpKernelTime, LPFILETIME lpUserTime);
  WINBASEAPI DWORD WINAPI GetCurrentProcessorNumber (VOID);

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

  typedef struct _PROCESS_INFORMATION {
    HANDLE hProcess;
    HANDLE hThread;
    DWORD dwProcessId;
    DWORD dwThreadId;
  } PROCESS_INFORMATION, *PPROCESS_INFORMATION, *LPPROCESS_INFORMATION;

  typedef struct _PROC_THREAD_ATTRIBUTE_LIST *PPROC_THREAD_ATTRIBUTE_LIST, *LPPROC_THREAD_ATTRIBUTE_LIST;

  typedef struct _STARTUPINFOA {
    DWORD cb;
    LPSTR lpReserved;
    LPSTR lpDesktop;
    LPSTR lpTitle;
    DWORD dwX;
    DWORD dwY;
    DWORD dwXSize;
    DWORD dwYSize;
    DWORD dwXCountChars;
    DWORD dwYCountChars;
    DWORD dwFillAttribute;
    DWORD dwFlags;
    WORD wShowWindow;
    WORD cbReserved2;
    LPBYTE lpReserved2;
    HANDLE hStdInput;
    HANDLE hStdOutput;
    HANDLE hStdError;
  } STARTUPINFOA, *LPSTARTUPINFOA;

  typedef struct _STARTUPINFOW {
    DWORD cb;
    LPWSTR lpReserved;
    LPWSTR lpDesktop;
    LPWSTR lpTitle;
    DWORD dwX;
    DWORD dwY;
    DWORD dwXSize;
    DWORD dwYSize;
    DWORD dwXCountChars;
    DWORD dwYCountChars;
    DWORD dwFillAttribute;
    DWORD dwFlags;
    WORD wShowWindow;
    WORD cbReserved2;
    LPBYTE lpReserved2;
    HANDLE hStdInput;
    HANDLE hStdOutput;
    HANDLE hStdError;
  } STARTUPINFOW, *LPSTARTUPINFOW;

  __MINGW_TYPEDEF_AW(STARTUPINFO)
  __MINGW_TYPEDEF_AW(LPSTARTUPINFO)

  WINBASEAPI HANDLE WINAPI CreateRemoteThread (HANDLE hProcess, LPSECURITY_ATTRIBUTES lpThreadAttributes, SIZE_T dwStackSize, LPTHREAD_START_ROUTINE lpStartAddress, LPVOID lpParameter, DWORD dwCreationFlags, LPDWORD lpThreadId);
  WINBASEAPI WINBOOL WINAPI TerminateThread (HANDLE hThread, DWORD dwExitCode);
  WINBASEAPI WINBOOL WINAPI SetProcessShutdownParameters (DWORD dwLevel, DWORD dwFlags);
  WINBASEAPI DWORD WINAPI GetProcessVersion (DWORD ProcessId);
  WINBASEAPI VOID WINAPI GetStartupInfoW (LPSTARTUPINFOW lpStartupInfo);
  WINBASEAPI WINBOOL WINAPI SetThreadStackGuarantee (PULONG StackSizeInBytes);
  WINBASEAPI WINBOOL WINAPI ProcessIdToSessionId (DWORD dwProcessId, DWORD *pSessionId);
  WINBASEAPI HANDLE WINAPI CreateRemoteThreadEx (HANDLE hProcess, LPSECURITY_ATTRIBUTES lpThreadAttributes, SIZE_T dwStackSize, LPTHREAD_START_ROUTINE lpStartAddress, LPVOID lpParameter, DWORD dwCreationFlags, LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList, LPDWORD lpThreadId);
  WINBASEAPI WINBOOL WINAPI SetThreadContext (HANDLE hThread, CONST CONTEXT *lpContext);
  WINBASEAPI WINBOOL WINAPI GetProcessHandleCount (HANDLE hProcess, PDWORD pdwHandleCount);

#ifdef UNICODE
#define GetStartupInfo GetStartupInfoW
#endif

#ifndef _APISET_EXPORTS_FILTER
  WINBASEAPI WINBOOL WINAPI CreateProcessA (LPCSTR lpApplicationName, LPSTR lpCommandLine, LPSECURITY_ATTRIBUTES lpProcessAttributes, LPSECURITY_ATTRIBUTES lpThreadAttributes, WINBOOL bInheritHandles, DWORD dwCreationFlags, LPVOID lpEnvironment, LPCSTR lpCurrentDirectory, LPSTARTUPINFOA lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation);
  WINBASEAPI WINBOOL WINAPI CreateProcessW (LPCWSTR lpApplicationName, LPWSTR lpCommandLine, LPSECURITY_ATTRIBUTES lpProcessAttributes, LPSECURITY_ATTRIBUTES lpThreadAttributes, WINBOOL bInheritHandles, DWORD dwCreationFlags, LPVOID lpEnvironment, LPCWSTR lpCurrentDirectory, LPSTARTUPINFOW lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation);
#define CreateProcess __MINGW_NAME_AW(CreateProcess)
#endif

#ifndef _APISET_EXPORTS_FILTER
  WINADVAPI WINBOOL WINAPI CreateProcessAsUserW (HANDLE hToken, LPCWSTR lpApplicationName, LPWSTR lpCommandLine, LPSECURITY_ATTRIBUTES lpProcessAttributes, LPSECURITY_ATTRIBUTES lpThreadAttributes, WINBOOL bInheritHandles, DWORD dwCreationFlags, LPVOID lpEnvironment, LPCWSTR lpCurrentDirectory, LPSTARTUPINFOW lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation);

#ifdef UNICODE
#define CreateProcessAsUser CreateProcessAsUserW
#endif
#endif

#if _WIN32_WINNT >= 0x0600
#define PROCESS_AFFINITY_ENABLE_AUTO_UPDATE __MSABI_LONG(0x1U)
#define PROC_THREAD_ATTRIBUTE_REPLACE_VALUE 0x00000001

  WINBASEAPI DWORD WINAPI GetProcessIdOfThread (HANDLE Thread);
  WINBASEAPI WINBOOL WINAPI InitializeProcThreadAttributeList (LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList, DWORD dwAttributeCount, DWORD dwFlags, PSIZE_T lpSize);
  WINBASEAPI VOID WINAPI DeleteProcThreadAttributeList (LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList);
  WINBASEAPI WINBOOL WINAPI SetProcessAffinityUpdateMode (HANDLE hProcess, DWORD dwFlags);
  WINBASEAPI WINBOOL WINAPI QueryProcessAffinityUpdateMode (HANDLE hProcess, LPDWORD lpdwFlags);
  WINBASEAPI WINBOOL WINAPI UpdateProcThreadAttribute (LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList, DWORD dwFlags, DWORD_PTR Attribute, PVOID lpValue, SIZE_T cbSize, PVOID lpPreviousValue, PSIZE_T lpReturnSize);
#endif
#if _WIN32_WINNT >= 0x0601
  WINBASEAPI WINBOOL WINAPI GetThreadIdealProcessorEx (HANDLE hThread, PPROCESSOR_NUMBER lpIdealProcessor);
  WINBASEAPI VOID WINAPI GetCurrentProcessorNumberEx (PPROCESSOR_NUMBER ProcNumber);
#endif
#if _WIN32_WINNT >= 0x0602
  WINBASEAPI VOID WINAPI GetCurrentThreadStackLimits (PULONG_PTR LowLimit, PULONG_PTR HighLimit);
  WINBASEAPI WINBOOL WINAPI SetProcessMitigationPolicy (PROCESS_MITIGATION_POLICY MitigationPolicy, PVOID lpBuffer, SIZE_T dwLength);
  WINBASEAPI WINBOOL WINAPI GetProcessMitigationPolicy (HANDLE hProcess, PROCESS_MITIGATION_POLICY MitigationPolicy, PVOID lpBuffer, SIZE_T dwLength);

  FORCEINLINE HANDLE GetCurrentProcessToken (VOID)
  {
    return (HANDLE)(LONG_PTR) (-4);
  }
  FORCEINLINE HANDLE GetCurrentThreadToken (VOID)
  {
    return (HANDLE)(LONG_PTR) (-5);
  }
  FORCEINLINE HANDLE GetCurrentThreadEffectiveToken (VOID)
  {
    return (HANDLE)(LONG_PTR) (-6);
  }

  typedef struct _MEMORY_PRIORITY_INFORMATION {
    ULONG MemoryPriority;
  } MEMORY_PRIORITY_INFORMATION, *PMEMORY_PRIORITY_INFORMATION;
#endif

#define MEMORY_PRIORITY_VERY_LOW      1
#define MEMORY_PRIORITY_LOW           2
#define MEMORY_PRIORITY_MEDIUM        3
#define MEMORY_PRIORITY_BELOW_NORMAL  4
#define MEMORY_PRIORITY_NORMAL        5

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI HANDLE WINAPI GetCurrentProcess (VOID);
  WINBASEAPI DWORD WINAPI GetCurrentProcessId (VOID);
  WINBASEAPI HANDLE WINAPI GetCurrentThread (VOID);
  WINBASEAPI DWORD WINAPI GetCurrentThreadId (VOID);
  WINBOOL WINAPI IsProcessorFeaturePresent (DWORD ProcessorFeature);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI VOID WINAPI FlushProcessWriteBuffers (VOID);
#endif
  WINBASEAPI HANDLE WINAPI CreateThread (LPSECURITY_ATTRIBUTES lpThreadAttributes, SIZE_T dwStackSize, LPTHREAD_START_ROUTINE lpStartAddress, LPVOID lpParameter, DWORD dwCreationFlags, LPDWORD lpThreadId);
  WINBASEAPI WINBOOL WINAPI SetThreadPriority (HANDLE hThread, int nPriority);
  WINBASEAPI int WINAPI GetThreadPriority (HANDLE hThread);
  WINBASEAPI DECLSPEC_NORETURN VOID WINAPI ExitThread (DWORD dwExitCode);
  WINBASEAPI WINBOOL WINAPI GetExitCodeThread (HANDLE hThread, LPDWORD lpExitCode);
#if _WIN32_WINNT >= 0x0A00
  WINBASEAPI DWORD WINAPI QueueUserAPC (PAPCFUNC pfnAPC, HANDLE hThread, ULONG_PTR dwData);
  WINBASEAPI WINBOOL WINAPI SwitchToThread (VOID);
#endif
  WINBASEAPI DWORD WINAPI SuspendThread (HANDLE hThread);
  WINBASEAPI DWORD WINAPI ResumeThread (HANDLE hThread);
  WINBASEAPI DWORD WINAPI TlsAlloc (VOID);
  WINBASEAPI LPVOID WINAPI TlsGetValue (DWORD dwTlsIndex);
  WINBASEAPI WINBOOL WINAPI TlsSetValue (DWORD dwTlsIndex, LPVOID lpTlsValue);
  WINBASEAPI WINBOOL WINAPI TlsFree (DWORD dwTlsIndex);
#if _WIN32_WINNT >= 0x0601
  WINBASEAPI WINBOOL WINAPI SetThreadIdealProcessorEx (HANDLE hThread, PPROCESSOR_NUMBER lpIdealProcessor, PPROCESSOR_NUMBER lpPreviousIdealProcessor);
#endif

#endif

#ifdef __cplusplus
}
#endif
#endif
