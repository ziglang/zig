
from cffi import FFI as _FFI

_ffi = _FFI()

_ffi.cdef("""
void* malloc(size_t size);
void free(void *ptr);
""")
_ffi.set_source("_pypy_util_cffi_inner", "")

if __name__ == '__main__':
    _ffi.compile()
