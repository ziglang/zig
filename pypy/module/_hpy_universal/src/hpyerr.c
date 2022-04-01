#ifndef RPYTHON_LL2CTYPES
#  include "common_header.h"
#  include "structdef.h"
#  include "forwarddecl.h"
#  include "preimpl.h"
#  include "src/exception.h"
#endif

#include <stdio.h>
#include "hpy.h"
#include "hpyerr.h"
#include "bridge.h"


void pypy_HPy_FatalError(HPyContext *ctx, const char *message)
{
    fprintf(stderr, "Fatal Python error: %s\n", message);
    abort();
}
