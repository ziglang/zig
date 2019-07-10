/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WINEVT
#define _INC_WINEVT
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef enum _EVT_CHANNEL_CLOCK_TYPE {
  EvtChannelClockTypeSystemTime   = 0,
  EvtChannelClockTypeQPC          = 1 
} EVT_CHANNEL_CLOCK_TYPE;

typedef enum _EVT_CHANNEL_CONFIG_PROPERTY_ID {
  EvtChannelConfigEnabled                 = 0,
  EvtChannelConfigIsolation               = 1,
  EvtChannelConfigType                    = 2,
  EvtChannelConfigOwningPublisher         = 3,
  EvtChannelConfigClassicEventlog         = 4,
  EvtChannelConfigAccess                  = 5,
  EvtChannelLoggingConfigRetention        = 6,
  EvtChannelLoggingConfigAutoBackup       = 7,
  EvtChannelLoggingConfigMaxSize          = 8,
  EvtChannelLoggingConfigLogFilePath      = 9,
  EvtChannelPublishingConfigLevel         = 10,
  EvtChannelPublishingConfigKeywords      = 11,
  EvtChannelPublishingConfigControlGuid   = 12,
  EvtChannelPublishingConfigBufferSize    = 13,
  EvtChannelPublishingConfigMinBuffers    = 14,
  EvtChannelPublishingConfigMaxBuffers    = 15,
  EvtChannelPublishingConfigLatency       = 16,
  EvtChannelPublishingConfigClockType     = 17,
  EvtChannelPublishingConfigSidType       = 18,
  EvtChannelPublisherList                 = 19,
  EvtChannelPublishingConfigFileMax       = 20,
  EvtChannelConfigPropertyIdEND           = 21 
} EVT_CHANNEL_CONFIG_PROPERTY_ID;

typedef enum _EVT_CHANNEL_ISOLATION_TYPE {
  EvtChannelIsolationTypeApplication   = 0,
  EvtChannelIsolationTypeSystem        = 1,
  EvtChannelIsolationTypeCustom        = 2 
} EVT_CHANNEL_ISOLATION_TYPE;

typedef enum _EVT_CHANNEL_REFERENCE_FLAGS {
  EvtChannelReferenceImported   = 0x1 
} EVT_CHANNEL_REFERENCE_FLAGS;

typedef enum _EVT_CHANNEL_SID_TYPE {
  EvtChannelSidTypeNone         = 0,
  EvtChannelSidTypePublishing   = 1 
} EVT_CHANNEL_SID_TYPE;

typedef enum _EVT_CHANNEL_TYPE {
  EvtChannelTypeAdmin         = 0,
  EvtChannelTypeOperational   = 1,
  EvtChannelTypeAnalytic      = 2,
  EvtChannelTypeDebug         = 3 
} EVT_CHANNEL_TYPE;

typedef enum _EVT_EVENT_METADATA_PROPERTY_ID {
  EventMetadataEventID            = 0,
  EventMetadataEventVersion       = 1,
  EventMetadataEventChannel       = 2,
  EventMetadataEventLevel         = 3,
  EventMetadataEventOpcode        = 4,
  EventMetadataEventTask          = 5,
  EventMetadataEventKeyword       = 6,
  EventMetadataEventMessageID     = 7,
  EventMetadataEventTemplate      = 8,
  EvtEventMetadataPropertyIdEND   = 9 
} EVT_EVENT_METADATA_PROPERTY_ID;

typedef enum _EVT_EVENT_PROPERTY_ID {
  EvtEventQueryIDs        = 0,
  EvtEventPath            = 1,
  EvtEventPropertyIdEND   = 2 
} EVT_EVENT_PROPERTY_ID;

typedef enum _EVT_EXPORTLOG_FLAGS {
  EvtExportLogChannelPath           = 0x1,
  EvtExportLogFilePath              = 0x2,
  EvtExportLogTolerateQueryErrors   = 0x1000 
} EVT_EXPORTLOG_FLAGS;

typedef enum _EVT_FORMAT_MESSAGE_FLAGS {
  EvtFormatMessageEvent      = 1,
  EvtFormatMessageLevel      = 2,
  EvtFormatMessageTask       = 3,
  EvtFormatMessageOpcode     = 4,
  EvtFormatMessageKeyword    = 5,
  EvtFormatMessageChannel    = 6,
  EvtFormatMessageProvider   = 7,
  EvtFormatMessageId         = 8,
  EvtFormatMessageXml        = 9 
} EVT_FORMAT_MESSAGE_FLAGS;

typedef enum _EVT_LOG_PROPERTY_ID {
  EvtLogCreationTime         = 0,
  EvtLogLastAccessTime       = 1,
  EvtLogLastWriteTime        = 2,
  EvtLogFileSize             = 3,
  EvtLogAttributes           = 4,
  EvtLogNumberOfLogRecords   = 5,
  EvtLogOldestRecordNumber   = 6,
  EvtLogFull                 = 7 
} EVT_LOG_PROPERTY_ID;

typedef enum _EVT_LOGIN_CLASS {
  EvtRpcLogin   = 1 
} EVT_LOGIN_CLASS;

typedef enum _EVT_OPEN_LOG_FLAGS {
  EvtOpenChannelPath   = 0x1,
  EvtOpenFilePath      = 0x2 
} EVT_OPEN_LOG_FLAGS;

typedef enum _EVT_PUBLISHER_METADATA_PROPERTY_ID {
  EvtPublisherMetadataPublisherGuid               = 0,
  EvtPublisherMetadataResourceFilePath,
  EvtPublisherMetadataParameterFilePath,
  EvtPublisherMetadataMessageFilePath,
  EvtPublisherMetadataHelpLink,
  EvtPublisherMetadataPublisherMessageID,
  EvtPublisherMetadataChannelReferences,
  EvtPublisherMetadataChannelReferencePath,
  EvtPublisherMetadataChannelReferenceIndex,
  EvtPublisherMetadataChannelReferenceID,
  EvtPublisherMetadataChannelReferenceFlags,
  EvtPublisherMetadataChannelReferenceMessageID,
  EvtPublisherMetadataLevels,
  EvtPublisherMetadataLevelName,
  EvtPublisherMetadataLevelValue,
  EvtPublisherMetadataLevelMessageID,
  EvtPublisherMetadataTasks,
  EvtPublisherMetadataTaskName,
  EvtPublisherMetadataTaskEventGuid,
  EvtPublisherMetadataTaskValue,
  EvtPublisherMetadataTaskMessageID,
  EvtPublisherMetadataOpcodes,
  EvtPublisherMetadataOpcodeName,
  EvtPublisherMetadataOpcodeValue,
  EvtPublisherMetadataOpcodeMessageID,
  EvtPublisherMetadataKeywords,
  EvtPublisherMetadataKeywordName,
  EvtPublisherMetadataKeywordValue,
  EvtPublisherMetadataKeywordMessageID,
  EvtPublisherMetadataPropertyIdEND 
} EVT_PUBLISHER_METADATA_PROPERTY_ID;

typedef enum _EVT_QUERY_FLAGS {
  EvtQueryChannelPath           = 0x1,
  EvtQueryFilePath              = 0x2,
  EvtQueryForwardDirection      = 0x100,
  EvtQueryReverseDirection      = 0x200,
  EvtQueryTolerateQueryErrors   = 0x1000 
} EVT_QUERY_FLAGS;

typedef enum _EVT_QUERY_PROPERTY_ID {
  EvtQueryNames           = 0,
  EvtQueryStatuses        = 1,
  EvtQueryPropertyIdEND   = 2 
} EVT_QUERY_PROPERTY_ID;

typedef enum _EVT_RENDER_CONTEXT_FLAGS {
  EvtRenderContextValues   = 0,
  EvtRenderContextSystem   = 1,
  EvtRenderContextUser     = 2  
} EVT_RENDER_CONTEXT_FLAGS;

typedef enum _EVT_RENDER_FLAGS {
  EvtRenderEventValues   = 0,
  EvtRenderEventXml      = 1,
  EvtRenderBookmark      = 2 
} EVT_RENDER_FLAGS;

typedef struct _EVT_RPC_LOGIN {
  LPWSTR Server;
  LPWSTR User;
  LPWSTR Domain;
  LPWSTR Password;
  DWORD  Flags;
} EVT_RPC_LOGIN;

typedef enum _EVT_RPC_LOGIN_FLAGS {
  EvtRpcLoginAuthDefault     = 0,
  EvtRpcLoginAuthNegotiate   = 1,
  EvtRpcLoginAuthKerberos    = 2,
  EvtRpcLoginAuthNTLM        = 3 
} EVT_RPC_LOGIN_FLAGS;

typedef enum _EVT_SEEK_FLAGS {
  EvtSeekRelativeToFirst      = 1,
  EvtSeekRelativeToLast       = 2,
  EvtSeekRelativeToCurrent    = 3,
  EvtSeekRelativeToBookmark   = 4,
  EvtSeekOriginMask           = 7,
  EvtSeekStrict               = 0x10000 
} EVT_SEEK_FLAGS;

typedef enum _EVT_SUBSCRIBE_FLAGS {
  EvtSubscribeToFutureEvents        = 1,
  EvtSubscribeStartAtOldestRecord   = 2,
  EvtSubscribeStartAfterBookmark    = 3,
  EvtSubscribeOriginMask            = 0x3,
  EvtSubscribeTolerateQueryErrors   = 0x1000,
  EvtSubscribeStrict                = 0x10000 
} EVT_SUBSCRIBE_FLAGS;

typedef enum _EVT_SUBSCRIBE_NOTIFY_ACTION {
  EvtSubscribeActionError     = 0,
  EvtSubscribeActionDeliver   = 1 
} EVT_SUBSCRIBE_NOTIFY_ACTION;

typedef enum _EVT_SYSTEM_PROPERTY_ID {
  EvtSystemProviderName        = 0,
  EvtSystemProviderGuid,
  EvtSystemEventID,
  EvtSystemQualifiers,
  EvtSystemLevel,
  EvtSystemTask,
  EvtSystemOpcode,
  EvtSystemKeywords,
  EvtSystemTimeCreated,
  EvtSystemEventRecordId,
  EvtSystemActivityID,
  EvtSystemRelatedActivityID,
  EvtSystemProcessID,
  EvtSystemThreadID,
  EvtSystemChannel,
  EvtSystemComputer,
  EvtSystemUserID,
  EvtSystemVersion,
  EvtSystemPropertyIdEND 
} EVT_SYSTEM_PROPERTY_ID;

typedef enum _EVT_VARIANT_TYPE {
  EvtVarTypeNull         = 0,
  EvtVarTypeString       = 1,
  EvtVarTypeAnsiString   = 2,
  EvtVarTypeSByte        = 3,
  EvtVarTypeByte         = 4,
  EvtVarTypeInt16        = 5,
  EvtVarTypeUInt16       = 6,
  EvtVarTypeInt32        = 7,
  EvtVarTypeUInt32       = 8,
  EvtVarTypeInt64        = 9,
  EvtVarTypeUInt64       = 10,
  EvtVarTypeSingle       = 11,
  EvtVarTypeDouble       = 12,
  EvtVarTypeBoolean      = 13,
  EvtVarTypeBinary       = 14,
  EvtVarTypeGuid         = 15,
  EvtVarTypeSizeT        = 16,
  EvtVarTypeFileTime     = 17,
  EvtVarTypeSysTime      = 18,
  EvtVarTypeSid          = 19,
  EvtVarTypeHexInt32     = 20,
  EvtVarTypeHexInt64     = 21,
  EvtVarTypeEvtHandle    = 32,
  EvtVarTypeEvtXml       = 35 
} EVT_VARIANT_TYPE;

typedef HANDLE EVT_HANDLE;
typedef HANDLE EVT_OBJECT_ARRAY_PROPERTY_HANDLE;

typedef struct _EVT_VARIANT {
  __C89_NAMELESS union {
    WINBOOL    BooleanVal;
    INT8       SByteVal;
    INT16      Int16Val;
    INT32      Int32Val;
    INT64      Int64Val;
    UINT8      ByteVal;
    UINT16     UInt16Val;
    UINT32     UInt32Val;
    UINT64     UInt64Val;
    float      SingleVal;
    double     DoubleVal;
    ULONGLONG  FileTimeVal;
    SYSTEMTIME *SysTimeVal;
    GUID       *GuidVal;
    LPCWSTR    StringVal;
    LPCSTR     AnsiStringVal;
    PBYTE      BinaryVal;
    PSID       SidVal;
    size_t     SizeTVal;
    EVT_HANDLE EvtHandleVal;
    BOOL       *BooleanArr;
    INT8       *SByteArr;
    INT16      *Int16Arr;
    INT32      *Int32Arr;
    INT64      *Int64Arr;
    UINT8      *ByteArr;
    UINT16     *UInt16Arr;
    UINT32     *UInt32Arr;
    UINT64     *UInt64Arr;
    float      *SingleArr;
    double     *DoubleArr;
    FILETIME   *FileTimeArr;
    SYSTEMTIME *SysTimeArr;
    GUID       *GuidArr;
    LPWSTR     *StringArr;
    LPSTR      *AnsiStringArr;
    PSID       *SidArr;
    size_t     *SizeTArr;
    LPCWSTR    XmlVal;
    LPCWSTR*   XmlValArr;
  };
  DWORD Count;
  DWORD Type;
} EVT_VARIANT, *PEVT_VARIANT;

typedef DWORD ( WINAPI *EVT_SUBSCRIBE_CALLBACK )(
    EVT_SUBSCRIBE_NOTIFY_ACTION Action,
    PVOID UserContext,
    EVT_HANDLE Event
);

WINBOOL WINAPI EvtArchiveExportedLog(
  EVT_HANDLE Session,
  LPCWSTR LogFilePath,
  LCID Locale,
  DWORD Flags
);

WINBOOL WINAPI EvtCancel(
  EVT_HANDLE Object
);

WINBOOL WINAPI EvtClearLog(
  EVT_HANDLE Session,
  LPCWSTR ChannelPath,
  LPCWSTR TargetFilePath,
  DWORD Flags
);

WINBOOL WINAPI EvtClose(
  EVT_HANDLE Object
);

EVT_HANDLE WINAPI EvtCreateBookmark(
  LPCWSTR BookmarkXml
);

EVT_HANDLE WINAPI EvtCreateRenderContext(
  DWORD ValuePathsCount,
  LPCWSTR *ValuePaths,
  DWORD Flags
);

WINBOOL WINAPI EvtExportLog(
  EVT_HANDLE Session,
  LPCWSTR Path,
  LPCWSTR Query,
  LPCWSTR TargetFilePath,
  DWORD Flags
);

WINBOOL WINAPI EvtFormatMessage(
  EVT_HANDLE PublisherMetadata,
  EVT_HANDLE Event,
  DWORD MessageId,
  DWORD ValueCount,
  PEVT_VARIANT Values,
  DWORD Flags,
  DWORD BufferSize,
  LPWSTR Buffer,
  PDWORD BufferUsed
);

WINBOOL WINAPI EvtGetChannelConfigProperty(
  EVT_HANDLE ChannelConfig,
  EVT_CHANNEL_CONFIG_PROPERTY_ID PropertyId,
  DWORD Flags,
  DWORD PropertyValueBufferSize,
  PEVT_VARIANT PropertyValueBuffer,
  PDWORD PropertyValueBufferUsed
);

WINBOOL WINAPI EvtGetEventInfo(
  EVT_HANDLE Event,
  EVT_EVENT_PROPERTY_ID PropertyId,
  DWORD PropertyValueBufferSize,
  PEVT_VARIANT PropertyValueBuffer,
  PDWORD PropertyValueBufferUsed
);

WINBOOL WINAPI EvtGetEventMetadataProperty(
  EVT_HANDLE EventMetadata,
  EVT_EVENT_METADATA_PROPERTY_ID PropertyId,
  DWORD Flags,
  DWORD EventMetadataPropertyBufferSize,
  PEVT_VARIANT EventMetadataPropertyBuffer,
  PDWORD EventMetadataPropertyBufferUsed
);

DWORD WINAPI EvtGetExtendedStatus(
  DWORD BufferSize,
  LPWSTR Buffer,
  PDWORD BufferUsed
);

WINBOOL WINAPI EvtGetLogInfo(
  EVT_HANDLE Log,
  EVT_LOG_PROPERTY_ID PropertyId,
  DWORD PropertyValueBufferSize,
  PEVT_VARIANT PropertyValueBuffer,
  PDWORD PropertyValueBufferUsed
);

WINBOOL WINAPI EvtGetObjectArrayProperty(
  EVT_OBJECT_ARRAY_PROPERTY_HANDLE ObjectArray,
  DWORD PropertyId,
  DWORD ArrayIndex,
  DWORD Flags,
  DWORD PropertyValueBufferSize,
  PEVT_VARIANT PropertyValueBuffer,
  PDWORD PropertyValueBufferUsed
);

WINBOOL WINAPI EvtGetObjectArraySize(
  EVT_OBJECT_ARRAY_PROPERTY_HANDLE ObjectArray,
  PDWORD ObjectArraySize
);

WINBOOL WINAPI EvtGetPublisherMetadataProperty(
  EVT_HANDLE PublisherMetadata,
  EVT_PUBLISHER_METADATA_PROPERTY_ID PropertyId,
  DWORD Flags,
  DWORD PublisherMetadataPropertyBufferSize,
  PEVT_VARIANT PublisherMetadataPropertyBuffer,
  PDWORD PublisherMetadataPropertyBufferUsed
);

WINBOOL WINAPI EvtGetQueryInfo(
  EVT_HANDLE QueryOrSubscription,
  EVT_QUERY_PROPERTY_ID PropertyId,
  DWORD PropertyValueBufferSize,
  PEVT_VARIANT PropertyValueBuffer,
  PDWORD PropertyValueBufferUsed
);

WINBOOL WINAPI EvtNext(
  EVT_HANDLE ResultSet,
  DWORD EventArraySize,
  EVT_HANDLE* EventArray,
  DWORD Timeout,
  DWORD Flags,
  PDWORD Returned
);

WINBOOL WINAPI EvtNextChannelPath(
  EVT_HANDLE ChannelEnum,
  DWORD ChannelPathBufferSize,
  LPWSTR ChannelPathBuffer,
  PDWORD ChannelPathBufferUsed
);

EVT_HANDLE WINAPI EvtNextEventMetadata(
  EVT_HANDLE EventMetadataEnum,
  DWORD Flags
);

WINBOOL WINAPI EvtNextPublisherId(
  EVT_HANDLE PublisherEnum,
  DWORD PublisherIdBufferSize,
  LPWSTR PublisherIdBuffer,
  PDWORD PublisherIdBufferUsed
);

EVT_HANDLE WINAPI EvtOpenChannelConfig(
  EVT_HANDLE Session,
  LPCWSTR ChannelPath,
  DWORD Flags
);

EVT_HANDLE WINAPI EvtOpenChannelEnum(
  EVT_HANDLE Session,
  DWORD Flags
);

EVT_HANDLE WINAPI EvtOpenEventMetadataEnum(
  EVT_HANDLE PublisherMetadata,
  DWORD Flags
);

EVT_HANDLE WINAPI EvtOpenLog(
  EVT_HANDLE Session,
  LPCWSTR Path,
  DWORD Flags
);

EVT_HANDLE WINAPI EvtOpenPublisherEnum(
  EVT_HANDLE Session,
  DWORD Flags
);

EVT_HANDLE WINAPI EvtOpenPublisherMetadata(
  EVT_HANDLE Session,
  LPCWSTR PublisherIdentity,
  LPCWSTR LogFilePath,
  LCID Locale,
  DWORD Flags
);

EVT_HANDLE WINAPI EvtOpenSession(
  EVT_LOGIN_CLASS LoginClass,
  PVOID Login,
  DWORD Timeout,
  DWORD Flags
);

EVT_HANDLE WINAPI EvtQuery(
  EVT_HANDLE Session,
  LPCWSTR Path,
  LPCWSTR Query,
  DWORD Flags
);

WINBOOL WINAPI EvtRender(
  EVT_HANDLE Context,
  EVT_HANDLE Fragment,
  DWORD Flags,
  DWORD BufferSize,
  PVOID Buffer,
  PDWORD BufferUsed,
  PDWORD PropertyCount
);

WINBOOL WINAPI EvtSaveChannelConfig(
  EVT_HANDLE ChannelConfig,
  DWORD Flags
);

WINBOOL WINAPI EvtSeek(
  EVT_HANDLE ResultSet,
  LONGLONG Position,
  EVT_HANDLE Bookmark,
  DWORD Timeout,
  DWORD Flags
);

WINBOOL WINAPI EvtSetChannelConfigProperty(
  EVT_HANDLE ChannelConfig,
  EVT_CHANNEL_CONFIG_PROPERTY_ID PropertyId,
  DWORD Flags,
  PEVT_VARIANT PropertyValue
);

EVT_HANDLE WINAPI EvtSubscribe(
  EVT_HANDLE Session,
  HANDLE SignalEvent,
  LPCWSTR ChannelPath,
  LPCWSTR Query,
  EVT_HANDLE Bookmark,
  PVOID context,
  EVT_SUBSCRIBE_CALLBACK Callback,
  DWORD Flags
);

WINBOOL WINAPI EvtUpdateBookmark(
  EVT_HANDLE Bookmark,
  EVT_HANDLE Event
);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_TDH*/
