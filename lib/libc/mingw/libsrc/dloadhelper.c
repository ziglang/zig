/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <delayloadhandler.h>

/* XXX NTSTATUS is supposed to be a LONG, but there are a bunch of STATUS_
 * constants in winnt.h defined as ((DWORD)0x...), including
 * STATUS_DLL_NOT_FOUND which we need, so using DWORD here to silence a warning
 */
typedef DWORD NTSTATUS;

extern IMAGE_DOS_HEADER __ImageBase;

/* this typedef is missing from the Windows SDK header, but is present in
 * Wine's version. */
typedef FARPROC (WINAPI *PDELAYLOAD_FAILURE_SYSTEM_ROUTINE)(LPCSTR pszDllName, LPCSTR pszProcName);

/* these functions aren't in any Windows SDK header, but are documented at
 * https://docs.microsoft.com/en-us/windows/win32/devnotes/delay-loaded-dlls */
WINBASEAPI FARPROC WINAPI DelayLoadFailureHook(LPCSTR pszDllName, LPCSTR pszProcName);

WINBASEAPI PVOID WINAPI ResolveDelayLoadedAPI(
		PVOID ParentModuleBase,
		PCIMAGE_DELAYLOAD_DESCRIPTOR DelayloadDescriptor,
		PDELAYLOAD_FAILURE_DLL_CALLBACK FailureDllHook,
		PDELAYLOAD_FAILURE_SYSTEM_ROUTINE FailureSystemHook,
		PIMAGE_THUNK_DATA ThunkAddress,
		ULONG Flags);

WINBASEAPI NTSTATUS WINAPI ResolveDelayLoadsFromDll(
		PVOID ParentBase,
		LPCSTR TargetDllName,
		ULONG Flags);

/* These functions are defined here, part of the delayimp API */
PVOID WINAPI __delayLoadHelper2(
		PCIMAGE_DELAYLOAD_DESCRIPTOR DelayloadDescriptor,
		PIMAGE_THUNK_DATA ThunkAddress);

HRESULT WINAPI __HrLoadAllImportsForDll(LPCSTR szDll);

PVOID WINAPI __delayLoadHelper2(
		PCIMAGE_DELAYLOAD_DESCRIPTOR DelayloadDescriptor,
		PIMAGE_THUNK_DATA ThunkAddress)
{
	return ResolveDelayLoadedAPI(&__ImageBase, DelayloadDescriptor, __pfnDliFailureHook2, DelayLoadFailureHook, ThunkAddress, 0);
}

HRESULT WINAPI __HrLoadAllImportsForDll(LPCSTR szDll)
{
	NTSTATUS status = ResolveDelayLoadsFromDll(&__ImageBase, szDll, 0);
	if (status == STATUS_DLL_NOT_FOUND)
		return HRESULT_FROM_WIN32(ERROR_MOD_NOT_FOUND);
	else
		return S_OK;
}
