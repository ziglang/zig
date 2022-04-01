#include <stdio.h>
#include "debug_internal.h"

static void debug_handles_sanity_check(HPyDebugInfo *info)
{
#ifndef NDEBUG
    DHQueue_sanity_check(&info->open_handles);
    DHQueue_sanity_check(&info->closed_handles);
    DebugHandle *h = info->open_handles.head;
    while(h != NULL) {
        assert(!h->is_closed);
        h = h->next;
    }
    h = info->closed_handles.head;
    while(h != NULL) {
        assert(h->is_closed);
        h = h->next;
    }
#endif
}

DHPy DHPy_open(HPyContext *dctx, UHPy uh)
{
    UHPy_sanity_check(uh);
    if (HPy_IsNull(uh))
        return HPy_NULL;
    HPyDebugInfo *info = get_info(dctx);

    // if the closed_handles queue is full, let's reuse one of those. Else,
    // malloc a new one
    DebugHandle *handle = NULL;
    if (info->closed_handles.size >= info->closed_handles_queue_max_size) {
        handle = DHQueue_popfront(&info->closed_handles);
    }
    else {
        handle = malloc(sizeof(DebugHandle));
        if (handle == NULL) {
            return HPyErr_NoMemory(info->uctx);
        }
    }
    handle->uh = uh;
    handle->generation = info->current_generation;
    handle->is_closed = 0;
    DHQueue_append(&info->open_handles, handle);
    debug_handles_sanity_check(info);
    return as_DHPy(handle);
}

static void print_error(HPyContext *uctx, const char *message)
{
    // We don't have a way to propagate exceptions from within DHPy_unwrap, so
    // we just print the exception to stderr and clear it
    // XXX: we should use HPySys_WriteStderr when we have it
    fprintf(stderr, "%s\n", message);
    //HPyErr_PrintEx(0); // uncommment when we have it
}


// this is called when we try to use a closed handle
void DHPy_invalid_handle(HPyContext *dctx, DHPy dh)
{
    HPyDebugInfo *info = get_info(dctx);
    HPyContext *uctx = info->uctx;
    DebugHandle *handle = as_DebugHandle(dh);
    assert(handle->is_closed);
    if (HPy_IsNull(info->uh_on_invalid_handle)) {
        // default behavior: print an error and abort
        HPy_FatalError(uctx, "Invalid usage of already closed handle");
    }
    /* call the custom callback but do NOT abort the execution. This
       is useful e.g. on CPython where "closed handles" are still
       actually valid until the refcount > 0: it should make it easier
       to port extensions to HPy, e.g. by printing a warning inside
       the callback and let the execution to continue, so that people
       can fix the warnings one by one.
    */
    UHPy uh_res = HPy_NULL;
    uh_res = HPy_CallTupleDict(uctx, info->uh_on_invalid_handle, HPy_NULL, HPy_NULL);
    if (HPy_IsNull(uh_res))
        print_error(uctx, "Error when executing the on_invalid_handle callback");
    HPy_Close(uctx, uh_res);
}

void DHPy_close(HPyContext *dctx, DHPy dh)
{
    DHPy_sanity_check(dh);
    if (HPy_IsNull(dh))
        return;
    HPyDebugInfo *info = get_info(dctx);
    DebugHandle *handle = as_DebugHandle(dh);

    /* This check is needed for a very specific case: calling HPy_Close twice
       on the same handle is considered an error, and by default the
       DHPy_unwrap inside debug_ctx_Close catches the problem and abort the
       process with a HPy_FatalError.

       However, we leave the possibility to the user to install a custom hook
       to be called when we detect an invalid handle. In this case, the
       process does not abort and the execution tries to continue. This is
       more useful than what it sounds, because on CPython "closing a handle
       twice" still works in practice as long as the refcount > 0. So, we can
       install a hook which emits a warning and let the user to fix the
       problems one by one, without aborting the process.
    */
    if (handle->is_closed)
        return;

    // move the handle from open_handles to closed_handles
    DHQueue_remove(&info->open_handles, handle);
    DHQueue_append(&info->closed_handles, handle);
    handle->is_closed = true;

    if (info->closed_handles.size > info->closed_handles_queue_max_size) {
        // we have too many closed handles. Let's free the oldest one
        DebugHandle *oldest = DHQueue_popfront(&info->closed_handles);
        DHPy_free(as_DHPy(oldest));
    }
    debug_handles_sanity_check(info);
}

void DHPy_free(DHPy dh)
{
    DHPy_sanity_check(dh);
    DebugHandle *handle = as_DebugHandle(dh);
    // this is not strictly necessary, but it increases the chances that you
    // get a clear segfault if you use a freed handle
    handle->uh = HPy_NULL;
    free(handle);
}
