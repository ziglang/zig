const std = @import("../../std.zig");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;
const LPVOID = windows.LPVOID;
const DWORD = windows.DWORD;
const HRESULT = windows.HRESULT;

pub extern "ole32" fn CoTaskMemFree(pv: LPVOID) callconv(WINAPI) void;
pub extern "ole32" fn CoUninitialize() callconv(WINAPI) void;
pub extern "ole32" fn CoGetCurrentProcess() callconv(WINAPI) DWORD;
pub extern "ole32" fn CoInitialize(pvReserved: ?LPVOID) callconv(WINAPI) HRESULT;
pub extern "ole32" fn CoInitializeEx(pvReserved: ?LPVOID, dwCoInit: DWORD) callconv(WINAPI) HRESULT;
