/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __QOSPOL_H_
#define __QOSPOL_H_

#define PE_TYPE_APPID 3

#define PE_ATTRIB_TYPE_POLICY_LOCATOR 1
#define PE_ATTRIB_TYPE_CREDENTIAL 2

#define POLICY_LOCATOR_SUB_TYPE_ASCII_DN 1
#define POLICY_LOCATOR_SUB_TYPE_UNICODE_DN 2
#define POLICY_LOCATOR_SUB_TYPE_ASCII_DN_ENC 3
#define POLICY_LOCATOR_SUB_TYPE_UNICODE_DN_ENC 4

#define CREDENTIAL_SUB_TYPE_ASCII_ID 1
#define CREDENTIAL_SUB_TYPE_UNICODE_ID 2
#define CREDENTIAL_SUB_TYPE_KERBEROS_TKT 3
#define CREDENTIAL_SUB_TYPE_X509_V3_CERT 4
#define CREDENTIAL_SUB_TYPE_PGP_CERT 5

typedef struct _IDPE_ATTR {
  USHORT PeAttribLength;
  UCHAR PeAttribType;
  UCHAR PeAttribSubType;
  UCHAR PeAttribValue[4];
} IDPE_ATTR,*LPIDPE_ATTR;

#define IDPE_ATTR_HDR_LEN (sizeof(USHORT)+sizeof(UCHAR)+sizeof(UCHAR))
#define RSVP_BYTE_MULTIPLE(x) (((x+3) / 4)*4)

#endif
