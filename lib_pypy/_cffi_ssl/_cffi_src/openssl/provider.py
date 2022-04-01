# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.


INCLUDES = """
#if CRYPTOGRAPHY_OPENSSL_300_OR_GREATER
#include <openssl/provider.h>
#include <openssl/proverr.h>
#endif
"""

TYPES = """
static const long Cryptography_HAS_PROVIDERS;

typedef ... OSSL_PROVIDER;
typedef ... OSSL_LIB_CTX;

static const long PROV_R_BAD_DECRYPT;
static const long PROV_R_XTS_DUPLICATED_KEYS;
static const long PROV_R_WRONG_FINAL_BLOCK_LENGTH;
"""

FUNCTIONS = """
"""

CUSTOMIZATIONS = """
#if CRYPTOGRAPHY_OPENSSL_300_OR_GREATER
static const long Cryptography_HAS_PROVIDERS = 1;
#else
static const long Cryptography_HAS_PROVIDERS = 0;
typedef void OSSL_PROVIDER;
typedef void OSSL_LIB_CTX;
static const long PROV_R_BAD_DECRYPT = 0;
static const long PROV_R_XTS_DUPLICATED_KEYS = 0;
static const long PROV_R_WRONG_FINAL_BLOCK_LENGTH = 0;
#endif
"""
