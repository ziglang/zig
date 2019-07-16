/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_PRNASNOT
#define _INC_PRNASNOT
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef enum tagPrintAsyncNotifyConversationStyle {
  kBiDirectional,
  kUniDirectional 
} PrintAsyncNotifyConversationStyle;

typedef enum tagPrintAsyncNotifyError {
  CHANNEL_CLOSED_BY_SERVER                  = 0x01,
  CHANNEL_CLOSED_BY_ANOTHER_LISTENER        = 0x02,
  CHANNEL_CLOSED_BY_SAME_LISTENER           = 0x03,
  CHANNEL_RELEASED_BY_LISTENER              = 0x04,
  UNIRECTIONAL_NOTIFICATION_LOST            = 0x05,
  ASYNC_NOTIFICATION_FAILURE                = 0x06,
  NO_LISTENERS                              = 0x07,
  CHANNEL_ALREADY_CLOSED                    = 0x08,
  CHANNEL_ALREADY_OPENED                    = 0x09,
  CHANNEL_WAITING_FOR_CLIENT_NOTIFICATION   = 0x0a,
  CHANNEL_NOT_OPENED                        = 0x0b,
  ASYNC_CALL_ALREADY_PARKED                 = 0x0c,
  NOT_REGISTERED                            = 0x0d,
  ALREADY_UNREGISTERED                      = 0x0e,
  ALREADY_REGISTERED                        = 0x0f,
  CHANNEL_ACQUIRED                          = 0x10,
  ASYNC_CALL_IN_PROGRESS                    = 0x11,
  MAX_NOTIFICATION_SIZE_EXCEEDED            = 0x12,
  INTERNAL_NOTIFICATION_QUEUE_IS_FULL       = 0x13,
  INVALID_NOTIFICATION_TYPE                 = 0x14,
  MAX_REGISTRATION_COUNT_EXCEEDED           = 0x15,
  MAX_CHANNEL_COUNT_EXCEEDED                = 0x16,
  LOCAL_ONLY_REGISTRATION                   = 0x17,
  REMOTE_ONLY_REGISTRATION                  = 0x18 
} PrintAsyncNotifyError;

typedef enum tagPrintAsyncNotifyUserFilter {
  kPerUser,
  kAllUsers 
} PrintAsyncNotifyUserFilter;

HRESULT CreatePrintAsyncNotifyChannel(
  LPCWSTR pName,
  PrintAsyncNotificationType *pSchema,
  PrintAsyncNotifyUserFilter filter,
  PrintAsyncNotifyConversationStyle directionality,
  IPrintAsyncNotifyCallback *pCallback,
  IPrintAsyncNotifyChannel **ppChannel
);

HRESULT RegisterForPrintAsyncNotifications(
  LPCWSTR pName,
  PrintAsyncNotificationType *pSchema,
  PrintAsyncNotifyUserFilter filter,
  PrintAsyncNotifyConversationStyle directionality,
  IPrintAsyncNotifyCallback *pCallback,
  HANDLE *pRegistrationHandler
);

HRESULT UnRegisterForPrintAsyncNotifications(
  HANDLE hRegistrationHandler
);

#ifdef __cplusplus
}
#endif

#endif /* (_WIN32_WINNT >= 0x0600) */
#endif /*_INC_PRNASNOT*/
