/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __INC_ELSCORE__
#define __INC_ELSCORE__

#include <objbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef ELSCOREAPI
#define ELSCOREAPI DECLSPEC_IMPORT
#endif

#ifndef CALLBACK
#define CALLBACK WINAPI
#endif

/* MAPPING_ENUM_OPTIONS.ServiceType */
#define ALL_SERVICE_TYPES 0
#define HIGHLEVEL_SERVICE_TYPES 1
#define LOWLEVEL_SERVICE_TYPES 2

/* MAPPING_ENUM_OPTIONS.OnlineService */
#define ALL_SERVICES 0
#define ONLINE_SERVICES 1
#define OFFLINE_SERVICES 2

typedef struct _MAPPING_DATA_RANGE {
  DWORD  dwStartIndex;
  DWORD  dwEndIndex;
  LPWSTR pszDescription;
  DWORD  dwDescriptionLength;
  LPVOID pData;
  DWORD  dwDataSize;
  LPWSTR pszContentType;
  LPWSTR *prgActionIds;
  DWORD  dwActionsCount;
  LPWSTR *prgActionDisplayNames;
} MAPPING_DATA_RANGE, *PMAPPING_DATA_RANGE;

typedef struct _MAPPING_ENUM_OPTIONS {
  size_t   Size;
  LPWSTR   pszCategory;
  LPWSTR   pszInputLanguage;
  LPWSTR   pszOutputLanguage;
  LPWSTR   pszInputScript;
  LPWSTR   pszOutputScript;
  LPWSTR   pszInputContentType;
  LPWSTR   pszOutputContentType;
  GUID     *pGuid;
  unsigned OnlineService  :2;
  unsigned ServiceType  :2;
} MAPPING_ENUM_OPTIONS, *PMAPPING_ENUM_OPTIONS;

typedef struct _MAPPING_PROPERTY_BAG {
  size_t              Size;
  PMAPPING_DATA_RANGE prgResultRanges;
  DWORD               dwRangesCount;
  LPVOID              pServiceData;
  DWORD               dwServiceDataSize;
  LPVOID              pCallerData;
  DWORD               dwCallerDataSize;
  LPVOID              pContext;
} MAPPING_PROPERTY_BAG, *PMAPPING_PROPERTY_BAG;

typedef void (CALLBACK *PFN_MAPPINGCALLBACKPROC)(
  MAPPING_PROPERTY_BAG *pBag,
  LPVOID data,
  DWORD dwDataSize,
  HRESULT Result
);

typedef struct _MAPPING_OPTIONS {
  size_t                  Size;
  LPWSTR                  pszInputLanguage;
  LPWSTR                  pszOutputLanguage;
  LPWSTR                  pszInputScript;
  LPWSTR                  pszOutputScript;
  LPWSTR                  pszInputContentType;
  LPWSTR                  pszOutputContentType;
  LPWSTR                  pszUILanguage;
  PFN_MAPPINGCALLBACKPROC pfnRecognizeCallback;
  LPVOID                  pRecognizeCallerData;
  DWORD                   dwRecognizeCallerDataSize;
  PFN_MAPPINGCALLBACKPROC pfnActionCallback;
  LPVOID                  pActionCallerData;
  DWORD                   dwActionCallerDataSize;
  DWORD                   dwServiceFlag;
  unsigned                GetActionDisplayName  :1;
} MAPPING_OPTIONS, *PMAPPING_OPTIONS;

typedef struct _MAPPING_SERVICE_INFO {
  size_t   Size;
  LPWSTR   pszCopyright;
  WORD     wMajorVersion;
  WORD     wMinorVersion;
  WORD     wBuildVersion;
  WORD     wStepVersion;
  DWORD    dwInputContentTypesCount;
  LPWSTR   *prgInputContentTypes;
  DWORD    dwOutputContentTypesCount;
  LPWSTR   *prgOutputContentTypes;
  DWORD    dwInputLanguagesCount;
  LPWSTR   *prgInputLanguages;
  DWORD    dwOutputLanguagesCount;
  LPWSTR   *prgOutputLanguages;
  DWORD    dwInputScriptsCount;
  LPWSTR   *prgInputScripts;
  DWORD    dwOutputScriptsCount;
  LPWSTR   *prgOutputScripts;
  GUID     guid;
  LPWSTR   pszCategory;
  LPWSTR   pszDescription;
  DWORD    dwPrivateDataSize;
  LPVOID   pPrivateData;
  LPVOID   pContext;
  unsigned IsOneToOneLanguageMapping  :1;
  unsigned HasSubservices  :1;
  unsigned OnlineOnly  :1;
  unsigned ServiceType  :2;
} MAPPING_SERVICE_INFO, *PMAPPING_SERVICE_INFO;

ELSCOREAPI HRESULT WINAPI MappingRecognizeText(
  PMAPPING_SERVICE_INFO pServiceInfo,
  LPCWSTR pszText,
  DWORD dwLength,
  DWORD dwIndex,
  PMAPPING_OPTIONS pOptions,
  PMAPPING_PROPERTY_BAG pBag
);

ELSCOREAPI HRESULT WINAPI MappingDoAction(
  PMAPPING_PROPERTY_BAG pBag,
  DWORD dwRangeIndex,
  LPCWSTR pszActionId
);

ELSCOREAPI HRESULT WINAPI MappingFreePropertyBag(
  PMAPPING_PROPERTY_BAG pBag
);

ELSCOREAPI HRESULT WINAPI MappingFreeServices(
  PMAPPING_SERVICE_INFO pServiceInfo
);

ELSCOREAPI HRESULT WINAPI MappingGetServices(
  PMAPPING_ENUM_OPTIONS pOptions,
  PMAPPING_SERVICE_INFO *prgServices,
  DWORD *pdwServicesCount
);

#ifdef __cplusplus
}
#endif

#endif /*__INC_ELSCORE__*/
