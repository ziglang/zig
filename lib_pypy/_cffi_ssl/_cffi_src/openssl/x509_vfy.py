# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/x509_vfy.h>

/*
 * This is part of a work-around for the difficulty cffi has in dealing with
 * `STACK_OF(foo)` as the name of a type.  We invent a new, simpler name that
 * will be an alias for this type and use the alias throughout.  This works
 * together with another opaque typedef for the same name in the TYPES section.
 * Note that the result is an opaque type.
 */
typedef STACK_OF(ASN1_OBJECT) Cryptography_STACK_OF_ASN1_OBJECT;
typedef STACK_OF(X509_OBJECT) Cryptography_STACK_OF_X509_OBJECT;
"""

TYPES = """
static const long Cryptography_HAS_102_VERIFICATION_ERROR_CODES;
static const long Cryptography_HAS_102_VERIFICATION_PARAMS;
static const long Cryptography_HAS_110_VERIFICATION_PARAMS;
static const long Cryptography_HAS_X509_V_FLAG_TRUSTED_FIRST;
static const long Cryptography_HAS_X509_V_FLAG_PARTIAL_CHAIN;
static const long Cryptography_HAS_X509_STORE_CTX_GET_ISSUER;

typedef ... Cryptography_STACK_OF_ASN1_OBJECT;
typedef ... Cryptography_STACK_OF_X509_OBJECT;

typedef ... X509_OBJECT;
typedef ... X509_STORE;
typedef ... X509_VERIFY_PARAM;
typedef ... X509_STORE_CTX;

typedef int (*X509_STORE_CTX_get_issuer_fn)(X509 **, X509_STORE_CTX *, X509 *);

/* While these are defined in the source as ints, they're tagged here
   as longs, just in case they ever grow to large, such as what we saw
   with OP_ALL. */

/* Verification error codes */
static const int X509_V_OK;
static const int X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT;
static const int X509_V_ERR_UNABLE_TO_GET_CRL;
static const int X509_V_ERR_UNABLE_TO_DECRYPT_CERT_SIGNATURE;
static const int X509_V_ERR_UNABLE_TO_DECRYPT_CRL_SIGNATURE;
static const int X509_V_ERR_UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY;
static const int X509_V_ERR_CERT_SIGNATURE_FAILURE;
static const int X509_V_ERR_CRL_SIGNATURE_FAILURE;
static const int X509_V_ERR_CERT_NOT_YET_VALID;
static const int X509_V_ERR_CERT_HAS_EXPIRED;
static const int X509_V_ERR_CRL_NOT_YET_VALID;
static const int X509_V_ERR_CRL_HAS_EXPIRED;
static const int X509_V_ERR_ERROR_IN_CERT_NOT_BEFORE_FIELD;
static const int X509_V_ERR_ERROR_IN_CERT_NOT_AFTER_FIELD;
static const int X509_V_ERR_ERROR_IN_CRL_LAST_UPDATE_FIELD;
static const int X509_V_ERR_ERROR_IN_CRL_NEXT_UPDATE_FIELD;
static const int X509_V_ERR_OUT_OF_MEM;
static const int X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT;
static const int X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN;
static const int X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY;
static const int X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE;
static const int X509_V_ERR_CERT_CHAIN_TOO_LONG;
static const int X509_V_ERR_CERT_REVOKED;
static const int X509_V_ERR_INVALID_CA;
static const int X509_V_ERR_PATH_LENGTH_EXCEEDED;
static const int X509_V_ERR_INVALID_PURPOSE;
static const int X509_V_ERR_CERT_UNTRUSTED;
static const int X509_V_ERR_CERT_REJECTED;
static const int X509_V_ERR_SUBJECT_ISSUER_MISMATCH;
static const int X509_V_ERR_AKID_SKID_MISMATCH;
static const int X509_V_ERR_AKID_ISSUER_SERIAL_MISMATCH;
static const int X509_V_ERR_KEYUSAGE_NO_CERTSIGN;
static const int X509_V_ERR_UNABLE_TO_GET_CRL_ISSUER;
static const int X509_V_ERR_UNHANDLED_CRITICAL_EXTENSION;
static const int X509_V_ERR_KEYUSAGE_NO_CRL_SIGN;
static const int X509_V_ERR_UNHANDLED_CRITICAL_CRL_EXTENSION;
static const int X509_V_ERR_INVALID_NON_CA;
static const int X509_V_ERR_PROXY_PATH_LENGTH_EXCEEDED;
static const int X509_V_ERR_KEYUSAGE_NO_DIGITAL_SIGNATURE;
static const int X509_V_ERR_PROXY_CERTIFICATES_NOT_ALLOWED;
static const int X509_V_ERR_INVALID_EXTENSION;
static const int X509_V_ERR_INVALID_POLICY_EXTENSION;
static const int X509_V_ERR_NO_EXPLICIT_POLICY;
static const int X509_V_ERR_DIFFERENT_CRL_SCOPE;
static const int X509_V_ERR_UNSUPPORTED_EXTENSION_FEATURE;
static const int X509_V_ERR_UNNESTED_RESOURCE;
static const int X509_V_ERR_PERMITTED_VIOLATION;
static const int X509_V_ERR_EXCLUDED_VIOLATION;
static const int X509_V_ERR_SUBTREE_MINMAX;
static const int X509_V_ERR_UNSUPPORTED_CONSTRAINT_TYPE;
static const int X509_V_ERR_UNSUPPORTED_CONSTRAINT_SYNTAX;
static const int X509_V_ERR_UNSUPPORTED_NAME_SYNTAX;
static const int X509_V_ERR_CRL_PATH_VALIDATION_ERROR;
static const int X509_V_ERR_SUITE_B_INVALID_VERSION;
static const int X509_V_ERR_SUITE_B_INVALID_ALGORITHM;
static const int X509_V_ERR_SUITE_B_INVALID_CURVE;
static const int X509_V_ERR_SUITE_B_INVALID_SIGNATURE_ALGORITHM;
static const int X509_V_ERR_SUITE_B_LOS_NOT_ALLOWED;
static const int X509_V_ERR_SUITE_B_CANNOT_SIGN_P_384_WITH_P_256;
static const int X509_V_ERR_HOSTNAME_MISMATCH;
static const int X509_V_ERR_EMAIL_MISMATCH;
static const int X509_V_ERR_IP_ADDRESS_MISMATCH;
static const int X509_V_ERR_APPLICATION_VERIFICATION;

/* Verification parameters */
static const long X509_V_FLAG_CB_ISSUER_CHECK;
static const long X509_V_FLAG_USE_CHECK_TIME;
static const long X509_V_FLAG_CRL_CHECK;
static const long X509_V_FLAG_CRL_CHECK_ALL;
static const long X509_V_FLAG_IGNORE_CRITICAL;
static const long X509_V_FLAG_X509_STRICT;
static const long X509_V_FLAG_ALLOW_PROXY_CERTS;
static const long X509_V_FLAG_POLICY_CHECK;
static const long X509_V_FLAG_EXPLICIT_POLICY;
static const long X509_V_FLAG_INHIBIT_ANY;
static const long X509_V_FLAG_INHIBIT_MAP;
static const long X509_V_FLAG_NOTIFY_POLICY;
static const long X509_V_FLAG_EXTENDED_CRL_SUPPORT;
static const long X509_V_FLAG_USE_DELTAS;
static const long X509_V_FLAG_CHECK_SS_SIGNATURE;
static const long X509_V_FLAG_TRUSTED_FIRST;
static const long X509_V_FLAG_SUITEB_128_LOS_ONLY;
static const long X509_V_FLAG_SUITEB_192_LOS;
static const long X509_V_FLAG_SUITEB_128_LOS;
static const long X509_V_FLAG_PARTIAL_CHAIN;

static const long X509_LU_X509;
static const long X509_LU_CRL;

static const long X509_CHECK_FLAG_ALWAYS_CHECK_SUBJECT;
static const long X509_CHECK_FLAG_NO_WILDCARDS;
static const long X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS;
static const long X509_CHECK_FLAG_MULTI_LABEL_WILDCARDS;
static const long X509_CHECK_FLAG_SINGLE_LABEL_SUBDOMAINS;
static const long X509_CHECK_FLAG_NEVER_CHECK_SUBJECT;
"""

FUNCTIONS = """
int X509_verify_cert(X509_STORE_CTX *);

/* X509_STORE */
X509_STORE *X509_STORE_new(void);
int X509_STORE_add_cert(X509_STORE *, X509 *);
int X509_STORE_add_crl(X509_STORE *, X509_CRL *);
int X509_STORE_load_locations(X509_STORE *, const char *, const char *);
int X509_STORE_set1_param(X509_STORE *, X509_VERIFY_PARAM *);
int X509_STORE_set_default_paths(X509_STORE *);
int X509_STORE_set_flags(X509_STORE *, unsigned long);
void X509_STORE_free(X509_STORE *);

/* X509_STORE_CTX */
X509_STORE_CTX *X509_STORE_CTX_new(void);
void X509_STORE_CTX_cleanup(X509_STORE_CTX *);
void X509_STORE_CTX_free(X509_STORE_CTX *);
int X509_STORE_CTX_init(X509_STORE_CTX *, X509_STORE *, X509 *,
                        Cryptography_STACK_OF_X509 *);
void X509_STORE_CTX_trusted_stack(X509_STORE_CTX *,
                                  Cryptography_STACK_OF_X509 *);
void X509_STORE_CTX_set_cert(X509_STORE_CTX *, X509 *);
void X509_STORE_CTX_set_chain(X509_STORE_CTX *,Cryptography_STACK_OF_X509 *);
X509_VERIFY_PARAM *X509_STORE_CTX_get0_param(X509_STORE_CTX *);
void X509_STORE_CTX_set0_param(X509_STORE_CTX *, X509_VERIFY_PARAM *);
int X509_STORE_CTX_set_default(X509_STORE_CTX *, const char *);
void X509_STORE_CTX_set_verify_cb(X509_STORE_CTX *,
                                  int (*)(int, X509_STORE_CTX *));
Cryptography_STACK_OF_X509 *X509_STORE_CTX_get_chain(X509_STORE_CTX *);
Cryptography_STACK_OF_X509 *X509_STORE_CTX_get1_chain(X509_STORE_CTX *);
int X509_STORE_CTX_get_error(X509_STORE_CTX *);
void X509_STORE_CTX_set_error(X509_STORE_CTX *, int);
int X509_STORE_CTX_get_error_depth(X509_STORE_CTX *);
X509 *X509_STORE_CTX_get_current_cert(X509_STORE_CTX *);
int X509_STORE_CTX_set_ex_data(X509_STORE_CTX *, int, void *);
void *X509_STORE_CTX_get_ex_data(X509_STORE_CTX *, int);
int X509_STORE_CTX_get1_issuer(X509 **, X509_STORE_CTX *, X509 *);

/* X509_VERIFY_PARAM */
X509_VERIFY_PARAM *X509_VERIFY_PARAM_new(void);
int X509_VERIFY_PARAM_set_flags(X509_VERIFY_PARAM *, unsigned long);
int X509_VERIFY_PARAM_clear_flags(X509_VERIFY_PARAM *, unsigned long);
unsigned long X509_VERIFY_PARAM_get_flags(X509_VERIFY_PARAM *);
int X509_VERIFY_PARAM_set_purpose(X509_VERIFY_PARAM *, int);
int X509_VERIFY_PARAM_set_trust(X509_VERIFY_PARAM *, int);
void X509_VERIFY_PARAM_set_time(X509_VERIFY_PARAM *, time_t);
int X509_VERIFY_PARAM_add0_policy(X509_VERIFY_PARAM *, ASN1_OBJECT *);
int X509_VERIFY_PARAM_set1_policies(X509_VERIFY_PARAM *,
                                    Cryptography_STACK_OF_ASN1_OBJECT *);
void X509_VERIFY_PARAM_set_depth(X509_VERIFY_PARAM *, int);
int X509_VERIFY_PARAM_get_depth(const X509_VERIFY_PARAM *);
void X509_VERIFY_PARAM_free(X509_VERIFY_PARAM *);
/* this CRYPTO_EX_DATA function became a macro in 1.1.0 */
int X509_STORE_CTX_get_ex_new_index(long, void *, CRYPTO_EX_new *,
                                    CRYPTO_EX_dup *, CRYPTO_EX_free *);

/* X509_STORE_CTX */
void X509_STORE_CTX_set0_crls(X509_STORE_CTX *,
                              Cryptography_STACK_OF_X509_CRL *);

/* X509_VERIFY_PARAM */
int X509_VERIFY_PARAM_set1_host(X509_VERIFY_PARAM *, const char *,
                                size_t);
void X509_VERIFY_PARAM_set_hostflags(X509_VERIFY_PARAM *, unsigned int);
int X509_VERIFY_PARAM_set1_email(X509_VERIFY_PARAM *, const char *,
                                 size_t);
int X509_VERIFY_PARAM_set1_ip(X509_VERIFY_PARAM *, const unsigned char *,
                              size_t);
int X509_VERIFY_PARAM_set1_ip_asc(X509_VERIFY_PARAM *, const char *);

int sk_X509_OBJECT_num(Cryptography_STACK_OF_X509_OBJECT *);
X509_OBJECT *sk_X509_OBJECT_value(Cryptography_STACK_OF_X509_OBJECT *, int);
X509_VERIFY_PARAM *X509_STORE_get0_param(X509_STORE *);
Cryptography_STACK_OF_X509_OBJECT *X509_STORE_get0_objects(X509_STORE *);
X509 *X509_OBJECT_get0_X509(X509_OBJECT *);
int X509_OBJECT_get_type(const X509_OBJECT *);

/* added in 1.1.0 */
X509 *X509_STORE_CTX_get0_cert(X509_STORE_CTX *);
X509_STORE_CTX_get_issuer_fn X509_STORE_get_get_issuer(X509_STORE *);
void X509_STORE_set_get_issuer(X509_STORE *, X509_STORE_CTX_get_issuer_fn);
"""

CUSTOMIZATIONS = """
/* OpenSSL 1.0.2+ verification parameters and error codes */
#if CRYPTOGRAPHY_OPENSSL_102_OR_GREATER
static const long Cryptography_HAS_102_VERIFICATION_ERROR_CODES = 1;
static const long Cryptography_HAS_102_VERIFICATION_PARAMS = 1;
#else
static const long Cryptography_HAS_102_VERIFICATION_ERROR_CODES = 0;
static const long Cryptography_HAS_102_VERIFICATION_PARAMS = 0;

static const long X509_V_ERR_SUITE_B_INVALID_VERSION = 0;
static const long X509_V_ERR_SUITE_B_INVALID_ALGORITHM = 0;
static const long X509_V_ERR_SUITE_B_INVALID_CURVE = 0;
static const long X509_V_ERR_SUITE_B_INVALID_SIGNATURE_ALGORITHM = 0;
static const long X509_V_ERR_SUITE_B_LOS_NOT_ALLOWED = 0;
static const long X509_V_ERR_SUITE_B_CANNOT_SIGN_P_384_WITH_P_256 = 0;
/* These 3 defines are unavailable in LibreSSL 2.5.x, but may be added
   in the future... */
#ifndef X509_V_ERR_HOSTNAME_MISMATCH
static const long X509_V_ERR_HOSTNAME_MISMATCH = 0;
#endif
#ifndef X509_V_ERR_EMAIL_MISMATCH
static const long X509_V_ERR_EMAIL_MISMATCH = 0;
#endif
#ifndef X509_V_ERR_IP_ADDRESS_MISMATCH
static const long X509_V_ERR_IP_ADDRESS_MISMATCH = 0;
#endif
#ifndef X509_CHECK_FLAG_ALWAYS_CHECK_SUBJECT
static const long X509_CHECK_FLAG_ALWAYS_CHECK_SUBJECT = 0;
#endif
#ifndef X509_CHECK_FLAG_NO_WILDCARDS
static const long X509_CHECK_FLAG_NO_WILDCARDS = 0;
#endif
#ifndef X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS
static const long X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS = 0;
#endif
#ifndef X509_CHECK_FLAG_MULTI_LABEL_WILDCARDS
static const long X509_CHECK_FLAG_MULTI_LABEL_WILDCARDS = 0;
#endif
#ifndef X509_CHECK_FLAG_SINGLE_LABEL_SUBDOMAINS
static const long X509_CHECK_FLAG_SINGLE_LABEL_SUBDOMAINS = 0;
#endif

/* X509_V_FLAG_TRUSTED_FIRST is also new in 1.0.2+, but it is added separately
   below because it shows up in some earlier 3rd party OpenSSL packages. */
static const long X509_V_FLAG_SUITEB_128_LOS_ONLY = 0;
static const long X509_V_FLAG_SUITEB_192_LOS = 0;
static const long X509_V_FLAG_SUITEB_128_LOS = 0;

#if !CRYPTOGRAPHY_LIBRESSL_27_OR_GREATER
int (*X509_VERIFY_PARAM_set1_host)(X509_VERIFY_PARAM *, const char *,
                                   size_t) = NULL;
int (*X509_VERIFY_PARAM_set1_email)(X509_VERIFY_PARAM *, const char *,
                                    size_t) = NULL;
int (*X509_VERIFY_PARAM_set1_ip)(X509_VERIFY_PARAM *, const unsigned char *,
                                 size_t) = NULL;
int (*X509_VERIFY_PARAM_set1_ip_asc)(X509_VERIFY_PARAM *, const char *) = NULL;
void (*X509_VERIFY_PARAM_set_hostflags)(X509_VERIFY_PARAM *,
                                        unsigned int) = NULL;
#endif
#endif

#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110 || CRYPTOGRAPHY_IS_LIBRESSL
static const long Cryptography_HAS_110_VERIFICATION_PARAMS = 0;
#ifndef X509_CHECK_FLAG_NEVER_CHECK_SUBJECT
static const long X509_CHECK_FLAG_NEVER_CHECK_SUBJECT = 0;
#endif
#else
static const long Cryptography_HAS_110_VERIFICATION_PARAMS = 1;
#endif

/* OpenSSL 1.0.2+ or Solaris's backport */
#ifdef X509_V_FLAG_PARTIAL_CHAIN
static const long Cryptography_HAS_X509_V_FLAG_PARTIAL_CHAIN = 1;
#else
static const long Cryptography_HAS_X509_V_FLAG_PARTIAL_CHAIN = 0;
static const long X509_V_FLAG_PARTIAL_CHAIN = 0;
#endif

/* OpenSSL 1.0.2+, *or* Fedora 20's flavor of OpenSSL 1.0.1e... */
#ifdef X509_V_FLAG_TRUSTED_FIRST
static const long Cryptography_HAS_X509_V_FLAG_TRUSTED_FIRST = 1;
#else
static const long Cryptography_HAS_X509_V_FLAG_TRUSTED_FIRST = 0;
static const long X509_V_FLAG_TRUSTED_FIRST = 0;
#endif

#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110 && !CRYPTOGRAPHY_LIBRESSL_27_OR_GREATER
Cryptography_STACK_OF_X509_OBJECT *X509_STORE_get0_objects(X509_STORE *ctx) {
    return ctx->objs;
}
X509_VERIFY_PARAM *X509_STORE_get0_param(X509_STORE *store) {
    return store->param;
}
int X509_OBJECT_get_type(const X509_OBJECT *x) {
    return x->type;
}

/* from x509/x509_vfy.c */
X509 *X509_STORE_CTX_get0_cert(X509_STORE_CTX *ctx)
{
    return ctx->cert;
}

X509 *X509_OBJECT_get0_X509(X509_OBJECT *x) {
    return x->data.x509;
}
#endif

#if CRYPTOGRAPHY_OPENSSL_LESS_THAN_110
static const long Cryptography_HAS_X509_STORE_CTX_GET_ISSUER = 0;
typedef void *X509_STORE_CTX_get_issuer_fn;
X509_STORE_CTX_get_issuer_fn (*X509_STORE_get_get_issuer)(X509_STORE *) = NULL;
void (*X509_STORE_set_get_issuer)(X509_STORE *,
                                  X509_STORE_CTX_get_issuer_fn) = NULL;
#else
static const long Cryptography_HAS_X509_STORE_CTX_GET_ISSUER = 1;
#endif
"""
