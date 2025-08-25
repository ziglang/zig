/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_SLPUBLIC
#define _INC_SLPUBLIC
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef GUID SLID;

typedef enum _SL_GENUINE_STATE {
  SL_GEN_STATE_IS_GENUINE        = 0,
  SL_GEN_STATE_INVALID_LICENSE   = 1,
  SL_GEN_STATE_TAMPERED          = 2,
  SL_GEN_STATE_LAST              = 3 
} SL_GENUINE_STATE;

typedef enum _tagSLDATATYPE {
  SL_DATA_NONE       = REG_NONE,
  SL_DATA_SZ         = REG_SZ,
  SL_DATA_DWORD      = REG_DWORD,
  SL_DATA_BINARY     = REG_BINARY,
  SL_DATA_MULTI_SZ   = REG_MULTI_SZ,
  SL_DATA_SUM        = 100 
} SLDATATYPE;

typedef struct _tagSL_NONGENUINE_UI_OPTIONS {
  DWORD      cbSize;
  const SLID *pComponentId;
  HRESULT    hResultUI;
} SL_NONGENUINE_UI_OPTIONS;

HRESULT WINAPI SLAcquireGenuineTicket(
  void **ppTicketBlob,
  UINT *pcbTicketBlob,
  PCWSTR pwszTemplateId,
  PCWSTR pwszServerUrl,
  PCWSTR pwszClientToken 
);

HRESULT WINAPI SLGetGenuineInformation(
  const SLID *pAppId,
  PCWSTR pwszValueName,
  SLDATATYPE *peDataType,
  UINT *pcbValue,
  BYTE **ppbValue
);

HRESULT WINAPI SLGetInstalledSAMLicenseApplications(
  UINT *pnReturnedAppIds,
  SLID **ppReturnedAppIds
);

HRESULT WINAPI SLGetSAMLicense(
  const SLID *pApplicationId,
  UINT *pcbXmlLicenseData,
  PBYTE *ppbXmlLicenseData
);

HRESULT WINAPI SLGetWindowsInformation(
  PCWSTR pwszValueName,
  SLDATATYPE *peDataType,
  UINT *pcbValue,
  PBYTE *ppbValue
);

HRESULT WINAPI SLGetWindowsInformationDWORD(
  PCWSTR pwszValueName,
  DWORD *pdwValue
);

HRESULT WINAPI SLInstallSAMLicense(
  const SLID *pApplicationId,
  UINT cbXmlLicenseData,
  const BYTE *pbXmlLicenseData
);

HRESULT WINAPI SLIsGenuineLocal(
  const SLID *pAppId,
  SL_GENUINE_STATE *pGenuineState,
  SL_NONGENUINE_UI_OPTIONS *pUIOptions
);

HRESULT WINAPI SLSetGenuineInformation(
  const SLID *pAppId,
  PCWSTR pwszValueName,
  SLDATATYPE eDataType,
  UINT cbValue,
  const BYTE *pbValue
);

HRESULT WINAPI SLUninstallSAMLicense(
  const SLID *pApplicationId
);

#if (_WIN32_WINNT >= 0x0601)
HRESULT WINAPI SLIsGenuineLocalEx(
  const SLID *pAppId,
  const SLID pSkuId,
  SL_GENUINE_STATE *pGenuineState
);
#endif /*(_WIN32_WINNT >= 0x0601)*/

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_SLPUBLIC*/
