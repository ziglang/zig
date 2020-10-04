// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");

pub extern "ole32" fn CoTaskMemFree(pv: LPVOID) callconv(.Stdcall) void;
pub extern "ole32" fn CoUninitialize() callconv(.Stdcall) void;
pub extern "ole32" fn CoGetCurrentProcess() callconv(.Stdcall) DWORD;
pub extern "ole32" fn CoInitializeEx(pvReserved: LPVOID, dwCoInit: DWORD) callconv(.Stdcall) HRESULT;
