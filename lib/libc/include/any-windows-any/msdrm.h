/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_MSDRM
#define _INC_MSDRM
#include <msdrmdefs.h>
#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI DRMCreateClientSession(
  DRMCALLBACK pfnCallback,
  UINT uCallbackVersion,
  PWSTR wszGroupIDProviderType,
  PWSTR wszGroupID,
  DRMHSESSION *phClient
);

HRESULT WINAPI DRMAcquireIssuanceLicenseTemplate(
  DRMHSESSION hClient,
  UINT uFlags,
  VOID *pvReserved,
  UINT cReserved,
  PWSTR *pwszReserved,
  PWSTR wszURL,
  VOID *pvContext
);

HRESULT WINAPI DRMActivate(
  DRMHSESSION hClient,
  UINT uFlags,
  UINT uLangID,
  DRM_ACTSERV_INFO *pActServInfo,
  VOID *pvContext,
  HWND hParentWnd
);

HRESULT WINAPI DRMGetServiceLocation(
  DRMHSESSION hClient,
  UINT uServiceType,
  UINT uServiceLocation,
  PWSTR wszIssuanceLicense,
  UINT *puServiceURLLength,
  PWSTR wszServiceURL
);

HRESULT WINAPI DRMIsActivated(
  DRMHSESSION hClient,
  UINT uFlags,
  DRM_ACTSERV_INFO *pActServInfo
);

HRESULT WINAPI DRMCheckSecurity(
  DRMENVHANDLE hEnv,
  UINT cLevel
);

HRESULT WINAPI DRMCloseSession(
  DRMHSESSION hSession
);

HRESULT WINAPI DRMCreateLicenseStorageSession(
  DRMENVHANDLE hEnv,
  DRMHANDLE hDefaultLibrary,
  DRMHSESSION hClient,
  UINT uFlags,
  PWSTR wszIssuanceLicense,
  DRMHSESSION *phLicenseStorage
);

HRESULT WINAPI DRMDuplicateSession(
  DRMHSESSION hSessionIn,
  DRMHSESSION *phSessionOut
);

HRESULT WINAPI DRMGetClientVersion(
  DRM_CLIENT_VERSION_INFO *pDRMClientVersionInfo
);

HRESULT WINAPI DRMGetEnvironmentInfo(
  DRMENVHANDLE handle,
  PWSTR wszAttribute,
  DRMENCODINGTYPE *peEncoding,
  UINT *pcBuffer,
  BYTE *pbBuffer
);

HRESULT WINAPI DRMGetIntervalTime(
  DRMPUBHANDLE hIssuanceLicense,
  UINT *pcDays
);

HRESULT WINAPI DRMGetOwnerLicense(
  DRMPUBHANDLE hIssuanceLicense,
  UINT *puLength,
  PWSTR wszOwnerLicense
);

HRESULT WINAPI DRMGetProcAddress(
  DRMHANDLE hLibrary,
  PWSTR wszProcName,
  FARPROC *ppfnProcAddress
);

HRESULT WINAPI DRMGetSecurityProvider(
  UINT uFlags,
  UINT *puTypeLen,
  PWSTR wszType,
  UINT *puPathLen,
  PWSTR wszPath
);

HRESULT WINAPI DRMInitEnvironment(
  DRMSECURITYPROVIDERTYPE eSecurityProviderType,
  DRMSPECTYPE eSpecification,
  PWSTR wszSecurityProvider,
  PWSTR wszManifestCredentials,
  PWSTR wszMachineCredentials,
  DRMENVHANDLE *phEnv,
  DRMHANDLE *phDefaultLibrary
);

HRESULT WINAPI DRMLoadLibrary(
  DRMENVHANDLE hEnv,
  DRMSPECTYPE eSpecification,
  PWSTR wszLibraryProvider,
  PWSTR wszCredentials,
  DRMHANDLE *phLibrary
);

HRESULT WINAPI DRMRegisterContent(
  WINBOOL fRegister
);

HRESULT WINAPI DRMRegisterRevocationList(
  DRMENVHANDLE hEnv,
  PWSTR wszRevocationList
);

HRESULT WINAPI DRMRepair(void);

HRESULT WINAPI DRMSetIntervalTime(
  DRMPUBHANDLE hIssuanceLicense,
  UINT cDays
);

HRESULT WINAPI DRMSetGlobalOptions(
  DRMGLOBALOPTIONS eGlobalOptions,
  LPVOID pvdata,
  DWORD dwlen
);

HRESULT WINAPI DRMAddRightWithUser(
  DRMPUBHANDLE hIssuanceLicense,
  DRMPUBHANDLE hRight,
  DRMPUBHANDLE hUser
);

HRESULT WINAPI DRMClearAllRights(
  DRMPUBHANDLE hIssuanceLicense
);

HRESULT WINAPI DRMCreateIssuanceLicense(
  SYSTEMTIME *pstTimeFrom,
  SYSTEMTIME *pstTimeUntil,
  PWSTR wszReferralInfoName,
  PWSTR wszReferralInfoURL,
  DRMPUBHANDLE hOwner,
  PWSTR wszIssuanceLicense,
  DRMHANDLE hBoundLicense,
  DRMPUBHANDLE *phIssuanceLicense
);

HRESULT WINAPI DRMCreateRight(
  PWSTR wszRightName,
  SYSTEMTIME *pstFrom,
  SYSTEMTIME *pstUntil,
  UINT cExtendedInfo,
  PWSTR *pwszExtendedInfoName,
  PWSTR *pwszExtendedInfoValue,
  DRMPUBHANDLE *phRight
);

HRESULT WINAPI DRMCreateUser(
  PWSTR wszUserName,
  PWSTR wszUserId,
  PWSTR wszUserIdType,
  DRMPUBHANDLE *phUser
);

HRESULT WINAPI DRMGetApplicationSpecificData(
  DRMPUBHANDLE hIssuanceLicense,
  UINT uIndex,
  UINT *puNameLength,
  PWSTR wszName,
  UINT *puValueLength,
  PWSTR wszValue
);

HRESULT WINAPI DRMGetIssuanceLicenseInfo(
  DRMPUBHANDLE hIssuanceLicense,
  SYSTEMTIME *pstTimeFrom,
  SYSTEMTIME *pstTimeUntil,
  UINT uFlags,
  UINT *puDistributionPointNameLength,
  PWSTR wszDistributionPointName,
  UINT *puDistributionPointURLLength,
  PWSTR wszDistributionPointURL,
  DRMPUBHANDLE *phOwner,
  WINBOOL *pfOfficial
);

HRESULT WINAPI DRMGetIssuanceLicenseTemplate(
  DRMPUBHANDLE hIssuanceLicense,
  UINT *puIssuanceLicenseTemplateLength,
  PWSTR wszIssuanceLicenseTemplate
);

HRESULT WINAPI DRMGetMetaData(
  DRMPUBHANDLE hIssuanceLicense,
  UINT *puContentIdLength,
  PWSTR wszContentId,
  UINT *puContentIdTypeLength,
  PWSTR wszContentIdType,
  UINT *puSKUIdLength,
  PWSTR wszSKUId,
  UINT *puSKUIdTypeLength,
  PWSTR wszSKUIdType,
  UINT *puContentTypeLength,
  PWSTR wszContentType,
  UINT *puContentNameLength,
  PWSTR wszContentName
);

HRESULT WINAPI DRMGetNameAndDescription(
  DRMPUBHANDLE hIssuanceLicense,
  UINT uIndex,
  UINT *pulcid,
  UINT *puNameLength,
  PWSTR wszName,
  UINT *puDescriptionLength,
  PWSTR wszDescription
);

HRESULT WINAPI DRMGetRevocationPoint(
  DRMPUBHANDLE hIssuanceLicense,
  UINT *puIdLength,
  PWSTR wszId,
  UINT *puIdTypeLength,
  PWSTR wszIdType,
  UINT *puURLLength,
  PWSTR wszURL,
  SYSTEMTIME *pstFrequency,
  UINT *puNameLength,
  PWSTR wszName,
  UINT *puPublicKeyLength,
  PWSTR wszPublicKey
);

HRESULT WINAPI DRMGetRightExtendedInfo(
  DRMPUBHANDLE hRight,
  UINT uIndex,
  UINT *puExtendedInfoNameLength,
  PWSTR wszExtendedInfoName,
  UINT *puExtendedInfoValueLength,
  PWSTR wszExtendedInfoValue
);

HRESULT WINAPI DRMGetRightInfo(
  DRMPUBHANDLE hRight,
  UINT *puRightNameLength,
  PWSTR wszRightName,
  SYSTEMTIME *pstFrom,
  SYSTEMTIME *pstUntil
);

HRESULT WINAPI DRMGetSignedIssuanceLicense(
  DRMENVHANDLE hEnv,
  DRMPUBHANDLE hIssuanceLicense,
  UINT uFlags,
  BYTE *pbSymKey,
  UINT cbSymKey,
  PWSTR wszSymKeyType,
  PWSTR wszClientLicensorCertificate,
  DRMCALLBACK pfnCallback,
  PWSTR wszURL,
  VOID *pvContext
);

HRESULT WINAPI DRMGetUsagePolicy(
  DRMPUBHANDLE hIssuanceLicense,
  UINT uIndex,
  DRM_USAGEPOLICY_TYPE *peUsagePolicyType,
  WINBOOL *pfExclusion,
  UINT *puNameLength,
  PWSTR wszName,
  UINT *puMinVersionLength,
  PWSTR wszMinVersion,
  UINT *puMaxVersionLength,
  PWSTR wszMaxVersion,
  UINT *puPublicKeyLength,
  PWSTR wszPublicKey,
  UINT *puDigestAlgorithmLength,
  PWSTR wszDigestAlgorithm,
  UINT *pcbDigest,
  BYTE *pbDigest
);

HRESULT WINAPI DRMGetUserInfo(
  DRMPUBHANDLE hUser,
  UINT *puUserNameLength,
  PWSTR wszUserName,
  UINT *puUserIdLength,
  PWSTR wszUserId,
  UINT *puUserIdTypeLength,
  PWSTR wszUserIdType
);

HRESULT WINAPI DRMGetUserRights(
  DRMPUBHANDLE hIssuanceLicense,
  DRMPUBHANDLE hUser,
  UINT uIndex,
  DRMPUBHANDLE *phRight
);

HRESULT WINAPI DRMGetUsers(
  DRMPUBHANDLE hIssuanceLicense,
  UINT uIndex,
  DRMPUBHANDLE *phUser
);

HRESULT WINAPI DRMSetApplicationSpecificData(
  DRMPUBHANDLE hIssuanceLicense,
  WINBOOL fDelete,
  PWSTR wszName,
  PWSTR wszValue
);

HRESULT WINAPI DRMSetMetaData(
  DRMPUBHANDLE hIssuanceLicense,
  PWSTR wszContentId,
  PWSTR wszContentIdType,
  PWSTR wszSKUId,
  PWSTR wszSKUIdType,
  PWSTR wszContentType,
  PWSTR wszContentName
);

HRESULT WINAPI DRMSetNameAndDescription(
  DRMPUBHANDLE hIssuanceLicense,
  WINBOOL fDelete,
  UINT lcid,
  PWSTR wszName,
  PWSTR wszDescription
);

HRESULT WINAPI DRMSetRevocationPoint(
  DRMPUBHANDLE hIssuanceLicense,
  WINBOOL fDelete,
  PWSTR wszId,
  PWSTR wszIdType,
  PWSTR wszURL,
  SYSTEMTIME *pstFrequency,
  PWSTR wszName,
  PWSTR wszPublicKey
);

HRESULT WINAPI DRMSetUsagePolicy(
  DRMPUBHANDLE hIssuanceLicense,
  DRM_USAGEPOLICY_TYPE eUsagePolicyType,
  WINBOOL fDelete,
  WINBOOL fExclusion,
  PWSTR wszName,
  PWSTR wszMinVersion,
  PWSTR wszMaxVersion,
  PWSTR wszPublicKey,
  PWSTR wszDigestAlgorithm,
  BYTE *pbDigest,
  UINT cbDigest
);

HRESULT WINAPI DRMCloseEnvironmentHandle(
  DRMENVHANDLE hEnv
);

HRESULT WINAPI DRMCloseHandle(
  DRMHANDLE handle
);

HRESULT WINAPI DRMClosePubHandle(
  DRMPUBHANDLE hPub
);

HRESULT WINAPI DRMCloseQueryHandle(
  DRMQUERYHANDLE hQuery
);

HRESULT WINAPI DRMDuplicateEnvironmentHandle(
  DRMENVHANDLE hToCopy,
  DRMENVHANDLE *phCopy
);

HRESULT WINAPI DRMDuplicateHandle(
  DRMHANDLE hToCopy,
  DRMHANDLE *phCopy
);

HRESULT WINAPI DRMDuplicatePubHandle(
  DRMPUBHANDLE hPubIn,
  DRMPUBHANDLE *phPubOut
);

HRESULT WINAPI DRMGetUnboundLicenseAttribute(
  DRMQUERYHANDLE hQueryRoot,
  PWSTR wszAttributeType,
  UINT iWhich,
  DRMENCODINGTYPE *peEncoding,
  UINT *pcBuffer,
  BYTE *pbBuffer
);

HRESULT WINAPI DRMGetUnboundLicenseAttributeCount(
  DRMQUERYHANDLE hQueryRoot,
  PWSTR wszAttributeType,
  UINT *pcAttributes
);

HRESULT WINAPI DRMGetUnboundLicenseObject(
  DRMQUERYHANDLE hQueryRoot,
  PWSTR wszSubObjectType,
  UINT iIndex,
  DRMQUERYHANDLE *phSubQuery
);

HRESULT WINAPI DRMGetUnboundLicenseObjectCount(
  DRMQUERYHANDLE hQueryRoot,
  PWSTR wszSubObjectType,
  UINT *pcSubObjects
);

HRESULT WINAPI DRMParseUnboundLicense(
  PWSTR wszCertificate,
  DRMQUERYHANDLE *phQueryRoot
);

HRESULT WINAPI DRMCreateBoundLicense(
  DRMENVHANDLE hEnv,
  DRMBOUNDLICENSEPARAMS *pParams,
  PWSTR wszLicenseChain,
  DRMHANDLE *phBoundLicense,
  DRMHANDLE *phErrorLog
);

HRESULT WINAPI DRMCreateEnablingPrincipal(
  DRMENVHANDLE hEnv,
  DRMHANDLE hLibrary,
  PWSTR wszObject,
  DRMID *pidPrincipal,
  PWSTR wszCredentials,
  DRMHANDLE *pHEnablingPrincipal
);

HRESULT WINAPI DRMGetBoundLicenseAttribute(
  DRMHANDLE hQueryRoot,
  PWSTR wszAttribute,
  UINT iWhich,
  DRMENCODINGTYPE *peEncoding,
  UINT *pcBuffer,
  BYTE *pbBuffer
);

HRESULT WINAPI DRMGetBoundLicenseAttributeCount(
  DRMHANDLE hQueryRoot,
  PWSTR wszAttribute,
  UINT *pcAttributes
);

HRESULT WINAPI DRMGetBoundLicenseObject(
  DRMHANDLE hQueryRoot,
  PWSTR wszSubObjectType,
  UINT iWhich,
  DRMHANDLE *phSubObject
);

HRESULT WINAPI DRMGetBoundLicenseObjectCount(
  DRMHANDLE hQueryRoot,
  PWSTR wszSubObjectType,
  UINT *pcSubObject
);

HRESULT WINAPI DRMAcquireAdvisories(
  DRMHSESSION hLicenseStorage,
  PWSTR wszLicense,
  PWSTR wszURL,
  VOID *pvContext
);

HRESULT WINAPI DRMAcquireLicense(
  DRMHSESSION hSession,
  UINT uFlags,
  PWSTR wszGroupIdentityCredential,
  PWSTR wszRequestedRights,
  PWSTR wszCustomData,
  PWSTR wszURL,
  VOID *pvContext
);

HRESULT WINAPI DRMAddLicense(
  DRMHSESSION hLicenseStorage,
  UINT uFlags,
  PWSTR wszLicense
);

HRESULT WINAPI DRMConstructCertificateChain(
  UINT cCertificates,
  PWSTR *rgwszCertificates,
  UINT *pcChain,
  PWSTR wszChain
);

HRESULT WINAPI DRMDeconstructCertificateChain(
  PWSTR wszChain,
  UINT iWhich,
  UINT *pcCert,
  PWSTR wszCert
);

HRESULT WINAPI DRMDeleteLicense(
  DRMHSESSION hSession,
  PWSTR wszLicenseId
);

HRESULT WINAPI DRMEnumerateLicense(
  DRMHSESSION hSession,
  UINT uFlags,
  UINT uIndex,
  WINBOOL *pfSharedFlag,
  UINT *puCertificateDataLen,
  PWSTR wszCertificateData
);

HRESULT WINAPI DRMGetCertificateChainCount(
  PWSTR wszChain,
  UINT *pcCertCount
);

HRESULT WINAPI DRMAttest(
  DRMHANDLE hEnablingPrincipal,
  PWSTR wszData,
  DRMATTESTTYPE eType,
  UINT *pcStrLen,
  PWSTR wszAttestedBlob
);

HRESULT WINAPI DRMCreateEnablingBitsDecryptor(
  DRMHANDLE hBoundLicense,
  PWSTR wszRight,
  DRMHANDLE hAuxLib,
  PWSTR wszAuxPlug,
  DRMHANDLE *phDecryptor
);

HRESULT WINAPI DRMCreateEnablingBitsEncryptor(
  DRMHANDLE hBoundLicense,
  PWSTR wszRight,
  DRMHANDLE hAuxLib,
  PWSTR wszAuxPlug,
  DRMHANDLE *phEncryptor
);

HRESULT WINAPI DRMDecrypt(
  DRMHANDLE hCryptoProvider,
  UINT iPosition,
  UINT cNumInBytes,
  BYTE *pbInData,
  UINT *pcNumOutBytes,
  BYTE *pbOutData
);

HRESULT WINAPI DRMEncrypt(
  DRMHANDLE hCryptoProvider,
  UINT iPosition,
  UINT cNumInBytes,
  BYTE *pbInData,
  UINT *pcNumOutBytes,
  BYTE *pbOutData
);

HRESULT WINAPI DRMVerify(
  PWSTR wszData,
  UINT *pcStrLenAttestedData,
  PWSTR wszAttestedData,
  DRMATTESTTYPE *peType,
  UINT *pcPrincipalChain,
  PWSTR wszPrincipalChain,
  UINT *pcManifestChain,
  PWSTR wszManifestChain
);

HRESULT WINAPI DRMDecode(
  PWSTR wszAlgID,
  PWSTR wszEncodedString,
  UINT *puDecodedDataLen,
  BYTE *pbDecodedData
);

HRESULT WINAPI DRMEncode(
  PWSTR wszAlgID,
  UINT uDataLen,
  BYTE *pbDecodedData,
  UINT *puEncodedStringLen,
  PWSTR wszEncodedString
);

HRESULT WINAPI DRMGetInfo(
  DRMHANDLE handle,
  PWSTR wszAttribute,
  DRMENCODINGTYPE *peEncoding,
  UINT *pcBuffer,
  BYTE *pbBuffer
);

HRESULT WINAPI DRMGetTime(
  DRMENVHANDLE hEnv,
  DRMTIMETYPE eTimerIdType,
  SYSTEMTIME *poTimeObject
);

#if (_WIN32_WINNT >= 0x0600)
HRESULT WINAPI DRMIsWindowProtected(
  HWND hwnd,
  WINBOOL *pfProtected
);

HRESULT WINAPI DRMRegisterProtectedWindow(
  DRMENVHANDLE hEnv,
  HWND hwnd
);

HRESULT WINAPI DRMAcquireIssuanceLicenseTemplate(
  DRMHSESSION hClient,
  UINT uFlags,
  VOID *pvReserved,
  UINT cReserved,
  PWSTR *pwszReserved,
  PWSTR wszURL,
  VOID *pvContext
);

#endif /*(_WIN32_WINNT >= 0x0600)*/
#if (_WIN32_WINNT >= 0x0601)
HRESULT WINAPI DRMGetSignedIssuanceLicenseEx(
  DRMENVHANDLE hEnv,
  DRMPUBHANDLE hIssuanceLicense,
  UINT uFlags,
  BYTE *pbSymKey,
  UINT cbSymKey,
  PWSTR wszSymKeyType,
  VOID *pvReserved,
  DRMHANDLE hEnablingPrincipal,
  DRMHANDLE hBoundLicense,
  DRMCALLBACK pfnCallback,
  VOID *pvContext
);
#endif /*(_WIN32_WINNT >= 0x0601)*/

#ifdef __cplusplus
}
#endif
#endif /*_INC_MSDRM*/
