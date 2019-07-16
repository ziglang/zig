/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __HTTP_H__
#define __HTTP_H__

#include <winsock2.h>
#include <ws2tcpip.h>

#define SECURITY_WIN32
#include <sspi.h>

#ifdef __cplusplus
extern "C" {
#endif

#define HTTP_INITIALIZE_SERVER 0x00000001
#define HTTP_INITIALIZE_CONFIG 0x00000002

#define HTTP_RECEIVE_REQUEST_FLAG_COPY_BODY 0x00000001
#define HTTP_RECEIVE_REQUEST_ENTITY_BODY_FLAG_FILL_BUFFER 0x00000001

#define HTTP_SEND_RESPONSE_FLAG_DISCONNECT 0x00000001
#define HTTP_SEND_RESPONSE_FLAG_MORE_DATA 0x00000002
#define HTTP_SEND_RESPONSE_FLAG_BUFFER_DATA 0x00000004

#define HTTP_FLUSH_RESPONSE_FLAG_RECURSIVE 0x00000001

  typedef ULONGLONG HTTP_OPAQUE_ID,*PHTTP_OPAQUE_ID;

  typedef HTTP_OPAQUE_ID HTTP_REQUEST_ID,*PHTTP_REQUEST_ID;
  typedef HTTP_OPAQUE_ID HTTP_CONNECTION_ID,*PHTTP_CONNECTION_ID;
  typedef HTTP_OPAQUE_ID HTTP_RAW_CONNECTION_ID,*PHTTP_RAW_CONNECTION_ID;
  typedef HTTP_OPAQUE_ID HTTP_URL_GROUP_ID, *PHTTP_URL_GROUP_ID;
  typedef HTTP_OPAQUE_ID HTTP_SERVER_SESSION_ID, *PHTTP_SERVER_SESSION_ID;

#define HTTP_NULL_ID (0ull)
#define HTTP_IS_NULL_ID(pid) (HTTP_NULL_ID==*(pid))
#define HTTP_SET_NULL_ID(pid) (*(pid) = HTTP_NULL_ID)

#define HTTP_BYTE_RANGE_TO_EOF ((ULONGLONG)-1)

  typedef struct _HTTP_BYTE_RANGE {
    ULARGE_INTEGER StartingOffset;
    ULARGE_INTEGER Length;
  } HTTP_BYTE_RANGE,*PHTTP_BYTE_RANGE;

  typedef struct _HTTP_VERSION {
    USHORT MajorVersion;
    USHORT MinorVersion;
  } HTTP_VERSION,*PHTTP_VERSION;

#define HTTP_VERSION_UNKNOWN { 0,0 }
#define HTTP_VERSION_0_9 { 0,9 }
#define HTTP_VERSION_1_0 { 1,0 }
#define HTTP_VERSION_1_1 { 1,1 }

#define HTTP_SET_VERSION(version,major,minor) do { (version).MajorVersion = (major); (version).MinorVersion = (minor); } while (0,0)
#define HTTP_EQUAL_VERSION(version,major,minor) ((version).MajorVersion==(major) && (version).MinorVersion==(minor))
#define HTTP_GREATER_VERSION(version,major,minor) ((version).MajorVersion > (major) || ((version).MajorVersion==(major) && (version).MinorVersion > (minor)))
#define HTTP_LESS_VERSION(version,major,minor) ((version).MajorVersion < (major) || ((version).MajorVersion==(major) && (version).MinorVersion < (minor)))
#define HTTP_NOT_EQUAL_VERSION(version,major,minor) (!HTTP_EQUAL_VERSION(version,major,minor))
#define HTTP_GREATER_EQUAL_VERSION(version,major,minor) (!HTTP_LESS_VERSION(version,major,minor))
#define HTTP_LESS_EQUAL_VERSION(version,major,minor) (!HTTP_GREATER_VERSION(version,major,minor))

  typedef enum _HTTP_VERB {
    HttpVerbUnparsed = 0,
    HttpVerbUnknown,HttpVerbInvalid,HttpVerbOPTIONS,HttpVerbGET,HttpVerbHEAD,HttpVerbPOST,HttpVerbPUT,HttpVerbDELETE,
    HttpVerbTRACE,HttpVerbCONNECT,HttpVerbTRACK,HttpVerbMOVE,HttpVerbCOPY,HttpVerbPROPFIND,HttpVerbPROPPATCH,HttpVerbMKCOL,HttpVerbLOCK,
    HttpVerbUNLOCK,HttpVerbSEARCH,HttpVerbMaximum
  } HTTP_VERB,*PHTTP_VERB;

  typedef enum _HTTP_HEADER_ID {
    HttpHeaderCacheControl = 0,HttpHeaderConnection = 1,HttpHeaderDate = 2,HttpHeaderKeepAlive = 3,HttpHeaderPragma = 4,HttpHeaderTrailer = 5,
    HttpHeaderTransferEncoding = 6,HttpHeaderUpgrade = 7,HttpHeaderVia = 8,HttpHeaderWarning = 9,HttpHeaderAllow = 10,HttpHeaderContentLength = 11,
    HttpHeaderContentType = 12,HttpHeaderContentEncoding = 13,HttpHeaderContentLanguage = 14,HttpHeaderContentLocation = 15,HttpHeaderContentMd5 = 16,
    HttpHeaderContentRange = 17,HttpHeaderExpires = 18,HttpHeaderLastModified = 19,HttpHeaderAccept = 20,HttpHeaderAcceptCharset = 21,
    HttpHeaderAcceptEncoding = 22,HttpHeaderAcceptLanguage = 23,HttpHeaderAuthorization = 24,HttpHeaderCookie = 25,HttpHeaderExpect = 26,
    HttpHeaderFrom = 27,HttpHeaderHost = 28,HttpHeaderIfMatch = 29,HttpHeaderIfModifiedSince = 30,HttpHeaderIfNoneMatch = 31,HttpHeaderIfRange = 32,
    HttpHeaderIfUnmodifiedSince = 33,HttpHeaderMaxForwards = 34,HttpHeaderProxyAuthorization = 35,HttpHeaderReferer = 36,HttpHeaderRange = 37,
    HttpHeaderTe = 38,HttpHeaderTranslate = 39,HttpHeaderUserAgent = 40,HttpHeaderRequestMaximum = 41,HttpHeaderAcceptRanges = 20,HttpHeaderAge = 21,
    HttpHeaderEtag = 22,HttpHeaderLocation = 23,HttpHeaderProxyAuthenticate = 24,HttpHeaderRetryAfter = 25,HttpHeaderServer = 26,
    HttpHeaderSetCookie = 27,HttpHeaderVary = 28,HttpHeaderWwwAuthenticate = 29,HttpHeaderResponseMaximum = 30,HttpHeaderMaximum = 41
  } HTTP_HEADER_ID,*PHTTP_HEADER_ID;

  typedef struct _HTTP_KNOWN_HEADER {
    USHORT RawValueLength;
    PCSTR pRawValue;
  } HTTP_KNOWN_HEADER,*PHTTP_KNOWN_HEADER;

  typedef struct _HTTP_UNKNOWN_HEADER {
    USHORT NameLength;
    USHORT RawValueLength;
    PCSTR pName;
    PCSTR pRawValue;
  } HTTP_UNKNOWN_HEADER,*PHTTP_UNKNOWN_HEADER;

  typedef enum _HTTP_DATA_CHUNK_TYPE {
    HttpDataChunkFromMemory = 0,
    HttpDataChunkFromFileHandle,
    HttpDataChunkFromFragmentCache,
    HttpDataChunkFromFragmentCacheEx,
    HttpDataChunkMaximum
  } HTTP_DATA_CHUNK_TYPE,*PHTTP_DATA_CHUNK_TYPE;

  typedef struct _HTTP_DATA_CHUNK {
    HTTP_DATA_CHUNK_TYPE DataChunkType;
    __C89_NAMELESS union {
      struct {
	PVOID pBuffer;
	ULONG BufferLength;
      } FromMemory;
      struct {
	HTTP_BYTE_RANGE ByteRange;
	HANDLE FileHandle;
      } FromFileHandle;
      struct {
	USHORT FragmentNameLength;
	PCWSTR pFragmentName;
      } FromFragmentCache;
    };
  } HTTP_DATA_CHUNK,*PHTTP_DATA_CHUNK;

  typedef struct _HTTP_REQUEST_HEADERS {
    USHORT UnknownHeaderCount;
    PHTTP_UNKNOWN_HEADER pUnknownHeaders;
    USHORT TrailerCount;
    PHTTP_UNKNOWN_HEADER pTrailers;
    HTTP_KNOWN_HEADER KnownHeaders[HttpHeaderRequestMaximum];
  } HTTP_REQUEST_HEADERS,*PHTTP_REQUEST_HEADERS;

  typedef struct _HTTP_RESPONSE_HEADERS {
    USHORT UnknownHeaderCount;
    PHTTP_UNKNOWN_HEADER pUnknownHeaders;
    USHORT TrailerCount;
    PHTTP_UNKNOWN_HEADER pTrailers;
    HTTP_KNOWN_HEADER KnownHeaders[HttpHeaderResponseMaximum];
  } HTTP_RESPONSE_HEADERS,*PHTTP_RESPONSE_HEADERS;

  typedef struct _HTTP_TRANSPORT_ADDRESS {
    PSOCKADDR pRemoteAddress;
    PSOCKADDR pLocalAddress;
  } HTTP_TRANSPORT_ADDRESS,*PHTTP_TRANSPORT_ADDRESS;

  typedef struct _HTTP_COOKED_URL {
    USHORT FullUrlLength;
    USHORT HostLength;
    USHORT AbsPathLength;
    USHORT QueryStringLength;
    PCWSTR pFullUrl;
    PCWSTR pHost;
    PCWSTR pAbsPath;
    PCWSTR pQueryString;
  } HTTP_COOKED_URL,*PHTTP_COOKED_URL;

  typedef ULONGLONG HTTP_URL_CONTEXT;

  typedef struct _HTTP_SSL_CLIENT_CERT_INFO {
    ULONG CertFlags;
    ULONG CertEncodedSize;
    PUCHAR pCertEncoded;
    HANDLE Token;
    BOOLEAN CertDeniedByMapper;
  } HTTP_SSL_CLIENT_CERT_INFO,*PHTTP_SSL_CLIENT_CERT_INFO;

  typedef struct _HTTP_SSL_INFO {
    USHORT ServerCertKeySize;
    USHORT ConnectionKeySize;
    ULONG ServerCertIssuerSize;
    ULONG ServerCertSubjectSize;
    PCSTR pServerCertIssuer;
    PCSTR pServerCertSubject;
    PHTTP_SSL_CLIENT_CERT_INFO pClientCertInfo;
    ULONG SslClientCertNegotiated;
  } HTTP_SSL_INFO,*PHTTP_SSL_INFO;

  typedef struct _HTTP_REQUEST_V1 {
    ULONG Flags;
    HTTP_CONNECTION_ID ConnectionId;
    HTTP_REQUEST_ID RequestId;
    HTTP_URL_CONTEXT UrlContext;
    HTTP_VERSION Version;
    HTTP_VERB Verb;
    USHORT UnknownVerbLength;
    USHORT RawUrlLength;
    PCSTR pUnknownVerb;
    PCSTR pRawUrl;
    HTTP_COOKED_URL CookedUrl;
    HTTP_TRANSPORT_ADDRESS Address;
    HTTP_REQUEST_HEADERS Headers;
    ULONGLONG BytesReceived;
    USHORT EntityChunkCount;
    PHTTP_DATA_CHUNK pEntityChunks;
    HTTP_RAW_CONNECTION_ID RawConnectionId;
    PHTTP_SSL_INFO pSslInfo;
  } HTTP_REQUEST_V1, *PHTTP_REQUEST_V1;

  typedef enum _HTTP_REQUEST_INFO_TYPE {
    HttpRequestInfoTypeAuth = 0
  } HTTP_REQUEST_INFO_TYPE, *PHTTP_REQUEST_INFO_TYPE;

  typedef struct _HTTP_REQUEST_INFO {
    HTTP_REQUEST_INFO_TYPE InfoType;
    ULONG                  InfoLength;
    PVOID                  pInfo;
  } HTTP_REQUEST_INFO, *PHTTP_REQUEST_INFO;

#ifdef __cplusplus
  typedef struct _HTTP_REQUEST_V2 : HTTP_REQUEST_V1 {
    USHORT             RequestInfoCount;
    PHTTP_REQUEST_INFO pRequestInfo;
  } HTTP_REQUEST_V2, *PHTTP_REQUEST_V2;
#else
  typedef struct _HTTP_REQUEST_V2 {
    /* struct HTTP_REQUEST_V1; */
    __C89_NAMELESS struct {
    ULONG Flags;
    HTTP_CONNECTION_ID ConnectionId;
    HTTP_REQUEST_ID RequestId;
    HTTP_URL_CONTEXT UrlContext;
    HTTP_VERSION Version;
    HTTP_VERB Verb;
    USHORT UnknownVerbLength;
    USHORT RawUrlLength;
    PCSTR pUnknownVerb;
    PCSTR pRawUrl;
    HTTP_COOKED_URL CookedUrl;
    HTTP_TRANSPORT_ADDRESS Address;
    HTTP_REQUEST_HEADERS Headers;
    ULONGLONG BytesReceived;
    USHORT EntityChunkCount;
    PHTTP_DATA_CHUNK pEntityChunks;
    HTTP_RAW_CONNECTION_ID RawConnectionId;
    PHTTP_SSL_INFO pSslInfo;
    };
    USHORT             RequestInfoCount;
    PHTTP_REQUEST_INFO pRequestInfo;
  } HTTP_REQUEST_V2, *PHTTP_REQUEST_V2;
#endif

#if (_WIN32_WINNT >= 0x0600)
  typedef HTTP_REQUEST_V2 HTTP_REQUEST, *PHTTP_REQUEST;
#else
  typedef HTTP_REQUEST_V1 HTTP_REQUEST, *PHTTP_REQUEST;
#endif

#define HTTP_REQUEST_FLAG_MORE_ENTITY_BODY_EXISTS 0x00000001

  typedef struct _HTTP_RESPONSE_V1 {
    ULONG Flags;
    HTTP_VERSION Version;
    USHORT StatusCode;
    USHORT ReasonLength;
    PCSTR pReason;
    HTTP_RESPONSE_HEADERS Headers;
    USHORT EntityChunkCount;
    PHTTP_DATA_CHUNK pEntityChunks;
  } HTTP_RESPONSE_V1,*PHTTP_RESPONSE_V1;

  typedef enum _HTTP_RESPONSE_INFO_TYPE {
    HttpResponseInfoTypeMultipleKnownHeaders = 0,
    HttpResponseInfoTypeAuthenticationProperty,
    HttpResponseInfoTypeQosProperty,
    HttpResponseInfoTypeChannelBind 
  } HTTP_RESPONSE_INFO_TYPE, *PHTTP_RESPONSE_INFO_TYPE;

  typedef struct _HTTP_RESPONSE_INFO {
    HTTP_RESPONSE_INFO_TYPE Type;
    ULONG                   Length;
    PVOID                   pInfo;
  } HTTP_RESPONSE_INFO, *PHTTP_RESPONSE_INFO;

#ifdef __cplusplus
  typedef struct _HTTP_RESPONSE_V2 : HTTP_RESPONSE_V1 {
    USHORT              ResponseInfoCount;
    PHTTP_RESPONSE_INFO pResponseInfo;
  } HTTP_RESPONSE_V2, *PHTTP_RESPONSE_V2;
#else
  typedef struct _HTTP_RESPONSE_V2 {
    /* struct HTTP_RESPONSE_V1; */
    __C89_NAMELESS struct {
    ULONG Flags;
    HTTP_VERSION Version;
    USHORT StatusCode;
    USHORT ReasonLength;
    PCSTR pReason;
    HTTP_RESPONSE_HEADERS Headers;
    USHORT EntityChunkCount;
    PHTTP_DATA_CHUNK pEntityChunks;
    };
    USHORT              ResponseInfoCount;
    PHTTP_RESPONSE_INFO pResponseInfo;
  } HTTP_RESPONSE_V2, *PHTTP_RESPONSE_V2;
#endif

#if (_WIN32_WINNT >= 0x0600)
  typedef HTTP_RESPONSE_V2 HTTP_RESPONSE, *PHTTP_RESPONSE;
#else
  typedef HTTP_RESPONSE_V1 HTTP_RESPONSE, *PHTTP_RESPONSE;
#endif /* _WIN32_WINNT >= 0x0600 */

  typedef enum _HTTP_CACHE_POLICY_TYPE {
    HttpCachePolicyNocache = 0,
    HttpCachePolicyUserInvalidates,
    HttpCachePolicyTimeToLive,
    HttpCachePolicyMaximum
  } HTTP_CACHE_POLICY_TYPE,*PHTTP_CACHE_POLICY_TYPE;

  typedef struct _HTTP_CACHE_POLICY {
    HTTP_CACHE_POLICY_TYPE Policy;
    ULONG SecondsToLive;
  } HTTP_CACHE_POLICY, *PHTTP_CACHE_POLICY;

  typedef enum _HTTP_SERVICE_CONFIG_ID {
    HttpServiceConfigIPListenList = 0,
    HttpServiceConfigSSLCertInfo,
    HttpServiceConfigUrlAclInfo,
    HttpServiceConfigMax
  } HTTP_SERVICE_CONFIG_ID, *PHTTP_SERVICE_CONFIG_ID;

  typedef enum _HTTP_SERVICE_CONFIG_QUERY_TYPE {
    HttpServiceConfigQueryExact = 0,
    HttpServiceConfigQueryNext,
    HttpServiceConfigQueryMax
  } HTTP_SERVICE_CONFIG_QUERY_TYPE,*PHTTP_SERVICE_CONFIG_QUERY_TYPE;

  typedef struct _HTTP_SERVICE_CONFIG_SSL_KEY {
    PSOCKADDR pIpPort;
  } HTTP_SERVICE_CONFIG_SSL_KEY,*PHTTP_SERVICE_CONFIG_SSL_KEY;

  typedef struct _HTTP_SERVICE_CONFIG_SSL_PARAM {
    ULONG SslHashLength;
    PVOID pSslHash;
    GUID AppId;
    PWSTR pSslCertStoreName;
    DWORD DefaultCertCheckMode;
    DWORD DefaultRevocationFreshnessTime;
    DWORD DefaultRevocationUrlRetrievalTimeout;
    PWSTR pDefaultSslCtlIdentifier;
    PWSTR pDefaultSslCtlStoreName;
    DWORD DefaultFlags;
  } HTTP_SERVICE_CONFIG_SSL_PARAM,*PHTTP_SERVICE_CONFIG_SSL_PARAM;

#define HTTP_SERVICE_CONFIG_SSL_FLAG_USE_DS_MAPPER 0x00000001
#define HTTP_SERVICE_CONFIG_SSL_FLAG_NEGOTIATE_CLIENT_CERT 0x00000002
#define HTTP_SERVICE_CONFIG_SSL_FLAG_NO_RAW_FILTER 0x00000004

  typedef struct _HTTP_SERVICE_CONFIG_SSL_SET {
    HTTP_SERVICE_CONFIG_SSL_KEY KeyDesc;
    HTTP_SERVICE_CONFIG_SSL_PARAM ParamDesc;
  } HTTP_SERVICE_CONFIG_SSL_SET,*PHTTP_SERVICE_CONFIG_SSL_SET;

  typedef struct _HTTP_SERVICE_CONFIG_SSL_QUERY {
    HTTP_SERVICE_CONFIG_QUERY_TYPE QueryDesc;
    HTTP_SERVICE_CONFIG_SSL_KEY KeyDesc;
    DWORD dwToken;
  } HTTP_SERVICE_CONFIG_SSL_QUERY,*PHTTP_SERVICE_CONFIG_SSL_QUERY;

  typedef struct _HTTP_SERVICE_CONFIG_IP_LISTEN_PARAM {
    USHORT AddrLength;
    PSOCKADDR pAddress;
  } HTTP_SERVICE_CONFIG_IP_LISTEN_PARAM,*PHTTP_SERVICE_CONFIG_IP_LISTEN_PARAM;

  typedef struct _HTTP_SERVICE_CONFIG_IP_LISTEN_QUERY {
    ULONG AddrCount;
    SOCKADDR_STORAGE AddrList[ANYSIZE_ARRAY];
  } HTTP_SERVICE_CONFIG_IP_LISTEN_QUERY,*PHTTP_SERVICE_CONFIG_IP_LISTEN_QUERY;

  typedef struct _HTTP_SERVICE_CONFIG_URLACL_KEY {
    PWSTR pUrlPrefix;
  } HTTP_SERVICE_CONFIG_URLACL_KEY,*PHTTP_SERVICE_CONFIG_URLACL_KEY;

  typedef struct _HTTP_SERVICE_CONFIG_URLACL_PARAM {
    PWSTR pStringSecurityDescriptor;
  } HTTP_SERVICE_CONFIG_URLACL_PARAM,*PHTTP_SERVICE_CONFIG_URLACL_PARAM;

  typedef struct _HTTP_SERVICE_CONFIG_URLACL_SET {
    HTTP_SERVICE_CONFIG_URLACL_KEY KeyDesc;
    HTTP_SERVICE_CONFIG_URLACL_PARAM ParamDesc;
  } HTTP_SERVICE_CONFIG_URLACL_SET,*PHTTP_SERVICE_CONFIG_URLACL_SET;

  typedef struct _HTTP_SERVICE_CONFIG_URLACL_QUERY {
    HTTP_SERVICE_CONFIG_QUERY_TYPE QueryDesc;
    HTTP_SERVICE_CONFIG_URLACL_KEY KeyDesc;
    DWORD dwToken;
  } HTTP_SERVICE_CONFIG_URLACL_QUERY,*PHTTP_SERVICE_CONFIG_URLACL_QUERY;

#if !defined(HTTPAPI_LINKAGE)
#ifdef HTTPAPI_LINKAGE_EXPORT
#define DECLSPEC_EXPORT __declspec(dllexport)
#define HTTPAPI_LINKAGE DECLSPEC_EXPORT
#else
#define HTTPAPI_LINKAGE DECLSPEC_IMPORT
#endif
#endif

  typedef struct _HTTPAPI_VERSION {
    USHORT HttpApiMajorVersion;
    USHORT HttpApiMinorVersion;
  } HTTPAPI_VERSION,*PHTTPAPI_VERSION;

#define HTTPAPI_VERSION_1 {1,0}

  HTTPAPI_LINKAGE ULONG WINAPI HttpInitialize(HTTPAPI_VERSION Version,ULONG Flags,PVOID pReserved);
  HTTPAPI_LINKAGE ULONG WINAPI HttpTerminate(ULONG Flags,PVOID pReserved);
  HTTPAPI_LINKAGE ULONG WINAPI HttpCreateHttpHandle(PHANDLE pReqQueueHandle,ULONG Options);
  HTTPAPI_LINKAGE ULONG WINAPI HttpReceiveClientCertificate(HANDLE ReqQueueHandle,HTTP_CONNECTION_ID ConnectionId,ULONG Flags,PHTTP_SSL_CLIENT_CERT_INFO pSslClientCertInfo,ULONG SslClientCertInfoSize,PULONG pBytesReceived,LPOVERLAPPED pOverlapped);
  HTTPAPI_LINKAGE ULONG WINAPI HttpAddUrl(HANDLE ReqQueueHandle,PCWSTR pUrlPrefix,PVOID pReserved);
  HTTPAPI_LINKAGE ULONG WINAPI HttpRemoveUrl(HANDLE ReqQueueHandle,PCWSTR pUrlPrefix);
  HTTPAPI_LINKAGE ULONG WINAPI HttpReceiveHttpRequest(HANDLE ReqQueueHandle,HTTP_REQUEST_ID RequestId,ULONG Flags,PHTTP_REQUEST pRequestBuffer,ULONG RequestBufferLength,PULONG pBytesReceived,LPOVERLAPPED pOverlapped);
  HTTPAPI_LINKAGE ULONG WINAPI HttpReceiveRequestEntityBody(HANDLE ReqQueueHandle,HTTP_REQUEST_ID RequestId,ULONG Flags,PVOID pBuffer,ULONG BufferLength,PULONG pBytesReceived,LPOVERLAPPED pOverlapped);
  HTTPAPI_LINKAGE ULONG WINAPI HttpSendHttpResponse(HANDLE ReqQueueHandle,HTTP_REQUEST_ID RequestId,ULONG Flags,PHTTP_RESPONSE pHttpResponse,PVOID pReserved1,PULONG pBytesSent,PVOID pReserved2,ULONG Reserved3,LPOVERLAPPED pOverlapped,PVOID pReserved4);
  HTTPAPI_LINKAGE ULONG WINAPI HttpSendResponseEntityBody(HANDLE ReqQueueHandle,HTTP_REQUEST_ID RequestId,ULONG Flags,USHORT EntityChunkCount,PHTTP_DATA_CHUNK pEntityChunks,PULONG pBytesSent,PVOID pReserved1,ULONG Reserved2,LPOVERLAPPED pOverlapped,PVOID pReserved3);
  HTTPAPI_LINKAGE ULONG WINAPI HttpWaitForDisconnect(HANDLE ReqQueueHandle,HTTP_CONNECTION_ID ConnectionId,LPOVERLAPPED pOverlapped);
  HTTPAPI_LINKAGE ULONG WINAPI HttpFlushResponseCache(HANDLE ReqQueueHandle,PCWSTR pUrlPrefix,ULONG Flags,LPOVERLAPPED pOverlapped);
  HTTPAPI_LINKAGE ULONG WINAPI HttpAddFragmentToCache(HANDLE ReqQueueHandle,PCWSTR pUrlPrefix,PHTTP_DATA_CHUNK pDataChunk,PHTTP_CACHE_POLICY pCachePolicy,LPOVERLAPPED pOverlapped);
  HTTPAPI_LINKAGE ULONG WINAPI HttpReadFragmentFromCache(HANDLE ReqQueueHandle,PCWSTR pUrlPrefix,PHTTP_BYTE_RANGE pByteRange,PVOID pBuffer,ULONG BufferLength,PULONG pBytesRead,LPOVERLAPPED pOverlapped);
  HTTPAPI_LINKAGE ULONG WINAPI HttpSetServiceConfiguration(HANDLE ServiceHandle,HTTP_SERVICE_CONFIG_ID ConfigId,PVOID pConfigInformation,ULONG ConfigInformationLength,LPOVERLAPPED pOverlapped);
  HTTPAPI_LINKAGE ULONG WINAPI HttpDeleteServiceConfiguration(HANDLE ServiceHandle,HTTP_SERVICE_CONFIG_ID ConfigId,PVOID pConfigInformation,ULONG ConfigInformationLength,LPOVERLAPPED pOverlapped);
  HTTPAPI_LINKAGE ULONG WINAPI HttpQueryServiceConfiguration(HANDLE ServiceHandle,HTTP_SERVICE_CONFIG_ID ConfigId,PVOID pInputConfigInformation,ULONG InputConfigInformationLength,PVOID pOutputConfigInformation,ULONG OutputConfigInformationLength,PULONG pReturnLength,LPOVERLAPPED pOverlapped);

#if (_WIN32_WINNT >= 0x0600)
#define HTTP_VERSION_2_0	{ 2, 0 }
#define HTTPAPI_VERSION_2	{ 2, 0 }

  typedef enum _HTTP_503_RESPONSE_VERBOSITY {
    Http503ResponseVerbosityBasic = 0,
    Http503ResponseVerbosityLimited,
    Http503ResponseVerbosityFull
  } HTTP_503_RESPONSE_VERBOSITY, *PHTTP_503_RESPONSE_VERBOSITY;

  typedef enum _HTTP_ENABLED_STATE {
    HttpEnabledStateActive = 0,
    HttpEnabledStateInactive
  } HTTP_ENABLED_STATE, *PHTTP_ENABLED_STATE;

  typedef enum _HTTP_LOGGING_ROLLOVER_TYPE {
    HttpLoggingRolloverSize = 0,
    HttpLoggingRolloverDaily,
    HttpLoggingRolloverWeekly,
    HttpLoggingRolloverMonthly,
    HttpLoggingRolloverHourly
  } HTTP_LOGGING_ROLLOVER_TYPE, *PHTTP_LOGGING_ROLLOVER_TYPE;

  typedef enum _HTTP_LOGGING_TYPE {
    HttpLoggingTypeW3C = 0,
    HttpLoggingTypeIIS,
    HttpLoggingTypeNCSA,
    HttpLoggingTypeRaw
  } HTTP_LOGGING_TYPE, *PHTTP_LOGGING_TYPE;

  typedef enum _HTTP_QOS_SETTING_TYPE {
    HttpQosSettingTypeBandwidth = 0,
    HttpQosSettingTypeConnectionLimit,
    HttpQosSettingTypeFlowRate
  } HTTP_QOS_SETTING_TYPE, *PHTTP_QOS_SETTING_TYPE;

  typedef enum _HTTP_SERVER_PROPERTY {
    HttpServerAuthenticationProperty = 0,
    HttpServerLoggingProperty,
    HttpServerQosProperty,
    HttpServerTimeoutsProperty,
    HttpServerQueueLengthProperty,
    HttpServerStateProperty,
    HttpServer503VerbosityProperty,
    HttpServerBindingProperty,
    HttpServerExtendedAuthenticationProperty,
    HttpServerListenEndpointProperty,
    HttpServerChannelBindProperty
  } HTTP_SERVER_PROPERTY, *PHTTP_SERVER_PROPERTY;

  typedef enum _HTTP_AUTHENTICATION_HARDENING_LEVELS {
    HttpAuthenticationHardeningLegacy   = 0,
    HttpAuthenticationHardeningMedium   = 1,
    HttpAuthenticationHardeningStrict   = 2
  } HTTP_AUTHENTICATION_HARDENING_LEVELS;

  typedef enum _HTTP_SERVICE_BINDING_TYPE {
    HttpServiceBindingTypeNone   = 0,
    HttpServiceBindingTypeW      = 1,
    HttpServiceBindingTypeA      = 2
  } HTTP_SERVICE_BINDING_TYPE;

  typedef enum _HTTP_LOG_DATA_TYPE {
    HttpLogDataTypeFields   = 0
  } HTTP_LOG_DATA_TYPE, *PHTTP_LOG_DATA_TYPE;

  typedef struct _HTTP_LOG_DATA {
    HTTP_LOG_DATA_TYPE Type;
  } HTTP_LOG_DATA, *PHTTP_LOG_DATA;

  typedef enum _HTTP_REQUEST_AUTH_TYPE {
    HttpRequestAuthTypeNone = 0,
    HttpRequestAuthTypeBasic,
    HttpRequestAuthTypeDigest,
    HttpRequestAuthTypeNTLM,
    HttpRequestAuthTypeNegotiate,
    HttpRequestAuthTypeKerberos
  } HTTP_REQUEST_AUTH_TYPE, *PHTTP_REQUEST_AUTH_TYPE;

  typedef enum _HTTP_AUTH_STATUS {
    HttpAuthStatusSuccess = 0,
    HttpAuthStatusNotAuthenticated,
    HttpAuthStatusFailure
  } HTTP_AUTH_STATUS, *PHTTP_AUTH_STATUS;

  typedef enum _HTTP_SERVICE_CONFIG_TIMEOUT_KEY {
    IdleConnectionTimeout = 0,
    HeaderWaitTimeout
  } HTTP_SERVICE_CONFIG_TIMEOUT_KEY, *PHTTP_SERVICE_CONFIG_TIMEOUT_KEY;

  typedef USHORT HTTP_SERVICE_CONFIG_TIMEOUT_PARAM, *PHTTP_SERVICE_CONFIG_TIMEOUT_PARAM;

  typedef struct _HTTP_PROPERTY_FLAGS {
    ULONG Present:1;
  } HTTP_PROPERTY_FLAGS, *PHTTP_PROPERTY_FLAGS;

  typedef struct _HTTP_CONNECTION_LIMIT_INFO {
    HTTP_PROPERTY_FLAGS Flags;
    ULONG               MaxConnections;
  } HTTP_CONNECTION_LIMIT_INFO, *PHTTP_CONNECTION_LIMIT_INFO;

  typedef struct _HTTP_STATE_INFO {
    HTTP_PROPERTY_FLAGS Flags;
    HTTP_ENABLED_STATE  State;
  } HTTP_STATE_INFO, *PHTTP_STATE_INFO;

  typedef struct _HTTP_QOS_SETTING_INFO {
    HTTP_QOS_SETTING_TYPE  QosType;
    PVOID               QosSetting;
  } HTTP_QOS_SETTING_INFO, *PHTTP_QOS_SETTING_INFO;

  typedef struct _HTTP_SERVER_AUTHENTICATION_DIGEST_PARAMS {
    USHORT DomainNameLength;
    PWSTR  DomainName;
    USHORT RealmLength;
    PWSTR  Realm;
  } HTTP_SERVER_AUTHENTICATION_DIGEST_PARAMS, *PHTTP_SERVER_AUTHENTICATION_DIGEST_PARAMS;

  typedef struct _HTTP_SERVER_AUTHENTICATION_BASIC_PARAMS {
    USHORT RealmLength;
    PWSTR  Realm;
  } HTTP_SERVER_AUTHENTICATION_BASIC_PARAMS, *PHTTP_SERVER_AUTHENTICATION_BASIC_PARAMS;

  typedef struct _HTTP_SERVER_AUTHENTICATION_INFO {
    HTTP_PROPERTY_FLAGS                      Flags;
    ULONG                                    AuthSchemes;
    BOOLEAN                                  ReceiveMutualAuth;
    BOOLEAN                                  ReceiveContextHandle;
    BOOLEAN                                  DisableNTLMCredentialCaching;
    UCHAR                                    ExFlags;
    HTTP_SERVER_AUTHENTICATION_DIGEST_PARAMS DigestParams;
    HTTP_SERVER_AUTHENTICATION_BASIC_PARAMS  BasicParams;
  } HTTP_SERVER_AUTHENTICATION_INFO, *PHTTP_SERVER_AUTHENTICATION_INFO;

  typedef struct _HTTP_LOGGING_INFO {
    HTTP_PROPERTY_FLAGS        Flags;
    ULONG                      LoggingFlags;
    PCWSTR                     SoftwareName;
    USHORT                     SoftwareNameLength;
    USHORT                     DirectoryNameLength;
    PCWSTR                     DirectoryName;
    HTTP_LOGGING_TYPE          Format;
    ULONG                      Fields;
    PVOID                      pExtFields;
    USHORT                     NumOfExtFields;
    USHORT                     MaxRecordSize;
    HTTP_LOGGING_ROLLOVER_TYPE RolloverType;
    ULONG                      RolloverSize;
    PSECURITY_DESCRIPTOR       pSecurityDescriptor;
  } HTTP_LOGGING_INFO, *PHTTP_LOGGING_INFO;

  typedef struct _HTTP_TIMEOUT_LIMIT_INFO {
    HTTP_PROPERTY_FLAGS Flags;
    USHORT              EntityBody;
    USHORT              DrainEntityBody;
    USHORT              RequestQueue;
    USHORT              IdleConnection;
    USHORT              HeaderWait;
    ULONG               MinSendRate;
  } HTTP_TIMEOUT_LIMIT_INFO, *PHTTP_TIMEOUT_LIMIT_INFO;

  typedef struct _HTTP_SERVICE_BINDING_BASE {
    HTTP_SERVICE_BINDING_TYPE Type;
  } HTTP_SERVICE_BINDING_BASE, *PHTTP_SERVICE_BINDING_BASE;

  typedef struct _HTTP_CHANNEL_BIND_INFO {
    HTTP_AUTHENTICATION_HARDENING_LEVELS Hardening;
    ULONG                                Flags;
    PHTTP_SERVICE_BINDING_BASE           *ServiceNames;
    ULONG                                NumberOfServiceNames;
  } HTTP_CHANNEL_BIND_INFO, *PHTTP_CHANNEL_BIND_INFO;

  typedef struct _HTTP_REQUEST_CHANNEL_BIND_STATUS {
    PHTTP_SERVICE_BINDING_BASE ServiceName;
    PUCHAR                     ChannelToken;
    ULONG                      ChannelTokenSize;
    ULONG                      Flags;
  } HTTP_REQUEST_CHANNEL_BIND_STATUS, *PHTTP_REQUEST_CHANNEL_BIND_STATUS;

  typedef struct _HTTP_SERVICE_BINDING_A {
    HTTP_SERVICE_BINDING_BASE Base;
    PCHAR                     Buffer;
    ULONG                     BufferSize;
  } HTTP_SERVICE_BINDING_A, *PHTTP_SERVICE_BINDING_A;

  typedef struct _HTTP_SERVICE_BINDING_W {
    HTTP_SERVICE_BINDING_BASE Base;
    PWCHAR                    Buffer;
    ULONG                     BufferSize;
  } HTTP_SERVICE_BINDING_W, *PHTTP_SERVICE_BINDING_W;

  /* TODO: Is there the abstract unicode type HTTP_SERVICE_BINDING present, too? */

  typedef struct _HTTP_LOG_FIELDS_DATA {
    HTTP_LOG_DATA Base;
    USHORT        UserNameLength;
    USHORT        UriStemLength;
    USHORT        ClientIpLength;
    USHORT        ServerNameLength;
    USHORT        ServerIpLength;
    USHORT        MethodLength;
    USHORT        UriQueryLength;
    USHORT        HostLength;
    USHORT        UserAgentLength;
    USHORT        CookieLength;
    USHORT        ReferrerLength;
    PWCHAR        UserName;
    PWCHAR        UriStem;
    PCHAR         ClientIp;
    PCHAR         ServerName;
    PCHAR         ServiceName;
    PCHAR         ServerIp;
    PCHAR         Method;
    PCHAR         UriQuery;
    PCHAR         Host;
    PCHAR         UserAgent;
    PCHAR         Cookie;
    PCHAR         Referrer;
    USHORT        ServerPort;
    USHORT        ProtocolStatus;
    ULONG         Win32Status;
    HTTP_VERB     MethodNum;
    USHORT        SubStatus;
  } HTTP_LOG_FIELDS_DATA, *PHTTP_LOG_FIELDS_DATA;

  typedef struct _HTTP_REQUEST_AUTH_INFO {
    HTTP_AUTH_STATUS       AuthStatus;
    SECURITY_STATUS        SecStatus;
    ULONG                  Flags;
    HTTP_REQUEST_AUTH_TYPE AuthType;
    HANDLE                 AccessToken;
    ULONG                  ContextAttributes;
    ULONG                  PackedContextLength;
    ULONG                  PackedContextType;
    PVOID                  PackedContext;
    ULONG                  MutualAuthDataLength;
    PCHAR                  pMutualAuthData;
  } HTTP_REQUEST_AUTH_INFO, *PHTTP_REQUEST_AUTH_INFO;

  typedef struct _HTTP_MULTIPLE_KNOWN_HEADERS {
    HTTP_HEADER_ID     HeaderId;
    ULONG              Flags;
    USHORT             KnownHeaderCount;
    PHTTP_KNOWN_HEADER KnownHeaders;
  } HTTP_MULTIPLE_KNOWN_HEADERS, *PHTTP_MULTIPLE_KNOWN_HEADERS;

  typedef struct _HTTP_SERVICE_CONFIG_TIMEOUT_SET {
    HTTP_SERVICE_CONFIG_TIMEOUT_KEY   KeyDesc;
    HTTP_SERVICE_CONFIG_TIMEOUT_PARAM ParamDesc;
  } HTTP_SERVICE_CONFIG_TIMEOUT_SET, *PHTTP_SERVICE_CONFIG_TIMEOUT_SET;

  typedef struct _HTTP_BANDWIDTH_LIMIT_INFO {
    HTTP_PROPERTY_FLAGS Flags;
    ULONG               MaxBandwidth;
  } HTTP_BANDWIDTH_LIMIT_INFO, *PHTTP_BANDWIDTH_LIMIT_INFO;

  typedef struct _HTTP_BINDING_INFO {
    HTTP_PROPERTY_FLAGS Flags;
    HANDLE              RequestQueueHandle;
  } HTTP_BINDING_INFO, *PHTTP_BINDING_INFO;

  typedef struct _HTTP_LISTEN_ENDPOINT_INFO {
    HTTP_PROPERTY_FLAGS Flags;
    BOOLEAN             EnableSharing;
  } HTTP_LISTEN_ENDPOINT_INFO, *PHTTP_LISTEN_ENDPOINT_INFO;

  HTTPAPI_LINKAGE ULONG WINAPI HttpSetRequestQueueProperty(HANDLE Handle,HTTP_SERVER_PROPERTY Property,PVOID pPropertyInformation,ULONG PropertyInformationLength,ULONG Reserved,PVOID pReserved);
  HTTPAPI_LINKAGE ULONG WINAPI HttpQueryRequestQueueProperty(HANDLE Handle,HTTP_SERVER_PROPERTY Property,PVOID pPropertyInformation,ULONG PropertyInformationLength,ULONG Reserved,PULONG pReturnLength,PVOID pReserved);
  HTTPAPI_LINKAGE ULONG WINAPI HttpCreateRequestQueue(HTTPAPI_VERSION Version,PCWSTR pName,PSECURITY_ATTRIBUTES pSecurityAttributes,ULONG Flags,PHANDLE pReqQueueHandle);
  HTTPAPI_LINKAGE ULONG WINAPI HttpAddUrlToUrlGroup(HTTP_URL_GROUP_ID UrlGroupId,PCWSTR pFullyQualifiedUrl,HTTP_URL_CONTEXT UrlContext,ULONG Reserved);
  HTTPAPI_LINKAGE ULONG WINAPI HttpCancelHttpRequest(HANDLE ReqQueueHandle,HTTP_REQUEST_ID RequestId,LPOVERLAPPED pOverlapped);
  HTTPAPI_LINKAGE ULONG WINAPI HttpCloseRequestQueue(HANDLE ReqQueueHandle);
  HTTPAPI_LINKAGE ULONG WINAPI HttpCloseServerSession(HTTP_SERVER_SESSION_ID ServerSessionId);
  HTTPAPI_LINKAGE ULONG WINAPI HttpCloseUrlGroup(HTTP_URL_GROUP_ID UrlGroupId);
  HTTPAPI_LINKAGE ULONG WINAPI HttpCreateServerSession(HTTPAPI_VERSION Version,PHTTP_SERVER_SESSION_ID pServerSessionId,ULONG Reserved);
  HTTPAPI_LINKAGE ULONG WINAPI HttpCreateUrlGroup(HTTP_SERVER_SESSION_ID ServerSessionId,PHTTP_URL_GROUP_ID pUrlGroupId,ULONG Reserved);
  HTTPAPI_LINKAGE ULONG WINAPI HttpQueryServerSessionProperty(HTTP_SERVER_SESSION_ID ServerSessionId,HTTP_SERVER_PROPERTY Property,PVOID pPropertyInformation,ULONG PropertyInformationLength,PULONG pReturnLength);
  HTTPAPI_LINKAGE ULONG WINAPI HttpQueryUrlGroupProperty(HTTP_URL_GROUP_ID UrlGroupId,HTTP_SERVER_PROPERTY Property,PVOID pPropertyInformation,ULONG PropertyInformationLength,PULONG pReturnLength);
  HTTPAPI_LINKAGE ULONG WINAPI HttpRemoveUrlFromUrlGroup(HTTP_URL_GROUP_ID UrlGroupId,PCWSTR pFullyQualifiedUrl,ULONG Flags);
  HTTPAPI_LINKAGE ULONG WINAPI HttpSetServerSessionProperty(HTTP_SERVER_SESSION_ID ServerSessionId,HTTP_SERVER_PROPERTY Property,PVOID pPropertyInformation,ULONG PropertyInformationLength);
  HTTPAPI_LINKAGE ULONG WINAPI HttpSetUrlGroupProperty(HTTP_URL_GROUP_ID UrlGroupId,HTTP_SERVER_PROPERTY Property,PVOID pPropertyInformation,ULONG PropertyInformationLength);
  HTTPAPI_LINKAGE ULONG WINAPI HttpShutdownRequestQueue(HANDLE ReqQueueHandle);
  HTTPAPI_LINKAGE ULONG WINAPI HttpWaitForDemandStart(HANDLE ReqQueueHandle,LPOVERLAPPED pOverlapped);

#if (_WIN32_WINNT >= 0x0601)
  typedef ULONG HTTP_SERVICE_CONFIG_CACHE_PARAM;

  typedef enum _HTTP_SERVICE_CONFIG_CACHE_KEY {
    MaxCacheResponseSize  = 0,
    CacheRangeChunkSize
  } HTTP_SERVICE_CONFIG_CACHE_KEY;

  typedef struct _HTTP_FLOWRATE_INFO {
    HTTP_PROPERTY_FLAGS  Flags;
    ULONG                MaxBandwidth;
    ULONG                MaxPeakBandwidth;
    ULONG                BurstSize;
  } HTTP_FLOWRATE_INFO, *PHTTP_FLOWRATE_INFO;

typedef struct _HTTP_SERVICE_CONFIG_CACHE_SET {
  HTTP_SERVICE_CONFIG_CACHE_KEY KeyDesc;
  HTTP_SERVICE_CONFIG_CACHE_PARAM ParamDesc;
} HTTP_SERVICE_CONFIG_CACHE_SET, *PHTTP_SERVICE_CONFIG_CACHE_SET;

#endif /*(_WIN32_WINNT >= 0x0601)*/

#endif /*(_WIN32_WINNT >= 0x0600)*/

#ifdef __cplusplus
}
#endif

#endif /* __HTTP_H__ */
