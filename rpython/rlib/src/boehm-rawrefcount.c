#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <limits.h>
#include <gc/gc.h>
#include <gc/gc_mark.h>

#ifdef TEST_BOEHM_RAWREFCOUNT
#  define RPY_EXTERN  /* nothing */
#else
#  include "common_header.h"
#endif


#define REFCNT_FROM_PYPY  (LONG_MAX / 4 + 1)

typedef struct pypy_header0 gcobj_t;    /* opaque here */

#ifndef _WIN32
typedef intptr_t Py_ssize_t;
#elif defined(_WIN64)
typedef long long Py_ssize_t;
#else
typedef long Py_ssize_t;
#endif

/* this is the first two words of the PyObject structure used in
   pypy/module/cpyext */
typedef struct {
    Py_ssize_t ob_refcnt;
    Py_ssize_t ob_pypy_link;
} pyobj_t;

struct link_s {
    pyobj_t *pyobj;    /* NULL if entry unused */
    uintptr_t gcenc;
    struct link_s *next_in_bucket;
};

#define MARKER_LIST_START  ((pyobj_t *)-1)

static struct link_s **hash_buckets, *hash_list, *hash_free_list;
static uintptr_t hash_mask_bucket;
static intptr_t hash_list_walk_next = -1;

static uintptr_t hash_get_hash(gcobj_t *gcobj)
{
    assert(gcobj != NULL);
    uintptr_t h = (uintptr_t)gcobj;
    assert((h & 1) == 0);
    h -= (h >> 6);
    return h & hash_mask_bucket;
}

static gcobj_t *decode_gcenc(uintptr_t gcenc)
{
    if (gcenc & 1)
        gcenc = ~gcenc;
    return (gcobj_t *)gcenc;
}

static void hash_link(struct link_s *lnk)
{
    uintptr_t h = hash_get_hash(decode_gcenc(lnk->gcenc));
    lnk->next_in_bucket = hash_buckets[h];
    hash_buckets[h] = lnk;
}

static void boehm_is_about_to_collect(void);

static void hash_grow_table(void)
{
    static int rec = 0;
    assert(!rec);   /* recursive hash_grow_table() */
    rec = 1;

    if (hash_buckets == NULL)
        GC_set_start_callback(boehm_is_about_to_collect);

    uintptr_t i, num_buckets = (hash_mask_bucket + 1) * 2;
    if (num_buckets < 16) num_buckets = 16;
    assert((num_buckets & (num_buckets - 1)) == 0);  /* power of two */

    /* The new hash_buckets: an array of pointers to struct link_s, of
       length a power of two, used as a dictionary hash table.  It is
       not allocated with Boehm because there is no point in Boehm looking
       in it.
     */
    struct link_s **new_buckets = calloc(num_buckets, sizeof(struct link_s *));
    assert(new_buckets);

    /* The new hash_list: the array of all struct link_s.  Their order
       is irrelevant.  There is a GC_register_finalizer() on the 'gcenc'
       field, so we don't move the array; instead we allocate a new array
       to use in addition to the old one.  There are a total of 2 to 4
       times as many 'struct link_s' as the length of 'buckets'.
     */
    uintptr_t num_list = num_buckets * 2;
    struct link_s *new_list = GC_MALLOC(num_list * sizeof(struct link_s));
    for (i = num_list; i-- > 1; ) {
        new_list[i].next_in_bucket = hash_free_list;
        hash_free_list = &new_list[i];
    }
    /* list[0] is abused to store a pointer to the previous list and
       the length of the current list */
    struct link_s *old_list = hash_list;
    new_list[0].next_in_bucket = old_list;
    new_list[0].gcenc = num_list;
    new_list[0].pyobj = MARKER_LIST_START;

    hash_list = new_list;
    free(hash_buckets);
    hash_buckets = new_buckets;
    hash_mask_bucket = num_buckets - 1;
    hash_list_walk_next = hash_mask_bucket;

    /* re-add all old 'struct link_s' to the hash_buckets */
    struct link_s *plist = old_list;
    while (plist != NULL) {
        uintptr_t count = plist[0].gcenc;
        for (i = 1; i < count; i++) {
            if (plist[i].gcenc != 0)
                hash_link(&plist[i]);
        }
        plist = plist[0].next_in_bucket;
    }
    GC_reachable_here(old_list);

    rec = 0;
}

static void hash_add_entry(gcobj_t *gcobj, pyobj_t *pyobj)
{
    if (hash_free_list == NULL) {
        hash_grow_table();
    }
    assert(pyobj->ob_pypy_link == 0);

    struct link_s *lnk = hash_free_list;
    hash_free_list = lnk->next_in_bucket;
    lnk->pyobj = pyobj;
    lnk->gcenc = (uintptr_t)gcobj;
    pyobj->ob_pypy_link = (Py_ssize_t)lnk;

    hash_link(lnk);

    if (GC_base(gcobj) == NULL) {
        /* 'gcobj' is probably a prebuilt object - it makes no */
        /* sense to register it then, and it crashes Boehm in */
        /* quite obscure ways */
    }
    else {
        int j = GC_general_register_disappearing_link(
                                    (void **)&lnk->gcenc, gcobj);
        assert(j == GC_SUCCESS);
    }
}

static pyobj_t *hash_get_entry(gcobj_t *gcobj)
{
    if (hash_buckets == NULL)
        return NULL;
    uintptr_t h = hash_get_hash(gcobj);
    struct link_s *lnk = hash_buckets[h];
    while (lnk != NULL) {
        assert(lnk->pyobj != NULL);
        if (decode_gcenc(lnk->gcenc) == gcobj)
            return lnk->pyobj;
        lnk = lnk->next_in_bucket;
    }
    return NULL;
}


RPY_EXTERN
/*pyobj_t*/void *gc_rawrefcount_next_dead(void)
{
    while (hash_list_walk_next >= 0) {
        struct link_s *p, **pp = &hash_buckets[hash_list_walk_next];
        while (1) {
            p = *pp;
            if (p == NULL)
                break;
            assert(p->pyobj != NULL);
            if (p->gcenc == 0) {
                /* quadratic time on the number of links from the same
                   bucket chain, but it should be small with very high
                   probability */
                pyobj_t *result = p->pyobj;
#ifdef TEST_BOEHM_RAWREFCOUNT
                printf("next_dead: %p\n", result);
#endif
                assert(result->ob_refcnt == REFCNT_FROM_PYPY);
                result->ob_refcnt = 1;
                result->ob_pypy_link = 0;
                p->pyobj = NULL;
                *pp = p->next_in_bucket;
                p->next_in_bucket = hash_free_list;
                hash_free_list = p;
                return result;
            }
            else {
                assert(p->gcenc != ~(uintptr_t)0);
                pp = &p->next_in_bucket;
            }
        }
        hash_list_walk_next--;
    }
    return NULL;
}

RPY_EXTERN
void gc_rawrefcount_create_link_pypy(/*gcobj_t*/void *gcobj, 
                                     /*pyobj_t*/void *pyobj)
{
    gcobj_t *gcobj1 = (gcobj_t *)gcobj;
    pyobj_t *pyobj1 = (pyobj_t *)pyobj;

    assert(pyobj1->ob_pypy_link == 0);
    /*assert(pyobj1->ob_refcnt >= REFCNT_FROM_PYPY);*/
    /*^^^ could also be fixed just after the call to create_link_pypy()*/

    hash_add_entry(gcobj1, pyobj1);
}

RPY_EXTERN
/*pyobj_t*/void *gc_rawrefcount_from_obj(/*gcobj_t*/void *gcobj)
{
    return hash_get_entry((gcobj_t *)gcobj);
}

RPY_EXTERN
/*gcobj_t*/void *gc_rawrefcount_to_obj(/*pyobj_t*/void *pyobj)
{
    pyobj_t *pyobj1 = (pyobj_t *)pyobj;

    if (pyobj1->ob_pypy_link == 0)
        return NULL;

    struct link_s *lnk = (struct link_s *)pyobj1->ob_pypy_link;
    assert(lnk->pyobj == pyobj1);
    
    gcobj_t *g = decode_gcenc(lnk->gcenc);
    assert(g != NULL);
    return g;
}

static void boehm_is_about_to_collect(void)
{
    struct link_s *plist = hash_list;
    uintptr_t gcenc_union = 0;
    while (plist != NULL) {
        uintptr_t i, count = plist[0].gcenc;
        for (i = 1; i < count; i++) {
            if (plist[i].gcenc == 0)
                continue;

            pyobj_t *p = plist[i].pyobj;
            assert(p != NULL);
            assert(p->ob_refcnt >= REFCNT_FROM_PYPY);

#ifdef TEST_BOEHM_RAWREFCOUNT
            printf("plist[%d].gcenc: %p ", (int)i, (void *)plist[i].gcenc);
#endif

            if ((plist[i].gcenc & 1) ^ (p->ob_refcnt == REFCNT_FROM_PYPY)) {
                /* ob_refcnt > FROM_PYPY: non-zero regular refcnt, 
                   the gc obj must stay alive.  decode gcenc.
                   ---OR---
                   ob_refcnt == FROM_PYPY: no refs from C code, the
                   gc obj must not (necessarily) stay alive.  encode gcenc.
                */
                plist[i].gcenc = ~plist[i].gcenc;
            }
            gcenc_union |= plist[i].gcenc;
#ifdef TEST_BOEHM_RAWREFCOUNT
            printf("-> %p\n", (void *)plist[i].gcenc);
#endif
    }
        plist = plist[0].next_in_bucket;
    }
    if (gcenc_union & 1)   /* if there is at least one item potentially dead */
        hash_list_walk_next = hash_mask_bucket;
}
