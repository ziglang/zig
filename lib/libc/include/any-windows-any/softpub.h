/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef SOFTPUB_H
#define SOFTPUB_H

#include <wintrust.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <pshpack8.h>

#define SP_POLICY_PROVIDER_DLL_NAME L"WINTRUST.DLL"

#define WINTRUST_ACTION_GENERIC_VERIFY_V2 { 0xaac56b,0xcd44,0x11d0,{ 0x8c,0xc2,0x0,0xc0,0x4f,0xc2,0x95,0xee } }

#define SP_INIT_FUNCTION L"SoftpubInitialize"
#define SP_OBJTRUST_FUNCTION L"SoftpubLoadMessage"
#define SP_SIGTRUST_FUNCTION L"SoftpubLoadSignature"
#define SP_CHKCERT_FUNCTION L"SoftpubCheckCert"
#define SP_FINALPOLICY_FUNCTION L"SoftpubAuthenticode"
#define SP_CLEANUPPOLICY_FUNCTION L"SoftpubCleanup"

#define WINTRUST_ACTION_TRUSTPROVIDER_TEST { 0x573e31f8,0xddba,0x11d0,{ 0x8c,0xcb,0x0,0xc0,0x4f,0xc2,0x95,0xee } }

#define SP_TESTDUMPPOLICY_FUNCTION_TEST L"SoftpubDumpStructure"

#define WINTRUST_ACTION_GENERIC_CERT_VERIFY { 0x189a3842,0x3041,0x11d1,{ 0x85,0xe1,0x0,0xc0,0x4f,0xc2,0x95,0xee } }

#define SP_GENERIC_CERT_INIT_FUNCTION L"SoftpubDefCertInit"

#define WINTRUST_ACTION_GENERIC_CHAIN_VERIFY { 0xfc451c16,0xac75,0x11d1,{ 0xb4,0xb8,0x00,0xc0,0x4f,0xb6,0x6e,0xa0 } }
#define GENERIC_CHAIN_FINALPOLICY_FUNCTION L"GenericChainFinalProv"
#define GENERIC_CHAIN_CERTTRUST_FUNCTION L"GenericChainCertificateTrust"

  typedef struct _WTD_GENERIC_CHAIN_POLICY_SIGNER_INFO
    WTD_GENERIC_CHAIN_POLICY_SIGNER_INFO,*PWTD_GENERIC_CHAIN_POLICY_SIGNER_INFO;

  struct _WTD_GENERIC_CHAIN_POLICY_SIGNER_INFO {
    __C89_NAMELESS union {
      DWORD cbStruct;
      DWORD cbSize;
    };
    PCCERT_CHAIN_CONTEXT pChainContext;
    DWORD dwSignerType;
    PCMSG_SIGNER_INFO pMsgSignerInfo;
    DWORD dwError;
    DWORD cCounterSigner;
    PWTD_GENERIC_CHAIN_POLICY_SIGNER_INFO *rgpCounterSigner;
  };

  typedef HRESULT (WINAPI *PFN_WTD_GENERIC_CHAIN_POLICY_CALLBACK)(PCRYPT_PROVIDER_DATA pProvData,DWORD dwStepError,DWORD dwRegPolicySettings,DWORD cSigner,PWTD_GENERIC_CHAIN_POLICY_SIGNER_INFO *rgpSigner,void *pvPolicyArg);

  typedef struct _WTD_GENERIC_CHAIN_POLICY_CREATE_INFO {
    __C89_NAMELESS union {
      DWORD cbStruct;
      DWORD cbSize;
    };
    HCERTCHAINENGINE hChainEngine;
    PCERT_CHAIN_PARA pChainPara;
    DWORD dwFlags;
    void *pvReserved;
  } WTD_GENERIC_CHAIN_POLICY_CREATE_INFO,*PWTD_GENERIC_CHAIN_POLICY_CREATE_INFO;

  typedef struct _WTD_GENERIC_CHAIN_POLICY_DATA {
    __C89_NAMELESS union {
      DWORD cbStruct;
      DWORD cbSize;
    };
    PWTD_GENERIC_CHAIN_POLICY_CREATE_INFO pSignerChainInfo;
    PWTD_GENERIC_CHAIN_POLICY_CREATE_INFO pCounterSignerChainInfo;
    PFN_WTD_GENERIC_CHAIN_POLICY_CALLBACK pfnPolicyCallback;
    void *pvPolicyArg;
  } WTD_GENERIC_CHAIN_POLICY_DATA,*PWTD_GENERIC_CHAIN_POLICY_DATA;

#define HTTPSPROV_ACTION { 0x573e31f8,0xaaba,0x11d0,{ 0x8c,0xcb,0x0,0xc0,0x4f,0xc2,0x95,0xee } }

#define HTTPS_FINALPOLICY_FUNCTION L"HTTPSFinalProv"
#define HTTPS_CHKCERT_FUNCTION L"HTTPSCheckCertProv"
#define HTTPS_CERTTRUST_FUNCTION L"HTTPSCertificateTrust"

#define OFFICESIGN_ACTION_VERIFY { 0x5555c2cd,0x17fb,0x11d1,{ 0x85,0xc4,0x0,0xc0,0x4f,0xc2,0x95,0xee } }

#define OFFICE_POLICY_PROVIDER_DLL_NAME SP_POLICY_PROVIDER_DLL_NAME
#define OFFICE_INITPROV_FUNCTION L"OfficeInitializePolicy"
#define OFFICE_CLEANUPPOLICY_FUNCTION L"OfficeCleanupPolicy"

#define DRIVER_ACTION_VERIFY { 0xf750e6c3,0x38ee,0x11d1,{ 0x85,0xe5,0x0,0xc0,0x4f,0xc2,0x95,0xee } }

#define DRIVER_INITPROV_FUNCTION L"DriverInitializePolicy"
#define DRIVER_FINALPOLPROV_FUNCTION L"DriverFinalPolicy"
#define DRIVER_CLEANUPPOLICY_FUNCTION L"DriverCleanupPolicy"

  typedef struct DRIVER_VER_MAJORMINOR_ {
    DWORD dwMajor;
    DWORD dwMinor;
  } DRIVER_VER_MAJORMINOR;

  typedef struct DRIVER_VER_INFO_ {
    DWORD cbStruct;
    ULONG_PTR dwReserved1;
    ULONG_PTR dwReserved2;
    DWORD dwPlatform;
    DWORD dwVersion;
    WCHAR wszVersion[MAX_PATH];
    WCHAR wszSignedBy[MAX_PATH];
    PCCERT_CONTEXT pcSignerCertContext;
    DRIVER_VER_MAJORMINOR sOSVersionLow;
    DRIVER_VER_MAJORMINOR sOSVersionHigh;
    DWORD dwBuildNumberLow;
    DWORD dwBuildNumberHigh;
  } DRIVER_VER_INFO,*PDRIVER_VER_INFO;

#include <poppack.h>

#ifdef __cplusplus
}
#endif
#endif
