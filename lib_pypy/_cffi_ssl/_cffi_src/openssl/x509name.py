# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/x509.h>

/*
 * See the comment above Cryptography_STACK_OF_X509 in x509.py
 */
typedef STACK_OF(X509_NAME) Cryptography_STACK_OF_X509_NAME;
typedef STACK_OF(X509_NAME_ENTRY) Cryptography_STACK_OF_X509_NAME_ENTRY;
"""

TYPES = """
typedef ... Cryptography_STACK_OF_X509_NAME_ENTRY;
typedef ... X509_NAME;
typedef ... X509_NAME_ENTRY;
typedef ... Cryptography_STACK_OF_X509_NAME;
"""

FUNCTIONS = """
X509_NAME *X509_NAME_new(void);
void X509_NAME_free(X509_NAME *);

// unsigned long X509_NAME_hash(X509_NAME *);

int i2d_X509_NAME(X509_NAME *, unsigned char **);
int X509_NAME_add_entry_by_txt(X509_NAME *, const char *, int,
                               const unsigned char *, int, int, int);
X509_NAME_ENTRY *X509_NAME_delete_entry(X509_NAME *, int);
void X509_NAME_ENTRY_free(X509_NAME_ENTRY *);
int X509_NAME_get_index_by_NID(X509_NAME *, int, int);
int X509_NAME_cmp(const X509_NAME *, const X509_NAME *);
X509_NAME *X509_NAME_dup(X509_NAME *);
int Cryptography_X509_NAME_ENTRY_set(X509_NAME_ENTRY *);
/* These became const X509_NAME * in 1.1.0 */
int X509_NAME_entry_count(X509_NAME *);
X509_NAME_ENTRY *X509_NAME_get_entry(X509_NAME *, int);
char *X509_NAME_oneline(X509_NAME *, char *, int);
int X509_NAME_print_ex(BIO *, X509_NAME *, int, unsigned long);

/* These became const X509_NAME_ENTRY * in 1.1.0 */
ASN1_OBJECT *X509_NAME_ENTRY_get_object(X509_NAME_ENTRY *);
ASN1_STRING *X509_NAME_ENTRY_get_data(X509_NAME_ENTRY *);
int X509_NAME_add_entry(X509_NAME *, X509_NAME_ENTRY *, int, int);

/* this became const unsigned char * in 1.1.0 */
int X509_NAME_add_entry_by_NID(X509_NAME *, int, int, unsigned char *,
                               int, int, int);

/* These became const ASN1_OBJECT * in 1.1.0 */
X509_NAME_ENTRY *X509_NAME_ENTRY_create_by_OBJ(X509_NAME_ENTRY **,
                                               ASN1_OBJECT *, int,
                                               const unsigned char *, int);
int X509_NAME_add_entry_by_OBJ(X509_NAME *, ASN1_OBJECT *, int,
                               unsigned char *, int, int, int);

Cryptography_STACK_OF_X509_NAME *sk_X509_NAME_new_null(void);
int sk_X509_NAME_num(Cryptography_STACK_OF_X509_NAME *);
int sk_X509_NAME_push(Cryptography_STACK_OF_X509_NAME *, X509_NAME *);
X509_NAME *sk_X509_NAME_value(Cryptography_STACK_OF_X509_NAME *, int);
void sk_X509_NAME_free(Cryptography_STACK_OF_X509_NAME *);
int sk_X509_NAME_ENTRY_num(Cryptography_STACK_OF_X509_NAME_ENTRY *);
Cryptography_STACK_OF_X509_NAME_ENTRY *sk_X509_NAME_ENTRY_new_null(void);
int sk_X509_NAME_ENTRY_push(Cryptography_STACK_OF_X509_NAME_ENTRY *,
                            X509_NAME_ENTRY *);
X509_NAME_ENTRY *sk_X509_NAME_ENTRY_value(
    Cryptography_STACK_OF_X509_NAME_ENTRY *, int);
Cryptography_STACK_OF_X509_NAME_ENTRY *sk_X509_NAME_ENTRY_dup(
    Cryptography_STACK_OF_X509_NAME_ENTRY *
);
"""

CUSTOMIZATIONS = """
#if CRYPTOGRAPHY_OPENSSL_110_OR_GREATER
int Cryptography_X509_NAME_ENTRY_set(X509_NAME_ENTRY *ne) {
    return X509_NAME_ENTRY_set(ne);
}
#else
int Cryptography_X509_NAME_ENTRY_set(X509_NAME_ENTRY *ne) {
    return ne->set;
}
#endif
"""
