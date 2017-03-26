pub extern fn CryptAcquireContext(phProv: &HCRYPTPROV, pszContainer: LPCTSTR,
    pszProvider: LPCTSTR, dwProvType: DWORD, dwFlags: DWORD) -> bool;

pub extern fn CryptReleaseContext(hProv: HCRYPTPROV, dwFlags: DWORD) -> bool;

pub extern fn CryptGenRandom(hProv: HCRYPTPROV, dwLen: DWORD, pbBuffer: &BYTE) -> bool;

pub const PROV_RSA_FULL = 1;


pub const BYTE = u8;
pub const DWORD = u32;
// TODO something about unicode WCHAR vs char
pub const TCHAR = u8;
pub const LPCTSTR = ?&const TCHAR;
pub const ULONG_PTR = usize;
pub const HCRYPTPROV = ULONG_PTR;
