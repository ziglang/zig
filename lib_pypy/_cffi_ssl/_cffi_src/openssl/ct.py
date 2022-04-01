# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#if CRYPTOGRAPHY_OPENSSL_110_OR_GREATER
#include <openssl/ct.h>

typedef STACK_OF(SCT) Cryptography_STACK_OF_SCT;
#endif
"""

TYPES = """
static const long Cryptography_HAS_SCT;

typedef enum {
    SCT_VERSION_NOT_SET,
    SCT_VERSION_V1
} sct_version_t;

typedef enum {
    CT_LOG_ENTRY_TYPE_NOT_SET,
    CT_LOG_ENTRY_TYPE_X509,
    CT_LOG_ENTRY_TYPE_PRECERT
} ct_log_entry_type_t;

typedef enum {
    SCT_SOURCE_UNKNOWN,
    SCT_SOURCE_TLS_EXTENSION,
    SCT_SOURCE_X509V3_EXTENSION,
    SCT_SOURCE_OCSP_STAPLED_RESPONSE
} sct_source_t;

typedef ... SCT;
typedef ... Cryptography_STACK_OF_SCT;
"""

FUNCTIONS = """
sct_version_t SCT_get_version(const SCT *);

ct_log_entry_type_t SCT_get_log_entry_type(const SCT *);

size_t SCT_get0_log_id(const SCT *, unsigned char **);

size_t SCT_get0_signature(const SCT *, unsigned char **);

uint64_t SCT_get_timestamp(const SCT *);

int SCT_set_source(SCT *, sct_source_t);

int sk_SCT_num(const Cryptography_STACK_OF_SCT *);
SCT *sk_SCT_value(const Cryptography_STACK_OF_SCT *, int);

void SCT_LIST_free(Cryptography_STACK_OF_SCT *);

int sk_SCT_push(Cryptography_STACK_OF_SCT *, SCT *);
Cryptography_STACK_OF_SCT *sk_SCT_new_null(void);
SCT *SCT_new(void);
int SCT_set1_log_id(SCT *, unsigned char *, size_t);
void SCT_set_timestamp(SCT *, uint64_t);
int SCT_set_version(SCT *, sct_version_t);
int SCT_set_log_entry_type(SCT *, ct_log_entry_type_t);
"""

CUSTOMIZATIONS = """
#if CRYPTOGRAPHY_OPENSSL_110_OR_GREATER
static const long Cryptography_HAS_SCT = 1;
#else
static const long Cryptography_HAS_SCT = 0;

typedef enum {
    SCT_VERSION_NOT_SET,
    SCT_VERSION_V1
} sct_version_t;
typedef enum {
    CT_LOG_ENTRY_TYPE_NOT_SET,
    CT_LOG_ENTRY_TYPE_X509,
    CT_LOG_ENTRY_TYPE_PRECERT
} ct_log_entry_type_t;
typedef enum {
    SCT_SOURCE_UNKNOWN,
    SCT_SOURCE_TLS_EXTENSION,
    SCT_SOURCE_X509V3_EXTENSION,
    SCT_SOURCE_OCSP_STAPLED_RESPONSE
} sct_source_t;
typedef void SCT;
typedef void Cryptography_STACK_OF_SCT;

sct_version_t (*SCT_get_version)(const SCT *) = NULL;
ct_log_entry_type_t (*SCT_get_log_entry_type)(const SCT *) = NULL;
size_t (*SCT_get0_log_id)(const SCT *, unsigned char **) = NULL;
size_t (*SCT_get0_signature)(const SCT *, unsigned char **) = NULL;
uint64_t (*SCT_get_timestamp)(const SCT *) = NULL;

int (*SCT_set_source)(SCT *, sct_source_t) = NULL;

int (*sk_SCT_num)(const Cryptography_STACK_OF_SCT *) = NULL;
SCT *(*sk_SCT_value)(const Cryptography_STACK_OF_SCT *, int) = NULL;

void (*SCT_LIST_free)(Cryptography_STACK_OF_SCT *) = NULL;
int (*sk_SCT_push)(Cryptography_STACK_OF_SCT *, SCT *) = NULL;
Cryptography_STACK_OF_SCT *(*sk_SCT_new_null)(void) = NULL;
SCT *(*SCT_new)(void) = NULL;
int (*SCT_set1_log_id)(SCT *, unsigned char *, size_t) = NULL;
void (*SCT_set_timestamp)(SCT *, uint64_t) = NULL;
int (*SCT_set_version)(SCT *, sct_version_t) = NULL;
int (*SCT_set_log_entry_type)(SCT *, ct_log_entry_type_t) = NULL;
#endif
"""
