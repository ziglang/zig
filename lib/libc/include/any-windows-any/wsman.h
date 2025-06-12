/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef _WSMAN_H_
#define _WSMAN_H_

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#if !defined (WSMAN_API_VERSION_1_0) && !defined (WSMAN_API_VERSION_1_1)
#error Either WSMAN_API_VERSION_1_0 or WSMAN_API_VERSION_1_1 need to be defined before including this header.
#endif

#define WSMAN_FLAG_REQUESTED_API_VERSION_1_0 0x0
#define WSMAN_FLAG_REQUESTED_API_VERSION_1_1 0x1

#define WSMAN_OPERATION_INFOV1 0x00000000
#define WSMAN_OPERATION_INFOV2 0xaabbccdd

#define WSMAN_STREAM_ID_STDIN L"stdin"
#define WSMAN_STREAM_ID_STDOUT L"stdout"
#define WSMAN_STREAM_ID_STDERR L"stderr"

#define WSMAN_DEFAULT_TIMEOUT_MS 60000

#define WSMAN_FLAG_RECEIVE_RESULT_NO_MORE_DATA 1
#define WSMAN_FLAG_RECEIVE_FLUSH 2
#define WSMAN_FLAG_RECEIVE_RESULT_DATA_BOUNDARY 4

#define WSMAN_PLUGIN_PARAMS_MAX_ENVELOPE_SIZE 1
#define WSMAN_PLUGIN_PARAMS_TIMEOUT 2
#define WSMAN_PLUGIN_PARAMS_REMAINING_RESULT_SIZE 3
#define WSMAN_PLUGIN_PARAMS_LARGEST_RESULT_SIZE 4
#define WSMAN_PLUGIN_PARAMS_GET_REQUESTED_LOCALE 5
#define WSMAN_PLUGIN_PARAMS_GET_REQUESTED_DATA_LOCALE 6

#define WSMAN_PLUGIN_PARAMS_SHAREDHOST 1
#define WSMAN_PLUGIN_PARAMS_RUNAS_USER 2
#define WSMAN_PLUGIN_PARAMS_AUTORESTART 3
#define WSMAN_PLUGIN_PARAMS_HOSTIDLETIMEOUTSECONDS 4
#define WSMAN_PLUGIN_PARAMS_NAME 5

#define WSMAN_PLUGIN_STARTUP_REQUEST_RECEIVED 0x0
#define WSMAN_PLUGIN_STARTUP_AUTORESTARTED_REBOOT 0x1
#define WSMAN_PLUGIN_STARTUP_AUTORESTARTED_CRASH 0x2

#define WSMAN_PLUGIN_SHUTDOWN_SYSTEM 1
#define WSMAN_PLUGIN_SHUTDOWN_SERVICE 2
#define WSMAN_PLUGIN_SHUTDOWN_IISHOST 3
#define WSMAN_PLUGIN_SHUTDOWN_IDLETIMEOUT_ELAPSED 4

#define WSMAN_FLAG_SEND_NO_MORE_DATA 1

#define WSMAN_SHELL_NS L"http://schemas.microsoft.com/wbem/wsman/1/windows/shell"
#define WSMAN_SHELL_NS_LEN (sizeof (WSMAN_SHELL_NS)/sizeof (WCHAR)-1)

#define WSMAN_CMDSHELL_URI WSMAN_SHELL_NS L"/cmd"

#define WSMAN_CMDSHELL_OPTION_CODEPAGE L"WINRS_CODEPAGE"
#define WSMAN_SHELL_OPTION_NOPROFILE L"WINRS_NOPROFILE"

#define WSMAN_CMDSHELL_OPTION_CONSOLEMODE_STDIN L"WINRS_CONSOLEMODE_STDIN"
#define WSMAN_CMDSHELL_OPTION_SKIP_CMD_SHELL L"WINRS_SKIP_CMD_SHELL"

#define WSMAN_COMMAND_STATE_DONE WSMAN_SHELL_NS L"/CommandState/Done"
#define WSMAN_COMMAND_STATE_PENDING WSMAN_SHELL_NS L"/CommandState/Pending"
#define WSMAN_COMMAND_STATE_RUNNING WSMAN_SHELL_NS L"/CommandState/Running"

#define WSMAN_SIGNAL_SHELL_CODE_TERMINATE WSMAN_SHELL_NS L"/signal/terminate"
#define WSMAN_SIGNAL_SHELL_CODE_CTRL_C WSMAN_SHELL_NS L"/signal/ctrl_c"
#define WSMAN_SIGNAL_SHELL_CODE_CTRL_BREAK WSMAN_SHELL_NS L"/signal/ctrl_break"

#ifdef __cplusplus
extern "C" {
#endif

  typedef enum WSManDataType {
    WSMAN_DATA_NONE = 0,
    WSMAN_DATA_TYPE_TEXT = 1,
    WSMAN_DATA_TYPE_BINARY = 2,
    WSMAN_DATA_TYPE_DWORD = 4
  } WSManDataType;

  typedef enum WSManAuthenticationFlags {
    WSMAN_FLAG_DEFAULT_AUTHENTICATION = 0x0,
    WSMAN_FLAG_NO_AUTHENTICATION = 0x1,
    WSMAN_FLAG_AUTH_DIGEST = 0x2,
    WSMAN_FLAG_AUTH_NEGOTIATE = 0x4,
    WSMAN_FLAG_AUTH_BASIC = 0x8,
    WSMAN_FLAG_AUTH_KERBEROS = 0x10,
    WSMAN_FLAG_AUTH_CLIENT_CERTIFICATE = 0x20
#if WINVER >= 0x600
    ,WSMAN_FLAG_AUTH_CREDSSP = 0x80
#endif
  } WSManAuthenticationFlags;

  enum WSManProxyAccessType {
    WSMAN_OPTION_PROXY_IE_PROXY_CONFIG = 1,
    WSMAN_OPTION_PROXY_WINHTTP_PROXY_CONFIG = 2,
    WSMAN_OPTION_PROXY_AUTO_DETECT = 4,
    WSMAN_OPTION_PROXY_NO_PROXY_SERVER = 8
  };

  typedef enum WSManSessionOption {
    WSMAN_OPTION_DEFAULT_OPERATION_TIMEOUTMS = 1,
    WSMAN_OPTION_MAX_RETRY_TIME = 11,
    WSMAN_OPTION_TIMEOUTMS_CREATE_SHELL = 12,
    WSMAN_OPTION_TIMEOUTMS_RUN_SHELL_COMMAND = 13,
    WSMAN_OPTION_TIMEOUTMS_RECEIVE_SHELL_OUTPUT = 14,
    WSMAN_OPTION_TIMEOUTMS_SEND_SHELL_INPUT = 15,
    WSMAN_OPTION_TIMEOUTMS_SIGNAL_SHELL = 16,
    WSMAN_OPTION_TIMEOUTMS_CLOSE_SHELL = 17,
    WSMAN_OPTION_SKIP_CA_CHECK = 18,
    WSMAN_OPTION_SKIP_CN_CHECK = 19,
    WSMAN_OPTION_UNENCRYPTED_MESSAGES = 20,
    WSMAN_OPTION_UTF16 = 21,
    WSMAN_OPTION_ENABLE_SPN_SERVER_PORT = 22,
    WSMAN_OPTION_MACHINE_ID = 23,
    WSMAN_OPTION_LOCALE = 25,
    WSMAN_OPTION_UI_LANGUAGE = 26,
    WSMAN_OPTION_MAX_ENVELOPE_SIZE_KB = 28,
    WSMAN_OPTION_SHELL_MAX_DATA_SIZE_PER_MESSAGE_KB = 29,
    WSMAN_OPTION_REDIRECT_LOCATION = 30,
    WSMAN_OPTION_SKIP_REVOCATION_CHECK = 31,
    WSMAN_OPTION_ALLOW_NEGOTIATE_IMPLICIT_CREDENTIALS = 32,
    WSMAN_OPTION_USE_SSL = 33,
    WSMAN_OPTION_USE_INTEARACTIVE_TOKEN = 34
  } WSManSessionOption;

  typedef enum WSManShellFlag {
    WSMAN_FLAG_NO_COMPRESSION = 0x1,
    WSMAN_FLAG_DELETE_SERVER_SESSION = 0x2,
    WSMAN_FLAG_SERVER_BUFFERING_MODE_DROP = 0x4,
    WSMAN_FLAG_SERVER_BUFFERING_MODE_BLOCK = 0x8,
    WSMAN_FLAG_RECEIVE_DELAY_OUTPUT_STREAM = 0x10
  } WSManShellFlag;

  typedef enum WSManCallbackFlags {
    WSMAN_FLAG_CALLBACK_END_OF_OPERATION = 0x1,
    WSMAN_FLAG_CALLBACK_END_OF_STREAM = 0x8,
    WSMAN_FLAG_CALLBACK_SHELL_SUPPORTS_DISCONNECT = 0x20,
    WSMAN_FLAG_CALLBACK_SHELL_AUTODISCONNECTED = 0x40,
    WSMAN_FLAG_CALLBACK_NETWORK_FAILURE_DETECTED = 0x100,
    WSMAN_FLAG_CALLBACK_RETRYING_AFTER_NETWORK_FAILURE = 0x200,
    WSMAN_FLAG_CALLBACK_RECONNECTED_AFTER_NETWORK_FAILURE = 0x400,
    WSMAN_FLAG_CALLBACK_SHELL_AUTODISCONNECTING = 0x800,
    WSMAN_FLAG_CALLBACK_RETRY_ABORTED_DUE_TO_INTERNAL_ERROR = 0x1000,
    WSMAN_FLAG_CALLBACK_RECEIVE_DELAY_STREAM_REQUEST_PROCESSED = 0x2000
  } WSManCallbackFlags;

  typedef struct _WSMAN_DATA_TEXT {
    DWORD bufferLength;
    PCWSTR buffer;
  } WSMAN_DATA_TEXT;

  typedef struct _WSMAN_DATA_BINARY {
    DWORD dataLength;
    BYTE *data;
  } WSMAN_DATA_BINARY;

  typedef struct _WSMAN_DATA {
    WSManDataType type;
    __C89_NAMELESS union {
      WSMAN_DATA_TEXT text;
      WSMAN_DATA_BINARY binaryData;
      DWORD number;
    };
  } WSMAN_DATA;

  typedef struct _WSMAN_ERROR {
    DWORD code;
    PCWSTR errorDetail;
    PCWSTR language;
    PCWSTR machineName;
    PCWSTR pluginName;
  } WSMAN_ERROR;

  typedef struct _WSMAN_USERNAME_PASSWORD_CREDS {
    PCWSTR username;
    PCWSTR password;
  } WSMAN_USERNAME_PASSWORD_CREDS;

  typedef struct _WSMAN_AUTHENTICATION_CREDENTIALS {
    DWORD authenticationMechanism;
    __C89_NAMELESS union {
      WSMAN_USERNAME_PASSWORD_CREDS userAccount;
      PCWSTR certificateThumbprint;
    };
  } WSMAN_AUTHENTICATION_CREDENTIALS;

  typedef struct _WSMAN_OPTION {
    PCWSTR name;
    PCWSTR value;
    WINBOOL mustComply;
  } WSMAN_OPTION;

  typedef struct _WSMAN_OPTION_SET {
    DWORD optionsCount;
    WSMAN_OPTION *options;
    WINBOOL optionsMustUnderstand;
  } WSMAN_OPTION_SET;

  typedef struct _WSMAN_OPTION_SETEX {
    DWORD optionsCount;
    WSMAN_OPTION *options;
    WINBOOL optionsMustUnderstand;
    PCWSTR *optionTypes;
  } WSMAN_OPTION_SETEX;

  typedef struct _WSMAN_KEY {
    PCWSTR key;
    PCWSTR value;
  } WSMAN_KEY;

  typedef struct _WSMAN_SELECTOR_SET {
    DWORD numberKeys;
    WSMAN_KEY *keys;
  } WSMAN_SELECTOR_SET;

  typedef struct _WSMAN_FRAGMENT {
    PCWSTR path;
    PCWSTR dialect;
  } WSMAN_FRAGMENT;

  typedef struct _WSMAN_FILTER {
    PCWSTR filter;
    PCWSTR dialect;
  } WSMAN_FILTER;

  typedef struct _WSMAN_OPERATION_INFO {
    WSMAN_FRAGMENT fragment;
    WSMAN_FILTER filter;
    WSMAN_SELECTOR_SET selectorSet;
    WSMAN_OPTION_SET optionSet;
    void *reserved;
    DWORD version;
  } WSMAN_OPERATION_INFO;

  typedef struct _WSMAN_OPERATION_INFOEX {
    WSMAN_FRAGMENT fragment;
    WSMAN_FILTER filter;
    WSMAN_SELECTOR_SET selectorSet;
    WSMAN_OPTION_SETEX optionSet;
    DWORD version;
    PCWSTR uiLocale;
    PCWSTR dataLocale;
  } WSMAN_OPERATION_INFOEX;

  typedef struct _WSMAN_PROXY_INFO {
    DWORD accessType;
    WSMAN_AUTHENTICATION_CREDENTIALS authenticationCredentials;
  } WSMAN_PROXY_INFO;

  typedef struct WSMAN_API *WSMAN_API_HANDLE;
  typedef struct WSMAN_SESSION *WSMAN_SESSION_HANDLE;
  typedef struct WSMAN_OPERATION *WSMAN_OPERATION_HANDLE;
  typedef struct WSMAN_SHELL *WSMAN_SHELL_HANDLE;
  typedef struct WSMAN_COMMAND *WSMAN_COMMAND_HANDLE;

  typedef struct _WSMAN_STREAM_ID_SET {
    DWORD streamIDsCount;
    PCWSTR *streamIDs;
  } WSMAN_STREAM_ID_SET;

  typedef struct _WSMAN_ENVIRONMENT_VARIABLE {
    PCWSTR name;
    PCWSTR value;
  } WSMAN_ENVIRONMENT_VARIABLE;

  typedef struct _WSMAN_ENVIRONMENT_VARIABLE_SET {
    DWORD varsCount;
    WSMAN_ENVIRONMENT_VARIABLE *vars;
  } WSMAN_ENVIRONMENT_VARIABLE_SET;

  typedef struct _WSMAN_SHELL_STARTUP_INFO_V10 {
    WSMAN_STREAM_ID_SET *inputStreamSet;
    WSMAN_STREAM_ID_SET *outputStreamSet;
    DWORD idleTimeoutMs;
    PCWSTR workingDirectory;
    WSMAN_ENVIRONMENT_VARIABLE_SET *variableSet;
  } WSMAN_SHELL_STARTUP_INFO_V10;

  typedef struct _WSMAN_SHELL_STARTUP_INFO_V11 {
    WSMAN_STREAM_ID_SET *inputStreamSet;
    WSMAN_STREAM_ID_SET *outputStreamSet;
    DWORD idleTimeoutMs;
    PCWSTR workingDirectory;
    WSMAN_ENVIRONMENT_VARIABLE_SET *variableSet;
    PCWSTR name;
  } WSMAN_SHELL_STARTUP_INFO_V11;

  typedef struct _WSMAN_SHELL_DISCONNECT_INFO {
    DWORD idleTimeoutMs;
  } WSMAN_SHELL_DISCONNECT_INFO;

  typedef struct _WSMAN_RECEIVE_DATA_RESULT {
    PCWSTR streamId;
    WSMAN_DATA streamData;
    PCWSTR commandState;
    DWORD exitCode;
  } WSMAN_RECEIVE_DATA_RESULT;

#ifdef WSMAN_API_VERSION_1_0
  typedef WSMAN_SHELL_STARTUP_INFO_V10 WSMAN_SHELL_STARTUP_INFO;
  typedef void (CALLBACK *WSMAN_SHELL_COMPLETION_FUNCTION) (PVOID operationContext, DWORD flags, WSMAN_ERROR *error, WSMAN_SHELL_HANDLE shell, WSMAN_COMMAND_HANDLE command, WSMAN_OPERATION_HANDLE operationHandle, WSMAN_RECEIVE_DATA_RESULT *data);
#else
  typedef WSMAN_SHELL_STARTUP_INFO_V11 WSMAN_SHELL_STARTUP_INFO;
  typedef void (CALLBACK *WSMAN_SHELL_COMPLETION_FUNCTION) (PVOID operationContext, DWORD flags, WSMAN_ERROR *error, WSMAN_SHELL_HANDLE shell, WSMAN_COMMAND_HANDLE command, WSMAN_OPERATION_HANDLE operationHandle, WSMAN_RESPONSE_DATA *data);

  typedef struct _WSMAN_CONNECT_DATA {
    WSMAN_DATA data;
  } WSMAN_CONNECT_DATA;

  typedef struct _WSMAN_CREATE_SHELL_DATA {
    WSMAN_DATA data;
  } WSMAN_CREATE_SHELL_DATA;

  typedef union _WSMAN_RESPONSE_DATA {
    WSMAN_RECEIVE_DATA_RESULT receiveData;
    WSMAN_CONNECT_DATA connectData;
    WSMAN_CREATE_SHELL_DATA createData;
  } WSMAN_RESPONSE_DATA;
#endif

  typedef struct _WSMAN_SHELL_ASYNC {
    PVOID operationContext;
    WSMAN_SHELL_COMPLETION_FUNCTION completionFunction;
  } WSMAN_SHELL_ASYNC;

  typedef struct _WSMAN_COMMAND_ARG_SET {
    DWORD argsCount;
    PCWSTR *args;
  } WSMAN_COMMAND_ARG_SET;

  typedef struct _WSMAN_CERTIFICATE_DETAILS {
    PCWSTR subject;
    PCWSTR issuerName;
    PCWSTR issuerThumbprint;
    PCWSTR subjectName;
  } WSMAN_CERTIFICATE_DETAILS;

  typedef struct _WSMAN_SENDER_DETAILS {
    PCWSTR senderName;
    PCWSTR authenticationMechanism;
    WSMAN_CERTIFICATE_DETAILS *certificateDetails;
    HANDLE clientToken;
    PCWSTR httpURL;
  } WSMAN_SENDER_DETAILS;

  typedef struct _WSMAN_PLUGIN_REQUEST {
    WSMAN_SENDER_DETAILS *senderDetails;
    PCWSTR locale;
    PCWSTR resourceUri;
    WSMAN_OPERATION_INFO *operationInfo;
    volatile WINBOOL shutdownNotification;
    HANDLE shutdownNotificationHandle;
    PCWSTR dataLocale;
  } WSMAN_PLUGIN_REQUEST;

  typedef struct _WSMAN_AUTHZ_QUOTA {
    DWORD maxAllowedConcurrentShells;
    DWORD maxAllowedConcurrentOperations;
    DWORD timeslotSize;
    DWORD maxAllowedOperationsPerTimeslot;
  } WSMAN_AUTHZ_QUOTA;

  typedef VOID (WINAPI *WSMAN_PLUGIN_RELEASE_SHELL_CONTEXT) (PVOID shellContext);
  typedef VOID (WINAPI *WSMAN_PLUGIN_RELEASE_COMMAND_CONTEXT) (PVOID shellContext, PVOID commandContext);
  typedef DWORD (WINAPI *WSMAN_PLUGIN_STARTUP) (DWORD flags, PCWSTR applicationIdentification, PCWSTR extraInfo, PVOID *pluginContext);
  typedef DWORD (WINAPI *WSMAN_PLUGIN_SHUTDOWN) (PVOID pluginContext, DWORD flags, DWORD reason);
  typedef VOID (WINAPI *WSMAN_PLUGIN_SHELL) (PVOID pluginContext, WSMAN_PLUGIN_REQUEST *requestDetails, DWORD flags, WSMAN_SHELL_STARTUP_INFO *startupInfo, WSMAN_DATA *inboundShellInformation);
  typedef VOID (WINAPI *WSMAN_PLUGIN_COMMAND) (WSMAN_PLUGIN_REQUEST *requestDetails, DWORD flags, PVOID shellContext, PCWSTR commandLine, WSMAN_COMMAND_ARG_SET *arguments);
  typedef VOID (WINAPI *WSMAN_PLUGIN_SEND) (WSMAN_PLUGIN_REQUEST *requestDetails, DWORD flags, PVOID shellContext, PVOID commandContext, PCWSTR stream, WSMAN_DATA *inboundData);
  typedef VOID (WINAPI *WSMAN_PLUGIN_RECEIVE) (WSMAN_PLUGIN_REQUEST *requestDetails, DWORD flags, PVOID shellContext, PVOID commandContext, WSMAN_STREAM_ID_SET *streamSet);
  typedef VOID (WINAPI *WSMAN_PLUGIN_SIGNAL) (WSMAN_PLUGIN_REQUEST *requestDetails, DWORD flags, PVOID shellContext, PVOID commandContext, PCWSTR code);
  typedef VOID (WINAPI *WSMAN_PLUGIN_CONNECT) (WSMAN_PLUGIN_REQUEST *requestDetails, DWORD flags, PVOID shellContext, PVOID commandContext, WSMAN_DATA *inboundConnectInformation);
  typedef VOID (WINAPI *WSMAN_PLUGIN_AUTHORIZE_USER) (PVOID pluginContext, WSMAN_SENDER_DETAILS *senderDetails, DWORD flags);
  typedef VOID (WINAPI *WSMAN_PLUGIN_AUTHORIZE_OPERATION) (PVOID pluginContext, WSMAN_SENDER_DETAILS *senderDetails, DWORD flags, DWORD operation, PCWSTR action, PCWSTR resourceUri);
  typedef VOID (WINAPI *WSMAN_PLUGIN_AUTHORIZE_QUERY_QUOTA) (PVOID pluginContext, WSMAN_SENDER_DETAILS *senderDetails, DWORD flags);
  typedef VOID (WINAPI *WSMAN_PLUGIN_AUTHORIZE_RELEASE_CONTEXT) (PVOID userAuthorizationContext);

  DWORD WINAPI WSManInitialize (DWORD flags, WSMAN_API_HANDLE *apiHandle);
  DWORD WINAPI WSManDeinitialize (WSMAN_API_HANDLE apiHandle, DWORD flags);
  DWORD WINAPI WSManGetErrorMessage (WSMAN_API_HANDLE apiHandle, DWORD flags, PCWSTR languageCode, DWORD errorCode, DWORD messageLength, PWSTR message, DWORD *messageLengthUsed);
  DWORD WINAPI WSManCreateSession (WSMAN_API_HANDLE apiHandle, PCWSTR connection, DWORD flags, WSMAN_AUTHENTICATION_CREDENTIALS *serverAuthenticationCredentials, WSMAN_PROXY_INFO *proxyInfo, WSMAN_SESSION_HANDLE *session);
  DWORD WINAPI WSManCloseSession (WSMAN_SESSION_HANDLE session, DWORD flags);
  DWORD WINAPI WSManSetSessionOption (WSMAN_SESSION_HANDLE session, WSManSessionOption option, WSMAN_DATA *data);
  DWORD WINAPI WSManGetSessionOptionAsDword (WSMAN_SESSION_HANDLE session, WSManSessionOption option, DWORD *value);
  DWORD WINAPI WSManGetSessionOptionAsString (WSMAN_SESSION_HANDLE session, WSManSessionOption option, DWORD stringLength, PWSTR string, DWORD *stringLengthUsed);
  DWORD WINAPI WSManCloseOperation (WSMAN_OPERATION_HANDLE operationHandle, DWORD flags);
  void WINAPI WSManCreateShell (WSMAN_SESSION_HANDLE session, DWORD flags, PCWSTR resourceUri, WSMAN_SHELL_STARTUP_INFO *startupInfo, WSMAN_OPTION_SET *options, WSMAN_DATA *createXml, WSMAN_SHELL_ASYNC *async, WSMAN_SHELL_HANDLE *shell);
  void WINAPI WSManRunShellCommand (WSMAN_SHELL_HANDLE shell, DWORD flags, PCWSTR commandLine, WSMAN_COMMAND_ARG_SET *args, WSMAN_OPTION_SET *options, WSMAN_SHELL_ASYNC *async, WSMAN_COMMAND_HANDLE *command);
  void WINAPI WSManSignalShell (WSMAN_SHELL_HANDLE shell, WSMAN_COMMAND_HANDLE command, DWORD flags, PCWSTR code, WSMAN_SHELL_ASYNC *async, WSMAN_OPERATION_HANDLE *signalOperation);
  void WINAPI WSManReceiveShellOutput (WSMAN_SHELL_HANDLE shell, WSMAN_COMMAND_HANDLE command, DWORD flags, WSMAN_STREAM_ID_SET *desiredStreamSet, WSMAN_SHELL_ASYNC *async, WSMAN_OPERATION_HANDLE *receiveOperation);
  void WINAPI WSManSendShellInput (WSMAN_SHELL_HANDLE shell, WSMAN_COMMAND_HANDLE command, DWORD flags, PCWSTR streamId, WSMAN_DATA *streamData, WINBOOL endOfStream, WSMAN_SHELL_ASYNC *async, WSMAN_OPERATION_HANDLE *sendOperation);
  void WINAPI WSManCloseCommand (WSMAN_COMMAND_HANDLE commandHandle, DWORD flags, WSMAN_SHELL_ASYNC *async);
  void WINAPI WSManCloseShell (WSMAN_SHELL_HANDLE shellHandle, DWORD flags, WSMAN_SHELL_ASYNC *async);
  DWORD WINAPI WSManPluginReportContext (WSMAN_PLUGIN_REQUEST *requestDetails, DWORD flags, PVOID context);
  DWORD WINAPI WSManPluginReceiveResult (WSMAN_PLUGIN_REQUEST *requestDetails, DWORD flags, PCWSTR stream, WSMAN_DATA *streamResult, PCWSTR commandState, DWORD exitCode);
  DWORD WINAPI WSManPluginOperationComplete (WSMAN_PLUGIN_REQUEST *requestDetails, DWORD flags, DWORD errorCode, PCWSTR extendedInformation);
  DWORD WINAPI WSManPluginGetOperationParameters (WSMAN_PLUGIN_REQUEST *requestDetails, DWORD flags, WSMAN_DATA *data);
  DWORD WINAPI WSManPluginGetConfiguration (PVOID pluginContext, DWORD flags, WSMAN_DATA *data);
  DWORD WINAPI WSManPluginReportCompletion (PVOID pluginContext, DWORD flags);
  DWORD WINAPI WSManPluginFreeRequestDetails (WSMAN_PLUGIN_REQUEST *requestDetails);
  DWORD WINAPI WSManPluginAuthzUserComplete (WSMAN_SENDER_DETAILS *senderDetails, DWORD flags, PVOID userAuthorizationContext, HANDLE impersonationToken, WINBOOL userIsAdministrator, DWORD errorCode, PCWSTR extendedErrorInformation);
  DWORD WINAPI WSManPluginAuthzOperationComplete (WSMAN_SENDER_DETAILS *senderDetails, DWORD flags, PVOID userAuthorizationContext, DWORD errorCode, PCWSTR extendedErrorInformation);
  DWORD WINAPI WSManPluginAuthzQueryQuotaComplete (WSMAN_SENDER_DETAILS *senderDetails, DWORD flags, WSMAN_AUTHZ_QUOTA *quota, DWORD errorCode, PCWSTR extendedErrorInformation);
#ifdef WSMAN_API_VERSION_1_1
  void WINAPI WSManCreateShellEx (WSMAN_SESSION_HANDLE session, DWORD flags, PCWSTR resourceUri, PCWSTR shellId, WSMAN_SHELL_STARTUP_INFO *startupInfo, WSMAN_OPTION_SET *options, WSMAN_DATA *createXml, WSMAN_SHELL_ASYNC *async, WSMAN_SHELL_HANDLE *shell);
  void WINAPI WSManRunShellCommandEx (WSMAN_SHELL_HANDLE shell, DWORD flags, PCWSTR commandId, PCWSTR commandLine, WSMAN_COMMAND_ARG_SET *args, WSMAN_OPTION_SET *options, WSMAN_SHELL_ASYNC *async, WSMAN_COMMAND_HANDLE *command);
  void WINAPI WSManDisconnectShell (WSMAN_SHELL_HANDLE shell, DWORD flags, WSMAN_SHELL_DISCONNECT_INFO *disconnectInfo, WSMAN_SHELL_ASYNC *async);
  void WINAPI WSManReconnectShell (WSMAN_SHELL_HANDLE shell, DWORD flags, WSMAN_SHELL_ASYNC *async);
  void WINAPI WSManReconnectShellCommand (WSMAN_COMMAND_HANDLE commandHandle, DWORD flags, WSMAN_SHELL_ASYNC *async);
  void WINAPI WSManConnectShell (WSMAN_SESSION_HANDLE session, DWORD flags, PCWSTR resourceUri, PCWSTR shellID, WSMAN_OPTION_SET *options, WSMAN_DATA *connectXml, WSMAN_SHELL_ASYNC *async, WSMAN_SHELL_HANDLE *shell);
  void WINAPI WSManConnectShellCommand (WSMAN_SHELL_HANDLE shell, DWORD flags, PCWSTR commandID, WSMAN_OPTION_SET *options, WSMAN_DATA *connectXml, WSMAN_SHELL_ASYNC *async, WSMAN_COMMAND_HANDLE *command);
#endif

#ifdef __cplusplus
}
#endif

#endif
#endif
