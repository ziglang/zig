/**
 * A manager for HPy handles, allowing handles to be tracked
 * and closed as a group.
 *
 * Note::
 *    Calling HPyTracker_New(ctx, n) will ensure that at least n handles
 *    can be tracked without a call to HPyTracker_Add failing.
 *
 *    If a call to HPyTracker_Add fails, the tracker still guarantees that
 *    the handle passed to it has been tracked (internally it does this by
 *    maintaining space for one more handle).
 *
 *    After HPyTracker_Add fails, HPyTracker_Close should be called without
 *    any further calls to HPyTracker_Add. Calling HPyTracker_Close will close
 *    all the tracked handles, including the handled passed to the failed call
 *    to HPyTracker_Add.
 *
 * Example usage (inside an HPyDef_METH function)::
 *
 * long i;
 * HPy key, value;
 * HPyTracker ht;
 *
 * ht = HPyTracker_New(ctx, 0);  // track the key-value pairs
 * if (HPy_IsNull(ht))
 *     return HPy_NULL;
 *
 * HPy dict = HPyDict_New(ctx);
 * if (HPy_IsNull(dict))
 *     goto error;
 *
 * for (i=0; i<5; i++) {
 *     key = HPyLong_FromLong(ctx, i);
 *     if (HPy_IsNull(key))
 *         goto error;
 *     if (HPyTracker_Add(ctx, ht, key) < 0)
 *         goto error;
 *     value = HPyLong_FromLong(ctx, i * i);
 *     if (HPy_IsNull(value)) {
 *         goto error;
 *     }
 *     if (HPyTracker_Add(ctx, ht, value) < 0)
 *         goto error;
 *     result = HPy_SetItem(ctx, dict, key, value);
 *     if (result < 0)
 *         goto error;
 * }
 *
 * success:
 *    HPyTracker_Close(ctx, ht);
 *    return dict;
 *
 * error:
 *    HPyTracker_Close(ctx, ht);
 *    HPy_Close(ctx, dict);
 *    // HPyErr will already have been set by the error that occurred.
 *    return HPy_NULL;
 */

#include "hpy.h"

static const HPy_ssize_t HPYTRACKER_INITIAL_CAPACITY = 5;

typedef struct {
    HPy_ssize_t capacity;  // allocated handles
    HPy_ssize_t length;    // used handles
    HPy *handles;
} _HPyTracker_s;


static inline _HPyTracker_s *_ht2hp(HPyTracker ht) {
    return (_HPyTracker_s *) (ht)._i;
}
static inline HPyTracker _hp2ht(_HPyTracker_s *hp) {
    return (HPyTracker) {(HPy_ssize_t) (hp)};
}


_HPy_HIDDEN HPyTracker
ctx_Tracker_New(HPyContext *ctx, HPy_ssize_t capacity)
{
    _HPyTracker_s *hp;
    if (capacity == 0) {
        capacity = HPYTRACKER_INITIAL_CAPACITY;
    }
    capacity++; // always reserve space for an extra handle, see the docs

    hp = malloc(sizeof(_HPyTracker_s));
    if (hp == NULL) {
        HPyErr_NoMemory(ctx);
        return _hp2ht(0);
    }
    hp->handles = calloc(capacity, sizeof(HPy));
    if (hp->handles == NULL) {
        free(hp);
        HPyErr_NoMemory(ctx);
        return _hp2ht(0);
    }
    hp->capacity = capacity;
    hp->length = 0;
    // cppcheck thinks that hp->handles is a memory leak because we cast the
    // pointer to an int (and thus the pointer is "lost" from its POV, I
    // suppose). But it's not a real leak because we free it in
    // ctx_Tracker_Close:
    // cppcheck-suppress memleak
    return _hp2ht(hp);
}

static int
tracker_resize(HPyContext *ctx, _HPyTracker_s *hp, HPy_ssize_t capacity)
{
    HPy *new_handles;
    capacity++;

    if (capacity <= hp->length) {
        // refuse a resize that would either 1) lose handles or  2) not leave
        // space for one new handle
        HPyErr_SetString(ctx, ctx->h_ValueError, "HPyTracker resize would lose handles");
        return -1;
    }
    new_handles = realloc(hp->handles, capacity * sizeof(HPy));
    if (new_handles == NULL) {
        HPyErr_NoMemory(ctx);
        return -1;
    }
    hp->capacity = capacity;
    hp->handles = new_handles;
    return 0;
}

_HPy_HIDDEN int
ctx_Tracker_Add(HPyContext *ctx, HPyTracker ht, HPy h)
{
    _HPyTracker_s *hp =  _ht2hp(ht);
    hp->handles[hp->length++] = h;
    if (hp->capacity <= hp->length) {
        if (tracker_resize(ctx, hp, hp->capacity * 2 - 1) < 0)
            return -1;
    }
    return 0;
}

_HPy_HIDDEN void
ctx_Tracker_ForgetAll(HPyContext *ctx, HPyTracker ht)
{
    _HPyTracker_s *hp = _ht2hp(ht);
    hp->length = 0;
}

_HPy_HIDDEN void
ctx_Tracker_Close(HPyContext *ctx, HPyTracker ht)
{
    _HPyTracker_s *hp = _ht2hp(ht);
    HPy_ssize_t i;
    for (i=0; i<hp->length; i++) {
        HPy_Close(ctx, hp->handles[i]);
    }
    free(hp->handles);
    free(hp);
}
