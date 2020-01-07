usingnamespace @import("bits.zig");

pub extern "shell32" fn SHGetKnownFolderPath(rfid: *const KNOWNFOLDERID, dwFlags: DWORD, hToken: ?HANDLE, ppszPath: *[*:0]WCHAR) callconv(.Stdcall) HRESULT;
