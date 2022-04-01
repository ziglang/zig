# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/ec.h>
#include <openssl/obj_mac.h>
"""

TYPES = """
static const int Cryptography_HAS_EC2M;
static const int Cryptography_HAS_EC_1_0_2;

static const int OPENSSL_EC_NAMED_CURVE;

typedef ... EC_KEY;
typedef ... EC_GROUP;
typedef ... EC_POINT;
typedef ... EC_METHOD;
typedef struct {
    int nid;
    const char *comment;
} EC_builtin_curve;
typedef enum {
    POINT_CONVERSION_COMPRESSED,
    POINT_CONVERSION_UNCOMPRESSED,
    ...
} point_conversion_form_t;
"""

FUNCTIONS = """
void EC_GROUP_free(EC_GROUP *);

EC_GROUP *EC_GROUP_new_by_curve_name(int);

int EC_GROUP_get_degree(const EC_GROUP *);

const EC_METHOD *EC_GROUP_method_of(const EC_GROUP *);
const EC_POINT *EC_GROUP_get0_generator(const EC_GROUP *);
int EC_GROUP_get_curve_name(const EC_GROUP *);

size_t EC_get_builtin_curves(EC_builtin_curve *, size_t);

EC_KEY *EC_KEY_new(void);
void EC_KEY_free(EC_KEY *);

EC_KEY *EC_KEY_new_by_curve_name(int);
const EC_GROUP *EC_KEY_get0_group(const EC_KEY *);
int EC_GROUP_get_order(const EC_GROUP *, BIGNUM *, BN_CTX *);
int EC_KEY_set_group(EC_KEY *, const EC_GROUP *);
const BIGNUM *EC_KEY_get0_private_key(const EC_KEY *);
int EC_KEY_set_private_key(EC_KEY *, const BIGNUM *);
const EC_POINT *EC_KEY_get0_public_key(const EC_KEY *);
int EC_KEY_set_public_key(EC_KEY *, const EC_POINT *);
void EC_KEY_set_asn1_flag(EC_KEY *, int);
int EC_KEY_generate_key(EC_KEY *);
int EC_KEY_set_public_key_affine_coordinates(EC_KEY *, BIGNUM *, BIGNUM *);

EC_POINT *EC_POINT_new(const EC_GROUP *);
void EC_POINT_free(EC_POINT *);
void EC_POINT_clear_free(EC_POINT *);
EC_POINT *EC_POINT_dup(const EC_POINT *, const EC_GROUP *);

int EC_POINT_set_affine_coordinates_GFp(const EC_GROUP *, EC_POINT *,
    const BIGNUM *, const BIGNUM *, BN_CTX *);

int EC_POINT_get_affine_coordinates_GFp(const EC_GROUP *,
    const EC_POINT *, BIGNUM *, BIGNUM *, BN_CTX *);

int EC_POINT_set_compressed_coordinates_GFp(const EC_GROUP *, EC_POINT *,
    const BIGNUM *, int, BN_CTX *);

int EC_POINT_set_affine_coordinates_GF2m(const EC_GROUP *, EC_POINT *,
    const BIGNUM *, const BIGNUM *, BN_CTX *);

int EC_POINT_get_affine_coordinates_GF2m(const EC_GROUP *,
    const EC_POINT *, BIGNUM *, BIGNUM *, BN_CTX *);

int EC_POINT_set_compressed_coordinates_GF2m(const EC_GROUP *, EC_POINT *,
    const BIGNUM *, int, BN_CTX *);

size_t EC_POINT_point2oct(const EC_GROUP *, const EC_POINT *,
    point_conversion_form_t,
    unsigned char *, size_t, BN_CTX *);

int EC_POINT_oct2point(const EC_GROUP *, EC_POINT *,
    const unsigned char *, size_t, BN_CTX *);

int EC_POINT_add(const EC_GROUP *, EC_POINT *, const EC_POINT *,
    const EC_POINT *, BN_CTX *);

int EC_POINT_dbl(const EC_GROUP *, EC_POINT *, const EC_POINT *, BN_CTX *);
int EC_POINT_invert(const EC_GROUP *, EC_POINT *, BN_CTX *);
int EC_POINT_is_at_infinity(const EC_GROUP *, const EC_POINT *);
int EC_POINT_is_on_curve(const EC_GROUP *, const EC_POINT *, BN_CTX *);

int EC_POINT_cmp(
    const EC_GROUP *, const EC_POINT *, const EC_POINT *, BN_CTX *);

int EC_POINT_mul(const EC_GROUP *, EC_POINT *, const BIGNUM *,
    const EC_POINT *, const BIGNUM *, BN_CTX *);

int EC_METHOD_get_field_type(const EC_METHOD *);

const char *EC_curve_nid2nist(int);
"""

CUSTOMIZATIONS = """
#if defined(OPENSSL_NO_EC2M)
static const long Cryptography_HAS_EC2M = 0;

int (*EC_POINT_set_affine_coordinates_GF2m)(const EC_GROUP *, EC_POINT *,
    const BIGNUM *, const BIGNUM *, BN_CTX *) = NULL;

int (*EC_POINT_get_affine_coordinates_GF2m)(const EC_GROUP *,
    const EC_POINT *, BIGNUM *, BIGNUM *, BN_CTX *) = NULL;

int (*EC_POINT_set_compressed_coordinates_GF2m)(const EC_GROUP *, EC_POINT *,
    const BIGNUM *, int, BN_CTX *) = NULL;
#else
static const long Cryptography_HAS_EC2M = 1;
#endif

#if (!CRYPTOGRAPHY_IS_LIBRESSL && CRYPTOGRAPHY_OPENSSL_LESS_THAN_102)
static const long Cryptography_HAS_EC_1_0_2 = 0;
const char *(*EC_curve_nid2nist)(int) = NULL;
#else
static const long Cryptography_HAS_EC_1_0_2 = 1;
#endif
"""
