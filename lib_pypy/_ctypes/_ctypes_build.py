import os

from cffi import FFI

ffi = FFI()
ffi.cdef('bool dyld_shared_cache_contains_path(const char* path);')
ffi.set_source('_ctypes_cffi', r'''
#include <stdbool.h>
#include <mach-o/dyld.h>

bool _dyld_shared_cache_contains_path(const char* path) __attribute__((weak_import));
bool dyld_shared_cache_contains_path(const char* path) {
    if (_dyld_shared_cache_contains_path == NULL) {
        return false;
    }
    return _dyld_shared_cache_contains_path(path);
}
''')

if __name__ == '__main__':
    os.chdir(os.path.dirname(__file__))
    ffi.compile()
