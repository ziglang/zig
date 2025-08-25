/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __WINEFS_H__
#define __WINEFS_H__

#ifdef __cplusplus
extern "C" {
#endif

#ifndef ALGIDDEF
#define ALGIDDEF
  typedef unsigned int ALG_ID;
#endif

  typedef struct _CERTIFICATE_BLOB {
    DWORD dwCertEncodingType;
    DWORD cbData;
    PBYTE pbData;
  } EFS_CERTIFICATE_BLOB,*PEFS_CERTIFICATE_BLOB;

  typedef struct _EFS_HASH_BLOB {
    DWORD cbData;
    PBYTE pbData;
  } EFS_HASH_BLOB,*PEFS_HASH_BLOB;

  typedef struct _EFS_RPC_BLOB {
    DWORD cbData;
    PBYTE pbData;
  } EFS_RPC_BLOB,*PEFS_RPC_BLOB;

  typedef struct _EFS_KEY_INFO {
    DWORD dwVersion;
    ULONG Entropy;
    ALG_ID Algorithm;
    ULONG KeyLength;
  } EFS_KEY_INFO,*PEFS_KEY_INFO;

  typedef struct _ENCRYPTION_CERTIFICATE {
    DWORD cbTotalLength;
    SID *pUserSid;
    PEFS_CERTIFICATE_BLOB pCertBlob;
  } ENCRYPTION_CERTIFICATE,*PENCRYPTION_CERTIFICATE;

#define MAX_SID_SIZE 256

  typedef struct _ENCRYPTION_CERTIFICATE_HASH {
    DWORD cbTotalLength;
    SID *pUserSid;
    PEFS_HASH_BLOB pHash;
    LPWSTR lpDisplayInformation;
  } ENCRYPTION_CERTIFICATE_HASH,*PENCRYPTION_CERTIFICATE_HASH;

  typedef struct _ENCRYPTION_CERTIFICATE_HASH_LIST {
    DWORD nCert_Hash;
    PENCRYPTION_CERTIFICATE_HASH *pUsers;
  } ENCRYPTION_CERTIFICATE_HASH_LIST,*PENCRYPTION_CERTIFICATE_HASH_LIST;

  typedef struct _ENCRYPTION_CERTIFICATE_LIST {
    DWORD nUsers;
    PENCRYPTION_CERTIFICATE *pUsers;
  } ENCRYPTION_CERTIFICATE_LIST,*PENCRYPTION_CERTIFICATE_LIST;

  WINADVAPI DWORD WINAPI QueryUsersOnEncryptedFile(LPCWSTR lpFileName,PENCRYPTION_CERTIFICATE_HASH_LIST *pUsers);
  WINADVAPI DWORD WINAPI QueryRecoveryAgentsOnEncryptedFile(LPCWSTR lpFileName,PENCRYPTION_CERTIFICATE_HASH_LIST *pRecoveryAgents);
  WINADVAPI DWORD WINAPI RemoveUsersFromEncryptedFile(LPCWSTR lpFileName,PENCRYPTION_CERTIFICATE_HASH_LIST pHashes);
  WINADVAPI DWORD WINAPI AddUsersToEncryptedFile(LPCWSTR lpFileName,PENCRYPTION_CERTIFICATE_LIST pUsers);
  WINADVAPI DWORD WINAPI SetUserFileEncryptionKey(PENCRYPTION_CERTIFICATE pEncryptionCertificate);
  WINADVAPI VOID WINAPI FreeEncryptionCertificateHashList(PENCRYPTION_CERTIFICATE_HASH_LIST pHashes);
  WINADVAPI WINBOOL WINAPI EncryptionDisable(LPCWSTR DirPath,WINBOOL Disable);
  WINADVAPI DWORD WINAPI DuplicateEncryptionInfoFile(LPCWSTR SrcFileName,LPCWSTR DstFileName,DWORD dwCreationDistribution,DWORD dwAttributes,CONST LPSECURITY_ATTRIBUTES lpSecurityAttributes);

#ifdef __cplusplus
}
#endif
#endif
