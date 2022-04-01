from _cffi_ssl._stdssl import (
    _PROTOCOL_NAMES, _OPENSSL_API_VERSION, _test_decode_cert, _SSLContext,
    _DEFAULT_CIPHERS)
from _cffi_ssl import _stdssl
from _cffi_ssl._stdssl import *

OP_SINGLE_DH_USE = lib.SSL_OP_SINGLE_DH_USE
OP_SINGLE_ECDH_USE = lib.SSL_OP_SINGLE_ECDH_USE

try: from __pypy__ import builtinify
except ImportError: builtinify = lambda f: f

RAND_add          = builtinify(RAND_add)
RAND_bytes        = builtinify(RAND_bytes)
RAND_pseudo_bytes = builtinify(RAND_pseudo_bytes)
RAND_status       = builtinify(RAND_status)
# RAND_egd is optional and might not be available on e.g. libressl
if hasattr(_stdssl, 'RAND_egd'):
    RAND_egd          = builtinify(RAND_egd)

import sys
if sys.platform == "win32":
    if 'enum_certificates' not in globals():
        def enum_certificates(*args, **kwds):
            import warnings
            warnings.warn("ssl.enum_certificates() is not implemented")
            return []
    if 'enum_crls' not in globals():
        def enum_crls(*args, **kwds):
            import warnings
            warnings.warn("ssl.enum_crls() is not implemented")
            return []
