#
# An extra bit of logic for the Win32-only functionality that is missing from the
# version from cryptography.
#

import sys

INCLUDES = """
#include <Wincrypt.h>
"""

TYPES = """
typedef ... *HCERTSTORE;
typedef ... *HCRYPTPROV_LEGACY;

typedef struct {
    DWORD      dwCertEncodingType;
    BYTE       *pbCertEncoded;
    DWORD      cbCertEncoded;
    ...;
} CERT_CONTEXT, *PCCERT_CONTEXT;

typedef struct {
    DWORD      dwCertEncodingType;
    BYTE       *pbCrlEncoded;
    DWORD      cbCrlEncoded;
    ...;
} CRL_CONTEXT, *PCCRL_CONTEXT;

typedef struct {
    DWORD cUsageIdentifier;
    LPSTR *rgpszUsageIdentifier;
    ...;
} CERT_ENHKEY_USAGE, *PCERT_ENHKEY_USAGE;
"""

FUNCTIONS = """
HCERTSTORE WINAPI CertOpenStore(
         LPCSTR            lpszStoreProvider,
         DWORD             dwMsgAndCertEncodingType,
         HCRYPTPROV_LEGACY hCryptProv,
         DWORD             dwFlags,
         const char        *pvPara
);
PCCERT_CONTEXT WINAPI CertEnumCertificatesInStore(
         HCERTSTORE     hCertStore,
         PCCERT_CONTEXT pPrevCertContext
);
BOOL WINAPI CertFreeCertificateContext(
         PCCERT_CONTEXT pCertContext
);
BOOL WINAPI CertFreeCRLContext(
         PCCRL_CONTEXT pCrlContext
);
BOOL WINAPI CertCloseStore(
         HCERTSTORE hCertStore,
         DWORD      dwFlags
);
BOOL WINAPI CertGetEnhancedKeyUsage(
         PCCERT_CONTEXT     pCertContext,
         DWORD              dwFlags,
         PCERT_ENHKEY_USAGE pUsage,
         DWORD              *pcbUsage
);
PCCRL_CONTEXT WINAPI CertEnumCRLsInStore(
         HCERTSTORE    hCertStore,
         PCCRL_CONTEXT pPrevCrlContext
);
"""

# cryptography does not use MACROS anymore
# MACROS = """
TYPES += """
#define CERT_STORE_READONLY_FLAG ...
#define CERT_SYSTEM_STORE_LOCAL_MACHINE ...
#define CRYPT_E_NOT_FOUND ...
#define CERT_FIND_PROP_ONLY_ENHKEY_USAGE_FLAG ...
#define CERT_FIND_EXT_ONLY_ENHKEY_USAGE_FLAG ...
#define X509_ASN_ENCODING ...
#define PKCS_7_ASN_ENCODING ...

static const LPCSTR CERT_STORE_PROV_SYSTEM_A;
"""

CUSTOMIZATIONS = """
"""
