# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/ecdsa.h>
"""

TYPES = """
static const int Cryptography_HAS_ECDSA;

typedef ... ECDSA_SIG;

typedef ... CRYPTO_EX_new;
typedef ... CRYPTO_EX_dup;
typedef ... CRYPTO_EX_free;
"""

FUNCTIONS = """
ECDSA_SIG *ECDSA_SIG_new();
void ECDSA_SIG_free(ECDSA_SIG *);
int i2d_ECDSA_SIG(const ECDSA_SIG *, unsigned char **);
ECDSA_SIG *d2i_ECDSA_SIG(ECDSA_SIG **s, const unsigned char **, long);
ECDSA_SIG *ECDSA_do_sign(const unsigned char *, int, EC_KEY *);
int ECDSA_do_verify(const unsigned char *, int, const ECDSA_SIG *, EC_KEY *);
int ECDSA_sign(int, const unsigned char *, int, unsigned char *,
               unsigned int *, EC_KEY *);
int ECDSA_verify(int, const unsigned char *, int, const unsigned char *, int,
                 EC_KEY *);
int ECDSA_size(const EC_KEY *);

"""

CUSTOMIZATIONS = """
static const long Cryptography_HAS_ECDSA = 1;
"""
