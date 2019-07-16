/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __WINSTRING_H__
#define __WINSTRING_H__

#include <windows.h>
#include <sdkddkver.h>
#include <rpc.h>
#include <hstring.h>

#ifdef __cplusplus
extern "C" {
#endif

void __RPC_USER HSTRING_UserFree(unsigned long *pFlags, HSTRING *ppidl);

unsigned char* __RPC_USER HSTRING_UserMarshal(unsigned long *pFlags, unsigned char *pBuffer, HSTRING *ppidl);

unsigned long __RPC_USER HSTRING_UserSize(unsigned long *pFlags, unsigned long StartingSize, HSTRING *ppidl);

unsigned char* __RPC_USER HSTRING_UserUnmarshal(unsigned long *pFlags, unsigned char *pBuffer, HSTRING *ppidl);

#ifdef _WIN64
void __RPC_USER HSTRING_UserFree64(unsigned long *pFlags, HSTRING *ppidl);

unsigned char* __RPC_USER HSTRING_UserMarshal64(unsigned long *pFlags, unsigned char *pBuffer, HSTRING *ppidl);

unsigned long __RPC_USER HSTRING_UserSize64(unsigned long *pFlags, unsigned long StartingSize, HSTRING *ppidl);

unsigned char* __RPC_USER HSTRING_UserUnmarshal64(unsigned long *pFlags, unsigned char *pBuffer, HSTRING *ppidl);
#endif

HRESULT WINAPI WindowsCompareStringOrdinal(HSTRING string1, HSTRING string2, INT32 *result);

HRESULT WINAPI WindowsConcatString(HSTRING string1, HSTRING string2, HSTRING *newString);

HRESULT WINAPI WindowsCreateString(LPCWSTR sourceString, UINT32 length, HSTRING *string);

HRESULT WINAPI WindowsCreateStringReference(PCWSTR sourceString, UINT32 length, HSTRING_HEADER *hstringHeader, HSTRING *string);

HRESULT WINAPI WindowsDeleteString(HSTRING string);

HRESULT WindowsDeleteStringBuffer(HSTRING_BUFFER bufferHandle);

HRESULT WINAPI WindowsDuplicateString(HSTRING string, HSTRING *newString);

UINT32 WINAPI WindowsGetStringLen(HSTRING string);

PCWSTR WINAPI WindowsGetStringRawBuffer(HSTRING string, UINT32 *length);

typedef HRESULT (WINAPI *PINSPECT_HSTRING_CALLBACK)(void *context, UINT_PTR readAddress, UINT32 length, BYTE *buffer);

HRESULT WINAPI WindowsInspectString(UINT_PTR targetHString, USHORT machine, PINSPECT_HSTRING_CALLBACK callback, void *context, UINT32 *length, UINT_PTR *targetStringAddress);

BOOL WINAPI WindowsIsStringEmpty(HSTRING string);

HRESULT WindowsPreallocateStringBuffer(UINT32 length, WCHAR **mutableBuffer, HSTRING_BUFFER *bufferHandle);

HRESULT WindowsPromoteStringBuffer(HSTRING_BUFFER bufferHandle, HSTRING *string);

HRESULT WINAPI WindowsReplaceString(HSTRING string, HSTRING stringReplaced, HSTRING stringReplaceWith, HSTRING *newString);

HRESULT WINAPI WindowsStringHasEmbeddedNull(HSTRING string, BOOL *hasEmbedNull);

HRESULT WINAPI WindowsSubstring(HSTRING string, UINT32 startIndex, HSTRING *newString);

HRESULT WINAPI WindowsSubstringWithSpecifiedLength(HSTRING string, UINT32 startIndex, UINT32 length, HSTRING *newString);

HRESULT WINAPI WindowsTrimStringEnd(HSTRING string, HSTRING trimString, HSTRING *newString);

HRESULT WINAPI WindowsTrimStringStart(HSTRING string, HSTRING trimString, HSTRING *newString);

#ifdef __cplusplus
}
#endif

#endif
