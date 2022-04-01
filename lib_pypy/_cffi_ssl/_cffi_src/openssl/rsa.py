# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/rsa.h>
"""

TYPES = """
typedef ... RSA;
typedef ... BN_GENCB;
static const int RSA_PKCS1_PADDING;
static const int RSA_NO_PADDING;
static const int RSA_PKCS1_OAEP_PADDING;
static const int RSA_PKCS1_PSS_PADDING;
static const int RSA_F4;

static const int Cryptography_HAS_PSS_PADDING;
static const int Cryptography_HAS_RSA_OAEP_MD;
static const int Cryptography_HAS_RSA_OAEP_LABEL;
"""

FUNCTIONS = """
RSA *RSA_new(void);
void RSA_free(RSA *);
int RSA_size(const RSA *);
int RSA_generate_key_ex(RSA *, int, BIGNUM *, BN_GENCB *);
int RSA_check_key(const RSA *);
RSA *RSAPublicKey_dup(RSA *);
int RSA_blinding_on(RSA *, BN_CTX *);
int RSA_public_encrypt(int, const unsigned char *, unsigned char *,
                       RSA *, int);
int RSA_private_encrypt(int, const unsigned char *, unsigned char *,
                        RSA *, int);
int RSA_public_decrypt(int, const unsigned char *, unsigned char *,
                       RSA *, int);
int RSA_private_decrypt(int, const unsigned char *, unsigned char *,
                        RSA *, int);
int RSA_print(BIO *, const RSA *, int);

/* added in 1.1.0 when the RSA struct was opaqued */
int RSA_set0_key(RSA *, BIGNUM *, BIGNUM *, BIGNUM *);
int RSA_set0_factors(RSA *, BIGNUM *, BIGNUM *);
int RSA_set0_crt_params(RSA *, BIGNUM *, BIGNUM *, BIGNUM *);
void RSA_get0_key(const RSA *, const BIGNUM **, const BIGNUM **,
                  const BIGNUM **);
void RSA_get0_factors(const RSA *, const BIGNUM **, const BIGNUM **);
void RSA_get0_crt_params(const RSA *, const BIGNUM **, const BIGNUM **,
                         const BIGNUM **);
// int EVP_PKEY_CTX_set_rsa_padding(EVP_PKEY_CTX *, int);
//int EVP_PKEY_CTX_set_rsa_pss_saltlen(EVP_PKEY_CTX *, int);
int EVP_PKEY_CTX_set_rsa_mgf1_md(EVP_PKEY_CTX *, EVP_MD *);
int EVP_PKEY_CTX_set0_rsa_oaep_label(EVP_PKEY_CTX *, unsigned char *, int);

int EVP_PKEY_CTX_set_rsa_oaep_md(EVP_PKEY_CTX *, EVP_MD *);
"""

CUSTOMIZATIONS = """
static const long Cryptography_HAS_PSS_PADDING = 1;

#if !CRYPTOGRAPHY_IS_LIBRESSL
static const long Cryptography_HAS_RSA_OAEP_MD = 1;
static const long Cryptography_HAS_RSA_OAEP_LABEL = 1;
#else
static const long Cryptography_HAS_RSA_OAEP_MD = 0;
static const long Cryptography_HAS_RSA_OAEP_LABEL = 0;
int (*EVP_PKEY_CTX_set_rsa_oaep_md)(EVP_PKEY_CTX *, EVP_MD *) = NULL;
int (*EVP_PKEY_CTX_set0_rsa_oaep_label)(EVP_PKEY_CTX *, unsigned char *,
                                        int) = NULL;
#endif

/* These functions were added in OpenSSL 1.1.0 */
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110 && !CRYPTOGRAPHY_LIBRESSL_27_OR_GREATER
int RSA_set0_key(RSA *r, BIGNUM *n, BIGNUM *e, BIGNUM *d)
{
    /* If the fields n and e in r are NULL, the corresponding input
     * parameters MUST be non-NULL for n and e.  d may be
     * left NULL (in case only the public key is used).
     */
    if ((r->n == NULL && n == NULL)
        || (r->e == NULL && e == NULL))
        return 0;

    if (n != NULL) {
        BN_free(r->n);
        r->n = n;
    }
    if (e != NULL) {
        BN_free(r->e);
        r->e = e;
    }
    if (d != NULL) {
        BN_free(r->d);
        r->d = d;
    }

    return 1;
}

int RSA_set0_factors(RSA *r, BIGNUM *p, BIGNUM *q)
{
    /* If the fields p and q in r are NULL, the corresponding input
     * parameters MUST be non-NULL.
     */
    if ((r->p == NULL && p == NULL)
        || (r->q == NULL && q == NULL))
        return 0;

    if (p != NULL) {
        BN_free(r->p);
        r->p = p;
    }
    if (q != NULL) {
        BN_free(r->q);
        r->q = q;
    }

    return 1;
}

int RSA_set0_crt_params(RSA *r, BIGNUM *dmp1, BIGNUM *dmq1, BIGNUM *iqmp)
{
    /* If the fields dmp1, dmq1 and iqmp in r are NULL, the corresponding input
     * parameters MUST be non-NULL.
     */
    if ((r->dmp1 == NULL && dmp1 == NULL)
        || (r->dmq1 == NULL && dmq1 == NULL)
        || (r->iqmp == NULL && iqmp == NULL))
        return 0;

    if (dmp1 != NULL) {
        BN_free(r->dmp1);
        r->dmp1 = dmp1;
    }
    if (dmq1 != NULL) {
        BN_free(r->dmq1);
        r->dmq1 = dmq1;
    }
    if (iqmp != NULL) {
        BN_free(r->iqmp);
        r->iqmp = iqmp;
    }

    return 1;
}

void RSA_get0_key(const RSA *r,
                  const BIGNUM **n, const BIGNUM **e, const BIGNUM **d)
{
    if (n != NULL)
        *n = r->n;
    if (e != NULL)
        *e = r->e;
    if (d != NULL)
        *d = r->d;
}

void RSA_get0_factors(const RSA *r, const BIGNUM **p, const BIGNUM **q)
{
    if (p != NULL)
        *p = r->p;
    if (q != NULL)
        *q = r->q;
}

void RSA_get0_crt_params(const RSA *r,
                         const BIGNUM **dmp1, const BIGNUM **dmq1,
                         const BIGNUM **iqmp)
{
    if (dmp1 != NULL)
        *dmp1 = r->dmp1;
    if (dmq1 != NULL)
        *dmq1 = r->dmq1;
    if (iqmp != NULL)
        *iqmp = r->iqmp;
}
#endif
"""
