const std = @import("../../std.zig");
const windows = std.os.windows;
const BOOL = windows.BOOL;
const DWORD = windows.DWORD;
const BYTE = windows.BYTE;
const LPCWSTR = windows.LPCWSTR;
const WINAPI = windows.WINAPI;
const GetLastError = windows.kernel32.GetLastError;

pub const CERT_INFO = *opaque {};
pub const HCERTSTORE = *opaque {};
pub const CERT_CONTEXT = extern struct {
    dwCertEncodingType: DWORD,
    pbCertEncoded: [*]BYTE,
    cbCertEncoded: DWORD,
    pCertInfo: CERT_INFO,
    hCertStore: HCERTSTORE,
};

pub extern "crypt32" fn CertOpenSystemStoreW(
    _: ?*const anyopaque,
    szSubsystemProtocol: LPCWSTR,
) callconv(WINAPI) ?HCERTSTORE;
pub fn certOpenSystemStoreW(
    hProv: ?*const anyopaque,
    szSubsystemProtocol: LPCWSTR,
) !HCERTSTORE {
    const value = CertOpenSystemStoreW(hProv, szSubsystemProtocol);
    return if (value) |store|
        store
    else switch (GetLastError()) {
        .FILE_NOT_FOUND => error.FileNotFound,
        else => |err| windows.unexpectedError(err),
    };
}

pub extern "crypt32" fn CertCloseStore(
    hCertStore: HCERTSTORE,
    dwFlags: DWORD,
) callconv(WINAPI) BOOL;
pub fn certCloseStore(
    hCertStore: HCERTSTORE,
    dwFlags: DWORD,
) !void {
    const value = CertCloseStore(hCertStore, dwFlags);
    if (value == 0) {
        return windows.unexpectedError(GetLastError());
    }
}

pub extern "crypt32" fn CertEnumCertificatesInStore(
    hCertStore: HCERTSTORE,
    pPrevCertContext: ?*CERT_CONTEXT,
) callconv(WINAPI) ?*CERT_CONTEXT;
