const std = @import("../../std.zig");
const windows = std.os.windows;
const BOOL = windows.BOOL;
const DWORD = windows.DWORD;
const BYTE = windows.BYTE;
const LPCWSTR = windows.LPCWSTR;

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
) callconv(.winapi) ?HCERTSTORE;

pub extern "crypt32" fn CertCloseStore(
    hCertStore: HCERTSTORE,
    dwFlags: DWORD,
) callconv(.winapi) BOOL;

pub extern "crypt32" fn CertEnumCertificatesInStore(
    hCertStore: HCERTSTORE,
    pPrevCertContext: ?*CERT_CONTEXT,
) callconv(.winapi) ?*CERT_CONTEXT;
