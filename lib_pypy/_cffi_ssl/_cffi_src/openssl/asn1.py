# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/asn1.h>
"""

TYPES = """
typedef int... time_t;

typedef ... ASN1_INTEGER;

struct asn1_string_st {
    int length;
    int type;
    unsigned char *data;
    long flags;
};

typedef struct asn1_string_st ASN1_OCTET_STRING;
typedef struct asn1_string_st ASN1_IA5STRING;
typedef struct asn1_string_st ASN1_BIT_STRING;
typedef struct asn1_string_st ASN1_TIME;
typedef ... ASN1_OBJECT;
typedef struct asn1_string_st ASN1_STRING;
typedef struct asn1_string_st ASN1_UTF8STRING;
typedef ... ASN1_TYPE;
typedef ... ASN1_GENERALIZEDTIME;
typedef ... ASN1_ENUMERATED;
typedef ... ASN1_ITEM;
typedef ... ASN1_VALUE;

typedef ... ASN1_ITEM_EXP;
typedef ... ASN1_NULL;

static const int V_ASN1_GENERALIZEDTIME;

static const int MBSTRING_UTF8;
"""

FUNCTIONS = """
void ASN1_OBJECT_free(ASN1_OBJECT *);

/*  ASN1 STRING */
unsigned char *ASN1_STRING_data(ASN1_STRING *);
int ASN1_STRING_set(ASN1_STRING *, const void *, int);

/*  ASN1 OCTET STRING */
ASN1_OCTET_STRING *ASN1_OCTET_STRING_new(void);
void ASN1_OCTET_STRING_free(ASN1_OCTET_STRING *);
int ASN1_OCTET_STRING_set(ASN1_OCTET_STRING *, const unsigned char *, int);

/* ASN1 IA5STRING */
ASN1_IA5STRING *ASN1_IA5STRING_new(void);

/*  ASN1 INTEGER */
void ASN1_INTEGER_free(ASN1_INTEGER *);
int ASN1_INTEGER_set(ASN1_INTEGER *, long);

/*  ASN1 TIME */
ASN1_TIME *ASN1_TIME_new(void);
void ASN1_TIME_free(ASN1_TIME *);
ASN1_TIME *ASN1_TIME_set(ASN1_TIME *, time_t);
int ASN1_TIME_set_string(ASN1_TIME *, const char *);

/*  ASN1 GENERALIZEDTIME */
ASN1_GENERALIZEDTIME *ASN1_GENERALIZEDTIME_set(ASN1_GENERALIZEDTIME *, time_t);
void ASN1_GENERALIZEDTIME_free(ASN1_GENERALIZEDTIME *);

/*  ASN1 ENUMERATED */
ASN1_ENUMERATED *ASN1_ENUMERATED_new(void);
void ASN1_ENUMERATED_free(ASN1_ENUMERATED *);
int ASN1_ENUMERATED_set(ASN1_ENUMERATED *, long);

ASN1_VALUE *ASN1_item_d2i(ASN1_VALUE **, const unsigned char **, long,
                          const ASN1_ITEM *);
int ASN1_BIT_STRING_set_bit(ASN1_BIT_STRING *, int, int);
/* These became const ASN1_* in 1.1.0 */
int ASN1_STRING_type(ASN1_STRING *);
int ASN1_STRING_to_UTF8(unsigned char **, ASN1_STRING *);
long ASN1_ENUMERATED_get(ASN1_ENUMERATED *);
int i2a_ASN1_INTEGER(BIO *, ASN1_INTEGER *);

/* This became const ASN1_TIME in 1.1.0f */
ASN1_GENERALIZEDTIME *ASN1_TIME_to_generalizedtime(ASN1_TIME *,
                                                   ASN1_GENERALIZEDTIME **);

ASN1_UTF8STRING *ASN1_UTF8STRING_new(void);
void ASN1_UTF8STRING_free(ASN1_UTF8STRING *);

ASN1_BIT_STRING *ASN1_BIT_STRING_new(void);
void ASN1_BIT_STRING_free(ASN1_BIT_STRING *);
const ASN1_ITEM *ASN1_ITEM_ptr(ASN1_ITEM_EXP *);

/* This is not a macro, but is const on some versions of OpenSSL */
int ASN1_BIT_STRING_get_bit(ASN1_BIT_STRING *, int);

int ASN1_TIME_print(BIO *, ASN1_TIME *);
int ASN1_STRING_length(ASN1_STRING *);
int ASN1_STRING_set_default_mask_asc(char *);

BIGNUM *ASN1_INTEGER_to_BN(ASN1_INTEGER *, BIGNUM *);
ASN1_INTEGER *BN_to_ASN1_INTEGER(BIGNUM *, ASN1_INTEGER *);

int i2d_ASN1_TYPE(ASN1_TYPE *, unsigned char **);
ASN1_TYPE *d2i_ASN1_TYPE(ASN1_TYPE **, const unsigned char **, long);

ASN1_NULL *ASN1_NULL_new(void);
"""

CUSTOMIZATIONS = """
"""
