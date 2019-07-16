/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef WINTRUST_H
#define WINTRUST_H

#include <wincrypt.h>

#ifdef __cplusplus
extern "C"
{
#endif

#ifndef WIN_CERT_REVISION_1_0
#define WT_DEFINE_ALL_APIS
#else
#undef WT_DEFINE_ALL_APIS
#endif

#include <pshpack8.h>

#define WTD_UI_ALL 1
#define WTD_UI_NONE 2
#define WTD_UI_NOBAD 3
#define WTD_UI_NOGOOD 4

#define WTD_REVOKE_NONE 0x00000000
#define WTD_REVOKE_WHOLECHAIN 0x00000001

#define WTD_CHOICE_FILE 1
#define WTD_CHOICE_CATALOG 2
#define WTD_CHOICE_BLOB 3
#define WTD_CHOICE_SIGNER 4
#define WTD_CHOICE_CERT 5

#define WTD_STATEACTION_IGNORE 0x00000000
#define WTD_STATEACTION_VERIFY 0x00000001
#define WTD_STATEACTION_CLOSE 0x00000002
#define WTD_STATEACTION_AUTO_CACHE 0x00000003
#define WTD_STATEACTION_AUTO_CACHE_FLUSH 0x00000004

#define WTD_PROV_FLAGS_MASK 0x0000FFFF
#define WTD_USE_IE4_TRUST_FLAG 0x00000001
#define WTD_NO_IE4_CHAIN_FLAG 0x00000002
#define WTD_NO_POLICY_USAGE_FLAG 0x00000004
#define WTD_REVOCATION_CHECK_NONE 0x00000010
#define WTD_REVOCATION_CHECK_END_CERT 0x00000020
#define WTD_REVOCATION_CHECK_CHAIN 0x00000040
#define WTD_REVOCATION_CHECK_CHAIN_EXCLUDE_ROOT 0x00000080
#define WTD_SAFER_FLAG 0x00000100
#define WTD_HASH_ONLY_FLAG 0x00000200
#define WTD_USE_DEFAULT_OSVER_CHECK 0x00000400
#define WTD_LIFETIME_SIGNING_FLAG 0x00000800
#define WTD_CACHE_ONLY_URL_RETRIEVAL 0x00001000

#define WTD_UICONTEXT_EXECUTE 0
#define WTD_UICONTEXT_INSTALL 1

  typedef struct _WINTRUST_DATA {
    DWORD cbStruct;
    LPVOID pPolicyCallbackData;
    LPVOID pSIPClientData;
    DWORD dwUIChoice;
    DWORD fdwRevocationChecks;
    DWORD dwUnionChoice;
    __C89_NAMELESS union {
      struct WINTRUST_FILE_INFO_ *pFile;
      struct WINTRUST_CATALOG_INFO_ *pCatalog;
      struct WINTRUST_BLOB_INFO_ *pBlob;
      struct WINTRUST_SGNR_INFO_ *pSgnr;
      struct WINTRUST_CERT_INFO_ *pCert;
    };
    DWORD dwStateAction;
    HANDLE hWVTStateData;
    WCHAR *pwszURLReference;
    DWORD dwProvFlags;
    DWORD dwUIContext;
  } WINTRUST_DATA,*PWINTRUST_DATA;

  typedef struct WINTRUST_FILE_INFO_ {
    DWORD cbStruct;
    LPCWSTR pcwszFilePath;
    HANDLE hFile;
    GUID *pgKnownSubject;
  } WINTRUST_FILE_INFO,*PWINTRUST_FILE_INFO;

  typedef HANDLE HCATADMIN;

  typedef struct WINTRUST_CATALOG_INFO_ {
    DWORD cbStruct;
    DWORD dwCatalogVersion;
    LPCWSTR pcwszCatalogFilePath;
    LPCWSTR pcwszMemberTag;
    LPCWSTR pcwszMemberFilePath;
    HANDLE hMemberFile;
    BYTE *pbCalculatedFileHash;
    DWORD cbCalculatedFileHash;
    PCCTL_CONTEXT pcCatalogContext;
#if (NTDDI_VERSION >= NTDDI_WIN8)
    HCATADMIN hCatAdmin;
#endif
  } WINTRUST_CATALOG_INFO,*PWINTRUST_CATALOG_INFO;

  typedef struct WINTRUST_BLOB_INFO_ {
    DWORD cbStruct;
    GUID gSubject;
    LPCWSTR pcwszDisplayName;
    DWORD cbMemObject;
    BYTE *pbMemObject;
    DWORD cbMemSignedMsg;
    BYTE *pbMemSignedMsg;
  } WINTRUST_BLOB_INFO,*PWINTRUST_BLOB_INFO;

  typedef struct WINTRUST_SGNR_INFO_ {
    DWORD cbStruct;
    LPCWSTR pcwszDisplayName;
    CMSG_SIGNER_INFO *psSignerInfo;
    DWORD chStores;
    HCERTSTORE *pahStores;
  } WINTRUST_SGNR_INFO,*PWINTRUST_SGNR_INFO;

#define WTCI_DONT_OPEN_STORES 0x00000001
#define WTCI_OPEN_ONLY_ROOT 0x00000002

  typedef struct WINTRUST_CERT_INFO_ {
    DWORD cbStruct;
    LPCWSTR pcwszDisplayName;
    CERT_CONTEXT *psCertContext;
    DWORD chStores;
    HCERTSTORE *pahStores;
    DWORD dwFlags;
    FILETIME *psftVerifyAsOf;
  } WINTRUST_CERT_INFO,*PWINTRUST_CERT_INFO;

#include <poppack.h>

  extern LONG WINAPI WinVerifyTrust(HWND hwnd,GUID *pgActionID,LPVOID pWVTData);
  extern HRESULT WINAPI WinVerifyTrustEx(HWND hwnd,GUID *pgActionID,WINTRUST_DATA *pWinTrustData);

#define WTPF_TRUSTTEST 0x00000020
#define WTPF_TESTCANBEVALID 0x00000080
#define WTPF_IGNOREEXPIRATION 0x00000100
#define WTPF_IGNOREREVOKATION 0x00000200
#define WTPF_OFFLINEOK_IND 0x00000400
#define WTPF_OFFLINEOK_COM 0x00000800
#define WTPF_OFFLINEOKNBU_IND 0x00001000
#define WTPF_OFFLINEOKNBU_COM 0x00002000
#define WTPF_VERIFY_V1_OFF 0x00010000
#define WTPF_IGNOREREVOCATIONONTS 0x00020000
#define WTPF_ALLOWONLYPERTRUST 0x00040000

  extern void WINAPI WintrustGetRegPolicyFlags(DWORD *pdwPolicyFlags);
  extern WINBOOL WINAPI WintrustSetRegPolicyFlags(DWORD dwPolicyFlags);

#define TRUSTERROR_STEP_WVTPARAMS 0
#define TRUSTERROR_STEP_FILEIO 2
#define TRUSTERROR_STEP_SIP 3
#define TRUSTERROR_STEP_SIPSUBJINFO 5
#define TRUSTERROR_STEP_CATALOGFILE 6
#define TRUSTERROR_STEP_CERTSTORE 7
#define TRUSTERROR_STEP_MESSAGE 8
#define TRUSTERROR_STEP_MSG_SIGNERCOUNT 9
#define TRUSTERROR_STEP_MSG_INNERCNTTYPE 10
#define TRUSTERROR_STEP_MSG_INNERCNT 11
#define TRUSTERROR_STEP_MSG_STORE 12
#define TRUSTERROR_STEP_MSG_SIGNERINFO 13
#define TRUSTERROR_STEP_MSG_SIGNERCERT 14
#define TRUSTERROR_STEP_MSG_CERTCHAIN 15
#define TRUSTERROR_STEP_MSG_COUNTERSIGINFO 16
#define TRUSTERROR_STEP_MSG_COUNTERSIGCERT 17
#define TRUSTERROR_STEP_VERIFY_MSGHASH 18
#define TRUSTERROR_STEP_VERIFY_MSGINDIRECTDATA 19

#define TRUSTERROR_STEP_FINAL_WVTINIT 30
#define TRUSTERROR_STEP_FINAL_INITPROV 31
#define TRUSTERROR_STEP_FINAL_OBJPROV 32
#define TRUSTERROR_STEP_FINAL_SIGPROV 33
#define TRUSTERROR_STEP_FINAL_CERTPROV 34
#define TRUSTERROR_STEP_FINAL_CERTCHKPROV 35
#define TRUSTERROR_STEP_FINAL_POLICYPROV 36
#define TRUSTERROR_STEP_FINAL_UIPROV 37

#define TRUSTERROR_MAX_STEPS 38

  typedef void *(*PFN_CPD_MEM_ALLOC)(DWORD cbSize);
  typedef void (*PFN_CPD_MEM_FREE)(void *pvMem2Free);
  typedef WINBOOL (*PFN_CPD_ADD_STORE)(struct _CRYPT_PROVIDER_DATA *pProvData,HCERTSTORE hStore2Add);
  typedef WINBOOL (*PFN_CPD_ADD_SGNR)(struct _CRYPT_PROVIDER_DATA *pProvData,WINBOOL fCounterSigner,DWORD idxSigner,struct _CRYPT_PROVIDER_SGNR *pSgnr2Add);
  typedef WINBOOL (*PFN_CPD_ADD_CERT)(struct _CRYPT_PROVIDER_DATA *pProvData,DWORD idxSigner,WINBOOL fCounterSigner,DWORD idxCounterSigner,PCCERT_CONTEXT pCert2Add);
  typedef WINBOOL (*PFN_CPD_ADD_PRIVDATA)(struct _CRYPT_PROVIDER_DATA *pProvData,struct _CRYPT_PROVIDER_PRIVDATA *pPrivData2Add);
  typedef HRESULT (*PFN_PROVIDER_INIT_CALL)(struct _CRYPT_PROVIDER_DATA *pProvData);
  typedef HRESULT (*PFN_PROVIDER_OBJTRUST_CALL)(struct _CRYPT_PROVIDER_DATA *pProvData);
  typedef HRESULT (*PFN_PROVIDER_SIGTRUST_CALL)(struct _CRYPT_PROVIDER_DATA *pProvData);
  typedef HRESULT (*PFN_PROVIDER_CERTTRUST_CALL)(struct _CRYPT_PROVIDER_DATA *pProvData);
  typedef HRESULT (*PFN_PROVIDER_FINALPOLICY_CALL)(struct _CRYPT_PROVIDER_DATA *pProvData);
  typedef HRESULT (*PFN_PROVIDER_TESTFINALPOLICY_CALL)(struct _CRYPT_PROVIDER_DATA *pProvData);
  typedef HRESULT (*PFN_PROVIDER_CLEANUP_CALL)(struct _CRYPT_PROVIDER_DATA *pProvData);
  typedef WINBOOL (*PFN_PROVIDER_CERTCHKPOLICY_CALL)(struct _CRYPT_PROVIDER_DATA *pProvData,DWORD idxSigner,WINBOOL fCounterSignerChain,DWORD idxCounterSigner);

#define WVT_OFFSETOF(t,f) ((ULONG)((ULONG_PTR)(&((t*)0)->f)))
#define WVT_ISINSTRUCT(structtypedef,structpassedsize,member) ((WVT_OFFSETOF(structtypedef,member) < structpassedsize) ? TRUE : FALSE)
#define WVT_IS_CBSTRUCT_GT_MEMBEROFFSET(structtypedef,structpassedsize,member) WVT_ISINSTRUCT(structtypedef,structpassedsize,member)

#include <pshpack8.h>

#define CPD_CHOICE_SIP 1

#define CPD_USE_NT5_CHAIN_FLAG 0x80000000
#define CPD_REVOCATION_CHECK_NONE 0x00010000
#define CPD_REVOCATION_CHECK_END_CERT 0x00020000
#define CPD_REVOCATION_CHECK_CHAIN 0x00040000
#define CPD_REVOCATION_CHECK_CHAIN_EXCLUDE_ROOT 0x00080000

#define CPD_UISTATE_MODE_PROMPT 0x00000000
#define CPD_UISTATE_MODE_BLOCK 0x00000001
#define CPD_UISTATE_MODE_ALLOW 0x00000002
#define CPD_UISTATE_MODE_MASK 0x00000003

  typedef struct _CRYPT_PROVIDER_DATA {
    DWORD cbStruct;
    WINTRUST_DATA *pWintrustData;
    WINBOOL fOpenedFile;
    HWND hWndParent;
    GUID *pgActionID;
    HCRYPTPROV hProv;
    DWORD dwError;
    DWORD dwRegSecuritySettings;
    DWORD dwRegPolicySettings;
    struct _CRYPT_PROVIDER_FUNCTIONS *psPfns;
    DWORD cdwTrustStepErrors;
    DWORD *padwTrustStepErrors;
    DWORD chStores;
    HCERTSTORE *pahStores;
    DWORD dwEncoding;
    HCRYPTMSG hMsg;
    DWORD csSigners;
    struct _CRYPT_PROVIDER_SGNR *pasSigners;
    DWORD csProvPrivData;
    struct _CRYPT_PROVIDER_PRIVDATA *pasProvPrivData;
    DWORD dwSubjectChoice;
    __C89_NAMELESS union {
      struct _PROVDATA_SIP *pPDSip;
    };
    char *pszUsageOID;
    WINBOOL fRecallWithState;
    FILETIME sftSystemTime;
    char *pszCTLSignerUsageOID;
    DWORD dwProvFlags;
    DWORD dwFinalError;
    PCERT_USAGE_MATCH pRequestUsage;
    DWORD dwTrustPubSettings;
    DWORD dwUIStateFlags;
  } CRYPT_PROVIDER_DATA,*PCRYPT_PROVIDER_DATA;

  typedef struct _CRYPT_PROVIDER_FUNCTIONS {
    DWORD cbStruct;
    PFN_CPD_MEM_ALLOC pfnAlloc;
    PFN_CPD_MEM_FREE pfnFree;
    PFN_CPD_ADD_STORE pfnAddStore2Chain;
    PFN_CPD_ADD_SGNR pfnAddSgnr2Chain;
    PFN_CPD_ADD_CERT pfnAddCert2Chain;
    PFN_CPD_ADD_PRIVDATA pfnAddPrivData2Chain;
    PFN_PROVIDER_INIT_CALL pfnInitialize;
    PFN_PROVIDER_OBJTRUST_CALL pfnObjectTrust;
    PFN_PROVIDER_SIGTRUST_CALL pfnSignatureTrust;
    PFN_PROVIDER_CERTTRUST_CALL pfnCertificateTrust;
    PFN_PROVIDER_FINALPOLICY_CALL pfnFinalPolicy;
    PFN_PROVIDER_CERTCHKPOLICY_CALL pfnCertCheckPolicy;
    PFN_PROVIDER_TESTFINALPOLICY_CALL pfnTestFinalPolicy;
    struct _CRYPT_PROVUI_FUNCS *psUIpfns;
    PFN_PROVIDER_CLEANUP_CALL pfnCleanupPolicy;
  } CRYPT_PROVIDER_FUNCTIONS,*PCRYPT_PROVIDER_FUNCTIONS;

  typedef WINBOOL (*PFN_PROVUI_CALL)(HWND hWndSecurityDialog,struct _CRYPT_PROVIDER_DATA *pProvData);

  typedef struct _CRYPT_PROVUI_FUNCS {
    DWORD cbStruct;
    struct _CRYPT_PROVUI_DATA *psUIData;
    PFN_PROVUI_CALL pfnOnMoreInfoClick;
    PFN_PROVUI_CALL pfnOnMoreInfoClickDefault;
    PFN_PROVUI_CALL pfnOnAdvancedClick;
    PFN_PROVUI_CALL pfnOnAdvancedClickDefault;
  } CRYPT_PROVUI_FUNCS,*PCRYPT_PROVUI_FUNCS;

  typedef struct _CRYPT_PROVUI_DATA {
    DWORD cbStruct;
    DWORD dwFinalError;
    WCHAR *pYesButtonText;
    WCHAR *pNoButtonText;
    WCHAR *pMoreInfoButtonText;
    WCHAR *pAdvancedLinkText;
    WCHAR *pCopyActionText;
    WCHAR *pCopyActionTextNoTS;
    WCHAR *pCopyActionTextNotSigned;
  } CRYPT_PROVUI_DATA,*PCRYPT_PROVUI_DATA;

#define SGNR_TYPE_TIMESTAMP 0x00000010

  typedef struct _CRYPT_PROVIDER_SGNR {
    DWORD cbStruct;
    FILETIME sftVerifyAsOf;
    DWORD csCertChain;
    struct _CRYPT_PROVIDER_CERT *pasCertChain;
    DWORD dwSignerType;
    CMSG_SIGNER_INFO *psSigner;
    DWORD dwError;
    DWORD csCounterSigners;
    struct _CRYPT_PROVIDER_SGNR *pasCounterSigners;
    PCCERT_CHAIN_CONTEXT pChainContext;
  } CRYPT_PROVIDER_SGNR,*PCRYPT_PROVIDER_SGNR;

#define CERT_CONFIDENCE_SIG 0x10000000
#define CERT_CONFIDENCE_TIME 0x01000000
#define CERT_CONFIDENCE_TIMENEST 0x00100000
#define CERT_CONFIDENCE_AUTHIDEXT 0x00010000
#define CERT_CONFIDENCE_HYGIENE 0x00001000
#define CERT_CONFIDENCE_HIGHEST 0x11111000

  typedef struct _CRYPT_PROVIDER_CERT {
    DWORD cbStruct;
    PCCERT_CONTEXT pCert;
    WINBOOL fCommercial;
    WINBOOL fTrustedRoot;
    WINBOOL fSelfSigned;
    WINBOOL fTestCert;
    DWORD dwRevokedReason;
    DWORD dwConfidence;
    DWORD dwError;
    CTL_CONTEXT *pTrustListContext;
    WINBOOL fTrustListSignerCert;
    PCCTL_CONTEXT pCtlContext;
    DWORD dwCtlError;
    WINBOOL fIsCyclic;
    PCERT_CHAIN_ELEMENT pChainElement;
  } CRYPT_PROVIDER_CERT,*PCRYPT_PROVIDER_CERT;

  typedef struct _CRYPT_PROVIDER_PRIVDATA {
    DWORD cbStruct;
    GUID gProviderID;
    DWORD cbProvData;
    void *pvProvData;
  } CRYPT_PROVIDER_PRIVDATA,*PCRYPT_PROVIDER_PRIVDATA;

  typedef struct _PROVDATA_SIP {
    DWORD cbStruct;
    GUID gSubject;
    struct SIP_DISPATCH_INFO_ *pSip;
    struct SIP_DISPATCH_INFO_ *pCATSip;
    struct SIP_SUBJECTINFO_ *psSipSubjectInfo;
    struct SIP_SUBJECTINFO_ *psSipCATSubjectInfo;
    struct SIP_INDIRECT_DATA_ *psIndirectData;
  } PROVDATA_SIP,*PPROVDATA_SIP;

#define WT_CURRENT_VERSION 0x00000200

  typedef struct _CRYPT_TRUST_REG_ENTRY {
    DWORD cbStruct;
    WCHAR *pwszDLLName;
    WCHAR *pwszFunctionName;
  } CRYPT_TRUST_REG_ENTRY,*PCRYPT_TRUST_REG_ENTRY;

  typedef struct _CRYPT_REGISTER_ACTIONID {
    DWORD cbStruct;
    CRYPT_TRUST_REG_ENTRY sInitProvider;
    CRYPT_TRUST_REG_ENTRY sObjectProvider;
    CRYPT_TRUST_REG_ENTRY sSignatureProvider;
    CRYPT_TRUST_REG_ENTRY sCertificateProvider;
    CRYPT_TRUST_REG_ENTRY sCertificatePolicyProvider;
    CRYPT_TRUST_REG_ENTRY sFinalPolicyProvider;
    CRYPT_TRUST_REG_ENTRY sTestPolicyProvider;
    CRYPT_TRUST_REG_ENTRY sCleanupProvider;
  } CRYPT_REGISTER_ACTIONID,*PCRYPT_REGISTER_ACTIONID;

  typedef WINBOOL (*PFN_ALLOCANDFILLDEFUSAGE)(const char *pszUsageOID,struct _CRYPT_PROVIDER_DEFUSAGE *psDefUsage);
  typedef WINBOOL (*PFN_FREEDEFUSAGE)(const char *pszUsageOID,struct _CRYPT_PROVIDER_DEFUSAGE *psDefUsage);

  typedef struct _CRYPT_PROVIDER_REGDEFUSAGE {
    DWORD cbStruct;
    GUID *pgActionID;
    WCHAR *pwszDllName;
    char *pwszLoadCallbackDataFunctionName;
    char *pwszFreeCallbackDataFunctionName;
  } CRYPT_PROVIDER_REGDEFUSAGE,*PCRYPT_PROVIDER_REGDEFUSAGE;

  typedef struct _CRYPT_PROVIDER_DEFUSAGE {
    DWORD cbStruct;
    GUID gActionID;
    LPVOID pDefPolicyCallbackData;
    LPVOID pDefSIPClientData;
  } CRYPT_PROVIDER_DEFUSAGE,*PCRYPT_PROVIDER_DEFUSAGE;

#include <poppack.h>

#define WT_PROVIDER_DLL_NAME L"WINTRUST.DLL"
#define WT_PROVIDER_CERTTRUST_FUNCTION L"WintrustCertificateTrust"

  extern WINBOOL WINAPI WintrustAddActionID(GUID *pgActionID,DWORD fdwFlags,CRYPT_REGISTER_ACTIONID *psProvInfo);

#define WT_ADD_ACTION_ID_RET_RESULT_FLAG 0x1

  extern WINBOOL WINAPI WintrustRemoveActionID(GUID *pgActionID);
  extern WINBOOL WINAPI WintrustLoadFunctionPointers(GUID *pgActionID,CRYPT_PROVIDER_FUNCTIONS *pPfns);
  extern WINBOOL WINAPI WintrustAddDefaultForUsage(const char *pszUsageOID,CRYPT_PROVIDER_REGDEFUSAGE *psDefUsage);

#define DWACTION_ALLOCANDFILL 1
#define DWACTION_FREE 2

  extern WINBOOL WINAPI WintrustGetDefaultForUsage(DWORD dwAction,const char *pszUsageOID,CRYPT_PROVIDER_DEFUSAGE *psUsage);
  extern CRYPT_PROVIDER_SGNR *WINAPI WTHelperGetProvSignerFromChain(CRYPT_PROVIDER_DATA *pProvData,DWORD idxSigner,WINBOOL fCounterSigner,DWORD idxCounterSigner);
  extern CRYPT_PROVIDER_CERT *WINAPI WTHelperGetProvCertFromChain(CRYPT_PROVIDER_SGNR *pSgnr,DWORD idxCert);
  extern CRYPT_PROVIDER_DATA *WINAPI WTHelperProvDataFromStateData(HANDLE hStateData);
  extern CRYPT_PROVIDER_PRIVDATA *WINAPI WTHelperGetProvPrivateDataFromChain(CRYPT_PROVIDER_DATA *pProvData,GUID *pgProviderID);
  extern WINBOOL WINAPI WTHelperCertIsSelfSigned(DWORD dwEncoding,CERT_INFO *pCert);
  extern HRESULT WINAPI WTHelperCertCheckValidSignature(CRYPT_PROVIDER_DATA *pProvData);

#include <pshpack8.h>

#define szOID_TRUSTED_CODESIGNING_CA_LIST "1.3.6.1.4.1.311.2.2.1"
#define szOID_TRUSTED_CLIENT_AUTH_CA_LIST "1.3.6.1.4.1.311.2.2.2"
#define szOID_TRUSTED_SERVER_AUTH_CA_LIST "1.3.6.1.4.1.311.2.2.3"

#define SPC_COMMON_NAME_OBJID szOID_COMMON_NAME
#define SPC_TIME_STAMP_REQUEST_OBJID "1.3.6.1.4.1.311.3.2.1"
#define SPC_INDIRECT_DATA_OBJID "1.3.6.1.4.1.311.2.1.4"
#define SPC_SP_AGENCY_INFO_OBJID "1.3.6.1.4.1.311.2.1.10"
#define SPC_STATEMENT_TYPE_OBJID "1.3.6.1.4.1.311.2.1.11"
#define SPC_SP_OPUS_INFO_OBJID "1.3.6.1.4.1.311.2.1.12"
#define SPC_CERT_EXTENSIONS_OBJID "1.3.6.1.4.1.311.2.1.14"
#define SPC_PE_IMAGE_DATA_OBJID "1.3.6.1.4.1.311.2.1.15"
#define SPC_RAW_FILE_DATA_OBJID "1.3.6.1.4.1.311.2.1.18"
#define SPC_STRUCTURED_STORAGE_DATA_OBJID "1.3.6.1.4.1.311.2.1.19"
#define SPC_JAVA_CLASS_DATA_OBJID "1.3.6.1.4.1.311.2.1.20"
#define SPC_INDIVIDUAL_SP_KEY_PURPOSE_OBJID "1.3.6.1.4.1.311.2.1.21"
#define SPC_COMMERCIAL_SP_KEY_PURPOSE_OBJID "1.3.6.1.4.1.311.2.1.22"
#define SPC_CAB_DATA_OBJID "1.3.6.1.4.1.311.2.1.25"
#define SPC_GLUE_RDN_OBJID "1.3.6.1.4.1.311.2.1.25"
#define SPC_MINIMAL_CRITERIA_OBJID "1.3.6.1.4.1.311.2.1.26"
#define SPC_FINANCIAL_CRITERIA_OBJID "1.3.6.1.4.1.311.2.1.27"
#define SPC_LINK_OBJID "1.3.6.1.4.1.311.2.1.28"
#define SPC_SIGINFO_OBJID "1.3.6.1.4.1.311.2.1.30"

#define CAT_NAMEVALUE_OBJID "1.3.6.1.4.1.311.12.2.1"
#define CAT_MEMBERINFO_OBJID "1.3.6.1.4.1.311.12.2.2"

#define SPC_SP_AGENCY_INFO_STRUCT ((LPCSTR) 2000)
#define SPC_MINIMAL_CRITERIA_STRUCT ((LPCSTR) 2001)
#define SPC_FINANCIAL_CRITERIA_STRUCT ((LPCSTR) 2002)
#define SPC_INDIRECT_DATA_CONTENT_STRUCT ((LPCSTR) 2003)
#define SPC_PE_IMAGE_DATA_STRUCT ((LPCSTR) 2004)
#define SPC_LINK_STRUCT ((LPCSTR) 2005)
#define SPC_STATEMENT_TYPE_STRUCT ((LPCSTR) 2006)
#define SPC_SP_OPUS_INFO_STRUCT ((LPCSTR) 2007)
#define SPC_CAB_DATA_STRUCT ((LPCSTR) 2008)
#define SPC_JAVA_CLASS_DATA_STRUCT ((LPCSTR) 2009)

#define SPC_SIGINFO_STRUCT ((LPCSTR) 2130)

#define CAT_NAMEVALUE_STRUCT ((LPCSTR) 2221)
#define CAT_MEMBERINFO_STRUCT ((LPCSTR) 2222)

#define SPC_UUID_LENGTH 16

  typedef BYTE SPC_UUID[SPC_UUID_LENGTH];

  typedef struct _SPC_SERIALIZED_OBJECT {
    SPC_UUID ClassId;
    CRYPT_DATA_BLOB SerializedData;
  } SPC_SERIALIZED_OBJECT,*PSPC_SERIALIZED_OBJECT;

  typedef struct SPC_SIGINFO_ {
    DWORD dwSipVersion;
    GUID gSIPGuid;
    DWORD dwReserved1;
    DWORD dwReserved2;
    DWORD dwReserved3;
    DWORD dwReserved4;
    DWORD dwReserved5;
  } SPC_SIGINFO,*PSPC_SIGINFO;

#define SPC_URL_LINK_CHOICE 1
#define SPC_MONIKER_LINK_CHOICE 2
#define SPC_FILE_LINK_CHOICE 3

  typedef struct SPC_LINK_ {
    DWORD dwLinkChoice;
    __C89_NAMELESS union {
      LPWSTR pwszUrl;
      SPC_SERIALIZED_OBJECT Moniker;
      LPWSTR pwszFile;
    };
  } SPC_LINK,*PSPC_LINK;

  typedef struct _SPC_PE_IMAGE_DATA {
    CRYPT_BIT_BLOB Flags;
    PSPC_LINK pFile;
  } SPC_PE_IMAGE_DATA,*PSPC_PE_IMAGE_DATA;

  typedef struct _SPC_INDIRECT_DATA_CONTENT {
    CRYPT_ATTRIBUTE_TYPE_VALUE Data;
    CRYPT_ALGORITHM_IDENTIFIER DigestAlgorithm;
    CRYPT_HASH_BLOB Digest;
  } SPC_INDIRECT_DATA_CONTENT,*PSPC_INDIRECT_DATA_CONTENT;

  typedef struct _SPC_FINANCIAL_CRITERIA {
    WINBOOL fFinancialInfoAvailable;
    WINBOOL fMeetsCriteria;
  } SPC_FINANCIAL_CRITERIA,*PSPC_FINANCIAL_CRITERIA;

  typedef struct _SPC_IMAGE {
    struct SPC_LINK_ *pImageLink;
    CRYPT_DATA_BLOB Bitmap;
    CRYPT_DATA_BLOB Metafile;
    CRYPT_DATA_BLOB EnhancedMetafile;
    CRYPT_DATA_BLOB GifFile;
  } SPC_IMAGE,*PSPC_IMAGE;

  typedef struct _SPC_SP_AGENCY_INFO {
    struct SPC_LINK_ *pPolicyInformation;
    LPWSTR pwszPolicyDisplayText;
    PSPC_IMAGE pLogoImage;
    struct SPC_LINK_ *pLogoLink;
  } SPC_SP_AGENCY_INFO,*PSPC_SP_AGENCY_INFO;

  typedef struct _SPC_STATEMENT_TYPE {
    DWORD cKeyPurposeId;
    LPSTR *rgpszKeyPurposeId;
  } SPC_STATEMENT_TYPE,*PSPC_STATEMENT_TYPE;

  typedef struct _SPC_SP_OPUS_INFO {
    LPCWSTR pwszProgramName;
    struct SPC_LINK_ *pMoreInfo;
    struct SPC_LINK_ *pPublisherInfo;
  } SPC_SP_OPUS_INFO,*PSPC_SP_OPUS_INFO;

  typedef struct _CAT_NAMEVALUE {
    LPWSTR pwszTag;
    DWORD fdwFlags;
    CRYPT_DATA_BLOB Value;
  } CAT_NAMEVALUE,*PCAT_NAMEVALUE;

  typedef struct _CAT_MEMBERINFO {
    LPWSTR pwszSubjGuid;
    DWORD dwCertVersion;
  } CAT_MEMBERINFO,*PCAT_MEMBERINFO;

#include <poppack.h>

#ifdef WT_DEFINE_ALL_APIS
  typedef struct _WIN_CERTIFICATE {
    DWORD dwLength;
    WORD wRevision;
    WORD wCertificateType;
    BYTE bCertificate[ANYSIZE_ARRAY];
  } WIN_CERTIFICATE,*LPWIN_CERTIFICATE;

#define WIN_CERT_REVISION_1_0 (0x0100)
#define WIN_CERT_REVISION_2_0 (0x0200)
#define WIN_CERT_TYPE_X509 (0x0001)
#define WIN_CERT_TYPE_PKCS_SIGNED_DATA (0x0002)
#define WIN_CERT_TYPE_RESERVED_1 (0x0003)
#define WIN_CERT_TYPE_TS_STACK_SIGNED (0x0004)

  typedef LPVOID WIN_TRUST_SUBJECT;

  typedef struct _WIN_TRUST_ACTDATA_CONTEXT_WITH_SUBJECT {
    HANDLE hClientToken;
    GUID *SubjectType;
    WIN_TRUST_SUBJECT Subject;
  } WIN_TRUST_ACTDATA_CONTEXT_WITH_SUBJECT,*LPWIN_TRUST_ACTDATA_CONTEXT_WITH_SUBJECT;

  typedef struct _WIN_TRUST_ACTDATA_SUBJECT_ONLY {
    GUID *SubjectType;
    WIN_TRUST_SUBJECT Subject;
  } WIN_TRUST_ACTDATA_SUBJECT_ONLY,*LPWIN_TRUST_ACTDATA_SUBJECT_ONLY;

#define WIN_TRUST_SUBJTYPE_RAW_FILE { 0x959dc450,0x8d9e,0x11cf,{0x87,0x36,0x00,0xaa,0x00,0xa4,0x85,0xeb} }
#define WIN_TRUST_SUBJTYPE_PE_IMAGE { 0x43c9a1e0,0x8da0,0x11cf,{0x87,0x36,0x00,0xaa,0x00,0xa4,0x85,0xeb} }
#define WIN_TRUST_SUBJTYPE_JAVA_CLASS { 0x08ad3990,0x8da1,0x11cf,{0x87,0x36,0x00,0xaa,0x00,0xa4,0x85,0xeb} }
#define WIN_TRUST_SUBJTYPE_CABINET { 0xd17c5374,0xa392,0x11cf,{ 0x9d,0xf5,0x0,0xaa,0x0,0xc1,0x84,0xe0 } }

  typedef struct _WIN_TRUST_SUBJECT_FILE {
    HANDLE hFile;
    LPCWSTR lpPath;
  } WIN_TRUST_SUBJECT_FILE,*LPWIN_TRUST_SUBJECT_FILE;

#define WIN_TRUST_SUBJTYPE_RAW_FILEEX { 0x6f458110,0xc2f1,0x11cf,{ 0x8a,0x69,0x0,0xaa,0x0,0x6c,0x37,0x6 } }
#define WIN_TRUST_SUBJTYPE_PE_IMAGEEX { 0x6f458111,0xc2f1,0x11cf,{ 0x8a,0x69,0x0,0xaa,0x0,0x6c,0x37,0x6 } }
#define WIN_TRUST_SUBJTYPE_JAVA_CLASSEX { 0x6f458113,0xc2f1,0x11cf,{ 0x8a,0x69,0x0,0xaa,0x0,0x6c,0x37,0x6 } }
#define WIN_TRUST_SUBJTYPE_CABINETEX { 0x6f458114,0xc2f1,0x11cf,{ 0x8a,0x69,0x0,0xaa,0x0,0x6c,0x37,0x6 } }

  typedef struct _WIN_TRUST_SUBJECT_FILE_AND_DISPLAY {
    HANDLE hFile;
    LPCWSTR lpPath;
    LPCWSTR lpDisplayName;
  } WIN_TRUST_SUBJECT_FILE_AND_DISPLAY,*LPWIN_TRUST_SUBJECT_FILE_AND_DISPLAY;

#define WIN_TRUST_SUBJTYPE_OLE_STORAGE { 0xc257e740,0x8da0,0x11cf,{0x87,0x36,0x00,0xaa,0x00,0xa4,0x85,0xeb} }
#define WIN_SPUB_ACTION_TRUSTED_PUBLISHER { 0x66426730,0x8da1,0x11cf,{0x87,0x36,0x00,0xaa,0x00,0xa4,0x85,0xeb} }
#define WIN_SPUB_ACTION_NT_ACTIVATE_IMAGE { 0x8bc96b00,0x8da1,0x11cf,{0x87,0x36,0x00,0xaa,0x00,0xa4,0x85,0xeb} }
#define WIN_SPUB_ACTION_PUBLISHED_SOFTWARE { 0x64b9d180,0x8da2,0x11cf,{0x87,0x36,0x00,0xaa,0x00,0xa4,0x85,0xeb} }

  typedef struct _WIN_SPUB_TRUSTED_PUBLISHER_DATA {
    HANDLE hClientToken;
    LPWIN_CERTIFICATE lpCertificate;
  } WIN_SPUB_TRUSTED_PUBLISHER_DATA,*LPWIN_SPUB_TRUSTED_PUBLISHER_DATA;

#endif /* WT_DEFINE_ALL_APIS */

#if (_WIN32_WINNT >= 0x0600)
void WINAPI WintrustSetDefaultIncludePEPageHashes(WINBOOL fIncludePEPageHashes);
#endif /*(_WIN32_WINNT >= 0x0600)*/

#ifdef __cplusplus
}
#endif
#endif
