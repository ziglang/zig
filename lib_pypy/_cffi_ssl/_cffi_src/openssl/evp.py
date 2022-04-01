# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/evp.h>
"""

TYPES = """
typedef ... EVP_CIPHER;
typedef ... EVP_CIPHER_CTX;
typedef ... EVP_MD;
typedef ... EVP_MD_CTX;

typedef ... EVP_PKEY;
typedef ... EVP_PKEY_CTX;
static const int EVP_PKEY_RSA;
static const int EVP_PKEY_DSA;
static const int EVP_PKEY_DH;
static const int EVP_PKEY_DHX;
static const int EVP_PKEY_EC;
static const int EVP_PKEY_X25519;
static const int EVP_PKEY_ED25519;
static const int EVP_PKEY_X448;
static const int EVP_PKEY_ED448;
static const int EVP_PKEY_POLY1305;
static const int EVP_MAX_MD_SIZE;
static const int EVP_CTRL_AEAD_SET_IVLEN;
static const int EVP_CTRL_AEAD_GET_TAG;
static const int EVP_CTRL_AEAD_SET_TAG;
// only on OpenSSL 1.1.1+
static const int EVP_MD_CTX_FLAG_NON_FIPS_ALLOW;

static const int Cryptography_HAS_SCRYPT;
static const int Cryptography_HAS_EVP_PKEY_DHX;
static const int Cryptography_HAS_EVP_PKEY_get_set_tls_encodedpoint;
static const int Cryptography_HAS_ONESHOT_EVP_DIGEST_SIGN_VERIFY;
static const long Cryptography_HAS_RAW_KEY;
static const long Cryptography_HAS_EVP_DIGESTFINAL_XOF;
"""

FUNCTIONS = """
const EVP_CIPHER *EVP_get_cipherbyname(const char *);
int EVP_CIPHER_CTX_set_padding(EVP_CIPHER_CTX *, int);
int EVP_CipherInit_ex(EVP_CIPHER_CTX *, const EVP_CIPHER *, ENGINE *,
                      const unsigned char *, const unsigned char *, int);
int EVP_CipherUpdate(EVP_CIPHER_CTX *, unsigned char *, int *,
                     const unsigned char *, int);
int EVP_CipherFinal_ex(EVP_CIPHER_CTX *, unsigned char *, int *);
int EVP_CIPHER_CTX_cleanup(EVP_CIPHER_CTX *);
EVP_CIPHER_CTX *EVP_CIPHER_CTX_new(void);
void EVP_CIPHER_CTX_free(EVP_CIPHER_CTX *);
int EVP_CIPHER_CTX_set_key_length(EVP_CIPHER_CTX *, int);
const EVP_CIPHER *EVP_CIPHER_CTX_cipher(const EVP_CIPHER_CTX *);

int EVP_MD_CTX_copy_ex(EVP_MD_CTX *, const EVP_MD_CTX *);
int EVP_DigestInit_ex(EVP_MD_CTX *, const EVP_MD *, ENGINE *);
int EVP_DigestUpdate(EVP_MD_CTX *, const void *, size_t);
int EVP_DigestFinal_ex(EVP_MD_CTX *, unsigned char *, unsigned int *);
int EVP_DigestFinalXOF(EVP_MD_CTX *, unsigned char *, size_t);
const EVP_MD *EVP_get_digestbyname(const char *);
int EVP_MD_size(const EVP_MD *);

EVP_PKEY *EVP_PKEY_new(void);
void EVP_PKEY_free(EVP_PKEY *);
int EVP_PKEY_type(int);
int EVP_PKEY_size(EVP_PKEY *);
RSA *EVP_PKEY_get1_RSA(EVP_PKEY *);
DSA *EVP_PKEY_get1_DSA(EVP_PKEY *);
DH *EVP_PKEY_get1_DH(EVP_PKEY *);

int EVP_PKEY_encrypt(EVP_PKEY_CTX *, unsigned char *, size_t *,
                     const unsigned char *, size_t);
int EVP_PKEY_decrypt(EVP_PKEY_CTX *, unsigned char *, size_t *,
                     const unsigned char *, size_t);

int EVP_SignInit(EVP_MD_CTX *, const EVP_MD *);
int EVP_SignUpdate(EVP_MD_CTX *, const void *, size_t);
int EVP_SignFinal(EVP_MD_CTX *, unsigned char *, unsigned int *, EVP_PKEY *);

int EVP_VerifyInit(EVP_MD_CTX *, const EVP_MD *);
int EVP_VerifyUpdate(EVP_MD_CTX *, const void *, size_t);
int EVP_VerifyFinal(EVP_MD_CTX *, const unsigned char *, unsigned int,
                    EVP_PKEY *);

int EVP_DigestSignInit(EVP_MD_CTX *, EVP_PKEY_CTX **, const EVP_MD *,
                       ENGINE *, EVP_PKEY *);
int EVP_DigestSignUpdate(EVP_MD_CTX *, const void *, size_t);
int EVP_DigestSignFinal(EVP_MD_CTX *, unsigned char *, size_t *);
int EVP_DigestVerifyInit(EVP_MD_CTX *, EVP_PKEY_CTX **, const EVP_MD *,
                         ENGINE *, EVP_PKEY *);

int PKCS5_PBKDF2_HMAC_SHA1(const char *, int, const unsigned char *, int, int,
                           int, unsigned char *);

EVP_PKEY_CTX *EVP_PKEY_CTX_new(EVP_PKEY *, ENGINE *);
EVP_PKEY_CTX *EVP_PKEY_CTX_new_id(int, ENGINE *);
EVP_PKEY_CTX *EVP_PKEY_CTX_dup(EVP_PKEY_CTX *);
void EVP_PKEY_CTX_free(EVP_PKEY_CTX *);
int EVP_PKEY_sign_init(EVP_PKEY_CTX *);
int EVP_PKEY_sign(EVP_PKEY_CTX *, unsigned char *, size_t *,
                  const unsigned char *, size_t);
int EVP_PKEY_verify_init(EVP_PKEY_CTX *);
int EVP_PKEY_verify(EVP_PKEY_CTX *, const unsigned char *, size_t,
                    const unsigned char *, size_t);
int EVP_PKEY_encrypt_init(EVP_PKEY_CTX *);
int EVP_PKEY_decrypt_init(EVP_PKEY_CTX *);

int EVP_PKEY_set1_RSA(EVP_PKEY *, RSA *);
int EVP_PKEY_set1_DSA(EVP_PKEY *, DSA *);
int EVP_PKEY_set1_DH(EVP_PKEY *, DH *);

int EVP_PKEY_cmp(const EVP_PKEY *, const EVP_PKEY *);

int EVP_PKEY_keygen_init(EVP_PKEY_CTX *);
int EVP_PKEY_keygen(EVP_PKEY_CTX *, EVP_PKEY **);
int EVP_PKEY_derive_init(EVP_PKEY_CTX *);
int EVP_PKEY_derive_set_peer(EVP_PKEY_CTX *, EVP_PKEY *);
int EVP_PKEY_derive(EVP_PKEY_CTX *, unsigned char *, size_t *);
int EVP_PKEY_set_type(EVP_PKEY *, int);

/* in 1.1.0 _create and _destroy were renamed to _new and _free. The following
   two functions wrap both the old and new functions so we can call them
   without worrying about what OpenSSL we're running against. */
EVP_MD_CTX *Cryptography_EVP_MD_CTX_new(void);
void Cryptography_EVP_MD_CTX_free(EVP_MD_CTX *);
/* Added in 1.1.1 */
int EVP_DigestSign(EVP_MD_CTX *, unsigned char *, size_t *,
                   const unsigned char *, size_t);
int EVP_DigestVerify(EVP_MD_CTX *, const unsigned char *, size_t,
                     const unsigned char *, size_t);
/* Added in 1.1.0 */
size_t EVP_PKEY_get1_tls_encodedpoint(EVP_PKEY *, unsigned char **);
int EVP_PKEY_set1_tls_encodedpoint(EVP_PKEY *, const unsigned char *,
                                   size_t);

/* EVP_PKEY * became const in 1.1.0 */
// int EVP_PKEY_bits(EVP_PKEY *);

void OpenSSL_add_all_algorithms(void);
int EVP_PKEY_assign_RSA(EVP_PKEY *, RSA *);

EC_KEY *EVP_PKEY_get1_EC_KEY(EVP_PKEY *);
int EVP_PKEY_set1_EC_KEY(EVP_PKEY *, EC_KEY *);

int EVP_MD_CTX_block_size(const EVP_MD_CTX *);
int EVP_CIPHER_CTX_ctrl(EVP_CIPHER_CTX *, int, int, void *);

int PKCS5_PBKDF2_HMAC(const char *, int, const unsigned char *, int, int,
                      const EVP_MD *, int, unsigned char *);

int EVP_PKEY_CTX_set_signature_md(EVP_PKEY_CTX *, const EVP_MD *);

int EVP_PBE_scrypt(const char *, size_t, const unsigned char *, size_t,
                   uint64_t, uint64_t, uint64_t, uint64_t, unsigned char *,
                   size_t);

EVP_PKEY *EVP_PKEY_new_raw_private_key(int, ENGINE *, const unsigned char *,
                                       size_t);
EVP_PKEY *EVP_PKEY_new_raw_public_key(int, ENGINE *, const unsigned char *,
                                      size_t);
int EVP_PKEY_get_raw_private_key(const EVP_PKEY *, unsigned char *, size_t *);
int EVP_PKEY_get_raw_public_key(const EVP_PKEY *, unsigned char *, size_t *);
/* OpenSSL 1.1.1+ */
void EVP_MD_CTX_set_flags(EVP_MD_CTX *ctx, int flags);
"""

CUSTOMIZATIONS = """
#ifdef EVP_PKEY_DHX
const long Cryptography_HAS_EVP_PKEY_DHX = 1;
#else
const long Cryptography_HAS_EVP_PKEY_DHX = 0;
const long EVP_PKEY_DHX = -1;
#endif

EVP_MD_CTX *Cryptography_EVP_MD_CTX_new(void) {
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110
    return EVP_MD_CTX_create();
#else
    return EVP_MD_CTX_new();
#endif
}
void Cryptography_EVP_MD_CTX_free(EVP_MD_CTX *ctx) {
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110
    EVP_MD_CTX_destroy(ctx);
#else
    EVP_MD_CTX_free(ctx);
#endif
}
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110 || defined(OPENSSL_NO_SCRYPT)
static const long Cryptography_HAS_SCRYPT = 0;
int (*EVP_PBE_scrypt)(const char *, size_t, const unsigned char *, size_t,
                      uint64_t, uint64_t, uint64_t, uint64_t, unsigned char *,
                      size_t) = NULL;
#else
static const long Cryptography_HAS_SCRYPT = 1;
#endif

#if CRYPTOGRAPHY_OPENSSL_110_OR_GREATER
static const long Cryptography_HAS_EVP_PKEY_get_set_tls_encodedpoint = 1;
#else
static const long Cryptography_HAS_EVP_PKEY_get_set_tls_encodedpoint = 0;
size_t (*EVP_PKEY_get1_tls_encodedpoint)(EVP_PKEY *, unsigned char **) = NULL;
int (*EVP_PKEY_set1_tls_encodedpoint)(EVP_PKEY *, const unsigned char *,
                                      size_t) = NULL;
#endif

#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_111
static const long Cryptography_HAS_ONESHOT_EVP_DIGEST_SIGN_VERIFY = 0;
static const long Cryptography_HAS_RAW_KEY = 0;
static const long Cryptography_HAS_EVP_DIGESTFINAL_XOF = 0;
int (*EVP_DigestFinalXOF)(EVP_MD_CTX *, unsigned char *, size_t) = NULL;
int (*EVP_DigestSign)(EVP_MD_CTX *, unsigned char *, size_t *,
                      const unsigned char *tbs, size_t) = NULL;
int (*EVP_DigestVerify)(EVP_MD_CTX *, const unsigned char *, size_t,
                        const unsigned char *, size_t) = NULL;
EVP_PKEY *(*EVP_PKEY_new_raw_private_key)(int, ENGINE *, const unsigned char *,
                                       size_t) = NULL;
EVP_PKEY *(*EVP_PKEY_new_raw_public_key)(int, ENGINE *, const unsigned char *,
                                      size_t) = NULL;
int (*EVP_PKEY_get_raw_private_key)(const EVP_PKEY *, unsigned char *,
                                    size_t *) = NULL;
int (*EVP_PKEY_get_raw_public_key)(const EVP_PKEY *, unsigned char *,
                                   size_t *) = NULL;
#else
static const long Cryptography_HAS_ONESHOT_EVP_DIGEST_SIGN_VERIFY = 1;
static const long Cryptography_HAS_RAW_KEY = 1;
static const long Cryptography_HAS_EVP_DIGESTFINAL_XOF = 1;
#endif

/* OpenSSL 1.1.0+ does this define for us, but if not present we'll do it */
#if !defined(EVP_CTRL_AEAD_SET_IVLEN)
# define EVP_CTRL_AEAD_SET_IVLEN EVP_CTRL_GCM_SET_IVLEN
#endif
#if !defined(EVP_CTRL_AEAD_GET_TAG)
# define EVP_CTRL_AEAD_GET_TAG EVP_CTRL_GCM_GET_TAG
#endif
#if !defined(EVP_CTRL_AEAD_SET_TAG)
# define EVP_CTRL_AEAD_SET_TAG EVP_CTRL_GCM_SET_TAG
#endif

/* This is tied to X25519 support so we reuse the Cryptography_HAS_X25519
   conditional to remove it. OpenSSL 1.1.0 didn't have this define, but
   1.1.1 will when it is released. We can remove this in the distant
   future when we drop 1.1.0 support. */
#ifndef EVP_PKEY_X25519
#define EVP_PKEY_X25519 NID_X25519
#endif

/* This is tied to X448 support so we reuse the Cryptography_HAS_X448
   conditional to remove it. OpenSSL 1.1.1 adds this define.  We can remove
   this in the distant future when we drop 1.1.0 support. */
#ifndef EVP_PKEY_X448
#define EVP_PKEY_X448 NID_X448
#endif

/* This is tied to ED25519 support so we reuse the Cryptography_HAS_ED25519
   conditional to remove it. */
#ifndef EVP_PKEY_ED25519
#define EVP_PKEY_ED25519 NID_ED25519
#endif

/* This is tied to ED448 support so we reuse the Cryptography_HAS_ED448
   conditional to remove it. */
#ifndef EVP_PKEY_ED448
#define EVP_PKEY_ED448 NID_ED448
#endif

/* This is tied to poly1305 support so we reuse the Cryptography_HAS_POLY1305
   conditional to remove it. */
#ifndef EVP_PKEY_POLY1305
#define EVP_PKEY_POLY1305 NID_poly1305
#endif
"""
