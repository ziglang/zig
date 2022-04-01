# PyPy's SSL module

PyPy's _ssl module began as a fork of cryptography 2.7. The code in _cffi_src
contains vestiges of the cryptography code, but has diverged significantly to
handle newer OpenSSL versions and to more closely track what is needed for
CPython compatibility.


The build uses cffi. The declarations and definitions of the imported functions
are in _cffi_src/openssl. The cryptography LICENSE is preserved in this
directory
