# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/err.h>
"""

TYPES = """
static const int Cryptography_HAS_EC_CODES;
static const int Cryptography_HAS_RSA_R_PKCS_DECODING_ERROR;
static const int Cryptography_HAS_EVP_R_MEMORY_LIMIT_EXCEEDED;

static const int ERR_LIB_DH;
static const int ERR_LIB_EVP;
static const int ERR_LIB_EC;
static const int ERR_LIB_PEM;
static const int ERR_LIB_ASN1;
static const int ERR_LIB_ASYNC;
static const int ERR_LIB_BIO;
static const int ERR_LIB_BN;
static const int ERR_LIB_BUF;
static const int ERR_LIB_CMP;
static const int ERR_LIB_CMS;
static const int ERR_LIB_COMP;
static const int ERR_LIB_CONF;
static const int ERR_LIB_CRMF;
static const int ERR_LIB_CRYPTO;
static const int ERR_LIB_CT;
static const int ERR_LIB_DH;
static const int ERR_LIB_DSA;
static const int ERR_LIB_DSO;
static const int ERR_LIB_EC;
static const int ERR_LIB_ECDH;
static const int ERR_LIB_ECDSA;
static const int ERR_LIB_ENGINE;
static const int ERR_LIB_ESS;
static const int ERR_LIB_EVP;
static const int ERR_LIB_FIPS;
static const int ERR_LIB_HMAC;
static const int ERR_LIB_HTTP;
static const int ERR_LIB_KDF;
static const int ERR_LIB_MASK;
static const int ERR_LIB_NONE;
static const int ERR_LIB_OBJ;
static const int ERR_LIB_OCSP;
static const int ERR_LIB_OFFSET;
static const int ERR_LIB_OSSL_DECODER;
static const int ERR_LIB_OSSL_ENCODER;
static const int ERR_LIB_OSSL_STORE;
static const int ERR_LIB_PEM;
static const int ERR_LIB_PKCS12;
static const int ERR_LIB_PKCS7;
static const int ERR_LIB_PROP;
static const int ERR_LIB_PROV;
static const int ERR_LIB_RAND;
static const int ERR_LIB_RSA;
static const int ERR_LIB_SM2;
static const int ERR_LIB_SSL;
static const int ERR_LIB_SYS;
static const int ERR_LIB_TS;
static const int ERR_LIB_UI;
static const int ERR_LIB_USER;
static const int ERR_LIB_X509;
static const int ERR_LIB_X509V3;

static const int ERR_R_MALLOC_FAILURE;
static const int EVP_R_MEMORY_LIMIT_EXCEEDED;

static const int ASN1_R_BOOLEAN_IS_WRONG_LENGTH;
static const int ASN1_R_BUFFER_TOO_SMALL;
static const int ASN1_R_CIPHER_HAS_NO_OBJECT_IDENTIFIER;
static const int ASN1_R_DATA_IS_WRONG;
static const int ASN1_R_DECODE_ERROR;
static const int ASN1_R_DEPTH_EXCEEDED;
static const int ASN1_R_ENCODE_ERROR;
static const int ASN1_R_ERROR_GETTING_TIME;
static const int ASN1_R_ERROR_LOADING_SECTION;
static const int ASN1_R_MSTRING_WRONG_TAG;
static const int ASN1_R_NESTED_ASN1_STRING;
static const int ASN1_R_NO_MATCHING_CHOICE_TYPE;
static const int ASN1_R_UNKNOWN_MESSAGE_DIGEST_ALGORITHM;
static const int ASN1_R_UNKNOWN_OBJECT_TYPE;
static const int ASN1_R_UNKNOWN_PUBLIC_KEY_TYPE;
static const int ASN1_R_UNKNOWN_TAG;
static const int ASN1_R_UNSUPPORTED_ANY_DEFINED_BY_TYPE;
static const int ASN1_R_UNSUPPORTED_PUBLIC_KEY_TYPE;
static const int ASN1_R_UNSUPPORTED_TYPE;
static const int ASN1_R_WRONG_TAG;
static const int ASN1_R_NO_CONTENT_TYPE;
static const int ASN1_R_NO_MULTIPART_BODY_FAILURE;
static const int ASN1_R_NO_MULTIPART_BOUNDARY;
static const int ASN1_R_HEADER_TOO_LONG;

static const int DH_R_INVALID_PUBKEY;

static const int EVP_F_EVP_ENCRYPTFINAL_EX;

static const int EVP_R_AES_KEY_SETUP_FAILED;
static const int EVP_R_BAD_DECRYPT;
static const int EVP_R_CIPHER_PARAMETER_ERROR;
static const int EVP_R_CTRL_NOT_IMPLEMENTED;
static const int EVP_R_CTRL_OPERATION_NOT_IMPLEMENTED;
static const int EVP_R_DATA_NOT_MULTIPLE_OF_BLOCK_LENGTH;
static const int EVP_R_DECODE_ERROR;
static const int EVP_R_DIFFERENT_KEY_TYPES;
static const int EVP_R_INITIALIZATION_ERROR;
static const int EVP_R_INPUT_NOT_INITIALIZED;
static const int EVP_R_INVALID_KEY_LENGTH;
static const int EVP_R_MISSING_PARAMETERS;
static const int EVP_R_NO_CIPHER_SET;
static const int EVP_R_NO_DIGEST_SET;
static const int EVP_R_PUBLIC_KEY_NOT_RSA;
static const int EVP_R_UNKNOWN_PBE_ALGORITHM;
static const int EVP_R_UNSUPPORTED_CIPHER;
static const int EVP_R_UNSUPPORTED_KEY_DERIVATION_FUNCTION;
static const int EVP_R_UNSUPPORTED_KEYLENGTH;
static const int EVP_R_UNSUPPORTED_SALT_TYPE;
static const int EVP_R_UNSUPPORTED_PRIVATE_KEY_ALGORITHM;
static const int EVP_R_WRONG_FINAL_BLOCK_LENGTH;
static const int EVP_R_CAMELLIA_KEY_SETUP_FAILED;

static const int EC_R_UNKNOWN_GROUP;

static const int PEM_R_BAD_BASE64_DECODE;
static const int PEM_R_BAD_DECRYPT;
static const int PEM_R_BAD_END_LINE;
static const int PEM_R_BAD_IV_CHARS;
static const int PEM_R_BAD_PASSWORD_READ;
static const int PEM_R_ERROR_CONVERTING_PRIVATE_KEY;
static const int PEM_R_NO_START_LINE;
static const int PEM_R_NOT_DEK_INFO;
static const int PEM_R_NOT_ENCRYPTED;
static const int PEM_R_NOT_PROC_TYPE;
static const int PEM_R_PROBLEMS_GETTING_PASSWORD;
static const int PEM_R_READ_KEY;
static const int PEM_R_SHORT_HEADER;
static const int PEM_R_UNSUPPORTED_CIPHER;
static const int PEM_R_UNSUPPORTED_ENCRYPTION;

static const int PKCS12_R_PKCS12_CIPHERFINAL_ERROR;

static const int RSA_R_DATA_TOO_LARGE_FOR_KEY_SIZE;
static const int RSA_R_DATA_TOO_LARGE_FOR_MODULUS;
static const int RSA_R_DIGEST_TOO_BIG_FOR_RSA_KEY;
static const int RSA_R_BLOCK_TYPE_IS_NOT_01;
static const int RSA_R_BLOCK_TYPE_IS_NOT_02;
static const int RSA_R_PKCS_DECODING_ERROR;
static const int RSA_R_OAEP_DECODING_ERROR;

static const int SSL_TLSEXT_ERR_OK;
static const int SSL_TLSEXT_ERR_ALERT_WARNING;
static const int SSL_TLSEXT_ERR_ALERT_FATAL;
static const int SSL_TLSEXT_ERR_NOACK;

static const int SSL_AD_CLOSE_NOTIFY;
static const int SSL_AD_UNEXPECTED_MESSAGE;
static const int SSL_AD_BAD_RECORD_MAC;
static const int SSL_AD_RECORD_OVERFLOW;
static const int SSL_AD_DECOMPRESSION_FAILURE;
static const int SSL_AD_HANDSHAKE_FAILURE;
static const int SSL_AD_BAD_CERTIFICATE;
static const int SSL_AD_UNSUPPORTED_CERTIFICATE;
static const int SSL_AD_CERTIFICATE_REVOKED;
static const int SSL_AD_CERTIFICATE_EXPIRED;
static const int SSL_AD_CERTIFICATE_UNKNOWN;
static const int SSL_AD_ILLEGAL_PARAMETER;
static const int SSL_AD_UNKNOWN_CA;
static const int SSL_AD_ACCESS_DENIED;
static const int SSL_AD_DECODE_ERROR;
static const int SSL_AD_DECRYPT_ERROR;
static const int SSL_AD_PROTOCOL_VERSION;
static const int SSL_AD_INSUFFICIENT_SECURITY;
static const int SSL_AD_INTERNAL_ERROR;
static const int SSL_AD_USER_CANCELLED;
static const int SSL_AD_NO_RENEGOTIATION;

static const int SSL_AD_UNSUPPORTED_EXTENSION;
static const int SSL_AD_CERTIFICATE_UNOBTAINABLE;
static const int SSL_AD_UNRECOGNIZED_NAME;
static const int SSL_AD_BAD_CERTIFICATE_STATUS_RESPONSE;
static const int SSL_AD_BAD_CERTIFICATE_HASH_VALUE;
static const int SSL_AD_UNKNOWN_PSK_IDENTITY;

static const int X509_R_CERT_ALREADY_IN_HASH_TABLE;
static const int X509_R_KEY_VALUES_MISMATCH;
"""

FUNCTIONS = """
void ERR_error_string_n(unsigned long, char *, size_t);
const char *ERR_lib_error_string(unsigned long);
const char *ERR_func_error_string(unsigned long);
const char *ERR_reason_error_string(unsigned long);
unsigned long ERR_get_error(void);
unsigned long ERR_peek_error(void);
unsigned long ERR_peek_last_error(void);
void ERR_clear_error(void);

int ERR_GET_LIB(unsigned long);
int ERR_GET_REASON(unsigned long);

"""

CUSTOMIZATIONS = """
static const long Cryptography_HAS_EC_CODES = 1;

#ifdef RSA_R_PKCS_DECODING_ERROR
static const long Cryptography_HAS_RSA_R_PKCS_DECODING_ERROR = 1;
#else
static const long Cryptography_HAS_RSA_R_PKCS_DECODING_ERROR = 0;
static const long RSA_R_PKCS_DECODING_ERROR = 0;
#endif

#ifdef EVP_R_MEMORY_LIMIT_EXCEEDED
static const long Cryptography_HAS_EVP_R_MEMORY_LIMIT_EXCEEDED = 1;
#else
static const long EVP_R_MEMORY_LIMIT_EXCEEDED = 0;
static const long Cryptography_HAS_EVP_R_MEMORY_LIMIT_EXCEEDED = 0;
#endif

#if CRYPTOGRAPHY_OPENSSL_300_OR_GREATER
#else
static const int ERR_LIB_CMP = -42;
static const int ERR_LIB_CRMF = -42;
static const int ERR_LIB_ESS = -42;
static const int ERR_LIB_HTTP = -42;
static const int ERR_LIB_MASK = -42;
static const int ERR_LIB_OFFSET = -42;
static const int ERR_LIB_OSSL_DECODER = -42;
static const int ERR_LIB_OSSL_ENCODER = -42;
static const int ERR_LIB_PROP = -42;
static const int ERR_LIB_PROV = -42;
#endif
"""
