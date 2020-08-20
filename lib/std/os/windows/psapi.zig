// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");

pub extern "psapi" fn EmptyWorkingSet(hProcess: HANDLE) callconv(.Stdcall) BOOL;
pub extern "psapi" fn EnumDeviceDrivers(lpImageBase: [*]LPVOID, cb: DWORD, lpcbNeeded: LPDWORD) callconv(.Stdcall) BOOL;
pub extern "psapi" fn EnumPageFilesA(pCallBackRoutine: PENUM_PAGE_FILE_CALLBACKA, pContext: LPVOID) callconv(.Stdcall) BOOL;
pub extern "psapi" fn EnumPageFilesW(pCallBackRoutine: PENUM_PAGE_FILE_CALLBACKW, pContext: LPVOID) callconv(.Stdcall) BOOL;
pub extern "psapi" fn EnumProcessModules(hProcess: HANDLE, lphModule: [*]HMODULE, cb: DWORD, lpcbNeeded: LPDWORD) callconv(.Stdcall) BOOL;
pub extern "psapi" fn EnumProcessModulesEx(hProcess: HANDLE, lphModule: [*]HMODULE, cb: DWORD, lpcbNeeded: LPDWORD, dwFilterFlag: DWORD) callconv(.Stdcall) BOOL;
pub extern "psapi" fn EnumProcesses(lpidProcess: [*]DWORD, cb: DWORD, cbNeeded: LPDWORD) callconv(.Stdcall) BOOL;
pub extern "psapi" fn GetDeviceDriverBaseNameA(ImageBase: LPVOID, lpBaseName: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetDeviceDriverBaseNameW(ImageBase: LPVOID, lpBaseName: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetDeviceDriverFileNameA(ImageBase: LPVOID, lpFilename: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetDeviceDriverFileNameW(ImageBase: LPVOID, lpFilename: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetMappedFileNameA(hProcess: HANDLE, lpv: ?LPVOID, lpFilename: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetMappedFileNameW(hProcess: HANDLE, lpv: ?LPVOID, lpFilename: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetModuleBaseNameA(hProcess: HANDLE, hModule: ?HMODULE, lpBaseName: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetModuleBaseNameW(hProcess: HANDLE, hModule: ?HMODULE, lpBaseName: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetModuleFileNameExA(hProcess: HANDLE, hModule: ?HMODULE, lpFilename: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetModuleFileNameExW(hProcess: HANDLE, hModule: ?HMODULE, lpFilename: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetModuleInformation(hProcess: HANDLE, hModule: HMODULE, lpmodinfo: LPMODULEINFO, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "psapi" fn GetPerformanceInfo(pPerformanceInformation: PPERFORMACE_INFORMATION, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "psapi" fn GetProcessImageFileNameA(hProcess: HANDLE, lpImageFileName: LPSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetProcessImageFileNameW(hProcess: HANDLE, lpImageFileName: LPWSTR, nSize: DWORD) callconv(.Stdcall) DWORD;
pub extern "psapi" fn GetProcessMemoryInfo(Process: HANDLE, ppsmemCounters: PPROCESS_MEMORY_COUNTERS, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "psapi" fn GetWsChanges(hProcess: HANDLE, lpWatchInfo: PPSAPI_WS_WATCH_INFORMATION, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "psapi" fn GetWsChangesEx(hProcess: HANDLE, lpWatchInfoEx: PPSAPI_WS_WATCH_INFORMATION_EX, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "psapi" fn InitializeProcessForWsWatch(hProcess: HANDLE) callconv(.Stdcall) BOOL;
pub extern "psapi" fn QueryWorkingSet(hProcess: HANDLE, pv: PVOID, cb: DWORD) callconv(.Stdcall) BOOL;
pub extern "psapi" fn QueryWorkingSetEx(hProcess: HANDLE, pv: PVOID, cb: DWORD) callconv(.Stdcall) BOOL;
