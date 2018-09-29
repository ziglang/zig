use @import("index.zig");

pub extern "ole32.dll" stdcallcc fn CoTaskMemFree(pv: LPVOID) void;
pub extern "ole32.dll" stdcallcc fn CoUninitialize() void;
pub extern "ole32.dll" stdcallcc fn CoGetCurrentProcess() DWORD;
pub extern "ole32.dll" stdcallcc fn CoInitializeEx(pvReserved: LPVOID, dwCoInit: DWORD) HRESULT;

pub const COINIT_APARTMENTTHREADED = COINIT.COINIT_APARTMENTTHREADED;
pub const COINIT_MULTITHREADED = COINIT.COINIT_MULTITHREADED;
pub const COINIT_DISABLE_OLE1DDE = COINIT.COINIT_DISABLE_OLE1DDE;
pub const COINIT_SPEED_OVER_MEMORY = COINIT.COINIT_SPEED_OVER_MEMORY;
pub const COINIT = extern enum {
    COINIT_APARTMENTTHREADED = 2,
    COINIT_MULTITHREADED = 0,
    COINIT_DISABLE_OLE1DDE = 4,
    COINIT_SPEED_OVER_MEMORY = 8,
};
