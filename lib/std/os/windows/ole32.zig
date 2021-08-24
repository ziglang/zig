usingnamespace @import("bits.zig");

pub extern "ole32" fn CoTaskMemFree(pv: LPVOID) callconv(WINAPI) void;
pub extern "ole32" fn CoUninitialize() callconv(WINAPI) void;
pub extern "ole32" fn CoGetCurrentProcess() callconv(WINAPI) DWORD;
pub extern "ole32" fn CoInitializeEx(pvReserved: ?LPVOID, dwCoInit: DWORD) callconv(WINAPI) HRESULT;
