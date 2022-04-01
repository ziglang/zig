# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/hmac.h>
"""

TYPES = """
typedef ... HMAC_CTX;
"""

FUNCTIONS = """
int HMAC_Init_ex(HMAC_CTX *, const void *, int, const EVP_MD *, ENGINE *);
int HMAC_Update(HMAC_CTX *, const unsigned char *, size_t);
int HMAC_Final(HMAC_CTX *, unsigned char *, unsigned int *);
int HMAC_CTX_copy(HMAC_CTX *, HMAC_CTX *);

HMAC_CTX *Cryptography_HMAC_CTX_new(void);
void Cryptography_HMAC_CTX_free(HMAC_CTX *ctx);
"""

CUSTOMIZATIONS = """
HMAC_CTX *Cryptography_HMAC_CTX_new(void) {
#if CRYPTOGRAPHY_OPENSSL_110_OR_GREATER
    return HMAC_CTX_new();
#else
    /* This uses OPENSSL_zalloc in 1.1.0, which is malloc + memset */
    HMAC_CTX *ctx = (HMAC_CTX *)OPENSSL_malloc(sizeof(HMAC_CTX));
    memset(ctx, 0, sizeof(HMAC_CTX));
    return ctx;
#endif
}


void Cryptography_HMAC_CTX_free(HMAC_CTX *ctx) {
#if CRYPTOGRAPHY_OPENSSL_110_OR_GREATER
    return HMAC_CTX_free(ctx);
#else
    if (ctx != NULL) {
        HMAC_CTX_cleanup(ctx);
        OPENSSL_free(ctx);
    }
#endif
}
"""
