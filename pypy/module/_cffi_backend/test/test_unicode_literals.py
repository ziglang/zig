#
# ----------------------------------------------
# WARNING, ALL LITERALS IN THIS FILE ARE UNICODE
# ----------------------------------------------
#
from __future__ import unicode_literals
#
#
#
from pypy.module._cffi_backend.newtype import _clean_cache


class AppTestUnicodeLiterals:
    spaceconfig = dict(usemodules=('_cffi_backend', ))

    def teardown_method(self, meth):
        _clean_cache(self.space)

    def test_cast(self):
        from _cffi_backend import FFI
        ffi = FFI()
        assert int(ffi.cast("int", 3.14)) == 3        # unicode literal

    def test_new(self):
        from _cffi_backend import FFI
        ffi = FFI()
        assert ffi.new("int[]", [3, 4, 5])[2] == 5    # unicode literal

    def test_typeof(self):
        from _cffi_backend import FFI
        ffi = FFI()
        tp = ffi.typeof("int[51]")                    # unicode literal
        assert tp.length == 51

    def test_sizeof(self):
        from _cffi_backend import FFI
        ffi = FFI()
        assert ffi.sizeof("int[51]") == 51 * 4        # unicode literal

    def test_alignof(self):
        from _cffi_backend import FFI
        ffi = FFI()
        assert ffi.alignof("int[51]") == 4            # unicode literal

    def test_getctype(self):
        from _cffi_backend import FFI
        ffi = FFI()
        assert ffi.getctype("int**") == "int * *"     # unicode literal
        assert type(ffi.getctype("int**")) is str

    def test_callback(self):
        from _cffi_backend import FFI
        ffi = FFI()
        cb = ffi.callback("int(int)",                 # unicode literal
                          lambda x: x + 42)
        assert cb(5) == 47
