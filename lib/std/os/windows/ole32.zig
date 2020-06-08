usingnamespace @import("bits.zig");

pub extern "ole32" fn CoTaskMemFree(pv: LPVOID) callconv(.Stdcall) void;
pub extern "ole32" fn CoUninitialize() callconv(.Stdcall) void;
pub extern "ole32" fn CoGetCurrentProcess() callconv(.Stdcall) DWORD;
pub extern "ole32" fn CoInitializeEx(pvReserved: LPVOID, dwCoInit: DWORD) callconv(.Stdcall) HRESULT;
