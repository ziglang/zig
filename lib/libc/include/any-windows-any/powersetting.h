/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _POWERSETTING_H_
#define _POWERSETTING_H_

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

#if (NTDDI_VERSION >= NTDDI_VISTA)
DWORD WINAPI PowerReadACValue(HKEY RootPowerKey, CONST GUID *SchemeGuid, CONST GUID *SubGroupOfPowerSettingsGuid, CONST GUID *PowerSettingGuid, PULONG Type, LPBYTE Buffer, LPDWORD BufferSize);
DWORD WINAPI PowerReadDCValue(HKEY RootPowerKey, CONST GUID *SchemeGuid, CONST GUID *SubGroupOfPowerSettingsGuid, CONST GUID *PowerSettingGuid, PULONG Type, PUCHAR Buffer, LPDWORD BufferSize);
DWORD WINAPI PowerWriteACValueIndex(HKEY RootPowerKey, CONST GUID *SchemeGuid, CONST GUID *SubGroupOfPowerSettingsGuid, CONST GUID *PowerSettingGuid, DWORD AcValueIndex);
DWORD WINAPI PowerWriteDCValueIndex(HKEY RootPowerKey, CONST GUID *SchemeGuid, CONST GUID *SubGroupOfPowerSettingsGuid, CONST GUID *PowerSettingGuid, DWORD DcValueIndex);
DWORD WINAPI PowerGetActiveScheme(HKEY UserRootPowerKey, GUID **ActivePolicyGuid);
DWORD WINAPI PowerSetActiveScheme(HKEY UserRootPowerKey, CONST GUID *SchemeGuid);
#endif

#if (NTDDI_VERSION >= NTDDI_WIN7)
DWORD WINAPI PowerSettingRegisterNotification(LPCGUID SettingGuid, DWORD Flags, HANDLE Recipient, PHPOWERNOTIFY RegistrationHandle);
DWORD WINAPI PowerSettingUnregisterNotification(HPOWERNOTIFY RegistrationHandle);
#endif

#if NTDDI_VERSION >= NTDDI_WIN10_RS5

typedef enum EFFECTIVE_POWER_MODE {
    EffectivePowerModeBatterySaver,
    EffectivePowerModeBetterBattery,
    EffectivePowerModeBalanced,
    EffectivePowerModeHighPerformance,
    EffectivePowerModeMaxPerformance,
    EffectivePowerModeGameMode,
    EffectivePowerModeMixedReality
} EFFECTIVE_POWER_MODE;

#define EFFECTIVE_POWER_MODE_V1 (0x00000001)
#define EFFECTIVE_POWER_MODE_V2 (0x00000002)

typedef VOID WINAPI EFFECTIVE_POWER_MODE_CALLBACK(EFFECTIVE_POWER_MODE Mode, VOID *Context);

HRESULT WINAPI PowerRegisterForEffectivePowerModeNotifications(ULONG Version, EFFECTIVE_POWER_MODE_CALLBACK *Callback, VOID *Context, VOID **RegistrationHandle);
HRESULT WINAPI PowerUnregisterFromEffectivePowerModeNotifications(VOID *RegistrationHandle);
#endif

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#ifdef __cplusplus
}
#endif

#endif /* _POWERSETTING_H_ */
