const std = @import("../../std.zig");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;
const KNOWNFOLDERID = windows.KNOWNFOLDERID;
const DWORD = windows.DWORD;
const HANDLE = windows.HANDLE;
const WCHAR = windows.WCHAR;
const HRESULT = windows.HRESULT;

pub extern "shell32" fn SHGetKnownFolderPath(
    rfid: *const KNOWNFOLDERID,
    dwFlags: DWORD,
    hToken: ?HANDLE,
    ppszPath: *[*:0]WCHAR,
) callconv(WINAPI) HRESULT;
