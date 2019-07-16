/*
 * ntpoapi.h
 *
 * APIs for power management.
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Casper S. Hornstrup <chorns@users.sourceforge.net>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef __NTPOAPI_H
#define __NTPOAPI_H

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _PO_DDK_
#define _PO_DDK_

/* Power States/Levels */
typedef enum _SYSTEM_POWER_STATE {
    PowerSystemUnspecified,
    PowerSystemWorking,
    PowerSystemSleeping1,
    PowerSystemSleeping2,
    PowerSystemSleeping3,
    PowerSystemHibernate,
    PowerSystemShutdown,
    PowerSystemMaximum
} SYSTEM_POWER_STATE, *PSYSTEM_POWER_STATE;
#define POWER_SYSTEM_MAXIMUM PowerSystemMaximum

typedef enum _DEVICE_POWER_STATE {
    PowerDeviceUnspecified,
    PowerDeviceD0,
    PowerDeviceD1,
    PowerDeviceD2,
    PowerDeviceD3,
    PowerDeviceMaximum
} DEVICE_POWER_STATE, *PDEVICE_POWER_STATE;

typedef union _POWER_STATE {
  SYSTEM_POWER_STATE  SystemState;
  DEVICE_POWER_STATE  DeviceState;
} POWER_STATE, *PPOWER_STATE;

typedef enum _POWER_STATE_TYPE {
  SystemPowerState = 0,
  DevicePowerState
} POWER_STATE_TYPE, *PPOWER_STATE_TYPE;

typedef enum _POWER_INFORMATION_LEVEL {
    SystemPowerPolicyAc,
    SystemPowerPolicyDc,
    VerifySystemPolicyAc,
    VerifySystemPolicyDc,
    SystemPowerCapabilities,
    SystemBatteryState,
    SystemPowerStateHandler,
    ProcessorStateHandler,
    SystemPowerPolicyCurrent,
    AdministratorPowerPolicy,
    SystemReserveHiberFile,
    ProcessorInformation,
    SystemPowerInformation,
    ProcessorStateHandler2,
    LastWakeTime,
    LastSleepTime,
    SystemExecutionState,
    SystemPowerStateNotifyHandler,
    ProcessorPowerPolicyAc,
    ProcessorPowerPolicyDc,
    VerifyProcessorPowerPolicyAc,
    VerifyProcessorPowerPolicyDc,
    ProcessorPowerPolicyCurrent,
    SystemPowerStateLogging,
    SystemPowerLoggingEntry,
    SetPowerSettingValue,
    NotifyUserPowerSetting,
    PowerInformationLevelUnused0,
    PowerInformationLevelUnused1,
    SystemVideoState,
    TraceApplicationPowerMessage,
    TraceApplicationPowerMessageEnd,
    ProcessorPerfStates,
    ProcessorIdleStates,
    ProcessorCap,
    SystemWakeSource,
    SystemHiberFileInformation,
    TraceServicePowerMessage,
    ProcessorLoad,
    PowerShutdownNotification,
    MonitorCapabilities,
    SessionPowerInit,
    SessionDisplayState,
    PowerRequestCreate,
    PowerRequestAction,
    GetPowerRequestList,
    ProcessorInformationEx,
    NotifyUserModeLegacyPowerEvent,
    GroupPark,
    ProcessorIdleDomains,
    WakeTimerList,
    SystemHiberFileSize,
    PowerInformationLevelMaximum
} POWER_INFORMATION_LEVEL;

typedef enum {
    PowerActionNone,
    PowerActionReserved,
    PowerActionSleep,
    PowerActionHibernate,
    PowerActionShutdown,
    PowerActionShutdownReset,
    PowerActionShutdownOff,
    PowerActionWarmEject
} POWER_ACTION, *PPOWER_ACTION;

#if (NTDDI_VERSION >= NTDDI_WINXP) || !defined(_BATCLASS_)
typedef struct {
    ULONG Granularity;
    ULONG Capacity;
} BATTERY_REPORTING_SCALE, *PBATTERY_REPORTING_SCALE;
#endif /* (NTDDI_VERSION >= NTDDI_WINXP) || !defined(_BATCLASS_) */


#endif /* _PO_DDK_ */


#define POWER_PERF_SCALE                  100
#define PERF_LEVEL_TO_PERCENT(x)          (((x) * 1000) / (POWER_PERF_SCALE * 10))
#define PERCENT_TO_PERF_LEVEL(x)          (((x) * POWER_PERF_SCALE * 10) / 1000)

typedef struct _PROCESSOR_IDLE_TIMES {
	ULONGLONG  StartTime;
	ULONGLONG  EndTime;
	ULONG  IdleHandlerReserved[4];
} PROCESSOR_IDLE_TIMES, *PPROCESSOR_IDLE_TIMES;

typedef BOOLEAN
(FASTCALL*PPROCESSOR_IDLE_HANDLER)(
  IN OUT PPROCESSOR_IDLE_TIMES IdleTimes);

typedef struct _PROCESSOR_IDLE_HANDLER_INFO {
  ULONG  HardwareLatency;
  PPROCESSOR_IDLE_HANDLER  Handler;
} PROCESSOR_IDLE_HANDLER_INFO, *PPROCESSOR_IDLE_HANDLER_INFO;

typedef VOID
(FASTCALL*PSET_PROCESSOR_THROTTLE)(
  IN UCHAR  Throttle);

typedef NTSTATUS
(FASTCALL*PSET_PROCESSOR_THROTTLE2)(
  IN UCHAR  Throttle);

#define MAX_IDLE_HANDLERS                 3

typedef struct _PROCESSOR_STATE_HANDLER {
	UCHAR  ThrottleScale;
	BOOLEAN  ThrottleOnIdle;
	PSET_PROCESSOR_THROTTLE  SetThrottle;
	ULONG  NumIdleHandlers;
	PROCESSOR_IDLE_HANDLER_INFO  IdleHandler[MAX_IDLE_HANDLERS];
} PROCESSOR_STATE_HANDLER, *PPROCESSOR_STATE_HANDLER;

typedef enum _POWER_STATE_HANDLER_TYPE {
	PowerStateSleeping1,
	PowerStateSleeping2,
	PowerStateSleeping3,
	PowerStateSleeping4,
	PowerStateSleeping4Firmware,
	PowerStateShutdownReset,
	PowerStateShutdownOff,
	PowerStateMaximum
} POWER_STATE_HANDLER_TYPE, *PPOWER_STATE_HANDLER_TYPE;

typedef NTSTATUS
(NTAPI*PENTER_STATE_SYSTEM_HANDLER)(
  IN PVOID  SystemContext);

typedef NTSTATUS
(NTAPI*PENTER_STATE_HANDLER)(
  IN PVOID  Context,
  IN PENTER_STATE_SYSTEM_HANDLER  SystemHandler  OPTIONAL,
  IN PVOID  SystemContext,
  IN LONG  NumberProcessors,
  IN LONG volatile *Number);

typedef struct _POWER_STATE_HANDLER {
	POWER_STATE_HANDLER_TYPE  Type;
	BOOLEAN  RtcWake;
	UCHAR  Spare[3];
	PENTER_STATE_HANDLER  Handler;
	PVOID  Context;
} POWER_STATE_HANDLER, *PPOWER_STATE_HANDLER;

typedef NTSTATUS
(NTAPI*PENTER_STATE_NOTIFY_HANDLER)(
  IN POWER_STATE_HANDLER_TYPE  State,
  IN PVOID  Context,
  IN BOOLEAN  Entering);

typedef struct _POWER_STATE_NOTIFY_HANDLER {
	PENTER_STATE_NOTIFY_HANDLER  Handler;
	PVOID  Context;
} POWER_STATE_NOTIFY_HANDLER, *PPOWER_STATE_NOTIFY_HANDLER;

NTSYSCALLAPI
NTSTATUS
NTAPI
NtPowerInformation(
  IN POWER_INFORMATION_LEVEL  InformationLevel,
  IN PVOID  InputBuffer OPTIONAL,
  IN ULONG  InputBufferLength,
  OUT PVOID  OutputBuffer OPTIONAL,
  IN ULONG  OutputBufferLength);

#define PROCESSOR_STATE_TYPE_PERFORMANCE  1
#define PROCESSOR_STATE_TYPE_THROTTLE     2

typedef struct _PROCESSOR_PERF_LEVEL {
  UCHAR  PercentFrequency;
  UCHAR  Reserved;
  USHORT  Flags;
} PROCESSOR_PERF_LEVEL, *PPROCESSOR_PERF_LEVEL;

typedef struct _PROCESSOR_PERF_STATE {
  UCHAR  PercentFrequency;
  UCHAR  MinCapacity;
  USHORT  Power;
  UCHAR  IncreaseLevel;
  UCHAR  DecreaseLevel;
  USHORT  Flags;
  ULONG  IncreaseTime;
  ULONG  DecreaseTime;
  ULONG  IncreaseCount;
  ULONG  DecreaseCount;
  ULONGLONG  PerformanceTime;
} PROCESSOR_PERF_STATE, *PPROCESSOR_PERF_STATE;

typedef struct _PROCESSOR_STATE_HANDLER2 {
	ULONG  NumIdleHandlers;
	PROCESSOR_IDLE_HANDLER_INFO  IdleHandler[MAX_IDLE_HANDLERS];
	PSET_PROCESSOR_THROTTLE2  SetPerfLevel;
	ULONG  HardwareLatency;
	UCHAR  NumPerfStates;
	PROCESSOR_PERF_LEVEL  PerfLevel[1];
} PROCESSOR_STATE_HANDLER2, *PPROCESSOR_STATE_HANDLER2;

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetThreadExecutionState(
  IN EXECUTION_STATE  esFlags,
  OUT EXECUTION_STATE  *PreviousFlags);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtRequestWakeupLatency(
  IN LATENCY_TIME  latency);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtInitiatePowerAction(
  IN POWER_ACTION  SystemAction,
  IN SYSTEM_POWER_STATE  MinSystemState,
  IN ULONG  Flags,
  IN BOOLEAN  Asynchronous);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtSetSystemPowerState(
  IN POWER_ACTION SystemAction,
  IN SYSTEM_POWER_STATE MinSystemState,
  IN ULONG Flags);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtGetDevicePowerState(
  IN HANDLE  Device,
  OUT DEVICE_POWER_STATE  *State);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtCancelDeviceWakeupRequest(
  IN HANDLE  Device);

NTSYSCALLAPI
BOOLEAN
NTAPI
NtIsSystemResumeAutomatic(
  VOID);

NTSYSCALLAPI
NTSTATUS
NTAPI
NtRequestDeviceWakeup(
  IN HANDLE  Device);

#define WINLOGON_LOCK_ON_SLEEP            0x00000001

typedef struct {
    BOOLEAN             PowerButtonPresent;
    BOOLEAN             SleepButtonPresent;
    BOOLEAN             LidPresent;
    BOOLEAN             SystemS1;
    BOOLEAN             SystemS2;
    BOOLEAN             SystemS3;
    BOOLEAN             SystemS4;
    BOOLEAN             SystemS5;
    BOOLEAN             HiberFilePresent;
    BOOLEAN             FullWake;
    BOOLEAN             VideoDimPresent;
    BOOLEAN             ApmPresent;
    BOOLEAN             UpsPresent;
    BOOLEAN             ThermalControl;
    BOOLEAN             ProcessorThrottle;
    UCHAR               ProcessorMinThrottle;
#if (NTDDI_VERSION < NTDDI_WINXP)
    UCHAR               ProcessorThrottleScale;
    UCHAR               spare2[4];
#else
    UCHAR               ProcessorMaxThrottle;
    BOOLEAN             FastSystemS4;
    UCHAR               spare2[3];
#endif /* (NTDDI_VERSION < NTDDI_WINXP) */
    BOOLEAN             DiskSpinDown;
    UCHAR               spare3[8];
    BOOLEAN             SystemBatteriesPresent;
    BOOLEAN             BatteriesAreShortTerm;
    BATTERY_REPORTING_SCALE BatteryScale[3];
    SYSTEM_POWER_STATE  AcOnLineWake;
    SYSTEM_POWER_STATE  SoftLidWake;
    SYSTEM_POWER_STATE  RtcWake;
    SYSTEM_POWER_STATE  MinDeviceWakeState;
    SYSTEM_POWER_STATE  DefaultLowLatencyWake;
} SYSTEM_POWER_CAPABILITIES, *PSYSTEM_POWER_CAPABILITIES;

typedef struct {
    BOOLEAN             AcOnLine;
    BOOLEAN             BatteryPresent;
    BOOLEAN             Charging;
    BOOLEAN             Discharging;
    BOOLEAN             Spare1[4];
    ULONG               MaxCapacity;
    ULONG               RemainingCapacity;
    ULONG               Rate;
    ULONG               EstimatedTime;
    ULONG               DefaultAlert1;
    ULONG               DefaultAlert2;
} SYSTEM_BATTERY_STATE, *PSYSTEM_BATTERY_STATE;

typedef struct _PROCESSOR_POWER_INFORMATION {
  ULONG  Number;
  ULONG  MaxMhz;
  ULONG  CurrentMhz;
  ULONG  MhzLimit;
  ULONG  MaxIdleState;
  ULONG  CurrentIdleState;
} PROCESSOR_POWER_INFORMATION, *PPROCESSOR_POWER_INFORMATION;

typedef struct _POWER_ACTION_POLICY {
    POWER_ACTION Action;
    ULONG Flags;
    ULONG EventCode;
} POWER_ACTION_POLICY, *PPOWER_ACTION_POLICY;

/* POWER_ACTION_POLICY.Flags constants */
#define POWER_ACTION_QUERY_ALLOWED        0x00000001
#define POWER_ACTION_UI_ALLOWED           0x00000002
#define POWER_ACTION_OVERRIDE_APPS        0x00000004
#define POWER_ACTION_LIGHTEST_FIRST       0x10000000
#define POWER_ACTION_LOCK_CONSOLE         0x20000000
#define POWER_ACTION_DISABLE_WAKES        0x40000000
#define POWER_ACTION_CRITICAL             0x80000000

/* POWER_ACTION_POLICY.EventCode constants */
#define POWER_LEVEL_USER_NOTIFY_TEXT      0x00000001
#define POWER_LEVEL_USER_NOTIFY_SOUND     0x00000002
#define POWER_LEVEL_USER_NOTIFY_EXEC      0x00000004
#define POWER_USER_NOTIFY_BUTTON          0x00000008
#define POWER_USER_NOTIFY_SHUTDOWN        0x00000010
#define POWER_FORCE_TRIGGER_RESET         0x80000000

#define DISCHARGE_POLICY_CRITICAL	0
#define DISCHARGE_POLICY_LOW		1
#define NUM_DISCHARGE_POLICIES		4

#define PO_THROTTLE_NONE	0
#define PO_THROTTLE_CONSTANT	1
#define PO_THROTTLE_DEGRADE	2
#define PO_THROTTLE_ADAPTIVE	3
#define PO_THROTTLE_MAXIMUM	4

#ifdef __cplusplus
}
#endif

#endif /* __NTPOAPI_H */

