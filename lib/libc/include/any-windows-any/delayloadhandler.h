/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __delayloadhandler_h__
#define __delayloadhandler_h__

#ifdef __cplusplus
extern "C" {
#endif

#if NTDDI_VERSION >= NTDDI_WIN8

#define DELAYLOAD_GPA_FAILURE 4

typedef struct _DELAYLOAD_PROC_DESCRIPTOR {
  ULONG ImportDescribedByName;
  union {
    LPCSTR Name;
    ULONG Ordinal;
  } Description;
} DELAYLOAD_PROC_DESCRIPTOR, *PDELAYLOAD_PROC_DESCRIPTOR;

typedef struct _DELAYLOAD_INFO {
  ULONG Size;
  PCIMAGE_DELAYLOAD_DESCRIPTOR DelayloadDescriptor;
  PIMAGE_THUNK_DATA ThunkAddress;
  LPCSTR TargetDllName;
  DELAYLOAD_PROC_DESCRIPTOR TargetApiDescriptor;
  PVOID TargetModuleBase;
  PVOID Unused;
  ULONG LastError;
} DELAYLOAD_INFO, *PDELAYLOAD_INFO;


typedef PVOID (WINAPI *PDELAYLOAD_FAILURE_DLL_CALLBACK)(ULONG NotificationReason,PDELAYLOAD_INFO DelayloadInfo);

extern PDELAYLOAD_FAILURE_DLL_CALLBACK __pfnDliFailureHook2;

#endif

#ifdef __cplusplus
}
#endif
#endif
