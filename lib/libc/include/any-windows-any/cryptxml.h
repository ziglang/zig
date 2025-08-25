/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_CRYPTXML
#define _INC_CRYPTXML

#ifdef __cplusplus
extern "C" {
#endif

#ifndef DECLSPEC_IMPORT
#ifndef __WIDL__
#define DECLSPEC_IMPORT __declspec(dllimport)
#else
#define DECLSPEC_IMPORT
#endif
#endif

#ifndef CRYPTXMLAPI
#define CRYPTXMLAPI DECLSPEC_IMPORT
#endif

#ifndef __HCRYPTPROV_OR_NCRYPT_KEY_HANDLE_DEFINED__
#define __HCRYPTPROV_OR_NCRYPT_KEY_HANDLE_DEFINED__
/*Also in wincrypth*/
typedef ULONG_PTR HCRYPTPROV_OR_NCRYPT_KEY_HANDLE;
#endif /*__HCRYPTPROV_OR_NCRYPT_KEY_HANDLE_DEFINED__*/

#ifndef __BCRYPT_KEY_HANDLE_DEFINED__
#define __BCRYPT_KEY_HANDLE_DEFINED__
/*also in bcrypt.h*/
typedef LPVOID BCRYPT_KEY_HANDLE;
#endif /*__BCRYPT_KEY_HANDLE_DEFINED__*/

typedef HANDLE HCRYPTXML;

#if (_WIN32_WINNT >= 0x0601)

typedef enum tagCRYPT_XML_CHARSET {
  CRYPT_XML_CHARSET_AUTO      = 0,
  CRYPT_XML_CHARSET_UTF8      = 1,
  CRYPT_XML_CHARSET_UTF16LE   = 2,
  CRYPT_XML_CHARSET_UTF16BE   = 3 
} CRYPT_XML_CHARSET;

typedef enum tagCRYPT_XML_KEYINFO_SPEC {
  CRYPT_XML_KEYINFO_SPEC_NONE      = 0,
  CRYPT_XML_KEYINFO_SPEC_ENCODED   = 1,
  CRYPT_XML_KEYINFO_SPEC_PARAM     = 2 
} CRYPT_XML_KEYINFO_SPEC;

typedef enum tagCRYPT_XML_PROPERTY_ID {
  CRYPT_XML_PROPERTY_MAX_HEAP_SIZE        = 1,
  CRYPT_XML_PROPERTY_SIGNATURE_LOCATION   = 2,
  CRYPT_XML_PROPERTY_MAX_SIGNATURES       = 3,
  CRYPT_XML_PROPERTY_DOC_DECLARATION      = 4,
  CRYPT_XML_PROPERTY_XML_OUTPUT_CHARSET   = 5,
  CRYPT_XML_PROPERTY_HMAC_OUTPUT_LENGTH   = 6 
} CRYPT_XML_PROPERTY_ID;

typedef struct _CRYPT_XML_BLOB {
  CRYPT_XML_CHARSET dwCharset;
  ULONG             cbData;
  BYTE              *pbData;
} CRYPT_XML_BLOB, *PCRYPT_XML_BLOB;

#define CRYPT_XML_BLOB_MAX 0x7FFFFFF8

typedef struct _CRYPT_XML_ALGORITHM {
  ULONG          cbSize;
  LPCWSTR        wszAlgorithm;
  CRYPT_XML_BLOB Encoded;
} CRYPT_XML_ALGORITHM, *PCRYPT_XML_ALGORITHM;

typedef struct _CRYPT_XML_ALGORITHM_INFO {
  DWORD cbSize;
  WCHAR *wszAlgorithmURI;
  WCHAR *wszName;
  DWORD dwGroupId;
  WCHAR *wszCNGAlgid;
  WCHAR wszCNGExtraAlgid;
  DWORD dwSignFlags;
  DWORD dwVerifyFlags;
  void  pvPaddingInfo;
  void  pvExtraInfo;
} CRYPT_XML_ALGORITHM_INFO, *PCRYPT_XML_ALGORITHM_INFO;

#define CRYPT_XML_GROUP_ID_HASH 1
#define CRYPT_XML_GROUP_ID_SIGN 2

typedef HRESULT (CALLBACK *PFN_CRYPT_XML_WRITE_CALLBACK)(
  void *pvCallbackState,
  BYTE pbData,
  ULONG cbData
);

typedef HRESULT ( WINAPI *CryptXmlDllEncodeAlgorithm )(
  CRYPT_XML_ALGORITHM_INFO *pAlgInfo,
  CRYPT_XML_CHARSET dwCharset,
  void *pvCallbackState,
  PFN_CRYPT_XML_WRITE_CALLBACK pfnWrite
);

typedef HANDLE CRYPT_XML_DIGEST;

typedef HRESULT ( WINAPI *CryptXmlDllCreateDigest )(
  const CRYPT_XML_ALGORITHM *pDigestMethod,
  ULONG *pcbSize,
  CRYPT_XML_DIGEST *phDigest
);

typedef HRESULT ( WINAPI *CryptXmlDllDigestData )(
    CRYPT_XML_DIGEST hDigest,
    BYTE *pbData,
    ULONG cbDigest
);

typedef HRESULT ( WINAPI *CryptXmlDllFinalizeDigest )(
  CRYPT_XML_DIGEST hDigest,
  BYTE *pbDigest,
  ULONG cbDigest
);

typedef HRESULT ( WINAPI *CryptXmlDllCloseDigest )(
  CRYPT_XML_DIGEST hDigest
);

typedef HRESULT ( WINAPI *CryptXmlDllSignData )(
  const CRYPT_XML_ALGORITHM *pSignatureMethod,
  HCRYPTPROV_OR_NCRYPT_KEY_HANDLE hCryptProvOrNCryptKey,
  DWORD dwKeySpec,
  const BYTE *pbInput,
  ULONG cbInput,
  BYTE *pbOutput,
  ULONG cbOutput,
  ULONG *pcbResult
);

typedef HRESULT ( WINAPI *CryptXmlDllVerifySignature )(
  const CRYPT_XML_ALGORITHM *pSignatureMethod,
  HCRYPTXML_PROV hCryptProv,
  HCRYPTXML_KEY hKey,
  const BYTE *pbInput,
  ULONG cbInput,
  const BYTE *pbSignature,
  ULONG cbSignature
);

typedef HRESULT ( WINAPI *CryptXmlDllCreateKey )(
  CRYPT_XML_BLOB *pEncoded,
  const BCRYPT_KEY_HANDLE *phKey
);

typedef HRESULT ( WINAPI *CryptXmlDllEncodeKeyValue )(
  NCRYPT_KEY_HANDLE hKey,
  CRYPT_XML_CHARSET dwCharset,
  void *pvCallbackState,
  PFN_CRYPT_XML_WRITE_CALLBACK pfnWrite
);

typedef struct _CRYPT_XML_CRYPTOGRAPHIC_INTERFACE {
  ULONG                       cbSize;
  CryptXmlDllEncodeAlgorithm  fpCryptXmlEncodeAlgorithm;
  CryptXmlDllCreateDigest     fpCryptXmlCreateDigest;
  CryptXmlDllDigestData       fpCryptXmlDigestData;
  CryptXmlDllFinalizeDigest   fpCryptXmlFinalizeDigest;
  CryptXmlDllCloseDigest      fpCryptXmlCloseDigest;
  CryptXmlDllSignData         fpCryptXmlSignData;
  CryptXmlDllVerifySignature  fpCryptXmlVerifySignature;
  CryptXmlDllGetAlgorithmInfo fpCryptXmlGetAlgorithmInfo;
} CRYPT_XML_CRYPTOGRAPHIC_INTERFACE, *PCRYPT_XML_CRYPTOGRAPHIC_INTERFACE;

typedef HRESULT ( WINAPI *CryptXmlDllGetInterface )(
  DWORD dwFlags,
  const CRYPT_XML_ALGORITHM_INFO *pMethod,
  CRYPT_XML_CRYPTOGRAPHIC_INTERFACE *pInterface
);

typedef struct _CRYPT_XML_DATA_BLOB {
  ULONG cbData;
  BYTE  *pbData;
} CRYPT_XML_DATA_BLOB, *PCRYPT_XML_DATA_BLOB;

typedef HRESULT (CALLBACK *PFN_CRYPT_XML_DATA_PROVIDER_READ)(
  void *pvCallbackState,
  BYTE *pbData,
  ULONG cbData,
  ULONG *pcbRead
);

typedef HRESULT (CALLBACK *PFN_CRYPT_XML_DATA_PROVIDER_CLOSE)(
  void *pvCallbackState
);

typedef struct _CRYPT_XML_DATA_PROVIDER {
  void                              *pvCallbackState;
  ULONG                             cbBufferSize;
  PFN_CRYPT_XML_DATA_PROVIDER_READ  pfnRead;
  PFN_CRYPT_XML_DATA_PROVIDER_CLOSE pfnClose;
} CRYPT_XML_DATA_PROVIDER, *PCRYPT_XML_DATA_PROVIDER;

typedef HRESULT (CALLBACK *PFN_CRYPT_XML_CREATE_TRANSFORM)(
  const CRYPT_XML_ALGORITHM *pTransform,
  CRYPT_XML_DATA_PROVIDER *pProviderIn,
  CRYPT_XML_DATA_PROVIDER *pProviderOut
);

typedef struct _CRYPT_XML_TRANSFORM_INFO {
  ULONG                          cbSize;
  LPCWSTR                        wszAlgorithm;
  ULONG                          cbBufferSize;
  DWORD                          dwFlags;
  PFN_CRYPT_XML_CREATE_TRANSFORM pfnCreateTransform;
} CRYPT_XML_TRANSFORM_INFO, *PCRYPT_XML_TRANSFORM_INFO;

#define CRYPT_XML_TRANSFORM_ON_STREAM 0x00000001
#define CRYPT_XML_TRANSFORM_ON_NODESET 0x00000002
#define CRYPT_XML_TRANSFORM_URI_QUERY_STRING 0x00000003

typedef struct _CRYPT_XML_TRANSFORM_CHAIN_CONFIG {
  ULONG                     cbSize;
  ULONG                     cTransformInfo;
  PCRYPT_XML_TRANSFORM_INFO *rgpTransformInfo;
} CRYPT_XML_TRANSFORM_CHAIN_CONFIG, *PCRYPT_XML_TRANSFORM_CHAIN_CONFIG;

typedef struct _CRYPT_XML_REFERENCE {
  ULONG               cbSize;
  HCRYPTXML           hReference;
  LPCWSTR             wszId;
  LPCWSTR             wszUri;
  LPCWSTR             wszType;
  CRYPT_XML_ALGORITHM DigestMethod;
  CRYPT_DATA_BLOB     DigestValue;
  ULONG               cTransform;
  CRYPT_XML_ALGORITHM *rgTransform;
} CRYPT_XML_REFERENCE, *PCRYPT_XML_REFERENCE;

typedef struct _CRYPT_XML_REFERENCES {
  ULONG                cReference;
  PCRYPT_XML_REFERENCE *rgpReference;
} CRYPT_XML_REFERENCES, *PCRYPT_XML_REFERENCES;

typedef struct _CRYPT_XML_SIGNED_INFO {
  ULONG                cbSize;
  LPCWSTR              wszId;
  CRYPT_XML_ALGORITHM  Canonicalization;
  CRYPT_XML_ALGORITHM  SignatureMethod;
  ULONG                cReference;
  PCRYPT_XML_REFERENCE *rgpReference;
  CRYPT_XML_BLOB       Encoded;
} CRYPT_XML_SIGNED_INFO, *PCRYPT_XML_SIGNED_INFO;

typedef struct _CRYPT_XML_ISSUER_SERIAL {
  LPCWSTR wszIssuer ;
  LPCWSTR wszSerial;
} CRYPT_XML_ISSUER_SERIAL;

typedef struct _CRYPT_XML_X509DATA_ITEM {
  DWORD dwType;
  __C89_NAMELESS union {
    CRYPT_XML_ISSUER_SERIAL IssuerSerial;
    CRYPT_XML_DATA_BLOB     SKI;
    LPCWSTR                 wszSubjectName;
    CRYPT_XML_DATA_BLOB     Certificate;
    CRYPT_XML_DATA_BLOB     CRL;
    CRYPT_XML_BLOB          Custom;
  } ;
} CRYPT_XML_X509DATA_ITEM;

#define CRYPT_XML_X509DATA_TYPE_ISSUER_SERIAL 0x00000001
#define CRYPT_XML_X509DATA_TYPE_SKI 0x00000002
#define CRYPT_XML_X509DATA_TYPE_SUBJECT_NAME 0x00000003
#define CRYPT_XML_X509DATA_TYPE_CERTIFICATE 0x00000004
#define CRYPT_XML_X509DATA_TYPE_CRL 0x00000005
#define CRYPT_XML_X509DATA_TYPE_CUSTOM 0x00000006

typedef struct _CRYPT_XML_X509DATA {
  UINT                    cX509Data;
  CRYPT_XML_X509DATA_ITEM *rgX509Data;
} CRYPT_XML_X509DATA, *PCRYPT_XML_X509DATA;

typedef struct _CRYPT_XML_KEY_INFO_ITEM {
  DWORD dwType;
  __C89_NAMELESS union {
    LPCWSTR             wszKeyName;
    CRYPT_XML_KEY_VALUE KeyValue;
    CRYPT_XML_BLOB      RetrievalMethod;
    CRYPT_XML_X509DATA  X509Data;
    CRYPT_XML_BLOB      Custom;
  } ;
} CRYPT_XML_KEY_INFO_ITEM;

#define CRYPT_XML_KEYINFO_TYPE_KEYNAME 0x00000001
#define CRYPT_XML_KEYINFO_TYPE_KEYVALUE 0x00000002
#define CRYPT_XML_KEYINFO_TYPE_RETRIEVAL 0x00000003
#define CRYPT_XML_KEYINFO_TYPE_X509DATA 0x00000004
#define CRYPT_XML_KEYINFO_TYPE_CUSTOM 0x00000005

typedef struct _CRYPT_XML_KEY_DSA_KEY_VALUE {
  CRYPT_XML_DATA_BLOB P;
  CRYPT_XML_DATA_BLOB Q;
  CRYPT_XML_DATA_BLOB G;
  CRYPT_XML_DATA_BLOB Y;
  CRYPT_XML_DATA_BLOB J;
  CRYPT_XML_DATA_BLOB Seed;
  CRYPT_XML_DATA_BLOB Counter;
} CRYPT_XML_KEY_DSA_KEY_VALUE;

typedef struct _CRYPT_XML_KEY_RSA_KEY_VALUE {
  CRYPT_XML_DATA_BLOB Modulus;
  CRYPT_XML_DATA_BLOB Exponent;
} CRYPT_XML_KEY_RSA_KEY_VALUE;

typedef struct _CRYPT_XML_KEY_ECDSA_KEY_VALUE {
  LPCWSTR                  wszNamedCurve;
  CRYPT_XML_DATA_BLOB      X;
  CRYPT_XML_DATA_BLOB      Y;
  CRYPT_XML_BLOB           ExplicitPara;
} CRYPT_XML_KEY_ECDSA_KEY_VALUE;

typedef struct _CRYPT_XML_KEY_VALUE {
  DWORD dwType;
  __C89_NAMELESS union {
    CRYPT_XML_KEY_DSA_KEY_VALUE   DSAKeyValue;
    CRYPT_XML_KEY_RSA_KEY_VALUE   RSAKeyValue;
    CRYPT_XML_KEY_ECDSA_KEY_VALUE ECDSAKeyValue;
    CRYPT_XML_BLOB                Custom;
  } ;
} CRYPT_XML_KEY_VALUE;

#define CRYPT_XML_KEY_VALUE_TYPE_DSA 0x00000001
#define CRYPT_XML_KEY_VALUE_TYPE_RSA 0x00000002
#define CRYPT_XML_KEY_VALUE_TYPE_ECDSA 0x00000003
#define CRYPT_XML_KEY_VALUE_TYPE_CUSTOM 0x00000004

typedef struct _CRYPT_XML_KEY_INFO {
  ULONG                   cbSize;
  LPCWSTR                 wszId;
  UINT                    cKeyInfo;
  CRYPT_XML_KEY_INFO_ITEM *rgKeyInfo;
  BCRYPT_KEY_HANDLE       hVerifyKey;
} CRYPT_XML_KEY_INFO;

typedef struct _CRYPT_XML_OBJECT {
  ULONG                cbSize;
  HCRYPTXML            hObject;
  LPCWSTR              wszId;
  LPCWSTR              wszMimeType;
  LPCWSTR              wszEncoding;
  CRYPT_XML_REFERENCES Manifest;
  CRYPT_XML_BLOB       Encoded;
} CRYPT_XML_OBJECT, *PCRYPT_XML_OBJECT;

typedef struct _CRYPT_XML_SIGNATURE {
  ULONG                 cbSize;
  HCRYPTXML             hSignature;
  LPCWSTR               wszId;
  CRYPT_XML_SIGNED_INFO SignedInfo;
  CRYPT_DATA_BLOB       SignatureValue;
  CRYPT_XML_KEY_INFO    *pKeyInfo;
  ULONG                 cObject;
  PCRYPT_XML_OBJECT     *rgpObject;
} CRYPT_XML_SIGNATURE, *PCRYPT_XML_SIGNATURE;

typedef struct _CRYPT_XML_DOC_CTXT {
  ULONG                            cbSize;
  HCRYPTXML                        hDocCtxt;
  CRYPT_XML_TRANSFORM_CHAIN_CONFIG *pTransformsConfig;
  ULONG                            cSignature;
  PCRYPT_XML_SIGNATURE             *rgpSignature;
} CRYPT_XML_DOC_CTXT, *PCRYPT_XML_DOC_CTXT;

typedef struct _CRYPT_XML_KEYINFO_PARAM {
  LPCWSTR   wszId;
  LPCWSTR   wszKeyName;
  CERT_BLOB SKI;
  LPCWSTR   wszSubjectName;
  ULONG     cCertificate;
  CERT_BLOB *rgCertificate;
  ULONG     cCRL;
  CERT_BLOB *rgCRL;
} CRYPT_XML_KEYINFO_PARAM;

typedef struct _CRYPT_XML_PROPERTY {
  CRYPT_XML_PROPERTY_ID dwPropId;
  const void            *pvValue;
  ULONG                 cbValue;
} CRYPT_XML_PROPERTY, *PCRYPT_XML_PROPERTY;

typedef struct _CRYPT_XML_STATUS {
  ULONG cbSize;
  DWORD dwErrorStatus;
  DWORD dwInfoStatus;
} CRYPT_XML_STATUS, *PCRYPT_XML_STATUS;

#define CRYPT_XML_STATUS_ERROR_NOT_RESOLVED 0x00000001
#define CRYPT_XML_STATUS_ERROR_DIGEST_INVALID 0x00000002
#define CRYPT_XML_STATUS_ERROR_NOT_SUPPORTED_ALGORITHM 0x00000005
#define CRYPT_XML_STATUS_ERROR_NOT_SUPPORTED_TRANSFORM 0x00000008
#define CRYPT_XML_STATUS_ERROR_SIGNATURE_INVALID 0x00010000
#define CRYPT_XML_STATUS_ERROR_KEYINFO_NOT_PARSED 0x00020000

#define CRYPT_XML_STATUS_INTERNAL_REFERENCE 0x00000001
#define CRYPT_XML_STATUS_KEY_AVAILABLE 0x00000002
#define CRYPT_XML_STATUS_DIGESTING 0x00000004
#define CRYPT_XML_STATUS_DIGEST_VALID 0x00000008
#define CRYPT_XML_STATUS_SIGNATURE_VALID 0x00010000
#define CRYPT_XML_STATUS_OPENED_TO_ENCODE 0x80000000

CRYPTXMLAPI HRESULT WINAPI CryptXmlAddObject(
  HCRYPTXML hSignatureOrObject,
  DWORD dwFlags,
  const CRYPT_XML_PROPERTY *rgProperty,
  ULONG cProperty,
  const PCRYPT_XML_BLOB pEncoded,
  const CRYPT_XML_OBJECT **ppObject
);

CRYPTXMLAPI HRESULT WINAPI CryptXmlClose(
  HCRYPTXML hCryptXml
);

CRYPTXMLAPI HRESULT WINAPI CryptXmlCreateReference(
  HCRYPTXML hCryptXml,
  DWORD dwFlags,
  LPCWSTR wszId,
  LPCWSTR wszURI,
  LPCWSTR wszType,
  const CRYPT_XML_ALGORITHM *pDigestMethod,
  ULONG cTransform,
  const CRYPT_XML_ALGORITHM *rgTransform,
  HCRYPTXML *phReference
);

#define CRYPT_XML_FLAG_CREATE_REFERENCE_AS_OBJECT 0x00000001

CRYPTXMLAPI HRESULT WINAPI CryptXmlDigestReference(
  HCRYPTXML hReference,
  DWORD dwFlags,
  CRYPT_XML_DATA_PROVIDER *pDataProviderIn
);

#define CRYPT_XML_REFERENCE_DATA_TRANSFORMED 0x00000001

CRYPTXMLAPI HRESULT WINAPI CryptXmlEncode(
  HCRYPTXML hCryptXml,
  CRYPT_XML_CHARSET dwCharset,
  const CRYPT_XML_PROPERTY *rgProperty,
  ULONG cProperty,
  void *pvCallbackState,
  PFN_CRYPT_XML_WRITE_CALLBACK pfnWrite
);

CRYPTXMLAPI HRESULT WINAPI CryptXmlGetAlgorithmInfo(
  const CRYPT_XML_ALGORITHM *pXmlAlgorithm,
  DWORD dwFlags,
  CRYPT_XML_ALGORITHM_INFO **ppAlgInfo
);

CRYPTXMLAPI HRESULT WINAPI CryptXmlGetDocContext(
  HCRYPTXML hCryptXml,
  const CRYPT_XML_DOC_CTXT **ppStruct
);

CRYPTXMLAPI HRESULT WINAPI CryptXmlGetReference(
  HCRYPTXML HCRYPTXML,
  const CRYPT_XML_REFERENCE **ppStruct
);

CRYPTXMLAPI HRESULT WINAPI CryptXmlGetSignature(
  HCRYPTXML hCryptXml,
  const PCRYPT_XML_SIGNATURE **ppStruct
);

CRYPTXMLAPI HRESULT WINAPI CryptXmlGetStatus(
  HCRYPTXML hCryptXml,
  CRYPT_XML_STATUS *pStatus
);

CRYPTXMLAPI HRESULT WINAPI CryptXmlGetTransforms(
  PCRYPT_XML_TRANSFORM_CHAIN_CONFIG **pConfig
);

CRYPTXMLAPI HRESULT WINAPI CryptXmlImportPublicKey(
  DWORD dwFlags,
  CRYPT_XML_KEY_VALUE *pKeyValue,
  BCRYPT_KEY_HANDLE *phKey
);

#define CRYPT_XML_FLAG_DISABLE_EXTENSIONS 0x10000000

CRYPTXMLAPI HRESULT WINAPI CryptXmlOpenToDecode(
  CRYPT_XML_TRANSFORM_CHAIN_CONFIG *pConfig,
  DWORD dwFlags,
  const CRYPT_XML_PROPERTY *rgProperty,
  ULONG cProperty,
  const CRYPT_XML_BLOB *pEncoded,
  HCRYPTXML phCryptXml
);

#define CRYPT_XML_FLAG_NO_SERIALIZE 0x80000000
#define CRYPT_XML_FLAG_DISABLE_EXTENSION 0x10000000

CRYPTXMLAPI HRESULT WINAPI CryptXmlOpenToEncode(
  CRYPT_XML_TRANSFORM_CHAIN_CONFIG *pConfig,
  DWORD dwFlags,
  LPCWSTR wszId,
  CRYPT_XML_PROPERTY *rgProperty,
  ULONG cProperty,
  CRYPT_XML_BLOB *pEncoded,
  HCRYPTXML *phSignature
);

#define CRYPT_XML_FLAG_NO_SERIALIZE 0x80000000
#define CRYPT_XML_FLAG_DISABLE_EXTENSIONS 0x10000000

CRYPTXMLAPI HRESULT WINAPI CryptXmlSetHMACSecret(
  HCRYPTXML hSignature,
  const BYTE *pbSecret,
  ULONG cbSecret
);

CRYPTXMLAPI HRESULT WINAPI CryptXmlSign(
  HCRYPTXML hSignature,
  HCRYPTPROV_OR_NCRYPT_KEY_HANDLE hKey,
  DWORD dwKeySpec,
  DWORD dwFlags,
  CRYPT_XML_KEYINFO_SPEC dwKeyInfoSpec,
  const void pvKeyInfoSpec,
  const CRYPT_XML_ALGORITHM pSignatureMethod,
  const CRYPT_XML_ALGORITHM pCanonicalization
);

#define AT_KEYEXCHANGE 1
#define AT_SIGNATURE 2
#define CERT_NCRYPT_KEY_SPEC 0xFFFFFFFF

#define CRYPT_XML_SIGN_ADD_KEYVALUE 0x00000001
#define CRYPT_XML_FLAG_DISABLE_EXTENSIONS 0x10000000

CRYPTXMLAPI HRESULT WINAPI CryptXmlVerifySignature(
  HCRYPTXML hSignature,
  BCRYPT_KEY_HANDLE hKey,
  DWORD dwFlags
);

#endif /*(_WIN32_WINNT >= 0x0601)*/

#ifdef __cplusplus
}
#endif
#endif /*_INC_CRYPTXML*/
