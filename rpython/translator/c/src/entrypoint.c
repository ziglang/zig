#include "common_header.h"
#ifdef PYPY_STANDALONE
#include "structdef.h"
#include "forwarddecl.h"
#include "preimpl.h"
#include <src/entrypoint.h>
#include <src/commondefs.h>
#include <src/mem.h>
#include <src/instrument.h>
#include <src/rtyper.h>
#include <src/exception.h>
#include <src/debug_traceback.h>
#include <src/asm.h>

#include <stdlib.h>
#include <stdio.h>


#if defined(MS_WINDOWS)
#  include <stdio.h>
#  include <fcntl.h>
#  include <io.h>
#endif

#ifdef RPY_WITH_GIL
# include <src/thread.h>
# include <src/threadlocal.h>
#endif

#ifdef RPY_REVERSE_DEBUGGER
# include <src-revdb/revdb_include.h>
#endif

RPY_EXPORTED
void rpython_startup_code(void)
{
#ifdef RPY_WITH_GIL
    RPython_ThreadLocals_ProgramInit();
    RPyGilAcquire();
#endif
    RPython_StartupCode();
#ifdef RPY_WITH_GIL
    RPyGilRelease();
#endif
}


RPY_EXTERN
int pypy_main_function(int argc, char *argv[])
{
    char *errmsg;
    int i, exitcode;

#if defined(MS_WINDOWS)
    _setmode(0, _O_BINARY);
    _setmode(1, _O_BINARY);
    _setmode(2, _O_BINARY);
#endif

#ifdef RPY_WITH_GIL
    /* Note that the GIL's mutexes are not automatically made; if the
       program starts threads, it needs to call rgil.gil_allocate().
       RPyGilAcquire() still works without that, but crash if it finds
       that it really needs to wait on a mutex. */
    RPython_ThreadLocals_ProgramInit();
    RPyGilAcquire();
#endif

    instrument_setup();

#ifdef RPY_REVERSE_DEBUGGER
    rpy_reverse_db_setup(&argc, &argv);
#endif

#ifndef MS_WINDOWS
    /* this message does no longer apply to win64 :-) */
    if (sizeof(void*) != SIZEOF_LONG) {
        errmsg = "only support platforms where sizeof(void*) == sizeof(long),"
                 " for now";
        goto error;
    }
#endif

    RPython_StartupCode();

#ifndef RPY_REVERSE_DEBUGGER
    exitcode = STANDALONE_ENTRY_POINT(argc, argv);
#else
    exitcode = rpy_reverse_db_main(STANDALONE_ENTRY_POINT, argc, argv);
#endif

    pypy_debug_alloc_results();

    if (RPyExceptionOccurred()) {
        /* print the RPython traceback */
        pypy_debug_catch_fatal_exception();
    }

    pypy_malloc_counters_results();

#ifdef RPY_WITH_GIL
    RPyGilRelease();
#endif

    return exitcode;

 memory_out:
    errmsg = "out of memory";
 error:
    fprintf(stderr, "Fatal error during initialization: %s\n", errmsg);
    abort();
    return 1;
}

int PYPY_MAIN_FUNCTION(int argc, char *argv[])
{
#ifdef PYPY_X86_CHECK_SSE2_DEFINED
    pypy_x86_check_sse2();
#endif
    return pypy_main_function(argc, argv);
}

#endif  /* PYPY_STANDALONE */
