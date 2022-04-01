#include "debug_internal.h"
#include "dctx.h"

// the default symbol visibility is hidden: the easiest way to export
// these two functions is to write a small wrapper.
HPyContext* pypy_hpy_debug_get_ctx(HPyContext *uctx) {
    return hpy_debug_get_ctx(uctx);
}

int pypy_hpy_debug_ctx_init(HPyContext *dctx, HPyContext *uctx) {
    return hpy_debug_ctx_init(dctx, uctx);
}

HPy_ssize_t pypy_hpy_debug_open_handle(HPyContext *dctx, HPy_ssize_t _uh) {
    HPy uh = {._i = _uh};
    HPy dh = hpy_debug_open_handle(dctx, uh);
    return dh._i;
}

HPy_ssize_t pypy_hpy_debug_unwrap_handle(HPyContext *dctx, HPy_ssize_t _dh) {
    HPy dh = {._i = _dh};
    HPy uh = hpy_debug_unwrap_handle(dctx, dh);
    return uh._i;
}

void pypy_hpy_debug_close_handle(HPyContext *dctx, HPy_ssize_t _dh) {
    DHPy dh = {._i = _dh};
    hpy_debug_close_handle(dctx, dh);
}

HPy_ssize_t pypy_HPyInit__debug(HPyContext *uctx) {
    HPy h_mod = HPyInit__debug(uctx);
    return h_mod._i;
}

void pypy_hpy_debug_set_ctx(HPyContext *dctx) {
    hpy_debug_set_ctx(dctx);
}

// NOTE: this is currently unused: it is needed because it is
// referenced by hpy_magic_dump. But we could try to use this variable to
// store the actual ctx instead of malloc()ing it in setup_ctx.
struct _HPyContext_s g_universal_ctx;
