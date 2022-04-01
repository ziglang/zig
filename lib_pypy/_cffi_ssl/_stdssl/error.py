import sys
import os
import socket
import traceback
from _pypy_openssl import ffi
from _pypy_openssl import lib

from _cffi_ssl._stdssl.utility import _string_from_asn1, _str_to_ffi_buffer, _str_from_buf
from _cffi_ssl._stdssl.errorcodes import _error_codes, _lib_codes
from __pypy__ import write_unraisable

SSL_ERROR_NONE = 0
SSL_ERROR_SSL = 1
SSL_ERROR_WANT_READ = 2
SSL_ERROR_WANT_WRITE = 3
SSL_ERROR_WANT_X509_LOOKUP = 4
SSL_ERROR_SYSCALL = 5
SSL_ERROR_ZERO_RETURN = 6
SSL_ERROR_WANT_CONNECT = 7
# start of non ssl.h errorcodes
SSL_ERROR_EOF = 8 # special case of SSL_ERROR_SYSCALL
SSL_ERROR_NO_SOCKET = 9 # socket has been GC'd
SSL_ERROR_INVALID_ERROR_CODE = 10

class SSLError(OSError):
    """ An error occurred in the SSL implementation. """
    def __str__(self):
        if self.strerror and isinstance(self.strerror, str):
            return self.strerror
        return str(self.args)
# these are expected on socket as well
socket.sslerror = SSLError
for v in [ 'SSL_ERROR_ZERO_RETURN', 'SSL_ERROR_WANT_READ',
     'SSL_ERROR_WANT_WRITE', 'SSL_ERROR_WANT_X509_LOOKUP', 'SSL_ERROR_SYSCALL',
     'SSL_ERROR_SSL', 'SSL_ERROR_WANT_CONNECT', 'SSL_ERROR_EOF',
     'SSL_ERROR_INVALID_ERROR_CODE' ]:
    setattr(socket, v, locals()[v])

class SSLCertVerificationError(SSLError, ValueError):
    """A certificate could not be verified."""

class SSLZeroReturnError(SSLError):
    """ SSL/TLS session closed cleanly. """

class SSLWantReadError(SSLError):
    """ Non-blocking SSL socket needs to read more data
        before the requested operation can be completed.
    """

class SSLWantWriteError(SSLError):
    """Non-blocking SSL socket needs to write more data
       before the requested operation can be completed.
    """

class SSLSyscallError(SSLError):
    """ System error when attempting SSL operation. """

class SSLEOFError(SSLError):
    """ SSL/TLS connection terminated abruptly. """

def ssl_error(errstr, errcode=0):
    if errstr is None:
        errcode = lib.ERR_peek_last_error()
    try:
        return fill_sslerror(None, SSLError, errcode, errstr, errcode)
    finally:
        lib.ERR_clear_error()

ERR_CODES_TO_NAMES = {}
ERR_NAMES_TO_CODES = {}
LIB_CODES_TO_NAMES = {}

for mnemo, library, reason in _error_codes:
    key = (library, reason)
    assert mnemo is not None and key is not None
    ERR_CODES_TO_NAMES[key] = mnemo
    ERR_NAMES_TO_CODES[mnemo] = key


for mnemo, number in _lib_codes:
    LIB_CODES_TO_NAMES[number] = mnemo


# the PySSL_SetError equivalent
def pyssl_error(obj, ret):
    errcode = lib.ERR_peek_last_error()

    errstr = ""
    errval = 0
    errtype = SSLError
    e = lib.ERR_peek_last_error()

    if obj.ssl != ffi.NULL:
        err = obj.err

        if err.ssl == SSL_ERROR_ZERO_RETURN:
            errtype = SSLZeroReturnError
            errstr = "TLS/SSL connection has been closed (EOF)"
            errval = SSL_ERROR_ZERO_RETURN
        elif err.ssl == SSL_ERROR_WANT_READ:
            errtype = SSLWantReadError
            errstr = "The operation did not complete (read)"
            errval = SSL_ERROR_WANT_READ
        elif err.ssl == SSL_ERROR_WANT_WRITE:
            errtype = SSLWantWriteError
            errstr = "The operation did not complete (write)"
            errval = SSL_ERROR_WANT_WRITE
        elif err.ssl == SSL_ERROR_WANT_X509_LOOKUP:
            errstr = "The operation did not complete (X509 lookup)"
            errval = SSL_ERROR_WANT_X509_LOOKUP
        elif err.ssl == SSL_ERROR_WANT_CONNECT:
            errstr = "The operation did not complete (connect)"
            errval = SSL_ERROR_WANT_CONNECT
        elif err.ssl == SSL_ERROR_SYSCALL:
            if e == 0:
                if ret == 0 or obj.socket is None:
                    errtype = SSLEOFError
                    errstr = "EOF occurred in violation of protocol"
                    errval = SSL_ERROR_EOF
                elif ret == -1 and obj.socket is not None:
                    # the underlying BIO reported an I/0 error
                    lib.ERR_clear_error()
                    # s = obj.get_socket_or_None()
                    if sys.platform == 'win32':
                        if err.ws:
                            return OSError(err.ws, os.strerror(err.ws))
                    if err.c:
                        ffi.errno = err.c 
                    errno = ffi.errno
                    return OSError(errno, os.strerror(errno))
                else:
                    errtype = SSLSyscallError
                    errstr = "Some I/O error occurred"
                    errval = SSL_ERROR_SYSCALL
            else:
                errstr = _str_from_buf(lib.ERR_lib_error_string(e))
                errval = SSL_ERROR_SYSCALL
        elif err.ssl == SSL_ERROR_SSL:
            errval = SSL_ERROR_SSL
            if e == 0:
                errstr = "A failure in the SSL library occurred"
            else:
                errstr = _str_from_buf(lib.ERR_lib_error_string(errcode))
            err_lib = lib.ERR_GET_LIB(e)
            err_reason = lib.ERR_GET_REASON(e)
            reason_str = ERR_CODES_TO_NAMES.get((err_lib, err_reason), None)
            if (lib.ERR_GET_LIB(e) == lib.ERR_LIB_SSL and 
                    reason_str == 'CERTIFICATE_VERIFY_FAILED'):
                errtype = SSLCertVerificationError
        else:
            errstr = "Invalid error code"
            errval = SSL_ERROR_INVALID_ERROR_CODE
    return fill_sslerror(obj, errtype, errval, errstr, e)


def fill_sslerror(obj, errtype, ssl_errno, errstr, errcode):
    reason_str = None
    lib_str = None
    if errcode != 0:
        err_lib = lib.ERR_GET_LIB(errcode)
        err_reason = lib.ERR_GET_REASON(errcode)
        reason_str = ERR_CODES_TO_NAMES.get((err_lib, err_reason), None)
        lib_str = LIB_CODES_TO_NAMES.get(err_lib, None)
        # Set last part of msg to a lower-case version of reason_str
        errstr = _str_from_buf(lib.ERR_reason_error_string(errcode))
    msg = errstr
    if not errstr:
        msg = "unknown error"
    # verify code for cert validation error
    verify_str = None
    if (obj and errtype is SSLCertVerificationError):
        verify_code = lib.SSL_get_verify_result(obj.ssl)
        if lib.Cryptography_HAS_102_VERIFICATION_ERROR_CODES:
            if verify_code == lib.X509_V_ERR_HOSTNAME_MISMATCH:
                verify_str = ("Hostname mismatch, certificate is not "
                              f"valid for '{obj.server_hostname}'.")
            elif verify_code == lib.X509_V_ERR_IP_ADDRESS_MISMATCH :
                verify_str = ("IP address mismatch, certificate is not "
                              f"valid for '{obj.server_hostname}'.")
        if not verify_str:
            verify_str = ffi.string(lib.X509_verify_cert_error_string(verify_code)).decode()
    if verify_str and reason_str and lib_str:
        msg = f'[{lib_str}: {reason_str}] {errstr}: {verify_str}'
    elif reason_str and lib_str:
        msg = f"[{lib_str}: {reason_str}] {errstr}"
    elif lib_str:
        msg = f"[{lib_str}] {errstr}"

    err_value = errtype(ssl_errno, msg)
    err_value.reason = reason_str if reason_str else None
    err_value.library = lib_str if lib_str else None
    if (obj and errtype is SSLCertVerificationError):
        err_value.verify_code = verify_code
        err_value.verify_message = verify_str
    return err_value

def pyerr_write_unraisable(exc, obj):
    write_unraisable('in ssl', exc, obj)

SSL_AD_NAMES = [
    "ACCESS_DENIED",
    "BAD_CERTIFICATE",
    "BAD_CERTIFICATE_HASH_VALUE",
    "BAD_CERTIFICATE_STATUS_RESPONSE",
    "BAD_RECORD_MAC",
    "CERTIFICATE_EXPIRED",
    "CERTIFICATE_REVOKED",
    "CERTIFICATE_UNKNOWN",
    "CERTIFICATE_UNOBTAINABLE",
    "CLOSE_NOTIFY",
    "DECODE_ERROR",
    "DECOMPRESSION_FAILURE",
    "DECRYPT_ERROR",
    "HANDSHAKE_FAILURE",
    "ILLEGAL_PARAMETER",
    "INSUFFICIENT_SECURITY",
    "INTERNAL_ERROR",
    "NO_RENEGOTIATION",
    "PROTOCOL_VERSION",
    "RECORD_OVERFLOW",
    "UNEXPECTED_MESSAGE",
    "UNKNOWN_CA",
    "UNKNOWN_PSK_IDENTITY",
    "UNRECOGNIZED_NAME",
    "UNSUPPORTED_CERTIFICATE",
    "UNSUPPORTED_EXTENSION",
    "USER_CANCELLED",
]
