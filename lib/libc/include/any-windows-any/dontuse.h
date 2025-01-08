/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _DONTUSE_H_INCLUDED_
#define _DONTUSE_H_INCLUDED_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#undef strcpy
#define strcpy strcpy_instead_use_StringCbCopyA_or_StringCchCopyA

#undef wcscpy
#define wcscpy wcscpy_instead_use_StringCbCopyW_or_StringCchCopyW

#undef strcat
#define strcat strcat_instead_use_StringCbCatA_or_StringCchCatA

#undef wcscat
#define wcscat wcscat_instead_use_StringCbCatW_or_StringCchCatW

#undef sprintf
#define sprintf sprintf_instead_use_StringCbPrintfA_or_StringCchPrintfA

#undef swprintf
#define swprintf swprintf_instead_use_StringCbPrintfW_or_StringCchPrintfW

#undef vsprintf
#define vsprintf vsprintf_instead_use_StringCbVPrintfA_or_StringCchVPrintfA

#undef vswprintf
#define vswprintf vswprintf_instead_use_StringCbVPrintfW_or_StringCchVPrintfW

#undef _snprintf
#define _snprintf _snprintf_instead_use_StringCbPrintfA_or_StringCchPrintfA

#undef _snwprintf
#define _snwprintf _snwprintf_instead_use_StringCbPrintfW_or_StringCchPrintfW

#undef _vsnprintf
#define _vsnprintf _vsnprintf_instead_use_StringCbVPrintfA_or_StringCchVPrintfA

#undef _vsnwprintf
#define _vsnwprintf _vsnwprintf_instead_use_StringCbVPrintfW_or_StringCchVPrintfW

#undef strcpyA
#define strcpyA strcpyA_instead_use_StringCbCopyA_or_StringCchCopyA

#undef strcpyW
#define strcpyW strcpyW_instead_use_StringCbCopyW_or_StringCchCopyW

#undef lstrcpy
#define lstrcpy lstrcpy_instead_use_StringCbCopy_or_StringCchCopy

#undef lstrcpyA
#define lstrcpyA lstrcpyA_instead_use_StringCbCopyA_or_StringCchCopyA

#undef lstrcpyW
#define lstrcpyW lstrcpyW_instead_use_StringCbCopyW_or_StringCchCopyW

#undef StrCpy
#define StrCpy StrCpy_instead_use_StringCbCopy_or_StringCchCopy

#undef StrCpyA
#define StrCpyA StrCpyA_instead_use_StringCbCopyA_or_StringCchCopyA

#undef StrCpyW
#define StrCpyW StrCpyW_instead_use_StringCbCopyW_or_StringCchCopyW

#undef _tcscpy
#define _tcscpy _tcscpy_instead_use_StringCbCopy_or_StringCchCopy

#undef _ftcscpy
#define _ftcscpy _ftcscpy_instead_use_StringCbCopy_or_StringCchCopy

#undef lstrcat
#define lstrcat lstrcat_instead_use_StringCbCat_or_StringCchCat

#undef lstrcatA
#define lstrcatA lstrcatA_instead_use_StringCbCatA_or_StringCchCatA

#undef lstrcatW
#define lstrcatW lstrcatW_instead_use_StringCbCatW_or_StringCchCatW

#undef StrCat
#define StrCat StrCat_instead_use_StringCbCat_or_StringCchCat

#undef StrCatA
#define StrCatA StrCatA_instead_use_StringCbCatA_or_StringCchCatA

#undef StrCatW
#define StrCatW StrCatW_instead_use_StringCbCatW_or_StringCchCatW

#undef StrNCat
#define StrNCat StrNCat_instead_use_StringCbCatN_or_StringCchCatN

#undef StrNCatA
#define StrNCatA StrNCatA_instead_use_StringCbCatNA_or_StringCchCatNA

#undef StrNCatW
#define StrNCatW StrNCatW_instead_use_StringCbCatNW_or_StringCchCatNW

#undef StrCatN
#define StrCatN StrCatN_instead_use_StringCbCatN_or_StringCchCatN

#undef StrCatNA
#define StrCatNA StrCatNA_instead_use_StringCbCatNA_or_StringCchCatNA

#undef StrCatNW
#define StrCatNW StrCatNW_instead_use_StringCbCatNW_or_StringCchCatNW

#undef _tcscat
#define _tcscat _tcscat_instead_use_StringCbCat_or_StringCchCat

#undef _ftcscat
#define _ftcscat _ftcscat_instead_use_StringCbCat_or_StringCchCat

#undef wsprintf
#define wsprintf wsprintf_instead_use_StringCbPrintf_or_StringCchPrintf

#undef wsprintfA
#define wsprintfA wsprintfA_instead_use_StringCbPrintfA_or_StringCchPrintfA

#undef wsprintfW
#define wsprintfW wsprintfW_instead_use_StringCbPrintfW_or_StringCchPrintfW

#undef wvsprintf
#define wvsprintf wvsprintf_instead_use_StringCbVPrintf_or_StringCchVPrintf

#undef wvsprintfA
#define wvsprintfA wvsprintfA_instead_use_StringCbVPrintfA_or_StringCchVPrintfA

#undef wvsprintfW
#define wvsprintfW wvsprintfW_instead_use_StringCbVPrintfW_or_StringCchVPrintfW

#undef _vstprintf
#define _vstprintf _vstprintf_instead_use_StringCbVPrintf_or_StringCchVPrintf

#undef _vsntprintf
#define _vsntprintf _vsntprintf_instead_use_StringCbVPrintf_or_StringCchVPrintf

#undef _stprintf
#define _stprintf _stprintf_instead_use_StringCbPrintf_or_StringCchPrintf

#undef _sntprintf
#define _sntprintf _sntprintf_instead_use_StringCbPrintf_or_StringCchPrintf

#undef _getts
#define _getts _getts_instead_use_StringCbGets_or_StringCchGets

#undef gets
#define gets _gets_instead_use_StringCbGetsA_or_StringCchGetsA

#undef _getws
#define _getws _getws_instead_use_StringCbGetsW_or_StringCchGetsW

#endif  /* WINAPI_PARTITION_DESKTOP */
#endif
