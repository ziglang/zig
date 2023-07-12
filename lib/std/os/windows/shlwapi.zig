const std = @import("../../std.zig");
const windows = std.os.windows;

const DWORD = windows.DWORD;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const LPCSTR = windows.LPCSTR;
const LPSTR = windows.LPSTR;
const LPWSTR = windows.LPWSTR;
const LPCWSTR = windows.LPCWSTR;

pub extern "shlwapi" fn PathCreateFromUrlW(pszUrl: LPCWSTR, pszPath: LPWSTR, pcchPath: *DWORD, dwFlags: DWORD) callconv(WINAPI) HRESULT;
pub extern "shlwapi" fn PathCreateFromUrlA(pszUrl: LPCSTR, pszPath: LPSTR, pcchPath: *DWORD, dwFlags: DWORD) callconv(WINAPI) HRESULT;
