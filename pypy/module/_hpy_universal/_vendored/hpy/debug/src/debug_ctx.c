#include <string.h>
#include <stdio.h>
#include "debug_internal.h"
#include "autogen_debug_ctx_init.h"
#include "hpy/runtime/ctx_funcs.h"
#if defined(_MSC_VER)
# include <malloc.h>   /* for alloca() */
#endif

static struct _HPyContext_s g_debug_ctx = {
    .name = "HPy Debug Mode ABI",
    ._private = NULL,
    .ctx_version = 1,
};

// NOTE: at the moment this function assumes that uctx is always the
// same. If/when we migrate to a system in which we can have multiple
// independent contexts, this function should ensure to create a different
// debug wrapper for each of them.
int hpy_debug_ctx_init(HPyContext *dctx, HPyContext *uctx)
{
    if (dctx->_private != NULL) {
        // already initialized
        assert(get_info(dctx)->uctx == uctx); // sanity check
        return 0;
    }
    // initialize debug_info
    // XXX: currently we never free this malloc
    HPyDebugInfo *info = malloc(sizeof(HPyDebugInfo));
    if (info == NULL) {
        HPyErr_NoMemory(uctx);
        return -1;
    }
    info->magic_number = HPY_DEBUG_MAGIC;
    info->uctx = uctx;
    info->current_generation = 0;
    info->uh_on_invalid_handle = HPy_NULL;
    info->closed_handles_queue_max_size = DEFAULT_CLOSED_HANDLES_QUEUE_MAX_SIZE;
    DHQueue_init(&info->open_handles);
    DHQueue_init(&info->closed_handles);
    dctx->_private = info;
    debug_ctx_init_fields(dctx, uctx);
    return 0;
}

HPyContext * hpy_debug_get_ctx(HPyContext *uctx)
{
    HPyContext *dctx = &g_debug_ctx;
    if (uctx == dctx) {
        HPy_FatalError(uctx, "hpy_debug_get_ctx: expected an universal ctx, "
                             "got a debug ctx");
    }
    if (hpy_debug_ctx_init(dctx, uctx) < 0)
        return NULL;
    return dctx;
}

void hpy_debug_set_ctx(HPyContext *dctx)
{
    g_debug_ctx = *dctx;
}

HPy hpy_debug_open_handle(HPyContext *dctx, HPy uh)
{
    return DHPy_open(dctx, uh);
}

HPy hpy_debug_unwrap_handle(HPyContext *dctx, HPy dh)
{
    return DHPy_unwrap(dctx, dh);
}

void hpy_debug_close_handle(HPyContext *dctx, HPy dh)
{
    DHPy_close(dctx, dh);
}

// this function is supposed to be called from gdb: it tries to determine
// whether a handle is universal or debug by looking at the last bit
extern struct _HPyContext_s g_universal_ctx;
#ifndef _MSC_VER
__attribute__((unused))
#endif
static void hpy_magic_dump(HPy h)
{
    int universal = h._i & 1;
    if (universal)
        fprintf(stderr, "\nUniversal handle\n");
    else
        fprintf(stderr, "\nDebug handle\n");

#ifdef _MSC_VER
    fprintf(stderr, "raw value: %Ix (%Id)\n", h._i, h._i);
#else
    fprintf(stderr, "raw value: %lx (%ld)\n", h._i, h._i);
#endif
    if (universal)
        _HPy_Dump(&g_universal_ctx, h);
    else {
        DebugHandle *dh = as_DebugHandle(h);
#ifdef _MSC_VER
        fprintf(stderr, "dh->uh: %Ix\n", dh->uh._i);
#else
        fprintf(stderr, "dh->uh: %lx\n", dh->uh._i);
#endif
        _HPy_Dump(&g_universal_ctx, dh->uh);
    }
}

/* ~~~~~~~~~~ manually written wrappers ~~~~~~~~~~ */

void debug_ctx_Close(HPyContext *dctx, DHPy dh)
{
    UHPy uh = DHPy_unwrap(dctx, dh);
    DHPy_close(dctx, dh);
    HPy_Close(get_info(dctx)->uctx, uh);
}

DHPy debug_ctx_Tuple_FromArray(HPyContext *dctx, DHPy dh_items[], HPy_ssize_t n)
{
    UHPy *uh_items = (UHPy *)alloca(n * sizeof(UHPy));
    for(int i=0; i<n; i++) {
        uh_items[i] = DHPy_unwrap(dctx, dh_items[i]);
    }
    return DHPy_open(dctx, HPyTuple_FromArray(get_info(dctx)->uctx, uh_items, n));
}

DHPy debug_ctx_Type_GenericNew(HPyContext *dctx, DHPy dh_type, DHPy *dh_args,
                               HPy_ssize_t nargs, DHPy dh_kw)
{
    UHPy uh_type = DHPy_unwrap(dctx, dh_type);
    UHPy uh_kw = DHPy_unwrap(dctx, dh_kw);
    UHPy *uh_args = (UHPy *)alloca(nargs * sizeof(UHPy));
    for(int i=0; i<nargs; i++) {
        uh_args[i] = DHPy_unwrap(dctx, dh_args[i]);
    }
    return DHPy_open(dctx, HPyType_GenericNew(get_info(dctx)->uctx, uh_type, uh_args,
                                              nargs, uh_kw));
}

DHPy debug_ctx_Type_FromSpec(HPyContext *dctx, HPyType_Spec *spec, HPyType_SpecParam *dparams)
{
    // dparams might contain some hidden DHPy: we need to manually unwrap them.
    if (dparams != NULL) {
        // count the params
        HPy_ssize_t n = 1;
        for (HPyType_SpecParam *p = dparams; p->kind != 0; p++) {
            n++;
        }
        HPyType_SpecParam *uparams = (HPyType_SpecParam *)alloca(n * sizeof(HPyType_SpecParam));
        for (HPy_ssize_t i=0; i<n; i++) {
            uparams[i].kind = dparams[i].kind;
            uparams[i].object = DHPy_unwrap(dctx, dparams[i].object);
        }
        return DHPy_open(dctx, HPyType_FromSpec(get_info(dctx)->uctx, spec, uparams));
    }
    return DHPy_open(dctx, HPyType_FromSpec(get_info(dctx)->uctx, spec, NULL));
}

/* ~~~ debug mode implementation of HPyTracker ~~~

   This is a bit special and it's worth explaining what is going on.

   The HPyTracker functions need their own debug mode implementation because
   the debug moe needs to be aware of when a DHPy is closed, for the same
   reason for why we need debug_ctx_Close.

   So, in theory here we should have our own implementation of a
   DebugHPyTracker which manages a growable list of handles, and which calls
   debug_ctx_Close at the end. But, we ALREADY have the logic available, it's
   implemented in ctx_tracker.c.

   So, here we simply implement debug_ctx_Tracker_* in terms of ctx_Tracker_*:
   but note that it's VERY different than what the autogen wrappers do:

     - the autogen wrappers DHPy_unwrap() all the handles before calling the
       "super" implementation. Here we don't, we pass the DHPys directly.

     - the autogen wrappers pass the uctx to the "super" implementation, here
       we pass the dctx.

   Conceptually, it is equivalent to just have our own implementation of a
   growable array, but by using this trick we can easily reuse the existing
   code.

   It is better understood if you think of what happens on PyPy (or any other
   universal implementation): normally, on PyPy HPyTracker_Add calls PyPy's
   own implementation (see interp_tracker.py). But when in debug mode,
   HPyTracker_Add will call the ctx_Tracker_Add defined in ctx_tracker.c,
   completely bypassing PyPy's own tracker (which is fine). Incidentally, this
   also means that if PyPy wants to bundle the debug mode, it also needs to
   compile ctx_tracker.c
*/

HPyTracker debug_ctx_Tracker_New(HPyContext *dctx, HPy_ssize_t size)
{
    return ctx_Tracker_New(dctx, size);
}

int debug_ctx_Tracker_Add(HPyContext *dctx, HPyTracker ht, DHPy dh)
{
    return ctx_Tracker_Add(dctx, ht, dh);
}

void debug_ctx_Tracker_ForgetAll(HPyContext *dctx, HPyTracker ht)
{
    ctx_Tracker_ForgetAll(dctx, ht);
}

void debug_ctx_Tracker_Close(HPyContext *dctx, HPyTracker ht)
{
    // note: ctx_Tracker_Close internally calls HPy_Close() to close each
    // handle: since we are calling it with the dctx, it will end up calling
    // debug_ctx_Close, which is exactly what we need to properly record that
    // the handles were closed.
    ctx_Tracker_Close(dctx, ht);
}
