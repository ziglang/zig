/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __AQADMTYP_H__
#define __AQADMTYP_H__

#define MIDL(x)
#define QUEUE_ADMIN_MAX_BUFFER_REQUIRED 200

typedef enum tagQUEUE_ADMIN_VERSIONS {
  CURRENT_QUEUE_ADMIN_VERSION = 4
} QUEUE_ADMIN_VERSIONS;

typedef struct tagMESSAGE_FILTER {
  DWORD dwVersion;
  DWORD fFlags;
  LPCWSTR szMessageId;
  LPCWSTR szMessageSender;
  LPCWSTR szMessageRecipient;
  DWORD dwLargerThanSize;
  SYSTEMTIME stOlderThan;
} MESSAGE_FILTER,*PMESSAGE_FILTER;

typedef enum tagMESSAGE_FILTER_FLAGS {
  MF_MESSAGEID = 0x1,
  MF_SENDER = 0x2,
  MF_RECIPIENT = 0x4,
  MF_SIZE = 0x8,
  MF_TIME = 0x10,
  MF_FROZEN = 0x20,
  MF_FAILED = 0x100,
  MF_ALL = 0x40000000,
  MF_INVERTSENSE = 0x80000000
} MESSAGE_FILTER_FLAGS;

typedef enum tagMESSAGE_ACTION {
  MA_THAW_GLOBAL = 0x1,
  MA_COUNT = 0x2,
  MA_FREEZE_GLOBAL = 0x4,
  MA_DELETE = 0x8,
  MA_DELETE_SILENT = 0x10
} MESSAGE_ACTION;

typedef enum tagMESSAGE_ENUM_FILTER_TYPE {
  MEF_FIRST_N_MESSAGES = 0x1,
  MEF_SENDER = 0x2,
  MEF_RECIPIENT = 0x4,
  MEF_LARGER_THAN = 0x8,
  MEF_OLDER_THAN = 0x10,
  MEF_FROZEN = 0x20,
  MEF_N_LARGEST_MESSAGES = 0x40,
  MEF_N_OLDEST_MESSAGES = 0x80,
  MEF_FAILED = 0x100,
  MEF_ALL = 0x40000000,
  MEF_INVERTSENSE = 0x80000000
} MESSAGE_ENUM_FILTER_TYPE;

typedef struct tagMESSAGE_ENUM_FILTER {
  DWORD dwVersion;
  DWORD mefType;
  DWORD cMessages;
  DWORD cbSize;
  DWORD cSkipMessages;
  SYSTEMTIME stDate;
  LPCWSTR szMessageSender;
  LPCWSTR szMessageRecipient;
} MESSAGE_ENUM_FILTER,*PMESSAGE_ENUM_FILTER;

typedef enum tagLINK_INFO_FLAGS {
  LI_ACTIVE = 0x1,
  LI_READY = 0x2,
  LI_RETRY = 0x4,
  LI_SCHEDULED = 0x8,
  LI_REMOTE = 0x10,
  LI_FROZEN = 0x20,
  LI_TYPE_REMOTE_DELIVERY = 0x100,
  LI_TYPE_LOCAL_DELIVERY = 0x200,
  LI_TYPE_PENDING_ROUTING = 0x400,
  LI_TYPE_PENDING_CAT = 0x800,
  LI_TYPE_CURRENTLY_UNREACHABLE = 0x1000,
  LI_TYPE_DEFERRED_DELIVERY = 0x2000,
  LI_TYPE_INTERNAL = 0x4000,
  LI_TYPE_PENDING_SUBMIT = 0x8000
} LINK_INFO_FLAGS;

typedef enum tagLINK_ACTION {
  LA_INTERNAL = 0x0,
  LA_KICK = 0x1,
  LA_FREEZE = 0x20,
  LA_THAW = 0x40
} LINK_ACTION;

typedef struct tagLINK_INFO {
  DWORD dwVersion;
  LPWSTR szLinkName;
  DWORD cMessages;
  DWORD fStateFlags;
  SYSTEMTIME stNextScheduledConnection;
  SYSTEMTIME stOldestMessage;
  ULARGE_INTEGER cbLinkVolume;
  LPWSTR szLinkDN;
  LPWSTR szExtendedStateInfo;
  DWORD dwSupportedLinkActions;
} LINK_INFO,*PLINK_INFO;

typedef struct tagQUEUE_INFO {
  DWORD dwVersion;
  LPWSTR szQueueName;
  LPWSTR szLinkName;
  DWORD cMessages;
  ULARGE_INTEGER cbQueueVolume;
  DWORD dwMsgEnumFlagsSupported;
} QUEUE_INFO,*PQUEUE_INFO;

typedef enum tagAQ_MESSAGE_FLAGS {
  MP_HIGH = 0x1,
  MP_NORMAL = 0x2,
  MP_LOW = 0x4,
  MP_MSG_FROZEN = 0x8,
  MP_MSG_RETRY = 0x10,
  MP_MSG_CONTENT_AVAILABLE = 0x20
} AQ_MESSAGE_FLAGS;

typedef struct tagMESSAGE_INFO {
  DWORD dwVersion;
  LPWSTR szMessageId;
  LPWSTR szSender;
  LPWSTR szSubject;
  DWORD cRecipients;
  LPWSTR szRecipients;
  DWORD cCCRecipients;
  LPWSTR szCCRecipients;
  DWORD cBCCRecipients;
  LPWSTR szBCCRecipients;
  DWORD fMsgFlags;
  DWORD cbMessageSize;
  SYSTEMTIME stSubmission;
  SYSTEMTIME stReceived;
  SYSTEMTIME stExpiry;
  DWORD cFailures;
  DWORD cEnvRecipients;
  DWORD cbEnvRecipients;
  WCHAR *mszEnvRecipients;
} MESSAGE_INFO,*PMESSAGE_INFO;

typedef enum tagQUEUELINK_TYPE {
  QLT_QUEUE,QLT_LINK,QLT_NONE
} QUEUELINK_TYPE;

typedef struct tagQUEUELINK_ID {
  GUID uuid;
  LPWSTR szName;
  DWORD dwId;
  QUEUELINK_TYPE qltType;
} QUEUELINK_ID;
#endif
