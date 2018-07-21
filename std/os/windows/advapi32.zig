use @import("index.zig");

pub const PROV_RSA_FULL = 1;

pub const REGSAM = ACCESS_MASK;
pub const ACCESS_MASK = DWORD;
pub const PHKEY = &HKEY;
pub const HKEY = &HKEY__;
pub const HKEY__ = extern struct {
    unused: c_int,
};
pub const LSTATUS = LONG;

pub extern "advapi32" stdcallcc fn CryptAcquireContextA(
    phProv: *HCRYPTPROV,
    pszContainer: ?LPCSTR,
    pszProvider: ?LPCSTR,
    dwProvType: DWORD,
    dwFlags: DWORD,
) BOOL;

pub extern "advapi32" stdcallcc fn CryptReleaseContext(hProv: HCRYPTPROV, dwFlags: DWORD) BOOL;

pub extern "advapi32" stdcallcc fn CryptGenRandom(hProv: HCRYPTPROV, dwLen: DWORD, pbBuffer: [*]BYTE) BOOL;

pub extern "advapi32" stdcallcc fn RegOpenKeyExW(hKey: HKEY, lpSubKey: LPCWSTR, ulOptions: DWORD, samDesired: REGSAM,
    phkResult: &HKEY,) LSTATUS;

pub extern "advapi32" stdcallcc fn RegQueryValueExW(hKey: HKEY, lpValueName: LPCWSTR, lpReserved: LPDWORD,
    lpType: LPDWORD, lpData: LPBYTE, lpcbData: LPDWORD,) LSTATUS;
