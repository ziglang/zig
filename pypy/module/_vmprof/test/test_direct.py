import sys
import py
try:
    import cffi
except ImportError:
    py.test.skip('cffi required')

from rpython.rlib import rvmprof
srcdir = py.path.local(rvmprof.__file__).join("..", "src")
shareddir = srcdir.join('shared')

ffi = cffi.FFI()
ffi.cdef("""
long vmprof_write_header_for_jit_addr(void **, long, void*, int);
void *pypy_find_codemap_at_addr(long addr, long *start_addr);
long pypy_yield_codemap_at_addr(void *codemap_raw, long addr,
                                long *current_pos_addr);
long buffer[];
""")

lib = ffi.verify("""
#define PYPY_JIT_CODEMAP
#include "vmprof_stack.h"

volatile int pypy_codemap_currently_invalid = 0;

long buffer[] = {0, 0, 0, 0, 0};



void *pypy_find_codemap_at_addr(long addr, long *start_addr)
{
    return (void*)buffer;
}

long pypy_yield_codemap_at_addr(void *codemap_raw, long addr,
                                long *current_pos_addr)
{
    long c = *current_pos_addr;
    if (c >= 5)
        return -1;
    *current_pos_addr = c + 1;
    return *((long*)codemap_raw + c);
}


""" + open(str(srcdir.join("shared/vmprof_get_custom_offset.h"))).read(), include_dirs=[str(srcdir), str(shareddir)])

class TestDirect(object):
    def test_infrastructure(self):
        cont = ffi.new("long[1]", [0])
        buf = lib.pypy_find_codemap_at_addr(0, cont)
        assert buf
        cont[0] = 0
        next_addr = lib.pypy_yield_codemap_at_addr(buf, 0, cont)
        assert cont[0] == 1
        assert not next_addr
        lib.buffer[0] = 13
        cont[0] = 0
        next_addr = lib.pypy_yield_codemap_at_addr(buf, 0, cont)
        assert int(ffi.cast("long", next_addr)) == 13

    def test_write_header_for_jit_addr(self):
        lib.buffer[0] = 4
        lib.buffer[1] = 8
        lib.buffer[2] = 12
        lib.buffer[3] = 16
        lib.buffer[4] = 0
        buf = ffi.new("long[10]", [0] * 10)
        result = ffi.cast("void**", buf)
        res = lib.vmprof_write_header_for_jit_addr(result, 0, ffi.NULL, 100)
        assert res == 10
        assert [x for x in buf] == [6, 0, 3, 16, 3, 12, 3, 8, 3, 4]
