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
    lpReserved: ?*DWORD,
    lpType: ?*DWORD,
    lpData: ?*BYTE,
    lpcbData: ?*DWORD,
) callconv(WINAPI) LSTATUS;

pub extern "advapi32" fn RegCloseKey(hKey: HKEY) callconv(WINAPI) LSTATUS;

// RtlGenRandom is known as SystemFunction036 under advapi32
// http://msdn.microsoft.com/en-us/library/windows/desktop/aa387694.aspx */
pub extern "advapi32" fn SystemFunction036(output: [*]u8, length: ULONG) callconv(WINAPI) BOOL;
pub const RtlGenRandom = SystemFunction036;

pub const RRF = struct {
    pub const RT_ANY: DWORD = 0x0000ffff;

    pub const RT_DWORD: DWORD = 0x00000018;
    pub const RT_QWORD: DWORD = 0x00000048;

    pub const RT_REG_BINARY: DWORD = 0x00000008;
    pub const RT_REG_DWORD: DWORD = 0x00000010;
    pub const RT_REG_EXPAND_SZ: DWORD = 0x00000004;
    pub const RT_REG_MULTI_SZ: DWORD = 0x00000020;
    pub const RT_REG_NONE: DWORD = 0x00000001;
    pub const RT_REG_QWORD: DWORD = 0x00000040;
    pub const RT_REG_SZ: DWORD = 0x00000002;

    pub const NOEXPAND: DWORD = 0x10000000;
    pub const ZEROONFAILURE: DWORD = 0x20000000;
    pub const SUBKEY_WOW6464KEY: DWORD = 0x00010000;
    pub const SUBKEY_WOW6432KEY: DWORD = 0x00020000;
};

pub extern "advapi32" fn RegGetValueW(
    hkey: HKEY,
    lpSubKey: LPCWSTR,
    lpValue: LPCWSTR,
    dwFlags: DWORD,
    pdwType: ?*DWORD,
    pvData: ?*anyopaque,
    pcbData: ?*DWORD,
) callconv(WINAPI) LSTATUS;

pub extern "advapi32" fn RegLoadAppKeyW(
    lpFile: LPCWSTR,
    phkResult: *HKEY,
    samDesired: REGSAM,
    dwOptions: DWORD,
    reserved: DWORD,
) callconv(WINAPI) LSTATUS;
