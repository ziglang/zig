/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_CARDMOD
#define _INC_CARDMOD
#include <wincrypt.h>

#define CARD_BUFFER_SIZE_ONLY 0x20000000
#define CARD_PADDING_INFO_PRESENT 0x40000000

#define CARD_PADDING_NONE  0
#define CARD_PADDING_PKCS1 1
#define CARD_PADDING_PSS   4

#define CARD_CREATE_CONTAINER_KEY_GEN 1
#define CARD_CREATE_CONTAINER_KEY_IMPORT 2

#define AT_KEYEXCHANGE 1
#define AT_SIGNATURE   2
#define AT_ECDSA_P256  3
#define AT_ECDSA_P384  4
#define AT_ECDSA_P521  5
#define AT_ECDHE_P256  6
#define AT_ECDHE_P384  7
#define AT_ECDHE_P521  8

#ifdef __cplusplus
extern "C" {
#endif

#define InvalidAc 0

typedef enum _CARD_DIRECTORY_ACCESS_CONDITION {
  UserCreateDeleteDirAc    = 1,
  AdminCreateDeleteDirAc   = 2 
} CARD_DIRECTORY_ACCESS_CONDITION;

typedef enum _CARD_FILE_ACCESS_CONDITION {
  EveryoneReadUserWriteAc    = 1,
  UserWriteExecuteAc         = 2,
  EveryoneReadAdminWriteAc   = 3,
  UnknownAc                  = 4 
} CARD_FILE_ACCESS_CONDITION;

typedef struct _CARD_SIGNING_INFO {
  DWORD  dwVersion;
  BYTE   bContainerIndex;
  DWORD  dwKeySpec;
  DWORD  dwSigningFlags;
  ALG_ID aiHashAlg;
  PBYTE  pbData;
  DWORD  cbData;
  PBYTE  pbSignedData;
  DWORD  cbSignedData;
  LPVOID pPaddingInfo;
  DWORD  dwPaddingType;
} CARD_SIGNING_INFO, *PCARD_SIGNING_INFO;

typedef struct _CARD_CAPABILITIES {
  DWORD   dwVersion;
  WINBOOL fCertificateCompression;
  WINBOOL fKeyGen;
} CARD_CAPABILITIES, *PCARD_CAPABILITIES;

typedef struct _CONTAINER_INFO {
  DWORD dwVersion;
  DWORD dwReserved;
  DWORD cbSigPublicKey;
  PBYTE pbSigPublicKey;
  DWORD cbKeyExPublicKey;
  PBYTE pbKeyExPublicKey;
} CONTAINER_INFO, *PCONTAINER_INFO;

typedef LPVOID ( WINAPI *PFN_CSP_ALLOC )(SIZE_T Size);
typedef LPVOID ( WINAPI *PFN_CSP_REALLOC )(LPVOID Address,SIZE_T Size);
typedef VOID ( WINAPI *PFN_CSP_FREE )(LPVOID Address);
typedef DWORD ( WINAPI *PFN_CSP_CACHE_ADD_FILE )(
  PVOID pvCacheContext,
  LPWSTR wszTag,
  DWORD dwFlags,
  PBYTE pbData,
  DWORD cbData
);

typedef DWORD ( WINAPI *PFN_CSP_CACHE_LOOKUP_FILE )(
  PVOID pvCacheContext,
  LPWSTR wszTag,
  DWORD dwFlags,
  PBYTE *ppbData,
  PDWORD pcbData
);

typedef DWORD ( WINAPI *PFN_CSP_CACHE_DELETE_FILE )(
  PVOID pvCacheContext,
  LPWSTR wszTag,
  DWORD dwFlags
);

typedef DWORD ( WINAPI *PFN_CSP_PAD_DATA )(
  PCARD_SIGNING_INFO pSigningInfo,
  DWORD cbMaxWidth,
  DWORD *pcbPaddedBuffer,
  PBYTE *ppbPaddedBuffer
);

typedef struct _CARD_DERIVE_KEY {
  DWORD   dwVersion;
  DWORD   dwFlags;
  LPCWSTR pwszKDF;
  BYTE    bSecretAgreementIndex;
  PVOID   pParameterList;
  PUCHAR  pbDerivedKey;
  DWORD   cbDerivedKey;
} CARD_DERIVE_KEY, *PCARD_DERIVE_KEY;

typedef struct _CARD_FILE_INFO {
  DWORD                      dwVersion;
  DWORD                      cbFileSize;
  CARD_FILE_ACCESS_CONDITION AccessCondition;
} CARD_FILE_INFO, *PCARD_FILE_INFO;

typedef struct _CARD_FREE_SPACE_INFO {
  DWORD dwVersion;
  DWORD dwBytesAvailable;
  DWORD dwKeyContainersAvailable;
  DWORD dwMaxKeyContainers;
} CARD_FREE_SPACE_INFO, *PCARD_FREE_SPACE_INFO;

typedef struct _CARD_RSA_DECRYPT_INFO {
  DWORD dwVersion;
  BYTE  bContainerIndex;
  DWORD dwKeySpec;
  PBYTE pbData;
  DWORD cbData;
} CARD_RSA_DECRYPT_INFO, *PCARD_RSA_DECRYPT_INFO;

typedef struct _CARD_DH_AGREEMENT_INFO {
  DWORD dwVersion;
  BYTE  bContainerIndex;
  DWORD dwFlags;
  DWORD dwPublicKey;
  PBYTE pbPublicKey;
  PBYTE pbReserved;
  DWORD cbReserved;
  BYTE  bSecretAgreementIndex;
} CARD_DH_AGREEMENT_INFO, *PCARD_DH_AGREEMENT_INFO;

typedef struct _CARD_KEY_SIZES {
  DWORD dwVersion;
  DWORD dwMinimumBitlen;
  DWORD dwMaximumBitlen;
  DWORD dwIncrementalBitlen;
} CARD_KEY_SIZES, *PCARD_KEY_SIZES;

typedef struct _CARD_DATA *PCARD_DATA;

typedef DWORD (WINAPI *PFN_CARD_DELETE_CONTEXT)(
  PCARD_DATA pCardData
);

typedef DWORD (WINAPI *PFN_CARD_QUERY_CAPABILITIES)(
  PCARD_DATA pCardData,
  PCARD_CAPABILITIES pCardCapabilities
);

typedef DWORD (WINAPI *PFN_CARD_DELETE_CONTAINER)(
  PCARD_DATA pCardData,
  BYTE bContainerIndex,
  DWORD dwReserved
);

typedef DWORD (WINAPI *PFN_CARD_CREATE_CONTAINER)(
  PCARD_DATA pCardData,
  BYTE bContainerIndex,
  DWORD dwFlags,
  DWORD dwKeySpec,
  DWORD dwKeySize,
  PBYTE pbKeyData
);

typedef DWORD (WINAPI *PFN_CARD_GET_CONTAINER_INFO)(
  PCARD_DATA pCardData,
  BYTE bContainerIndex,
  DWORD dwFlags,
  PCONTAINER_INFO pContainerInfo
);

typedef DWORD (WINAPI *PFN_CARD_AUTHENTICATE_PIN)(
  PCARD_DATA pCardData,
  LPWSTR pwszUserId,
  PBYTE pbPin,
  DWORD cbPin,
  PDWORD pcAttemptsRemaining
);

typedef DWORD (WINAPI *PFN_CARD_GET_CHALLENGE)(
  PCARD_DATA pCardData,
  PBYTE *ppbChallengeData,
  PDWORD pcbChallengeData
);

typedef DWORD (WINAPI *PFN_CARD_AUTHENTICATE_CHALLENGE)(
  PCARD_DATA pCardData,
  PBYTE pbResponseData,
  DWORD cbResponseData,
  PDWORD pcAttemptsRemaining
);

typedef DWORD (WINAPI *PFN_CARD_UNBLOCK_PIN)(
  PCARD_DATA pCardData,
  LPWSTR pwszUserId,
  PBYTE pbAuthenticationData,
  DWORD cbAuthenticationData,
  PBYTE pbNewPinData,
  DWORD cbNewPinData,
  DWORD cRetryCount,
  DWORD dwFlags
);

typedef DWORD (WINAPI *PFN_CARD_CHANGE_AUTHENTICATOR)(
  PCARD_DATA pCardData,
  LPWSTR pwszUserId,
  PBYTE pbCurrentAuthenticator,
  DWORD cbCurrentAuthenticator,
  PBYTE pbNewAuthenticator,
  DWORD cbNewAuthenticator,
  DWORD cRetryCount,
  DWORD dwFlags,
  PDWORD pcAttemptsRemaining
);

typedef DWORD (WINAPI *PFN_CARD_DEAUTHENTICATE)(
  PCARD_DATA pCardData,
  LPWSTR pwszUserId,
  DWORD dwFlags
);

typedef DWORD (WINAPI *PFN_CARD_CREATE_DIRECTORY)(
  PCARD_DATA pCardData,
  LPSTR pszDirectory,
  CARD_DIRECTORY_ACCESS_CONDITION AccessCondition
);

typedef DWORD (WINAPI *PFN_CARD_DELETE_DIRECTORY)(
  PCARD_DATA pCardData,
  LPSTR pszDirectoryName
);

typedef DWORD (WINAPI *PFN_CARD_CREATE_FILE)(
  PCARD_DATA pCardData,
  LPSTR pszDirectoryName,
  LPSTR pszFileName,
  DWORD cbInitialCreationSize,
  CARD_FILE_ACCESS_CONDITION AccessCondition
);

typedef DWORD (WINAPI *PFN_CARD_READ_FILE)(
  PCARD_DATA pCardData,
  LPSTR pszDirectoryName,
  LPSTR pszFileName,
  DWORD dwFlags,
  PBYTE *ppbData,
  PDWORD pcbData
);

typedef DWORD (WINAPI *PFN_CARD_WRITE_FILE)(
  PCARD_DATA pCardData,
  LPSTR pszDirectoryName,
  LPSTR pszFileName,
  DWORD dwFlags,
  PBYTE pbData,
  DWORD cbData
);

typedef DWORD (WINAPI *PFN_CARD_DELETE_FILE)(
  PCARD_DATA pCardData,
  LPSTR pszDirectoryName,
  LPSTR pszFileName,
  DWORD dwFlags
);

typedef DWORD (WINAPI *PFN_CARD_ENUM_FILES)(
  PCARD_DATA pCardData,
  LPSTR pszDirectoryName,
  LPSTR *pmszFileNames,
  LPDWORD pdwcbFileName,
  DWORD dwFlags
);

typedef DWORD (WINAPI *PFN_CARD_GET_FILE_INFO)(
  PCARD_DATA pCardData,
  LPSTR pszDirectoryName,
  LPSTR pszFileName,
  PCARD_FILE_INFO pCardFileInfo
);

typedef DWORD (WINAPI *PFN_CARD_QUERY_FREE_SPACE)(
  PCARD_DATA pCardData,
  DWORD dwFlags,
  PCARD_FREE_SPACE_INFO pCardFreeSpaceInfo
);

typedef DWORD (WINAPI *PFN_CARD_QUERY_KEY_SIZES)(
  PCARD_DATA pCardData,
  DWORD dwKeySpec,
  DWORD dwFlags,
  PCARD_KEY_SIZES pKeySizes
);

typedef DWORD (WINAPI *PFN_CARD_SIGN_DATA)(
  PCARD_DATA pCardData,
  PCARD_SIGNING_INFO pInfo
);

typedef DWORD (WINAPI *PFN_CARD_RSA_DECRYPT)(
  PCARD_DATA pCardData,
  PCARD_RSA_DECRYPT_INFO pInfo
);

typedef DWORD (WINAPI *PFN_CARD_CONSTRUCT_DH_AGREEMENT)(
  PCARD_DATA pCardData,
  PCARD_DH_AGREEMENT_INFO pAgreementInfo
);

#if (_WIN32_WINNT >= 0x0600)
typedef DWORD (WINAPI *PFN_CARD_DERIVE_KEY)(
  PCARD_DATA pCardData,
  PCARD_DERIVE_KEY pAgreementInfo
);

typedef DWORD (WINAPI *PFN_CARD_DESTROY_DH_AGREEMENT)(
  PCARD_DATA pCardData,
  BYTE bSecretAgreementIndex,
  DWORD dwFlags
);

typedef DWORD (WINAPI *PFN_CSP_GET_DH_AGREEMENT)(
  PCARD_DATA pCardData,
  PVOID hSecretAgreement,
  BYTE *pbSecretAgreementIndex,
  DWORD dwFlags
);

#else
typedef LPVOID PFN_CARD_DERIVE_KEY;
typedef LPVOID PFN_CARD_DESTROY_DH_AGREEMENT;
typedef LPVOID PFN_CSP_GET_DH_AGREEMENT;
#endif /*(_WIN32_WINNT >= 0x0600)*/

typedef struct _CARD_DATA {
  DWORD                           dwVersion;
  PBYTE                           pbAtr;
  DWORD                           cbAtr;
  LPWSTR                          pwszCardName;
  PFN_CSP_ALLOC                   pfnCspAlloc;
  PFN_CSP_REALLOC                 pfnCspReAlloc;
  PFN_CSP_FREE                    pfnCspFree;
  PFN_CSP_CACHE_ADD_FILE          pfnCspCacheAddFile;
  PFN_CSP_CACHE_LOOKUP_FILE       pfnCspCacheLookupFile;
  PFN_CSP_CACHE_DELETE_FILE       pfnCspCacheDeleteFile;
  PVOID                           pvCacheContext;
  PFN_CSP_PAD_DATA                pfnCspPadData;
  SCARDCONTEXT                    hSCardCtx;
  SCARDHANDLE                     hScard;
  PVOID                           pvVendorSpecific;
  PFN_CARD_DELETE_CONTEXT         pfnCardDeleteContext;
  PFN_CARD_QUERY_CAPABILITIES     pfnCardQueryCapabilities;
  PFN_CARD_DELETE_CONTAINER       pfnCardDeleteContainer;
  PFN_CARD_CREATE_CONTAINER       pfnCardCreateContainer;
  PFN_CARD_GET_CONTAINER_INFO     pfnCardGetContainerInfo;
  PFN_CARD_AUTHENTICATE_PIN       pfnCardAuthenticatePin;
  PFN_CARD_GET_CHALLENGE          pfnCardGetChallenge;
  PFN_CARD_AUTHENTICATE_CHALLENGE pfnCardAuthenticateChallenge;
  PFN_CARD_UNBLOCK_PIN            pfnCardUnblockPin;
  PFN_CARD_CHANGE_AUTHENTICATOR   pfnCardChangeAuthenticator;
  PFN_CARD_DEAUTHENTICATE         pfnCardDeauthenticate;
  PFN_CARD_CREATE_DIRECTORY       pfnCardCreateDirectory;
  PFN_CARD_DELETE_DIRECTORY       pfnCardDeleteDirectory;
  LPVOID                          pvUnused3;
  LPVOID                          pvUnused4;
  PFN_CARD_CREATE_FILE            pfnCardCreateFile;
  PFN_CARD_READ_FILE              pfnCardReadFile;
  PFN_CARD_WRITE_FILE             pfnCardWriteFile;
  PFN_CARD_DELETE_FILE            pfnCardDeleteFile;
  PFN_CARD_ENUM_FILES             pfnCardEnumFiles;
  PFN_CARD_GET_FILE_INFO          pfnCardGetFileInfo;
  PFN_CARD_QUERY_FREE_SPACE       pfnCardQueryFreeSpace;
  PFN_CARD_QUERY_KEY_SIZES        pfnCardQueryKeySizes;
  PFN_CARD_SIGN_DATA              pfnCardSignData;
  PFN_CARD_RSA_DECRYPT            pfnCardRSADecrypt;
  PFN_CARD_CONSTRUCT_DH_AGREEMENT pfnCardConstructDHAgreement;
  PFN_CARD_DERIVE_KEY             pfnCardDeriveKey;
  PFN_CARD_DESTROY_DH_AGREEMENT   pfnCardDestroyDHAgreement;
  PFN_CSP_GET_DH_AGREEMENT        pfnCspGetDHAgreement;
} CARD_DATA, *PCARD_DATA;

DWORD WINAPI CardAcquireContext(
  PCARD_DATA pCardData,
  DWORD dwFlags
);

DWORD WINAPI CardDeleteContainer(
  PCARD_DATA pCardData,
  BYTE bContainerIndex,
  DWORD dwReserved
);

#ifdef __cplusplus
}
#endif
#endif /*_INC_CARDMOD*/
