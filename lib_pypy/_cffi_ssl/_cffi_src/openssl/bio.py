# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/bio.h>
"""

TYPES = """
typedef ... BIO;
typedef ... BIO_METHOD;
"""

FUNCTIONS = """
int BIO_free(BIO *);
void BIO_free_all(BIO *);
BIO *BIO_new_file(const char *, const char *);
BIO *BIO_new_dgram(int, int);
size_t BIO_ctrl_pending(BIO *);
int BIO_read(BIO *, void *, int);
int BIO_gets(BIO *, char *, int);
int BIO_write(BIO *, const void *, int);
/* Added in 1.1.0 */
int BIO_up_ref(BIO *);

BIO *BIO_new(BIO_METHOD *);
const BIO_METHOD *BIO_s_mem(void);
const BIO_METHOD *BIO_s_file(void);
const BIO_METHOD *BIO_s_datagram(void);
BIO *BIO_new_mem_buf(const void *, int);
long BIO_set_mem_eof_return(BIO *, int);
long BIO_get_mem_data(BIO *, char **);
long BIO_read_filename(BIO *, char *);
int BIO_should_read(BIO *);
int BIO_should_write(BIO *);
int BIO_should_io_special(BIO *);
int BIO_should_retry(BIO *);
int BIO_reset(BIO *);
long BIO_set_nbio(BIO *, long);
void BIO_set_retry_read(BIO *);
void BIO_clear_retry_flags(BIO *);
"""

CUSTOMIZATIONS = """
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110 && !CRYPTOGRAPHY_LIBRESSL_27_OR_GREATER
int BIO_up_ref(BIO *b) {
    CRYPTO_add(&b->references, 1, CRYPTO_LOCK_BIO);
    return 1;
}
#endif
"""
