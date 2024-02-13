/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _POWERBASE_H_
#define _POWERBASE_H_

#include <apiset.h>
#include <apisetcconv.h>

#ifdef _CONTRACT_GEN
#include <nt.h>
#include <ntrtl.h>
#include <nturtl.h>
#include <minwindef.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#ifndef _HPOWERNOTIFY_DEF_
#define _HPOWERNOTIFY_DEF_

typedef PVOID HPOWERNOTIFY, *PHPOWERNOTIFY;

#endif /* _HPOWERNOTIFY_DEF_ */

#ifndef NT_SUCCESS
#define NTSTATUS LONG
#define _OVERRIDE_NTSTATUS_
#endif

NTSTATUS WINAPI CallNtPowerInformation(POWER_INFORMATION_LEVEL InformationLevel, PVOID InputBuffer, ULONG InputBufferLength, PVOID OutputBuffer, ULONG OutputBufferLength);

#ifdef _OVERRIDE_NTSTATUS_
#undef NTSTATUS
#endif

BOOLEAN WINAPI GetPwrCapabilities(PSYSTEM_POWER_CAPABILITIES lpspc);

#if (NTDDI_VERSION >= NTDDI_WIN8)
POWER_PLATFORM_ROLE WINAPI PowerDeterminePlatformRoleEx(ULONG Version);
DWORD WINAPI PowerRegisterSuspendResumeNotification(DWORD Flags, HANDLE Recipient, PHPOWERNOTIFY RegistrationHandle);
DWORD WINAPI PowerUnregisterSuspendResumeNotification(HPOWERNOTIFY RegistrationHandle);
#endif

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#ifdef __cplusplus
}
#endif

#endif /* _POWERBASE_H_ */
