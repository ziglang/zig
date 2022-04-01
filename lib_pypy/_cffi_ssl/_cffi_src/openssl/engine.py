# This file is dual licensed under the terms of the Apache License, Version
# 2.0, and the BSD License. See the LICENSE file in the root of this repository
# for complete details.

from __future__ import absolute_import, division, print_function

INCLUDES = """
#include <openssl/engine.h>
"""

TYPES = """
typedef ... ENGINE;

static const long Cryptography_HAS_ENGINE;
"""

FUNCTIONS = """
ENGINE *ENGINE_by_id(const char *);
int ENGINE_init(ENGINE *);
int ENGINE_finish(ENGINE *);
ENGINE *ENGINE_get_default_RAND(void);
int ENGINE_set_default_RAND(ENGINE *);
void ENGINE_unregister_RAND(ENGINE *);
int ENGINE_ctrl_cmd(ENGINE *, const char *, long, void *, void (*)(void), int);
int ENGINE_free(ENGINE *);
const char *ENGINE_get_name(const ENGINE *);

"""

CUSTOMIZATIONS = """
#ifdef OPENSSL_NO_ENGINE
static const long Cryptography_HAS_ENGINE = 0;

ENGINE *(*ENGINE_by_id)(const char *) = NULL;
int (*ENGINE_init)(ENGINE *) = NULL;
int (*ENGINE_finish)(ENGINE *) = NULL;
ENGINE *(*ENGINE_get_default_RAND)(void) = NULL;
int (*ENGINE_set_default_RAND)(ENGINE *) = NULL;
void (*ENGINE_unregister_RAND)(ENGINE *) = NULL;
int (*ENGINE_ctrl_cmd)(ENGINE *, const char *, long, void *,
                       void (*)(void), int) = NULL;

int (*ENGINE_free)(ENGINE *) = NULL;
const char *(*ENGINE_get_id)(const ENGINE *) = NULL;
const char *(*ENGINE_get_name)(const ENGINE *) = NULL;

#else
static const long Cryptography_HAS_ENGINE = 1;
#endif
"""
