use @import("index.zig");

pub extern "shell32" stdcallcc fn SHGetKnownFolderPath(rfid: *const KNOWNFOLDERID, dwFlags: DWORD, hToken: ?HANDLE, ppszPath: *[*]WCHAR) HRESULT;

