const std = @import("../../std.zig");
const windows = std.os.windows;
const BOOL = windows.BOOL;
const DWORD = windows.DWORD;
const HKEY = windows.HKEY;
const BYTE = windows.BYTE;
const LPCWSTR = windows.LPCWSTR;
const LSTATUS = windows.LSTATUS;
const REGSAM = windows.REGSAM;
const ULONG = windows.ULONG;
const WINAPI = windows.WINAPI;

pub extern "advapi32" fn RegOpenKeyExW(
    hKey: HKEY,
    lpSubKey: LPCWSTR,
    ulOptions: DWORD,
    samDesired: REGSAM,
    phkResult: *HKEY,
) callconv(WINAPI) LSTATUS;

pub extern "advapi32" fn RegQueryValueExW(
    hKey: HKEY,
    lpValueName: LPCWSTR,
    lpReserved: *DWORD,
    lpType: *DWORD,
    lpData: *BYTE,
    lpcbData: *DWORD,
) callconv(WINAPI) LSTATUS;

// RtlGenRandom is known as SystemFunction036 under advapi32
// http://msdn.microsoft.com/en-us/library/windows/desktop/aa387694.aspx */
pub extern "advapi32" fn SystemFunction036(output: [*]u8, length: ULONG) callconv(WINAPI) BOOL;
pub const RtlGenRandom = SystemFunction036;
