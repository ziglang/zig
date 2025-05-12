/* $Id: ppath.h,v 1.1 2011/08/25 16:15:29 dyoung Exp $ */

/* Copyright (c) 2010 David Young.  All rights reserved. */

#ifndef _PPATH_H
#define _PPATH_H

#include <prop/proplib.h>

#define	PPATH_MAX_COMPONENTS	16

struct _ppath;
struct _ppath_component;
typedef struct _ppath ppath_t;
typedef struct _ppath_component ppath_component_t;

ppath_component_t *ppath_idx(unsigned int);
ppath_component_t *ppath_key(const char *);

ppath_component_t *ppath_component_retain(ppath_component_t *);
void ppath_component_release(ppath_component_t *);

ppath_t *ppath_create(void);
unsigned int ppath_length(const ppath_t *);
int ppath_component_idx(const ppath_component_t *);
const char *ppath_component_key(const ppath_component_t *);
ppath_t *ppath_pop(ppath_t *, ppath_component_t **);
ppath_t *ppath_push(ppath_t *, ppath_component_t *);
ppath_component_t *ppath_component_at(const ppath_t *, unsigned int);
ppath_t *ppath_subpath(const ppath_t *, unsigned int, unsigned int);
ppath_t *ppath_push_idx(ppath_t *, unsigned int);
ppath_t *ppath_push_key(ppath_t *, const char *);
ppath_t *ppath_replace_idx(ppath_t *, unsigned int);
ppath_t *ppath_replace_key(ppath_t *, const char *);

ppath_t *ppath_copy(const ppath_t *);
ppath_t *ppath_retain(ppath_t *);
void ppath_release(ppath_t *);

prop_object_t ppath_lookup(prop_object_t, const ppath_t *);

int ppath_copydel_object(prop_object_t, prop_object_t *, const ppath_t *);
int ppath_copyset_object(prop_object_t, prop_object_t *, const ppath_t *,
    prop_object_t);
int ppath_create_object(prop_object_t, const ppath_t *, prop_object_t);
int ppath_set_object(prop_object_t, const ppath_t *, prop_object_t);
int ppath_get_object(prop_object_t, const ppath_t *, prop_object_t *);
int ppath_delete_object(prop_object_t, const ppath_t *);

int ppath_copydel_bool(prop_object_t, prop_object_t *, const ppath_t *);
int ppath_copyset_bool(prop_object_t, prop_object_t *, const ppath_t *, bool);
int ppath_create_bool(prop_object_t, const ppath_t *, bool);
int ppath_create_int64(prop_object_t, const ppath_t *, int64_t);
int ppath_create_uint64(prop_object_t, const ppath_t *, uint64_t);
int ppath_create_data(prop_object_t, const ppath_t *, const void *, size_t);
int ppath_create_string(prop_object_t, const ppath_t *, const char *);
int ppath_set_bool(prop_object_t, const ppath_t *, bool);
int ppath_get_bool(prop_object_t, const ppath_t *, bool *);
int ppath_delete_bool(prop_object_t, const ppath_t *);

int ppath_copydel_data(prop_object_t, prop_object_t *, const ppath_t *);
int ppath_copyset_data(prop_object_t, prop_object_t *, const ppath_t *,
    const void *, size_t);
int ppath_set_data(prop_object_t, const ppath_t *, const void *, size_t);
int ppath_get_data(prop_object_t, const ppath_t *, const void **, size_t *);
int ppath_dup_data(prop_object_t, const ppath_t *, void **, size_t *);
int ppath_delete_data(prop_object_t, const ppath_t *);

int ppath_copydel_int64(prop_object_t, prop_object_t *, const ppath_t *);
int ppath_copyset_int64(prop_object_t, prop_object_t *, const ppath_t *,
    int64_t);
int ppath_set_int64(prop_object_t, const ppath_t *, int64_t);
int ppath_get_int64(prop_object_t, const ppath_t *, int64_t *);
int ppath_delete_int64(prop_object_t, const ppath_t *);

int ppath_copydel_string(prop_object_t, prop_object_t *, const ppath_t *);
int ppath_copyset_string(prop_object_t, prop_object_t *, const ppath_t *,
    const char *);
int ppath_set_string(prop_object_t, const ppath_t *, const char *);
int ppath_get_string(prop_object_t, const ppath_t *, const char **);
int ppath_dup_string(prop_object_t, const ppath_t *, char **);
int ppath_delete_string(prop_object_t, const ppath_t *);

int ppath_copydel_uint64(prop_object_t, prop_object_t *, const ppath_t *);
int ppath_copyset_uint64(prop_object_t, prop_object_t *, const ppath_t *,
    uint64_t);
int ppath_set_uint64(prop_object_t, const ppath_t *, uint64_t);
int ppath_get_uint64(prop_object_t, const ppath_t *, uint64_t *);
int ppath_delete_uint64(prop_object_t, const ppath_t *);

#endif /* _PPATH_H */