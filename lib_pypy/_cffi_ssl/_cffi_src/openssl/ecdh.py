# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/ecdh.h>
"""

TYPES = """
static const int Cryptography_HAS_SET_ECDH_AUTO;
"""

FUNCTIONS = """
int ECDH_compute_key(void *, size_t, const EC_POINT *, EC_KEY *,
                     void *(*)(const void *, size_t, void *, size_t *));
long SSL_CTX_set_ecdh_auto(SSL_CTX *, int);
"""

CUSTOMIZATIONS = """
#ifndef SSL_CTX_set_ecdh_auto
static const long Cryptography_HAS_SET_ECDH_AUTO = 0;
long (*SSL_CTX_set_ecdh_auto)(SSL_CTX *, int) = NULL;
#else
static const long Cryptography_HAS_SET_ECDH_AUTO = 1;
#endif
"""
