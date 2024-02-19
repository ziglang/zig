/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _POWRPROF_H_
#define _POWRPROF_H_

#include <powerbase.h>
#include <powersetting.h>

#ifdef __cplusplus
extern "C" {
#endif

  typedef struct _GLOBAL_MACHINE_POWER_POLICY{
    ULONG Revision;
    SYSTEM_POWER_STATE LidOpenWakeAc;
    SYSTEM_POWER_STATE LidOpenWakeDc;
    ULONG BroadcastCapacityResolution;
  } GLOBAL_MACHINE_POWER_POLICY,*PGLOBAL_MACHINE_POWER_POLICY;

  typedef struct _GLOBAL_USER_POWER_POLICY{
    ULONG Revision;
    POWER_ACTION_POLICY PowerButtonAc;
    POWER_ACTION_POLICY PowerButtonDc;
    POWER_ACTION_POLICY SleepButtonAc;
    POWER_ACTION_POLICY SleepButtonDc;
    POWER_ACTION_POLICY LidCloseAc;
    POWER_ACTION_POLICY LidCloseDc;
    SYSTEM_POWER_LEVEL DischargePolicy[NUM_DISCHARGE_POLICIES];
    ULONG GlobalFlags;
  } GLOBAL_USER_POWER_POLICY,*PGLOBAL_USER_POWER_POLICY;

  typedef struct _GLOBAL_POWER_POLICY{
    GLOBAL_USER_POWER_POLICY user;
    GLOBAL_MACHINE_POWER_POLICY mach;
  } GLOBAL_POWER_POLICY,*PGLOBAL_POWER_POLICY;

  typedef struct _MACHINE_POWER_POLICY{
    ULONG Revision;
    SYSTEM_POWER_STATE MinSleepAc;
    SYSTEM_POWER_STATE MinSleepDc;
    SYSTEM_POWER_STATE ReducedLatencySleepAc;
    SYSTEM_POWER_STATE ReducedLatencySleepDc;
    ULONG DozeTimeoutAc;
    ULONG DozeTimeoutDc;
    ULONG DozeS4TimeoutAc;
    ULONG DozeS4TimeoutDc;
    UCHAR MinThrottleAc;
    UCHAR MinThrottleDc;
    UCHAR pad1[2];
    POWER_ACTION_POLICY OverThrottledAc;
    POWER_ACTION_POLICY OverThrottledDc;
  } MACHINE_POWER_POLICY,*PMACHINE_POWER_POLICY;

  typedef struct _MACHINE_PROCESSOR_POWER_POLICY {
    ULONG Revision;
    PROCESSOR_POWER_POLICY ProcessorPolicyAc;
    PROCESSOR_POWER_POLICY ProcessorPolicyDc;
  } MACHINE_PROCESSOR_POWER_POLICY,*PMACHINE_PROCESSOR_POWER_POLICY;

  typedef struct _USER_POWER_POLICY{
    ULONG Revision;
    POWER_ACTION_POLICY IdleAc;
    POWER_ACTION_POLICY IdleDc;
    ULONG IdleTimeoutAc;
    ULONG IdleTimeoutDc;
    UCHAR IdleSensitivityAc;
    UCHAR IdleSensitivityDc;
    UCHAR ThrottlePolicyAc;
    UCHAR ThrottlePolicyDc;
    SYSTEM_POWER_STATE MaxSleepAc;
    SYSTEM_POWER_STATE MaxSleepDc;
    ULONG Reserved[2];
    ULONG VideoTimeoutAc;
    ULONG VideoTimeoutDc;
    ULONG SpindownTimeoutAc;
    ULONG SpindownTimeoutDc;
    BOOLEAN OptimizeForPowerAc;
    BOOLEAN OptimizeForPowerDc;
    UCHAR FanThrottleToleranceAc;
    UCHAR FanThrottleToleranceDc;
    UCHAR ForcedThrottleAc;
    UCHAR ForcedThrottleDc;
  } USER_POWER_POLICY,*PUSER_POWER_POLICY;

  typedef struct _POWER_POLICY{
    USER_POWER_POLICY user;
    MACHINE_POWER_POLICY mach;
  } POWER_POLICY,*PPOWER_POLICY;

#define EnableSysTrayBatteryMeter 0x01
#define EnableMultiBatteryDisplay 0x02
#define EnablePasswordLogon 0x04
#define EnableWakeOnRing 0x08
#define EnableVideoDimDisplay 0x10

#define NEWSCHEME (UINT)-1

  typedef BOOLEAN (CALLBACK *PWRSCHEMESENUMPROC)(UINT,DWORD,LPTSTR,DWORD,LPTSTR,PPOWER_POLICY,LPARAM);
  typedef BOOLEAN (CALLBACK *PFNNTINITIATEPWRACTION)(POWER_ACTION,SYSTEM_POWER_STATE,ULONG,BOOLEAN);

  BOOLEAN WINAPI GetPwrDiskSpindownRange(PUINT,PUINT);
  BOOLEAN WINAPI EnumPwrSchemes(PWRSCHEMESENUMPROC,LPARAM);
  BOOLEAN WINAPI ReadGlobalPwrPolicy(PGLOBAL_POWER_POLICY);
  BOOLEAN WINAPI ReadPwrScheme(UINT,PPOWER_POLICY);
  BOOLEAN WINAPI WritePwrScheme(PUINT,LPTSTR,LPTSTR,PPOWER_POLICY);
  BOOLEAN WINAPI WriteGlobalPwrPolicy(PGLOBAL_POWER_POLICY);
  BOOLEAN WINAPI DeletePwrScheme(UINT);
  BOOLEAN WINAPI GetActivePwrScheme(PUINT);
  BOOLEAN WINAPI SetActivePwrScheme(UINT,PGLOBAL_POWER_POLICY,PPOWER_POLICY);
  BOOLEAN WINAPI IsPwrSuspendAllowed(VOID);
  BOOLEAN WINAPI IsPwrHibernateAllowed(VOID);
  BOOLEAN WINAPI IsPwrShutdownAllowed(VOID);
  BOOLEAN WINAPI IsAdminOverrideActive(PADMINISTRATOR_POWER_POLICY);
  BOOLEAN WINAPI SetSuspendState(BOOLEAN,BOOLEAN,BOOLEAN);
  BOOLEAN WINAPI GetCurrentPowerPolicies(PGLOBAL_POWER_POLICY,PPOWER_POLICY);
  BOOLEAN WINAPI CanUserWritePwrScheme(VOID);
  BOOLEAN WINAPI ReadProcessorPwrScheme(UINT,PMACHINE_PROCESSOR_POWER_POLICY);
  BOOLEAN WINAPI WriteProcessorPwrScheme(UINT,PMACHINE_PROCESSOR_POWER_POLICY);
  BOOLEAN WINAPI ValidatePowerPolicies(PGLOBAL_POWER_POLICY,PPOWER_POLICY);

#if (_WIN32_WINNT >= 0x0600)
#define DEVICEPOWER_HARDWAREID 0x80000000
#define DEVICEPOWER_FILTER_DEVICES_PRESENT 0x20000000
#define DEVICEPOWER_AND_OPERATION 0x40000000
#define DEVICEPOWER_FILTER_WAKEENABLED 0x08000000
#define DEVICEPOWER_FILTER_ON_NAME 0x02000000

#define PDCAP_D0_SUPPORTED 0x00000001
#define PDCAP_D1_SUPPORTED 0x00000002
#define PDCAP_D2_SUPPORTED 0x00000004
#define PDCAP_D3_SUPPORTED 0x00000008
#define PDCAP_S0_SUPPORTED 0x00010000
#define PDCAP_S1_SUPPORTED 0x00020000
#define PDCAP_S2_SUPPORTED 0x00040000
#define PDCAP_S3_SUPPORTED 0x00080000
#define PDCAP_S4_SUPPORTED 0x01000000
#define PDCAP_S5_SUPPORTED 0x02000000
#define PDCAP_WAKE_FROM_D0_SUPPORTED 0x00000010
#define PDCAP_WAKE_FROM_D1_SUPPORTED 0x00000020
#define PDCAP_WAKE_FROM_D2_SUPPORTED 0x00000040
#define PDCAP_WAKE_FROM_D3_SUPPORTED 0x00000080
#define PDCAP_WAKE_FROM_S0_SUPPORTED 0x00100000
#define PDCAP_WAKE_FROM_S1_SUPPORTED 0x00200000
#define PDCAP_WAKE_FROM_S2_SUPPORTED 0x00400000
#define PDCAP_WAKE_FROM_S3_SUPPORTED 0x00800000
#define PDCAP_WARM_EJECT_SUPPORTED 0x00000100

#define DEVICEPOWER_SET_WAKEENABLED 0x00000001
#define DEVICEPOWER_CLEAR_WAKEENABLED 0x00000002

typedef enum _POWER_DATA_ACCESSOR {
  ACCESS_AC_POWER_SETTING_INDEX   = 0,   // 0x0
  ACCESS_DC_POWER_SETTING_INDEX   = 1,   // 0x1
  ACCESS_SCHEME                   = 16,  // 0x10
  ACCESS_SUBGROUP                 = 17,  // 0x11
  ACCESS_INDIVIDUAL_SETTING       = 18,  // 0x12
  ACCESS_ACTIVE_SCHEME            = 19,  // 0x13
  ACCESS_CREATE_SCHEME            = 20   // 0x14
} POWER_DATA_ACCESSOR, *PPOWER_DATA_ACCESSOR;

BOOLEAN WINAPI DevicePowerClose(void);
BOOLEAN WINAPI DevicePowerEnumDevices(
  ULONG QueryIndex,
  ULONG QueryInterpretationFlags,
  ULONG QueryFlags,
  PBYTE pReturnBuffer,
  PULONG pBufferSize
);

BOOLEAN WINAPI DevicePowerOpen(
  ULONG Flags
);

DWORD WINAPI DevicePowerSetDeviceState(
  LPCWSTR DeviceDescription,
  ULONG SetFlags,
  LPCVOID SetData
);

DWORD WINAPI PowerCanRestoreIndividualDefaultPowerScheme(
  const GUID *SchemeGuid
);

DWORD WINAPI PowerCreatePossibleSetting(
  HKEY RootSystemPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  ULONG PossibleSettingIndex
);

DWORD WINAPI PowerCreateSetting(
  HKEY RootSystemPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid
);

DWORD WINAPI PowerDeleteScheme(
  HKEY RootPowerKey,
  const GUID *SchemeGuid
);

POWER_PLATFORM_ROLE WINAPI PowerDeterminePlatformRole(void);

DWORD WINAPI PowerDuplicateScheme(
  HKEY RootPowerKey,
  const GUID *SourceSchemeGuid,
  GUID **DestinationSchemeGuid
);

DWORD WINAPI PowerEnumerate(
  HKEY RootPowerKey,
  const GUID *SchemeGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  POWER_DATA_ACCESSOR AccessFlags,
  ULONG Index,
  UCHAR *Buffer,
  DWORD *BufferSize
);

DWORD WINAPI PowerImportPowerScheme(
  HKEY RootPowerKey,
  LPCWSTR ImportFileNamePath,
  GUID **DestinationSchemeGuid
);

DWORD WINAPI PowerReadACDefaultIndex(
  HKEY RootPowerKey,
  const GUID *SchemePersonalityGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  LPDWORD AcDefaultIndex
);

DWORD WINAPI PowerReadACValueIndex(
  HKEY RootPowerKey,
  const GUID *SchemeGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  LPDWORD AcValueIndex
);

DWORD WINAPI PowerReadDCDefaultIndex(
  HKEY RootPowerKey,
  const GUID *SchemePersonalityGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  LPDWORD DcDefaultIndex
);

DWORD WINAPI PowerReadDCValueIndex(
  HKEY RootPowerKey,
  const GUID *SchemeGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  LPDWORD DcValueIndex
);

DWORD WINAPI PowerReadDescription(
  HKEY RootPowerKey,
  const GUID *SchemeGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  PUCHAR Buffer,
  LPDWORD BufferSize
);

DWORD WINAPI PowerReadFriendlyName(
  HKEY RootPowerKey,
  const GUID *SchemeGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  PUCHAR Buffer,
  LPDWORD BufferSize
);

DWORD WINAPI PowerReadIconResourceSpecifier(
  HKEY RootPowerKey,
  const GUID *SchemeGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  PUCHAR Buffer,
  LPDWORD BufferSize
);

DWORD WINAPI PowerReadPossibleDescription(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  ULONG PossibleSettingIndex,
  PUCHAR Buffer,
  LPDWORD BufferSize
);

DWORD WINAPI PowerReadPossibleFriendlyName(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  ULONG PossibleSettingIndex,
  PUCHAR Buffer,
  LPDWORD BufferSize
);

DWORD WINAPI PowerReadPossibleValue(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  PULONG Type,
  ULONG PossibleSettingIndex,
  PUCHAR Buffer,
  LPDWORD BufferSize
);

DWORD WINAPI PowerReadSettingAttributes(
  const GUID *SubGroupGuid,
  const GUID *PowerSettingGuid
);

DWORD WINAPI PowerReadValueIncrement(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  LPDWORD ValueIncrement
);

DWORD WINAPI PowerReadValueMax(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  LPDWORD ValueMaximum
);

DWORD WINAPI PowerReadValueMin(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  LPDWORD ValueMinimum
);

DWORD WINAPI PowerReadValueUnitsSpecifier(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  UCHAR *Buffer,
  LPDWORD BufferSize
);

DWORD WINAPI PowerRemovePowerSetting(
  const GUID *PowerSettingSubKeyGuid,
  const GUID *PowerSettingGuid
);

DWORD WINAPI PowerReplaceDefaultPowerSchemes(void);

DWORD WINAPI PowerRestoreDefaultPowerSchemes(void);

DWORD WINAPI PowerRestoreIndividualDefaultPowerScheme(
  const GUID *SchemeGuid
);

DWORD WINAPI PowerSettingAccessCheck(
  POWER_DATA_ACCESSOR AccessFlags,
  const GUID *PowerGuid
);

DWORD WINAPI PowerWriteACDefaultIndex(
  HKEY RootSystemPowerKey,
  const GUID *SchemePersonalityGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  DWORD DefaultAcIndex
);

DWORD WINAPI PowerWriteDCDefaultIndex(
  HKEY RootSystemPowerKey,
  const GUID *SchemePersonalityGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  DWORD DefaultDcIndex
);

DWORD WINAPI PowerWriteDescription(
  HKEY RootPowerKey,
  const GUID *SchemeGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  UCHAR *Buffer,
  DWORD BufferSize
);

DWORD WINAPI PowerWriteFriendlyName(
  HKEY RootPowerKey,
  const GUID *SchemeGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  UCHAR *Buffer,
  DWORD BufferSize
);

DWORD WINAPI PowerWriteIconResourceSpecifier(
  HKEY RootPowerKey,
  const GUID *SchemeGuid,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  UCHAR *Buffer,
  DWORD BufferSize
);

DWORD WINAPI PowerWritePossibleDescription(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  ULONG PossibleSettingIndex,
  UCHAR *Buffer,
  DWORD BufferSize
);

DWORD WINAPI PowerWritePossibleFriendlyName(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  ULONG PossibleSettingIndex,
  UCHAR *Buffer,
  DWORD BufferSize
);

DWORD WINAPI PowerWritePossibleValue(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  ULONG Type,
  ULONG PossibleSettingIndex,
  UCHAR *Buffer,
  DWORD BufferSize
);

#define POWER_ATTRIBUTE_HIDE 1

DWORD WINAPI PowerWriteSettingAttributes(
  const GUID *SubGroupGuid,
  const GUID *PowerSettingGuid,
  DWORD Attributes
);

DWORD WINAPI PowerWriteValueIncrement(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  DWORD ValueIncrement
);

DWORD WINAPI PowerWriteValueMax(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  DWORD ValueMaximum
);

DWORD WINAPI PowerWriteValueMin(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  DWORD ValueMinimum
);

DWORD WINAPI PowerWriteValueUnitsSpecifier(
  HKEY RootPowerKey,
  const GUID *SubGroupOfPowerSettingsGuid,
  const GUID *PowerSettingGuid,
  UCHAR *Buffer,
  DWORD BufferSize
);

#endif /*(_WIN32_WINNT >= 0x0600)*/

#ifdef __cplusplus
}
#endif

#endif /* _POWRPROF_H_ */
