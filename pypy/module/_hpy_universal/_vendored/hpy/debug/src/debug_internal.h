/* Internal header for all the files in hpy/debug/src. The public API is in
   include/hpy_debug.h
*/
#ifndef HPY_DEBUG_INTERNAL_H
#define HPY_DEBUG_INTERNAL_H

#include <assert.h>
#include "hpy.h"
#include "hpy_debug.h"

#define HPY_DEBUG_MAGIC 0xDEB00FF

/* The Debug context is a wrapper around an underlying context, which we will
   call Universal. Inside the debug mode we manipulate handles which belongs
   to both contexts, so to make things easier we create two typedefs to make
   it clear what kind of handle we expect: UHPy and DHPy:

     * UHPy are opaque from our point of view.

     * DHPy are actually DebugHandle* in disguise. DebugHandles are wrappers
       around a UHPy, with a bunch of extra info.

   To cast between DHPy and DebugHandle*, use as_DebugHandle and as_DHPy:
   these are just no-op casts.

   Each DHPy wraps a corresponding UHPy: DHPys are created by calling
   DHPy_open, and they must be eventually closed by DHPy_close. Note that if
   you call DHPy_open twice on the same UHPy, you get two different DHPy.

   To unwrap a DHPy and get the underyling UHPy, call DHPy_unwrap. If you call
   DHPy_unwrap multiple times on the same DHPy, you always get the same UHPy.

   WARNING: both UHPy and DHPy are alias of HPy, so we need to take care of
   not mixing them, because the compiler cannot help.

   Each DebugHandle has a "generation", which is just a int to be able to get
   only the handles which were created after a certain point.

   DHPys/DebugHandles are memory-managed by using a free list:

     - info->open_handles is a list of all DHPys which are currently open

     - DHPy_close() moves a DHPy from info->open_handles to info->closed_handles

     - if closed_handles is too big, the oldest DHPy is freed by DHPy_free()

     - to allocate memory for a new DHPy, DHPy_open() does the following:

         * if closed_handles is full, it reuses the memory of the oldest DHPy
           in the queue

         * else, it malloc()s memory for a new DHPy
*/

typedef HPy UHPy;
typedef HPy DHPy;

/* Under CPython:
     - UHPy always end with 1 (see hpy.universal's _py2h and _h2py)
     - DHPy are pointers, so they always end with 0

   DHPy_sanity_check is a minimal check to ensure that we are not treating a
   UHPy as a DHPy. Note that DHPy_sanity_check works fine also on HPy_NULL.

   NOTE: UHPy_sanity_check works ONLY with CPython's hpy.universal, because
   UHPys are computed in such a way that the last bit it's always 1. On other
   implementations this assumption might not hold. By default,
   UHPy_sanity_check does nothing, unless you #define
   HPY_DEBUG_ENABLE_UHPY_SANITY_CHECK, which for CPython is done by setup.py
*/
static inline void DHPy_sanity_check(DHPy dh) {
    assert( (dh._i & 1) == 0 );
}

static inline void UHPy_sanity_check(UHPy uh) {
#ifdef HPY_DEBUG_ENABLE_UHPY_SANITY_CHECK
    if (!HPy_IsNull(uh))
        assert( (uh._i & 1) == 1 );
#endif
}

// NOTE: having a "generation" field is the easiest way to know when a handle
// was created, but we waste 8 bytes per handle. Since all handles of the same
// generation are stored sequentially in the open_handles list, a possible
// alternative implementation is to put special placeholders inside the list
// to mark the creation of a new generation
typedef struct DebugHandle {
    UHPy uh;
    long generation;
    bool is_closed;
    struct DebugHandle *prev;
    struct DebugHandle *next;
} DebugHandle;

static inline DebugHandle * as_DebugHandle(DHPy dh) {
    DHPy_sanity_check(dh);
    return (DebugHandle *)dh._i;
}

static inline DHPy as_DHPy(DebugHandle *handle) {
    return (DHPy){(HPy_ssize_t)handle};
}

DHPy DHPy_open(HPyContext *dctx, UHPy uh);
void DHPy_close(HPyContext *dctx, DHPy dh);
void DHPy_free(DHPy dh);
void DHPy_invalid_handle(HPyContext *dctx, DHPy dh);

static inline UHPy DHPy_unwrap(HPyContext *dctx, DHPy dh)
{
    if (HPy_IsNull(dh))
        return HPy_NULL;
    DebugHandle *handle = as_DebugHandle(dh);
    if (handle->is_closed)
        DHPy_invalid_handle(dctx, dh);
    return handle->uh;
}

/* === DHQueue === */

typedef struct {
    DebugHandle *head;
    DebugHandle *tail;
    HPy_ssize_t size;
} DHQueue;

void DHQueue_init(DHQueue *q);
void DHQueue_append(DHQueue *q, DebugHandle *h);
DebugHandle *DHQueue_popfront(DHQueue *q);
void DHQueue_remove(DHQueue *q, DebugHandle *h);
void DHQueue_sanity_check(DHQueue *q);

/* === HPyDebugInfo === */

static const HPy_ssize_t DEFAULT_CLOSED_HANDLES_QUEUE_MAX_SIZE = 1024;

typedef struct {
    long magic_number; // used just for sanity checks
    HPyContext *uctx;
    long current_generation;
    UHPy uh_on_invalid_handle; // should be an HPyField, when we have it
    HPy_ssize_t closed_handles_queue_max_size; // configurable by the user
    DHQueue open_handles;
    DHQueue closed_handles;
} HPyDebugInfo;

static inline HPyDebugInfo *get_info(HPyContext *dctx)
{
    HPyDebugInfo *info = (HPyDebugInfo*)dctx->_private;
    assert(info->magic_number == HPY_DEBUG_MAGIC); // sanity check
    return info;
}


#endif /* HPY_DEBUG_INTERNAL_H */
