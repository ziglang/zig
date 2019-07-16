/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WLANAPI
#define _INC_WLANAPI

#include <l2cmn.h>
#include <windot11.h>
#include <eaptypes.h>

#ifdef __cplusplus
extern "C" {
#endif

#define WLAN_NOTIFICATION_SOURCE_NONE      L2_NOTIFICATION_SOURCE_NONE
#define WLAN_NOTIFICATION_SOURCE_ALL       L2_NOTIFICATION_SOURCE_ALL
#define WLAN_NOTIFICATION_SOURCE_ACM       L2_NOTIFICATION_SOURCE_WLAN_ACM
#define WLAN_NOTIFICATION_SOURCE_MSM       L2_NOTIFICATION_SOURCE_WLAN_MSM
#define WLAN_NOTIFICATION_SOURCE_SECURITY  L2_NOTIFICATION_SOURCE_WLAN_SECURITY
#define WLAN_NOTIFICATION_SOURCE_IHV       L2_NOTIFICATION_SOURCE_WLAN_IHV
#define WLAN_NOTIFICATION_SOURCE_HNWK      L2_NOTIFICATION_SOURCE_WLAN_HNWK
#define WLAN_NOTIFICATION_SOURCE_ONEX      L2_NOTIFICATION_SOURCE_ONEX

typedef DWORD WLAN_REASON_CODE, *PWLAN_REASON_CODE;
typedef ULONG WLAN_SIGNAL_QUALITY, *PWLAN_SIGNAL_QUALITY;

typedef struct _DOT11_NETWORK {
  DOT11_SSID     dot11Ssid;
  DOT11_BSS_TYPE dot11BssType;
} DOT11_NETWORK, *PDOT11_NETWORK;

typedef enum _DOT11_RADIO_STATE {
  dot11_radio_state_unknown,
  dot11_radio_state_on,
  dot11_radio_state_off 
} DOT11_RADIO_STATE, *PDOT11_RADIO_STATE;

typedef enum _WLAN_NOTIFICATION_ACM {
    wlan_notification_acm_start = 0,
    wlan_notification_acm_autoconf_enabled,
    wlan_notification_acm_autoconf_disabled,
    wlan_notification_acm_background_scan_enabled,
    wlan_notification_acm_background_scan_disabled,
    wlan_notification_acm_bss_type_change,
    wlan_notification_acm_power_setting_change,
    wlan_notification_acm_scan_complete,
    wlan_notification_acm_scan_fail,
    wlan_notification_acm_connection_start,
    wlan_notification_acm_connection_complete,
    wlan_notification_acm_connection_attempt_fail,
    wlan_notification_acm_filter_list_change,
    wlan_notification_acm_interface_arrival,
    wlan_notification_acm_interface_removal,
    wlan_notification_acm_profile_change,
    wlan_notification_acm_profile_name_change,
    wlan_notification_acm_profiles_exhausted,
    wlan_notification_acm_network_not_available,
    wlan_notification_acm_network_available,
    wlan_notification_acm_disconnecting,
    wlan_notification_acm_disconnected,
    wlan_notification_acm_adhoc_network_state_change,
    wlan_notification_acm_end
} WLAN_NOTIFICATION_ACM, *PWLAN_NOTIFICATION_ACM;

typedef enum _WLAN_INTERFACE_STATE {
  wlan_interface_state_not_ready               = 0,
  wlan_interface_state_connected               = 1,
  wlan_interface_state_ad_hoc_network_formed   = 2,
  wlan_interface_state_disconnecting           = 3,
  wlan_interface_state_disconnected            = 4,
  wlan_interface_state_associating             = 5,
  wlan_interface_state_discovering             = 6,
  wlan_interface_state_authenticating          = 7 
} WLAN_INTERFACE_STATE, *PWLAN_INTERFACE_STATE;

typedef enum _WLAN_CONNECTION_MODE {
  wlan_connection_mode_profile,
  wlan_connection_mode_temporary_profile,
  wlan_connection_mode_discovery_secure,
  wlan_connection_mode_discovery_unsecure,
  wlan_connection_mode_auto,
  wlan_connection_mode_invalid 
} WLAN_CONNECTION_MODE, *PWLAN_CONNECTION_MODE;

typedef enum _WLAN_INTERFACE_TYPE {
  wlan_interface_type_emulated_802_11   = 0,
  wlan_interface_type_native_802_11,
  wlan_interface_type_invalid 
} WLAN_INTERFACE_TYPE, *PWLAN_INTERFACE_TYPE;

typedef enum _WLAN_INTF_OPCODE {
  wlan_intf_opcode_autoconf_start                               = 0x000000000,
  wlan_intf_opcode_autoconf_enabled,
  wlan_intf_opcode_background_scan_enabled,
  wlan_intf_opcode_media_streaming_mode,
  wlan_intf_opcode_radio_state,
  wlan_intf_opcode_bss_type,
  wlan_intf_opcode_interface_state,
  wlan_intf_opcode_current_connection,
  wlan_intf_opcode_channel_number,
  wlan_intf_opcode_supported_infrastructure_auth_cipher_pairs,
  wlan_intf_opcode_supported_adhoc_auth_cipher_pairs,
  wlan_intf_opcode_supported_country_or_region_string_list,
  wlan_intf_opcode_current_operation_mode,
  wlan_intf_opcode_supported_safe_mode,
  wlan_intf_opcode_certified_safe_mode,
  wlan_intf_opcode_hosted_network_capable,
  wlan_intf_opcode_autoconf_end                                 = 0x0fffffff,
  wlan_intf_opcode_msm_start                                    = 0x10000100,
  wlan_intf_opcode_statistics,
  wlan_intf_opcode_rssi,
  wlan_intf_opcode_msm_end                                      = 0x1fffffff,
  wlan_intf_opcode_security_start                               = 0x20010000,
  wlan_intf_opcode_security_end                                 = 0x2fffffff,
  wlan_intf_opcode_ihv_start                                    = 0x30000000,
  wlan_intf_opcode_ihv_end                                      = 0x3fffffff 
} WLAN_INTF_OPCODE, *PWLAN_INTF_OPCODE;

typedef enum _WLAN_OPCODE_VALUE_TYPE {
  wlan_opcode_value_type_query_only            = 0,
  wlan_opcode_value_type_set_by_group_policy   = 1,
  wlan_opcode_value_type_set_by_user           = 2,
  wlan_opcode_value_type_invalid               = 3 
} WLAN_OPCODE_VALUE_TYPE, *PWLAN_OPCODE_VALUE_TYPE;

typedef enum _WLAN_POWER_SETTING {
  wlan_power_setting_no_saving,
  wlan_power_setting_low_saving,
  wlan_power_setting_medium_saving,
  wlan_power_setting_maximum_saving,
  wlan_power_setting_invalid 
} WLAN_POWER_SETTING, *PWLAN_POWER_SETTING;

typedef struct _WLAN_ASSOCIATION_ATTRIBUTES {
  DOT11_SSID          dot11Ssid;
  DOT11_BSS_TYPE      dot11BssType;
  DOT11_MAC_ADDRESS   dot11Bssid;
  DOT11_PHY_TYPE      dot11PhyType;
  ULONG               uDot11PhyIndex;
  WLAN_SIGNAL_QUALITY wlanSignalQuality;
  ULONG               ulRxRate;
  ULONG               ulTxRate;
} WLAN_ASSOCIATION_ATTRIBUTES, *PWLAN_ASSOCIATION_ATTRIBUTES;

typedef struct _WLAN_AUTH_CIPHER_PAIR_LIST {
  DWORD                  dwNumberOfItems;
  DOT11_AUTH_CIPHER_PAIR pAuthCipherPairList;
} WLAN_AUTH_CIPHER_PAIR_LIST, *PWLAN_AUTH_CIPHER_PAIR_LIST;

typedef struct _WLAN_NOTIFICATION_DATA {
  DWORD NotificationSource;
  DWORD NotificationCode;
  GUID  InterfaceGuid;
  DWORD dwDataSize;
  PVOID pData;
} WLAN_NOTIFICATION_DATA, *PWLAN_NOTIFICATION_DATA;

#define WLAN_MAX_PHY_TYPE_NUMBER 8

typedef struct _WLAN_AVAILABLE_NETWORK {
  WCHAR                  strProfileName[256];
  DOT11_SSID             dot11Ssid;
  DOT11_BSS_TYPE         dot11BssType;
  ULONG                  uNumberOfBssids;
  WINBOOL                bNetworkConnectable;
  WLAN_REASON_CODE       wlanNotConnectableReason;
  ULONG                  uNumberOfPhyTypes;
  DOT11_PHY_TYPE         dot11PhyTypes[WLAN_MAX_PHY_TYPE_NUMBER];
  WINBOOL                bMorePhyTypes;
  WLAN_SIGNAL_QUALITY    wlanSignalQuality;
  WINBOOL                bSecurityEnabled;
  DOT11_AUTH_ALGORITHM   dot11DefaultAuthAlgorithm;
  DOT11_CIPHER_ALGORITHM dot11DefaultCipherAlgorithm;
  DWORD                  dwFlags;
  DWORD                  dwReserved;
} WLAN_AVAILABLE_NETWORK, *PWLAN_AVAILABLE_NETWORK;

typedef struct _WLAN_AVAILABLE_NETWORK_LIST {
  DWORD                  dwNumberOfItems;
  DWORD                  dwIndex;
  WLAN_AVAILABLE_NETWORK Network[1];
} WLAN_AVAILABLE_NETWORK_LIST, *PWLAN_AVAILABLE_NETWORK_LIST;

typedef struct _WLAN_SECURITY_ATTRIBUTES {
  WINBOOL                bSecurityEnabled;
  WINBOOL                bOneXEnabled;
  DOT11_AUTH_ALGORITHM   dot11AuthAlgorithm;
  DOT11_CIPHER_ALGORITHM dot11CipherAlgorithm;
} WLAN_SECURITY_ATTRIBUTES, *PWLAN_SECURITY_ATTRIBUTES;

typedef struct _WLAN_CONNECTION_ATTRIBUTES {
  WLAN_INTERFACE_STATE        isState;
  WLAN_CONNECTION_MODE        wlanConnectionMode;
  WCHAR                       strProfileName[256];
  WLAN_ASSOCIATION_ATTRIBUTES wlanAssociationAttributes;
  WLAN_SECURITY_ATTRIBUTES    wlanSecurityAttributes;
} WLAN_CONNECTION_ATTRIBUTES, *PWLAN_CONNECTION_ATTRIBUTES;

/* Assuming stdcall */
typedef VOID (CALLBACK *WLAN_NOTIFICATION_CALLBACK)(
  PWLAN_NOTIFICATION_DATA ,
  PVOID 
);

#define WLAN_MAX_NAME_LENGTH 256

typedef struct _WLAN_CONNECTION_NOTIFICATION_DATA {
  WLAN_CONNECTION_MODE wlanConnectionMode;
  WCHAR                strProfileName[WLAN_MAX_NAME_LENGTH];
  DOT11_SSID           dot11Ssid;
  DOT11_BSS_TYPE       dot11BssType;
  BOOL                 bSecurityEnabled;
  WLAN_REASON_CODE     wlanReasonCode;
  DWORD                dwFlags;
  WCHAR                strProfileXml[1];
} WLAN_CONNECTION_NOTIFICATION_DATA, *PWLAN_CONNECTION_NOTIFICATION_DATA;

#define WLAN_CONNECTION_HIDDEN_NETWORK 0x00000001
#define WLAN_CONNECTION_ADHOC_JOIN_ONLY 0x00000002
#define WLAN_CONNECTION_IGNORE_PRIVACY_BIT 0x00000004
#define WLAN_CONNECTION_EAPOL_PASSTHROUGH 0x00000008

typedef struct _WLAN_CONNECTION_PARAMETERS {
  WLAN_CONNECTION_MODE wlanConnectionMode;
  LPCWSTR              strProfile;
  PDOT11_SSID          pDot11Ssid;
  PDOT11_BSSID_LIST    pDesiredBssidList;
  DOT11_BSS_TYPE       dot11BssType;
  DWORD                dwFlags;
} WLAN_CONNECTION_PARAMETERS, *PWLAN_CONNECTION_PARAMETERS;

typedef struct _WLAN_INTERFACE_INFO {
  GUID                 InterfaceGuid;
  WCHAR                strInterfaceDescription[256];
  WLAN_INTERFACE_STATE isState;
} WLAN_INTERFACE_INFO, *PWLAN_INTERFACE_INFO;

typedef struct _WLAN_INTERFACE_INFO_LIST {
  DWORD               dwNumberOfItems;
  DWORD               dwIndex;
  WLAN_INTERFACE_INFO InterfaceInfo[];
} WLAN_INTERFACE_INFO_LIST, *PWLAN_INTERFACE_INFO_LIST;

typedef struct _WLAN_PROFILE_INFO {
  WCHAR strProfileName[256];
  DWORD dwFlags;
} WLAN_PROFILE_INFO, *PWLAN_PROFILE_INFO;

typedef struct _WLAN_PROFILE_INFO_LIST {
  DWORD             dwNumberOfItems;
  DWORD             dwIndex;
  WLAN_PROFILE_INFO ProfileInfo[1];
} WLAN_PROFILE_INFO_LIST, *PWLAN_PROFILE_INFO_LIST;

PVOID WINAPI WlanAllocateMemory(
  DWORD dwMemorySize
);

DWORD WINAPI WlanCloseHandle(
  HANDLE hClientHandle,
  PVOID pReserved
);

DWORD WINAPI WlanConnect(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  const PWLAN_CONNECTION_PARAMETERS pConnectionParameters,
  PVOID pReserved
);

DWORD WINAPI WlanDeleteProfile(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPCWSTR strProfileName,
  PVOID pReserved
);

DWORD WINAPI WlanDisconnect(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  PVOID pReserved
);

DWORD WINAPI WlanEnumInterfaces(
  HANDLE hClientHandle,
  PVOID pReserved,
  PWLAN_INTERFACE_INFO_LIST *ppInterfaceList
);

VOID WINAPI WlanFreeMemory(
  PVOID pMemory
);

DWORD WINAPI WlanGetAvailableNetworkList(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  DWORD dwFlags,
  PVOID pReserved,
  PWLAN_AVAILABLE_NETWORK_LIST *ppAvailableNetworkList
);

DWORD WINAPI WlanGetProfile(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPCWSTR strProfileName,
  PVOID pReserved,
  LPWSTR *pstrProfileXml,
  DWORD *pdwFlags,
  PDWORD pdwGrantedAccess
);

DWORD WINAPI WlanGetProfileList(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  PVOID pReserved,
  PWLAN_PROFILE_INFO_LIST *ppProfileList
);

DWORD WINAPI WlanOpenHandle(
  DWORD dwClientVersion,
  PVOID pReserved,
  PDWORD pdwNegotiatedVersion,
  PHANDLE phClientHandle
);

DWORD WINAPI WlanQueryInterface(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  WLAN_INTF_OPCODE OpCode,
  PVOID pReserved,
  PDWORD pdwDataSize,
  PVOID *ppData,
  PWLAN_OPCODE_VALUE_TYPE pWlanOpcodeValueType
);

DWORD WINAPI WlanReasonCodeToString(
  DWORD dwReasonCode,
  DWORD dwBufferSize,
  PWCHAR pStringBuffer,
  PVOID pReserved
);

DWORD WINAPI WlanRegisterNotification(
  HANDLE hClientHandle,
  DWORD dwNotifSource,
  WINBOOL bIgnoreDuplicate,
  WLAN_NOTIFICATION_CALLBACK  funcCallback,
  PVOID pCallbackContext,
  PVOID pReserved,
  PDWORD pdwPrevNotifSource
);

DWORD WINAPI WlanSetInterface(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  WLAN_INTF_OPCODE OpCode,
  DWORD dwDataSize,
  const PVOID pData,
  PVOID pReserved
);

DWORD WINAPI WlanSetProfile(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  DWORD dwFlags,
  LPCWSTR strProfileXml,
  LPCWSTR strAllUserProfileSecurity,
  WINBOOL bOverwrite,
  PVOID pReserved,
  DWORD *pdwReasonCode
);

DWORD WINAPI WlanSetProfileEapXmlUserData(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPCWSTR strProfileName,
  DWORD dwFlags,
  LPCWSTR strEapXmlUserData,
  PVOID pReserved
);

DWORD WINAPI WlanSetProfileList(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  DWORD dwItems,
  LPCWSTR *strProfileNames,
  PVOID pReserved
);

DWORD WINAPI WlanSetProfilePosition(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPCWSTR strProfileName,
  DWORD dwPosition,
  PVOID pReserved
);

typedef enum _WLAN_AUTOCONF_OPCODE {
  wlan_autoconf_opcode_start                                       = 0,
  wlan_autoconf_opcode_show_denied_networks                        = 1,
  wlan_autoconf_opcode_power_setting                               = 2,
  wlan_autoconf_opcode_only_use_gp_profiles_for_allowed_networks   = 3,
  wlan_autoconf_opcode_allow_explicit_creds                        = 4,
  wlan_autoconf_opcode_block_period                                = 5,
  wlan_autoconf_opcode_allow_virtual_station_extensibility         = 6,
  wlan_autoconf_opcode_end                                         = 7 
} WLAN_AUTOCONF_OPCODE, *PWLAN_AUTOCONF_OPCODE;

typedef enum _WL_DISPLAY_PAGES {
  WLConnectionPage,
  WLSecurityPage 
} WL_DISPLAY_PAGES, *PWL_DISPLAY_PAGES;

typedef enum _WLAN_ADHOC_NETWORK_STATE {
  wlan_adhoc_network_state_formed      = 0,
  wlan_adhoc_network_state_connected   = 1 
} WLAN_ADHOC_NETWORK_STATE;

typedef enum _WLAN_IHV_CONTROL_TYPE {
  wlan_ihv_control_type_service,
  wlan_ihv_control_type_driver 
} WLAN_IHV_CONTROL_TYPE, *PWLAN_IHV_CONTROL_TYPE;

typedef enum _WLAN_FILTER_LIST_TYPE {
  wlan_filter_list_type_gp_permit,
  wlan_filter_list_type_gp_deny,
  wlan_filter_list_type_user_permit,
  wlan_filter_list_type_user_deny 
} WLAN_FILTER_LIST_TYPE, *PWLAN_FILTER_LIST_TYPE;

typedef enum _WLAN_SECURABLE_OBJECT {
  wlan_secure_permit_list                      = 0,
  wlan_secure_deny_list                        = 1,
  wlan_secure_ac_enabled                       = 2,
  wlan_secure_bc_scan_enabled                  = 3,
  wlan_secure_bss_type                         = 4,
  wlan_secure_show_denied                      = 5,
  wlan_secure_interface_properties             = 6,
  wlan_secure_ihv_control                      = 7,
  wlan_secure_all_user_profiles_order          = 8,
  wlan_secure_add_new_all_user_profiles        = 9,
  wlan_secure_add_new_per_user_profiles        = 10,
  wlan_secure_media_streaming_mode_enabled     = 11,
  wlan_secure_current_operation_mode           = 12,
  wlan_secure_get_plaintext_key                = 13,
  wlan_secure_hosted_network_elevated_access   = 14 
} WLAN_SECURABLE_OBJECT, *PWLAN_SECURABLE_OBJECT;

typedef struct _DOT11_NETWORK_LIST {
  DWORD         dwNumberOfItems;
  DWORD         dwIndex;
  DOT11_NETWORK Network[1];
} DOT11_NETWORK_LIST, *PDOT11_NETWORK_LIST;

#define DOT11_RATE_SET_MAX_LENGTH 126

typedef struct _WLAN_RATE_SET {
  ULONG  uRateSetLength;
  USHORT usRateSet[DOT11_RATE_SET_MAX_LENGTH];
} WLAN_RATE_SET, *PWLAN_RATE_SET;

typedef struct _WLAN_BSS_ENTRY {
  DOT11_SSID        dot11Ssid;
  ULONG             uPhyId;
  DOT11_MAC_ADDRESS dot11Bssid;
  DOT11_BSS_TYPE    dot11BssType;
  DOT11_PHY_TYPE    dot11BssPhyType;
  LONG              lRssi;
  ULONG             uLinkQuality;
  BOOLEAN           bInRegDomain;
  USHORT            usBeaconPeriod;
  ULONGLONG         ullTimestamp;
  ULONGLONG         ullHostTimestamp;
  USHORT            usCapabilityInformation;
  ULONG             ulChCenterFrequency;
  WLAN_RATE_SET     wlanRateSet;
  ULONG             ulIeOffset;
  ULONG             ulIeSize;
} WLAN_BSS_ENTRY, *PWLAN_BSS_ENTRY;

typedef struct _WLAN_BSS_LIST {
  DWORD          dwTotalSize;
  DWORD          dwNumberOfItems;
  WLAN_BSS_ENTRY wlanBssEntries[1];
} WLAN_BSS_LIST, *PWLAN_BSS_LIST;

typedef struct _WLAN_COUNTRY_OR_REGION_STRING_LIST {
  DWORD                          dwNumberOfItems;
  DOT11_COUNTRY_OR_REGION_STRING pCountryOrRegionStringList[1];
} WLAN_COUNTRY_OR_REGION_STRING_LIST, *PWLAN_COUNTRY_OR_REGION_STRING_LIST;

#define WLAN_MAX_PHY_INDEX 64

typedef struct _WLAN_INTERFACE_CAPABILITY {
  WLAN_INTERFACE_TYPE interfaceType;
  WINBOOL             bDot11DSupported;
  DWORD               dwMaxDesiredSsidListSize;
  DWORD               dwMaxDesiredBssidListSize;
  DWORD               dwNumberOfSupportedPhys;
  DOT11_PHY_TYPE      dot11PhyTypes[WLAN_MAX_PHY_INDEX];
} WLAN_INTERFACE_CAPABILITY, *PWLAN_INTERFACE_CAPABILITY;

typedef struct _WLAN_MAC_FRAME_STATISTICS {
  ULONGLONG ullTransmittedFrameCount;
  ULONGLONG ullReceivedFrameCount;
  ULONGLONG ullWEPExcludedCount;
  ULONGLONG ullTKIPLocalMICFailures;
  ULONGLONG ullTKIPReplays;
  ULONGLONG ullTKIPICVErrorCount;
  ULONGLONG ullCCMPReplays;
  ULONGLONG ullCCMPDecryptErrors;
  ULONGLONG ullWEPUndecryptableCount;
  ULONGLONG ullWEPICVErrorCount;
  ULONGLONG ullDecryptSuccessCount;
  ULONGLONG ullDecryptFailureCount;
} WLAN_MAC_FRAME_STATISTICS, *PWLAN_MAC_FRAME_STATISTICS;

typedef struct _WLAN_MSM_NOTIFICATION_DATA {
  WLAN_CONNECTION_MODE wlanConnectionMode;
  WCHAR                strProfileName[WLAN_MAX_NAME_LENGTH];
  DOT11_SSID           dot11Ssid;
  DOT11_BSS_TYPE       dot11BssType;
  DOT11_MAC_ADDRESS    dot11MacAddr;
  BOOL                 bSecurityEnabled;
  BOOL                 bFirstPeer;
  BOOL                 bLastPeer;
  WLAN_REASON_CODE     wlanReasonCode;
} WLAN_MSM_NOTIFICATION_DATA, *PWLAN_MSM_NOTIFICATION_DATA;

typedef struct _WLAN_PHY_FRAME_STATISTICS {
  ULONGLONG ullTransmittedFrameCount;
  ULONGLONG ullMulticastTransmittedFrameCount;
  ULONGLONG ullFailedCount;
  ULONGLONG ullRetryCount;
  ULONGLONG ullMultipleRetryCount;
  ULONGLONG ullMaxTXLifetimeExceededCount;
  ULONGLONG ullTransmittedFragmentCount;
  ULONGLONG ullRTSSuccessCount;
  ULONGLONG ullRTSFailureCount;
  ULONGLONG ullACKFailureCount;
  ULONGLONG ullReceivedFrameCount;
  ULONGLONG ullMulticastReceivedFrameCount;
  ULONGLONG ullPromiscuousReceivedFrameCount;
  ULONGLONG ullMaxRXLifetimeExceededCount;
  ULONGLONG ullFrameDuplicateCount;
  ULONGLONG ullReceivedFragmentCount;
  ULONGLONG ullPromiscuousReceivedFragmentCount;
  ULONGLONG ullFCSErrorCount;
} WLAN_PHY_FRAME_STATISTICS, *PWLAN_PHY_FRAME_STATISTICS;

typedef struct _WLAN_PHY_RADIO_STATE {
  DWORD             dwPhyIndex;
  DOT11_RADIO_STATE dot11SoftwareRadioState;
  DOT11_RADIO_STATE dot11HardwareRadioState;
} WLAN_PHY_RADIO_STATE, *PWLAN_PHY_RADIO_STATE;

typedef struct _WLAN_RADIO_STATE {
  DWORD                dwNumberOfPhys;
  WLAN_PHY_RADIO_STATE PhyRadioState[64];
} WLAN_RADIO_STATE, *PWLAN_RADIO_STATE;

#define DOT11_PSD_IE_MAX_DATA_SIZE 240
#define DOT11_PSD_IE_MAX_ENTRY_NUMBER 5

typedef struct _WLAN_RAW_DATA {
  DWORD dwDataSize;
  BYTE  DataBlob[1];
} WLAN_RAW_DATA, *PWLAN_RAW_DATA;

typedef struct _WLAN_RAW_DATA_LIST {
  DWORD dwTotalSize;
  DWORD dwNumberOfItems;
  struct {
    DWORD dwDataOffset;
    DWORD dwDataSize;
  } DataList[1];
} WLAN_RAW_DATA_LIST, *PWLAN_RAW_DATA_LIST;

typedef struct _WLAN_STATISTICS {
  ULONGLONG                 ullFourWayHandshakeFailures;
  ULONGLONG                 ullTKIPCounterMeasuresInvoked;
  ULONGLONG                 ullReserved;
  WLAN_MAC_FRAME_STATISTICS MacUcastCounters;
  WLAN_MAC_FRAME_STATISTICS MacMcastCounters;
  DWORD                     dwNumberOfPhys;
  WLAN_PHY_FRAME_STATISTICS PhyCounters[1];
} WLAN_STATISTICS, *PWLAN_STATISTICS;

DWORD WINAPI WlanExtractPsdIEDataList(
  HANDLE hClientHandle,
  DWORD dwIeDataSize,
  const PBYTE pRawIeData,
  LPCWSTR strFormat,
  PVOID pReserved,
  PWLAN_RAW_DATA_LIST *ppPsdIEDataList
);

DWORD WINAPI WlanGetFilterList(
  HANDLE hClientHandle,
  WLAN_FILTER_LIST_TYPE wlanFilterListType,
  PVOID pReserved,
  PDOT11_NETWORK_LIST *ppNetworkList
);

DWORD WINAPI WlanGetInterfaceCapability(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  PVOID pReserved,
  PWLAN_INTERFACE_CAPABILITY *ppCapability
);

DWORD WINAPI WlanGetNetworkBssList(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  const  PDOT11_SSID pDot11Ssid,
  DOT11_BSS_TYPE dot11BssType,
  WINBOOL bSecurityEnabled,
  PVOID pReserved,
  PWLAN_BSS_LIST *ppWlanBssList
);

DWORD WINAPI WlanGetProfileCustomUserData(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPCWSTR strProfileName,
  PVOID pReserved,
  DWORD *pdwDataSize,
  PBYTE *ppData
);

DWORD WINAPI WlanGetSecuritySettings(
  HANDLE hClientHandle,
  WLAN_SECURABLE_OBJECT SecurableObject,
  PWLAN_OPCODE_VALUE_TYPE pValueType,
  LPWSTR *pstrCurrentSDDL,
  PDWORD pdwGrantedAccess
);

DWORD WINAPI WlanIhvControl(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  WLAN_IHV_CONTROL_TYPE Type,
  DWORD dwInBufferSize,
  PVOID pInBuffer,
  DWORD dwOutBufferSize,
  PVOID pOutBuffer,
  PDWORD pdwBytesReturned
);

DWORD WINAPI WlanQueryAutoConfigParameter(
  HANDLE hClientHandle,
  WLAN_AUTOCONF_OPCODE OpCode,
  PVOID pReserved,
  PDWORD pdwDataSize,
  PVOID ppData,
  PWLAN_OPCODE_VALUE_TYPE pWlanOpcodeValueType
);

DWORD WINAPI WlanRenameProfile(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPCWSTR strOldProfileName,
  LPCWSTR strNewProfileName,
  PVOID pReserved
);

#define WLAN_PROFILE_USER 0x00000002
#define WLAN_PROFILE_CONNECTION_MODE_SET_BY_CLIENT 0x00010000
#define WLAN_PROFILE_CONNECTION_MODE_AUTO 0x00020000

DWORD WINAPI WlanSaveTemporaryProfile(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPCWSTR strProfileName,
  LPCWSTR strAllUserProfileSecurity,
  DWORD dwFlags,
  WINBOOL bOverWrite,
  PVOID pReserved
);

DWORD WINAPI WlanScan(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  const PDOT11_SSID pDot11Ssid,
  const PWLAN_RAW_DATA pIeData,
  PVOID pReserved
);

DWORD WINAPI WlanSetAutoConfigParameter(
  HANDLE hClientHandle,
  WLAN_AUTOCONF_OPCODE OpCode,
  DWORD dwDataSize,
  const PVOID pData,
  PVOID pReserved
);

DWORD WINAPI WlanSetFilterList(
  HANDLE hClientHandle,
  WLAN_FILTER_LIST_TYPE wlanFilterListType,
  const PDOT11_NETWORK_LIST pNetworkList,
  PVOID pReserved
);

DWORD WINAPI WlanSetProfileCustomUserData(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPCWSTR strProfileName,
  DWORD dwDataSize,
  const PBYTE pData,
  PVOID pReserved
);

DWORD WlanSetProfileEapUserData(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPCWSTR strProfileName,
  EAP_METHOD_TYPE eapType,
  DWORD dwFlags,
  DWORD dwEapUserDataSize,
  const LPBYTE pbEapUserData,
  PVOID pReserved
);

DWORD WINAPI WlanSetPsdIEDataList(
  HANDLE hClientHandle,
  LPCWSTR strFormat,
  const PWLAN_RAW_DATA_LIST pPsdIEDataList,
  PVOID pReserved
);

DWORD WINAPI WlanSetSecuritySettings(
  HANDLE hClientHandle,
  WLAN_SECURABLE_OBJECT SecurableObject,
  LPCWSTR strModifiedSDDL
);

DWORD WINAPI WlanUIEditProfile(
  DWORD dwClientVersion,
  LPCWSTR wstrProfileName,
  GUID *pInterfaceGuid,
  HWND hWnd,
  WL_DISPLAY_PAGES wlStartPage,
  PVOID pReserved,
  PWLAN_REASON_CODE *pWlanReasonCode
);

#ifdef __cplusplus
}
#endif

#endif /*_INC_WLANAPI*/
