# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/ssl.h>

/*
 * This is part of a work-around for the difficulty cffi has in dealing with
 * `STACK_OF(foo)` as the name of a type.  We invent a new, simpler name that
 * will be an alias for this type and use the alias throughout.  This works
 * together with another opaque typedef for the same name in the TYPES section.
 * Note that the result is an opaque type.
 */
typedef STACK_OF(X509) Cryptography_STACK_OF_X509;
typedef STACK_OF(X509_CRL) Cryptography_STACK_OF_X509_CRL;
typedef STACK_OF(X509_REVOKED) Cryptography_STACK_OF_X509_REVOKED;
"""

TYPES = """
typedef ... Cryptography_STACK_OF_X509;
typedef ... Cryptography_STACK_OF_X509_CRL;
typedef ... Cryptography_STACK_OF_X509_REVOKED;

typedef struct {
    ASN1_OBJECT *algorithm;
    ...;
} X509_ALGOR;

typedef ... X509_EXTENSION;
typedef ... X509_EXTENSIONS;
typedef ... X509_REQ;
typedef ... X509_REVOKED;
typedef ... X509_CRL;
typedef ... X509;

typedef ... NETSCAPE_SPKI;

typedef ... PKCS8_PRIV_KEY_INFO;

typedef void (*sk_X509_EXTENSION_freefunc)(X509_EXTENSION *);
"""

FUNCTIONS = """
X509 *X509_new(void);
void X509_free(X509 *);
X509 *X509_dup(X509 *);
int X509_cmp(const X509 *, const X509 *);
int X509_up_ref(X509 *);

int X509_print_ex(BIO *, X509 *, unsigned long, unsigned long);

int X509_set_version(X509 *, long);

EVP_PKEY *X509_get_pubkey(X509 *);
int X509_set_pubkey(X509 *, EVP_PKEY *);

unsigned char *X509_alias_get0(X509 *, int *);
int X509_sign(X509 *, EVP_PKEY *, const EVP_MD *);

int X509_digest(const X509 *, const EVP_MD *, unsigned char *, unsigned int *);

ASN1_TIME *X509_gmtime_adj(ASN1_TIME *, long);

unsigned long X509_subject_name_hash(X509 *);

int X509_set_subject_name(X509 *, X509_NAME *);

int X509_set_issuer_name(X509 *, X509_NAME *);

int X509_add_ext(X509 *, X509_EXTENSION *, int);
X509_EXTENSION *X509_EXTENSION_dup(X509_EXTENSION *);

ASN1_OBJECT *X509_EXTENSION_get_object(X509_EXTENSION *);
void X509_EXTENSION_free(X509_EXTENSION *);

int i2d_X509(X509 *, unsigned char **);

int X509_REQ_set_version(X509_REQ *, long);
X509_REQ *X509_REQ_new(void);
void X509_REQ_free(X509_REQ *);
int X509_REQ_set_pubkey(X509_REQ *, EVP_PKEY *);
int X509_REQ_set_subject_name(X509_REQ *, X509_NAME *);
int X509_REQ_sign(X509_REQ *, EVP_PKEY *, const EVP_MD *);
int X509_REQ_verify(X509_REQ *, EVP_PKEY *);
EVP_PKEY *X509_REQ_get_pubkey(X509_REQ *);
int X509_REQ_print_ex(BIO *, X509_REQ *, unsigned long, unsigned long);
int X509_REQ_add_extensions(X509_REQ *, X509_EXTENSIONS *);
X509_EXTENSIONS *X509_REQ_get_extensions(X509_REQ *);

int X509V3_EXT_print(BIO *, X509_EXTENSION *, unsigned long, int);
ASN1_OCTET_STRING *X509_EXTENSION_get_data(X509_EXTENSION *);

X509_REVOKED *X509_REVOKED_new(void);
void X509_REVOKED_free(X509_REVOKED *);

int X509_REVOKED_set_serialNumber(X509_REVOKED *, ASN1_INTEGER *);

int X509_REVOKED_add_ext(X509_REVOKED *, X509_EXTENSION*, int);
int X509_REVOKED_add1_ext_i2d(X509_REVOKED *, int, void *, int, unsigned long);
X509_EXTENSION *X509_REVOKED_delete_ext(X509_REVOKED *, int);

int X509_REVOKED_set_revocationDate(X509_REVOKED *, ASN1_TIME *);

X509_CRL *X509_CRL_new(void);
X509_CRL *X509_CRL_dup(X509_CRL *);
X509_CRL *d2i_X509_CRL_bio(BIO *, X509_CRL **);
int X509_CRL_add0_revoked(X509_CRL *, X509_REVOKED *);
int X509_CRL_add_ext(X509_CRL *, X509_EXTENSION *, int);
int X509_CRL_cmp(const X509_CRL *, const X509_CRL *);
int X509_CRL_print(BIO *, X509_CRL *);
int X509_CRL_set_issuer_name(X509_CRL *, X509_NAME *);
int X509_CRL_set_version(X509_CRL *, long);
int X509_CRL_sign(X509_CRL *, EVP_PKEY *, const EVP_MD *);
int X509_CRL_sort(X509_CRL *);
int X509_CRL_verify(X509_CRL *, EVP_PKEY *);
int i2d_X509_CRL_bio(BIO *, X509_CRL *);
void X509_CRL_free(X509_CRL *);

int NETSCAPE_SPKI_verify(NETSCAPE_SPKI *, EVP_PKEY *);
int NETSCAPE_SPKI_sign(NETSCAPE_SPKI *, EVP_PKEY *, const EVP_MD *);
char *NETSCAPE_SPKI_b64_encode(NETSCAPE_SPKI *);
NETSCAPE_SPKI *NETSCAPE_SPKI_b64_decode(const char *, int);
EVP_PKEY *NETSCAPE_SPKI_get_pubkey(NETSCAPE_SPKI *);
int NETSCAPE_SPKI_set_pubkey(NETSCAPE_SPKI *, EVP_PKEY *);
NETSCAPE_SPKI *NETSCAPE_SPKI_new(void);
void NETSCAPE_SPKI_free(NETSCAPE_SPKI *);

/*  ASN1 serialization */
int i2d_X509_bio(BIO *, X509 *);
X509 *d2i_X509_bio(BIO *, X509 **);

int i2d_X509_REQ_bio(BIO *, X509_REQ *);
X509_REQ *d2i_X509_REQ_bio(BIO *, X509_REQ **);

int i2d_PrivateKey_bio(BIO *, EVP_PKEY *);
EVP_PKEY *d2i_PrivateKey_bio(BIO *, EVP_PKEY **);
int i2d_PUBKEY_bio(BIO *, EVP_PKEY *);
EVP_PKEY *d2i_PUBKEY_bio(BIO *, EVP_PKEY **);

ASN1_INTEGER *X509_get_serialNumber(X509 *);
int X509_set_serialNumber(X509 *, ASN1_INTEGER *);

const char *X509_verify_cert_error_string(long);

const char *X509_get_default_cert_dir(void);
const char *X509_get_default_cert_file(void);
const char *X509_get_default_cert_dir_env(void);
const char *X509_get_default_cert_file_env(void);

int i2d_RSAPrivateKey_bio(BIO *, RSA *);
RSA *d2i_RSAPublicKey_bio(BIO *, RSA **);
int i2d_RSAPublicKey_bio(BIO *, RSA *);
int i2d_DSAPrivateKey_bio(BIO *, DSA *);

/* These became const X509 in 1.1.0 */
int X509_get_ext_count(X509 *);
X509_EXTENSION *X509_get_ext(X509 *, int);
int X509_get_ext_by_NID(X509 *, int, int);
X509_NAME *X509_get_subject_name(X509 *);
X509_NAME *X509_get_issuer_name(X509 *);

/* This became const ASN1_OBJECT * in 1.1.0 */
X509_EXTENSION *X509_EXTENSION_create_by_OBJ(X509_EXTENSION **,
                                             ASN1_OBJECT *, int,
                                             ASN1_OCTET_STRING *);


/* This became const X509_EXTENSION * in 1.1.0 */
int X509_EXTENSION_get_critical(X509_EXTENSION *);

/* This became const X509_REVOKED * in 1.1.0 */
int X509_REVOKED_get_ext_count(X509_REVOKED *);
X509_EXTENSION *X509_REVOKED_get_ext(X509_REVOKED *, int);

/* This became const X509_CRL * in 1.1.0 */
X509_EXTENSION *X509_CRL_get_ext(X509_CRL *, int);
int X509_CRL_get_ext_count(X509_CRL *);

int X509_CRL_get0_by_serial(X509_CRL *, X509_REVOKED **, ASN1_INTEGER *);

X509_REVOKED *Cryptography_X509_REVOKED_dup(X509_REVOKED *);

/* new in 1.0.2 */
int i2d_re_X509_tbs(X509 *, unsigned char **);
int X509_get_signature_nid(const X509 *);

const X509_ALGOR *X509_get0_tbs_sigalg(const X509 *);

void X509_get0_signature(const ASN1_BIT_STRING **,
                         const X509_ALGOR **, const X509 *);

long X509_get_version(X509 *);

ASN1_TIME *X509_get_notBefore(X509 *);
ASN1_TIME *X509_get_notAfter(X509 *);

long X509_REQ_get_version(X509_REQ *);
X509_NAME *X509_REQ_get_subject_name(X509_REQ *);

Cryptography_STACK_OF_X509 *sk_X509_new_null(void);
void sk_X509_free(Cryptography_STACK_OF_X509 *);
int sk_X509_num(Cryptography_STACK_OF_X509 *);
int sk_X509_push(Cryptography_STACK_OF_X509 *, X509 *);
X509 *sk_X509_value(Cryptography_STACK_OF_X509 *, int);

X509_EXTENSIONS *sk_X509_EXTENSION_new_null(void);
int sk_X509_EXTENSION_num(X509_EXTENSIONS *);
X509_EXTENSION *sk_X509_EXTENSION_value(X509_EXTENSIONS *, int);
int sk_X509_EXTENSION_push(X509_EXTENSIONS *, X509_EXTENSION *);
int sk_X509_EXTENSION_insert(X509_EXTENSIONS *, X509_EXTENSION *, int);
X509_EXTENSION *sk_X509_EXTENSION_delete(X509_EXTENSIONS *, int);
void sk_X509_EXTENSION_free(X509_EXTENSIONS *);
void sk_X509_EXTENSION_pop_free(X509_EXTENSIONS *, sk_X509_EXTENSION_freefunc);

int sk_X509_REVOKED_num(Cryptography_STACK_OF_X509_REVOKED *);
X509_REVOKED *sk_X509_REVOKED_value(Cryptography_STACK_OF_X509_REVOKED *, int);

Cryptography_STACK_OF_X509_CRL *sk_X509_CRL_new_null(void);
void sk_X509_CRL_free(Cryptography_STACK_OF_X509_CRL *);
int sk_X509_CRL_num(Cryptography_STACK_OF_X509_CRL *);
int sk_X509_CRL_push(Cryptography_STACK_OF_X509_CRL *, X509_CRL *);
X509_CRL *sk_X509_CRL_value(Cryptography_STACK_OF_X509_CRL *, int);

long X509_CRL_get_version(X509_CRL *);
ASN1_TIME *X509_CRL_get_lastUpdate(X509_CRL *);
ASN1_TIME *X509_CRL_get_nextUpdate(X509_CRL *);
X509_NAME *X509_CRL_get_issuer(X509_CRL *);
Cryptography_STACK_OF_X509_REVOKED *X509_CRL_get_REVOKED(X509_CRL *);

/* These aren't macros these arguments are all const X on openssl > 1.0.x */
int X509_CRL_set_lastUpdate(X509_CRL *, ASN1_TIME *);
int X509_CRL_set_nextUpdate(X509_CRL *, ASN1_TIME *);
int X509_set_notBefore(X509 *, ASN1_TIME *);
int X509_set_notAfter(X509 *, ASN1_TIME *);

EC_KEY *d2i_EC_PUBKEY_bio(BIO *, EC_KEY **);
int i2d_EC_PUBKEY_bio(BIO *, EC_KEY *);
EC_KEY *d2i_ECPrivateKey_bio(BIO *, EC_KEY **);
int i2d_ECPrivateKey_bio(BIO *, EC_KEY *);

// declared in safestack
int sk_ASN1_OBJECT_num(Cryptography_STACK_OF_ASN1_OBJECT *);
ASN1_OBJECT *sk_ASN1_OBJECT_value(Cryptography_STACK_OF_ASN1_OBJECT *, int);
void sk_ASN1_OBJECT_free(Cryptography_STACK_OF_ASN1_OBJECT *);
Cryptography_STACK_OF_ASN1_OBJECT *sk_ASN1_OBJECT_new_null(void);
int sk_ASN1_OBJECT_push(Cryptography_STACK_OF_ASN1_OBJECT *, ASN1_OBJECT *);

/* these functions were added in 1.1.0 */
const ASN1_INTEGER *X509_REVOKED_get0_serialNumber(const X509_REVOKED *);
const ASN1_TIME *X509_REVOKED_get0_revocationDate(const X509_REVOKED *);
void X509_CRL_get0_signature(const X509_CRL *, const ASN1_BIT_STRING **,
                             const X509_ALGOR **);
int i2d_re_X509_REQ_tbs(X509_REQ *, unsigned char **);
int i2d_re_X509_CRL_tbs(X509_CRL *, unsigned char **);
void X509_REQ_get0_signature(const X509_REQ *, const ASN1_BIT_STRING **,
                             const X509_ALGOR **);
"""

CUSTOMIZATIONS = """
/* Added in 1.0.2 beta but we need it in all versions now due to the great
   opaquing. */
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_102 && !CRYPTOGRAPHY_LIBRESSL_27_OR_GREATER
/* from x509/x_x509.c version 1.0.2 */
void X509_get0_signature(const ASN1_BIT_STRING **psig,
                         const X509_ALGOR **palg, const X509 *x)
{
    if (psig)
        *psig = x->signature;
    if (palg)
        *palg = x->sig_alg;
}

int X509_get_signature_nid(const X509 *x)
{
    return OBJ_obj2nid(x->sig_alg->algorithm);
}

#endif

/* Added in 1.0.2 but we need it in all versions now due to the great
   opaquing. */
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_102
/* from x509/x_x509.c */
int i2d_re_X509_tbs(X509 *x, unsigned char **pp)
{
    /* in 1.0.2+ this function also sets x->cert_info->enc.modified = 1
       but older OpenSSLs don't have the enc ASN1_ENCODING member in the
       X509 struct.  Setting modified to 1 marks the encoding
       (x->cert_info->enc.enc) as invalid, but since the entire struct isn't
       present we don't care. */
    return i2d_X509_CINF(x->cert_info, pp);
}
#endif

/* X509_REVOKED_dup only exists on 1.0.2+. It is implemented using
   IMPLEMENT_ASN1_DUP_FUNCTION. The below is the equivalent so we have
   it available on all OpenSSLs. */
X509_REVOKED *Cryptography_X509_REVOKED_dup(X509_REVOKED *rev) {
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_102
    return ASN1_item_dup(ASN1_ITEM_rptr(X509_REVOKED), rev);
#else
    return X509_REVOKED_dup(rev);
#endif
}

/* Added in 1.1.0 but we need it in all versions now due to the great
   opaquing. */
#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110
int i2d_re_X509_REQ_tbs(X509_REQ *req, unsigned char **pp)
{
    req->req_info->enc.modified = 1;
    return i2d_X509_REQ_INFO(req->req_info, pp);
}
int i2d_re_X509_CRL_tbs(X509_CRL *crl, unsigned char **pp) {
    crl->crl->enc.modified = 1;
    return i2d_X509_CRL_INFO(crl->crl, pp);
}

#if !CRYPTOGRAPHY_LIBRESSL_27_OR_GREATER
int X509_up_ref(X509 *x) {
   return CRYPTO_add(&x->references, 1, CRYPTO_LOCK_X509);
}

const X509_ALGOR *X509_get0_tbs_sigalg(const X509 *x)
{
    return x->cert_info->signature;
}

/* from x509/x509_req.c */
void X509_REQ_get0_signature(const X509_REQ *req, const ASN1_BIT_STRING **psig,
                             const X509_ALGOR **palg)
{
    if (psig != NULL)
        *psig = req->signature;
    if (palg != NULL)
        *palg = req->sig_alg;
}
void X509_CRL_get0_signature(const X509_CRL *crl, const ASN1_BIT_STRING **psig,
                             const X509_ALGOR **palg)
{
    if (psig != NULL)
        *psig = crl->signature;
    if (palg != NULL)
        *palg = crl->sig_alg;
}
const ASN1_TIME *X509_REVOKED_get0_revocationDate(const X509_REVOKED *x)
{
    return x->revocationDate;
}
const ASN1_INTEGER *X509_REVOKED_get0_serialNumber(const X509_REVOKED *x)
{
    return x->serialNumber;
}
#endif
#endif
"""
