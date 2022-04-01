#include "src/precommondefs.h"
#include <hpy.h>

RPY_EXPORTED HPyContext* pypy_hpy_debug_get_ctx(HPyContext *uctx);
RPY_EXPORTED int pypy_hpy_debug_ctx_init(HPyContext *dctx, HPyContext *uctx);
RPY_EXPORTED void pypy_hpy_debug_set_ctx(HPyContext *uctx);
RPY_EXPORTED HPy_ssize_t pypy_hpy_debug_open_handle(HPyContext *dctx, HPy_ssize_t uh);
RPY_EXPORTED void pypy_hpy_debug_close_handle(HPyContext *dctx, HPy_ssize_t _dh);
RPY_EXPORTED HPy_ssize_t pypy_hpy_debug_unwrap_handle(HPyContext *dctx, HPy_ssize_t _dh);
RPY_EXPORTED HPy_ssize_t pypy_HPyInit__debug(HPyContext *uctx);
