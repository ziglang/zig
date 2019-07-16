/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __SCHANNEL_H__
#define __SCHANNEL_H__

#include <_mingw_unicode.h>
#include <wincrypt.h>

#define UNISP_NAME_A "Microsoft Unified Security Protocol Provider"
#define UNISP_NAME_W L"Microsoft Unified Security Protocol Provider"

#define SSL2SP_NAME_A "Microsoft SSL 2.0"
#define SSL2SP_NAME_W L"Microsoft SSL 2.0"

#define SSL3SP_NAME_A "Microsoft SSL 3.0"
#define SSL3SP_NAME_W L"Microsoft SSL 3.0"

#define TLS1SP_NAME_A "Microsoft TLS 1.0"
#define TLS1SP_NAME_W L"Microsoft TLS 1.0"

#define PCT1SP_NAME_A "Microsoft PCT 1.0"
#define PCT1SP_NAME_W L"Microsoft PCT 1.0"

#define SCHANNEL_NAME_A "Schannel"
#define SCHANNEL_NAME_W L"Schannel"

#define UNISP_NAME __MINGW_NAME_UAW(UNISP_NAME)
#define PCT1SP_NAME __MINGW_NAME_UAW(PCT1SP_NAME)
#define SSL2SP_NAME __MINGW_NAME_UAW(SSL2SP_NAME)
#define SSL3SP_NAME __MINGW_NAME_UAW(SSL3SP_NAME)
#define TLS1SP_NAME __MINGW_NAME_UAW(TLS1SP_NAME)
#define SCHANNEL_NAME __MINGW_NAME_UAW(SCHANNEL_NAME)

#define UNISP_RPC_ID 14

#define SECPKG_ATTR_ISSUER_LIST 0x50
#define SECPKG_ATTR_REMOTE_CRED 0x51
#define SECPKG_ATTR_LOCAL_CRED 0x52
#define SECPKG_ATTR_REMOTE_CERT_CONTEXT 0x53
#define SECPKG_ATTR_LOCAL_CERT_CONTEXT 0x54
#define SECPKG_ATTR_ROOT_STORE 0x55
#define SECPKG_ATTR_SUPPORTED_ALGS 0x56
#define SECPKG_ATTR_CIPHER_STRENGTHS 0x57
#define SECPKG_ATTR_SUPPORTED_PROTOCOLS 0x58
#define SECPKG_ATTR_ISSUER_LIST_EX 0x59
#define SECPKG_ATTR_CONNECTION_INFO 0x5a
#define SECPKG_ATTR_EAP_KEY_BLOCK 0x5b
#define SECPKG_ATTR_MAPPED_CRED_ATTR 0x5c
#define SECPKG_ATTR_SESSION_INFO 0x5d
#define SECPKG_ATTR_APP_DATA 0x5e

typedef struct _SecPkgContext_IssuerListInfo {
  DWORD cbIssuerList;
  PBYTE pIssuerList;
} SecPkgContext_IssuerListInfo,*PSecPkgContext_IssuerListInfo;

typedef struct _SecPkgContext_RemoteCredentialInfo {
  DWORD cbCertificateChain;
  PBYTE pbCertificateChain;
  DWORD cCertificates;
  DWORD fFlags;
  DWORD dwBits;
} SecPkgContext_RemoteCredentialInfo,*PSecPkgContext_RemoteCredentialInfo;

typedef SecPkgContext_RemoteCredentialInfo SecPkgContext_RemoteCredenitalInfo,*PSecPkgContext_RemoteCredenitalInfo;

#define RCRED_STATUS_NOCRED 0x00000000
#define RCRED_CRED_EXISTS 0x00000001
#define RCRED_STATUS_UNKNOWN_ISSUER 0x00000002

typedef struct _SecPkgContext_LocalCredentialInfo {
  DWORD cbCertificateChain;
  PBYTE pbCertificateChain;
  DWORD cCertificates;
  DWORD fFlags;
  DWORD dwBits;
} SecPkgContext_LocalCredentialInfo,*PSecPkgContext_LocalCredentialInfo;

typedef SecPkgContext_LocalCredentialInfo SecPkgContext_LocalCredenitalInfo,*PSecPkgContext_LocalCredenitalInfo;

#define LCRED_STATUS_NOCRED 0x00000000
#define LCRED_CRED_EXISTS 0x00000001
#define LCRED_STATUS_UNKNOWN_ISSUER 0x00000002

typedef struct _SecPkgCred_SupportedAlgs {
  DWORD cSupportedAlgs;
  ALG_ID *palgSupportedAlgs;
} SecPkgCred_SupportedAlgs,*PSecPkgCred_SupportedAlgs;

typedef struct _SecPkgCred_CipherStrengths {
  DWORD dwMinimumCipherStrength;
  DWORD dwMaximumCipherStrength;
} SecPkgCred_CipherStrengths,*PSecPkgCred_CipherStrengths;

typedef struct _SecPkgCred_SupportedProtocols {
  DWORD grbitProtocol;
} SecPkgCred_SupportedProtocols,*PSecPkgCred_SupportedProtocols;

typedef struct _SecPkgContext_IssuerListInfoEx {
  PCERT_NAME_BLOB aIssuers;
  DWORD cIssuers;
} SecPkgContext_IssuerListInfoEx,*PSecPkgContext_IssuerListInfoEx;

typedef struct _SecPkgContext_ConnectionInfo {
  DWORD dwProtocol;
  ALG_ID aiCipher;
  DWORD dwCipherStrength;
  ALG_ID aiHash;
  DWORD dwHashStrength;
  ALG_ID aiExch;
  DWORD dwExchStrength;
} SecPkgContext_ConnectionInfo,*PSecPkgContext_ConnectionInfo;

typedef struct _SecPkgContext_EapKeyBlock {
  BYTE rgbKeys[128];
  BYTE rgbIVs[64];
} SecPkgContext_EapKeyBlock,*PSecPkgContext_EapKeyBlock;

typedef struct _SecPkgContext_MappedCredAttr {
  DWORD dwAttribute;
  PVOID pvBuffer;
} SecPkgContext_MappedCredAttr,*PSecPkgContext_MappedCredAttr;

#define SSL_SESSION_RECONNECT 1

typedef struct _SecPkgContext_SessionInfo {
  DWORD dwFlags;
  DWORD cbSessionId;
  BYTE rgbSessionId[32];
} SecPkgContext_SessionInfo,*PSecPkgContext_SessionInfo;

typedef struct _SecPkgContext_SessionAppData {
  DWORD dwFlags;
  DWORD cbAppData;
  PBYTE pbAppData;
} SecPkgContext_SessionAppData,*PSecPkgContext_SessionAppData;

#define SCH_CRED_V1 0x00000001
#define SCH_CRED_V2 0x00000002
#define SCH_CRED_VERSION 0x00000002
#define SCH_CRED_V3 0x00000003
#define SCHANNEL_CRED_VERSION 0x00000004

struct _HMAPPER;

typedef struct _SCHANNEL_CRED {
  DWORD dwVersion;
  DWORD cCreds;
  PCCERT_CONTEXT *paCred;
  HCERTSTORE hRootStore;
  DWORD cMappers;
  struct _HMAPPER **aphMappers;
  DWORD cSupportedAlgs;
  ALG_ID *palgSupportedAlgs;
  DWORD grbitEnabledProtocols;
  DWORD dwMinimumCipherStrength;
  DWORD dwMaximumCipherStrength;
  DWORD dwSessionLifespan;
  DWORD dwFlags;
  DWORD dwCredFormat;
} SCHANNEL_CRED,*PSCHANNEL_CRED;

#define SCH_CRED_FORMAT_CERT_HASH 0x00000001

#define SCH_CRED_MAX_SUPPORTED_ALGS 256
#define SCH_CRED_MAX_SUPPORTED_CERTS 100

typedef struct _SCHANNEL_CERT_HASH {
  DWORD dwLength;
  DWORD dwFlags;
  HCRYPTPROV hProv;
  BYTE ShaHash[20];
} SCHANNEL_CERT_HASH,*PSCHANNEL_CERT_HASH;

#define SCH_MACHINE_CERT_HASH 0x00000001

#define SCH_CRED_NO_SYSTEM_MAPPER 0x00000002
#define SCH_CRED_NO_SERVERNAME_CHECK 0x00000004
#define SCH_CRED_MANUAL_CRED_VALIDATION 0x00000008
#define SCH_CRED_NO_DEFAULT_CREDS 0x00000010
#define SCH_CRED_AUTO_CRED_VALIDATION 0x00000020
#define SCH_CRED_USE_DEFAULT_CREDS 0x00000040
#define SCH_CRED_DISABLE_RECONNECTS 0x00000080

#define SCH_CRED_REVOCATION_CHECK_END_CERT 0x00000100
#define SCH_CRED_REVOCATION_CHECK_CHAIN 0x00000200
#define SCH_CRED_REVOCATION_CHECK_CHAIN_EXCLUDE_ROOT 0x00000400
#define SCH_CRED_IGNORE_NO_REVOCATION_CHECK 0x00000800
#define SCH_CRED_IGNORE_REVOCATION_OFFLINE 0x00001000
#define SCH_CRED_REVOCATION_CHECK_CACHE_ONLY 0x00004000

#define SCH_CRED_CACHE_ONLY_URL_RETRIEVAL 0x00008000

#define SCHANNEL_RENEGOTIATE 0
#define SCHANNEL_SHUTDOWN 1
#define SCHANNEL_ALERT 2
#define SCHANNEL_SESSION 3

typedef struct _SCHANNEL_ALERT_TOKEN {
  DWORD dwTokenType;
  DWORD dwAlertType;
  DWORD dwAlertNumber;
} SCHANNEL_ALERT_TOKEN;

#define TLS1_ALERT_WARNING 1
#define TLS1_ALERT_FATAL 2

#define TLS1_ALERT_CLOSE_NOTIFY 0
#define TLS1_ALERT_UNEXPECTED_MESSAGE 10
#define TLS1_ALERT_BAD_RECORD_MAC 20
#define TLS1_ALERT_DECRYPTION_FAILED 21
#define TLS1_ALERT_RECORD_OVERFLOW 22
#define TLS1_ALERT_DECOMPRESSION_FAIL 30
#define TLS1_ALERT_HANDSHAKE_FAILURE 40
#define TLS1_ALERT_BAD_CERTIFICATE 42
#define TLS1_ALERT_UNSUPPORTED_CERT 43
#define TLS1_ALERT_CERTIFICATE_REVOKED 44
#define TLS1_ALERT_CERTIFICATE_EXPIRED 45
#define TLS1_ALERT_CERTIFICATE_UNKNOWN 46
#define TLS1_ALERT_ILLEGAL_PARAMETER 47
#define TLS1_ALERT_UNKNOWN_CA 48
#define TLS1_ALERT_ACCESS_DENIED 49
#define TLS1_ALERT_DECODE_ERROR 50
#define TLS1_ALERT_DECRYPT_ERROR 51
#define TLS1_ALERT_EXPORT_RESTRICTION 60
#define TLS1_ALERT_PROTOCOL_VERSION 70
#define TLS1_ALERT_INSUFFIENT_SECURITY 71
#define TLS1_ALERT_INTERNAL_ERROR 80
#define TLS1_ALERT_USER_CANCELED 90
#define TLS1_ALERT_NO_RENEGOTIATATION 100

#define SSL_SESSION_ENABLE_RECONNECTS 1
#define SSL_SESSION_DISABLE_RECONNECTS 2

typedef struct _SCHANNEL_SESSION_TOKEN {
  DWORD dwTokenType;
  DWORD dwFlags;
} SCHANNEL_SESSION_TOKEN;

#define CERT_SCHANNEL_IIS_PRIVATE_KEY_PROP_ID (CERT_FIRST_USER_PROP_ID + 0)
#define CERT_SCHANNEL_IIS_PASSWORD_PROP_ID (CERT_FIRST_USER_PROP_ID + 1)
#define CERT_SCHANNEL_SGC_CERTIFICATE_PROP_ID (CERT_FIRST_USER_PROP_ID + 2)

#define SP_PROT_PCT1_SERVER 0x00000001
#define SP_PROT_PCT1_CLIENT 0x00000002
#define SP_PROT_PCT1 (SP_PROT_PCT1_SERVER | SP_PROT_PCT1_CLIENT)

#define SP_PROT_SSL2_SERVER 0x00000004
#define SP_PROT_SSL2_CLIENT 0x00000008
#define SP_PROT_SSL2 (SP_PROT_SSL2_SERVER | SP_PROT_SSL2_CLIENT)

#define SP_PROT_SSL3_SERVER 0x00000010
#define SP_PROT_SSL3_CLIENT 0x00000020
#define SP_PROT_SSL3 (SP_PROT_SSL3_SERVER | SP_PROT_SSL3_CLIENT)

#define SP_PROT_TLS1_SERVER 0x00000040
#define SP_PROT_TLS1_CLIENT 0x00000080
#define SP_PROT_TLS1 (SP_PROT_TLS1_SERVER | SP_PROT_TLS1_CLIENT)

#define SP_PROT_SSL3TLS1_CLIENTS (SP_PROT_TLS1_CLIENT | SP_PROT_SSL3_CLIENT)
#define SP_PROT_SSL3TLS1_SERVERS (SP_PROT_TLS1_SERVER | SP_PROT_SSL3_SERVER)
#define SP_PROT_SSL3TLS1 (SP_PROT_SSL3 | SP_PROT_TLS1)

#define SP_PROT_UNI_SERVER 0x40000000
#define SP_PROT_UNI_CLIENT 0x80000000
#define SP_PROT_UNI (SP_PROT_UNI_SERVER | SP_PROT_UNI_CLIENT)

#define SP_PROT_ALL 0xffffffff
#define SP_PROT_NONE 0
#define SP_PROT_CLIENTS (SP_PROT_PCT1_CLIENT | SP_PROT_SSL2_CLIENT | SP_PROT_SSL3_CLIENT | SP_PROT_UNI_CLIENT | SP_PROT_TLS1_CLIENT)
#define SP_PROT_SERVERS (SP_PROT_PCT1_SERVER | SP_PROT_SSL2_SERVER | SP_PROT_SSL3_SERVER | SP_PROT_UNI_SERVER | SP_PROT_TLS1_SERVER)

typedef WINBOOL (*SSL_EMPTY_CACHE_FN_A)(LPSTR pszTargetName,DWORD dwFlags);

WINBOOL SslEmptyCacheA(LPSTR pszTargetName,DWORD dwFlags);

typedef WINBOOL (*SSL_EMPTY_CACHE_FN_W)(LPWSTR pszTargetName,DWORD dwFlags);

WINBOOL SslEmptyCacheW(LPWSTR pszTargetName,DWORD dwFlags);

#define SSL_EMPTY_CACHE_FN __MINGW_NAME_UAW(SSL_EMPTY_CACHE_FN)
#define SslEmptyCache __MINGW_NAME_AW(SslEmptyCache)

typedef struct _SSL_CREDENTIAL_CERTIFICATE {
  DWORD cbPrivateKey;
  PBYTE pPrivateKey;
  DWORD cbCertificate;
  PBYTE pCertificate;
  PSTR pszPassword;
} SSL_CREDENTIAL_CERTIFICATE,*PSSL_CREDENTIAL_CERTIFICATE;

#define SCHANNEL_SECRET_TYPE_CAPI 0x00000001
#define SCHANNEL_SECRET_PRIVKEY 0x00000002
#define SCH_CRED_X509_CERTCHAIN 0x00000001
#define SCH_CRED_X509_CAPI 0x00000002
#define SCH_CRED_CERT_CONTEXT 0x00000003

struct _HMAPPER;
typedef struct _SCH_CRED {
  DWORD dwVersion;
  DWORD cCreds;
  PVOID *paSecret;
  PVOID *paPublic;
  DWORD cMappers;
  struct _HMAPPER **aphMappers;
} SCH_CRED,*PSCH_CRED;

typedef struct _SCH_CRED_SECRET_CAPI {
  DWORD dwType;
  HCRYPTPROV hProv;
} SCH_CRED_SECRET_CAPI,*PSCH_CRED_SECRET_CAPI;

typedef struct _SCH_CRED_SECRET_PRIVKEY {
  DWORD dwType;
  PBYTE pPrivateKey;
  DWORD cbPrivateKey;
  PSTR pszPassword;
} SCH_CRED_SECRET_PRIVKEY,*PSCH_CRED_SECRET_PRIVKEY;

typedef struct _SCH_CRED_PUBLIC_CERTCHAIN {
  DWORD dwType;
  DWORD cbCertChain;
  PBYTE pCertChain;
} SCH_CRED_PUBLIC_CERTCHAIN,*PSCH_CRED_PUBLIC_CERTCHAIN;

typedef struct _SCH_CRED_PUBLIC_CAPI {
  DWORD dwType;
  HCRYPTPROV hProv;
} SCH_CRED_PUBLIC_CAPI,*PSCH_CRED_PUBLIC_CAPI;

typedef struct _PctPublicKey {
  DWORD Type;
  DWORD cbKey;
  UCHAR pKey[1];
} PctPublicKey;

typedef struct _X509Certificate {
  DWORD Version;
  DWORD SerialNumber[4];
  ALG_ID SignatureAlgorithm;
  FILETIME ValidFrom;
  FILETIME ValidUntil;
  PSTR pszIssuer;
  PSTR pszSubject;
  PctPublicKey *pPublicKey;
} X509Certificate,*PX509Certificate;

WINBOOL SslGenerateKeyPair(PSSL_CREDENTIAL_CERTIFICATE pCerts,PSTR pszDN,PSTR pszPassword,DWORD Bits);
VOID SslGenerateRandomBits(PUCHAR pRandomData,LONG cRandomData);
WINBOOL SslCrackCertificate(PUCHAR pbCertificate,DWORD cbCertificate,DWORD dwFlags,PX509Certificate *ppCertificate);
VOID SslFreeCertificate(PX509Certificate pCertificate);
DWORD WINAPI SslGetMaximumKeySize(DWORD Reserved);
WINBOOL SslGetDefaultIssuers(PBYTE pbIssuers,DWORD *pcbIssuers);

#define SSL_CRACK_CERTIFICATE_NAME TEXT("SslCrackCertificate")
#define SSL_FREE_CERTIFICATE_NAME TEXT("SslFreeCertificate")

typedef WINBOOL (WINAPI *SSL_CRACK_CERTIFICATE_FN)(PUCHAR pbCertificate,DWORD cbCertificate,WINBOOL VerifySignature,PX509Certificate *ppCertificate);
typedef VOID (WINAPI *SSL_FREE_CERTIFICATE_FN)(PX509Certificate pCertificate);

#if (_WIN32_WINNT >= 0x0600)
typedef struct _SecPkgContext_EapPrfInfo {
  DWORD dwVersion;
  DWORD cbPrfData;
} SecPkgContext_EapPrfInfo, *PSecPkgContext_EapPrfInfo;
#endif /*(_WIN32_WINNT >= 0x0600)*/
#if (_WIN32_WINNT >= 0x0601)
typedef struct _SecPkgContext_SupportedSignatures {
  WORD cSignatureAndHashAlgorithms;
  WORD *pSignatureAndHashAlgorithms;
} SecPkgContext_SupportedSignatures, *PSecPkgContext_SupportedSignatures;
#endif /*(_WIN32_WINNT >= 0x0601)*/
#endif
