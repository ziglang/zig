# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/objects.h>
"""

TYPES = """
typedef struct {
    int type;
    int alias;
    const char *name;
    const char *data;
} OBJ_NAME;

static const long OBJ_NAME_TYPE_MD_METH;
"""

FUNCTIONS = """
ASN1_OBJECT *OBJ_nid2obj(int);
const char *OBJ_nid2ln(int);
const char *OBJ_nid2sn(int);
int OBJ_obj2nid(const ASN1_OBJECT *);
int OBJ_ln2nid(const char *);
int OBJ_sn2nid(const char *);
int OBJ_txt2nid(const char *);
ASN1_OBJECT *OBJ_txt2obj(const char *, int);
int OBJ_obj2txt(char *, int, const ASN1_OBJECT *, int);
int OBJ_cmp(const ASN1_OBJECT *, const ASN1_OBJECT *);
ASN1_OBJECT *OBJ_dup(const ASN1_OBJECT *);
int OBJ_create(const char *, const char *, const char *);
void OBJ_NAME_do_all(int, void (*) (const OBJ_NAME *, void *), void *);
/* OBJ_cleanup became a macro in 1.1.0 */
void OBJ_cleanup(void);
"""

CUSTOMIZATIONS = """
"""
