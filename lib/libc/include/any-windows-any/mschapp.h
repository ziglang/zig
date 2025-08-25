/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSCHAPP_H_
#define _MSCHAPP_H_

#ifndef _NTCRYPT_
#define CYPHER_BLOCK_LENGTH 8

typedef struct _CYPHER_BLOCK {
  CHAR data[CYPHER_BLOCK_LENGTH];
}CYPHER_BLOCK;

typedef struct _LM_OWF_PASSWORD {
  CYPHER_BLOCK data[2];
} LM_OWF_PASSWORD;

typedef LM_OWF_PASSWORD *PLM_OWF_PASSWORD;
typedef LM_OWF_PASSWORD NT_OWF_PASSWORD;
typedef NT_OWF_PASSWORD *PNT_OWF_PASSWORD;

typedef struct _SAMPR_ENCRYPTED_USER_PASSWORD {
  UCHAR Buffer[(256 *2) + 4 ];
} SAMPR_ENCRYPTED_USER_PASSWORD,*PSAMPR_ENCRYPTED_USER_PASSWORD;

typedef struct _ENCRYPTED_LM_OWF_PASSWORD {
  CYPHER_BLOCK data[2];
};

typedef ENCRYPTED_LM_OWF_PASSWORD ENCRYPTED_NT_OWF_PASSWORD;
#endif

extern WINADVAPI DWORD WINAPI MSChapSrvChangePassword(LPWSTR ServerName,LPWSTR UserName,BOOLEAN LmOldPresent,PLM_OWF_PASSWORD LmOldOwfPassword,PLM_OWF_PASSWORD LmNewOwfPassword,PNT_OWF_PASSWORD NtOldOwfPassword,PNT_OWF_PASSWORD NtNewOwfPassword);
extern WINADVAPI DWORD WINAPI MSChapSrvChangePassword2(LPWSTR ServerName,LPWSTR UserName,PSAMPR_ENCRYPTED_USER_PASSWORD NewPasswordEncryptedWithOldNt,PENCRYPTED_NT_OWF_PASSWORD OldNtOwfPasswordEncryptedWithNewNt,BOOLEAN LmPresent,PSAMPR_ENCRYPTED_USER_PASSWORD NewPasswordEncryptedWithOldLm,PENCRYPTED_LM_OWF_PASSWORD OldLmOwfPasswordEncryptedWithNewLmOrNt);
#endif
