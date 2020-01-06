usingnamespace @import("bits.zig");

pub extern "shell32" fn SHGetKnownFolderPath(rfid: *const KNOWNFOLDERID, dwFlags: DWORD, hToken: ?HANDLE, ppszPath: *[*]WCHAR) callconv(.Stdcall) HRESULT;
