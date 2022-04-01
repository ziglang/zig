import warnings
import base64
import textwrap
from _pypy_openssl import ffi
from _pypy_openssl import lib
from _cffi_ssl._stdssl.utility import _string_from_asn1, _str_with_len, _bytes_with_len
from _cffi_ssl._stdssl.error import ssl_error, pyssl_error

X509_NAME_MAXLEN = 256

def _create_tuple_for_attribute(name, value):
    buf = ffi.new("char[]", X509_NAME_MAXLEN)
    length = lib.OBJ_obj2txt(buf, X509_NAME_MAXLEN, name, 0)
    if length < 0:
        raise ssl_error(None)
    name = _str_with_len(buf, length)

    buf_ptr = ffi.new("unsigned char**")
    length = lib.ASN1_STRING_to_UTF8(buf_ptr, value)
    if length < 0:
        raise ssl_error(None)
    try:
        value = _str_with_len(buf_ptr[0], length)
    finally:
        lib.OPENSSL_free(buf_ptr[0])
    return (name, value)

def _get_aia_uri(certificate, nid):
    info = lib.X509_get_ext_d2i(certificate, lib.NID_info_access, ffi.NULL, ffi.NULL)
    if (info == ffi.NULL):
        return None;
    if lib.sk_ACCESS_DESCRIPTION_num(info) == 0:
        lib.sk_ACCESS_DESCRIPTION_free(info)
        return None

    lst = []
    count = lib.sk_ACCESS_DESCRIPTION_num(info)
    for i in range(count):
        ad = lib.sk_ACCESS_DESCRIPTION_value(info, i)

        if lib.OBJ_obj2nid(ad.method) != nid or \
           ad.location.type != lib.GEN_URI:
            continue
        uri = ad.location.d.uniformResourceIdentifier
        ostr = _str_with_len(uri.data, uri.length)
        lst.append(ostr)
    lib.sk_ACCESS_DESCRIPTION_free(info)

    # convert to tuple or None
    if len(lst) == 0: return None
    return tuple(lst)

def _get_peer_alt_names(certificate):
    # this code follows the procedure outlined in
    # OpenSSL's crypto/x509v3/v3_prn.c:X509v3_EXT_print()
    # function to extract the STACK_OF(GENERAL_NAME),
    # then iterates through the stack to add the
    # names.
    peer_alt_names = []

    if certificate == ffi.NULL:
        return None

    # get a memory buffer
    biobuf = lib.BIO_new(lib.BIO_s_mem());

    i = -1
    while True:
        i = lib.X509_get_ext_by_NID(certificate, lib.NID_subject_alt_name, i)
        if i < 0:
            break


        # now decode the altName
        ext = lib.X509_get_ext(certificate, i);
        method = lib.X509V3_EXT_get(ext)
        if method is ffi.NULL:
            raise ssl_error("No method for internalizing subjectAltName!")

        ext_data = lib.X509_EXTENSION_get_data(ext)
        ext_data_len = ext_data.length
        ext_data_value = ffi.new("unsigned char**", ffi.NULL)
        ext_data_value[0] = ext_data.data

        if method.it != ffi.NULL:
            names = lib.ASN1_item_d2i(ffi.NULL, ext_data_value, ext_data_len, lib.ASN1_ITEM_ptr(method.it))
        else:
            names = method.d2i(ffi.NULL, ext_data_value, ext_data_len)

        names = ffi.cast("GENERAL_NAMES*", names)
        count = lib.sk_GENERAL_NAME_num(names)
        for j in range(count):
            # get a rendering of each name in the set of names
            name = lib.sk_GENERAL_NAME_value(names, j);
            _type = name.type
            if _type == lib.GEN_DIRNAME:
                # we special-case DirName as a tuple of
                # tuples of attributes
                v = _create_tuple_for_X509_NAME(name.d.dirn)
                peer_alt_names.append(("DirName", v))
            # GENERAL_NAME_print() doesn't handle NULL bytes in ASN1_string
            # correctly, CVE-2013-4238
            elif _type == lib.GEN_EMAIL:
                v = _string_from_asn1(name.d.rfc822Name)
                peer_alt_names.append(("email", v))
            elif _type == lib.GEN_DNS:
                v = _string_from_asn1(name.d.dNSName)
                peer_alt_names.append(("DNS", v))
            elif _type == lib.GEN_URI:
                v = _string_from_asn1(name.d.uniformResourceIdentifier)
                peer_alt_names.append(("URI", v))
            elif _type == lib.GEN_RID:
                v = "Registered ID"
                buf = ffi.new("char[2048]")

                length = lib.OBJ_obj2txt(buf, 2047, name.d.rid, 0)
                if length < 0:
                    # TODO _setSSLError(NULL, 0, __FILE__, __LINE__);
                    raise NotImplementedError
                elif length >= 2048:
                    v = "<INVALID>"
                else:
                    v = _str_with_len(buf, length)
                peer_alt_names.append(("Registered ID", v))
            else:
                # for everything else, we use the OpenSSL print form
                if _type not in (lib.GEN_OTHERNAME, lib.GEN_X400, \
                                 lib.GEN_EDIPARTY, lib.GEN_IPADD, lib.GEN_RID):
                    warnings.warn("Unknown general type %d" % _type, RuntimeWarning)
                    continue
                lib.BIO_reset(biobuf);
                lib.GENERAL_NAME_print(biobuf, name);
                v = _bio_get_str(biobuf)
                idx = v.find(":")
                if idx == -1:
                    raise ValueError("Invalid value %s", v)
                peer_alt_names.append((v[:idx], v[idx+1:]))

        free_func_addr = ffi.addressof(lib, "GENERAL_NAME_free")
        lib.sk_GENERAL_NAME_pop_free(names, free_func_addr);
    lib.BIO_free(biobuf)
    if peer_alt_names is not None:
        return tuple(peer_alt_names)
    return peer_alt_names

def _create_tuple_for_X509_NAME(xname):
    dn = []
    rdn = []
    rdn_level = -1
    entry_count = lib.X509_NAME_entry_count(xname);
    for index_counter in range(entry_count):
        entry = lib.X509_NAME_get_entry(xname, index_counter);

        # check to see if we've gotten to a new RDN
        _set = lib.Cryptography_X509_NAME_ENTRY_set(entry)
        if rdn_level >= 0:
            if rdn_level != _set:
                dn.append(tuple(rdn))
                rdn = []
        rdn_level = _set

        # now add this attribute to the current RDN
        name = lib.X509_NAME_ENTRY_get_object(entry);
        value = lib.X509_NAME_ENTRY_get_data(entry);
        attr = _create_tuple_for_attribute(name, value);
        if attr == ffi.NULL:
            raise NotImplementedError
        rdn.append(attr)

    # now, there's typically a dangling RDN
    if rdn and len(rdn) > 0:
        dn.append(tuple(rdn))

    return tuple(dn)

def _bio_get_str(biobuf):
    bio_buf = ffi.new("char[]", 2048)
    length = lib.BIO_gets(biobuf, bio_buf, len(bio_buf)-1)
    if length < 0:
        if biobuf: lib.BIO_free(biobuf)
        raise ssl_error(None)
    return _str_with_len(bio_buf, length)

def _decode_certificate(certificate):
    retval = {}

    peer = _create_tuple_for_X509_NAME(lib.X509_get_subject_name(certificate));
    if not peer:
        return None
    retval["subject"] = peer

    issuer = _create_tuple_for_X509_NAME(lib.X509_get_issuer_name(certificate));
    if not issuer:
        return None
    retval["issuer"] = issuer

    version = lib.X509_get_version(certificate) + 1
    if version == 0:
        return None
    retval["version"] = version

    try:
        biobuf = lib.BIO_new(lib.BIO_s_mem());

        lib.BIO_reset(biobuf);
        serialNumber = lib.X509_get_serialNumber(certificate);
        # should not exceed 20 octets, 160 bits, so buf is big enough
        lib.i2a_ASN1_INTEGER(biobuf, serialNumber)
        buf = ffi.new("char[]", 2048)
        length = lib.BIO_gets(biobuf, buf, len(buf)-1)
        if length < 0:
            raise ssl_error(None)
        retval["serialNumber"] = _str_with_len(buf, length)

        lib.BIO_reset(biobuf);
        notBefore = lib.X509_get_notBefore(certificate);
        lib.ASN1_TIME_print(biobuf, notBefore);
        length = lib.BIO_gets(biobuf, buf, len(buf)-1);
        if length < 0:
            raise ssl_error(None)
        retval["notBefore"] = _str_with_len(buf, length)

        lib.BIO_reset(biobuf);
        notAfter = lib.X509_get_notAfter(certificate);
        lib.ASN1_TIME_print(biobuf, notAfter);
        length = lib.BIO_gets(biobuf, buf, len(buf)-1);
        if length < 0:
            raise ssl_error(None)
        retval["notAfter"] = _str_with_len(buf, length)

        # Now look for subjectAltName
        peer_alt_names = _get_peer_alt_names(certificate);
        if peer_alt_names is None:
            return None
        if len(peer_alt_names) > 0:
            retval["subjectAltName"] = peer_alt_names

        # Authority Information Access: OCSP URIs
        obj = _get_aia_uri(certificate, lib.NID_ad_OCSP)
        if obj:
            retval["OCSP"] = obj

        obj = _get_aia_uri(certificate, lib.NID_ad_ca_issuers)
        if obj:
            retval["caIssuers"] = obj

        # CDP (CRL distribution points)
        obj = _get_crl_dp(certificate)
        if obj:
            retval["crlDistributionPoints"] = obj
    finally:
        lib.BIO_free(biobuf)

    return retval


def _get_crl_dp(certificate):
    if lib.OPENSSL_VERSION_NUMBER >= 0x10001000:
        lib.X509_check_ca(certificate)
    dps = lib.X509_get_ext_d2i(certificate, lib.NID_crl_distribution_points, ffi.NULL, ffi.NULL)
    if dps is ffi.NULL:
        return None

    lst = []
    count = lib.sk_DIST_POINT_num(dps)
    for i in range(count):
        dp = lib.sk_DIST_POINT_value(dps, i);
        if not dp.distpoint:
            return None
        gns = dp.distpoint.name.fullname;

        jcount = lib.sk_GENERAL_NAME_num(gns)
        for j in range(jcount):
            gn = lib.sk_GENERAL_NAME_value(gns, j)
            if gn.type != lib.GEN_URI:
                continue

            uri = gn.d.uniformResourceIdentifier;
            ouri = _str_with_len(uri.data, uri.length)
            lst.append(ouri)

    if lib.OPENSSL_VERSION_NUMBER < 0x10001000:
        lib.sk_DIST_POINT_free(dps);

    if len(lst) == 0: return None
    return tuple(lst)

def _test_decode_cert(path):
    cert = lib.BIO_new(lib.BIO_s_file())
    if cert is ffi.NULL:
        lib.BIO_free(cert)
        raise ssl_error("Can't malloc memory to read file")

    epath = path.encode()
    if lib.BIO_read_filename(cert, epath) <= 0:
        lib.BIO_free(cert)
        raise ssl_error("Can't open file")

    x = lib.PEM_read_bio_X509(cert, ffi.NULL, ffi.NULL, ffi.NULL)
    if x is ffi.NULL:
        ssl_error("Error decoding PEM-encoded file")

    retval = _decode_certificate(x)
    lib.X509_free(x);

    if cert != ffi.NULL:
        lib.BIO_free(cert)
    return retval

PEM_HEADER = "-----BEGIN CERTIFICATE-----"
PEM_FOOTER = "-----END CERTIFICATE-----"

def PEM_cert_to_DER_cert(pem_cert_string):
    """Takes a certificate in ASCII PEM format and returns the
    DER-encoded version of it as a byte sequence"""

    if not pem_cert_string.startswith(PEM_HEADER):
        raise ValueError("Invalid PEM encoding; must start with %s"
                         % PEM_HEADER)
    if not pem_cert_string.strip().endswith(PEM_FOOTER):
        raise ValueError("Invalid PEM encoding; must end with %s"
                         % PEM_FOOTER)
    d = pem_cert_string.strip()[len(PEM_HEADER):-len(PEM_FOOTER)]
    return base64.decodebytes(d.encode('ASCII', 'strict'))

def DER_cert_to_PEM_cert(der_cert_bytes):
    """Takes a certificate in binary DER format and returns the
    PEM version of it as a string."""

    f = str(base64.standard_b64encode(der_cert_bytes), 'ASCII', 'strict')
    return (PEM_HEADER + '\n' +
            textwrap.fill(f, 64) + '\n' +
            PEM_FOOTER + '\n')

def _certificate_to_der(certificate):
    buf_ptr = ffi.new("unsigned char**")
    buf_ptr[0] = ffi.NULL
    length = lib.i2d_X509(certificate, buf_ptr)
    if length < 0:
        raise ssl_error(None)
    try:
        return _bytes_with_len(ffi.cast("char*",buf_ptr[0]), length)
    finally:
        lib.OPENSSL_free(buf_ptr[0])
