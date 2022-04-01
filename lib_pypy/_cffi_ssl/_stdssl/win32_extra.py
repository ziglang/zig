from _pypy_openssl import lib, ffi


def enum_certificates(store_name):
    """Retrieve certificates from Windows' cert store.

store_name may be one of 'CA', 'ROOT' or 'MY'.  The system may provide
more cert storages, too.  The function returns a list of (bytes,
encoding_type, trust) tuples.  The encoding_type flag can be interpreted
with X509_ASN_ENCODING or PKCS_7_ASN_ENCODING. The trust setting is either
a set of OIDs or the boolean True.
    """
    hStore = lib.CertOpenStore(lib.CERT_STORE_PROV_SYSTEM_A, 0, ffi.NULL,
                               lib.CERT_STORE_READONLY_FLAG | lib.CERT_SYSTEM_STORE_LOCAL_MACHINE,
                               bytes(store_name, "ascii"))
    if hStore == ffi.NULL:
        raise WindowsError(*ffi.getwinerror())
    
    result = []
    pCertCtx = ffi.NULL
    try:
        while True:
            pCertCtx = lib.CertEnumCertificatesInStore(hStore, pCertCtx)
            if pCertCtx == ffi.NULL:
                break
            cert = ffi.buffer(pCertCtx.pbCertEncoded, pCertCtx.cbCertEncoded)[:]
            enc = certEncodingType(pCertCtx.dwCertEncodingType)
            keyusage = parseKeyUsage(pCertCtx, lib.CERT_FIND_PROP_ONLY_ENHKEY_USAGE_FLAG)
            if keyusage is True:
                keyusage = parseKeyUsage(pCertCtx, lib.CERT_FIND_EXT_ONLY_ENHKEY_USAGE_FLAG)
            result.append((cert, enc, keyusage))
    finally:
        if pCertCtx != ffi.NULL:
            lib.CertFreeCertificateContext(pCertCtx)
        if not lib.CertCloseStore(hStore, 0):
            # This error case might shadow another exception.
            raise WindowsError(*ffi.getwinerror())
    return result


def enum_crls(store_name):
    """Retrieve CRLs from Windows' cert store.

store_name may be one of 'CA', 'ROOT' or 'MY'.  The system may provide
more cert storages, too.  The function returns a list of (bytes,
encoding_type) tuples.  The encoding_type flag can be interpreted with
X509_ASN_ENCODING or PKCS_7_ASN_ENCODING."""
    hStore = lib.CertOpenStore(lib.CERT_STORE_PROV_SYSTEM_A, 0, ffi.NULL,
                               lib.CERT_STORE_READONLY_FLAG | lib.CERT_SYSTEM_STORE_LOCAL_MACHINE,
                               bytes(store_name, "ascii"))
    if hStore == ffi.NULL:
        raise WindowsError(*ffi.getwinerror())

    result = []
    pCrlCtx = ffi.NULL
    try:
        while True:
            pCrlCtx = lib.CertEnumCRLsInStore(hStore, pCrlCtx)
            if pCrlCtx == ffi.NULL:
                break
            crl = ffi.buffer(pCrlCtx.pbCrlEncoded, pCrlCtx.cbCrlEncoded)[:]
            enc = certEncodingType(pCrlCtx.dwCertEncodingType)
            result.append((crl, enc))
    finally:
        if pCrlCtx != ffi.NULL:
            lib.CertFreeCRLContext(pCrlCtx)
        if not lib.CertCloseStore(hStore, 0):
            # This error case might shadow another exception.
            raise WindowsError(*ffi.getwinerror())
    return result


def certEncodingType(encodingType):
    if encodingType == lib.X509_ASN_ENCODING:
        return "x509_asn"
    if encodingType == lib.PKCS_7_ASN_ENCODING:
        return "pkcs_7_asn"
    return encodingType

def parseKeyUsage(pCertCtx, flags):
    pSize = ffi.new("DWORD *")
    if not lib.CertGetEnhancedKeyUsage(pCertCtx, flags, ffi.NULL, pSize):
        error_with_message = ffi.getwinerror()
        if error_with_message[0] == lib.CRYPT_E_NOT_FOUND:
            return True
        raise WindowsError(*error_with_message)

    pUsageMem = ffi.new("char[]", pSize[0])
    pUsage = ffi.cast("PCERT_ENHKEY_USAGE", pUsageMem)
    if not lib.CertGetEnhancedKeyUsage(pCertCtx, flags, pUsage, pSize):
        error_with_message = ffi.getwinerror()
        if error_with_message[0] == lib.CRYPT_E_NOT_FOUND:
            return True
        raise WindowsError(*error_with_message)

    retval = set()
    for i in range(pUsage.cUsageIdentifier):
        if pUsage.rgpszUsageIdentifier[i]:
            oid = ffi.string(pUsage.rgpszUsageIdentifier[i]).decode('ascii')
            retval.add(oid)
    return retval
