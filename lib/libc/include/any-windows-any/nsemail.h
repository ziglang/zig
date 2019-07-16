/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_NSEMAIL
#define _INC_NSEMAIL

#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef enum _tag_NAPI_PROVIDER_TYPE {
  ProviderType_Application   = 1,
  ProviderType_Service 
} NAPI_PROVIDER_TYPE;

typedef enum _tag_NAPI_PROVIDER_LEVEL {
  ProviderLevel_None        = 0,
  ProviderLevel_Secondary,
  ProviderLevel_Primary 
} NAPI_PROVIDER_LEVEL;

typedef struct _NAPI_DOMAIN_DESCRIPTION_BLOB {
  DWORD AuthLevel;
  DWORD cchDomainName;
  DWORD OffsetNextDomainDescription;
  DWORD OffsetThisDomainName;
} NAPI_DOMAIN_DESCRIPTION_BLOB, *PNAPI_DOMAIN_DESCRIPTION_BLOB;

typedef struct _NAPI_PROVIDER_INSTALLATION_BLOB {
  DWORD dwVersion;
  DWORD dwProviderType;
  DWORD fSupportsWildCard;
  DWORD cDomains;
  DWORD OffsetFirstDomain;
} NAPI_PROVIDER_INSTALLATION_BLOB, *PNAPI_PROVIDER_INSTALLATION_BLOB;

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_NSEMAIL*/
