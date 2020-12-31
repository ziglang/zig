// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");

pub extern "shell32" fn SHGetKnownFolderPath(rfid: *const KNOWNFOLDERID, dwFlags: DWORD, hToken: ?HANDLE, ppszPath: *[*:0]WCHAR) callconv(WINAPI) HRESULT;
