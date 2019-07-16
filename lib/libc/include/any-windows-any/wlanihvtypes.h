/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef __WLANIHVTYPES_H__
#define __WLANIHVTYPES_H__

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <eaptypes.h>
#include <wlantypes.h>

#define MS_MAX_PROFILE_NAME_LENGTH 256

#define MS_PROFILE_GROUP_POLICY 0x1
#define MS_PROFILE_USER 0x2

typedef struct _DOT11_MSSECURITY_SETTINGS {
  DOT11_AUTH_ALGORITHM dot11AuthAlgorithm;
  DOT11_CIPHER_ALGORITHM dot11CipherAlgorithm;
  WINBOOL fOneXEnabled;
  EAP_METHOD_TYPE eapMethodType;
  DWORD dwEapConnectionDataLen;
#ifdef __WIDL__
  [size_is (dwEapConnectionDataLen)]
#endif
  BYTE *pEapConnectionData;
} DOT11_MSSECURITY_SETTINGS, *PDOT11_MSSECURITY_SETTINGS;

typedef struct _DOT11EXT_IHV_SSID_LIST {
  ULONG ulCount;
#ifdef __WIDL__
  [unique, size_is (ulCount)] DOT11_SSID SSIDs[*];
#else
  DOT11_SSID SSIDs[1];
#endif
} DOT11EXT_IHV_SSID_LIST, *PDOT11EXT_IHV_SSID_LIST;

typedef struct _DOT11EXT_IHV_PROFILE_PARAMS {
  PDOT11EXT_IHV_SSID_LIST pSsidList;
  DOT11_BSS_TYPE BssType;
  PDOT11_MSSECURITY_SETTINGS pMSSecuritySettings;
} DOT11EXT_IHV_PROFILE_PARAMS, *PDOT11EXT_IHV_PROFILE_PARAMS;

typedef struct _DOT11EXT_IHV_PARAMS {
  DOT11EXT_IHV_PROFILE_PARAMS dot11ExtIhvProfileParams;
  WCHAR wstrProfileName[MS_MAX_PROFILE_NAME_LENGTH];
  DWORD dwProfileTypeFlags;
  GUID interfaceGuid;
} DOT11EXT_IHV_PARAMS, *PDOT11EXT_IHV_PARAMS;
#endif

#endif
