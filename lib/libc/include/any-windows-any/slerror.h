/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_SLERROR
#define _INC_SLERROR
#if (_WIN32_WINNT >= 0x0600)

#define SL_E_LICENSE_FILE_NOT_INSTALLED 0xC004F011
#define SL_E_RIGHT_NOT_GRANTED 0xC004F013
#define SL_E_NOT_SUPPORTED 0xC004F016
#define SL_E_DATATYPE_MISMATCHED 0xC004F01E
#define SL_E_LUA_ACCESSDENIED 0xC004F025
#define SL_E_DEPENDENT_PROPERTY_NOT_SET 0xC004F066

#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_SLERROR*/
