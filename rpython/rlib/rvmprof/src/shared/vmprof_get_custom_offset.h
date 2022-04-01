#pragma once

#ifdef PYPY_JIT_CODEMAP
#include "vmprof.h"

#ifdef VMPROF_WINDOWS
#include "msiinttypes/stdint.h"
#else
#include <stdint.h>
#endif

void *pypy_find_codemap_at_addr(long addr, long *start_addr);
long pypy_yield_codemap_at_addr(void *codemap_raw, long addr,
                                long *current_pos_addr);

#define MAX_INLINE_DEPTH  384

long vmprof_write_header_for_jit_addr(intptr_t *result, long n,
                                      intptr_t addr, int max_depth)
{
    void *codemap;
    long current_pos = 0;
    intptr_t ident, local_stack[MAX_INLINE_DEPTH];
    long m;
    long start_addr = 0;

    codemap = pypy_find_codemap_at_addr(addr, &start_addr);
    if (codemap == NULL || n >= max_depth - 2)
        // not a jit code at all or almost max depth
        return n;

    // modify the last entry to point to start address and not the random one
    // in the middle
    result[n++] = VMPROF_ASSEMBLER_TAG;
    result[n++] = start_addr;

    // build the list of code idents corresponding to the current
    // position inside this particular piece of assembler.  If (very
    // unlikely) we get more than MAX_INLINE_DEPTH recursion levels
    // all inlined inside this single piece of assembler, then stop:
    // there will be some missing frames then.  Otherwise, we need to
    // first collect 'local_stack' and then write it to 'result' in the
    // opposite order, stopping at 'max_depth'.  Previous versions of
    // the code would write the oldest calls and then stop---whereas
    // what we really need it to write the newest calls and then stop.
    m = 0;
    while (m < MAX_INLINE_DEPTH) {
        ident = pypy_yield_codemap_at_addr(codemap, addr, &current_pos);
        if (ident == -1)
            // finish
            break;
        if (ident == 0)
            continue; // not main codemap
        local_stack[m++] = ident;
    }
    while (m > 0 && n < max_depth) {
        result[n++] = VMPROF_JITTED_TAG;
        result[n++] = local_stack[--m];
    }
    return n;
}
#endif
