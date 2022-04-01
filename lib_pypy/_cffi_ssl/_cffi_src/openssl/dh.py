# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/dh.h>
"""

TYPES = """
typedef ... DH;

const long DH_NOT_SUITABLE_GENERATOR;
"""

FUNCTIONS = """
DH *DH_new(void);
void DH_free(DH *);
int DH_size(const DH *);
int DH_generate_key(DH *);
int DH_compute_key(unsigned char *, const BIGNUM *, DH *);
DH *DHparams_dup(DH *);

/* added in 1.1.0 when the DH struct was opaqued */
void DH_get0_pqg(const DH *, const BIGNUM **, const BIGNUM **,
                 const BIGNUM **);
int DH_set0_pqg(DH *, BIGNUM *, BIGNUM *, BIGNUM *);
void DH_get0_key(const DH *, const BIGNUM **, const BIGNUM **);
int DH_set0_key(DH *, BIGNUM *, BIGNUM *);

int Cryptography_DH_check(const DH *, int *);
int DH_generate_parameters_ex(DH *, int, int, BN_GENCB *);
DH *d2i_DHparams_bio(BIO *, DH **);
int i2d_DHparams_bio(BIO *, DH *);
DH *Cryptography_d2i_DHxparams_bio(BIO *bp, DH **x);
int Cryptography_i2d_DHxparams_bio(BIO *bp, DH *x);
"""

CUSTOMIZATIONS = """
/* These functions were added in OpenSSL 1.1.0 */
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110 && !CRYPTOGRAPHY_LIBRESSL_27_OR_GREATER
void DH_get0_pqg(const DH *dh,
                 const BIGNUM **p, const BIGNUM **q, const BIGNUM **g)
{
    if (p != NULL)
        *p = dh->p;
    if (q != NULL)
        *q = dh->q;
    if (g != NULL)
        *g = dh->g;
}

int DH_set0_pqg(DH *dh, BIGNUM *p, BIGNUM *q, BIGNUM *g)
{
    /* If the fields p and g in d are NULL, the corresponding input
     * parameters MUST be non-NULL.  q may remain NULL.
     */
    if ((dh->p == NULL && p == NULL)
        || (dh->g == NULL && g == NULL))
        return 0;

    if (p != NULL) {
        BN_free(dh->p);
        dh->p = p;
    }
    if (q != NULL) {
        BN_free(dh->q);
        dh->q = q;
    }
    if (g != NULL) {
        BN_free(dh->g);
        dh->g = g;
    }

    if (q != NULL) {
        dh->length = BN_num_bits(q);
    }

    return 1;
}

void DH_get0_key(const DH *dh, const BIGNUM **pub_key, const BIGNUM **priv_key)
{
    if (pub_key != NULL)
        *pub_key = dh->pub_key;
    if (priv_key != NULL)
        *priv_key = dh->priv_key;
}

int DH_set0_key(DH *dh, BIGNUM *pub_key, BIGNUM *priv_key)
{
    /* If the field pub_key in dh is NULL, the corresponding input
     * parameters MUST be non-NULL.  The priv_key field may
     * be left NULL.
     */
    if (dh->pub_key == NULL && pub_key == NULL)
        return 0;

    if (pub_key != NULL) {
        BN_free(dh->pub_key);
        dh->pub_key = pub_key;
    }
    if (priv_key != NULL) {
        BN_free(dh->priv_key);
        dh->priv_key = priv_key;
    }

    return 1;
}
#endif

#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110
#ifndef DH_CHECK_Q_NOT_PRIME
#define DH_CHECK_Q_NOT_PRIME            0x10
#endif

#ifndef DH_CHECK_INVALID_Q_VALUE
#define DH_CHECK_INVALID_Q_VALUE        0x20
#endif

#ifndef DH_CHECK_INVALID_J_VALUE
#define DH_CHECK_INVALID_J_VALUE        0x40
#endif

/* DH_check implementation taken from OpenSSL 1.1.0pre6 */

/*-
 * Check that p is a safe prime and
 * if g is 2, 3 or 5, check that it is a suitable generator
 * where
 * for 2, p mod 24 == 11
 * for 3, p mod 12 == 5
 * for 5, p mod 10 == 3 or 7
 * should hold.
 */

int Cryptography_DH_check(const DH *dh, int *ret)
{
    int ok = 0, r;
    BN_CTX *ctx = NULL;
    BN_ULONG l;
    BIGNUM *t1 = NULL, *t2 = NULL;

    *ret = 0;
    ctx = BN_CTX_new();
    if (ctx == NULL)
        goto err;
    BN_CTX_start(ctx);
    t1 = BN_CTX_get(ctx);
    if (t1 == NULL)
        goto err;
    t2 = BN_CTX_get(ctx);
    if (t2 == NULL)
        goto err;

    if (dh->q) {
        if (BN_cmp(dh->g, BN_value_one()) <= 0)
            *ret |= DH_NOT_SUITABLE_GENERATOR;
        else if (BN_cmp(dh->g, dh->p) >= 0)
            *ret |= DH_NOT_SUITABLE_GENERATOR;
        else {
            /* Check g^q == 1 mod p */
            if (!BN_mod_exp(t1, dh->g, dh->q, dh->p, ctx))
                goto err;
            if (!BN_is_one(t1))
                *ret |= DH_NOT_SUITABLE_GENERATOR;
        }
        r = BN_is_prime_ex(dh->q, BN_prime_checks, ctx, NULL);
        if (r < 0)
            goto err;
        if (!r)
            *ret |= DH_CHECK_Q_NOT_PRIME;
        /* Check p == 1 mod q  i.e. q divides p - 1 */
        if (!BN_div(t1, t2, dh->p, dh->q, ctx))
            goto err;
        if (!BN_is_one(t2))
            *ret |= DH_CHECK_INVALID_Q_VALUE;
        if (dh->j && BN_cmp(dh->j, t1))
            *ret |= DH_CHECK_INVALID_J_VALUE;

    } else if (BN_is_word(dh->g, DH_GENERATOR_2)) {
        l = BN_mod_word(dh->p, 24);
        if (l == (BN_ULONG)-1)
            goto err;
        if (l != 11)
            *ret |= DH_NOT_SUITABLE_GENERATOR;
    } else if (BN_is_word(dh->g, DH_GENERATOR_5)) {
        l = BN_mod_word(dh->p, 10);
        if (l == (BN_ULONG)-1)
            goto err;
        if ((l != 3) && (l != 7))
            *ret |= DH_NOT_SUITABLE_GENERATOR;
    } else
        *ret |= DH_UNABLE_TO_CHECK_GENERATOR;

    r = BN_is_prime_ex(dh->p, BN_prime_checks, ctx, NULL);
    if (r < 0)
        goto err;
    if (!r)
        *ret |= DH_CHECK_P_NOT_PRIME;
    else if (!dh->q) {
        if (!BN_rshift1(t1, dh->p))
            goto err;
        r = BN_is_prime_ex(t1, BN_prime_checks, ctx, NULL);
        if (r < 0)
            goto err;
        if (!r)
            *ret |= DH_CHECK_P_NOT_SAFE_PRIME;
    }
    ok = 1;
 err:
    if (ctx != NULL) {
        BN_CTX_end(ctx);
        BN_CTX_free(ctx);
    }
    return (ok);
}
#else
int Cryptography_DH_check(const DH *dh, int *ret) {
    return DH_check(dh, ret);
}
#endif

/* These functions were added in OpenSSL 1.1.0f commit d0c50e80a8 */
/* Define our own to simplify support across all versions. */
#if defined(EVP_PKEY_DHX) && EVP_PKEY_DHX != -1
DH *Cryptography_d2i_DHxparams_bio(BIO *bp, DH **x) {
    return ASN1_d2i_bio_of(DH, DH_new, d2i_DHxparams, bp, x);
}
int Cryptography_i2d_DHxparams_bio(BIO *bp, DH *x) {
    return ASN1_i2d_bio_of_const(DH, i2d_DHxparams, bp, x);
}
#else
DH *(*Cryptography_d2i_DHxparams_bio)(BIO *bp, DH **x) = NULL;
int (*Cryptography_i2d_DHxparams_bio)(BIO *bp, DH *x) = NULL;
#endif
"""
