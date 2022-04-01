from rpython.rlib.rdynload import *
from rpython.rlib.clibffi import get_libc_name
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.translator.platform import platform
import py

class TestDLOperations:
    def test_dlopen(self):
        s = rffi.str2charp('xxxxxxxxxxxx')
        py.test.raises(DLOpenError, "dlopen(s)")
        rffi.free_charp(s)
        #
        s = rffi.str2charp(get_libc_name())
        assert dlopen(s)
        rffi.free_charp(s)

    def test_dlsym(self):
        s = rffi.str2charp(get_libc_name())
        lib = dlopen(s)
        rffi.free_charp(s)
        handle = rffi.cast(lltype.Ptr(lltype.FuncType([lltype.Signed],
                           lltype.Signed)), dlsym(lib, 'abs'))
        assert 1 == handle(1)
        assert 1 == handle(-1)

    def test_ldscripts(self):
        # this test only makes sense on linux
        if platform.name != "linux":
            return

        fname = os.path.join(os.path.dirname(__file__), "ldscript_working1.so")
        s = rffi.str2charp(fname)
        assert "C object" in str(dlopen(s))
        rffi.free_charp(s)

        fname = os.path.join(os.path.dirname(__file__), "ldscript_working2.so")
        s = rffi.str2charp(fname)
        assert "C object" in str(dlopen(s))
        rffi.free_charp(s)

        fname = os.path.join(os.path.dirname(__file__), "ldscript_broken1.so")
        s = rffi.str2charp(fname)
        py.test.raises(DLOpenError, 'dlopen(s)')
        rffi.free_charp(s)

        fname = os.path.join(os.path.dirname(__file__), "ldscript_broken2.so")
        s = rffi.str2charp(fname)
        py.test.raises(DLOpenError, 'dlopen(s)')
        rffi.free_charp(s)
