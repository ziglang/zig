/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>
#include <_mingw_unicode.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifndef NTLMSP_NAME_A
#define NTLMSP_NAME_A "NTLM"
#define NTLMSP_NAME L"NTLM"
#endif

#ifndef MICROSOFT_KERBEROS_NAME_A
#define MICROSOFT_KERBEROS_NAME_A "Kerberos"
#define MICROSOFT_KERBEROS_NAME_W L"Kerberos"
#ifdef WIN32_CHICAGO
#define MICROSOFT_KERBEROS_NAME MICROSOFT_KERBEROS_NAME_A
#else
#define MICROSOFT_KERBEROS_NAME MICROSOFT_KERBEROS_NAME_W
#endif
#endif

#ifndef NEGOSSP_NAME
#define NEGOSSP_NAME_W L"Negotiate"
#define NEGOSSP_NAME_A "Negotiate"

#define NEGOSSP_NAME __MINGW_NAME_UAW(NEGOSSP_NAME)
#endif

#include <sspi.h>

#if defined (SECURITY_WIN32) || defined (SECURITY_KERNEL)
#include <secext.h>
#endif

#if ISSP_LEVEL == 16
#include <issper16.h>
#endif
#endif
