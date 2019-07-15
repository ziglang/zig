/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef __SECEXT_H__
#define __SECEXT_H__

#include <winapifamily.h>
#include <_mingw_unicode.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include "sspi.h"

#ifdef __cplusplus
extern "C" {
#endif

  typedef enum {
    NameUnknown = 0,
    NameFullyQualifiedDN = 1,
    NameSamCompatible = 2,
    NameDisplay = 3,
    NameUniqueId = 6,
    NameCanonical = 7,
    NameUserPrincipal = 8,
    NameCanonicalEx = 9,
    NameServicePrincipal = 10,
    NameDnsDomain = 12,
    NameGivenName = 13,
    NameSurname = 14
  } EXTENDED_NAME_FORMAT,*PEXTENDED_NAME_FORMAT;

#define GetUserNameEx __MINGW_NAME_AW(GetUserNameEx)
#define GetComputerObjectName __MINGW_NAME_AW(GetComputerObjectName)
#define TranslateName __MINGW_NAME_AW(TranslateName)

  BOOLEAN SEC_ENTRY GetUserNameExA (EXTENDED_NAME_FORMAT NameFormat, LPSTR lpNameBuffer, PULONG nSize);
  BOOLEAN SEC_ENTRY GetUserNameExW (EXTENDED_NAME_FORMAT NameFormat, LPWSTR lpNameBuffer, PULONG nSize);
  BOOLEAN SEC_ENTRY GetComputerObjectNameA (EXTENDED_NAME_FORMAT NameFormat, LPSTR lpNameBuffer, PULONG nSize);
  BOOLEAN SEC_ENTRY GetComputerObjectNameW (EXTENDED_NAME_FORMAT NameFormat, LPWSTR lpNameBuffer, PULONG nSize);
  BOOLEAN SEC_ENTRY TranslateNameA (LPCSTR lpAccountName, EXTENDED_NAME_FORMAT AccountNameFormat, EXTENDED_NAME_FORMAT DesiredNameFormat, LPSTR lpTranslatedName, PULONG nSize);
  BOOLEAN SEC_ENTRY TranslateNameW (LPCWSTR lpAccountName, EXTENDED_NAME_FORMAT AccountNameFormat, EXTENDED_NAME_FORMAT DesiredNameFormat, LPWSTR lpTranslatedName, PULONG nSize);

#ifdef __cplusplus
}
#endif

#endif

#endif
