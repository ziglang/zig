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

#define WLAN_MAX_NAME_LENGTH L2_PROFILE_MAX_NAME_LENGTH

#define WLAN_SET_EAPHOST_DATA_ALL_USERS 0x00000001

#define WLAN_NOTIFICATION_SOURCE_NONE      L2_NOTIFICATION_SOURCE_NONE
#define WLAN_NOTIFICATION_SOURCE_ALL       L2_NOTIFICATION_SOURCE_ALL
#define WLAN_NOTIFICATION_SOURCE_ACM       L2_NOTIFICATION_SOURCE_WLAN_ACM
#define WLAN_NOTIFICATION_SOURCE_MSM       L2_NOTIFICATION_SOURCE_WLAN_MSM
#define WLAN_NOTIFICATION_SOURCE_SECURITY  L2_NOTIFICATION_SOURCE_WLAN_SECURITY
#define WLAN_NOTIFICATION_SOURCE_IHV       L2_NOTIFICATION_SOURCE_WLAN_IHV
#define WLAN_NOTIFICATION_SOURCE_HNWK      L2_NOTIFICATION_SOURCE_WLAN_HNWK
#define WLAN_NOTIFICATION_SOURCE_ONEX      L2_NOTIFICATION_SOURCE_ONEX
#define WLAN_NOTIFICATION_SOURCE_DEVICE_SERVICE L2_NOTIFICATION_SOURCE_WLAN_DEVICE_SERVICE

#define WLAN_REASON_CODE_SUCCESS L2_REASON_CODE_SUCCESS
#define WLAN_REASON_CODE_UNKNOWN L2_REASON_CODE_UNKNOWN
#define WLAN_REASON_CODE_RANGE_SIZE L2_REASON_CODE_GROUP_SIZE
#define WLAN_REASON_CODE_BASE L2_REASON_CODE_DOT11_AC_BASE
#define WLAN_REASON_CODE_AC_BASE L2_REASON_CODE_DOT11_AC_BASE
#define WLAN_REASON_CODE_AC_CONNECT_BASE (WLAN_REASON_CODE_AC_BASE + WLAN_REASON_CODE_RANGE_SIZE / 2)
#define WLAN_REASON_CODE_AC_END (WLAN_REASON_CODE_AC_BASE + WLAN_REASON_CODE_RANGE_SIZE - 1)
#define WLAN_REASON_CODE_PROFILE_BASE L2_REASON_CODE_PROFILE_BASE
#define WLAN_REASON_CODE_PROFILE_CONNECT_BASE (WLAN_REASON_CODE_PROFILE_BASE + WLAN_REASON_CODE_RANGE_SIZE / 2)
#define WLAN_REASON_CODE_PROFILE_END (WLAN_REASON_CODE_PROFILE_BASE + WLAN_REASON_CODE_RANGE_SIZE - 1)
#define WLAN_REASON_CODE_MSM_BASE L2_REASON_CODE_DOT11_MSM_BASE
#define WLAN_REASON_CODE_MSM_CONNECT_BASE (WLAN_REASON_CODE_MSM_BASE + WLAN_REASON_CODE_RANGE_SIZE / 2)
#define WLAN_REASON_CODE_MSM_END (WLAN_REASON_CODE_MSM_BASE + WLAN_REASON_CODE_RANGE_SIZE - 1)
#define WLAN_REASON_CODE_MSMSEC_BASE L2_REASON_CODE_DOT11_SECURITY_BASE
#define WLAN_REASON_CODE_MSMSEC_CONNECT_BASE (WLAN_REASON_CODE_MSMSEC_BASE + WLAN_REASON_CODE_RANGE_SIZE / 2)
#define WLAN_REASON_CODE_MSMSEC_END (WLAN_REASON_CODE_MSMSEC_BASE + WLAN_REASON_CODE_RANGE_SIZE - 1)
#define WLAN_REASON_CODE_RESERVED_BASE L2_REASON_CODE_RESERVED_BASE
#define WLAN_REASON_CODE_RESERVED_END (WLAN_REASON_CODE_RESERVED_BASE + WLAN_REASON_CODE_RANGE_SIZE - 1)
#define WLAN_REASON_CODE_NETWORK_NOT_COMPATIBLE (WLAN_REASON_CODE_AC_BASE +1)
#define WLAN_REASON_CODE_PROFILE_NOT_COMPATIBLE (WLAN_REASON_CODE_AC_BASE +2)
#define WLAN_REASON_CODE_NO_AUTO_CONNECTION (WLAN_REASON_CODE_AC_CONNECT_BASE +1)
#define WLAN_REASON_CODE_NOT_VISIBLE (WLAN_REASON_CODE_AC_CONNECT_BASE +2)
#define WLAN_REASON_CODE_GP_DENIED (WLAN_REASON_CODE_AC_CONNECT_BASE +3)
#define WLAN_REASON_CODE_USER_DENIED (WLAN_REASON_CODE_AC_CONNECT_BASE +4)
#define WLAN_REASON_CODE_BSS_TYPE_NOT_ALLOWED (WLAN_REASON_CODE_AC_CONNECT_BASE +5)
#define WLAN_REASON_CODE_IN_FAILED_LIST (WLAN_REASON_CODE_AC_CONNECT_BASE +6)
#define WLAN_REASON_CODE_IN_BLOCKED_LIST (WLAN_REASON_CODE_AC_CONNECT_BASE +7)
#define WLAN_REASON_CODE_SSID_LIST_TOO_LONG (WLAN_REASON_CODE_AC_CONNECT_BASE +8)
#define WLAN_REASON_CODE_CONNECT_CALL_FAIL (WLAN_REASON_CODE_AC_CONNECT_BASE +9)
#define WLAN_REASON_CODE_SCAN_CALL_FAIL (WLAN_REASON_CODE_AC_CONNECT_BASE +10)
#define WLAN_REASON_CODE_NETWORK_NOT_AVAILABLE (WLAN_REASON_CODE_AC_CONNECT_BASE +11)
#define WLAN_REASON_CODE_PROFILE_CHANGED_OR_DELETED (WLAN_REASON_CODE_AC_CONNECT_BASE +12)
#define WLAN_REASON_CODE_KEY_MISMATCH (WLAN_REASON_CODE_AC_CONNECT_BASE + 13)
#define WLAN_REASON_CODE_USER_NOT_RESPOND (WLAN_REASON_CODE_AC_CONNECT_BASE + 14)
#define WLAN_REASON_CODE_AP_PROFILE_NOT_ALLOWED_FOR_CLIENT (WLAN_REASON_CODE_AC_CONNECT_BASE + 15)
#define WLAN_REASON_CODE_AP_PROFILE_NOT_ALLOWED (WLAN_REASON_CODE_AC_CONNECT_BASE + 16)
#define WLAN_REASON_CODE_HOTSPOT2_PROFILE_DENIED (WLAN_REASON_CODE_AC_CONNECT_BASE + 17)
#define WLAN_REASON_CODE_INVALID_PROFILE_SCHEMA (WLAN_REASON_CODE_PROFILE_BASE +1)
#define WLAN_REASON_CODE_PROFILE_MISSING (WLAN_REASON_CODE_PROFILE_BASE +2)
#define WLAN_REASON_CODE_INVALID_PROFILE_NAME (WLAN_REASON_CODE_PROFILE_BASE +3)
#define WLAN_REASON_CODE_INVALID_PROFILE_TYPE (WLAN_REASON_CODE_PROFILE_BASE +4)
#define WLAN_REASON_CODE_INVALID_PHY_TYPE (WLAN_REASON_CODE_PROFILE_BASE +5)
#define WLAN_REASON_CODE_MSM_SECURITY_MISSING (WLAN_REASON_CODE_PROFILE_BASE +6)
#define WLAN_REASON_CODE_IHV_SECURITY_NOT_SUPPORTED (WLAN_REASON_CODE_PROFILE_BASE +7)
#define WLAN_REASON_CODE_IHV_OUI_MISMATCH (WLAN_REASON_CODE_PROFILE_BASE +8)
#define WLAN_REASON_CODE_IHV_OUI_MISSING (WLAN_REASON_CODE_PROFILE_BASE +9)
#define WLAN_REASON_CODE_IHV_SETTINGS_MISSING (WLAN_REASON_CODE_PROFILE_BASE +10)
#define WLAN_REASON_CODE_CONFLICT_SECURITY (WLAN_REASON_CODE_PROFILE_BASE +11)
#define WLAN_REASON_CODE_SECURITY_MISSING (WLAN_REASON_CODE_PROFILE_BASE +12)
#define WLAN_REASON_CODE_INVALID_BSS_TYPE (WLAN_REASON_CODE_PROFILE_BASE +13)
#define WLAN_REASON_CODE_INVALID_ADHOC_CONNECTION_MODE (WLAN_REASON_CODE_PROFILE_BASE +14)
#define WLAN_REASON_CODE_NON_BROADCAST_SET_FOR_ADHOC (WLAN_REASON_CODE_PROFILE_BASE +15)
#define WLAN_REASON_CODE_AUTO_SWITCH_SET_FOR_ADHOC (WLAN_REASON_CODE_PROFILE_BASE +16)
#define WLAN_REASON_CODE_AUTO_SWITCH_SET_FOR_MANUAL_CONNECTION (WLAN_REASON_CODE_PROFILE_BASE +17)
#define WLAN_REASON_CODE_IHV_SECURITY_ONEX_MISSING (WLAN_REASON_CODE_PROFILE_BASE +18)
#define WLAN_REASON_CODE_PROFILE_SSID_INVALID (WLAN_REASON_CODE_PROFILE_BASE +19)
#define WLAN_REASON_CODE_TOO_MANY_SSID (WLAN_REASON_CODE_PROFILE_BASE +20)
#define WLAN_REASON_CODE_IHV_CONNECTIVITY_NOT_SUPPORTED (WLAN_REASON_CODE_PROFILE_BASE +21)
#define WLAN_REASON_CODE_BAD_MAX_NUMBER_OF_CLIENTS_FOR_AP (WLAN_REASON_CODE_PROFILE_BASE +22)
#define WLAN_REASON_CODE_INVALID_CHANNEL (WLAN_REASON_CODE_PROFILE_BASE +23)
#define WLAN_REASON_CODE_OPERATION_MODE_NOT_SUPPORTED (WLAN_REASON_CODE_PROFILE_BASE +24)
#define WLAN_REASON_CODE_AUTO_AP_PROFILE_NOT_ALLOWED (WLAN_REASON_CODE_PROFILE_BASE +25)
#define WLAN_REASON_CODE_AUTO_CONNECTION_NOT_ALLOWED (WLAN_REASON_CODE_PROFILE_BASE +26)
#define WLAN_REASON_CODE_HOTSPOT2_PROFILE_NOT_ALLOWED (WLAN_REASON_CODE_PROFILE_BASE +27)
#define WLAN_REASON_CODE_UNSUPPORTED_SECURITY_SET_BY_OS (WLAN_REASON_CODE_MSM_BASE +1)
#define WLAN_REASON_CODE_UNSUPPORTED_SECURITY_SET (WLAN_REASON_CODE_MSM_BASE +2)
#define WLAN_REASON_CODE_BSS_TYPE_UNMATCH (WLAN_REASON_CODE_MSM_BASE +3)
#define WLAN_REASON_CODE_PHY_TYPE_UNMATCH (WLAN_REASON_CODE_MSM_BASE +4)
#define WLAN_REASON_CODE_DATARATE_UNMATCH (WLAN_REASON_CODE_MSM_BASE +5)
#define WLAN_REASON_CODE_USER_CANCELLED (WLAN_REASON_CODE_MSM_CONNECT_BASE+1)
#define WLAN_REASON_CODE_ASSOCIATION_FAILURE (WLAN_REASON_CODE_MSM_CONNECT_BASE+2)
#define WLAN_REASON_CODE_ASSOCIATION_TIMEOUT (WLAN_REASON_CODE_MSM_CONNECT_BASE+3)
#define WLAN_REASON_CODE_PRE_SECURITY_FAILURE (WLAN_REASON_CODE_MSM_CONNECT_BASE+4)
#define WLAN_REASON_CODE_START_SECURITY_FAILURE (WLAN_REASON_CODE_MSM_CONNECT_BASE+5)
#define WLAN_REASON_CODE_SECURITY_FAILURE (WLAN_REASON_CODE_MSM_CONNECT_BASE+6)
#define WLAN_REASON_CODE_SECURITY_TIMEOUT (WLAN_REASON_CODE_MSM_CONNECT_BASE+7)
#define WLAN_REASON_CODE_ROAMING_FAILURE (WLAN_REASON_CODE_MSM_CONNECT_BASE+8)
#define WLAN_REASON_CODE_ROAMING_SECURITY_FAILURE (WLAN_REASON_CODE_MSM_CONNECT_BASE+9)
#define WLAN_REASON_CODE_ADHOC_SECURITY_FAILURE (WLAN_REASON_CODE_MSM_CONNECT_BASE+10)
#define WLAN_REASON_CODE_DRIVER_DISCONNECTED (WLAN_REASON_CODE_MSM_CONNECT_BASE+11)
#define WLAN_REASON_CODE_DRIVER_OPERATION_FAILURE (WLAN_REASON_CODE_MSM_CONNECT_BASE+12)
#define WLAN_REASON_CODE_IHV_NOT_AVAILABLE (WLAN_REASON_CODE_MSM_CONNECT_BASE+13)
#define WLAN_REASON_CODE_IHV_NOT_RESPONDING (WLAN_REASON_CODE_MSM_CONNECT_BASE+14)
#define WLAN_REASON_CODE_DISCONNECT_TIMEOUT (WLAN_REASON_CODE_MSM_CONNECT_BASE+15)
#define WLAN_REASON_CODE_INTERNAL_FAILURE (WLAN_REASON_CODE_MSM_CONNECT_BASE+16)
#define WLAN_REASON_CODE_UI_REQUEST_TIMEOUT (WLAN_REASON_CODE_MSM_CONNECT_BASE+17)
#define WLAN_REASON_CODE_TOO_MANY_SECURITY_ATTEMPTS (WLAN_REASON_CODE_MSM_CONNECT_BASE+18)
#define WLAN_REASON_CODE_AP_STARTING_FAILURE (WLAN_REASON_CODE_MSM_CONNECT_BASE+19)
#define WLAN_REASON_CODE_NO_VISIBLE_AP (WLAN_REASON_CODE_MSM_CONNECT_BASE+20)
#define WLAN_REASON_CODE_MSMSEC_MIN WLAN_REASON_CODE_MSMSEC_BASE
#define WLAN_REASON_CODE_MSMSEC_PROFILE_INVALID_KEY_INDEX (WLAN_REASON_CODE_MSMSEC_BASE+1)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_PSK_PRESENT (WLAN_REASON_CODE_MSMSEC_BASE+2)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_KEY_LENGTH (WLAN_REASON_CODE_MSMSEC_BASE+3)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_PSK_LENGTH (WLAN_REASON_CODE_MSMSEC_BASE+4)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_NO_AUTH_CIPHER_SPECIFIED (WLAN_REASON_CODE_MSMSEC_BASE+5)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_TOO_MANY_AUTH_CIPHER_SPECIFIED (WLAN_REASON_CODE_MSMSEC_BASE+6)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_DUPLICATE_AUTH_CIPHER (WLAN_REASON_CODE_MSMSEC_BASE+7)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_RAWDATA_INVALID (WLAN_REASON_CODE_MSMSEC_BASE+8)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_INVALID_AUTH_CIPHER (WLAN_REASON_CODE_MSMSEC_BASE+9)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_ONEX_DISABLED (WLAN_REASON_CODE_MSMSEC_BASE+10)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_ONEX_ENABLED (WLAN_REASON_CODE_MSMSEC_BASE+11)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_INVALID_PMKCACHE_MODE (WLAN_REASON_CODE_MSMSEC_BASE+12)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_INVALID_PMKCACHE_SIZE (WLAN_REASON_CODE_MSMSEC_BASE+13)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_INVALID_PMKCACHE_TTL (WLAN_REASON_CODE_MSMSEC_BASE+14)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_INVALID_PREAUTH_MODE (WLAN_REASON_CODE_MSMSEC_BASE+15)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_INVALID_PREAUTH_THROTTLE (WLAN_REASON_CODE_MSMSEC_BASE+16)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_PREAUTH_ONLY_ENABLED (WLAN_REASON_CODE_MSMSEC_BASE+17)
#define WLAN_REASON_CODE_MSMSEC_CAPABILITY_NETWORK (WLAN_REASON_CODE_MSMSEC_BASE+18)
#define WLAN_REASON_CODE_MSMSEC_CAPABILITY_NIC (WLAN_REASON_CODE_MSMSEC_BASE+19)
#define WLAN_REASON_CODE_MSMSEC_CAPABILITY_PROFILE (WLAN_REASON_CODE_MSMSEC_BASE+20)
#define WLAN_REASON_CODE_MSMSEC_CAPABILITY_DISCOVERY (WLAN_REASON_CODE_MSMSEC_BASE+21)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_PASSPHRASE_CHAR (WLAN_REASON_CODE_MSMSEC_BASE+22)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_KEYMATERIAL_CHAR (WLAN_REASON_CODE_MSMSEC_BASE+23)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_WRONG_KEYTYPE (WLAN_REASON_CODE_MSMSEC_BASE+24)
#define WLAN_REASON_CODE_MSMSEC_MIXED_CELL (WLAN_REASON_CODE_MSMSEC_BASE+25)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_AUTH_TIMERS_INVALID (WLAN_REASON_CODE_MSMSEC_BASE+26)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_INVALID_GKEY_INTV (WLAN_REASON_CODE_MSMSEC_BASE+27)
#define WLAN_REASON_CODE_MSMSEC_TRANSITION_NETWORK (WLAN_REASON_CODE_MSMSEC_BASE+28)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_KEY_UNMAPPED_CHAR (WLAN_REASON_CODE_MSMSEC_BASE+29)
#define WLAN_REASON_CODE_MSMSEC_CAPABILITY_PROFILE_AUTH (WLAN_REASON_CODE_MSMSEC_BASE+30)
#define WLAN_REASON_CODE_MSMSEC_CAPABILITY_PROFILE_CIPHER (WLAN_REASON_CODE_MSMSEC_BASE+31)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_SAFE_MODE (WLAN_REASON_CODE_MSMSEC_BASE+32)
#define WLAN_REASON_CODE_MSMSEC_CAPABILITY_PROFILE_SAFE_MODE_NIC (WLAN_REASON_CODE_MSMSEC_BASE+33)
#define WLAN_REASON_CODE_MSMSEC_CAPABILITY_PROFILE_SAFE_MODE_NW (WLAN_REASON_CODE_MSMSEC_BASE+34)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_UNSUPPORTED_AUTH (WLAN_REASON_CODE_MSMSEC_BASE+35)
#define WLAN_REASON_CODE_MSMSEC_PROFILE_UNSUPPORTED_CIPHER (WLAN_REASON_CODE_MSMSEC_BASE+36)
#define WLAN_REASON_CODE_MSMSEC_CAPABILITY_MFP_NW_NIC (WLAN_REASON_CODE_MSMSEC_BASE+37)
#define WLAN_REASON_CODE_MSMSEC_UI_REQUEST_FAILURE (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+1)
#define WLAN_REASON_CODE_MSMSEC_AUTH_START_TIMEOUT (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+2)
#define WLAN_REASON_CODE_MSMSEC_AUTH_SUCCESS_TIMEOUT (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+3)
#define WLAN_REASON_CODE_MSMSEC_KEY_START_TIMEOUT (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+4)
#define WLAN_REASON_CODE_MSMSEC_KEY_SUCCESS_TIMEOUT (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+5)
#define WLAN_REASON_CODE_MSMSEC_M3_MISSING_KEY_DATA (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+6)
#define WLAN_REASON_CODE_MSMSEC_M3_MISSING_IE (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+7)
#define WLAN_REASON_CODE_MSMSEC_M3_MISSING_GRP_KEY (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+8)
#define WLAN_REASON_CODE_MSMSEC_PR_IE_MATCHING (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+9)
#define WLAN_REASON_CODE_MSMSEC_SEC_IE_MATCHING (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+10)
#define WLAN_REASON_CODE_MSMSEC_NO_PAIRWISE_KEY (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+11)
#define WLAN_REASON_CODE_MSMSEC_G1_MISSING_KEY_DATA (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+12)
#define WLAN_REASON_CODE_MSMSEC_G1_MISSING_GRP_KEY (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+13)
#define WLAN_REASON_CODE_MSMSEC_PEER_INDICATED_INSECURE (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+14)
#define WLAN_REASON_CODE_MSMSEC_NO_AUTHENTICATOR (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+15)
#define WLAN_REASON_CODE_MSMSEC_NIC_FAILURE (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+16)
#define WLAN_REASON_CODE_MSMSEC_CANCELLED (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+17)
#define WLAN_REASON_CODE_MSMSEC_KEY_FORMAT (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+18)
#define WLAN_REASON_CODE_MSMSEC_DOWNGRADE_DETECTED (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+19)
#define WLAN_REASON_CODE_MSMSEC_PSK_MISMATCH_SUSPECTED (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+20)
#define WLAN_REASON_CODE_MSMSEC_FORCED_FAILURE (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+21)
#define WLAN_REASON_CODE_MSMSEC_M3_TOO_MANY_RSNIE (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+22)
#define WLAN_REASON_CODE_MSMSEC_M2_MISSING_KEY_DATA (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+23)
#define WLAN_REASON_CODE_MSMSEC_M2_MISSING_IE (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+24)
#define WLAN_REASON_CODE_MSMSEC_AUTH_WCN_COMPLETED (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+25)
#define WLAN_REASON_CODE_MSMSEC_M3_MISSING_MGMT_GRP_KEY (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+26)
#define WLAN_REASON_CODE_MSMSEC_G1_MISSING_MGMT_GRP_KEY (WLAN_REASON_CODE_MSMSEC_CONNECT_BASE+27)
#define WLAN_REASON_CODE_MSMSEC_MAX WLAN_REASON_CODE_MSMSEC_END

#define WLAN_AVAILABLE_NETWORK_CONNECTED 0x00000001
#define WLAN_AVAILABLE_NETWORK_HAS_PROFILE 0x00000002
#define WLAN_AVAILABLE_NETWORK_CONSOLE_USER_PROFILE 0x00000004
#define WLAN_AVAILABLE_NETWORK_INTERWORKING_SUPPORTED 0x00000008
#define WLAN_AVAILABLE_NETWORK_HOTSPOT2_ENABLED 0x00000010
#define WLAN_AVAILABLE_NETWORK_ANQP_SUPPORTED 0x00000020
#define WLAN_AVAILABLE_NETWORK_HOTSPOT2_DOMAIN 0x00000040
#define WLAN_AVAILABLE_NETWORK_HOTSPOT2_ROAMING 0x00000080
#define WLAN_AVAILABLE_NETWORK_AUTO_CONNECT_FAILED 0x00000100

#define WLAN_AVAILABLE_NETWORK_INCLUDE_ALL_ADHOC_PROFILES 0x00000001
#define WLAN_AVAILABLE_NETWORK_INCLUDE_ALL_MANUAL_HIDDEN_PROFILES 0x00000002

#define WLAN_READ_ACCESS (STANDARD_RIGHTS_READ | FILE_READ_DATA)
#define WLAN_EXECUTE_ACCESS (WLAN_READ_ACCESS | STANDARD_RIGHTS_EXECUTE | FILE_EXECUTE)
#define WLAN_WRITE_ACCESS (WLAN_READ_ACCESS | WLAN_EXECUTE_ACCESS | STANDARD_RIGHTS_WRITE | FILE_WRITE_DATA | DELETE | WRITE_DAC)

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
    wlan_notification_acm_start = L2_NOTIFICATION_CODE_PUBLIC_BEGIN,
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
    wlan_notification_acm_profile_unblocked,
    wlan_notification_acm_screen_power_change,
    wlan_notification_acm_profile_blocked,
    wlan_notification_acm_scan_list_refresh,
    wlan_notification_acm_operational_state_change,
    wlan_notification_acm_end
} WLAN_NOTIFICATION_ACM, *PWLAN_NOTIFICATION_ACM;

typedef enum _WLAN_NOTIFICATION_MSM {
  wlan_notification_msm_start = L2_NOTIFICATION_CODE_PUBLIC_BEGIN,
  wlan_notification_msm_associating,
  wlan_notification_msm_associated,
  wlan_notification_msm_authenticating,
  wlan_notification_msm_connected,
  wlan_notification_msm_roaming_start,
  wlan_notification_msm_roaming_end,
  wlan_notification_msm_radio_state_change,
  wlan_notification_msm_signal_quality_change,
  wlan_notification_msm_disassociating,
  wlan_notification_msm_disconnected,
  wlan_notification_msm_peer_join,
  wlan_notification_msm_peer_leave,
  wlan_notification_msm_adapter_removal,
  wlan_notification_msm_adapter_operation_mode_change,
  wlan_notification_msm_link_degraded,
  wlan_notification_msm_link_improved,
  wlan_notification_msm_end
} WLAN_NOTIFICATION_MSM, *PWLAN_NOTIFICATION_MSM;

typedef enum _WLAN_NOTIFICATION_SECURITY {
  wlan_notification_security_start = L2_NOTIFICATION_CODE_PUBLIC_BEGIN,
  wlan_notification_security_end
} WLAN_NOTIFICATION_SECURITY, *PWLAN_NOTIFICATION_SECURITY;

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
  wlan_intf_opcode_management_frame_protection_capable,
  wlan_intf_opcode_secondary_sta_interfaces,
  wlan_intf_opcode_secondary_sta_synchronized_connections,
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
  DOT11_AUTH_CIPHER_PAIR pAuthCipherPairList[1];
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
  WCHAR                  strProfileName[WLAN_MAX_NAME_LENGTH];
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

typedef struct _WLAN_AVAILABLE_NETWORK_V2 {
  WCHAR strProfileName[WLAN_MAX_NAME_LENGTH];
  DOT11_SSID dot11Ssid;
  DOT11_BSS_TYPE dot11BssType;
  ULONG uNumberOfBssids;
  WINBOOL bNetworkConnectable;
  WLAN_REASON_CODE wlanNotConnectableReason;
  ULONG uNumberOfPhyTypes;
  DOT11_PHY_TYPE dot11PhyTypes[WLAN_MAX_PHY_TYPE_NUMBER];
  WINBOOL bMorePhyTypes;
  WLAN_SIGNAL_QUALITY wlanSignalQuality;
  WINBOOL bSecurityEnabled;
  DOT11_AUTH_ALGORITHM dot11DefaultAuthAlgorithm;
  DOT11_CIPHER_ALGORITHM dot11DefaultCipherAlgorithm;
  DWORD dwFlags;
  DOT11_ACCESSNETWORKOPTIONS AccessNetworkOptions;
  DOT11_HESSID dot11HESSID;
  DOT11_VENUEINFO VenueInfo;
  DWORD dwReserved;
} WLAN_AVAILABLE_NETWORK_V2, *PWLAN_AVAILABLE_NETWORK_V2;

typedef struct _WLAN_AVAILABLE_NETWORK_LIST {
  DWORD                  dwNumberOfItems;
  DWORD                  dwIndex;
  WLAN_AVAILABLE_NETWORK Network[1];
} WLAN_AVAILABLE_NETWORK_LIST, *PWLAN_AVAILABLE_NETWORK_LIST;

typedef struct _WLAN_AVAILABLE_NETWORK_LIST_V2 {
  DWORD dwNumberOfItems;
  DWORD dwIndex;
  WLAN_AVAILABLE_NETWORK_V2 Network[1];
} WLAN_AVAILABLE_NETWORK_LIST_V2, *PWLAN_AVAILABLE_NETWORK_LIST_V2;

typedef struct _WLAN_SECURITY_ATTRIBUTES {
  WINBOOL                bSecurityEnabled;
  WINBOOL                bOneXEnabled;
  DOT11_AUTH_ALGORITHM   dot11AuthAlgorithm;
  DOT11_CIPHER_ALGORITHM dot11CipherAlgorithm;
} WLAN_SECURITY_ATTRIBUTES, *PWLAN_SECURITY_ATTRIBUTES;

typedef struct _WLAN_CONNECTION_ATTRIBUTES {
  WLAN_INTERFACE_STATE        isState;
  WLAN_CONNECTION_MODE        wlanConnectionMode;
  WCHAR                       strProfileName[WLAN_MAX_NAME_LENGTH];
  WLAN_ASSOCIATION_ATTRIBUTES wlanAssociationAttributes;
  WLAN_SECURITY_ATTRIBUTES    wlanSecurityAttributes;
} WLAN_CONNECTION_ATTRIBUTES, *PWLAN_CONNECTION_ATTRIBUTES;

/* Assuming stdcall */
typedef VOID (CALLBACK *WLAN_NOTIFICATION_CALLBACK)(
  PWLAN_NOTIFICATION_DATA ,
  PVOID 
);

#define WLAN_CONNECTION_NOTIFICATION_ADHOC_NETWORK_FORMED 0x00000001
#define WLAN_CONNECTION_NOTIFICATION_CONSOLE_USER_PROFILE 0x00000004

typedef struct _WLAN_CONNECTION_NOTIFICATION_DATA {
  WLAN_CONNECTION_MODE wlanConnectionMode;
  WCHAR                strProfileName[WLAN_MAX_NAME_LENGTH];
  DOT11_SSID           dot11Ssid;
  DOT11_BSS_TYPE       dot11BssType;
  WINBOOL              bSecurityEnabled;
  WLAN_REASON_CODE     wlanReasonCode;
  DWORD                dwFlags;
  WCHAR                strProfileXml[1];
} WLAN_CONNECTION_NOTIFICATION_DATA, *PWLAN_CONNECTION_NOTIFICATION_DATA;

typedef struct _WLAN_DEVICE_SERVICE_NOTIFICATION_DATA {
  GUID DeviceService;
  DWORD dwOpCode;
  DWORD dwDataSize;
  BYTE DataBlob[1];
} WLAN_DEVICE_SERVICE_NOTIFICATION_DATA, *PWLAN_DEVICE_SERVICE_NOTIFICATION_DATA;

#define WLAN_CONNECTION_HIDDEN_NETWORK 0x00000001
#define WLAN_CONNECTION_ADHOC_JOIN_ONLY 0x00000002
#define WLAN_CONNECTION_IGNORE_PRIVACY_BIT 0x00000004
#define WLAN_CONNECTION_EAPOL_PASSTHROUGH 0x00000008
#define WLAN_CONNECTION_PERSIST_DISCOVERY_PROFILE 0x00000010
#define WLAN_CONNECTION_PERSIST_DISCOVERY_PROFILE_CONNECTION_MODE_AUTO 0x00000020
#define WLAN_CONNECTION_PERSIST_DISCOVERY_PROFILE_OVERWRITE_EXISTING 0x00000040

typedef struct _WLAN_CONNECTION_PARAMETERS {
  WLAN_CONNECTION_MODE wlanConnectionMode;
  LPCWSTR              strProfile;
  PDOT11_SSID          pDot11Ssid;
  PDOT11_BSSID_LIST    pDesiredBssidList;
  DOT11_BSS_TYPE       dot11BssType;
  DWORD                dwFlags;
} WLAN_CONNECTION_PARAMETERS, *PWLAN_CONNECTION_PARAMETERS;

typedef struct _WLAN_CONNECTION_PARAMETERS_V2 {
  WLAN_CONNECTION_MODE wlanConnectionMode;
  LPCWSTR strProfile;
  PDOT11_SSID pDot11Ssid;
  PDOT11_HESSID pDot11Hessid;
  PDOT11_BSSID_LIST pDesiredBssidList;
  DOT11_BSS_TYPE dot11BssType;
  DWORD dwFlags;
  PDOT11_ACCESSNETWORKOPTIONS pDot11AccessNetworkOptions;
} WLAN_CONNECTION_PARAMETERS_V2, *PWLAN_CONNECTION_PARAMETERS_V2;

typedef struct _WLAN_INTERFACE_INFO {
  GUID                 InterfaceGuid;
  WCHAR                strInterfaceDescription[WLAN_MAX_NAME_LENGTH];
  WLAN_INTERFACE_STATE isState;
} WLAN_INTERFACE_INFO, *PWLAN_INTERFACE_INFO;

typedef struct _WLAN_INTERFACE_INFO_LIST {
  DWORD               dwNumberOfItems;
  DWORD               dwIndex;
  WLAN_INTERFACE_INFO InterfaceInfo[];
} WLAN_INTERFACE_INFO_LIST, *PWLAN_INTERFACE_INFO_LIST;

typedef struct _WLAN_PROFILE_INFO {
  WCHAR strProfileName[WLAN_MAX_NAME_LENGTH];
  DWORD dwFlags;
} WLAN_PROFILE_INFO, *PWLAN_PROFILE_INFO;

typedef struct _WLAN_PROFILE_INFO_LIST {
  DWORD             dwNumberOfItems;
  DWORD             dwIndex;
  WLAN_PROFILE_INFO ProfileInfo[1];
} WLAN_PROFILE_INFO_LIST, *PWLAN_PROFILE_INFO_LIST;

#define WFD_API_VERSION_1_0 0x00000001

#if _WIN32_WINNT >= _WIN32_WINNT_WIN8
#define WFD_API_SUPPORTED
#define WFD_API_VERSION WFD_API_VERSION_1_0
#endif

#ifdef WFD_API_SUPPORTED
  typedef enum _WFD_ROLE_TYPE {
    WFD_ROLE_TYPE_NONE = 0x00,
    WFD_ROLE_TYPE_DEVICE = 0x01,
    WFD_ROLE_TYPE_GROUP_OWNER = 0x02,
    WFD_ROLE_TYPE_CLIENT = 0x04,
    WFD_ROLE_TYPE_MAX = 0x05
  } WFD_ROLE_TYPE, *PWFD_ROLE_TYPE;
#endif

  typedef struct _WFD_GROUP_ID {
    DOT11_MAC_ADDRESS DeviceAddress;
    DOT11_SSID GroupSSID;
  } WFD_GROUP_ID, *PWFD_GROUP_ID;

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

DWORD WINAPI WlanConnect2(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  const PWLAN_CONNECTION_PARAMETERS_V2 pConnectionParameters,
  PVOID pReserved
);

DWORD WINAPI WlanDeleteProfile(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPCWSTR strProfileName,
  PVOID pReserved
);

DWORD WINAPI WlanDeviceServiceCommand(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPGUID pDeviceServiceGuid,
  DWORD dwOpCode,
  DWORD dwInBufferSize,
  PVOID pInBuffer,
  DWORD dwOutBufferSize,
  PVOID pOutBuffer,
  PDWORD pdwBytesReturned
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

DWORD WINAPI WlanGetAvailableNetworkList2(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  DWORD dwFlags,
  PVOID pReserved,
  PWLAN_AVAILABLE_NETWORK_LIST_V2 *ppAvailableNetworkList
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
} WLAN_ADHOC_NETWORK_STATE, *PWLAN_ADHOC_NETWORK_STATE;

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
  wlan_secure_hosted_network_elevated_access   = 14,
  wlan_secure_virtual_station_extensibility    = 15,
  wlan_secure_wfd_elevated_access              = 16,
  WLAN_SECURABLE_OBJECT_COUNT                  = 17
} WLAN_SECURABLE_OBJECT, *PWLAN_SECURABLE_OBJECT;

typedef struct _WLAN_DEVICE_SERVICE_GUID_LIST {
  DWORD dwNumberOfItems;
  DWORD dwIndex;
  GUID DeviceService[1];
} WLAN_DEVICE_SERVICE_GUID_LIST, *PWLAN_DEVICE_SERVICE_GUID_LIST;

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
  WINBOOL              bSecurityEnabled;
  WINBOOL              bFirstPeer;
  WINBOOL              bLastPeer;
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
  WLAN_PHY_RADIO_STATE PhyRadioState[WLAN_MAX_PHY_INDEX];
} WLAN_RADIO_STATE, *PWLAN_RADIO_STATE;

typedef enum _WLAN_OPERATIONAL_STATE {
  wlan_operational_state_unknown = 0,
  wlan_operational_state_off,
  wlan_operational_state_on,
  wlan_operational_state_going_off,
  wlan_operational_state_going_on
} WLAN_OPERATIONAL_STATE, *PWLAN_OPERATIONAL_STATE;

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

DWORD WINAPI WlanGetSupportedDeviceServices(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  PWLAN_DEVICE_SERVICE_GUID_LIST *ppDevSvcGuidList
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
  PVOID *ppData,
  PWLAN_OPCODE_VALUE_TYPE pWlanOpcodeValueType
);

DWORD WINAPI WlanRegisterDeviceServiceNotification(
  HANDLE hClientHandle,
  const PWLAN_DEVICE_SERVICE_GUID_LIST pDevSvcGuidList
);

DWORD WINAPI WlanRenameProfile(
  HANDLE hClientHandle,
  const GUID *pInterfaceGuid,
  LPCWSTR strOldProfileName,
  LPCWSTR strNewProfileName,
  PVOID pReserved
);

#define WLAN_PROFILE_GROUP_POLICY 0x00000001
#define WLAN_PROFILE_USER 0x00000002
#define WLAN_PROFILE_GET_PLAINTEXT_KEY 0x00000004
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
