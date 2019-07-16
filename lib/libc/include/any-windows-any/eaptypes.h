/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_EAPTYPES
#define _INC_EAPTYPES

#ifdef __cplusplus
extern "C" {
#endif


typedef DWORD EAP_SESSIONID;
typedef void* EAP_SESSION_HANDLE;

#define EAP_FLAG_Reserved1 0x00000001
#define EAP_FLAG_NON_INTERACTIVE 0x00000002
#define EAP_FLAG_LOGON 0x00000004
#define EAP_FLAG_PREVIEW 0x00000008
#define EAP_FLAG_Reserved2 0x00000010
#define EAP_FLAG_MACHINE_AUTH 0x00000020
#define EAP_FLAG_GUEST_ACCESS 0x00000040
#define EAP_FLAG_Reserved3 0x00000080
#define EAP_FLAG_Reserved4 0x00000100
#define EAP_FLAG_RESUME_FROM_HIBERNATE 0x00000200
#define EAP_FLAG_Reserved5 0x00000400
#define EAP_FLAG_Reserved6 0x00000800
#define EAP_FLAG_FULL_AUTH 0x00001000
#define EAP_FLAG_PREFER_ALT_CREDENTIALS 0x00002000
#define EAP_FLAG_Reserved7 0x00004000
#define EAP_PEER_FLAG_HEALTH_STATE_CHANGE 0x00008000
#define EAP_FLAG_SUPRESS_UI 0x00010000
#define EAP_FLAG_PRE_LOGON 0x00020000
#define EAP_FLAG_USER_AUTH 0x00040000
#define EAP_FLAG_CONFG_READONLY 0x00080000
#define EAP_FLAG_Reserved8 0x00100000

typedef enum _EAP_ATTRIBUTE_TYPE {
  eatMinimum                  = 0,
  eatUserName                 = 1,
  eatUserPassword             = 2,
  eatMD5CHAPPassword          = 3,
  eatNASIPAddress             = 4,
  eatNASport                  = 5,
  eatServiceType              = 6,
  eatFramedProtocol           = 7,
  eatFramedIPAddress          = 8,
  eatFramedIPNetmask          = 9,
  eatFramedRouting            = 10,
  eatFilterId                 = 11,
  eatFramedMTU                = 12,
  eatFramedCompression        = 13,
  eatLoginIPHost              = 14,
  eatLoginService             = 15,
  eatLoginTCPPort             = 16,
  eatUnassigned17             = 17,
  eatReplyMessage             = 18,
  eatCallbackNumber           = 19,
  eatCallbackId               = 20,
  eatUnassigned21             = 21,
  eatFramedRoute              = 22,
  eatFramedIPXNetwork         = 23,
  eatState                    = 24,
  eatClass                    = 25,
  eatVendorSpecific           = 26,
  eatSessionTimeout           = 27,
  eatIdleTimeout              = 28,
  eatTerminationAction        = 29,
  eatCalledStationId          = 30,
  eatCallingStationId         = 31,
  eatNASIdentifier            = 32,
  eatProxyState               = 33,
  eatLoginLATService          = 34,
  eatLoginLATNode             = 35,
  eatLoginLATGroup            = 36,
  eatFramedAppleTalkLink      = 37,
  eatFramedAppleTalkNetwork   = 38,
  eatFramedAppleTalkZone      = 39,
  eatAcctStatusType           = 40,
  eatAcctDelayTime            = 41,
  eatAcctInputOctets          = 42,
  eatAcctOutputOctets         = 43,
  eatAcctSessionId            = 44,
  eatAcctAuthentic            = 45,
  eatAcctSessionTime          = 46,
  eatAcctInputPackets         = 47,
  eatAcctOutputPackets        = 48,
  eatAcctTerminateCause       = 49,
  eatAcctMultiSessionId       = 50,
  eatAcctLinkCount            = 51,
  eatAcctEventTimeStamp       = 55,
  eatMD5CHAPChallenge         = 60,
  eatNASPortType              = 61,
  eatPortLimit                = 62,
  eatLoginLATPort             = 63,
  eatTunnelType               = 64,
  eatTunnelMediumType         = 65,
  eatTunnelClientEndpoint     = 66,
  eatTunnelServerEndpoint     = 67,
  eatARAPPassword             = 70,
  eatARAPFeatures             = 71,
  eatARAPZoneAccess           = 72,
  eatARAPSecurity             = 73,
  eatARAPSecurityData         = 74,
  eatPasswordRetry            = 75,
  eatPrompt                   = 76,
  eatConnectInfo              = 77,
  eatConfigurationToken       = 78,
  eatEAPMessage               = 79,
  eatSignature                = 80,
  eatARAPChallengeResponse    = 84,
  eatAcctInterimInterval      = 85,
  eatNASIPv6Address           = 95,
  eatFramedInterfaceId        = 96,
  eatFramedIPv6Prefix         = 97,
  eatLoginIPv6Host            = 98,
  eatFramedIPv6Route          = 99,
  eatFramedIPv6Pool           = 100,
  eatARAPGuestLogon           = 8096,
  eatCertificateOID           = 8097,
  eatEAPConfiguration         = 8098,
  eatPEAPEmbeddedEAPTypeId    = 8099,
  eatPEAPFastRoamedSession    = 8100,
  eatEAPTLV                   = 8102,
  eatCredentialsChanged       = 8103,
  eatInnerEapMethodType       = 8104,
  eatClearTextPassword        = 8107,
  eatQuarantineSoH            = 8150,
  eatPeerId                   = 9000,
  eatServerId                 = 9001,
  eatMethodId                 = 9002,
  eatEMSK                     = 9003,
  eatSessionId                = 9004,
  eatReserved                 = 0xFFFFFFFF 
} EAP_ATTRIBUTE_TYPE, EapAttributeType;

typedef struct _EAP_ATTRIBUTE {
  EAP_ATTRIBUTE_TYPE eapType;
  DWORD              dwLength;
  BYTE *             pValue;
} EAP_ATTRIBUTE, EapAttribute;

typedef struct _EAP_ATTRIBUTES {
  DWORD         dwNumberOfAttributes;
  EAP_ATTRIBUTE *pAttribs;
} EAP_ATTRIBUTES, EapAttributes;

typedef struct _EAP_TYPE {
  BYTE  type;
  DWORD dwVendorId;
  DWORD dwVendorType;
} EAP_TYPE;

typedef struct _EAP_METHOD_TYPE {
  EAP_TYPE eapType;
  DWORD    dwAuthorId;
} EAP_METHOD_TYPE;

typedef struct _EAP_ERROR {
  DWORD           dwWinError;
  EAP_METHOD_TYPE type;
  DWORD           dwReasonCode;
  GUID            rootCauseGuid;
  GUID            repairGuid;
  GUID            helpLinkGuid;
  LPWSTR          pRootCauseString;
  LPWSTR          pRepairString;
} EAP_ERROR;

typedef enum _EAP_CONFIG_INPUT_FIELD_TYPE {
  EapConfigInputUsername = 0,
  EapConfigInputPassword,
  EapConfigInputNetworkUsername,
  EapConfigInputNetworkPassword,
  EapConfigInputPin,
  EapConfigInputPSK,
  EapConfigInputEdit,
  EapConfigSmartCardUsername,
  EapConfigSmartCardError 
} EAP_CONFIG_INPUT_FIELD_TYPE;

typedef enum _EAP_INTERACTIVE_UI_DATA_TYPE {
  EapCredReq,
  EapCredResp,
  EapCredExpiryReq,
  EapCredExpiryResp 
} EAP_INTERACTIVE_UI_DATA_TYPE;

#define EAP_UI_INPUT_FIELD_PROPS_DEFAULT 0x00000000
#define EAP_CONFIG_INPUT_FIELD_PROPS_DEFAULT 0x00000000
#define EAP_UI_INPUT_FIELD_PROPS_NON_DISPLAYABLE 0x00000001
#define EAP_CONFIG_INPUT_FIELD_PROPS_NON_DISPLAYABLE 0x00000001
#define EAP_UI_INPUT_FIELD_PROPS_NON_PERSIST 0x00000002
#define EAP_CONFIG_INPUT_FIELD_PROPS_NON_PERSIST 0x00000002
#define EAP_UI_INPUT_FIELD_PROPS_READ_ONLY 0x00000004

#define MAX_EAP_CONFIG_INPUT_FIELD_LENGTH 256

#define MAX_EAP_CONFIG_INPUT_FIELD_VALUE_LENGTH 1024

typedef struct _EAP_CONFIG_INPUT_FIELD_DATA {
  DWORD                       dwSize;
  EAP_CONFIG_INPUT_FIELD_TYPE Type;
  DWORD                       dwFlagProps;
  LPWSTR                      pwszLabel;
  LPWSTR                      pwszData;
  DWORD                       dwMinDataLength;
  DWORD                       dwMaxDataLength;
} EAP_CONFIG_INPUT_FIELD_DATA, *PEAP_CONFIG_INPUT_FIELD_DATA;

#define EAP_CREDENTIAL_VERSION 1

typedef struct _EAP_CONFIG_INPUT_FIELD_ARRAY {
  DWORD                       dwVersion;
  DWORD                       dwNumberOfFields;
  DWORD                       dwSize;
  EAP_CONFIG_INPUT_FIELD_DATA *pFields;
} EAP_CONFIG_INPUT_FIELD_ARRAY, *PEAP_CONFIG_INPUT_FIELD_ARRAY;

typedef EAP_CONFIG_INPUT_FIELD_ARRAY EAP_CRED_REQ;
typedef EAP_CONFIG_INPUT_FIELD_ARRAY EAP_CRED_RESP;
typedef struct _EAP_CRED_EXPIRY_REQ EAP_CRED_EXPIRY_REQ;

typedef union _EAP_UI_DATA_FORMAT {
  EAP_CRED_REQ *      credData;
  EAP_CRED_EXPIRY_REQ *credExpiryData;
} EAP_UI_DATA_FORMAT;

typedef struct _EAP_INTERACTIVE_UI_DATA {
  DWORD                        dwVersion;
  DWORD                        dwSize;
  EAP_INTERACTIVE_UI_DATA_TYPE dwDataType;
  DWORD                        cbUiData;
  EAP_UI_DATA_FORMAT           pbUiData;
} EAP_INTERACTIVE_UI_DATA;

#define eapPropCipherSuiteNegotiation 0x00000001
#define eapPropMutualAuth 0x00000002
#define eapPropIntegrity 0x00000004
#define eapPropReplayProtection 0x00000008
#define eapPropConfidentiality 0x00000010
#define eapPropKeyDerivation 0x00000020
#define eapPropKeyStrength64 0x00000040
#define eapPropKeyStrength128 0x00000080
#define eapPropKeyStrength256 0x00000100
#define eapPropKeyStrength512 0x00000200
#define eapPropKeyStrength1024 0x00000400
#define eapPropDictionaryAttackResistance 0x00000800
#define eapPropFastReconnect 0x00001000
#define eapPropCryptoBinding 0x00002000
#define eapPropSessionIndependence 0x00004000
#define eapPropFragmentation 0x00008000
#define eapPropChannelBinding 0x00010000
#define eapPropNap 0x00020000
#define eapPropStandalone 0x00040000
#define eapPropMppeEncryption 0x00080000
#define eapPropTunnelMethod 0x00100000
#define eapPropSupportsConfig 0x00200000
#define eapPropCertifiedMethod 0x00400000
#if (_WIN32_WINNT >= 0x0601)
#define eapPropmachineAuth 0x01000000
#define eapPropUserAuth 0x02000000
#define eapPropIdentityPrivacy 0x04000000
#define eapPropMethodChaining 0x08000000
#define eapPropSharedStateEquivalence 0x10000000
#endif /*(_WIN32_WINNT >= 0x0601)*/
#define eapPropReserved 0x20000000

typedef struct _EAP_METHOD_INFO {
  EAP_METHOD_TYPE         eapType;
  LPWSTR                  pwszAuthorName;
  LPWSTR                  pwszFriendlyName;
  DWORD                   eapProperties;
  struct _EAP_METHOD_INFO *pInnerMethodInfo;
} EAP_METHOD_INFO;

typedef struct _EAP_METHOD_INFO_ARRAY {
  DWORD           dwNumberOfMethods;
  EAP_METHOD_INFO *pEapMethods;
} EAP_METHOD_INFO_ARRAY, *PEAP_METHOD_INFO_ARRAY;

typedef struct _EAP_METHOD_INFO_EX {
  EAP_METHOD_TYPE                  eapType;
  LPWSTR                           pwszAuthorName;
  LPWSTR                           pwszFriendlyName;
  DWORD                            eapProperties;
  struct _EAP_METHOD_INFO_ARRAY_EX *pInnerMethodInfoArray;
} EAP_METHOD_INFO_EX;

typedef struct _EAP_METHOD_INFO_ARRAY_EX {
  DWORD              dwNumberOfMethods;
  EAP_METHOD_INFO_EX *pEapMethods;
} EAP_METHOD_INFO_ARRAY_EX, *PEAP_METHOD_INFO_ARRAY_EX;

typedef struct _EAP_CRED_EXPIRY_REQ {
  EAP_CONFIG_INPUT_FIELD_ARRAY curCreds;
  EAP_CONFIG_INPUT_FIELD_ARRAY newCreds;
} /* EAP_CRED_EXPIRY_REQ, */ *PEAP_CRED_EXPIRY_REQ;

typedef struct _EAP_CRED_EXPIRY_RESP {
  EAP_CONFIG_INPUT_FIELD_ARRAY curCreds;
  EAP_CONFIG_INPUT_FIELD_ARRAY newCreds;
} EAP_CRED_EXPIRY_RESP, *PEAP_CRED_EXPIRY_RESP;

#ifdef __cplusplus
}
#endif

#endif /*_INC_EAPTYPES*/
