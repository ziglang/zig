# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

import os
import sys

from _cffi_src.utils import (
    build_ffi_for_binding, compiler_type, extra_link_args
)


def _get_openssl_libraries(platform):
    if os.environ.get("CRYPTOGRAPHY_SUPPRESS_LINK_FLAGS", None):
        return []
    # OpenSSL goes by a different library name on different operating systems.
    if platform == "win32" and compiler_type() == "msvc":
        windows_link_legacy_openssl = os.environ.get(
            "CRYPTOGRAPHY_WINDOWS_LINK_LEGACY_OPENSSL", None
        )
        if windows_link_legacy_openssl is None:
            # Link against the 1.1.0 names
            libs = ["libssl", "libcrypto"]
        else:
            # Link against the 1.0.2 and lower names
            libs = ["libeay32", "ssleay32"]
        return libs + ["advapi32", "crypt32", "gdi32", "user32", "ws2_32"]
    else:
        # darwin, linux, mingw all use this path
        # In some circumstances, the order in which these libs are
        # specified on the linker command-line is significant;
        # libssl must come before libcrypto
        # (https://marc.info/?l=openssl-users&m=135361825921871)
        return ["ssl", "crypto"]


def _extra_compile_args(platform):
    """
    We set -Wconversion args here so that we only do Wconversion checks on the
    code we're compiling and not on cffi itself (as passing -Wconversion in
    CFLAGS would do). We set no error on sign conversion because some
    function signatures in OpenSSL have changed from long -> unsigned long
    in the past. Since that isn't a precision issue we don't care.
    When we drop support for CRYPTOGRAPHY_OPENSSL_LESS_THAN_110 we can
    revisit this.
    """
    if platform not in ["win32", "hp-ux11", "sunos5"]:
        return ["-Wconversion", "-Wno-error=sign-conversion"]
    else:
        return []


ffi = build_ffi_for_binding(
    module_name="_openssl",
    module_prefix="_cffi_src.openssl.",
    modules=[
        # This goes first so we can define some cryptography-wide symbols.
        "cryptography",

        "aes",
        "asn1",
        "bignum",
        "bio",
        "cmac",
        "conf",
        "crypto",
        "ct",
        "dh",
        "dsa",
        "ec",
        "ecdh",
        "ecdsa",
        "engine",
        "err",
        "evp",
        "fips",
        "hmac",
        "nid",
        "objects",
        "ocsp",
        "opensslv",
        "osrandom_engine",
        "pem",
        "pkcs12",
        "rand",
        "rsa",
        "ssl",
        "x509",
        "x509name",
        "x509v3",
        "x509_vfy",
        "pkcs7",
        "callbacks",
    ],
    libraries=_get_openssl_libraries(sys.platform),
    # These args are passed here so that we only do Wconversion checks on the
    # code we're compiling and not on cffi itself (as passing -Wconversion in
    # CFLAGS would do). We set no error on sign convesrion because some
    # function signatures in OpenSSL have changed from long -> unsigned long
    # in the past. Since that isn't a precision issue we don't care.
    # When we drop support for CRYPTOGRAPHY_OPENSSL_LESS_THAN_110 we can
    # revisit this.
    extra_compile_args=_extra_compile_args(sys.platform),
    extra_link_args=extra_link_args(compiler_type()),
)
