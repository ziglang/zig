/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _HYPERV_COMPUTEDEFS_H_
#define _HYPERV_COMPUTEDEFS_H_

DECLARE_HANDLE(HCS_SYSTEM);
DECLARE_HANDLE(HCS_PROCESS);
DECLARE_HANDLE(HCS_OPERATION);
DECLARE_HANDLE(HCS_CALLBACK);

typedef enum HCS_OPERATION_TYPE {
  HcsOperationTypeNone = -1,
  HcsOperationTypeEnumerate = 0,
  HcsOperationTypeCreate = 1,
  HcsOperationTypeStart = 2,
  HcsOperationTypeShutdown = 3,
  HcsOperationTypePause = 4,
  HcsOperationTypeResume = 5,
  HcsOperationTypeSave = 6,
  HcsOperationTypeTerminate = 7,
  HcsOperationTypeModify = 8,
  HcsOperationTypeGetProperties = 9,
  HcsOperationTypeCreateProcess = 10,
  HcsOperationTypeSignalProcess = 11,
  HcsOperationTypeGetProcessInfo = 12,
  HcsOperationTypeGetProcessProperties = 13,
  HcsOperationTypeModifyProcess = 14,
  HcsOperationTypeCrash = 15,
  HcsOperationTypeLiveMigration = 19,
  HcsOperationTypeReserved1 = 16,
  HcsOperationTypeReserved2 = 17,
  HcsOperationTypeReserved3 = 18
} HCS_OPERATION_TYPE;

#define HCS_INVALID_OPERATION_ID (UINT64)(-1)

typedef void (CALLBACK *HCS_OPERATION_COMPLETION)(HCS_OPERATION operation, void *context);

typedef enum HCS_EVENT_TYPE {
  HcsEventInvalid = 0x00000000,
  HcsEventSystemExited = 0x00000001,
  HcsEventSystemCrashInitiated = 0x00000002,
  HcsEventSystemCrashReport = 0x00000003,
  HcsEventSystemRdpEnhancedModeStateChanged = 0x00000004,
  HcsEventSystemSiloJobCreated = 0x00000005,
  HcsEventSystemGuestConnectionClosed = 0x00000006,
  HcsEventProcessExited = 0x00010000,
  HcsEventOperationCallback = 0x01000000,
  HcsEventServiceDisconnect = 0x02000000,
  HcsEventGroupVmLifecycle = 0x80000002,
  HcsEventGroupLiveMigration = 0x80000003,
  HcsEventGroupOperationInfo = 0xC0000001
} HCS_EVENT_TYPE;

typedef struct HCS_EVENT {
  HCS_EVENT_TYPE Type;
  PCWSTR EventData;
  HCS_OPERATION Operation;
} HCS_EVENT;

typedef enum HCS_EVENT_OPTIONS {
  HcsEventOptionNone = 0x00000000,
  HcsEventOptionEnableOperationCallbacks = 0x00000001,
  HcsEventOptionEnableVmLifecycle = 0x00000002,
  HcsEventOptionEnableLiveMigrationEvents = 0x00000004
} HCS_EVENT_OPTIONS;

DEFINE_ENUM_FLAG_OPERATORS(HCS_EVENT_OPTIONS);

typedef enum HCS_OPERATION_OPTIONS {
  HcsOperationOptionNone = 0x00000000,
  HcsOperationOptionProgressUpdate = 0x00000001,
  HcsOperationOptionReserved1 = 0x00000002
} HCS_OPERATION_OPTIONS;

DEFINE_ENUM_FLAG_OPERATORS(HCS_OPERATION_OPTIONS);

typedef void (CALLBACK *HCS_EVENT_CALLBACK)(HCS_EVENT *event, void *context);

typedef enum HCS_RESOURCE_TYPE {
  HcsResourceTypeNone = 0,
  HcsResourceTypeFile = 1,
  HcsResourceTypeJob = 2,
  HcsResourceTypeComObject = 3,
  HcsResourceTypeSocket = 4
} HCS_RESOURCE_TYPE;

typedef enum HCS_NOTIFICATION_FLAGS {
  HcsNotificationFlagSuccess = 0x00000000,
  HcsNotificationFlagFailure = 0x80000000
} HCS_NOTIFICATION_FLAGS;

typedef enum HCS_NOTIFICATIONS {
  HcsNotificationInvalid = 0x00000000,
  HcsNotificationSystemExited = 0x00000001,
  HcsNotificationSystemCreateCompleted = 0x00000002,
  HcsNotificationSystemStartCompleted = 0x00000003,
  HcsNotificationSystemPauseCompleted = 0x00000004,
  HcsNotificationSystemResumeCompleted = 0x00000005,
  HcsNotificationSystemCrashReport = 0x00000006,
  HcsNotificationSystemSiloJobCreated = 0x00000007,
  HcsNotificationSystemSaveCompleted = 0x00000008,
  HcsNotificationSystemRdpEnhancedModeStateChanged = 0x00000009,
  HcsNotificationSystemShutdownFailed = 0x0000000A,
  HcsNotificationSystemShutdownCompleted = 0x0000000A,
  HcsNotificationSystemGetPropertiesCompleted = 0x0000000B,
  HcsNotificationSystemModifyCompleted = 0x0000000C,
  HcsNotificationSystemCrashInitiated =  0x0000000D,
  HcsNotificationSystemGuestConnectionClosed = 0x0000000E,
  HcsNotificationSystemOperationCompletion = 0x0000000F,
  HcsNotificationSystemPassThru = 0x00000010,
  HcsNotificationOperationProgressUpdate = 0x00000100,
  HcsNotificationProcessExited = 0x00010000,
  HcsNotificationServiceDisconnect = 0x01000000,
  HcsNotificationFlagsReserved = 0xF0000000
} HCS_NOTIFICATIONS;

typedef void (CALLBACK *HCS_NOTIFICATION_CALLBACK)(DWORD notificationType, void *context, HRESULT notificationStatus, PCWSTR notificationData);

typedef struct {
  DWORD ProcessId;
  DWORD Reserved;
  HANDLE StdInput;
  HANDLE StdOutput;
  HANDLE StdError;
} HCS_PROCESS_INFORMATION;

typedef enum HCS_CREATE_OPTIONS {
  HcsCreateOptions_1 = 0x00010000
}HCS_CREATE_OPTIONS;

typedef struct {
  HCS_CREATE_OPTIONS Version;
  HANDLE UserToken;
  SECURITY_DESCRIPTOR* SecurityDescriptor;
  HCS_EVENT_OPTIONS CallbackOptions;
  void* CallbackContext;
  HCS_EVENT_CALLBACK Callback;
} HCS_CREATE_OPTIONS_1;

#endif /* _HYPERV_COMPUTEDEFS_H_ */
