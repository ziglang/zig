usingnamespace @import("bits.zig");

pub extern "ole32" stdcallcc fn CoTaskMemFree(pv: LPVOID) void;
pub extern "ole32" stdcallcc fn CoUninitialize() void;
pub extern "ole32" stdcallcc fn CoGetCurrentProcess() DWORD;
pub extern "ole32" stdcallcc fn CoInitializeEx(pvReserved: LPVOID, dwCoInit: DWORD) HRESULT;
