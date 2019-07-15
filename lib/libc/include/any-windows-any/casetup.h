/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_CASETUP
#define _INC_CASETUP

#ifdef __cplusplus
extern "C" {
#endif

#if (_WIN32_WINNT >= 0x0600)

typedef enum _CASetupProperty {
  ENUM_SETUPPROP_INVALID              = -1,
  ENUM_SETUPPROP_CATYPE               = 0,
  ENUM_SETUPPROP_CAKEYINFORMATION     = 1,
  ENUM_SETUPPROP_INTERACTIVE          = 2,
  ENUM_SETUPPROP_CANAME               = 3,
  ENUM_SETUPPROP_CADSSUFFIX           = 4,
  ENUM_SETUPPROP_VALIDITYPERIOD       = 5,
  ENUM_SETUPPROP_VALIDITYPERIODUNIT   = 6,
  ENUM_SETUPPROP_EXPIRATIONDATE       = 7,
  ENUM_SETUPPROP_PRESERVEDATABASE     = 8,
  ENUM_SETUPPROP_DATABASEDIRECTORY    = 9,
  ENUM_SETUPPROP_LOGDIRECTORY         = 10,
  ENUM_SETUPPROP_SHAREDFOLDER         = 11,
  ENUM_SETUPPROP_PARENTCAMACHINE      = 12,
  ENUM_SETUPPROP_PARENTCANAME         = 13,
  ENUM_SETUPPROP_REQUESTFILE          = 14,
  ENUM_SETUPPROP_WEBCAMACHINE         = 15,
  ENUM_SETUPPROP_WEBCANAME            = 16
} CASetupProperty;

typedef enum _MSCEPSetupProperty {
  ENUM_CEPSETUPPROP_USELOCALSYSTEM           = 0,
  ENUM_CEPSETUPPROP_USECHALLENGE             = 1,
  ENUM_CEPSETUPPROP_RANAME_CN                = 2,
  ENUM_CEPSETUPPROP_RANAME_EMAIL             = 3,
  ENUM_CEPSETUPPROP_RANAME_COMPANY           = 4,
  ENUM_CEPSETUPPROP_RANAME_DEPT              = 5,
  ENUM_CEPSETUPPROP_RANAME_CITY              = 6,
  ENUM_CEPSETUPPROP_RANAME_STATE             = 7,
  ENUM_CEPSETUPPROP_RANAME_COUNTRY           = 8,
  ENUM_CEPSETUPPROP_SIGNINGKEYINFORMATION    = 9,
  ENUM_CEPSETUPPROP_EXCHANGEKEYINFORMATION   = 10,
  ENUM_CEPSETUPPROP_CAINFORMATION            = 11,
  ENUM_CEPSETUPPROP_MSCEPURL                 = 12,
  ENUM_CEPSETUPPROP_CHALLENGEURL             = 13
} MSCEPSetupProperty;

#endif /*(_WIN32_WINNT >= 0x0600)*/

#ifdef __cplusplus
}
#endif

#endif /*_INC_CASETUP*/
