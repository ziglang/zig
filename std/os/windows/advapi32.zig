usingnamespace @import("bits.zig");

pub extern "advapi32" stdcallcc fn RegOpenKeyExW(
    hKey: HKEY,
    lpSubKey: LPCWSTR,
    ulOptions: DWORD,
    samDesired: REGSAM,
    phkResult: *HKEY,
) LSTATUS;

pub extern "advapi32" stdcallcc fn RegQueryValueExW(
    hKey: HKEY,
    lpValueName: LPCWSTR,
    lpReserved: LPDWORD,
    lpType: LPDWORD,
    lpData: LPBYTE,
    lpcbData: LPDWORD,
) LSTATUS;

// RtlGenRandom is known as SystemFunction036 under advapi32
// http://msdn.microsoft.com/en-us/library/windows/desktop/aa387694.aspx */
pub extern "advapi32" stdcallcc fn SystemFunction036(output: [*]u8, length: ULONG) BOOL;
pub const RtlGenRandom = SystemFunction036;
